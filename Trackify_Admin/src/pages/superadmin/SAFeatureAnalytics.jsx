import React, { useState, useEffect } from 'react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts';
import { BarChart2, TrendingUp, TrendingDown } from 'lucide-react';
import { getFeatureUsage } from '../../lib/services/saas.service';

export default function SAFeatureAnalytics() {
  const [featureUsage, setFeatureUsage] = useState([]);
  useEffect(() => {
    getFeatureUsage().then(setFeatureUsage);
  }, []);

  const sorted = [...featureUsage].sort((a, b) => b.usage - a.usage);
  const top3    = sorted.slice(0, 3);
  const bottom3 = sorted.slice(-3);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-text-primary flex items-center gap-2">
          <BarChart2 className="h-6 w-6 text-violet-400" /> Feature Analytics
        </h2>
        <p className="text-[13px] text-text-muted mt-0.5">Which Trackify features are being used across all companies</p>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        {/* Most used */}
        <div className="rounded-2xl border border-emerald-500/20 bg-emerald-500/5 p-5">
          <div className="flex items-center gap-2 mb-4">
            <TrendingUp className="h-4 w-4 text-emerald-400" />
            <p className="text-sm font-semibold text-text-primary">Most Used Features</p>
          </div>
          <div className="space-y-3">
            {top3.map(f => (
              <div key={f.feature} className="flex items-center gap-3">
                <span className="text-xl">{f.icon}</span>
                <div className="flex-1">
                  <div className="flex justify-between text-[13px] mb-1">
                    <span className="text-text-primary font-medium">{f.feature}</span>
                    <span className="font-mono font-bold text-emerald-400">{f.usage}%</span>
                  </div>
                  <div className="h-2 rounded-full bg-white/[0.05] overflow-hidden">
                    <div className="h-full rounded-full bg-emerald-500 transition-all" style={{ width: `${f.usage}%` }} />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Least used */}
        <div className="rounded-2xl border border-amber-500/20 bg-amber-500/5 p-5">
          <div className="flex items-center gap-2 mb-4">
            <TrendingDown className="h-4 w-4 text-amber-400" />
            <p className="text-sm font-semibold text-text-primary">Least Used Features</p>
          </div>
          <div className="space-y-3">
            {bottom3.map(f => (
              <div key={f.feature} className="flex items-center gap-3">
                <span className="text-xl">{f.icon}</span>
                <div className="flex-1">
                  <div className="flex justify-between text-[13px] mb-1">
                    <span className="text-text-primary font-medium">{f.feature}</span>
                    <span className="font-mono font-bold text-amber-400">{f.usage}%</span>
                  </div>
                  <div className="h-2 rounded-full bg-white/[0.05] overflow-hidden">
                    <div className="h-full rounded-full bg-amber-500 transition-all" style={{ width: `${f.usage}%` }} />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Full bar chart */}
      <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
        <p className="text-sm font-semibold text-text-primary mb-1">All Features — Adoption Rate</p>
        <p className="text-[11px] text-text-muted mb-5">% of active companies using each feature</p>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={sorted} layout="vertical" barCategoryGap="25%">
            <XAxis type="number" domain={[0, 100]} tick={{ fill: '#64748B', fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={v => `${v}%`} />
            <YAxis dataKey="feature" type="category" tick={{ fill: '#94A3B8', fontSize: 11 }} axisLine={false} tickLine={false} width={160} />
            <Tooltip cursor={{ fill: 'transparent' }} contentStyle={{ background: '#13102B', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 8 }} itemStyle={{ color: '#E2E8F0', fontSize: 12 }} formatter={(v) => [`${v}%`, 'Adoption']} />
            <Bar dataKey="usage" radius={[0, 4, 4, 0]}>
              {sorted.map((entry, i) => (
                <Cell key={i} fill={entry.usage >= 70 ? '#10B981' : entry.usage >= 40 ? '#F5A623' : '#EF4444'} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Full list */}
      <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] overflow-hidden">
        <div className="border-b border-white/[0.06] px-5 py-4">
          <p className="text-sm font-semibold text-text-primary">All Features Detail</p>
        </div>
        <div className="divide-y divide-white/[0.04]">
          {sorted.map((f, i) => (
            <div key={f.feature} className="flex items-center gap-4 px-5 py-3 hover:bg-violet-500/5 transition-colors">
              <span className="text-[13px] font-mono font-bold text-text-muted w-6">{i+1}</span>
              <span className="text-xl">{f.icon}</span>
              <span className="flex-1 text-[13px] font-medium text-text-primary">{f.feature}</span>
              <div className="w-32 h-2 rounded-full bg-white/[0.05] overflow-hidden">
                <div className="h-full rounded-full transition-all" style={{ width: `${f.usage}%`, background: f.usage >= 70 ? '#10B981' : f.usage >= 40 ? '#F5A623' : '#EF4444' }} />
              </div>
              <span className="font-mono font-bold text-[13px] w-10 text-right" style={{ color: f.usage >= 70 ? '#10B981' : f.usage >= 40 ? '#F5A623' : '#EF4444' }}>{f.usage}%</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
