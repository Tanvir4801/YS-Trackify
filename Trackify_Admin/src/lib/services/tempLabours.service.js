import { db } from '../firebase';
import { collection, doc, setDoc, query, where, getDocs, deleteDoc, onSnapshot, orderBy } from 'firebase/firestore';

const COLLECTION_NAME = 'temp_labour_entries';

export function subscribeTempLabours(contractorId, onData) {
  if (!contractorId) {
    onData([]);
    return () => {};
  }
  const q = query(
    collection(db, COLLECTION_NAME),
    where('contractorId', '==', contractorId)
  );
  return onSnapshot(q, (snap) => {
    onData(snap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate() || new Date()
    })));
  });
}

export async function getTempLaboursByDate(contractorId, date) {
  if (
    contractorId === 'trackify_demo' ||
    (typeof window !== 'undefined' && sessionStorage.getItem('trackify_demo_mode') === 'true')
  ) {
    return [];
  }
  const constraints = [
    where('contractorId', '==', contractorId),
    where('date', '==', date)
  ];
  
  const q = query(collection(db, COLLECTION_NAME), ...constraints);
  const snap = await getDocs(q);
  
  return snap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
    createdAt: doc.data().createdAt?.toDate() || new Date()
  }));
}

export async function addTempLabourEntry(data) {
  const entryId = crypto.randomUUID();
  
  const wage = Number(data.wage) || 0;
  const attendanceUnit = Number(data.attendanceUnit) || 1.0;
  const totalWage = wage * attendanceUnit;
  const paidAmount = Number(data.paidAmount) || 0;
  const remainingAmount = totalWage - paidAmount;
  
  let paymentStatus = 'unpaid';
  if (paidAmount > 0) {
    paymentStatus = remainingAmount <= 0 ? 'paid' : 'partial_paid';
  }

  const entry = {
    contractorId: data.contractorId,
    supervisorId: data.supervisorId,
    siteId: data.siteId,
    date: data.date,
    name: data.name,
    wage: wage,
    attendanceUnit: attendanceUnit,
    remarks: data.remarks || '',
    totalWage,
    paidAmount,
    remainingAmount,
    paymentStatus,
    paymentDate: paidAmount > 0 ? (data.paymentDate || new Date().toISOString().split('T')[0]) : null,
    paymentTime: paidAmount > 0 ? (data.paymentTime || new Date().toISOString().split('T')[1].split('.')[0]) : '',
    paymentMethod: data.paymentMethod || '',
    paidBy: data.paidBy || '',
    paymentRemark: data.paymentRemark || '',
    phone: data.phone || '',
    village: data.village || '',
    createdAt: new Date()
  };

  await setDoc(doc(db, COLLECTION_NAME, entryId), entry);
  return { id: entryId, ...entry };
}

export async function updateTempLabourEntry(entryId, patch) {
  await setDoc(doc(db, COLLECTION_NAME, entryId), patch, { merge: true });
}

export async function bulkUpdateTempLabourPayments(entryIds, paymentData) {
  const batch = [];
  const { writeBatch } = await import('firebase/firestore');
  const firestoreBatch = writeBatch(db);
  
  for (const id of entryIds) {
    const docRef = doc(db, COLLECTION_NAME, id);
    firestoreBatch.update(docRef, paymentData);
  }
  
  await firestoreBatch.commit();
}

export async function deleteTempLabourEntry(entryId) {
  await deleteDoc(doc(db, COLLECTION_NAME, entryId));
}

// Used for Reports
// P2-5 FIX: Use server-side Firestore date range filtering instead of downloading
// all entries and filtering client-side. Date is stored as YYYY-MM-DD string,
// so lexicographic comparisons work correctly.
// Requires composite index: temp_labour_entries (contractorId ASC, date ASC) — see firestore.indexes.json.
export async function getTempLaboursByDateRange(contractorId, startDate, endDate) {
  if (!contractorId) return [];
  if (
    contractorId === 'trackify_demo' ||
    (typeof window !== 'undefined' && sessionStorage.getItem('trackify_demo_mode') === 'true')
  ) {
    return [];
  }

  const q = query(
    collection(db, COLLECTION_NAME),
    where('contractorId', '==', contractorId),
    where('date', '>=', startDate),
    where('date', '<=', endDate),
  );

  const snap = await getDocs(q);
  return snap.docs.map(d => ({
    id: d.id,
    ...d.data(),
    createdAt: d.data().createdAt?.toDate?.() || new Date(),
  }));
}
