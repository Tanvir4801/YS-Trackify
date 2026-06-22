import { create } from 'zustand';
import { useSubscriptionStore } from './subscriptionStore';
export const useAuthStore = create((set) => ({
  uid: null,
  role: null,
  name: null,
  email: null,
  isLoading: true,

  userContractorId: null,
  activeContractorId: null,
  activeContractorName: null,

  contractorsList: [],

  setLoading: (isLoading) => set({ isLoading }),

  setUser: ({ uid, role, name, email, contractorId }) => {
    const cId = contractorId ?? null;
    if (role === 'contractor') {
      useSubscriptionStore.getState().initForContractor(cId || uid);
    }
    set({
      uid,
      role,
      name,
      email: email ?? null,
      userContractorId: cId,
      isLoading: false,
    });
  },

  clearUser: () => {
    useSubscriptionStore.getState().clear();
    set({
      uid: null,
      role: null,
      name: null,
      email: null,
      userContractorId: null,
      activeContractorId: null,
      activeContractorName: null,
      contractorsList: [],
      isLoading: false,
    });
  },

  switchContractor: (id, name) => {
    if (id) {
      useSubscriptionStore.getState().initForContractor(id);
    } else {
      useSubscriptionStore.getState().clear();
    }
    set({
      activeContractorId: id || null,
      activeContractorName: name || null,
    });
  },

  setContractorsList: (list) => set({ contractorsList: list || [] }),
}));

// Returns the value used to scope Firestore queries for the current user.
// - super_admin: the selected contractor's id (or null = "all" view)
// - contractor: their assigned contractorId
// - supervisor: their own UID
export function useScopeId() {
  return useAuthStore((s) => {
    if (s.role === 'trackops') return s.activeContractorId || null;
    if (s.role === 'super_admin') return s.activeContractorId;
    if (s.role === 'contractor') {
      return s.userContractorId || s.activeContractorId || s.uid;
    }
    // For supervisors, their scope (tenant) is the contractor they belong to
    return s.userContractorId || s.uid;
  });
}
