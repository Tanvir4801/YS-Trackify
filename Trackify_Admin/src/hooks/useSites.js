import { useQuery } from '@tanstack/react-query';
import { useScopeId } from '../store/authStore';
import { getSites } from '../lib/services/sites.service';
import { DEMO_SITES } from '../lib/demoData';

export function useSites(includeInactive = false) {
  const scopeId = useScopeId();
  const isDemo =
    scopeId === 'trackify_demo' ||
    (typeof window !== 'undefined' && sessionStorage.getItem('trackify_demo_mode') === 'true');

  return useQuery({
    queryKey: ['sites', scopeId, includeInactive],
    queryFn: () => (isDemo ? Promise.resolve(DEMO_SITES) : getSites(scopeId, includeInactive)),
    staleTime: 30_000,
  });
}
