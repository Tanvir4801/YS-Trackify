import { collection, doc, onSnapshot, setDoc, query, orderBy, updateDoc, increment, getDocs, getDoc, deleteDoc, runTransaction } from 'firebase/firestore';
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

export function subscribeSuppliers(contractorId, onData, onError) {
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
  }, (err) => {
    // P2-4 FIX: propagate error instead of silently stalling
    console.error('subscribeSuppliers error:', err?.code, err?.message);
    if (typeof onError === 'function') {
      onError(err);
    } else {
      // Fallback: emit empty array so UI doesn't remain stuck in loading
      onData([]);
    }
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

  // P3-1 FIX: Use a Firestore transaction to safely decrement supplier totals.
  // This prevents race conditions and double-decrements.
  await runTransaction(db, async (tx) => {
    const purchaseSnap = await tx.get(docRef);
    if (!purchaseSnap.exists()) {
      // Document already deleted — nothing to do
      return;
    }

    const purchase = purchaseSnap.data();
    const amount = Number(purchase.totalAmount || purchase.amount || 0);

    // Delete the purchase
    tx.delete(docRef);

    // Decrement supplier total if applicable
    if (purchase.supplierId && amount > 0) {
      const supplierRef = doc(db, 'suppliers', contractorId, 'records', purchase.supplierId);
      const supplierSnap = await tx.get(supplierRef);
      if (supplierSnap.exists()) {
        const currentTotal = Number(supplierSnap.data().totalPurchases || 0);
        // Never allow negative totals
        const newTotal = Math.max(0, currentTotal - amount);
        tx.update(supplierRef, { totalPurchases: newTotal });
      }
      // If supplier doc doesn't exist, just delete purchase (already done above)
    }
  });
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


