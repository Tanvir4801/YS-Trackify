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
  serverTimestamp,
} from 'firebase/firestore';
import { db } from '../firebase';

const SITES_COLLECTION = 'sites';

function snapToSite(snap) {
  const d = snap.data() || {};
  const da = d.defaultAllowances || {};
  return {
    id: snap.id,
    name: d.name || '',
    description: d.description || '',
    contractorId: d.contractorId || '',
    isActive: d.isActive !== false,
    createdAt: d.createdAt?.toDate?.() || null,
    defaultAllowances: {
      petrol:    Number(da.petrol    ?? 0),
      lunch:     Number(da.lunch     ?? 0),
      breakfast: Number(da.breakfast ?? 0),
      tea:       Number(da.tea       ?? 0),
    },
  };
}

const sortByName = (arr) => arr.sort((a, b) => a.name.localeCompare(b.name));

export async function getSites(contractorId) {
  if (!contractorId) return [];
  try {
    const q = query(
      collection(db, SITES_COLLECTION),
      where('contractorId', '==', contractorId),
      where('isActive', '==', true),
    );
    const snap = await getDocs(q);
    return sortByName(snap.docs.map(snapToSite));
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
  );
  return onSnapshot(
    q,
    (snap) => callback(sortByName(snap.docs.map(snapToSite))),
    (e) => { console.error('subscribeSites error:', e); callback([]); },
  );
}

export async function addSite(contractorId, name, description = '', defaultAllowances = {}) {
  const da = {
    petrol:    Number(defaultAllowances.petrol    ?? 0),
    lunch:     Number(defaultAllowances.lunch     ?? 0),
    breakfast: Number(defaultAllowances.breakfast ?? 0),
    tea:       Number(defaultAllowances.tea       ?? 0),
  };
  const docRef = await addDoc(collection(db, SITES_COLLECTION), {
    contractorId,
    name: name.trim(),
    description: description.trim(),
    isActive: true,
    createdAt: serverTimestamp(),
    defaultAllowances: da,
  });
  await updateDoc(docRef, { id: docRef.id });
  return { id: docRef.id, name: name.trim(), description: description.trim(), contractorId, isActive: true, defaultAllowances: da };
}

export async function updateSite(siteId, patch) {
  await updateDoc(doc(db, SITES_COLLECTION, siteId), { ...patch });
}

export async function deleteSite(siteId) {
  await updateDoc(doc(db, SITES_COLLECTION, siteId), { isActive: false });
}
