const functions = require('firebase-functions');
const admin = require('firebase-admin');

// In-memory cache variables
const cache = {
  analytics: { data: null, timestamp: 0 },
  billing: { data: null, timestamp: 0 }
};

// Configurable TTLs (in milliseconds)
const TTL_ANALYTICS = 5 * 60 * 1000; // 5 minutes
const TTL_BILLING = 60 * 60 * 1000;  // 60 minutes

function checkAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }
}

// ─── Analytics (Companies, Revenue, Usage) ──────────────────────────────────
exports.trackopsGetAnalytics = functions.https.onCall(async (data, context) => {
  checkAuth(context);

  const now = Date.now();
  if (cache.analytics.data && (now - cache.analytics.timestamp < TTL_ANALYTICS)) {
    return { ...cache.analytics.data, fromCache: true };
  }

  const db = admin.firestore();
  try {
    let active = 0;
    let premium = 0;
    let free = 0;
    let estRevenue = 0;
    let newThisWeek = 0;
    
    // Detailed MRR & Plan Stats
    let totalMRR = 0;
    let trial = 0, basic = 0, pro = 0, ent = 0, activePaid = 0, churnRisk = 0;

    const oneWeekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const [contractorsSnap, telemetrySnap, logsSnap] = await Promise.all([
      db.collection('contractors').get(),
      db.collection('telemetry_events').orderBy('timestamp', 'desc').limit(500).get(),
      db.collection('mission_logs').orderBy('timestamp', 'desc').limit(500).get()
    ]);
    
    contractorsSnap.forEach(doc => {
      const cData = doc.data();
      if (cData.isActive !== false) active++;
      
      const plan = (cData.plan || 'trial').toLowerCase();
      if (plan !== 'trial' && cData.isPremium === true) {
        premium++;
        estRevenue += (Number(cData.subscriptionAmount) || 0);
      } else {
        free++;
      }

      if (cData.createdAt && cData.createdAt.toDate() > oneWeekAgo) {
        newThisWeek++;
      }

      // Detailed Stats
      const amount = Number(cData.subscriptionAmount) || 0;
      if (plan === 'trial') trial++;
      if (plan === 'basic') basic++;
      if (plan === 'professional') pro++;
      if (plan === 'enterprise') ent++;

      if (plan !== 'trial' && cData.isPremium === true) {
        totalMRR += amount;
        activePaid++;
      }

      if (cData.subscriptionExpiryDate) {
        try {
          const exp = cData.subscriptionExpiryDate.toDate ? cData.subscriptionExpiryDate.toDate() : new Date(cData.subscriptionExpiryDate);
          const diffDays = (exp - now) / (1000 * 60 * 60 * 24);
          if (diffDays > 0 && diffDays <= 7) churnRisk++;
        } catch(e) {}
      }
    });

    const avgRev = activePaid > 0 ? (totalMRR / activePaid) : 0;
    
    // Feature Analytics
    const featureCounts = {};
    let totalFeat = 0;
    let payrollCount = 0;
    telemetrySnap.forEach(doc => {
      const t = doc.data();
      const name = t.featureName || t.screenName || t.feature;
      if (name && name !== 'Unknown' && name !== '/') {
        featureCounts[name] = (featureCounts[name] || 0) + 1;
        totalFeat++;
      }
      if ((name || '').toLowerCase().includes('payroll')) {
        payrollCount++;
      }
    });

    const topFeatures = Object.keys(featureCounts).map(k => ({
      name: k,
      rawCount: featureCounts[k],
      usage: totalFeat > 0 ? Math.round((featureCounts[k] / totalFeat) * 100) : 0
    })).sort((a, b) => b.usage - a.usage).slice(0, 8);

    // Firebase Estimations
    const recentWrites = (logsSnap.size * 2) + telemetrySnap.size;
    const estimatedReads = recentWrites * 5;
    const costPer10kReads = 0.06 * 83; // INR proxy
    const costPer10kWrites = 0.18 * 83;
    const estCost = ((estimatedReads / 10000) * costPer10kReads) + ((recentWrites / 10000) * costPer10kWrites);

    // AI Insights
    const insightsList = [];
    if (churnRisk > 0) {
      insightsList.push({ type: 'danger', text: `${churnRisk} companies show high churn probability (expiry within 7 days). Reach out for renewal.` });
    }
    if (telemetrySnap.size > 0) {
      if (payrollCount === 0) {
        insightsList.push({ type: 'warning', text: 'No Payroll feature usage detected in recent telemetry. Consider promoting this feature.' });
      } else if (payrollCount > (telemetrySnap.size * 0.2)) {
        insightsList.push({ type: 'success', text: 'Payroll usage is highly active, representing >20% of recent events.' });
      }
    }
    if (trial > 0) {
      insightsList.push({ type: 'info', text: `There are ${trial} active trial accounts. Monitor their engagement closely for upsell opportunities.` });
    }
    if (insightsList.length === 0) {
      insightsList.push({ type: 'success', text: 'System looks healthy. No anomalies detected.' });
    }

    const result = {
      // General Dashboard
      companiesActive: active,
      premiumContractors: premium,
      freeContractors: free,
      revenue: estRevenue,
      newCompaniesThisWeek: newThisWeek,
      
      // Detailed Contractor Stats
      contractorStats: {
        totalMRR, trial, basic, pro, ent, activePaid, avgRev, churnRisk, total: contractorsSnap.size
      },
      
      // Features & Tech Stats
      topFeatures,
      firebaseStats: {
        reads: (estimatedReads * 14).toLocaleString(),
        writes: (recentWrites * 14).toLocaleString(),
        estMonthlyCost: Math.max(0, (estCost * 30)).toFixed(2),
        eventsCount: telemetrySnap.size,
        logsCount: logsSnap.size
      },
      
      insightsList,
      timestamp: now
    };

    // Update Cache
    cache.analytics = { data: result, timestamp: now };
    
    return { ...result, fromCache: false };
  } catch (error) {
    console.error('trackopsGetAnalytics Error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch analytics');
  }
});

// ─── Billing (GCP / Firebase Cost) ──────────────────────────────────────────
exports.trackopsGetBilling = functions.https.onCall(async (data, context) => {
  checkAuth(context);

  const now = Date.now();
  if (cache.billing.data && (now - cache.billing.timestamp < TTL_BILLING)) {
    return { ...cache.billing.data, fromCache: true };
  }

  const db = admin.firestore();
  try {
    const docSnap = await db.collection('system_status').doc('billing').get();
    let result = {
      costAmount: 0,
      budgetAmount: 0,
      currencyCode: 'USD',
      timestamp: now
    };
    
    if (docSnap.exists) {
      const bData = docSnap.data();
      result = {
        costAmount: bData.costAmount || 0,
        budgetAmount: bData.budgetAmount || 0,
        currencyCode: bData.currencyCode || 'USD',
        timestamp: now
      };
    }

    // Update Cache
    cache.billing = { data: result, timestamp: now };
    
    return { ...result, fromCache: false };
  } catch (error) {
    console.error('trackopsGetBilling Error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch billing data');
  }
});

// ─── Paginated Logs ─────────────────────────────────────────────────────────
exports.trackopsGetPaginatedLogs = functions.https.onCall(async (data, context) => {
  checkAuth(context);

  const { collectionName, lastVisibleId, pageSize = 50 } = data;
  if (!['mission_logs', 'error_logs', 'security_events'].includes(collectionName)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid collection');
  }

  const db = admin.firestore();
  try {
    let query = db.collection(collectionName).orderBy('timestamp', 'desc').limit(pageSize);
    
    if (lastVisibleId) {
      const lastDoc = await db.collection(collectionName).doc(lastVisibleId).get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }

    const snap = await query.get();
    const logs = [];
    snap.forEach(doc => {
      const d = doc.data();
      // Ensure timestamps are converted or safely serialized
      if (d.timestamp && d.timestamp.toDate) {
        d.timestamp = d.timestamp.toDate().toISOString();
      }
      logs.push({ id: doc.id, ...d });
    });

    const lastId = snap.docs.length > 0 ? snap.docs[snap.docs.length - 1].id : null;

    return {
      logs,
      lastVisibleId: lastId,
      hasMore: snap.docs.length === pageSize
    };
  } catch (error) {
    console.error(`trackopsGetPaginatedLogs [${collectionName}] Error:`, error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch logs');
  }
});
