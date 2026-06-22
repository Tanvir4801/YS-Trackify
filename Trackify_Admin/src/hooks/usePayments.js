import { useEffect, useState } from 'react';
import { useScopeId } from '../store/authStore';
import { subscribePayments } from '../lib/services/payments.service';

export function usePayments(options = {}) {
  const scopeId = useScopeId();
  const [data, setData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  const { type, labourId, startDate, endDate } = options;

  useEffect(() => {
    setIsLoading(true);
    const unsub = subscribePayments(scopeId, (list) => {
      setData(list);
      setIsLoading(false);
    }, { type, labourId, startDate, endDate });
    return () => unsub();
  }, [scopeId, type, labourId, startDate, endDate]);

  return { data, isLoading };
}
