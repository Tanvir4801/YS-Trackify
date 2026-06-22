import { useQuery } from '@tanstack/react-query';
import { collection, query, orderBy, getDocs, doc, updateDoc } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { useScopeId } from '../store/authStore';

export function useSupportRequests() {
  const scopeId = useScopeId();

  return useQuery({
    queryKey: ['support_requests', scopeId],
    queryFn: async () => {
      if (!scopeId) return [];
      
      const q = query(
        collection(db, 'support_requests'),
        orderBy('createdAt', 'desc')
      );
      
      const snap = await getDocs(q);
      const data = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      
      return data;
    },
    enabled: !!scopeId,
  });
}

export async function updateSupportRequestStatus(requestId, newStatus) {
  const ref = doc(db, 'support_requests', requestId);
  await updateDoc(ref, { status: newStatus });
}
