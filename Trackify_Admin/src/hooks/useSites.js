import { useQuery } from '@tanstack/react-query';
import { useScopeId } from '../store/authStore';
import { getSites } from '../lib/services/sites.service';

export function useSites(includeInactive = false) {
  const scopeId = useScopeId();

  return useQuery({
    queryKey: ['sites', scopeId, includeInactive],
    queryFn: () => getSites(scopeId, includeInactive),
    staleTime: 30_000,
  });
}
