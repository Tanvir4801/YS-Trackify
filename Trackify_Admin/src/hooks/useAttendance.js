import { useEffect, useState } from 'react';
import { useScopeId, useAuthStore } from '../store/authStore';
import { subscribeAttendanceByDate } from '../lib/services/attendance.service';

export function useAttendanceByDate(date) {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeFromStore = useScopeId();
  const isSupervisor = role === 'supervisor';
  
  // contractorId is always the selected contractor (scopeFromStore)
  // For supervisors: scopeFromStore is the selected contractor
  // For contractors: scopeFromStore is their own ID
  const contractorId = scopeFromStore;

  const [records, setRecords] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!date || !contractorId) {
      setRecords([]);
      setIsLoading(false);
      return undefined;
    }
    setIsLoading(true);
    const unsub = subscribeAttendanceByDate(contractorId, date, (list) => {
      setRecords(list);
      setIsLoading(false);
    }, isSupervisor, isSupervisor ? uid : null);
    return () => unsub();
  }, [contractorId, date, isSupervisor, uid]);

  return { records, isLoading };
}
