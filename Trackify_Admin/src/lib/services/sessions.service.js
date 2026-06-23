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

/**
 * Sessions are stored at:
 *   attendance/{contractorId}/sessions/{sessionId}
 *
 * This reuses the existing Firestore wildcard rule
 *   match /attendance/{contractorId}/{rest=**}
 * so no new security rules are needed.
 */
function sessionsCol(contractorId) {
  return collection(db, 'attendance', contractorId, 'sessions');
}

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
    sessionsCol(contractorId),
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
export async function forceEndSession(contractorId, sessionId) {
  await updateDoc(doc(db, 'attendance', contractorId, 'sessions', sessionId), {
    status: 'completed',
    endedAt: serverTimestamp(),
  });
}
