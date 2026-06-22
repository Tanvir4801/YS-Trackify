import React, { useState, useEffect } from 'react';
import { Sparkles, TrendingUp, AlertTriangle, Users, Zap, IndianRupee, HardHat, Activity } from 'lucide-react';
import { getAllCustomers, getSAKPIs } from '../../lib/services/saas.service';

const kpi = getSAKPIs();

const INSIGHTS = [
  {
    type: 'opportunity',
    icon: Activity,
    color: '#8B5CF6',
    title: '45 contractors not using Site Cost Management',
    body: 'This feature is available on all plans but only 28% of companies have used it in the last 30 days. A targeted in-app guide or email campaign could boost stickiness.',
    action: 'Create campaign',
  },
  {
    type: 'alert',
    icon: Users,
    color: '#F59E0B',
    title: '12 companies have crossed 500 labourers',
    body: 'These companies may be outgrowing Starter/Professional plans. Consider reaching out to upgrade them to Enterprise for higher MRR.',
    action: 'View companies',
  },
  {
    type: 'positive',
    icon: TrendingUp,
    color: '#10B981',
    title: '20 customers may renew this week',
    body: 'Based on subscription start dates, 20 active subscribers are approaching their next billing cycle. Ensure invoices are queued.',
    action: 'View renewals',
  },
  {
    type: 'alert',
    icon: AlertTriangle,
    color: '#EF4444',
    title: '8 contractors inactive for 30+ days',
    body: 'These accounts have not had any QR scans or attendance activity in the last 30 days. They are at high churn risk. Send re-engagement messages.',
    action: 'View inactive',
  },
  {
    type: 'opportunity',
    icon: IndianRupee,
    color: '#3B82F6',
    title: 'Revenue forecast: ₹1.2L next month',
    body: 'Based on current MRR of ₹44,990 and 9 renewals due in August, projected revenue for August 2026 is approximately ₹1,20,000 including GST.',
    action: 'View forecast',
  },
  {
    type: 'positive',
    icon: HardHat,
    color: '#EC4899',
    title: '3 companies added 50+ labourers this month',
    body: 'YS Construction, MG Developers, and Raj Constructions have grown their workforce significantly. This signals platform stickiness and a good time to upsell features.',
    action: 'View growth',
  },
  {
    type: 'opportunity',
    icon: Zap,
    color: '#F5A623',
    title: 'PDF download adoption is low (42%)',
    body: 'Only 42% of companies have used PDF report downloads in the last 30 days. Consider adding a prominent download button or sending a feature highlight email.',
    action: 'View analytics',
  },
];

const TYPE_STYLES = {
  positive:    { bg: 'from-emerald-950/40',  border: 'border-emerald-500/20', badge: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20', label: '✅ Positive' },
  opportunity: { bg: 'from-violet-950/40',   border: 'border-violet-500/20',  badge: 'bg-violet-500/10 text-violet-300 border-violet-500/20',    label: '💡 Opportunity' },
  alert:       { bg: 'from-amber-950/30',    border: 'border-amber-500/20',   badge: 'bg-amber-500/10 text-amber-400 border-amber-500/20',       label: '⚠️ Action Needed' },
};

export default function SAInsights() {
  const [allCustomers, setAllCustomers] = useState([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  useEffect(() => {
    getAllCustomers().then(data => {
      setAllCustomers(data);
      setLoadingCustomers(false);
    });
  }, []);

  const [kpi, setKpi] = useState({ mrr: 0, arr: 0, active: 0, trial: 0, expired: 0, totalLabours: 0, totalSites: 0, pending: 0 });
  useEffect(() => {
    getSAKPIs().then(setKpi);
  }, []);


  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-2xl font-bold text-text-primary flex items-center gap-2">
            <Sparkles className="h-6 w-6 text-violet-400" /> AI Insights
          </h2>
          <p className="text-[13px] text-text-muted mt-0.5">Smart suggestions based on platform usage and revenue data</p>
        </div>
        <div className="flex items-center gap-2 rounded-xl border border-violet-500/20 bg-violet-500/10 px-4 py-2">
          <Sparkles className="h-4 w-4 text-violet-400" />
          <span className="text-[12px] font-medium text-violet-300">{INSIGHTS.length} insights today</span>
        </div>
      </div>

      {/* Summary row */}
      <div className="grid gap-4 sm:grid-cols-3">
        {[
          { label: 'Opportunities', count: INSIGHTS.filter(i=>i.type==='opportunity').length, color: '#8B5CF6' },
          { label: 'Action Needed', count: INSIGHTS.filter(i=>i.type==='alert').length,       color: '#F59E0B' },
          { label: 'Positive Signals', count: INSIGHTS.filter(i=>i.type==='positive').length, color: '#10B981' },
        ].map(s => (
          <div key={s.label} className="rounded-xl border border-white/[0.06] bg-[#13102B] px-5 py-4 flex items-center justify-between">
            <p className="text-[12px] text-text-muted">{s.label}</p>
            <p className="text-2xl font-mono font-bold" style={{ color: s.color }}>{s.count}</p>
          </div>
        ))}
      </div>

      {/* Insight cards */}
      <div className="grid gap-4 md:grid-cols-2">
        {INSIGHTS.map((insight, i) => {
          const s = TYPE_STYLES[insight.type];
          return (
            <div key={i} className={`relative overflow-hidden rounded-2xl border ${s.border} bg-gradient-to-br ${s.bg} via-[#13102B] to-[#13102B] p-5`}>
              <div className="absolute top-0 right-0 h-24 w-24 rounded-full blur-3xl opacity-15" style={{ background: insight.color }} />
              <div className="relative">
                <div className="flex items-start justify-between gap-3 mb-3">
                  <div className="flex h-9 w-9 items-center justify-center rounded-xl shrink-0" style={{ background: `${insight.color}15`, border: `1px solid ${insight.color}30` }}>
                    <insight.icon className="h-4 w-4" style={{ color: insight.color }} />
                  </div>
                  <span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold border ${s.badge}`}>{s.label}</span>
                </div>
                <p className="text-[14px] font-semibold text-text-primary mb-2">{insight.title}</p>
                <p className="text-[12px] text-text-secondary leading-relaxed mb-4">{insight.body}</p>
                <button className="text-[12px] font-semibold transition-colors" style={{ color: insight.color }}>
                  {insight.action} →
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Platform stats banner */}
      <div className="relative overflow-hidden rounded-2xl border border-violet-500/20 bg-gradient-to-r from-violet-950/40 via-purple-950/30 to-indigo-950/40 p-6">
        <div className="absolute inset-0 bg-gradient-to-r from-violet-500/5 to-indigo-500/5" />
        <div className="relative">
          <div className="flex items-center gap-2 mb-4">
            <Sparkles className="h-5 w-5 text-violet-400" />
            <p className="text-base font-bold text-text-primary">Trackify Platform Statistics</p>
            <span className="ml-auto text-[11px] text-violet-400">Marketing-ready numbers</span>
          </div>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {[
              { label: 'Total Labours Managed', value: `${kpi.totalLabours.toLocaleString()}+`, icon: '👷' },
              { label: 'Attendance Records', value: '1.2M+', icon: '📋' },
              { label: 'Construction Sites', value: `${kpi.totalSites}+`, icon: '🏗️' },
              { label: 'Salary Processed', value: '₹5 Cr+', icon: '💰' },
            ].map(stat => (
              <div key={stat.label} className="text-center">
                <p className="text-2xl mb-1">{stat.icon}</p>
                <p className="text-xl font-mono font-bold text-violet-300">{stat.value}</p>
                <p className="text-[11px] text-text-muted mt-0.5">{stat.label}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
