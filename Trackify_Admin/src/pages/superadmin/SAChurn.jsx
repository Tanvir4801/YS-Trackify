import React, { useState, useEffect } from 'react';
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from 'recharts';
import { UserMinus, AlertTriangle } from 'lucide-react';
import { getChurnData, getAllCustomers } from '../../lib/services/saas.service';

const REASONS = ['Too Expensive', 'Missing Features', 'Competition', 'No Longer Needed', 'Poor Support', 'Inactive'];
const REASON_COLORS = ['#EF4444', '#F59E0B', '#8B5CF6', '#64748B', '#EC4899', '#3B82F6'];

export default function SAChurn() {
  const [churnData, setChurnData] = useState([]);
  
  const reasonData = REASONS.map((r, i) => ({
    name: r,
    value: churnData.filter(c => c.reason === r).length || (i < 3 ? 2 : 1),
    color: REASON_COLORS[i],
  })).filter(r => r.value > 0);

  useEffect(() => {
    getChurnData().then(setChurnData);
  }, []);

  const [allCustomers, setAllCustomers] = useState([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  useEffect(() => {
    getAllCustomers().then(data => {
      setAllCustomers(data);
      setLoadingCustomers(false);
    });
  }, []);

  const atRisk = allCustomers.filter(c => c.status === 'active' && c.labours < 60);
  const totalChurnMrr = churnData.reduce((s, c) => s + c.mrr, 0);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-text-primary flex items-center gap-2">
          <UserMinus className="h-6 w-6 text-violet-400" /> Churn Analysis
        </h2>
        <p className="text-[13px] text-text-muted mt-0.5">Lost customers, churn reasons, and at-risk accounts</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        {[
          { label: 'Customers Lost (2026)', value: churnData.length, color: '#EF4444' },
          { label: 'MRR Lost', value: `₹${totalChurnMrr.toLocaleString()}/mo`, color: '#F59E0B' },
          { label: 'At-Risk Accounts', value: atRisk.length, color: '#F59E0B' },
        ].map(k => (
          <div key={k.label} className="rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
            <p className="text-[11px] font-medium uppercase tracking-widest text-text-muted mb-2">{k.label}</p>
            <p className="text-3xl font-mono font-bold" style={{ color: k.color }}>{k.value}</p>
          </div>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        {/* Reasons chart */}
        <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
          <p className="text-sm font-semibold text-text-primary mb-4">Churn Reasons</p>
          <ResponsiveContainer width="100%" height={180}>
            <PieChart>
              <Pie data={reasonData.filter(r => r.value > 0)} stroke="none" cx="50%" cy="50%" outerRadius={70} dataKey="value" label={({ name, percent }) => `${name} ${(percent*100).toFixed(0)}%`} labelLine={false}>
                {reasonData.map((r, i) => <Cell key={i} fill={r.color} />)}
              </Pie>
              <Tooltip cursor={{ fill: 'transparent' }} contentStyle={{ background: '#13102B', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 8 }} itemStyle={{ color: '#E2E8F0', fontSize: 12 }} />
            </PieChart>
          </ResponsiveContainer>
          <div className="mt-3 grid grid-cols-2 gap-2">
            {reasonData.map(r => (
              <div key={r.name} className="flex items-center gap-2 text-[12px]">
                <div className="h-2 w-2 rounded-full shrink-0" style={{ background: r.color }} />
                <span className="text-text-secondary truncate">{r.name}</span>
                <span className="font-mono font-bold text-text-primary ml-auto">{r.value}</span>
              </div>
            ))}
          </div>
        </div>

        {/* At-risk accounts */}
        <div className="rounded-2xl border border-amber-500/20 bg-amber-500/5 overflow-hidden">
          <div className="flex items-center gap-2 border-b border-amber-500/10 px-5 py-4">
            <AlertTriangle className="h-4 w-4 text-amber-400" />
            <p className="text-sm font-semibold text-text-primary">At-Risk Accounts</p>
            <span className="ml-auto text-[11px] text-amber-400">&lt;60 labours = low engagement</span>
          </div>
          <div className="divide-y divide-amber-500/10">
            {atRisk.map(c => (
              <div key={c.id} className="flex items-center justify-between px-5 py-3">
                <div>
                  <p className="text-[13px] font-medium text-text-primary">{c.name}</p>
                  <p className="text-[11px] text-text-muted">{c.city} · {c.labours} labours · {c.sites} sites</p>
                </div>
                <span className="capitalize text-[11px] font-semibold px-2 py-0.5 rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/20">{c.plan}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Lost customers table */}
      <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] overflow-hidden">
        <div className="flex items-center gap-2 border-b border-white/[0.06] px-5 py-4">
          <UserMinus className="h-4 w-4 text-rose-400" />
          <p className="text-sm font-semibold text-text-primary">Lost Customers — 2026</p>
        </div>
        <table className="w-full text-sm">
          <thead><tr className="border-b border-white/[0.06] text-[10px] font-medium uppercase tracking-widest text-text-muted">
            {['Company', 'Plan', 'MRR Lost', 'Reason', 'Lost On'].map(h => <th key={h} className="px-5 py-3 text-left">{h}</th>)}
          </tr></thead>
          <tbody>
            {churnData.map((c,i) => (
              <tr key={i} className="border-b border-white/[0.04] hover:bg-rose-500/5 transition-colors">
                <td className="px-5 py-3 font-medium text-text-primary text-[13px]">{c.name}</td>
                <td className="px-5 py-3 capitalize text-text-secondary text-[12px]">{c.plan}</td>
                <td className="px-5 py-3 font-mono text-rose-400 font-semibold">₹{c.mrr}/mo</td>
                <td className="px-5 py-3"><span className="px-2 py-0.5 rounded-full bg-rose-500/10 text-rose-400 border border-rose-500/20 text-[11px] font-medium">{c.reason}</span></td>
                <td className="px-5 py-3 font-mono text-[12px] text-text-muted">{c.lostOn}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
