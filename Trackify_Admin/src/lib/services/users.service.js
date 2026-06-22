import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  query,
  where,
  orderBy,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from '../firebase';

// ─────────────────────────────────────────────
// HELPER
// ─────────────────────────────────────────────
function snapToDoc(snap) {
  return { id: snap.id, ...snap.data() };
}

// ─────────────────────────────────────────────
// GET SINGLE USER PROFILE
// ─────────────────────────────────────────────
export async function getUserProfile(uid) {
  const snap = await getDoc(doc(db, 'users', uid));
  if (!snap.exists()) return null;
  return snapToDoc(snap);
}

// ─────────────────────────────────────────────
// GET ALL USERS FOR A CONTRACTOR
// ─────────────────────────────────────────────
export async function getUsers(scopeId, options = {}) {
  try {
    const constraints = [];

    if (scopeId) {
      constraints.push(where('contractorId', '==', scopeId));
    }

    if (options.role) {
      constraints.push(where('role', '==', options.role));
    }

    if (options.activeOnly) {
      constraints.push(where('isActive', '==', true));
    }

    // TEMP REMOVE ORDERBY
    // constraints.push(orderBy('name'));

    const q = query(collection(db, 'users'), ...constraints);

    const snap = await getDocs(q);

    console.log("Users found:", snap.size);

    const result = snap.docs.map((d) => ({
      id: d.id,
      ...d.data(),
    }));

    return result.sort((a, b) =>
      (a.name || '').localeCompare(b.name || '')
    );

  } catch (error) {
    console.error("getUsers ERROR:", error);
    throw error;
  }
}
// ─────────────────────────────────────────────
// GET SUPERVISORS — fixed map call
// ─────────────────────────────────────────────
export async function getSupervisors(scopeId) {
  console.log('getSupervisors called with scopeId:', scopeId); // debug

  const constraints = [
    where('role', '==', 'supervisor'),
    where('isActive', '==', true),
  ];

  if (scopeId) {
    constraints.push(where('contractorId', '==', scopeId));
  }

  constraints.push(orderBy('name'));

  try {
    const snap = await getDocs(
      query(collection(db, 'users'), ...constraints),
    );

    console.log('supervisors found:', snap.size); // debug

    // FIX: was snap.docs.map(snapToDoc) — that passes the function
    // as a callback correctly BUT snap.docs.map is not a function
    // because of the markdown link corruption in the original file
    // Correct form:
    const result = snap.docs.map((d) => snapToDoc(d));
    console.log('supervisors result:', result); // debug
    return result;

  } catch (error) {
    console.error('getSupervisors error:', error);

    // If composite index missing — retry without orderBy
    if (error.code === 'failed-precondition') {
      console.warn('Index missing — retrying without orderBy');
      const constraints2 = [
        where('role', '==', 'supervisor'),
        where('isActive', '==', true),
      ];
      if (scopeId) constraints2.push(where('contractorId', '==', scopeId));

      const snap2 = await getDocs(
        query(collection(db, 'users'), ...constraints2),
      );

      const result2 = snap2.docs.map((d) => snapToDoc(d));
      // Sort client-side since no orderBy
      return result2.sort((a, b) =>
        (a.name || '').localeCompare(b.name || ''),
      );
    }

    throw error;
  }
}

// ─────────────────────────────────────────────
// CREATE USER
// ─────────────────────────────────────────────
export async function createUser(uid, data) {
  const payload = {
    uid,
    name: data.name,
    email: data.email,
    phone: data.phone ?? '',
    role: data.role,
    contractorId: data.contractorId ?? '',
    supervisorId: data.supervisorId ?? null,
    labourId: null,
    isActive: data.isActive ?? true,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
  await setDoc(doc(db, 'users', uid), payload);
  console.log('✅ User created:', uid, data.role);
}

// ─────────────────────────────────────────────
// UPDATE USER
// ─────────────────────────────────────────────
export async function updateUser(uid, updates) {
  const payload = { ...updates, updatedAt: serverTimestamp() };
  await updateDoc(doc(db, 'users', uid), payload);
}

// ─────────────────────────────────────────────
// DEACTIVATE / ACTIVATE
// ─────────────────────────────────────────────
export async function deactivateUser(uid) {
  await updateDoc(doc(db, 'users', uid), {
    isActive: false,
    updatedAt: serverTimestamp(),
  });
}

export async function activateUser(uid) {
  await updateDoc(doc(db, 'users', uid), {
    isActive: true,
    updatedAt: serverTimestamp(),
  });
}