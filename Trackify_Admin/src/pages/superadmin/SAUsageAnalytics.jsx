import React, { useState, useEffect } from 'react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, RadialBarChart, RadialBar, Cell } from 'recharts';
import { Activity, Zap, FileDown, BarChart2, Users2, MapPin } from 'lucide-react';
import { getTodayUsage, getAllCustomers } from '../../lib/services/saas.service';

const HOURLY = Array.from({ length: 12 }, (_, i) => ({
  hour: `${(i + 7).toString().padStart(2,'0')}:00`,
  scans: Math.round(800 + Math.random() * 1800),
  att: Math.round(1000 + Math.random() * 2500),
}));

export default function SAUsageAnalytics() {
  const [todayUsage, setTodayUsage] = useState({ qrScans: 0, attendanceMarked: 0, pdfDownloads: 0, reportsGenerated: 0, activeSupervisors: 0, activeSites: 0 });
  useEffect(() => {
    getTodayUsage().then(setTodayUsage);
  }, []);

  const [allCustomers, setAllCustomers] = useState([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  useEffect(() => {
    getAllCustomers().then(data => {
      setAllCustomers(data);
      setLoadingCustomers(false);
    });
  }, []);

  const usageByContractor = React.useMemo(() => {
    return allCustomers.filter(c=>c.status==='active').slice(0,8).map(c => ({
      name: c.name.split(' ')[0],
      scans: Math.round(c.labours * 12 + Math.random() * 500),
      att: Math.round(c.labours * 10),
    }));
  }, [allCustomers]);

  const u = todayUsage;
  const stats = [
    { label: 'QR Scans Today', value: u.qrScans.toLocaleString(), icon: Zap, color: '#8B5CF6', trend: '+4.2%' },
    { label: 'Attendance Marked', value: u.attendanceMarked.toLocaleString(), icon: Activity, color: '#10B981', trend: '+2.8%' },
    { label: 'PDF Downloads', value: u.pdfDownloads.toLocaleString(), icon: FileDown, color: '#F5A623', trend: '-1.1%' },
    { label: 'Reports Generated', value: u.reportsGenerated, icon: BarChart2, color: '#3B82F6', trend: '+6.5%' },
    { label: 'Active Supervisors', value: u.activeSupervisors, icon: Users2, color: '#EC4899', trend: '+3.0%' },
    { label: 'Active Sites', value: u.activeSites, icon: MapPin, color: '#F59E0B', trend: '+1.5%' },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-text-primary flex items-center gap-2">
          <Activity className="h-6 w-6 text-violet-400" /> Usage Analytics
        </h2>
        <p className="text-[13px] text-text-muted mt-0.5">Platform-wide usage — Today, July 22 2026</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {stats.map(s => (
          <div key={s.label} className="relative overflow-hidden rounded-2xl border border-white/[0.06] bg-[#13102B] p-5 group hover:border-violet-500/20 transition-all">
            <div className="absolute top-0 right-0 h-20 w-20 rounded-full blur-3xl opacity-20" style={{ background: s.color }} />
            <div className="relative flex items-center justify-between mb-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-xl" style={{ background: `${s.color}15`, border: `1px solid ${s.color}30` }}>
                <s.icon className="h-4 w-4" style={{ color: s.color }} />
              </div>
              <span className={`text-[11px] font-semibold px-2 py-0.5 rounded-full ${s.trend.startsWith('+') ? 'text-emerald-400 bg-emerald-500/10' : 'text-rose-400 bg-rose-500/10'}`}>
                {s.trend}
              </span>
            </div>
            <p className="text-[11px] font-medium uppercase tracking-widest text-text-muted">{s.label}</p>
            <p className="mt-1 text-2xl font-mono font-bold text-text-primary">{s.value}</p>
          </div>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        {/* Hourly QR scan activity */}
        <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
          <p className="text-sm font-semibold text-text-primary mb-1">QR Scan Activity — Hourly</p>
          <p className="text-[11px] text-text-muted mb-4">Platform-wide scans per hour today</p>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={HOURLY} barCategoryGap="40%">
              <XAxis dataKey="hour" tick={{ fill: '#64748B', fontSize: 10 }} axisLine={false} tickLine={false} />
              <YAxis hide />
              <Tooltip cursor={{ fill: 'transparent' }} contentStyle={{ background: '#13102B', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 8 }} itemStyle={{ color: '#E2E8F0', fontSize: 12 }} formatter={(v) => [v.toLocaleString(), 'Scans']} />
              <Bar dataKey="scans" fill="#8B5CF6" radius={[4,4,0,0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Usage per contractor */}
        <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
          <p className="text-sm font-semibold text-text-primary mb-1">Attendance by Company</p>
          <p className="text-[11px] text-text-muted mb-4">Today's attendance marked per contractor</p>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={usageByContractor} layout="vertical" barCategoryGap="25%">
              <XAxis type="number" hide />
              <YAxis dataKey="name" type="category" tick={{ fill: '#94A3B8', fontSize: 11 }} axisLine={false} tickLine={false} width={80} />
              <Tooltip cursor={{ fill: 'transparent' }} contentStyle={{ background: '#13102B', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 8 }} itemStyle={{ color: '#E2E8F0', fontSize: 12 }} />
              <Bar dataKey="att" fill="#10B981" radius={[0,4,4,0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
}
