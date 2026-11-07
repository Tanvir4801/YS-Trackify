import { useEffect, useState } from 'react';
import { useScopeId } from '../store/authStore';
import { subscribePayments } from '../lib/services/payments.service';
import { DEMO_PAYMENTS } from '../lib/demoData';

export function usePayments(options = {}) {
  const scopeId = useScopeId();
  const isDemo =
    scopeId === 'trackify_demo' ||
    (typeof window !== 'undefined' && sessionStorage.getItem('trackify_demo_mode') === 'true');

  const [data, setData] = useState(isDemo ? DEMO_PAYMENTS : []);
  const [isLoading, setIsLoading] = useState(!isDemo);

  const { type, labourId, startDate, endDate } = options;

  useEffect(() => {
    if (isDemo) {
      setData(DEMO_PAYMENTS);
      setIsLoading(false);
      return undefined;
    }

    setIsLoading(true);
    const unsub = subscribePayments(
      scopeId,
      (list) => {
        setData(list);
        setIsLoading(false);
      },
      { type, labourId, startDate, endDate }
    );
    return () => unsub();
  }, [scopeId, type, labourId, startDate, endDate, isDemo]);

  return { data, isLoading };
}
