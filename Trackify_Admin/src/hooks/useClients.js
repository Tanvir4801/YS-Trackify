import { useEffect, useState } from 'react';
import { useScopeId, useAuthStore } from '../store/authStore';
import { subscribeClients } from '../lib/services/clients.service';
import { DEMO_CLIENTS } from '../lib/demoData';

export function useClients() {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeId = useScopeId(); 
  const isDemo =
    scopeId === 'trackify_demo' ||
    (typeof window !== 'undefined' && sessionStorage.getItem('trackify_demo_mode') === 'true');

  const [data, setData] = useState(isDemo ? DEMO_CLIENTS : []);
  const [isLoading, setIsLoading] = useState(!isDemo);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (isDemo) {
      setData(DEMO_CLIENTS);
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
    const unsub = subscribeClients(
      scopeId,
      (list) => {
        setData(list);
        setIsLoading(false);
      },
      (err) => {
        setError(err);
        setIsLoading(false);
      }
    );
    return () => unsub();
  }, [scopeId, role, uid, isDemo]);

  return { data, isLoading, error };
}
