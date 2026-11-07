import { useQuery } from '@tanstack/react-query';
import { useScopeId } from '../store/authStore';
import { getSupervisors } from '../lib/services/users.service';
import { DEMO_SUPERVISORS } from '../lib/demoData';

export function useSupervisors() {
  const scopeId = useScopeId();
  const isDemo =
    scopeId === 'trackify_demo' ||
    (typeof window !== 'undefined' && sessionStorage.getItem('trackify_demo_mode') === 'true');

  return useQuery({
    queryKey: ['supervisors', scopeId],
    queryFn: () => (isDemo ? Promise.resolve(DEMO_SUPERVISORS) : getSupervisors(scopeId)),
    staleTime: 30_000,
  });
}
