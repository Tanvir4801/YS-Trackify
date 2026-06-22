import { db } from '../firebase';
import {
  collection, doc, getDoc, setDoc, updateDoc, 
  query, where, getDocs, serverTimestamp, increment, addDoc
} from 'firebase/firestore';

export const SUBSCRIPTION_PLANS = {
  FREE: {
    id: 'free',
    name: 'Free',
    price: 0,
    maxSites: 2,
    maxSupervisors: 1,
    features: { pdf_reports: false, excel_reports: false, payroll: false, multi_site: true, analytics_advanced: false, priority_support: false }
  },
  PROFESSIONAL: {
    id: 'professional',
    name: 'Professional',
    price: 499,
    maxSites: 9999,
    maxSupervisors: 10,
    features: { pdf_reports: true, excel_reports: true, payroll: true, multi_site: true, analytics_advanced: false, priority_support: false }
  },
  ENTERPRISE: {
    id: 'enterprise',
    name: 'Enterprise',
    price: 999,
    maxSites: 9999,
    maxSupervisors: 9999,
    features: { pdf_reports: true, excel_reports: true, payroll: true, multi_site: true, analytics_advanced: true, priority_support: true }
  }
};

/** Initialize 30-day Pro trial if no subscription exists */
export async function initializeSubscription(contractorId) {
  if (!contractorId) return null;
  const subRef = doc(db, 'subscriptions', contractorId);
  const snap = await getDoc(subRef);
  if (snap.exists()) return snap.data();

  const now = new Date();
  const expiry = new Date();
  expiry.setDate(expiry.getDate() + 30); // 30 day trial

  const plan = SUBSCRIPTION_PLANS.PROFESSIONAL;

  const subData = {
    plan: plan.id,
    status: 'trial',
    startDate: now.toISOString(),
    expiryDate: expiry.toISOString(),
    isTrial: true,
    isLifetime: false,
    trialDays: 30,
    maxSites: plan.maxSites,
    maxSupervisors: plan.maxSupervisors,
    paymentStatus: 'none',
    createdAt: serverTimestamp(),
  };

  await setDoc(subRef, subData);
  await setDoc(doc(db, 'feature_flags', contractorId), plan.features);
  
  // init health
  await setDoc(doc(db, 'health_scores', contractorId), {
    overall: 100, attendance: 30, payroll: 25, siteTracking: 25, supervisorProductivity: 20, computedAt: serverTimestamp()
  });

  return subData;
}

export async function getSubscription(contractorId) {
  if (!contractorId) return null;
  const snap = await getDoc(doc(db, 'subscriptions', contractorId));
  if (!snap.exists()) return await initializeSubscription(contractorId);
  return snap.data();
}

export async function getFeatureFlags(contractorId) {
  if (!contractorId) return null;
  const snap = await getDoc(doc(db, 'feature_flags', contractorId));
  return snap.exists() ? snap.data() : null;
}

export async function trackUsage(contractorId, metric, count = 1) {
  if (!contractorId) return;
  const month = new Date().toISOString().slice(0, 7); // YYYY-MM
  const ref = doc(db, 'usage_stats', contractorId, 'monthly', month);
  try {
    await setDoc(ref, { [metric]: increment(count), lastUpdated: serverTimestamp() }, { merge: true });
  } catch (err) {
    console.error('Usage track error', err);
  }
}

export async function downgradeToFree(contractorId) {
  const plan = SUBSCRIPTION_PLANS.FREE;
  await updateDoc(doc(db, 'subscriptions', contractorId), {
    plan: plan.id,
    status: 'expired',
    isTrial: false,
    maxSites: plan.maxSites,
    maxSupervisors: plan.maxSupervisors,
    updatedAt: serverTimestamp()
  });
  await setDoc(doc(db, 'feature_flags', contractorId), plan.features);
}

export async function upgradePlan(contractorId, planId, durationDays = 30) {
  const plan = SUBSCRIPTION_PLANS[planId.toUpperCase()];
  if (!plan) return;
  
  const now = new Date();
  const expiry = new Date();
  expiry.setDate(expiry.getDate() + durationDays);

  await updateDoc(doc(db, 'subscriptions', contractorId), {
    plan: plan.id,
    status: 'active',
    isTrial: false,
    startDate: now.toISOString(),
    expiryDate: expiry.toISOString(),
    maxSites: plan.maxSites,
    maxSupervisors: plan.maxSupervisors,
    updatedAt: serverTimestamp()
  });
  await setDoc(doc(db, 'feature_flags', contractorId), plan.features);
}

export async function calculateHealthScore(contractorId) {
  // Mock algorithm implementation. In a real scenario, this would aggregate data from attendance/sites.
  // We'll leave it as a callable function that updates the score.
  const score = {
    overall: Math.floor(Math.random() * 40) + 60, // 60-100
    attendance: 25,
    payroll: 20,
    siteTracking: 20,
    supervisorProductivity: 15,
    computedAt: serverTimestamp()
  };
  await setDoc(doc(db, 'health_scores', contractorId), score, { merge: true });
  return score;
}
