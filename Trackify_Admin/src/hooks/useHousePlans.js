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

    // Failsafe timeout to prevent indefinite loading spinner
    const fallbackTimer = setTimeout(() => {
      setIsLoading(false);
    }, 3500);

    return () => {
      unsub();
      clearTimeout(fallbackTimer);
    };
  }, [scopeId]);

  return { data, isLoading, error };
}

export function useMasterPlanCatalog() {
  const scopeId = useScopeId();
  const [catalog, setCatalog] = useState(() => {
    try {
      if (typeof window !== 'undefined' && scopeId) {
        const cached = localStorage.getItem(`trackify_master_catalog_${scopeId}`);
        if (cached) {
          const parsed = JSON.parse(cached);
          if (Array.isArray(parsed) && parsed.length > 0) return parsed;
        }
      }
    } catch (_) {}
    return DEFAULT_MASTER_PLANS;
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!scopeId) {
      setCatalog(DEFAULT_MASTER_PLANS);
      setLoading(false);
      return undefined;
    }

    const unsub = subscribeMasterPlanCatalog(scopeId, (list) => {
      if (list && Array.isArray(list) && list.length > 0) {
        // Ensure standard templates (like 22-Door Details) are merged in if missing from older saved list
        const existingNames = new Set(list.map((m) => (m.mainName || m.name || '').toLowerCase()));
        const missingDefaults = DEFAULT_MASTER_PLANS.filter(
          (def) => !existingNames.has((def.mainName || def.name || '').toLowerCase())
        );
        const finalList = missingDefaults.length > 0 ? [...list, ...missingDefaults] : list;
        setCatalog(finalList);
        try {
          localStorage.setItem(`trackify_master_catalog_${scopeId}`, JSON.stringify(finalList));
        } catch (_) {}
      } else {
        setCatalog(DEFAULT_MASTER_PLANS);
      }
      setLoading(false);
    });

    const fallbackTimer = setTimeout(() => {
      setLoading(false);
    }, 3500);

    return () => {
      unsub();
      clearTimeout(fallbackTimer);
    };
  }, [scopeId]);

  return { catalog, loading };
}
