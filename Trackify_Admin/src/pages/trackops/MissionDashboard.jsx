import React, { useEffect, useState } from 'react';
import { collection, onSnapshot, query, limit, orderBy, where } from 'firebase/firestore';
import { Activity, Server, Users, DollarSign, CloudLightning, ShieldAlert, Smartphone, TrendingUp, HeartPulse, CheckCircle2, Clock } from 'lucide-react';
import { db } from '../../lib/firebase';
import { useTrackOpsAnalytics, useTrackOpsBilling } from '../../lib/services/trackopsQueryService';
import FreshnessIndicator from '../../components/ui/FreshnessIndicator';
import { useTrackOpsMonitoring } from '../../context/TrackOpsMonitoringContext';
import CostOptimizerCard from './components/CostOptimizerCard';
import { getDocs } from 'firebase/firestore';

export default function MissionDashboard() {
  const [stats, setStats] = useState({
    onlineUsers: 0,
    attendanceToday: 0,
    reportsGenerated: 0,
    criticalErrors: 0,
    openTickets: 0,
    iosUsers: 0,
    androidUsers: 0,
    missionHealthScore: 100,
  });

  const [feed, setFeed] = useState([]);
  const [insights, setInsights] = useState([]);

  // Master Control Context
  const { isMonitoringActive, lastStoppedAt, monitoringEnabled } = useTrackOpsMonitoring();
  const [awaySummary, setAwaySummary] = useState(null);

  // React Query for Analytics and Billing (Polled)
  const { data: analyticsData, isFetching: isFetchingAnalytics, refetch: refetchAnalytics, dataUpdatedAt: analyticsUpdatedAt } = useTrackOpsAnalytics();
  const { data: billingData, isFetching: isFetchingBilling, refetch: refetchBilling, dataUpdatedAt: billingUpdatedAt } = useTrackOpsBilling();

  useEffect(() => {
    let unsubTelemetry = () => {};
    let unsubTickets = () => {};

    if (!isMonitoringActive) {
      return () => {};
    }

    try {
      // 1. Live Users & Device Analytics from Telemetry
      const tenMinsAgo = new Date(Date.now() - 10 * 60000);
      const qTel = query(collection(db, 'telemetry_events'), orderBy('timestamp', 'desc'), limit(100));
      unsubTelemetry = onSnapshot(qTel, (snap) => {
        try {
          const recentUsers = new Set();
          const iosUsersSet = new Set();
          const androidUsersSet = new Set();
          let attCount = 0;
          let repCount = 0;
          const liveFeed = [];

          snap.forEach(doc => {
            const data = doc.data();
            
            // Online counting
            if (data.userId && data.timestamp && data.timestamp.toDate() > tenMinsAgo) {
              recentUsers.add(data.userId);
            }

            // Device counts (only count unique users)
            if (data.userId && data.platform?.toLowerCase().includes('ios')) iosUsersSet.add(data.userId);
            if (data.userId && data.platform?.toLowerCase().includes('android')) androidUsersSet.add(data.userId);

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
            iosUsers: iosUsersSet.size, 
            androidUsers: androidUsersSet.size,
            attendanceToday: attCount * 5, // Simulation multiplier
            reportsGenerated: repCount
          }));
        } catch(e) { console.error('MissionDashboard telemetry processing error:', e); }
      }, (err) => {
        console.error("Telemetry Error in Dashboard:", err);

      }, (err) => {
        console.error("Telemetry Error in Dashboard:", err);
      });

      // 2. System Health (Open Support Tickets as a proxy for Critical Errors)
      unsubTickets = onSnapshot(query(collection(db, 'support_tickets'), where('status', 'in', ['Open', 'In Progress'])), (snap) => {
        try {
          setStats(s => ({ ...s, criticalErrors: snap.size }));
        } catch(e) { console.error('MissionDashboard tickets processing error:', e); }
      }, (err) => {
        console.error("Tickets Error in Dashboard:", err);
      });

    } catch(e) {
      console.warn("Mission Dashboard Listener Error:", e);
    }

    return () => {
      try { unsubTelemetry(); } catch(e) {}
      try { unsubTickets(); } catch(e) {}
    };
  }, [isMonitoringActive]);

  // "While you were away" fetcher
  useEffect(() => {
    if (isMonitoringActive && lastStoppedAt && monitoringEnabled) {
      const fetchAwayStats = async () => {
        try {
          const t = new Date(lastStoppedAt);
          // Only fetch tickets to show the example "12 new support tickets"
          const snap = await getDocs(query(collection(db, 'support_tickets'), where('createdAt', '>', t)));
          if (!snap.empty) {
            setAwaySummary({ tickets: snap.size });
          }
        } catch(e) { console.warn("Failed to fetch away stats", e); }
      };
      fetchAwayStats();
    } else {
      setAwaySummary(null);
    }
  }, [isMonitoringActive, lastStoppedAt, monitoringEnabled]);

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
    
    if (analyticsData?.newCompaniesThisWeek > 0) {
      insightsList.push({ type: 'success', text: `Growth alert: ${analyticsData.newCompaniesThisWeek} new contractors onboarded this week.`});
    }
    
    if (analyticsData?.premiumContractors > analyticsData?.freeContractors && analyticsData?.freeContractors > 0) {
      insightsList.push({ type: 'success', text: `Premium tier dominates the user base (${analyticsData.premiumContractors} vs ${analyticsData.freeContractors}).`});
    }

    setStats(s => ({ ...s, missionHealthScore: Math.min(Math.max(score, 0), 100) }));
    setInsights(insightsList);
    
  }, [stats.criticalErrors, stats.onlineUsers, analyticsData]);

  return (
    <div className="space-y-6 pb-10">
      <CostOptimizerCard />
      
      {awaySummary && (
        <div className="bg-blue-500/10 border border-blue-500/30 p-4 rounded-md font-mono flex items-start gap-3">
          <Clock className="w-5 h-5 text-blue-400 shrink-0 mt-0.5" />
          <div>
            <h3 className="text-blue-400 font-bold uppercase text-sm mb-1">While you were away</h3>
            <p className="text-gray-300 text-xs">
              {awaySummary.tickets || 0} new support tickets were created.
            </p>
          </div>
        </div>
      )}

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

      <div className="flex justify-end mb-4">
        <FreshnessIndicator 
          updatedAt={analyticsUpdatedAt} 
          isFetching={isFetchingAnalytics || isFetchingBilling} 
          onRefresh={() => { refetchAnalytics(); refetchBilling(); }} 
        />
      </div>

      {/* Row 1: Core Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Live Users" value={stats.onlineUsers} icon={Users} color="text-trackops-green" />
        <StatCard title="Active Companies" value={analyticsData?.companiesActive ?? '...'} icon={Server} color="text-trackops-steel" />
        <StatCard title="Total Revenue" value={analyticsData?.revenue !== undefined ? `₹${analyticsData.revenue}` : '...'} icon={DollarSign} color="text-trackops-green" />
        
        {/* Real-Time Billing Card */}
        <div className="bg-navy border border-white/5 rounded-xl p-5 hover:border-white/20 transition-all group">
          <div className="flex items-start justify-between">
            <div className="p-3 rounded-lg bg-red-500/10 text-red-400 group-hover:scale-110 transition-transform">
              <CloudLightning size={24} />
            </div>
            {billingData?.budgetAmount > 0 && (
              <div className={`text-xs font-bold px-2 py-1 rounded-full ${billingData.costAmount >= billingData.budgetAmount ? 'bg-red-500/20 text-red-400' : 'bg-green-500/20 text-green-400'}`}>
                {((billingData.costAmount / billingData.budgetAmount) * 100).toFixed(0)}% Used
              </div>
            )}
          </div>
          <div className="mt-4">
            <h3 className="text-white/50 font-medium text-sm">GCP Billing (Polled)</h3>
            <div className="flex items-end gap-2 mt-1">
              <p className="text-3xl font-black text-white">{billingData?.currencyCode === 'INR' ? '₹' : '$'}{(billingData?.costAmount || 0).toFixed(2)}</p>
              {billingData?.budgetAmount > 0 && (
                <p className="text-white/40 text-sm mb-1">/ {billingData.budgetAmount}</p>
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
        <StatCard title="Premium Subscriptions" value={analyticsData?.premiumContractors ?? '...'} icon={Activity} color="text-trackops-amber" />
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
      <div className="text-2xl font-bold text-white font-mono h-8 flex items-center">
        {value === '...' ? (
          <div className="flex space-x-1 items-end h-5 opacity-70">
            <div className={`w-1.5 h-3 ${color.replace('text-', 'bg-')} animate-pulse`} style={{animationDelay: '0ms'}}></div>
            <div className={`w-1.5 h-5 ${color.replace('text-', 'bg-')} animate-pulse`} style={{animationDelay: '150ms'}}></div>
            <div className={`w-1.5 h-4 ${color.replace('text-', 'bg-')} animate-pulse`} style={{animationDelay: '300ms'}}></div>
            <span className="text-[9px] text-gray-500 ml-2 tracking-widest uppercase mb-0.5 animate-pulse">Awaiting Signal</span>
          </div>
        ) : (
          value
        )}
      </div>
    </div>
  );
}
