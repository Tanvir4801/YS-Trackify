import { db } from '../firebase';
import { collection, getDocs, query, where } from 'firebase/firestore';

export async function getSAKPIs() {
  const subsSnap = await getDocs(collection(db, 'subscriptions'));
  
  let active = 0;
  let trial = 0;
  let expired = 0;
  let suspended = 0;
  let mrr = 0;
  let totalSites = 0;

  subsSnap.forEach(doc => {
    const data = doc.data();
    if (data.status === 'active') active++;
    else if (data.status === 'trial') trial++;
    else if (data.status === 'expired') expired++;
    else if (data.status === 'suspended') suspended++;

    if (data.status === 'active' && data.plan === 'enterprise') mrr += 999;
    else if (data.status === 'active' && data.plan === 'professional') mrr += 499;
    
    // We don't have total labours/sites directly on sub doc, 
    // but we can query them or just return 0 for now until aggregated.
  });

  return { 
    mrr, 
    arr: mrr * 12, 
    todayRev: 0, 
    pending: 0, 
    totalLabours: 0, 
    totalSites: 0, 
    active, 
    trial, 
    expired, 
    suspended, 
    total: subsSnap.size 
  };
}

export async function getPlanBreakdown() {
  const plans = { free: 0, professional: 0, enterprise: 0 };
  const subsSnap = await getDocs(collection(db, 'subscriptions'));
  
  subsSnap.forEach(doc => {
    const data = doc.data();
    if (data.status === 'active' || data.status === 'trial') {
      if (plans[data.plan] !== undefined) plans[data.plan]++;
    }
  });

  return [
    { name: 'Free',         value: plans.free,         color: '#64748B', price: 0 },
    { name: 'Professional', value: plans.professional, color: '#F5A623', price: 499 },
    { name: 'Enterprise',   value: plans.enterprise,   color: '#8B5CF6', price: 999 },
  ];
}

export async function getAtRiskContractors() {
  const q = query(collection(db, 'health_scores'), where('overall', '<', 60));
  const snap = await getDocs(q);
  const results = [];
  snap.forEach(doc => {
    results.push({ id: doc.id, ...doc.data() });
  });
  return results;
}

export async function getAllCustomers() {
  const usersSnap = await getDocs(query(collection(db, 'users'), where('role', '==', 'contractor')));
  const subsSnap = await getDocs(collection(db, 'subscriptions'));
  
  const subsMap = {};
  subsSnap.forEach(d => subsMap[d.id] = d.data());

  const customers = [];
  usersSnap.forEach(doc => {
    const user = doc.data();
    const sub = subsMap[doc.id] || {};
    customers.push({
      id: doc.id,
      name: user.companyName || user.name || 'Unknown',
      plan: sub.plan || 'none',
      status: sub.status || 'unknown',
      mrr: sub.plan === 'enterprise' ? 999 : (sub.plan === 'professional' ? 499 : 0),
      sites: 0,
      labours: 0,
      joined: user.createdAt?.toDate ? user.createdAt.toDate().toISOString() : '',
      owner: user.name || '',
      phone: user.phone || '',
      city: user.city || '',
      isTrial: sub.isTrial || false,
      trialDays: sub.trialDays || 0,
      expiryDate: sub.expiryDate || null
    });
  });

  return customers;
}

// Real tracking data endpoints
export async function getRevenueTransactions() {
  const snap = await getDocs(collection(db, 'revenue_transactions'));
  const results = [];
  snap.forEach(doc => results.push({ id: doc.id, ...doc.data() }));
  return results;
}

export async function getSupportTickets() {
  const snap = await getDocs(collection(db, 'support_requests'));
  const results = [];
  snap.forEach(doc => results.push({ id: doc.id, ...doc.data() }));
  return results;
}

export async function getMrrTrend() {
  const snap = await getDocs(collection(db, 'mrr_trend'));
  const results = [];
  snap.forEach(doc => results.push({ id: doc.id, ...doc.data() }));
  return results;
}

export async function getFeatureUsage() {
  const snap = await getDocs(collection(db, 'feature_usage'));
  const results = [];
  snap.forEach(doc => results.push({ id: doc.id, ...doc.data() }));
  return results;
}

export async function getTodayUsage() {
  const snap = await getDocs(query(collection(db, 'daily_stats'), where('date', '>=', new Date().toISOString().split('T')[0])));
  if (!snap.empty) {
    return snap.docs[0].data();
  }
  return { qrScans: 0, attendanceMarked: 0, pdfDownloads: 0, reportsGenerated: 0, activeSupervisors: 0, activeSites: 0 };
}

export async function getChurnData() {
  const snap = await getDocs(collection(db, 'churned_customers'));
  const results = [];
  snap.forEach(doc => results.push({ id: doc.id, ...doc.data() }));
  return results;
}
