import {
  collection,
  query,
  where,
  onSnapshot,
  updateDoc,
  doc,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from '../firebase';

const COL = 'attendanceSessions';

/**
 * Subscribe to all sessions for a contractorId on a given date.
 * callback receives an array of session objects with id field.
 */
export function subscribeSessionsForDate(contractorId, date, callback) {
  if (!contractorId || !date) {
    callback([]);
    return () => {};
  }
  const q = query(
    collection(db, COL),
    where('contractorId', '==', contractorId),
    where('date', '==', date),
  );
  return onSnapshot(q, (snap) => {
    const sessions = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    callback(sessions);
  }, () => callback([]));
}

/**
 * Force-end an abandoned/active session (admin use).
 */
export async function forceEndSession(sessionId) {
  await updateDoc(doc(db, COL, sessionId), {
    status: 'completed',
    endedAt: serverTimestamp(),
  });
}
