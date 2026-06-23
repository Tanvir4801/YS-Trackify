import {
  collection,
  doc,
  addDoc,
  updateDoc,
  getDocs,
  onSnapshot,
  query,
  where,
  orderBy,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { db } from '../firebase';

function snapToDoc(snap) {
  const data = snap.data() || {};
  return {
    id: snap.id,
    ...data,
    amount: Number(data.amount) || 0,
    date: data.date?.toDate?.() || null,
    updatedAt: data.updatedAt?.toDate?.() || null,
  };
}

function buildBaseConstraints(options) {
  const constraints = [];
  if (options.labourId) constraints.push(where('labourId', '==', options.labourId));
  if (options.type) constraints.push(where('type', '==', options.type));
  if (options.startDate) {
    constraints.push(where('date', '>=', Timestamp.fromDate(new Date(options.startDate))));
  }
  if (options.endDate) {
    const end = new Date(options.endDate);
    end.setHours(23, 59, 59, 999);
    constraints.push(where('date', '<=', Timestamp.fromDate(end)));
  }
  return constraints;
}

function applyClientFilters(items, options = {}) {
  const start = options.startDate ? new Date(options.startDate).getTime() : null;
  const end = options.endDate
    ? new Date(new Date(options.endDate).setHours(23, 59, 59, 999)).getTime()
    : null;

  return items.filter((item) => {
    if (options.labourId && item.labourId !== options.labourId) return false;
    if (options.type && item.type !== options.type) return false;

    const time = item.date?.getTime?.();
    if (start !== null && (typeof time !== 'number' || time < start)) return false;
    if (end !== null && (typeof time !== 'number' || time > end)) return false;

    return true;
  });
}


export async function getPayments(scopeId, options = {}) {
  // ⚠️ Only query by contractorId — supervisorId queries return docs with
  // different contractorId values which causes permission-denied.
  try {
    const constraints = scopeId
      ? [where('contractorId', '==', scopeId)]
      : [];
    const snap = await getDocs(query(collection(db, 'payments'), ...constraints));
    const rows = applyClientFilters(snap.docs.map(snapToDoc), options);
    return rows.sort((a, b) => (b.date?.getTime?.() || 0) - (a.date?.getTime?.() || 0));
  } catch (error) {
    if (error?.code === 'permission-denied') return [];
    throw error;
  }
}

export function subscribePayments(scopeId, callback, options = {}) {
  const constraints = scopeId
    ? [where('contractorId', '==', scopeId)]
    : [];
  const q = query(collection(db, 'payments'), ...constraints);

  return onSnapshot(q, (snap) => {
    const rows = applyClientFilters(snap.docs.map(snapToDoc), options);
    rows.sort((a, b) => (b.date?.getTime?.() || 0) - (a.date?.getTime?.() || 0));
    callback(rows);
  }, (err) => {
    console.error('❌ subscribePayments error:', err);
    callback([]);
  });
}

export async function addPayment(data) {
  if (!data.scopeId) throw new Error('scopeId is required');
  if (!data.labourId) throw new Error('labourId is required');
  if (!data.type) throw new Error('type is required');
  if (!data.date) throw new Error('date is required');

  const dateValue =
    data.date instanceof Date ? data.date : new Date(data.date);
  if (Number.isNaN(dateValue.getTime())) throw new Error('Invalid date');

  const payload = {
    labourId: data.labourId,
    supervisorId: data.scopeId,
    contractorId: data.scopeId,
    type: data.type,
    amount: Number(data.amount) || 0,
    date: Timestamp.fromDate(dateValue),
    notes: data.notes ?? '',
    paymentMethod: data.paymentMethod || 'cash',
    isSynced: true,
    updatedAt: serverTimestamp(),
  };

  const ref = await addDoc(collection(db, 'payments'), payload);
  await updateDoc(ref, { id: ref.id });
  return ref.id;
}

export async function updatePayment(paymentId, updates) {
  const payload = { ...updates, updatedAt: serverTimestamp() };
  if (payload.amount !== undefined) payload.amount = Number(payload.amount) || 0;
  if (payload.date && !(payload.date instanceof Timestamp)) {
    payload.date = Timestamp.fromDate(
      payload.date instanceof Date ? payload.date : new Date(payload.date),
    );
  }
  await updateDoc(doc(db, 'payments', paymentId), payload);
}
