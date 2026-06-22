import { collection, doc, onSnapshot, setDoc, query, orderBy, updateDoc, increment, getDocs } from 'firebase/firestore';
import { db } from '../firebase';

export function subscribeMaterialPurchases(contractorId, onData) {
  if (!contractorId) {
    onData([]);
    return () => {};
  }
  const q = query(
    collection(db, 'materialPurchases', contractorId, 'purchases'),
    orderBy('purchaseDate', 'desc')
  );
  return onSnapshot(q, (snap) => {
    onData(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
}

export function subscribeSiteExpenses(contractorId, onData) {
  if (!contractorId) {
    onData([]);
    return () => {};
  }
  const q = query(
    collection(db, 'siteExpenses', contractorId, 'expenses'),
    orderBy('date', 'desc')
  );
  return onSnapshot(q, (snap) => {
    onData(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
}

export function subscribeSuppliers(contractorId, onData) {
  if (!contractorId) {
    onData([]);
    return () => {};
  }
  const q = query(
    collection(db, 'suppliers', contractorId, 'records'),
    orderBy('name', 'asc')
  );
  return onSnapshot(q, (snap) => {
    onData(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
}

export async function addMaterialPurchase(contractorId, data) {
  const collectionRef = collection(db, 'materialPurchases', contractorId, 'purchases');
  const docRef = doc(collectionRef);
  const id = docRef.id;
  await setDoc(docRef, { ...data, id, contractorId });

  if (data.supplierId) {
    const supplierRef = doc(db, 'suppliers', contractorId, 'records', data.supplierId);
    await updateDoc(supplierRef, {
      totalPurchases: increment(data.totalAmount || 0)
    }).catch(e => console.error("Failed to update supplier total", e));
  }
}

export async function addSiteExpense(contractorId, data) {
  const collectionRef = collection(db, 'siteExpenses', contractorId, 'expenses');
  const docRef = doc(collectionRef);
  const id = docRef.id;
  await setDoc(docRef, { ...data, id, contractorId });
}

export async function updateMaterialPurchase(contractorId, id, data) {
  const docRef = doc(db, 'materialPurchases', contractorId, 'purchases', id);
  await updateDoc(docRef, data);
}

export async function deleteMaterialPurchase(contractorId, id) {
  const docRef = doc(db, 'materialPurchases', contractorId, 'purchases', id);
  // Ideally, deduct from supplier total purchases here if needed, but for simplicity, we just delete.
  const { deleteDoc } = await import('firebase/firestore');
  await deleteDoc(docRef);
}

export async function updateSiteExpense(contractorId, id, data) {
  const docRef = doc(db, 'siteExpenses', contractorId, 'expenses', id);
  await updateDoc(docRef, data);
}

export async function deleteSiteExpense(contractorId, id) {
  const docRef = doc(db, 'siteExpenses', contractorId, 'expenses', id);
  const { deleteDoc } = await import('firebase/firestore');
  await deleteDoc(docRef);
}


