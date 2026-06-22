import React, { useState, useEffect } from 'react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts';
import { TrendingUp, ArrowUpRight } from 'lucide-react';
import { getAllCustomers, getMrrTrend } from '../../lib/services/saas.service';

export default function SAGrowth() {
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

  const GROWTH_DATA = mrrTrend.map((m, i) => ({
    ...m,
    newCustomers: [1, 1, 1, 1, 1, 1, 2][i] || 0,
    churned: [0, 0, 0, 0, 1, 0, 0][i] || 0,
  }));

  const active = allCustomers.filter(c => c.status === 'active');
  const topBySites    = [...active].sort((a,b) => b.sites - a.sites).slice(0, 5);
  const topByLabours  = [...active].sort((a,b) => b.labours - a.labours).slice(0, 5);
  const topByRevenue  = [...active].sort((a,b) => b.mrr - a.mrr).slice(0, 5);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-text-primary flex items-center gap-2">
          <TrendingUp className="h-6 w-6 text-violet-400" /> Contractor Growth
        </h2>
        <p className="text-[13px] text-text-muted mt-0.5">Top customers, expansion, and platform growth</p>
      </div>

      {/* Growth chart */}
      <div className="grid gap-4 lg:grid-cols-2">
        <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
          <p className="text-sm font-semibold text-text-primary mb-1">Customer Growth — 2026</p>
          <p className="text-[11px] text-text-muted mb-4">New sign-ups vs churned per month</p>
          <ResponsiveContainer width="100%" height={180}>
            <BarChart data={GROWTH_DATA} barCategoryGap="35%">
              <XAxis dataKey="month" tick={{ fill: '#64748B', fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis hide />
              <Tooltip cursor={{ fill: 'transparent' }} contentStyle={{ background: '#13102B', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 8 }} itemStyle={{ color: '#E2E8F0', fontSize: 12 }} />
              <Bar dataKey="newCustomers" name="New" fill="#8B5CF6" radius={[4,4,0,0]} />
              <Bar dataKey="churned" name="Churned" fill="#EF4444" radius={[4,4,0,0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
          <p className="text-sm font-semibold text-text-primary mb-1">MRR Growth Trajectory</p>
          <p className="text-[11px] text-text-muted mb-4">Revenue ramp across 2026</p>
          <ResponsiveContainer width="100%" height={180}>
            <AreaChart data={mrrTrend}>
              <defs>
                <linearGradient id="gradG" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#8B5CF6" stopOpacity={0.35} />
                  <stop offset="95%" stopColor="#8B5CF6" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="month" tick={{ fill: '#64748B', fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis hide />
              <Tooltip cursor={{ fill: 'transparent' }} contentStyle={{ background: '#13102B', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 8 }} itemStyle={{ color: '#E2E8F0', fontSize: 12 }} formatter={v => [`₹${v.toLocaleString()}`, 'MRR']} />
              <Area type="monotone" dataKey="mrr" stroke="#8B5CF6" strokeWidth={2.5} fill="url(#gradG)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Leaderboards */}
      <div className="grid gap-4 lg:grid-cols-3">
        {[
          { title: 'Top by Revenue', data: topByRevenue,  key: 'mrr',     fmt: v => `₹${v.toLocaleString()}/mo`, color: '#8B5CF6' },
          { title: 'Top by Labours', data: topByLabours,  key: 'labours', fmt: v => `${v} labours`, color: '#10B981' },
          { title: 'Top by Sites',   data: topBySites,    key: 'sites',   fmt: v => `${v} sites`, color: '#F5A623' },
        ].map(board => (
          <div key={board.title} className="rounded-2xl border border-white/[0.06] bg-[#13102B] overflow-hidden">
            <div className="flex items-center gap-2 border-b border-white/[0.06] px-5 py-4">
              <div className="h-2.5 w-2.5 rounded-full" style={{ background: board.color }} />
              <p className="text-sm font-semibold text-text-primary">{board.title}</p>
            </div>
            <div className="divide-y divide-white/[0.04]">
              {board.data.map((c, i) => (
                <div key={c.id} className="flex items-center gap-3 px-5 py-3.5">
                  <span className="text-[13px] font-mono font-bold text-text-muted w-5">{i+1}</span>
                  <div className="flex-1 min-w-0">
                    <p className="text-[13px] font-medium text-text-primary truncate">{c.name}</p>
                    <p className="text-[11px] text-text-muted">{c.city}</p>
                  </div>
                  <span className="font-mono text-[12px] font-semibold" style={{ color: board.color }}>{board.fmt(c[board.key])}</span>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
