import {
  collection,
  addDoc,
  getDocs,
  query,
  orderBy,
  limit as fsLimit,
  serverTimestamp,
  onSnapshot,
} from 'firebase/firestore';
import { db } from '../firebase';

export async function logActivity(action, details, userId) {
  try {
    await addDoc(collection(db, 'activity_log'), {
      action,
      details,
      userId: userId || null,
      timestamp: serverTimestamp(),
    });
  } catch (_) {
    // Activity log is best-effort; never block core flows.
  }
}

export async function getRecentActivity(limitCount = 50) {
  const snap = await getDocs(
    query(
      collection(db, 'activity_log'),
      orderBy('timestamp', 'desc'),
      fsLimit(limitCount),
    ),
  );
  return snap.docs.map((d) => ({
    id: d.id,
    ...d.data(),
    timestamp: d.data().timestamp?.toDate?.() || null,
  }));
}

export function subscribeRecentActivity(limitCount = 20, callback) {
  const q = query(
    collection(db, 'activity_log'),
    orderBy('timestamp', 'desc'),
    fsLimit(limitCount),
  );
  return onSnapshot(q, (snap) => {
    callback(
      snap.docs.map((d) => ({
        id: d.id,
        ...d.data(),
        timestamp: d.data().timestamp?.toDate?.() || null,
      })),
    );
  });
}
