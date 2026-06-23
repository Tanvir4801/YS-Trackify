import { useQuery } from '@tanstack/react-query';
import { useScopeId } from '../store/authStore';
import { getPayments } from '../lib/services/payments.service';

export function usePayments(options = {}) {
  const scopeId = useScopeId();

  return useQuery({
    queryKey: ['payments', scopeId, options],
    queryFn: () => getPayments(scopeId, options),
    enabled: true,
    staleTime: 10_000,
  });
}
