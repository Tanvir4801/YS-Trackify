import { create } from 'zustand';

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

  setUser: ({ uid, role, name, email, contractorId }) =>
    set({
      uid,
      role,
      name,
      email: email ?? null,
      userContractorId: contractorId ?? null,
      isLoading: false,
    }),

  clearUser: () =>
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
    }),

  switchContractor: (id, name) =>
    set({
      activeContractorId: id || null,
      activeContractorName: name || null,
    }),

  setContractorsList: (list) => set({ contractorsList: list || [] }),
}));

// Returns the value used to scope Firestore queries for the current user.
// - super_admin: the selected contractor's id (or null = "all" view)
// - contractor: their assigned contractorId
// - supervisor: their own UID
export function useScopeId() {
  return useAuthStore((s) => {
    if (s.role === 'super_admin') return s.activeContractorId;
    if (s.role === 'contractor') {
      return s.userContractorId || s.activeContractorId || s.uid;
    }
    return s.uid;
  });
}
