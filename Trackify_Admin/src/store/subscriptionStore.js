import { create } from 'zustand';
import { doc, onSnapshot } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { getSubscription, getFeatureFlags } from '../lib/services/subscriptions.service';

export const useSubscriptionStore = create((set, get) => ({
  subscription: null,
  featureFlags: null,
  healthScore: null,
  loading: false,
  unsubSub: null,
  unsubFlags: null,
  unsubHealth: null,

  initForContractor: async (contractorId) => {
    const { unsubSub, unsubFlags, unsubHealth } = get();
    if (unsubSub) unsubSub();
    if (unsubFlags) unsubFlags();
    if (unsubHealth) unsubHealth();
    
    set({ subscription: null, featureFlags: null, healthScore: null, loading: true });
    
    if (!contractorId) {
      set({ loading: false });
      return;
    }

    // Ensure it exists in db first
    await getSubscription(contractorId);
    await getFeatureFlags(contractorId);

    const uSub = onSnapshot(doc(db, 'subscriptions', contractorId), (snap) => {
      set({ subscription: snap.data() });
    });
    const uFlags = onSnapshot(doc(db, 'feature_flags', contractorId), (snap) => {
      set({ featureFlags: snap.data() });
    });
    const uHealth = onSnapshot(doc(db, 'health_scores', contractorId), (snap) => {
      set({ healthScore: snap.data() });
    });

    set({ unsubSub: uSub, unsubFlags: uFlags, unsubHealth: uHealth, loading: false });
  },

  clear: () => {
    const { unsubSub, unsubFlags, unsubHealth } = get();
    if (unsubSub) unsubSub();
    if (unsubFlags) unsubFlags();
    if (unsubHealth) unsubHealth();
    set({ subscription: null, featureFlags: null, healthScore: null, unsubSub: null, unsubFlags: null, unsubHealth: null });
  }
}));
