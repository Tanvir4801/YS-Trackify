import {
  collection,
  doc,
  getDocs,
  addDoc,
  updateDoc,
  setDoc,
  writeBatch,
  query,
  where,
  onSnapshot,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from '../firebase';
import { getLabour } from './labours.service';

// ── Nested-path helpers ─────────────────────────────────────────────────────

function nestedRecordsCol(contractorId, date) {
  return collection(db, 'attendance', contractorId, 'dates', date, 'records');
}

function nestedRecordDoc(contractorId, date, labourId) {
  return doc(db, 'attendance', contractorId, 'dates', date, 'records', labourId);
}

function dateSentinelDoc(contractorId, date) {
  return doc(db, 'attendance', contractorId, 'dates', date);
}

// ── Converters ──────────────────────────────────────────────────────────────

function snapToDoc(snap) {
  const data = snap.data() || {};
  const al = (typeof data.allowances === 'object' && data.allowances) ? data.allowances : {};
  const petrol    = Number(al.petrol    ?? data.petrol    ?? 0) || 0;
  const lunch     = Number(al.lunch     ?? data.lunch     ?? 0) || 0;
  const breakfast = Number(al.breakfast ?? data.breakfast ?? 0) || 0;
  const tea       = Number(al.tea       ?? data.tea       ?? 0) || 0;
  const advance   = Number(data.advance ?? 0) || 0;
  const wageAtTime = Number(data.wageAtTime) || 0;
  return {
    id: snap.id,
    ...data,
    overtimeHours: Number(data.overtimeHours) || 0,
    wageAtTime,
    remark: data.remark || data.notes || '',
    siteId: data.siteId || data.supervisorId || '',
    syncedAt: data.syncedAt?.toDate?.() || null,
    petrol, lunch, breakfast, tea, advance,
    totalAllowance: petrol + lunch + breakfast + tea,
    grandTotal: wageAtTime + petrol + lunch + breakfast + tea - advance,
  };
}

// Nested docs use labourId as the doc ID — synthesise a flat-compatible record
function nestedSnapToDoc(snap, date) {
  const data = snap.data() || {};
  const labourId = data.labourId || snap.id;
  const al = (typeof data.allowances === 'object' && data.allowances) ? data.allowances : {};
  const petrol    = Number(al.petrol    ?? data.petrol    ?? 0) || 0;
  const lunch     = Number(al.lunch     ?? data.lunch     ?? 0) || 0;
  const breakfast = Number(al.breakfast ?? data.breakfast ?? 0) || 0;
  const tea       = Number(al.tea       ?? data.tea       ?? 0) || 0;
  const advance   = Number(data.advance ?? 0) || 0;
  const wageAtTime = Number(data.wageAtTime) || 0;
  return {
    id: `${labourId}_${date}`,
    ...data,
    labourId,
    date: date || data.date || '',
    overtimeHours: Number(data.overtimeHours) || 0,
    wageAtTime,
    remark: data.remark || data.notes || '',
    siteId: data.siteId || data.supervisorId || '',
    syncedAt: data.syncedAt?.toDate?.() || null,
    markedVia: data.markedVia || '',
    petrol, lunch, breakfast, tea, advance,
    totalAllowance: petrol + lunch + breakfast + tea,
    grandTotal: wageAtTime + petrol + lunch + breakfast + tea - advance,
  };
}

// Merge: flat records (richer, have allowances) override nested.
// Nested fills in any QR records that failed the flat write.
function mergeFlatAndNested(flatDocs, nestedDocs, supervisorIdFilter) {
  const merged = new Map();
  const filteredNested = supervisorIdFilter
    ? nestedDocs.filter((r) => !r.supervisorId || r.supervisorId === supervisorIdFilter)
    : nestedDocs;
  filteredNested.forEach((r) => { if (r.labourId) merged.set(r.labourId, r); });
  flatDocs.forEach((r) => { if (r.labourId) merged.set(r.labourId, r); });
  return Array.from(merged.values());
}

// ── getAttendanceByDate ─────────────────────────────────────────────────────

export async function getAttendanceByDate(scopeId, date, isSupervisor = false, supervisorId = null) {
  if (!date || !scopeId) return [];

  const flatQ = isSupervisor && supervisorId
    ? query(collection(db, 'attendance'), where('date', '==', date), where('supervisorId', '==', supervisorId), where('contractorId', '==', scopeId))
    : query(collection(db, 'attendance'), where('date', '==', date), where('contractorId', '==', scopeId));

  const [flatSnap, nestedSnap] = await Promise.all([
    getDocs(flatQ),
    getDocs(nestedRecordsCol(scopeId, date)).catch(() => ({ docs: [] })),
  ]);

  return mergeFlatAndNested(
    flatSnap.docs.map(snapToDoc),
    nestedSnap.docs.map((d) => nestedSnapToDoc(d, date)),
    isSupervisor ? supervisorId : null,
  );
}

// ── subscribeAttendanceByDate ───────────────────────────────────────────────

export function subscribeAttendanceByDate(scopeId, date, callback, isSupervisor = false, supervisorId = null) {
  if (!date || !scopeId) { callback([]); return () => {}; }

  const flatQ = isSupervisor && supervisorId
    ? query(collection(db, 'attendance'), where('date', '==', date), where('supervisorId', '==', supervisorId), where('contractorId', '==', scopeId))
    : query(collection(db, 'attendance'), where('date', '==', date), where('contractorId', '==', scopeId));

  let flatDocs = [];
  let nestedDocs = [];
  let firstEmit = false;

  const emit = () => {
    callback(mergeFlatAndNested(flatDocs, nestedDocs, isSupervisor ? supervisorId : null));
  };

  const unsub1 = onSnapshot(flatQ, (snap) => {
    flatDocs = snap.docs.map(snapToDoc);
    firstEmit = true;
    emit();
  }, (err) => { console.error('subscribeAttendanceByDate flat error:', err); });

  const unsub2 = onSnapshot(nestedRecordsCol(scopeId, date), (snap) => {
    nestedDocs = snap.docs.map((d) => nestedSnapToDoc(d, date));
    if (firstEmit) emit(); // only emit once flat has fired at least once
  }, (err) => { console.error('subscribeAttendanceByDate nested error:', err); });

  return () => { unsub1(); unsub2(); };
}

// ── updateAttendanceStatus ──────────────────────────────────────────────────

export async function updateAttendanceStatus(id, status) {
  await updateDoc(doc(db, 'attendance', id), { status, updatedAt: serverTimestamp() });
}

// ── updateOvertimeHours ─────────────────────────────────────────────────────

export async function updateOvertimeHours(id, overtimeHours) {
  await updateDoc(doc(db, 'attendance', id), {
    overtimeHours: Number(overtimeHours) || 0,
    updatedAt: serverTimestamp(),
  });
}

// ── updateAttendanceRemark ──────────────────────────────────────────────────

export async function updateAttendanceRemark(id, remark, contractorId = null, date = null, labourId = null) {
  await updateDoc(doc(db, 'attendance', id), {
    remark, notes: remark, updatedAt: serverTimestamp(),
  });
  if (contractorId && date && labourId) {
    try {
      await updateDoc(nestedRecordDoc(contractorId, date, labourId), {
        remark, updatedAt: serverTimestamp(),
      });
    } catch (e) {
      console.warn('updateAttendanceRemark nested update skipped (doc may not exist yet):', e?.code);
    }
  }
}

// ── markAttendance ──────────────────────────────────────────────────────────

export async function markAttendance(scopeId, labourId, date, data, isSupervisor = false, supervisorId = null) {
  if (!labourId || !date || !scopeId) throw new Error('scopeId, labourId, and date are required');

  const q_obj = isSupervisor && supervisorId
    ? query(collection(db, 'attendance'), where('labourId', '==', labourId), where('date', '==', date), where('supervisorId', '==', supervisorId), where('contractorId', '==', scopeId))
    : query(collection(db, 'attendance'), where('labourId', '==', labourId), where('date', '==', date), where('contractorId', '==', scopeId));

  const snap = await getDocs(q_obj);
  const existingId = snap.docs[0]?.id || null;

  let wageAtTime = Number(data.wageAtTime) || 0;
  if (!wageAtTime) {
    try { wageAtTime = Number((await getLabour(labourId))?.dailyWage) || 0; } catch (_) { /* ignore */ }
  }

  const supId = isSupervisor ? supervisorId : scopeId;
  const payload = {
    labourId, date,
    status: data.status,
    overtimeHours: Number(data.overtimeHours) || 0,
    remark: data.remark || '',
    notes: data.remark || '',
    wageAtTime,
    siteId: data.siteId || supervisorId || scopeId,
    contractorId: scopeId,
    supervisorId: supId,
    markedVia: 'admin_manual',
    isSynced: true,
    syncedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  let flatId;
  if (existingId) {
    await updateDoc(doc(db, 'attendance', existingId), payload);
    flatId = existingId;
  } else {
    const ref = await addDoc(collection(db, 'attendance'), payload);
    await updateDoc(ref, { id: ref.id });
    flatId = ref.id;
  }

  try {
    await setDoc(nestedRecordDoc(scopeId, date, labourId), {
      labourId, date, contractorId: scopeId, supervisorId: supId,
      status: data.status,
      overtimeHours: Number(data.overtimeHours) || 0,
      remark: data.remark || '',
      wageAtTime,
      siteId: data.siteId || supervisorId || scopeId,
      markedVia: 'admin_manual',
      markedAt: serverTimestamp(),
      lastModifiedVia: 'admin_manual',
      lastModifiedAt: serverTimestamp(),
      legacyId: flatId,
    }, { merge: true });
    await setDoc(dateSentinelDoc(scopeId, date), {
      date, contractorId: scopeId, updatedAt: serverTimestamp(),
    }, { merge: true });
  } catch (e) {
    console.error('markAttendance nested write failed:', e);
  }

  return flatId;
}

// ── bulkMarkAttendance ──────────────────────────────────────────────────────

export async function bulkMarkAttendance(scopeId, date, records, isSupervisor = false, supervisorId = null) {
  if (!scopeId || !date) throw new Error('scopeId and date are required');
  if (!records || records.length === 0) return;

  const existing = await getAttendanceByDate(scopeId, date, isSupervisor, supervisorId);
  const existingByLabour = new Map();
  existing.forEach((r) => { if (r.labourId) existingByLabour.set(r.labourId, r.id); });
  const wageMap = new Map();
  existing.forEach((r) => { if (r.wageAtTime) wageMap.set(r.labourId, r.wageAtTime); });

  // Each record = 2 ops (flat + nested) + 1 sentinel per chunk → max 200 records/chunk
  const CHUNK = 200;
  const chunks = [];
  for (let i = 0; i < records.length; i += CHUNK) chunks.push(records.slice(i, i + CHUNK));

  const supId = isSupervisor ? supervisorId : scopeId;

  for (const chunk of chunks) {
    const batch = writeBatch(db);

    for (const rec of chunk) {
      if (!rec.labourId || !rec.status) { console.warn('Skipping invalid record:', rec); continue; }

      const existingId = existingByLabour.get(rec.labourId);
      const wageAtTime = Number(rec.wageAtTime) || wageMap.get(rec.labourId) || Number(rec.dailyWage) || 0;

      const payload = {
        labourId: rec.labourId, date,
        status: rec.status || 'present',
        overtimeHours: Number(rec.overtimeHours) || 0,
        remark: rec.remark || '',
        notes: rec.remark || '',
        wageAtTime,
        siteId: rec.siteId || supervisorId || scopeId,
        contractorId: scopeId,
        supervisorId: supId,
        markedVia: 'admin_manual',
        isSynced: true,
        syncedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };

      let flatId;
      if (existingId) {
        flatId = existingId;
        batch.update(doc(db, 'attendance', existingId), payload);
      } else {
        const flatRef = doc(collection(db, 'attendance'));
        flatId = flatRef.id;
        batch.set(flatRef, { id: flatRef.id, ...payload });
      }

      batch.set(nestedRecordDoc(scopeId, date, rec.labourId), {
        labourId: rec.labourId, date,
        contractorId: scopeId,
        supervisorId: supId,
        status: rec.status || 'present',
        overtimeHours: Number(rec.overtimeHours) || 0,
        remark: rec.remark || '',
        wageAtTime,
        siteId: rec.siteId || supervisorId || scopeId,
        markedVia: 'admin_manual',
        markedAt: serverTimestamp(),
        lastModifiedVia: 'admin_manual',
        lastModifiedAt: serverTimestamp(),
        legacyId: flatId,
      }, { merge: true });
    }

    batch.set(dateSentinelDoc(scopeId, date), {
      date, contractorId: scopeId, updatedAt: serverTimestamp(),
    }, { merge: true });

    await batch.commit();
  }
}

// ── updateAttendanceAllowances ──────────────────────────────────────────────

export async function updateAttendanceAllowances(id, {
  petrol = 0, lunch = 0, breakfast = 0, tea = 0,
  advance = 0, wageAtTime = 0,
  contractorId = null, date = null, labourId = null,
}) {
  const p = Number(petrol) || 0;
  const l = Number(lunch) || 0;
  const b = Number(breakfast) || 0;
  const t = Number(tea) || 0;
  const adv = Number(advance) || 0;
  const wage = Number(wageAtTime) || 0;
  const totalAllowance = p + l + b + t;
  const grandTotal = wage + totalAllowance - adv;

  const allowancePayload = {
    allowances: { petrol: p, lunch: l, breakfast: b, tea: t },
    petrol: p, lunch: l, breakfast: b, tea: t,
    advance: adv, totalAllowance, grandTotal,
    updatedAt: serverTimestamp(),
  };

  await updateDoc(doc(db, 'attendance', id), allowancePayload);

  if (contractorId && date && labourId) {
    try {
      await updateDoc(nestedRecordDoc(contractorId, date, labourId), {
        allowances: { petrol: p, lunch: l, breakfast: b, tea: t },
        petrol: p, lunch: l, breakfast: b, tea: t,
        advance: adv, totalAllowance, grandTotal,
        updatedAt: serverTimestamp(),
      });
    } catch (e) {
      console.warn('updateAttendanceAllowances nested update skipped:', e?.code);
    }
  }
}

// ── getAttendanceRange ──────────────────────────────────────────────────────
// Query by contractorId only (single-field index — always available).
// Date range and supervisorId filtering done client-side to avoid composite
// index requirements that cause failed-precondition errors.

export async function getAttendanceRange(scopeId, startDate, endDate, labourId, isSupervisor = false, supervisorId = null) {
  if (!startDate || !endDate || !scopeId) return [];

  const snap = await getDocs(
    query(collection(db, 'attendance'), where('contractorId', '==', scopeId))
  );

  const map = new Map();
  snap.docs.forEach((d) => {
    const rec = snapToDoc(d);
    if (!rec.labourId || !rec.date) return;
    // Client-side date filter
    if (rec.date < startDate || rec.date > endDate) return;
    // Client-side labourId filter
    if (labourId && rec.labourId !== labourId) return;
    // Client-side supervisorId filter
    if (isSupervisor && supervisorId && rec.supervisorId && rec.supervisorId !== supervisorId) return;
    map.set(`${rec.labourId}_${rec.date}`, rec);
  });
  return Array.from(map.values());
}
