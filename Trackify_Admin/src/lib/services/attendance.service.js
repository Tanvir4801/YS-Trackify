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

// ── Shared status config ─────────────────────────────────────────────────────
// Single source of truth for all attendance status labels and badge colors.
export const ATTENDANCE_STATUS_CONFIG = {
  present: { label: 'Present', color: 'bg-green-100 text-green-700', wageMultiplier: 1 },
  three_quarter: { label: '3/4 Day', color: 'bg-teal-100 text-teal-700', wageMultiplier: 0.75 },
  half: { label: 'Half day', color: 'bg-amber-100 text-amber-700', wageMultiplier: 0.5 },
  quarter: { label: '1/4 Day', color: 'bg-orange-100 text-orange-700', wageMultiplier: 0.25 },
  absent: { label: 'Absent', color: 'bg-red-100 text-red-700', wageMultiplier: 0 },
  pending: { label: 'Pending', color: 'bg-slate-100 text-slate-500', wageMultiplier: 0 },
};

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
  const petrol = Number(al.petrol ?? data.petrol ?? 0) || 0;
  const lunch = Number(al.lunch ?? data.lunch ?? 0) || 0;
  const breakfast = Number(al.breakfast ?? data.breakfast ?? 0) || 0;
  const tea = Number(al.tea ?? data.tea ?? 0) || 0;
  const advance = Number(data.advance ?? 0) || 0;
  const wageAtTime = Number(data.wageAtTime) || 0;

  return {
    id: snap.id,
    ...data,
    overtimeHours: Number(data.overtimeHours) || 0,
    wageAtTime,
    remark: data.remark || data.notes || '',

    // Real production docs do not have siteId/supervisorId reliably.
    // Keep it blank so UI never depends on missing fields.
    siteId: data.siteId || '',

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

function nestedSnapToDoc(snap, date) {
  const data = snap.data() || {};
  const labourId = data.labourId || snap.id;

  const al = (typeof data.allowances === 'object' && data.allowances) ? data.allowances : {};
  const petrol = Number(al.petrol ?? data.petrol ?? 0) || 0;
  const lunch = Number(al.lunch ?? data.lunch ?? 0) || 0;
  const breakfast = Number(al.breakfast ?? data.breakfast ?? 0) || 0;
  const tea = Number(al.tea ?? data.tea ?? 0) || 0;
  const advance = Number(data.advance ?? 0) || 0;
  const wageAtTime = Number(data.wageAtTime) || 0;

  return {
    id: data.siteId ? `${labourId}_${date}_${data.siteId}` : `${labourId}_${date}`,
    ...data,
    labourId,
    date: date || data.date || '',
    overtimeHours: Number(data.overtimeHours) || 0,
    wageAtTime,
    remark: data.remark || data.notes || '',

    // Do NOT derive siteId from supervisorId.
    siteId: data.siteId || '',

    syncedAt: data.syncedAt?.toDate?.() || null,
    markedVia: data.markedVia || '',
    petrol,
    lunch,
    breakfast,
    tea,
    advance,
    totalAllowance: petrol + lunch + breakfast + tea,
    grandTotal: wageAtTime + petrol + lunch + breakfast + tea - advance,
  };
}

// Merge: flat records (richer) override nested.
function mergeFlatAndNested(flatDocs, nestedDocs) {
  const merged = new Map();
  nestedDocs.forEach((r) => {
    if (r?.labourId) {
      const key = `${r.labourId}_${r.siteId || ''}`;
      merged.set(key, r);
    }
  });
  flatDocs.forEach((r) => {
    if (r?.labourId) {
      const key = `${r.labourId}_${r.siteId || ''}`;
      merged.set(key, r);
    }
  });
  return Array.from(merged.values());
}

// ── getAttendanceByDate ─────────────────────────────────────────────────────

export async function getAttendanceByDate(scopeId, date) {
  if (!date || !scopeId) return [];

  const flatQ = query(
    collection(db, 'attendance'),
    where('date', '==', date),
    where('contractorId', '==', scopeId)
  );

  const [flatSnap, nestedSnap] = await Promise.all([
    getDocs(flatQ),
    getDocs(nestedRecordsCol(scopeId, date)).catch(() => ({ docs: [] })),
  ]);

  return mergeFlatAndNested(
    flatSnap.docs.map(snapToDoc),
    nestedSnap.docs.map((d) => nestedSnapToDoc(d, date)),
  );
}

// ── subscribeAttendanceByDate ───────────────────────────────────────────────

export function subscribeAttendanceByDate(scopeId, date, callback) {
  if (!date || !scopeId) {
    callback([]);
    return () => {};
  }

  const flatQ = query(
    collection(db, 'attendance'),
    where('date', '==', date),
    where('contractorId', '==', scopeId)
  );

  let flatDocs = [];
  let nestedDocs = [];

  const emit = () => callback(mergeFlatAndNested(flatDocs, nestedDocs));

  const unsub1 = onSnapshot(flatQ, (snap) => {
    flatDocs = snap.docs.map(snapToDoc);
    emit();
  }, (err) => {
    console.error('subscribeAttendanceByDate flat error:', err);
  });

  const unsub2 = onSnapshot(nestedRecordsCol(scopeId, date), (snap) => {
    nestedDocs = snap.docs.map((d) => nestedSnapToDoc(d, date));
    emit();
  }, (err) => {
    console.error('subscribeAttendanceByDate nested error:', err);
  });

  return () => {
    unsub1();
    unsub2();
  };
}

// ── updateAttendanceStatus ──────────────────────────────────────────────────

export async function updateAttendanceStatus(id, status) {
  await updateDoc(doc(db, 'attendance', id), { status, updatedAt: serverTimestamp() });
}

// ── markAsPending ───────────────────────────────────────────────────────────

export async function markAsPending(contractorId, labourId, date, { siteId = null, pendingReason = 'admin_reset' } = {}) {
  if (!contractorId || !labourId || !date) {
    throw new Error('contractorId, labourId, and date are required');
  }

  const qParts = [
    where('labourId', '==', labourId),
    where('date', '==', date),
    where('contractorId', '==', contractorId)
  ];
  if (siteId) {
    qParts.push(where('siteId', '==', siteId));
  }

  const flatQ = query(collection(db, 'attendance'), ...qParts);

  const snap = await getDocs(flatQ);
  if (snap.empty) return null;

  const flatDoc = snap.docs[0];
  const flatId = flatDoc.id;

  await updateDoc(doc(db, 'attendance', flatId), {
    status: 'pending',
    pendingReason,
    updatedAt: serverTimestamp(),
  });

  // Mirror to nested path
  try {
    const nestedDocId = siteId ? `${labourId}_${siteId}` : labourId;
    await updateDoc(nestedRecordDoc(contractorId, date, nestedDocId), {
      status: 'pending',
      pendingReason,
      lastModifiedVia: 'admin_manual',
      lastModifiedAt: serverTimestamp(),
    });
  } catch (e) {
    console.warn('markAsPending nested update skipped (doc may not exist):', e?.code);
  }

  return flatId;
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
    remark,
    notes: remark,
    updatedAt: serverTimestamp(),
  });

  if (contractorId && date && labourId) {
    try {
      await updateDoc(nestedRecordDoc(contractorId, date, labourId), {
        remark,
        updatedAt: serverTimestamp(),
      });
    } catch (e) {
      console.warn('updateAttendanceRemark nested update skipped:', e?.code);
    }
  }
}

// ── markAttendance ──────────────────────────────────────────────────────────


export async function markAttendance(scopeId, labourId, date, data) {
  if (!labourId || !date || !scopeId) throw new Error('scopeId, labourId, and date are required');

  let q_obj;
  if (data.siteId) {
    q_obj = query(
      collection(db, 'attendance'),
      where('labourId', '==', labourId),
      where('date', '==', date),
      where('contractorId', '==', scopeId),
      where('siteId', '==', data.siteId)
    );
  } else {
    q_obj = query(
      collection(db, 'attendance'),
      where('labourId', '==', labourId),
      where('date', '==', date),
      where('contractorId', '==', scopeId)
    );
  }

  const snap = await getDocs(q_obj);
  const existingId = snap.docs[0]?.id || null;

  let wageAtTime = Number(data.wageAtTime) || 0;
  if (!wageAtTime) {
    try {
      wageAtTime = Number((await getLabour(labourId))?.dailyWage) || 0;
    } catch (_) {}
  }

  let shiftFactor = 0.0;
  if (data.status === 'present') shiftFactor = 1.0;
  else if (data.status === 'three_quarter') shiftFactor = 0.75;
  else if (data.status === 'half') shiftFactor = 0.5;
  else if (data.status === 'quarter') shiftFactor = 0.25;

  const payload = {
    labourId,
    date,
    status: data.status,
    shiftFactor: shiftFactor,
    overtimeHours: Number(data.overtimeHours) || 0,
    remark: data.remark || '',
    notes: data.remark || '',
    wageAtTime,

    contractorId: scopeId,

    markedVia: 'admin_manual',
    isSynced: true,
    syncedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  if (data.siteId) {
    payload.siteId = data.siteId;
  }

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
    const nestedPayload = {
      labourId,
      date,
      contractorId: scopeId,
      status: data.status,
      shiftFactor: shiftFactor,
      overtimeHours: Number(data.overtimeHours) || 0,
      remark: data.remark || '',
      wageAtTime,
      markedVia: 'admin_manual',
      markedAt: serverTimestamp(),
      lastModifiedVia: 'admin_manual',
      lastModifiedAt: serverTimestamp(),
      legacyId: flatId,
    };
    if (data.siteId) {
      nestedPayload.siteId = data.siteId;
    }
    const nestedDocId = data.siteId ? `${labourId}_${data.siteId}` : labourId;
    await setDoc(nestedRecordDoc(scopeId, date, nestedDocId), nestedPayload, { merge: true });

    await setDoc(dateSentinelDoc(scopeId, date), {
      date,
      contractorId: scopeId,
      updatedAt: serverTimestamp(),
    }, { merge: true });
  } catch (e) {
    console.error('markAttendance nested write failed:', e);
  }

  return flatId;
}

// ── bulkMarkAttendance ──────────────────────────────────────────────────────

export async function bulkMarkAttendance(scopeId, date, records) {
  if (!scopeId || !date) throw new Error('scopeId and date are required');
  if (!records || records.length === 0) return;

  const existing = await getAttendanceByDate(scopeId, date);
  const existingByLabourAndSite = new Map();
  existing.forEach((r) => {
    if (r?.labourId) {
      existingByLabourAndSite.set(`${r.labourId}_${r.siteId || ''}`, r.id);
    }
  });

  const wageMap = new Map();
  existing.forEach((r) => {
    if (r?.wageAtTime) wageMap.set(r.labourId, r.wageAtTime);
  });

  const CHUNK = 200;
  const chunks = [];
  for (let i = 0; i < records.length; i += CHUNK) chunks.push(records.slice(i, i + CHUNK));

  for (const chunk of chunks) {
    const batch = writeBatch(db);

    for (const rec of chunk) {
      if (!rec?.labourId || !rec?.status) {
        console.warn('Skipping invalid record:', rec);
        continue;
      }

      const existingId = existingByLabourAndSite.get(`${rec.labourId}_${rec.siteId || ''}`);
      const wageAtTime = Number(rec.wageAtTime) || wageMap.get(rec.labourId) || Number(rec.dailyWage) || 0;

      const st = rec.status || 'present';
      let shiftFactor = 0.0;
      if (st === 'present') shiftFactor = 1.0;
      else if (st === 'three_quarter') shiftFactor = 0.75;
      else if (st === 'half') shiftFactor = 0.5;
      else if (st === 'quarter') shiftFactor = 0.25;

      const payload = {
        labourId: rec.labourId,
        date,
        status: st,
        shiftFactor,
        overtimeHours: Number(rec.overtimeHours) || 0,
        remark: rec.remark || '',
        notes: rec.remark || '',
        wageAtTime,
        contractorId: scopeId,

        markedVia: 'admin_manual',
        isSynced: true,
        syncedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };
      if (rec.siteId) {
        payload.siteId = rec.siteId;
      }

      let flatId;
      if (existingId) {
        flatId = existingId;
        batch.update(doc(db, 'attendance', existingId), payload);
      } else {
        flatId = rec.siteId ? `${rec.labourId}_${date}_${rec.siteId}` : `${rec.labourId}_${date}`;
        const flatRef = doc(db, 'attendance', flatId);
        batch.set(flatRef, { id: flatId, ...payload });
      }

      const nestedPayload = {
        labourId: rec.labourId,
        date,
        contractorId: scopeId,
        status: st,
        shiftFactor,
        overtimeHours: Number(rec.overtimeHours) || 0,
        remark: rec.remark || '',
        wageAtTime,
        markedVia: 'admin_manual',
        markedAt: serverTimestamp(),
        lastModifiedVia: 'admin_manual',
        lastModifiedAt: serverTimestamp(),
        legacyId: flatId,
      };
      if (rec.siteId) {
        nestedPayload.siteId = rec.siteId;
      }

      const nestedDocId = rec.siteId ? `${rec.labourId}_${rec.siteId}` : rec.labourId;
      batch.set(nestedRecordDoc(scopeId, date, nestedDocId), nestedPayload, { merge: true });
    }

    batch.set(dateSentinelDoc(scopeId, date), {
      date,
      contractorId: scopeId,
      updatedAt: serverTimestamp(),
    }, { merge: true });

    await batch.commit();
  }
}

// ── updateAttendanceAllowances ──────────────────────────────────────────────

export async function updateAttendanceAllowances(id, {
  petrol = 0,
  lunch = 0,
  breakfast = 0,
  tea = 0,
  advance = 0,
  wageAtTime = 0,
  contractorId = null,
  date = null,
  labourId = null,
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
    petrol: p,
    lunch: l,
    breakfast: b,
    tea: t,
    advance: adv,
    totalAllowance,
    grandTotal,
    updatedAt: serverTimestamp(),
  };

  await updateDoc(doc(db, 'attendance', id), allowancePayload);

  if (contractorId && date && labourId) {
    try {
      await updateDoc(nestedRecordDoc(contractorId, date, labourId), {
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
    } catch (e) {
      console.warn('updateAttendanceAllowances nested update skipped:', e?.code);
    }
  }
}

// ── getAttendanceRange ──────────────────────────────────────────────────────

export async function getAttendanceRange(scopeId, startDate, endDate, labourId) {
  if (!startDate || !endDate || !scopeId) return [];

  // IMPORTANT:
  // Firestore must filter by date; doing it only in JS can cause stale/partial results
  // (especially when deletes happen concurrently).
  // We use lexicographic comparisons because your date keys are YYYY-MM-DD.

  const qParts = [
    where('contractorId', '==', scopeId),
    where('date', '>=', startDate),
    where('date', '<=', endDate),
  ];

  if (labourId) {
    qParts.push(where('labourId', '==', labourId));
  }

  const snap = await getDocs(query(collection(db, 'attendance'), ...qParts));

  const map = new Map();
  snap.docs.forEach((d) => {
    const rec = snapToDoc(d);
    if (!rec?.labourId || !rec?.date) return;
    // Still keep a defensive filter in case of unexpected formats.
    if (rec.date < startDate || rec.date > endDate) return;
    map.set(`${rec.labourId}_${rec.date}`, rec);
  });

  return Array.from(map.values());
}


