import React, { useEffect, useState } from 'react';
import { collection, onSnapshot, query, limit, orderBy, where, doc } from 'firebase/firestore';
import { Activity, Server, Users, DollarSign, CloudLightning, ShieldAlert, Smartphone, TrendingUp, HeartPulse, CheckCircle2 } from 'lucide-react';
import { db } from '../../lib/firebase';

export default function MissionDashboard() {
  const [stats, setStats] = useState({
    onlineUsers: 0,
    companiesActive: 0,
    revenue: 0,
    firebaseCost: 0,
    attendanceToday: 0,
    reportsGenerated: 0,
    premiumContractors: 0,
    freeContractors: 0,
    criticalErrors: 0,
    openTickets: 0,
    iosUsers: 0,
    androidUsers: 0,
    newCompaniesThisWeek: 0,
    missionHealthScore: 100,
  });

  const [billing, setBilling] = useState({
    costAmount: 0,
    budgetAmount: 0,
    currencyCode: 'USD',
  });

  const [feed, setFeed] = useState([]);
  const [insights, setInsights] = useState([]);

  useEffect(() => {
    let unsubTelemetry = () => {};
    let unsubContractors = () => {};
    let unsubTickets = () => {};
    let unsubLogs = () => {};
    let unsubBilling = () => {};

    try {
      // 1. Live Users & Device Analytics from Telemetry
      const tenMinsAgo = new Date(Date.now() - 10 * 60000);
      const qTel = query(collection(db, 'telemetry_events'), orderBy('timestamp', 'desc'), limit(100));
      unsubTelemetry = onSnapshot(qTel, (snap) => {
        try {
          const recentUsers = new Set();
          let ios = 0;
          let android = 0;
          let attCount = 0;
          let repCount = 0;
          const liveFeed = [];

          snap.forEach(doc => {
            const data = doc.data();
            
            // Online counting
            if (data.userId && data.timestamp && data.timestamp.toDate() > tenMinsAgo) {
              recentUsers.add(data.userId);
            }

            // Device counts (only count unique sessions roughly)
            if (data.platform?.toLowerCase().includes('ios')) ios++;
            if (data.platform?.toLowerCase().includes('android')) android++;

            // Feature counts
            if (data.featureName?.toLowerCase().includes('attendance')) attCount++;
            if (data.featureName?.toLowerCase().includes('export')) repCount++;

            // Feed
            if (data.timestamp) {
              liveFeed.push({
                id: doc.id,
                time: data.timestamp.toDate().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}),
                text: `[${data.platform || 'System'}] ${data.featureName || data.screenName} accessed by ${data.role || 'user'}`,
                severity: 'INFO'
              });
            }
          });

          setFeed(liveFeed.slice(0, 10));
          
          setStats(s => ({ 
            ...s, 
            onlineUsers: recentUsers.size, 
            iosUsers: ios, 
            androidUsers: android,
            attendanceToday: attCount * 5, // Simulation multiplier
            reportsGenerated: repCount
          }));
        } catch(e) { console.error('MissionDashboard telemetry processing error:', e); }
      }, (err) => {
        console.error("Telemetry Error in Dashboard:", err);

      });

      // 2. Company, Subscription, Revenue & Growth Analytics
      unsubContractors = onSnapshot(collection(db, 'contractors'), (snap) => {
        try {
          let active = 0;
          let premium = 0;
          let free = 0;
          let estRevenue = 0;
          let newThisWeek = 0;
          
          const oneWeekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

          snap.forEach(doc => {
            const data = doc.data();
            if (data.isActive !== false) active++;
            
            const plan = (data.plan || 'trial').toLowerCase();
            if (plan !== 'trial' && data.isPremium === true) {
              premium++;
              estRevenue += (Number(data.subscriptionAmount) || 0);
            } else {
              free++;
            }

            if (data.createdAt && data.createdAt.toDate() > oneWeekAgo) {
              newThisWeek++;
            }
          });
          
          setStats(s => ({ 
            ...s, 
            companiesActive: active, 
            premiumContractors: premium,
            freeContractors: free,
            revenue: estRevenue,
            newCompaniesThisWeek: newThisWeek,
          }));
        } catch(e) { console.error('MissionDashboard contractors processing error:', e); }
      }, (err) => {
        console.error("Contractors Error in Dashboard:", err);
      });

      // 3. Listen to Real-Time Billing from Google Cloud (via system_status/billing)
      unsubBilling = onSnapshot(doc(db, 'system_status', 'billing'), (docSnap) => {
        if (docSnap.exists()) {
          const bData = docSnap.data();
          setBilling({
            costAmount: bData.costAmount || 0,
            budgetAmount: bData.budgetAmount || 0,
            currencyCode: bData.currencyCode || 'USD',
          });
        }
      }, (err) => {
        console.error("Billing Error:", err);

      });

      // 3. System Health (Open Support Tickets as a proxy for Critical Errors)
      unsubTickets = onSnapshot(query(collection(db, 'support_tickets'), where('status', 'in', ['Open', 'In Progress'])), (snap) => {
        try {
          setStats(s => ({ ...s, criticalErrors: snap.size }));
        } catch(e) { console.error('MissionDashboard tickets processing error:', e); }
      }, (err) => {
        console.error("Tickets Error in Dashboard:", err);

      });

      // 4. Firebase Cost Proxy
      const qLogs = query(collection(db, 'mission_logs'), orderBy('timestamp', 'desc'), limit(100));
      unsubLogs = onSnapshot(qLogs, (snap) => {
        try {
          setStats(s => ({ 
            ...s, 
            firebaseCost: (snap.size * 0.05).toFixed(2) // Rough estimate proxy
          }));
        } catch(e) { console.error('MissionDashboard logs processing error:', e); }
      }, (err) => {
        console.error("Logs Error in Dashboard:", err);
      });

    } catch(e) {
      console.warn("Mission Dashboard Listener Error:", e);
    }

    return () => {
      try { unsubTelemetry(); } catch(e) {}
      try { unsubContractors(); } catch(e) {}
      try { unsubTickets(); } catch(e) {}
      try { unsubLogs(); } catch(e) {}
    };
  }, []);

  // Compute Mission Health Score and Owner Insights
  useEffect(() => {
    let score = 100;
    const insightsList = [];
    
    if (stats.criticalErrors > 0) {
      score -= Math.min(stats.criticalErrors * 5, 40);
      insightsList.push({ type: 'danger', text: `${stats.criticalErrors} open support tickets impacting health.`});
    }
    
    if (stats.onlineUsers > 5) {
      score += 5;
      insightsList.push({ type: 'success', text: `High concurrency! ${stats.onlineUsers} active sessions right now.`});
    } else if (stats.onlineUsers === 0) {
      score -= 5;
      insightsList.push({ type: 'warning', text: `Zero online users detected.`});
    }
    
    if (stats.newCompaniesThisWeek > 0) {
      insightsList.push({ type: 'success', text: `Growth alert: ${stats.newCompaniesThisWeek} new contractors onboarded this week.`});
    }
    
    if (stats.premiumContractors > stats.freeContractors && stats.freeContractors > 0) {
      insightsList.push({ type: 'success', text: `Premium tier dominates the user base (${stats.premiumContractors} vs ${stats.freeContractors}).`});
    }

    setStats(s => ({ ...s, missionHealthScore: Math.min(Math.max(score, 0), 100) }));
    setInsights(insightsList);
    
  }, [stats.criticalErrors, stats.onlineUsers, stats.newCompaniesThisWeek, stats.premiumContractors, stats.freeContractors]);

  return (
    <div className="space-y-6 pb-10">
      <div className="flex items-center justify-between border-b border-trackops-border pb-4">
        <h1 className="text-2xl font-bold tracking-widest text-white uppercase flex items-center">
          <Activity className="w-6 h-6 mr-3 text-trackops-green animate-pulse" />
          Mission Control Center
        </h1>
        <div className={`px-4 py-2 rounded-full border flex items-center font-bold font-mono tracking-widest ${
          stats.missionHealthScore >= 90 ? 'bg-trackops-green/10 text-trackops-green border-trackops-green' :
          stats.missionHealthScore >= 70 ? 'bg-trackops-amber/10 text-trackops-amber border-trackops-amber' :
          'bg-trackops-red/10 text-trackops-red border-trackops-red animate-pulse'
        }`}>
          <HeartPulse className="w-5 h-5 mr-2" />
          Health: {stats.missionHealthScore}/100
        </div>
      </div>

      {/* Row 1: Core Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Live Users" value={stats.onlineUsers} icon={Users} color="text-trackops-green" />
        <StatCard title="Active Companies" value={stats.companiesActive} icon={Server} color="text-trackops-steel" />
        <StatCard title="Total Revenue" value={`₹${stats.revenue}`} icon={DollarSign} color="text-trackops-green" />
        
        {/* Real-Time Billing Card */}
        <div className="bg-navy border border-white/5 rounded-xl p-5 hover:border-white/20 transition-all group">
          <div className="flex items-start justify-between">
            <div className="p-3 rounded-lg bg-red-500/10 text-red-400 group-hover:scale-110 transition-transform">
              <CloudLightning size={24} />
            </div>
            {billing.budgetAmount > 0 && (
              <div className={`text-xs font-bold px-2 py-1 rounded-full ${billing.costAmount >= billing.budgetAmount ? 'bg-red-500/20 text-red-400' : 'bg-green-500/20 text-green-400'}`}>
                {((billing.costAmount / billing.budgetAmount) * 100).toFixed(0)}% Used
              </div>
            )}
          </div>
          <div className="mt-4">
            <h3 className="text-white/50 font-medium text-sm">GCP Billing (Live)</h3>
            <div className="flex items-end gap-2 mt-1">
              <p className="text-3xl font-black text-white">{billing.currencyCode === 'INR' ? '₹' : '$'}{billing.costAmount.toFixed(2)}</p>
              {billing.budgetAmount > 0 && (
                <p className="text-white/40 text-sm mb-1">/ {billing.budgetAmount}</p>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Row 2: Product Usage & Support */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Attendance Synced" value={stats.attendanceToday.toLocaleString()} icon={CheckCircle2} color="text-trackops-navy" />
        <StatCard title="Reports Exported" value={stats.reportsGenerated} icon={TrendingUp} color="text-trackops-navy" />
        <StatCard title="Unresolved Issues" value={stats.criticalErrors} icon={ShieldAlert} color={stats.criticalErrors > 0 ? "text-trackops-red animate-pulse" : "text-trackops-green"} />
        <StatCard title="Premium Subscriptions" value={stats.premiumContractors} icon={Activity} color="text-trackops-amber" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-6">
        
        {/* Left Column: Live Feed */}
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-trackops-card border border-trackops-border p-4 rounded-md font-mono relative overflow-hidden min-h-[300px]">
            {/* Radar Effect background */}
            <div className="absolute top-0 right-0 p-8 opacity-10 pointer-events-none">
              <div className="w-32 h-32 rounded-full border-2 border-trackops-green animate-radar-spin border-t-transparent" />
            </div>

            <h3 className="text-trackops-green text-sm tracking-widest uppercase mb-4 flex items-center">
              <Activity className="w-4 h-4 mr-2" /> Live Activity Feed
            </h3>
            
            <div className="space-y-4">
              {feed.length === 0 ? (
                <div className="text-gray-500 text-sm">Awaiting telemetry...</div>
              ) : (
                feed.map((item) => (
                  <div key={item.id} className="flex text-xs space-x-4 border-b border-trackops-border/50 pb-2 items-start">
                    <div className="text-gray-500 w-12 shrink-0">{item.time}</div>
                    <div className={`
                      ${item.severity === 'CRITICAL' || item.severity === 'ERROR' ? 'text-trackops-red' : ''}
                      ${item.severity === 'SUCCESS' ? 'text-trackops-green' : ''}
                      ${item.severity === 'WARNING' || item.severity === 'SECURITY' ? 'text-trackops-amber' : ''}
                      ${item.severity === 'INFO' ? 'text-gray-300' : ''}
                    `}>
                      {item.text}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

        {/* Right Column: Devices & Insights */}
        <div className="space-y-6">
          {/* Device Analytics */}
          <div className="bg-trackops-card border border-trackops-border p-4 rounded-md font-mono">
            <h3 className="text-gray-400 text-xs tracking-widest uppercase mb-4">Device Distribution</h3>
            <div className="space-y-4">
              <div className="flex justify-between text-sm items-end mb-1">
                <span className="text-gray-300 flex items-center"><Smartphone className="w-4 h-4 mr-2" /> Android</span>
                <span className="text-trackops-green font-bold">{stats.androidUsers}</span>
              </div>
              <div className="w-full bg-trackops-navy h-1.5 rounded overflow-hidden">
                <div className="bg-trackops-green h-full" style={{ width: `${Math.min((stats.androidUsers / Math.max(1, stats.androidUsers + stats.iosUsers)) * 100, 100)}%` }} />
              </div>

              <div className="flex justify-between text-sm items-end mb-1 pt-2">
                <span className="text-gray-300 flex items-center"><Smartphone className="w-4 h-4 mr-2" /> iOS</span>
                <span className="text-trackops-amber font-bold">{stats.iosUsers}</span>
              </div>
              <div className="w-full bg-trackops-navy h-1.5 rounded overflow-hidden">
                <div className="bg-trackops-amber h-full" style={{ width: `${Math.min((stats.iosUsers / Math.max(1, stats.androidUsers + stats.iosUsers)) * 100, 100)}%` }} />
              </div>
            </div>
          </div>

          {/* AI Insights Panel */}
          <div className="bg-trackops-card border border-trackops-border p-4 rounded-md font-mono">
            <h3 className="text-trackops-amber text-xs tracking-widest uppercase mb-4 flex items-center">
              <CloudLightning className="w-4 h-4 mr-2" /> Owner Insights
            </h3>
            <div className="space-y-3 text-xs">
              {insights.length === 0 ? (
                <div className="text-gray-500">System is stable. No critical insights generated.</div>
              ) : (
                insights.map((insight, idx) => (
                  <div key={idx} className={`p-3 border-l-2 ${
                    insight.type === 'danger' ? 'border-trackops-red text-trackops-red' : 
                    insight.type === 'warning' ? 'border-trackops-amber text-trackops-amber' : 
                    'border-trackops-green text-trackops-green'
                  }`}>
                    {insight.text}
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function StatCard({ title, value, icon: Icon, color }) {
  return (
    <div className="bg-trackops-card border border-trackops-border p-4 rounded-md relative overflow-hidden group">
      <div className="flex justify-between items-start mb-2">
        <div className="text-gray-500 text-[10px] uppercase tracking-widest">{title}</div>
        <div className={`p-1.5 rounded bg-trackops-navy ${color}`}>
          <Icon className="w-4 h-4" />
        </div>
      </div>
      <div className="text-2xl font-bold text-white font-mono">{value}</div>
    </div>
  );
}
