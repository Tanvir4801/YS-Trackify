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
export async function getTempLaboursByDateRange(contractorId, startDate, endDate) {
  // We filter in-memory for date range to avoid missing index errors for now
  const q = query(
    collection(db, COLLECTION_NAME), 
    where('contractorId', '==', contractorId)
  );
  
  const snap = await getDocs(q);
  
  const start = new Date(startDate);
  const end = new Date(endDate);
  start.setHours(0,0,0,0);
  end.setHours(23,59,59,999);
  
  return snap.docs.map(doc => {
    const data = doc.data();
    return { id: doc.id, ...data };
  }).filter(entry => {
    const entryDate = new Date(entry.date);
    return entryDate >= start && entryDate <= end;
  });
}
