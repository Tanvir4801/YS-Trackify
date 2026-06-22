import {
  collection,
  doc,
  addDoc,
  updateDoc,
  deleteDoc,
  getDocs,
  onSnapshot,
  query,
  where,
  orderBy,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from '../firebase';

const SITES_COLLECTION = 'sites';

function snapToSite(snap) {
  const d = snap.data() || {};
  return {
    id: snap.id,
    name: d.name || '',
    description: d.description || '',
    contractorId: d.contractorId || '',
    isActive: d.isActive !== false,
    createdAt: d.createdAt?.toDate?.() || null,
  };
}

export async function getSites(contractorId) {
  if (!contractorId) return [];
  try {
    const q = query(
      collection(db, SITES_COLLECTION),
      where('contractorId', '==', contractorId),
      where('isActive', '==', true),
      orderBy('name'),
    );
    const snap = await getDocs(q);
    return snap.docs.map(snapToSite);
  } catch (e) {
    console.error('getSites error:', e);
    return [];
  }
}

export function subscribeSites(contractorId, callback) {
  if (!contractorId) { callback([]); return () => {}; }
  const q = query(
    collection(db, SITES_COLLECTION),
    where('contractorId', '==', contractorId),
    where('isActive', '==', true),
    orderBy('name'),
  );
  return onSnapshot(q, (snap) => callback(snap.docs.map(snapToSite)), (e) => {
    console.error('subscribeSites error:', e);
    callback([]);
  });
}

export async function addSite(contractorId, name, description = '') {
  const docRef = await addDoc(collection(db, SITES_COLLECTION), {
    contractorId,
    name: name.trim(),
    description: description.trim(),
    isActive: true,
    createdAt: serverTimestamp(),
  });
  await updateDoc(docRef, { id: docRef.id });
  return { id: docRef.id, name: name.trim(), description: description.trim(), contractorId, isActive: true };
}

export async function updateSite(siteId, patch) {
  await updateDoc(doc(db, SITES_COLLECTION, siteId), { ...patch });
}

export async function deleteSite(siteId) {
  await updateDoc(doc(db, SITES_COLLECTION, siteId), { isActive: false });
}
