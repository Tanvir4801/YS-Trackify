import { useQuery } from '@tanstack/react-query';
import { collection, query, orderBy, where, getDocs, doc, updateDoc } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { useScopeId } from '../store/authStore';

export function useSupportRequests() {
  const scopeId = useScopeId();

  return useQuery({
    queryKey: ['support_requests', scopeId],
    queryFn: async () => {
      if (!scopeId) return [];

      // P1-5 FIX: Scope support requests to contractor tenant.
      // Without this filter, all contractors can see each other's requests.
      const q = query(
        collection(db, 'support_requests'),
        where('contractorId', '==', scopeId),
        orderBy('createdAt', 'desc'),
      );

      const snap = await getDocs(q);
      return snap.docs.map(d => ({ id: d.id, ...d.data() }));
    },
    enabled: !!scopeId,
  });
}

export async function updateSupportRequestStatus(requestId, newStatus) {
  // Canonical format going forward: lowercase
  const canonical = String(newStatus || '').trim().toLowerCase();
  const ref = doc(db, 'support_requests', requestId);
  await updateDoc(ref, { status: canonical });
}
