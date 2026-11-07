import { useEffect, useMemo, useState } from 'react';
import { useScopeId, useAuthStore } from '../store/authStore';
import { subscribeAttendanceByDate } from '../lib/services/attendance.service';
import { useLabours } from './useLabours';
import { DEMO_ATTENDANCE } from '../lib/demoData';

export function useAttendanceByDate(date) {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeFromStore = useScopeId();
  const isSupervisor = role === 'supervisor';

  const contractorId = scopeFromStore;
  const isDemo =
    contractorId === 'trackify_demo' ||
    (typeof window !== 'undefined' && sessionStorage.getItem('trackify_demo_mode') === 'true');

  const { data: allLabours = [] } = useLabours({ activeOnly: false });
  const allowedLabourIds = useMemo(() => {
    if (!isSupervisor) return null;
    const ids = new Set();
    allLabours.forEach((l) => {
      if (l.supervisorId === uid || l.supervisorRefPath === `users/${uid}`) {
        ids.add(l.id);
      }
    });
    return ids;
  }, [isSupervisor, uid, allLabours]);

  const [records, setRecords] = useState(isDemo ? DEMO_ATTENDANCE : []);
  const [isLoading, setIsLoading] = useState(!isDemo);

  useEffect(() => {
    if (isDemo) {
      setRecords(DEMO_ATTENDANCE);
      setIsLoading(false);
      return undefined;
    }

    if (!date || !contractorId) {
      setRecords([]);
      setIsLoading(false);
      return undefined;
    }
    setIsLoading(true);

    const options = isSupervisor
      ? { isSupervisor: true, supervisorId: uid, allowedLabourIds }
      : {};

    const unsub = subscribeAttendanceByDate(
      contractorId,
      date,
      (list) => {
        setRecords(list);
        setIsLoading(false);
      },
      options
    );
    return () => unsub();
  }, [contractorId, date, isSupervisor, uid, allowedLabourIds, isDemo]);

  return { records, isLoading };
}
