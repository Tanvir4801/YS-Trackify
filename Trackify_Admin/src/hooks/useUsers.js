import { useQuery } from '@tanstack/react-query';
import { useScopeId } from '../store/authStore';
import { getUsers } from '../lib/services/users.service';
import { DEMO_SUPERVISORS } from '../lib/demoData';

export function useUsers(options = {}) {
  const scopeId = useScopeId();
  const isDemo =
    scopeId === 'trackify_demo' ||
    (typeof window !== 'undefined' && sessionStorage.getItem('trackify_demo_mode') === 'true');

  return useQuery({
    queryKey: ['users', scopeId, options],
    queryFn: () => (isDemo ? Promise.resolve(DEMO_SUPERVISORS) : getUsers(scopeId, options)),
    staleTime: 30_000,
  });
}
