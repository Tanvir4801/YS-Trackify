import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import {
  AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell,
} from 'recharts';
import {
  TrendingUp, Users, Building2, AlertCircle, IndianRupee, Activity,
  HardHat, LifeBuoy, ArrowUpRight, Star, Zap,
} from 'lucide-react';
import { getSAKPIs, getPlanBreakdown, getMrrTrend, getAllCustomers } from '../../lib/services/saas.service';

function KpiCard({ label, value, sub, icon: Icon, accent = '#8B5CF6', trend }) {
  return (
    <div className="relative overflow-hidden rounded-2xl border border-white/[0.06] bg-[#13102B] p-5 shadow-sm group hover:border-violet-500/30 transition-all">
      <div className="absolute top-0 right-0 h-24 w-24 rounded-full blur-3xl opacity-20" style={{ background: accent }} />
      <div className="relative">
        <div className="flex items-center justify-between mb-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl border" style={{ borderColor: `${accent}40`, background: `${accent}15` }}>
            <Icon className="h-4 w-4" style={{ color: accent }} />
          </div>
          {trend && (
            <span className="flex items-center gap-1 text-[11px] font-semibold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded-full">
              <ArrowUpRight className="h-3 w-3" /> {trend}
            </span>
          )}
        </div>
        <p className="text-[11px] font-medium uppercase tracking-widest text-text-muted">{label}</p>
        <p className="mt-1 text-2xl font-mono font-bold text-text-primary">{value}</p>
        {sub && <p className="mt-1 text-[11px] text-text-muted">{sub}</p>}
      </div>
    </div>
  );
}

function fmt(n) {
  if (n >= 100000) return `₹${(n / 100000).toFixed(1)}L`;
  if (n >= 1000) return `₹${(n / 1000).toFixed(1)}K`;
  return `₹${n}`;
}

const CustomTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-white/[0.06] bg-[#13102B] px-3 py-2 text-xs shadow-lg">
      <p className="font-medium text-violet-300 mb-1">{label}</p>
      <p className="text-text-primary">MRR: <span className="font-mono font-bold">{fmt(payload[0]?.value)}</span></p>
      <p className="text-text-secondary">Customers: <span className="font-mono">{payload[1]?.value}</span></p>
    </div>
  );
};

export default function SADashboard() {
  const [mrrTrend, setMrrTrend] = useState([]);
  useEffect(() => {
    getMrrTrend().then(setMrrTrend);
  }, []);

  const [allCustomers, setAllCustomers] = useState([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  useEffect(() => {
    getAllCustomers().then(data => {
      setAllCustomers(data);
      setLoadingCustomers(false);
    });
  }, []);

  const [kpi, setKpi] = useState({ mrr: 0, arr: 0, active: 0, trial: 0, expired: 0, totalLabours: 0, totalSites: 0, pending: 0 });
  const [plans, setPlans] = useState([]);
  const [topCustomers, setTopCustomers] = useState([]);

  useEffect(() => {
    getSAKPIs().then(setKpi);
    getPlanBreakdown().then(setPlans);
  }, []);

  useEffect(() => {
    setTopCustomers([...allCustomers].filter(c => c.status === 'active').sort((a, b) => b.mrr - a.mrr).slice(0, 5));
  }, [allCustomers]);


  
  
  

  return (
    <div className="space-y-6">
      {/* KPI Grid */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KpiCard label="Monthly Recurring Revenue" value={fmt(kpi.mrr)} sub={`ARR: ${fmt(kpi.arr)}`} icon={IndianRupee} accent="#8B5CF6" trend="+8.4%" />
        <KpiCard label="Active Companies" value={kpi.active} sub={`${kpi.trial} on trial · ${kpi.expired} expired`} icon={Building2} accent="#F5A623" trend="+2 this mo" />
        <KpiCard label="Total Labours Tracked" value={kpi.totalLabours.toLocaleString()} sub={`Across ${kpi.totalSites} active sites`} icon={HardHat} accent="#10B981" trend="+12%" />
        <KpiCard label="Pending Payments" value={fmt(kpi.pending)} sub="Awaiting collection" icon={AlertCircle} accent="#EF4444" />
      </div>

      {/* Charts row */}
      <div className="grid gap-4 lg:grid-cols-3">
        {/* MRR Trend */}
        <div className="lg:col-span-2 rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
          <p className="text-sm font-semibold text-text-primary mb-1">MRR Growth — 2026</p>
          <p className="text-[11px] text-text-muted mb-4">Monthly Recurring Revenue trend</p>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={mrrTrend} margin={{ top: 4, right: 4, left: 4, bottom: 0 }}>
              <defs>
                <linearGradient id="gradMrr" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#8B5CF6" stopOpacity={0.35} />
                  <stop offset="95%" stopColor="#8B5CF6" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="month" tick={{ fill: '#64748B', fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis hide />
              <Tooltip cursor={{ fill: 'transparent' }} content={<CustomTooltip />} />
              <Area type="monotone" dataKey="mrr" stroke="#8B5CF6" strokeWidth={2.5} fill="url(#gradMrr)" />
              <Area type="monotone" dataKey="customers" stroke="#F5A623" strokeWidth={1.5} fill="none" strokeDasharray="4 3" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Plan Breakdown */}
        <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
          <p className="text-sm font-semibold text-text-primary mb-1">Plan Breakdown</p>
          <p className="text-[11px] text-text-muted mb-2">Active subscribers by tier</p>
          <ResponsiveContainer width="100%" height={140}>
            <PieChart>
              <Pie data={plans.filter(p => p.value > 0)} stroke="none" cx="50%" cy="50%" innerRadius={45} outerRadius={65} paddingAngle={3} dataKey="value">
                {plans.map((p, i) => <Cell key={i} fill={p.color} />)}
              </Pie>
              <Tooltip cursor={{ fill: 'transparent' }} formatter={(v, n) => [v + ' companies', n]} contentStyle={{ background: '#13102B', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 8 }} itemStyle={{ color: '#E2E8F0', fontSize: 12 }} />
            </PieChart>
          </ResponsiveContainer>
          <div className="mt-3 space-y-2">
            {plans.map(p => (
              <div key={p.name} className="flex items-center justify-between text-[12px]">
                <div className="flex items-center gap-2">
                  <div className="h-2 w-2 rounded-full" style={{ background: p.color }} />
                  <span className="text-text-secondary">{p.name}</span>
                </div>
                <span className="font-mono font-medium text-text-primary">{p.value} co · ₹{p.price}/mo</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Top Customers + Quick Stats */}
      <div className="grid gap-4 lg:grid-cols-3">
        {/* Top Customers */}
        <div className="lg:col-span-2 rounded-2xl border border-white/[0.06] bg-[#13102B] overflow-hidden">
          <div className="flex items-center gap-2 border-b border-white/[0.06] px-5 py-4">
            <Star className="h-4 w-4 text-violet-400" />
            <p className="text-sm font-semibold text-text-primary">Top Customers by Revenue</p>
          </div>
          <div className="divide-y divide-white/[0.04]">
            {topCustomers.map((c, i) => (
              <Link to={`/sa/customers/${c.id}`} key={c.id} className="flex items-center gap-4 px-5 py-3.5 hover:bg-violet-500/5 transition-colors group">
                <span className="text-[13px] font-mono font-bold text-text-muted w-5">{i + 1}</span>
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-violet-500/10 border border-violet-500/20 text-[12px] font-bold text-violet-300">
                  {c.name.slice(0, 2).toUpperCase()}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-[13px] font-medium text-text-primary truncate group-hover:text-violet-300 transition-colors">{c.name}</p>
                  <p className="text-[11px] text-text-muted">{c.sites} sites · {c.labours} labours · {c.city}</p>
                </div>
                <div className="text-right">
                  <p className="text-[13px] font-mono font-bold text-violet-300">₹{c.mrr.toLocaleString()}/mo</p>
                  <span className={`text-[10px] font-semibold uppercase px-1.5 py-0.5 rounded-full ${c.plan === 'enterprise' ? 'bg-violet-500/20 text-violet-300' : c.plan === 'professional' ? 'bg-gold-bg text-gold' : 'bg-bg-elevated text-text-muted'}`}>
                    {c.plan}
                  </span>
                </div>
              </Link>
            ))}
          </div>
          <div className="px-5 py-3 border-t border-white/[0.06]">
            <Link to="/sa/customers" className="text-[12px] text-violet-400 hover:text-violet-300 font-medium flex items-center gap-1">
              View all {kpi.total} companies <ArrowUpRight className="h-3 w-3" />
            </Link>
          </div>
        </div>

        {/* Quick Stats */}
        <div className="space-y-3">
          {[
            { label: 'Today\'s Revenue', value: fmt(kpi.todayRev), icon: IndianRupee, color: '#10B981' },
            { label: 'Open Support Tickets', value: '7', icon: LifeBuoy, color: '#EF4444' },
            { label: 'Renewals This Month', value: '9', icon: Activity, color: '#F5A623' },
            { label: 'New Sign-ups (July)', value: '2', icon: Users, color: '#8B5CF6' },
            { label: 'Total Revenue (Lifetime)', value: '₹5.8L', icon: TrendingUp, color: '#3B82F6' },
          ].map(stat => (
            <div key={stat.label} className="flex items-center gap-3 rounded-xl border border-white/[0.06] bg-[#13102B] px-4 py-3">
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg" style={{ background: `${stat.color}15`, border: `1px solid ${stat.color}30` }}>
                <stat.icon className="h-4 w-4" style={{ color: stat.color }} />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-[11px] text-text-muted leading-tight">{stat.label}</p>
                <p className="text-[15px] font-mono font-bold text-text-primary">{stat.value}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
