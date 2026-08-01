import React, { useState } from 'react';
import { BarChart2, TrendingUp, Cpu, Database, CloudLightning, Activity, AlertCircle, Users, CreditCard } from 'lucide-react';
import { useTrackOpsAnalytics } from '../../lib/services/trackopsQueryService';
import FreshnessIndicator from '../../components/ui/FreshnessIndicator';

export default function UsageAnalytics() {
  const [activeTab, setActiveTab] = useState('features'); // features, firebase, contractors, insights
  
  const { data, isLoading: loading, isFetching, refetch, dataUpdatedAt } = useTrackOpsAnalytics();

  return (
    <div className="space-y-6 pb-10">
      <div className="flex flex-col md:flex-row md:items-center justify-between border-b border-trackops-border pb-4 gap-4">
        <h1 className="text-2xl font-bold tracking-widest text-white uppercase flex items-center">
          <BarChart2 className="w-6 h-6 mr-3 text-trackops-green animate-pulse" />
          Analytics & Insights
        </h1>
        <div className="flex flex-wrap gap-2 font-mono text-sm">
          <FreshnessIndicator updatedAt={dataUpdatedAt} isFetching={isFetching} onRefresh={refetch} />
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
            {activeTab === 'features' && <FeatureAnalytics topFeatures={data?.topFeatures || []} />}
            {activeTab === 'firebase' && <FirebaseAnalytics stats={data?.firebaseStats} />}
            {activeTab === 'contractors' && <ContractorAnalytics stats={data?.contractorStats} />}
            {activeTab === 'insights' && <AIInsights insights={data?.insightsList || []} />}
          </>
        )}
      </div>
    </div>
  );
}

// -------------------------------------------------------------
// Features Tab
// -------------------------------------------------------------
function FeatureAnalytics({ topFeatures }) {
  if (topFeatures.length === 0) {
    return <div className="text-gray-500 font-mono text-center py-10">No telemetry data gathered yet. Open screens in the app to generate data.</div>;
  }

  return (
    <div className="space-y-4 font-mono">
      <h2 className="text-trackops-green tracking-widest uppercase text-sm mb-6">Real-Time Feature Adoption</h2>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {topFeatures.map((feat) => (
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
function FirebaseAnalytics({ stats }) {
  if (!stats) return null;

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
function ContractorAnalytics({ stats }) {
  if (!stats) return null;

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
function AIInsights({ insights }) {

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
