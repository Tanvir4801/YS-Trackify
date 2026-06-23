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
    petrol,
    lunch,
    breakfast,
    tea,
    advance,
    totalAllowance: petrol + lunch + breakfast + tea,
    grandTotal: wageAtTime + petrol + lunch + breakfast + tea - advance,
  };
}

export async function getAttendanceByDate(scopeId, date, isSupervisor = false, supervisorId = null) {
  if (!date) return [];
  let queries = [];
  if (isSupervisor && supervisorId) {
    queries = [query(collection(db, 'attendance'), where('date', '==', date), where('supervisorId', '==', supervisorId), where('contractorId', '==', scopeId))];
  } else {
    queries = [query(collection(db, 'attendance'), where('date', '==', date), where('contractorId', '==', scopeId))];
  }
  const snaps = await Promise.all(queries.map((q) => getDocs(q)));
  const map = new Map();
  snaps.forEach((snap) => snap.docs.forEach((d) => map.set(d.id, snapToDoc(d))));
  return Array.from(map.values());
}

export function subscribeAttendanceByDate(scopeId, date, callback, isSupervisor = false, supervisorId = null) {
  if (!date) { callback([]); return () => {}; }

  let queries = [];
  if (isSupervisor && supervisorId) {
    queries = [query(collection(db, 'attendance'), where('date', '==', date), where('supervisorId', '==', supervisorId), where('contractorId', '==', scopeId))];
  } else {
    queries = [query(collection(db, 'attendance'), where('date', '==', date), where('contractorId', '==', scopeId))];
  }

  const buckets = queries.map(() => new Map());

  const emit = () => {
    const merged = new Map();
    buckets.forEach((b) => b.forEach((v, k) => merged.set(k, v)));
    callback(Array.from(merged.values()));
  };

  const unsubs = queries.map((q, i) =>
    onSnapshot(q, (snap) => {
      const next = new Map();
      snap.docs.forEach((d) => next.set(d.id, snapToDoc(d)));
      buckets[i] = next;
      emit();
    }, (err) => { console.error('subscribeAttendanceByDate error', err); }),
  );

  return () => unsubs.forEach((u) => u());
}

export async function updateAttendanceStatus(id, status) {
  await updateDoc(doc(db, 'attendance', id), { status, updatedAt: serverTimestamp() });
}

export async function updateOvertimeHours(id, overtimeHours) {
  await updateDoc(doc(db, 'attendance', id), { overtimeHours: Number(overtimeHours) || 0, updatedAt: serverTimestamp() });
}

export async function updateAttendanceRemark(id, remark) {
  await updateDoc(doc(db, 'attendance', id), { remark, notes: remark, updatedAt: serverTimestamp() });
}

export async function markAttendance(scopeId, labourId, date, data, isSupervisor = false, supervisorId = null) {
  if (!labourId || !date || !scopeId) throw new Error('scopeId, labourId, and date are required');

  let query_obj;
  if (isSupervisor && supervisorId) {
    query_obj = query(collection(db, 'attendance'), where('labourId', '==', labourId), where('date', '==', date), where('supervisorId', '==', supervisorId), where('contractorId', '==', scopeId));
  } else {
    query_obj = query(collection(db, 'attendance'), where('labourId', '==', labourId), where('date', '==', date), where('contractorId', '==', scopeId));
  }

  const snap = await getDocs(query_obj);
  const existingId = snap.docs[0]?.id || null;

  let wageAtTime = Number(data.wageAtTime) || 0;
  if (!wageAtTime) {
    try {
      const labour = await getLabour(labourId);
      wageAtTime = Number(labour?.dailyWage) || 0;
    } catch (e) { /* ignore */ }
  }

  const payload = {
    labourId,
    date,
    status: data.status,
    overtimeHours: Number(data.overtimeHours) || 0,
    remark: data.remark || '',
    notes: data.remark || '',
    wageAtTime,
    siteId: data.siteId || supervisorId || scopeId,
    isSynced: true,
    syncedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  if (isSupervisor) {
    payload.supervisorId = supervisorId;
    payload.contractorId = scopeId;
  } else {
    payload.contractorId = scopeId;
  }

  if (existingId) {
    await updateDoc(doc(db, 'attendance', existingId), payload);
    return existingId;
  }
  const ref = await addDoc(collection(db, 'attendance'), payload);
  await updateDoc(ref, { id: ref.id });
  return ref.id;
}

export async function bulkMarkAttendance(scopeId, date, records, isSupervisor = false, supervisorId = null) {
  if (!scopeId || !date) throw new Error('scopeId and date are required');
  if (!records || records.length === 0) return;

  const existing = await getAttendanceByDate(scopeId, date, isSupervisor, supervisorId);
  const existingByLabour = new Map();
  existing.forEach((r) => { if (r.labourId) existingByLabour.set(r.labourId, r.id); });

  const wageMap = new Map();
  existing.forEach((r) => { if (r.wageAtTime) wageMap.set(r.labourId, r.wageAtTime); });

  const chunks = [];
  for (let i = 0; i < records.length; i += 400) chunks.push(records.slice(i, i + 400));

  for (const chunk of chunks) {
    const batch = writeBatch(db);
    for (const rec of chunk) {
      if (!rec.labourId || !rec.status) { console.warn('Skipping invalid record:', rec); continue; }

      const existingId = existingByLabour.get(rec.labourId);
      const wageAtTime = Number(rec.wageAtTime) || wageMap.get(rec.labourId) || Number(rec.dailyWage) || 0;

      const payload = {
        labourId: rec.labourId,
        date,
        status: rec.status || 'present',
        overtimeHours: Number(rec.overtimeHours) || 0,
        remark: rec.remark || '',
        notes: rec.remark || '',
        wageAtTime,
        siteId: rec.siteId || supervisorId || scopeId,
        isSynced: true,
        syncedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };

      if (isSupervisor) {
        payload.supervisorId = supervisorId;
        payload.contractorId = scopeId;
      } else {
        payload.contractorId = scopeId;
      }

      if (existingId) {
        batch.update(doc(db, 'attendance', existingId), payload);
      } else {
        const ref = doc(collection(db, 'attendance'));
        batch.set(ref, { id: ref.id, ...payload });
      }
    }
    await batch.commit();
  }
}

export async function updateAttendanceAllowances(id, { petrol = 0, lunch = 0, breakfast = 0, tea = 0, advance = 0, wageAtTime = 0 }) {
  const p = Number(petrol) || 0;
  const l = Number(lunch) || 0;
  const b = Number(breakfast) || 0;
  const t = Number(tea) || 0;
  const adv = Number(advance) || 0;
  const wage = Number(wageAtTime) || 0;
  const totalAllowance = p + l + b + t;
  const grandTotal = wage + totalAllowance - adv;
  await updateDoc(doc(db, 'attendance', id), {
    allowances: { petrol: p, lunch: l, breakfast: b, tea: t },
    petrol: p,
    lunch: l,
    breakfast: b,
    tea: t,
    advance: adv,
    totalAllowance,
    grandTotal,
    updatedAt: serverTimestamp(),
  });
}

export async function getAttendanceRange(scopeId, startDate, endDate, labourId, isSupervisor = false, supervisorId = null) {
  if (!startDate || !endDate) return [];
  const base = [where('date', '>=', startDate), where('date', '<=', endDate)];
  if (labourId) base.push(where('labourId', '==', labourId));

  let queries = [];
  if (isSupervisor && supervisorId) {
    base.push(where('supervisorId', '==', supervisorId));
    base.push(where('contractorId', '==', scopeId));
    queries = [query(collection(db, 'attendance'), ...base)];
  } else {
    base.push(where('contractorId', '==', scopeId));
    queries = [query(collection(db, 'attendance'), ...base)];
  }

  const snaps = await Promise.all(queries.map((q) => getDocs(q)));
  const map = new Map();
  snaps.forEach((snap) => snap.docs.forEach((d) => map.set(d.id, snapToDoc(d))));
  return Array.from(map.values());
}
