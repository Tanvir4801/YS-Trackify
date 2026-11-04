import { useEffect, useState } from 'react';
import { useScopeId } from '../store/authStore';
import {
  subscribeHousePlans,
  subscribeMasterPlanCatalog,
  DEFAULT_MASTER_PLANS,
} from '../lib/services/plans.service';

export function useHousePlans() {
  const scopeId = useScopeId();
  const [data, setData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!scopeId) {
      setData([]);
      setIsLoading(false);
      return undefined;
    }

    setIsLoading(true);
    setError(null);

    const unsub = subscribeHousePlans(
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
  }, [scopeId]);

  return { data, isLoading, error };
}

export function useMasterPlanCatalog() {
  const scopeId = useScopeId();
  const [catalog, setCatalog] = useState(DEFAULT_MASTER_PLANS);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!scopeId) {
      setCatalog(DEFAULT_MASTER_PLANS);
      setLoading(false);
      return undefined;
    }

    const unsub = subscribeMasterPlanCatalog(scopeId, (list) => {
      setCatalog(list && list.length > 0 ? list : DEFAULT_MASTER_PLANS);
      setLoading(false);
    });

    return () => unsub();
  }, [scopeId]);

  return { catalog, loading };
}
