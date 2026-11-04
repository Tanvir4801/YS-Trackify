import { useEffect, useMemo, useState } from 'react';
import { useScopeId, useAuthStore } from '../store/authStore';
import { subscribeAttendanceByDate } from '../lib/services/attendance.service';
import { useLabours } from './useLabours';

export function useAttendanceByDate(date) {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeFromStore = useScopeId();
  const isSupervisor = role === 'supervisor';

  // contractorId is always the contractor tenant ID
  const contractorId = scopeFromStore;

  // P1-1 FIX: Pre-fetch the supervisor's allowed labour IDs so the service can
  // do proper data-layer filtering without extra Firestore queries on every emit.
  const { data: allLabours = [] } = useLabours({ activeOnly: false });
  const allowedLabourIds = useMemo(() => {
    if (!isSupervisor) return null;
    const ids = new Set();
    allLabours.forEach((l) => {
      if (
        l.supervisorId === uid ||
        l.supervisorRefPath === `users/${uid}`
      ) {
        ids.add(l.id);
      }
    });
    return ids;
  }, [isSupervisor, uid, allLabours]);

  const [records, setRecords] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!date || !contractorId) {
      setRecords([]);
      setIsLoading(false);
      return undefined;
    }
    setIsLoading(true);

    const options = isSupervisor
      ? { isSupervisor: true, supervisorId: uid, allowedLabourIds }
      : {};

    const unsub = subscribeAttendanceByDate(contractorId, date, (list) => {
      setRecords(list);
      setIsLoading(false);
    }, options);
    return () => unsub();
  }, [contractorId, date, isSupervisor, uid, allowedLabourIds]);

  return { records, isLoading };
}
