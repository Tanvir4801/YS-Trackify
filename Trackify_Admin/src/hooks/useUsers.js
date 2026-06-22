import { useQuery } from '@tanstack/react-query';
import { useScopeId } from '../store/authStore';
import { getUsers } from '../lib/services/users.service';

export function useUsers(options = {}) {
  const scopeId = useScopeId();
  return useQuery({
    queryKey: ['users', scopeId, options],
    queryFn: () => getUsers(scopeId, options),
    staleTime: 30_000,
  });
}
