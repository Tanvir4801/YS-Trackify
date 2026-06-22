import { useEffect, useState } from 'react';
import { useScopeId, useAuthStore } from '../store/authStore';
import { subscribeLabours } from '../lib/services/labours.service';

export function useLabours(options = {}) {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeFromStore = useScopeId();
  // Supervisors always see only their own labours regardless of selection.
  const scopeId = role === 'supervisor' ? uid : scopeFromStore;

  const [data, setData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  const activeOnly = options.activeOnly ?? true;

  useEffect(() => {
    if (role === 'supervisor' && !uid) {
      setData([]);
      setIsLoading(false);
      return undefined;
    }
    setIsLoading(true);
    setError(null);
    const unsub = subscribeLabours(
      scopeId,
      (list) => {
        setData(list);
        setIsLoading(false);
      },
      { activeOnly },
    );
    return () => unsub();
  }, [scopeId, activeOnly, role, uid]);

  return { data, isLoading, error };
}
