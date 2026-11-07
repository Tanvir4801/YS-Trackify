import { useEffect, useState } from 'react';
import { useScopeId, useAuthStore } from '../store/authStore';
import { subscribeLabours } from '../lib/services/labours.service';
import { DEMO_LABOURS } from '../lib/demoData';

export function useLabours(options = {}) {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeId = useScopeId(); // Always query by contractorId

  const isDemo =
    scopeId === 'trackify_demo' ||
    (typeof window !== 'undefined' && sessionStorage.getItem('trackify_demo_mode') === 'true');

  const [data, setData] = useState(isDemo ? DEMO_LABOURS : []);
  const [isLoading, setIsLoading] = useState(!isDemo);
  const [error, setError] = useState(null);

  const activeOnly = options.activeOnly ?? true;

  useEffect(() => {
    if (isDemo) {
      setData(DEMO_LABOURS);
      setIsLoading(false);
      setError(null);
      return undefined;
    }

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
  }, [scopeId, activeOnly, role, uid, isDemo]);

  return { data, isLoading, error };
}
