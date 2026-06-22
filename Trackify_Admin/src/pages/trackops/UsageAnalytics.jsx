import React, { useState, useEffect, useMemo } from 'react';
import { BarChart2, TrendingUp, Cpu, Database, CloudLightning, Activity, AlertCircle, Users, CreditCard } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, query, orderBy, limit, where } from 'firebase/firestore';

export default function UsageAnalytics() {
  const [activeTab, setActiveTab] = useState('features'); // features, firebase, contractors, insights
  
  const [contractors, setContractors] = useState([]);
  const [telemetry, setTelemetry] = useState([]);
  const [missionLogs, setMissionLogs] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let unsubContractors = () => {};
    let unsubTelemetry = () => {};
    let unsubLogs = () => {};

    let loadedCount = 0;
    const checkLoaded = () => {
      loadedCount++;
      if (loadedCount >= 3) setLoading(false);
    };

    try {
      // 1. Fetch Contractors
      unsubContractors = onSnapshot(collection(db, 'contractors'), (snapshot) => {
        const data = [];
        snapshot.forEach(doc => data.push({ id: doc.id, ...doc.data() }));
        setContractors(data);
        checkLoaded();
      }, (err) => {
        console.error("Contractors Error:", err);
        checkLoaded();
      });

      // 2. Fetch Telemetry (limit to recent 500 for performance)
      const qTel = query(collection(db, 'telemetry_events'), orderBy('timestamp', 'desc'), limit(500));
      unsubTelemetry = onSnapshot(qTel, (snapshot) => {
        const data = [];
        snapshot.forEach(doc => data.push({ id: doc.id, ...doc.data() }));
        setTelemetry(data);
        checkLoaded();
      }, (err) => {
        console.error("Telemetry Error:", err);
        checkLoaded();
      });

      // 3. Fetch Mission Logs (limit to recent 500 for Firebase activity estimates)
      const qLogs = query(collection(db, 'mission_logs'), orderBy('timestamp', 'desc'), limit(500));
      unsubLogs = onSnapshot(qLogs, (snapshot) => {
        const data = [];
        snapshot.forEach(doc => data.push({ id: doc.id, ...doc.data() }));
        setMissionLogs(data);
        checkLoaded();
      }, (err) => {
        console.error("Logs Error:", err);
        checkLoaded();
      });

    } catch (e) {
      console.error('UsageAnalytics listener initialization error:', e);
      setLoading(false);
    }

    return () => {
      try { unsubContractors(); unsubTelemetry(); unsubLogs(); } catch(e) { console.error('UsageAnalytics cleanup error:', e); }
    };
  }, []);

  return (
    <div className="space-y-6 pb-10">
      <div className="flex flex-col md:flex-row md:items-center justify-between border-b border-trackops-border pb-4 gap-4">
        <h1 className="text-2xl font-bold tracking-widest text-white uppercase flex items-center">
          <BarChart2 className="w-6 h-6 mr-3 text-trackops-green animate-pulse" />
          Analytics & Insights
        </h1>
        <div className="flex flex-wrap gap-2 font-mono text-sm">
          {['features', 'firebase', 'contractors', 'insights'].map(tab => (
            <button 
              key={tab}
              onClick={() => setActiveTab(tab)} 
              className={`px-4 py-2 rounded border transition-colors capitalize ${activeTab === tab ? 'bg-trackops-steel text-white border-trackops-green' : 'bg-trackops-navy text-gray-400 border-trackops-border hover:text-white'}`}
            >
              {tab}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-4 relative min-h-[400px]">
        {loading ? (
          <div className="absolute inset-0 flex flex-col items-center justify-center text-trackops-green font-mono">
            <Activity className="w-8 h-8 mb-4 animate-bounce" />
            Compiling Telemetry...
          </div>
        ) : (
          <>
            {activeTab === 'features' && <FeatureAnalytics telemetry={telemetry} />}
            {activeTab === 'firebase' && <FirebaseAnalytics telemetry={telemetry} logs={missionLogs} />}
            {activeTab === 'contractors' && <ContractorAnalytics contractors={contractors} />}
            {activeTab === 'insights' && <AIInsights contractors={contractors} telemetry={telemetry} />}
          </>
        )}
      </div>
    </div>
  );
}

// -------------------------------------------------------------
// Features Tab
// -------------------------------------------------------------
function FeatureAnalytics({ telemetry }) {
  const featureStats = useMemo(() => {
    const counts = {};
    let total = 0;
    telemetry.forEach(t => {
      const name = t.featureName || t.screenName || t.feature; // fallback for old data
      if (name && name !== 'Unknown' && name !== '/') {
        counts[name] = (counts[name] || 0) + 1;
        total++;
      }
    });

    const arr = Object.keys(counts).map(k => ({
      name: k,
      rawCount: counts[k],
      usage: total > 0 ? Math.round((counts[k] / total) * 100) : 0
    })).sort((a, b) => b.usage - a.usage);

    return arr.slice(0, 8); // Top 8 features
  }, [telemetry]);

  if (featureStats.length === 0) {
    return <div className="text-gray-500 font-mono text-center py-10">No telemetry data gathered yet. Open screens in the app to generate data.</div>;
  }

  return (
    <div className="space-y-4 font-mono">
      <h2 className="text-trackops-green tracking-widest uppercase text-sm mb-6">Real-Time Feature Adoption</h2>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {featureStats.map((feat) => (
          <div key={feat.name} className="bg-trackops-card border border-trackops-border p-4 rounded group hover:border-trackops-green/50 transition-colors">
            <div className="flex justify-between items-end mb-2">
              <div className="text-gray-300 font-bold uppercase truncate max-w-[200px]" title={feat.name}>{feat.name}</div>
              <div className="text-xl text-white font-bold">{feat.usage}%</div>
            </div>
            <div className="w-full bg-trackops-navy h-2 rounded overflow-hidden mb-1">
              <div className="bg-trackops-green h-full" style={{ width: `${feat.usage}%` }} />
            </div>
            <div className="text-[10px] text-gray-500 text-right">{feat.rawCount} recent events</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// -------------------------------------------------------------
// Firebase Tab
// -------------------------------------------------------------
function FirebaseAnalytics({ telemetry, logs }) {
  const stats = useMemo(() => {
    // Basic estimation based on recent events (since we don't have direct Google Cloud API access)
    // Assuming 1 log = ~2 writes, 1 telemetry = ~1 write
    // Assuming reads are 5x writes generically.
    const recentWrites = (logs.length * 2) + telemetry.length;
    const estimatedReads = recentWrites * 5;
    
    const costPer10kReads = 0.06 * 83; // approx INR
    const costPer10kWrites = 0.18 * 83; // approx INR
    
    const estCost = ((estimatedReads / 10000) * costPer10kReads) + ((recentWrites / 10000) * costPer10kWrites);

    return {
      reads: (estimatedReads * 14).toLocaleString(), // Extrapolated proxy for "Monthly"
      writes: (recentWrites * 14).toLocaleString(),
      estMonthlyCost: Math.max(0, (estCost * 30)).toFixed(2), // highly rough proxy
      eventsCount: telemetry.length,
      logsCount: logs.length
    };
  }, [telemetry, logs]);

  return (
    <div className="space-y-6 font-mono">
      <h2 className="text-trackops-green tracking-widest uppercase text-sm mb-6">Firebase Telemetry Proxy</h2>
      
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <StatBox title="Est. Monthly Cost" value={`₹${stats.estMonthlyCost}`} icon={CloudLightning} color="text-trackops-red" />
        <StatBox title="Recent Events" value={stats.eventsCount} icon={Activity} color="text-trackops-amber" />
        <StatBox title="Est. Reads (Proxy)" value={stats.reads} icon={Database} color="text-trackops-green" />
        <StatBox title="Est. Writes (Proxy)" value={stats.writes} icon={Database} color="text-trackops-green" />
      </div>

      <div className="mt-4 p-4 border border-trackops-border bg-trackops-navy/50 rounded text-xs text-gray-400">
        Note: These are client-side estimations derived from Mission Logs and Telemetry Events. True billing requires Google Cloud Monitoring API integration.
      </div>
    </div>
  );
}

// -------------------------------------------------------------
// Contractors Tab (Revenue & Subscription Logic)
// -------------------------------------------------------------
function ContractorAnalytics({ contractors }) {
  const stats = useMemo(() => {
    let totalMRR = 0;
    let trial = 0;
    let basic = 0;
    let pro = 0;
    let ent = 0;
    let activePaid = 0;
    let churnRisk = 0;

    const now = new Date();

    contractors.forEach(c => {
      const plan = (c.plan || 'trial').toLowerCase();
      const amount = Number(c.subscriptionAmount) || 0;
      
      if (plan === 'trial') trial++;
      if (plan === 'basic') basic++;
      if (plan === 'professional') pro++;
      if (plan === 'enterprise') ent++;

      if (plan !== 'trial' && c.isPremium === true) {
        totalMRR += amount;
        activePaid++;
      }

      // Basic Churn check: If expiry is within 7 days
      if (c.subscriptionExpiryDate) {
        try {
          const exp = typeof c.subscriptionExpiryDate === 'string' ? new Date(c.subscriptionExpiryDate) : c.subscriptionExpiryDate.toDate();
          const diffDays = (exp - now) / (1000 * 60 * 60 * 24);
          if (diffDays > 0 && diffDays <= 7) churnRisk++;
        } catch(e) {}
      }
    });

    const avgRev = activePaid > 0 ? (totalMRR / activePaid) : 0;

    return { totalMRR, trial, basic, pro, ent, activePaid, avgRev, churnRisk, total: contractors.length };
  }, [contractors]);

  return (
    <div className="space-y-6 font-mono">
      <h2 className="text-trackops-green tracking-widest uppercase text-sm mb-6">Contractor & Revenue Matrix</h2>
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <StatBox title="Total MRR" value={`₹${stats.totalMRR.toLocaleString()}`} icon={CreditCard} color="text-trackops-green" />
        <StatBox title="Annual Projection" value={`₹${(stats.totalMRR * 12).toLocaleString()}`} icon={TrendingUp} color="text-trackops-green" />
        <StatBox title="Avg Revenue / User" value={`₹${Math.round(stats.avgRev).toLocaleString()}`} icon={CreditCard} color="text-white" />
        <StatBox title="Active Paid" value={stats.activePaid} icon={Users} color="text-trackops-green" />
        
        <StatBox title="Trial Users" value={stats.trial} icon={AlertCircle} color="text-trackops-amber" />
        <StatBox title="Basic Plan" value={stats.basic} icon={Users} color="text-white" />
        <StatBox title="Pro Plan" value={stats.pro} icon={Users} color="text-trackops-amber" />
        <StatBox title="Enterprise" value={stats.ent} icon={Users} color="text-trackops-red" />
      </div>

      {stats.churnRisk > 0 && (
        <div className="mt-4 p-4 border border-trackops-red/50 bg-trackops-red/10 rounded text-trackops-red flex items-center">
          <AlertCircle className="w-5 h-5 mr-3" />
          Warning: {stats.churnRisk} contractors are at risk of churning (subscription expires in &lt; 7 days).
        </div>
      )}
    </div>
  );
}

// -------------------------------------------------------------
// AI Insights Tab
// -------------------------------------------------------------
function AIInsights({ contractors, telemetry }) {
  const insights = useMemo(() => {
    const list = [];
    
    // Rule 1: Churn
    const now = new Date();
    let expiringSoon = 0;
    contractors.forEach(c => {
      if (c.subscriptionExpiryDate) {
        try {
          const exp = typeof c.subscriptionExpiryDate === 'string' ? new Date(c.subscriptionExpiryDate) : c.subscriptionExpiryDate.toDate();
          const diffDays = (exp - now) / (1000 * 60 * 60 * 24);
          if (diffDays > 0 && diffDays <= 7) expiringSoon++;
        } catch(e) {}
      }
    });

    if (expiringSoon > 0) {
      list.push({ type: 'danger', text: `${expiringSoon} companies show high churn probability (expiry within 7 days). Reach out for renewal.` });
    }

    // Rule 2: Feature Adoption
    if (telemetry.length > 0) {
      const payrollCount = telemetry.filter(t => (t.featureName || t.feature || '').toLowerCase().includes('payroll') || (t.screenName || '').toLowerCase().includes('payroll')).length;
      if (payrollCount === 0) {
        list.push({ type: 'warning', text: 'No Payroll feature usage detected in recent telemetry. Consider promoting this feature.' });
      } else if (payrollCount > (telemetry.length * 0.2)) {
        list.push({ type: 'success', text: 'Payroll usage is highly active, representing >20% of recent events.' });
      }
    }

    // Rule 3: Trial Conversion
    const trials = contractors.filter(c => (c.plan || 'trial').toLowerCase() === 'trial').length;
    if (trials > 0) {
      list.push({ type: 'info', text: `There are ${trials} active trial accounts. Monitor their engagement closely for upsell opportunities.` });
    }

    // Default if none
    if (list.length === 0) {
      list.push({ type: 'success', text: 'System looks healthy. No anomalies detected.' });
    }

    return list;
  }, [contractors, telemetry]);

  return (
    <div className="space-y-6 font-mono">
      <h2 className="text-trackops-green tracking-widest uppercase text-sm mb-6 flex items-center">
        <Cpu className="w-5 h-5 mr-2 animate-pulse text-trackops-green" /> Dynamic Rule-Based Analysis
      </h2>
      <div className="space-y-3">
        {insights.map((insight, idx) => (
          <div key={idx} className={`p-4 border-l-4 bg-trackops-card ${
            insight.type === 'danger' ? 'border-trackops-red text-trackops-red' : 
            insight.type === 'warning' ? 'border-trackops-amber text-trackops-amber' : 
            insight.type === 'success' ? 'border-trackops-green text-trackops-green' : 
            'border-trackops-steel text-white'
          }`}>
            <span className="font-bold opacity-50 uppercase mr-2 text-xs">[{insight.type}]</span>
            {insight.text}
          </div>
        ))}
      </div>
    </div>
  );
}

// -------------------------------------------------------------
// Reusable StatBox
// -------------------------------------------------------------
function StatBox({ title, value, sub, icon: Icon, color }) {
  return (
    <div className="bg-trackops-card border border-trackops-border p-4 rounded group hover:border-trackops-green/50 transition-colors relative overflow-hidden">
      <div className="flex justify-between items-start mb-2">
        <div className="text-gray-500 text-[10px] uppercase tracking-wider">{title}</div>
        <Icon className={`w-5 h-5 ${color}`} />
      </div>
      <div className="text-xl font-bold text-white mb-1">{value}</div>
      {sub && <div className="text-xs text-gray-400">{sub}</div>}
    </div>
  );
}
