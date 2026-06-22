import { useQuery } from '@tanstack/react-query';
import { useScopeId } from '../store/authStore';
import { getSupervisors } from '../lib/services/users.service';

export function useSupervisors() {
  const scopeId = useScopeId();

  return useQuery({
    queryKey: ['supervisors', scopeId],
    queryFn: () => getSupervisors(scopeId),
    staleTime: 30_000,
  });
}
