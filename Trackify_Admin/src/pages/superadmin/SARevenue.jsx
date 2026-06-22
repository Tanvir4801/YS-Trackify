import React, { useMemo, useState } from 'react';
import {
  AreaChart, Area, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend,
} from 'recharts';
import { IndianRupee, TrendingUp, Download, FileText, CheckCircle, Clock, XCircle } from 'lucide-react';
import { getRevenueTransactions, getMrrTrend, getPlanBreakdown } from '../../lib/services/saas.service';

const STATUS_STYLES = {
  paid:    { cls: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20', label: 'Paid' },
  pending: { cls: 'bg-amber-500/10 text-amber-400 border-amber-500/20',       label: 'Pending' },
  failed:  { cls: 'bg-rose-500/10 text-rose-400 border-rose-500/20',          label: 'Failed' },
};

const TYPE_STYLES = {
  subscription: { cls: 'bg-violet-500/10 text-violet-300', label: 'Subscription' },
  setup_fee:    { cls: 'bg-blue-500/10 text-blue-300',     label: 'Setup Fee' },
  refund:       { cls: 'bg-rose-500/10 text-rose-300',     label: 'Refund' },
};

export default function SARevenue() {
  const [revenueTransactions, setRevenueTransactions] = useState([]);
  const [mrrTrend, setMrrTrend] = useState([]);
  useEffect(() => {
    getRevenueTransactions().then(setRevenueTransactions);
    getMrrTrend().then(setMrrTrend);
  }, []);

  const [filter, setFilter] = useState('all');
  const [plans, setPlans] = useState([]);
  
  React.useEffect(() => {
    getPlanBreakdown().then(setPlans);
  }, []);

  const totalPaid    = revenueTransactions.filter(t => t.status === 'paid').reduce((s, t) => s + t.amount, 0);
  const totalGst     = revenueTransactions.filter(t => t.status === 'paid').reduce((s, t) => s + t.gst, 0);
  const totalPending = revenueTransactions.filter(t => t.status === 'pending').reduce((s, t) => s + t.amount, 0);
  const totalFailed  = revenueTransactions.filter(t => t.status === 'failed').reduce((s, t) => s + t.amount, 0);

  const filtered = filter === 'all' ? revenueTransactions : revenueTransactions.filter(t => t.status === filter);

  const monthlyBar = mrrTrend.map(m => ({ month: m.month, revenue: m.mrr, gst: Math.round(m.mrr * 0.18) }));

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-text-primary flex items-center gap-2">
          <IndianRupee className="h-6 w-6 text-violet-400" /> Financial Dashboard
        </h2>
        <p className="text-[13px] text-text-muted mt-0.5">Revenue, GST, and transaction history</p>
      </div>

      {/* KPI row */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {[
          { label: 'Total Collected', value: `₹${totalPaid.toLocaleString()}`, sub: `+GST ₹${totalGst.toLocaleString()}`, color: '#10B981', icon: CheckCircle },
          { label: 'Pending', value: `₹${totalPending.toLocaleString()}`, sub: 'Awaiting payment', color: '#F59E0B', icon: Clock },
          { label: 'Failed / Retry', value: `₹${totalFailed.toLocaleString()}`, sub: 'Requires follow-up', color: '#EF4444', icon: XCircle },
          { label: 'Total Transactions', value: revenueTransactions.length, sub: 'All time', color: '#8B5CF6', icon: FileText },
        ].map(k => (
          <div key={k.label} className="relative overflow-hidden rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
            <div className="absolute top-0 right-0 h-20 w-20 rounded-full blur-3xl opacity-20" style={{ background: k.color }} />
            <div className="flex items-center gap-2 mb-3">
              <k.icon className="h-4 w-4" style={{ color: k.color }} />
              <p className="text-[11px] font-medium uppercase tracking-widest text-text-muted">{k.label}</p>
            </div>
            <p className="text-2xl font-mono font-bold text-text-primary">{k.value}</p>
            <p className="text-[11px] text-text-muted mt-1">{k.sub}</p>
          </div>
        ))}
      </div>

      {/* Charts */}
      <div className="grid gap-4 lg:grid-cols-3">
        <div className="lg:col-span-2 rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
          <p className="text-sm font-semibold text-text-primary mb-1">Monthly Revenue vs GST</p>
          <p className="text-[11px] text-text-muted mb-4">Collected revenue and GST component per month</p>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={monthlyBar} barCategoryGap="35%">
              <XAxis dataKey="month" tick={{ fill: '#64748B', fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis hide />
              <Tooltip cursor={{ fill: 'transparent' }} contentStyle={{ background: '#13102B', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 8 }} itemStyle={{ color: '#E2E8F0', fontSize: 12 }} formatter={(v) => [`₹${v.toLocaleString()}`, '']} />
              <Bar dataKey="revenue" fill="#8B5CF6" radius={[4, 4, 0, 0]} />
              <Bar dataKey="gst" fill="#F5A623" radius={[4, 4, 0, 0]} />
              <Legend formatter={(v) => <span className="text-[11px] text-text-muted capitalize">{v}</span>} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
          <p className="text-sm font-semibold text-text-primary mb-4">Revenue by Plan</p>
          <ResponsiveContainer width="100%" height={150}>
            <PieChart>
              <Pie data={plans.filter(p => p.value > 0)} stroke="none" cx="50%" cy="50%" outerRadius={60} dataKey="value">
                {plans.map((p, i) => <Cell key={i} fill={p.color} />)}
              </Pie>
              <Tooltip cursor={{ fill: 'transparent' }} contentStyle={{ background: '#13102B', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 8 }} itemStyle={{ color: '#E2E8F0', fontSize: 12 }} />
            </PieChart>
          </ResponsiveContainer>
          <div className="mt-3 space-y-2">
            {plans.map(p => (
              <div key={p.name} className="flex justify-between text-[12px]">
                <span className="flex items-center gap-1.5 text-text-secondary"><span className="h-2 w-2 rounded-full inline-block" style={{ background: p.color }} />{p.name}</span>
                <span className="font-mono text-text-primary">₹{(p.value * p.price).toLocaleString()}/mo</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Transactions Table */}
      <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-white/[0.06] px-5 py-4">
          <div className="flex items-center gap-2">
            <TrendingUp className="h-4 w-4 text-violet-400" />
            <p className="text-sm font-semibold text-text-primary">Transactions</p>
          </div>
          <div className="flex gap-2">
            {['all', 'paid', 'pending', 'failed'].map(f => (
              <button key={f} onClick={() => setFilter(f)}
                className={`px-3 py-1 rounded-lg text-[12px] font-medium capitalize transition-all ${filter === f ? 'bg-violet-500/20 text-violet-300 border border-violet-500/30' : 'text-text-muted hover:text-text-primary hover:bg-bg-elevated border border-transparent'}`}>
                {f}
              </button>
            ))}
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="border-b border-white/[0.06]">
              <tr className="text-[10px] font-medium uppercase tracking-widest text-text-muted">
                {['Date', 'Contractor', 'Type', 'Amount', 'GST', 'Invoice', 'Status'].map(h => (
                  <th key={h} className="px-5 py-3 text-left font-medium">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map(t => {
                const ss = STATUS_STYLES[t.status] || STATUS_STYLES.pending;
                const ts = TYPE_STYLES[t.type] || TYPE_STYLES.subscription;
                return (
                  <tr key={t.id} className="border-b border-white/[0.04] hover:bg-violet-500/5 transition-colors">
                    <td className="px-5 py-3 font-mono text-[12px] text-text-muted">{t.date}</td>
                    <td className="px-5 py-3 font-medium text-text-primary text-[13px]">{t.contractorName}</td>
                    <td className="px-5 py-3"><span className={`px-2 py-0.5 rounded-full text-[11px] font-medium ${ts.cls}`}>{ts.label}</span></td>
                    <td className="px-5 py-3 font-mono font-semibold text-text-primary">₹{t.amount.toLocaleString()}</td>
                    <td className="px-5 py-3 font-mono text-[12px] text-text-muted">₹{t.gst.toLocaleString()}</td>
                    <td className="px-5 py-3"><span className="font-mono text-[11px] text-text-muted">{t.invoiceNo}</span></td>
                    <td className="px-5 py-3">
                      <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-semibold border ${ss.cls}`}>{ss.label}</span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
