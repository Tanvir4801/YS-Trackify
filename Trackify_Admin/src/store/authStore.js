import { create } from 'zustand';
import { useSubscriptionStore } from './subscriptionStore';

const isDemoInit =
  typeof window !== 'undefined' &&
  sessionStorage.getItem('trackify_demo_mode') === 'true';

export const useAuthStore = create((set) => ({
  uid: isDemoInit ? 'demo_user_visitor' : null,
  role: isDemoInit ? 'contractor' : null,
  name: isDemoInit ? 'Demo Admin' : null,
  email: isDemoInit ? 'demo@xyz.com' : null,
  isLoading: !isDemoInit,
  isDemo: isDemoInit,

  userContractorId: isDemoInit ? 'trackify_demo' : null,
  activeContractorId: isDemoInit ? 'trackify_demo' : null,
  activeContractorName: isDemoInit ? 'XYZ Construction' : null,

  contractorsList: [],

  setLoading: (isLoading) => set({ isLoading }),

  setUser: ({ uid, role, name, email, contractorId }) => {
    const cId = contractorId ?? null;
    // P1-6 FIX: Init subscription for contractor AND supervisor
    // (supervisor operates under contractor's tenant).
    if (role === 'contractor') {
      useSubscriptionStore.getState().initForContractor(cId || uid);
    } else if (role === 'supervisor' && cId) {
      useSubscriptionStore.getState().initForContractor(cId);
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
