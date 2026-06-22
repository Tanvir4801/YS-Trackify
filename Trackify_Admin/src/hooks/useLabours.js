import { useEffect, useState } from 'react';
import { useScopeId, useAuthStore } from '../store/authStore';
import { subscribeLabours } from '../lib/services/labours.service';

export function useLabours(options = {}) {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeId = useScopeId(); // Always query by contractorId

  const [data, setData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  const activeOnly = options.activeOnly ?? true;

  useEffect(() => {
    if (!scopeId) {
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
