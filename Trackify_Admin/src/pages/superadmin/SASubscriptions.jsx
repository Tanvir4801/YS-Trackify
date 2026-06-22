import React, { useState, useEffect, useMemo } from 'react';
import { CreditCard, Calendar, AlertTriangle, CheckCircle } from 'lucide-react';
import { getAllCustomers, getPlanBreakdown } from '../../lib/services/saas.service';
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from 'recharts';

const PLAN_PRICES = { starter: 999, professional: 2499, enterprise: 4999 };
const RENEWAL_DATES = ['2026-08-01', '2026-08-05', '2026-08-10', '2026-08-12', '2026-08-15', '2026-08-18', '2026-08-20', '2026-08-22', '2026-08-25'];

export default function SASubscriptions() {
  const [allCustomers, setAllCustomers] = useState([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  useEffect(() => {
    getAllCustomers().then(data => {
      setAllCustomers(data);
      setLoadingCustomers(false);
    });
  }, []);

  const [plans, setPlans] = useState([]);
  useEffect(() => {
    getPlanBreakdown().then(setPlans);
  }, []);


  
  const active = allCustomers.filter(c => c.status === 'active');
  const trial  = allCustomers.filter(c => c.status === 'trial');
  const expiredList = allCustomers.filter(c => c.status === 'expired' || c.status === 'suspended');

  // Simulate upcoming renewals
  const renewals = active.slice(0, 9).map((c, i) => ({ ...c, renewalDate: RENEWAL_DATES[i] || '2026-08-31' }));

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-text-primary flex items-center gap-2">
          <CreditCard className="h-6 w-6 text-violet-400" /> Subscription Management
        </h2>
        <p className="text-[13px] text-text-muted mt-0.5">Plans, renewals, and subscription status</p>
      </div>

      {/* Plan stats */}
      <div className="grid gap-4 lg:grid-cols-3">
        {plans.map(p => (
          <div key={p.name} className="relative overflow-hidden rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
            <div className="absolute top-0 right-0 h-20 w-20 rounded-full blur-3xl opacity-20" style={{ background: p.color }} />
            <div className="relative">
              <div className="flex items-center justify-between mb-4">
                <span className="text-sm font-bold text-text-primary">{p.name}</span>
                <span className="font-mono text-[13px] font-semibold" style={{ color: p.color }}>₹{p.price}/mo</span>
              </div>
              <p className="text-3xl font-mono font-bold text-text-primary">{p.value}</p>
              <p className="text-[11px] text-text-muted mt-1">active companies</p>
              <p className="text-[12px] text-text-secondary mt-2 font-mono">₹{(p.value * p.price).toLocaleString()} MRR</p>
            </div>
          </div>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        {/* Pie chart */}
        <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
          <p className="text-sm font-semibold text-text-primary mb-4">Distribution</p>
          <ResponsiveContainer width="100%" height={160}>
            <PieChart><Pie data={plans.filter(p => p.value > 0)} stroke="none" cx="50%" cy="50%" outerRadius={65} dataKey="value" paddingAngle={3}>
              {plans.map((p,i) => <Cell key={i} fill={p.color} />)}
            </Pie><Tooltip cursor={{ fill: 'transparent' }} contentStyle={{ background: '#13102B', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 8 }} itemStyle={{ color: '#E2E8F0', fontSize: 12 }} /></PieChart>
          </ResponsiveContainer>
        </div>

        {/* Upcoming renewals */}
        <div className="lg:col-span-2 rounded-2xl border border-white/[0.06] bg-[#13102B] overflow-hidden">
          <div className="flex items-center gap-2 border-b border-white/[0.06] px-5 py-4">
            <Calendar className="h-4 w-4 text-violet-400" />
            <p className="text-sm font-semibold text-text-primary">Renewals — August 2026</p>
            <span className="ml-auto px-2 py-0.5 rounded-full bg-violet-500/10 text-violet-300 text-[11px] font-semibold border border-violet-500/20">{renewals.length} due</span>
          </div>
          <div className="divide-y divide-white/[0.04]">
            {renewals.map(c => (
              <div key={c.id} className="flex items-center justify-between px-5 py-3 hover:bg-violet-500/5 transition-colors">
                <div className="flex items-center gap-3">
                  <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-violet-500/10 text-[10px] font-bold text-violet-300">{c.name.slice(0,2).toUpperCase()}</div>
                  <div>
                    <p className="text-[13px] font-medium text-text-primary">{c.name}</p>
                    <p className="text-[11px] text-text-muted capitalize">{c.plan} · {c.city}</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-[12px] font-mono text-violet-300">₹{PLAN_PRICES[c.plan].toLocaleString()}</p>
                  <p className="text-[11px] text-text-muted">{c.renewalDate}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Trial accounts */}
      <div className="rounded-2xl border border-blue-500/20 bg-blue-500/5 overflow-hidden">
        <div className="flex items-center gap-2 border-b border-blue-500/10 px-5 py-4">
          <AlertTriangle className="h-4 w-4 text-blue-400" />
          <p className="text-sm font-semibold text-text-primary">Trial Accounts ({trial.length})</p>
          <span className="ml-auto text-[11px] text-blue-400">Convert to paid</span>
        </div>
        <div className="divide-y divide-blue-500/10">
          {trial.map(c => (
            <div key={c.id} className="flex items-center justify-between px-5 py-3">
              <div>
                <p className="text-[13px] font-medium text-text-primary">{c.name}</p>
                <p className="text-[11px] text-text-muted">{c.owner} · {c.city} · {c.labours} labours</p>
              </div>
              <button className="px-3 py-1.5 rounded-xl bg-violet-500/20 text-violet-300 text-[12px] font-semibold border border-violet-500/30 hover:bg-violet-500/30 transition-colors">
                Upgrade Plan
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Expired/Suspended */}
      <div className="rounded-2xl border border-rose-500/20 bg-rose-500/5 overflow-hidden">
        <div className="flex items-center gap-2 border-b border-rose-500/10 px-5 py-4">
          <AlertTriangle className="h-4 w-4 text-rose-400" />
          <p className="text-sm font-semibold text-text-primary">Expired / Suspended ({expiredList.length})</p>
        </div>
        <div className="divide-y divide-rose-500/10">
          {expiredList.map(c => (
            <div key={c.id} className="flex items-center justify-between px-5 py-3">
              <div>
                <p className="text-[13px] font-medium text-text-primary">{c.name}</p>
                <p className="text-[11px] text-text-muted capitalize">{c.status} · {c.city}</p>
              </div>
              <span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold border ${c.status==='expired'?'bg-rose-500/10 text-rose-400 border-rose-500/20':'bg-red-900/20 text-red-400 border-red-500/20'}`}>{c.status}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
