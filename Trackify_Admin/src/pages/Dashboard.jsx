import React, { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts';
import {
  Users, UserCheck, UserX, Wallet, TrendingUp, Activity,
  AlertTriangle, RefreshCw, Plus, HardHat, FileText, Download,
  Clock, ArrowRight, Building2, BarChart2,
} from 'lucide-react';

import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { useLabours } from '../hooks/useLabours';
import { getAttendanceRange, subscribeAttendanceByDate } from '../lib/services/attendance.service';
import { getPayments } from '../lib/services/payments.service';
import { useSupervisors } from '../hooks/useSupervisors';

import { todayKey, toDateKey, formatCurrency, exportCSV } from '../lib/utils';
import { Button } from '../components/ui/button';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import StatusBadge from '../components/shared/StatusBadge';
import AlertBanner from '../components/shared/AlertBanner';

function MarkedViaBadge({ via }) {
  const map = {
    qr:           { label: 'QR',         cls: 'bg-emerald-100 text-emerald-700' },
    offline_qr:   { label: 'Offline QR', cls: 'bg-orange-100  text-orange-700'  },
    manual:       { label: 'Manual',     cls: 'bg-blue-100    text-blue-700'    },
    admin_manual: { label: 'Admin',      cls: 'bg-purple-100  text-purple-700'  },
  };
  const { label, cls } = map[via] || { label: via || '—', cls: 'bg-slate-100 text-slate-500' };
  return (
    <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-semibold ${cls}`}>
      {label}
    </span>
  );
}

function StatCard({ label, value, sub, icon: Icon, color = 'blue', trend }) {
  const colors = {
    blue:   { bg: '#EFF6FF', icon: '#2563EB' },
    green:  { bg: '#F0FDF4', icon: '#16A34A' },
    red:    { bg: '#FEF2F2', icon: '#DC2626' },
    amber:  { bg: '#FFFBEB', icon: '#D97706' },
    purple: { bg: '#FAF5FF', icon: '#7C3AED' },
    slate:  { bg: '#F8FAFC', icon: '#475569' },
    indigo: { bg: '#EEF2FF', icon: '#4338CA' },
  };
  const c = colors[color] || colors.blue;
  return (
    <motion.div
      whileHover={{ y: -2, boxShadow: '0 8px 25px rgba(0,0,0,0.08)' }}
      transition={{ duration: 0.15 }}
      className="rounded-2xl border border-slate-200/70 bg-white p-5 shadow-sm cursor-default"
    >
      <div className="flex items-start justify-between">
        <div className="min-w-0 flex-1">
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">{label}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{value}</p>
          {trend && (
            <p className="mt-0.5 text-xs font-medium" style={{ color: trend.startsWith('↑') ? '#16A34A' : trend.startsWith('↓') ? '#DC2626' : '#94A3B8' }}>
              {trend}
            </p>
          )}
          {sub && !trend && <p className="mt-0.5 text-xs text-slate-400">{sub}</p>}
        </div>
        <div className="ml-3 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl" style={{ background: c.bg }}>
          <Icon className="h-5 w-5" style={{ color: c.icon }} />
        </div>
      </div>
    </motion.div>
  );
}

function QuickAction({ icon: Icon, label, desc, color, onClick }) {
  return (
    <motion.button
      whileHover={{ scale: 1.01 }}
      whileTap={{ scale: 0.98 }}
      onClick={onClick}
      className="flex items-center gap-3 rounded-xl border border-slate-200 bg-white p-3.5 text-left shadow-sm transition hover:border-blue-200 hover:shadow-md group w-full"
    >
      <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg" style={{ background: color + '18' }}>
        <Icon className="h-4 w-4" style={{ color }} />
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold text-slate-900">{label}</p>
        <p className="text-xs text-slate-400">{desc}</p>
      </div>
      <ArrowRight className="h-4 w-4 text-slate-300 group-hover:text-blue-500 transition shrink-0" />
    </motion.button>
  );
}

function SummaryChip({ icon, label, value, color }) {
  return (
    <div className="flex items-center gap-2 rounded-full border border-slate-200 bg-white px-3.5 py-2 shadow-sm">
      <span className="text-sm">{icon}</span>
      <span className="text-xs text-slate-500 font-medium">{label}:</span>
      <span className="text-xs font-bold" style={{ color }}>{value}</span>
    </div>
  );
}

function buildLast14() {
  const days = [];
  for (let i = 13; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    days.push({ date: d.toISOString().split('T')[0], label: `${String(d.getDate()).padStart(2,'0')}/${String(d.getMonth()+1).padStart(2,'0')}` });
  }
  return days;
}

function getGreeting() {
  const h = new Date().getHours();
  if (h < 12) return 'Good Morning';
  if (h < 17) return 'Good Afternoon';
  return 'Good Evening';
}

const cardVariants = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

const containerVariants = {
  hidden: {},
  show: { transition: { staggerChildren: 0.06 } },
};

export default function Dashboard() {
  const navigate = useNavigate();
  const role = useAuthStore((s) => s.role);
  const name = useAuthStore((s) => s.name);
  const activeContractorName = useAuthStore((s) => s.activeContractorName);
  const scopeId = useScopeId();
  const today = todayKey();

  const now = new Date();
  const monthStart = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
  const days14 = useMemo(() => buildLast14(), []);
  const days14Start = days14[0].date;

  const { data: labours = [], isLoading: loadingLabours } = useLabours();
  const { data: supervisors = [] } = useSupervisors();

  const [attendanceToday, setAttendanceToday] = useState([]);
  const [loadingToday, setLoadingToday] = useState(true);
  const [trend14, setTrend14] = useState([]);
  const [loadingTrend, setLoadingTrend] = useState(true);
  const [monthPayments, setMonthPayments] = useState([]);
  const [loadingPay, setLoadingPay] = useState(true);
  const [alerts, setAlerts] = useState([]);
  const [dismissed, setDismissed] = useState(new Set());

  useEffect(() => {
    if (!scopeId && role !== 'super_admin') {
      setAttendanceToday([]);
      setLoadingToday(false);
      return undefined;
    }
    setLoadingToday(true);
    const unsub = subscribeAttendanceByDate(scopeId, today, (records) => {
      setAttendanceToday(records);
      setLoadingToday(false);
    });
    return () => unsub();
  }, [scopeId, today, role]);

  useEffect(() => {
    getAttendanceRange(scopeId, days14Start, today)
      .then((records) => {
        const byDate = new Map();
        records.forEach((r) => {
          const entry = byDate.get(r.date) || { present: 0, absent: 0, half: 0 };
          if (entry[r.status] !== undefined) entry[r.status]++;
          byDate.set(r.date, entry);
        });
        setTrend14(
          days14.map((d) => ({
            label: d.label,
            ...({ present: 0, absent: 0, half: 0, ...(byDate.get(d.date) || {}) }),
          })),
        );
      })
      .catch(console.error)
      .finally(() => setLoadingTrend(false));
  }, [scopeId, days14Start, today, days14]);

  useEffect(() => {
    getPayments(scopeId, { startDate: monthStart, endDate: today })
      .then(setMonthPayments)
      .catch(console.error)
      .finally(() => setLoadingPay(false));
  }, [scopeId, monthStart, today]);

  const todayCounts = useMemo(() => {
    const s = { present: 0, absent: 0, half: 0, totalOT: 0 };
    attendanceToday.forEach((r) => {
      if (s[r.status] !== undefined) s[r.status]++;
      s.totalOT += Number(r.overtimeHours) || 0;
    });
    return s;
  }, [attendanceToday]);

  const payrollSummary = useMemo(() => {
    const advances = monthPayments.filter((p) => p.type === 'advance').reduce((s, p) => s + (Number(p.amount) || 0), 0);
    const salary   = monthPayments.filter((p) => p.type === 'salary').reduce((s, p) => s + (Number(p.amount) || 0), 0);
    const total    = monthPayments.reduce((s, p) => s + (Number(p.amount) || 0), 0);
    return { total, advances, salary };
  }, [monthPayments]);

  const labourMap = useMemo(() => {
    const m = new Map();
    labours.forEach((l) => m.set(l.id, l));
    return m;
  }, [labours]);

  const supervisorMap = useMemo(() => {
    const m = new Map();
    supervisors.forEach((s) => m.set(s.id, s));
    return m;
  }, [supervisors]);

  useEffect(() => {
    const list = [];
    const unmarked = labours.length - attendanceToday.length;
    if (!loadingToday && unmarked > 0) {
      list.push({ id: 'unmarked', type: 'warning', message: `${unmarked} labour${unmarked > 1 ? 's have' : ' has'} no attendance marked today.`, actionLabel: 'Mark now', action: () => navigate('/attendance') });
    }
    setAlerts(list);
  }, [labours.length, attendanceToday.length, loadingToday, navigate]);

  const handleExportToday = () => {
    const rows = attendanceToday.map((r) => {
      const labour = labourMap.get(r.labourId);
      return { Labour: labour?.name || r.labourId, Status: r.status, 'OT Hours': r.overtimeHours, Date: today };
    });
    exportCSV(`attendance-${today}.csv`, rows);
    toast.success("Today's attendance exported");
  };

  const dateStr = now.toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  const displayName = activeContractorName || name || 'your workspace';
  const presentPct = labours.length ? Math.round((todayCounts.present / labours.length) * 100) : 0;
  const absentPct  = labours.length ? Math.round((todayCounts.absent  / labours.length) * 100) : 0;

  return (
    <div className="space-y-5">

      {/* Compact hero */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className="rounded-2xl border border-slate-200/70 bg-white shadow-sm overflow-hidden"
      >
        <div className="px-6 py-4">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="text-sm font-medium text-slate-400">{getGreeting()} 👋</p>
              <h2 className="text-xl font-bold text-slate-900 mt-0.5">Welcome back, {displayName}</h2>
              <p className="text-xs text-slate-400 mt-0.5">{dateStr}</p>
            </div>
            <div className="flex flex-wrap gap-2">
              <QuickAction icon={Activity}  label="Mark Attendance" desc="Record today's attendance" color="#2563EB" onClick={() => navigate('/attendance')} />
              <QuickAction icon={Plus}      label="Add Labour"      desc="Register new labour"       color="#16A34A" onClick={() => navigate('/labours')} />
              <QuickAction icon={FileText}  label="Reports"         desc="View analytics"            color="#7C3AED" onClick={() => navigate('/reports')} />
              <QuickAction icon={Download}  label="Export Today"    desc="Download attendance CSV"   color="#D97706" onClick={handleExportToday} />
            </div>
          </div>
        </div>

        {/* Quick summary chips */}
        <div className="border-t border-slate-100 bg-slate-50/60 px-6 py-2.5 flex flex-wrap gap-2">
          <SummaryChip icon="👷" label="Active Labours"  value={labours.length}             color="#2563EB" />
          <SummaryChip icon="🏗️" label="Active Sites"    value="—"                          color="#D97706" />
          <SummaryChip icon="👨‍💼" label="Supervisors"     value={supervisors.length}         color="#7C3AED" />
          <SummaryChip icon="💰" label="Monthly Payroll" value={formatCurrency(payrollSummary.total)} color="#16A34A" />
        </div>
      </motion.div>

      {alerts.filter((a) => !dismissed.has(a.id)).map((a) => (
        <AlertBanner
          key={a.id}
          type={a.type}
          message={a.message}
          actionLabel={a.actionLabel}
          onAction={a.action}
          onDismiss={() => setDismissed((p) => new Set([...p, a.id]))}
        />
      ))}

      {/* KPI cards */}
      <motion.div
        variants={containerVariants}
        initial="hidden"
        animate="show"
        className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4"
      >
        {[
          { label: 'Active Labours',   value: labours.length,               icon: HardHat,    color: 'blue',   trend: labours.length > 0 ? `${labours.length} registered` : 'No labours yet' },
          { label: 'Present Today',    value: todayCounts.present,           icon: UserCheck,  color: 'green',  trend: `${presentPct}% workforce` },
          { label: 'Absent Today',     value: todayCounts.absent,            icon: UserX,      color: 'red',    trend: `${absentPct}% workforce` },
          { label: 'Half Day Today',   value: todayCounts.half,              icon: Activity,   color: 'amber',  sub: 'half-day records' },
          { label: 'Month Payroll',    value: formatCurrency(payrollSummary.total),    icon: Wallet,     color: 'purple', sub: 'this month total' },
          { label: 'Pending Advances', value: formatCurrency(payrollSummary.advances), icon: TrendingUp, color: 'amber',  sub: 'total advances given' },
          { label: 'Supervisors',      value: supervisors.length,            icon: Users,      color: 'slate',  sub: 'active supervisors' },
          { label: 'OT Hours Today',   value: todayCounts.totalOT,          icon: Clock,      color: 'indigo', sub: 'total overtime hrs' },
        ].map((card) => (
          <motion.div key={card.label} variants={cardVariants}>
            <StatCard {...card} />
          </motion.div>
        ))}
      </motion.div>

      {/* Chart + Payroll */}
      <div className="grid gap-5 lg:grid-cols-3">
        <div className="rounded-2xl border border-slate-200/70 bg-white p-5 shadow-sm lg:col-span-2">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h3 className="text-base font-bold text-slate-900">14-Day Attendance Trend</h3>
              <p className="text-xs text-slate-400 mt-0.5">Last 2 weeks overview</p>
            </div>
            <span className="text-xs text-slate-400 hidden sm:block">Last 2 weeks</span>
          </div>
          {loadingTrend ? (
            <div className="flex h-52 items-center justify-center">
              <LoadingSpinner label="Loading trend…" />
            </div>
          ) : trend14.every((d) => d.present === 0 && d.absent === 0 && d.half === 0) ? (
            <div className="flex h-52 flex-col items-center justify-center gap-3 text-center">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-slate-100">
                <BarChart2 className="h-7 w-7 text-slate-300" />
              </div>
              <div>
                <p className="text-sm font-semibold text-slate-500">Not enough attendance history</p>
                <p className="text-xs text-slate-400 mt-1">Attendance trends will appear after several days of records.</p>
              </div>
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={trend14} margin={{ top: 4, right: 8, left: -10, bottom: 0 }} barCategoryGap="35%">
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="label" tick={{ fontSize: 11, fill: '#94a3b8' }} />
                <YAxis tick={{ fontSize: 11, fill: '#94a3b8' }} allowDecimals={false} />
                <Tooltip
                  contentStyle={{ borderRadius: 12, border: '1px solid #e2e8f0', fontSize: 12, boxShadow: '0 4px 20px rgba(0,0,0,0.08)' }}
                  cursor={{ fill: '#f8fafc' }}
                />
                <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: 12 }} />
                <Bar dataKey="present" name="Present" fill="#22c55e" radius={[4, 4, 0, 0]} />
                <Bar dataKey="absent"  name="Absent"  fill="#ef4444" radius={[4, 4, 0, 0]} />
                <Bar dataKey="half"    name="Half Day" fill="#f59e0b" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>

        <div className="rounded-2xl border border-slate-200/70 bg-white p-5 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h3 className="text-base font-bold text-slate-900">Payroll Summary</h3>
              <p className="text-xs text-slate-400 mt-0.5">This month</p>
            </div>
          </div>
          {loadingPay ? (
            <LoadingSpinner label="Loading…" />
          ) : (
            <div className="space-y-3">
              {[
                { label: 'Gross Salary', value: payrollSummary.total, color: '#0F172A', bg: '#F8FAFC', bar: null },
                { label: 'Advances',     value: payrollSummary.advances, color: '#D97706', bg: '#FFFBEB', bar: null },
                { label: 'Salary Paid',  value: payrollSummary.salary,   color: '#16A34A', bg: '#F0FDF4', bar: null },
              ].map((row) => (
                <div key={row.label} className="flex items-center justify-between rounded-xl px-4 py-3" style={{ background: row.bg }}>
                  <span className="text-sm text-slate-500 font-medium">{row.label}</span>
                  <span className="text-sm font-bold" style={{ color: row.color }}>{formatCurrency(row.value)}</span>
                </div>
              ))}

              {payrollSummary.total > 0 && (
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs text-slate-400">Advance ratio</span>
                    <span className="text-xs font-semibold text-amber-600">{Math.round((payrollSummary.advances / payrollSummary.total) * 100)}%</span>
                  </div>
                  <div className="h-1.5 w-full overflow-hidden rounded-full bg-slate-100">
                    <div
                      className="h-full rounded-full transition-all"
                      style={{ width: `${Math.min(100, (payrollSummary.advances / payrollSummary.total) * 100).toFixed(0)}%`, background: '#F59E0B' }}
                    />
                  </div>
                </div>
              )}

              <Button
                onClick={() => navigate('/payroll')}
                className="w-full gap-2 text-white text-sm mt-1"
                style={{ background: '#2563EB' }}
                size="sm"
              >
                Open Payroll Calculator
              </Button>
            </div>
          )}
        </div>
      </div>

      {/* Live attendance feed */}
      <div className="rounded-2xl border border-slate-200/70 bg-white shadow-sm overflow-hidden">
        <div className="flex items-center justify-between border-b border-slate-100 px-5 py-3.5">
          <div className="flex items-center gap-3">
            <h3 className="text-base font-bold text-slate-900">Today's Live Attendance Feed</h3>
            <span className="flex items-center gap-1.5 rounded-full bg-green-100 px-2.5 py-1 text-xs font-bold text-green-700">
              <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-green-500" />
              Live
            </span>
          </div>
          <span className="text-xs font-medium text-slate-400">{attendanceToday.length} records</span>
        </div>

        {loadingToday ? (
          <div className="py-10"><LoadingSpinner label="Loading feed…" /></div>
        ) : attendanceToday.length === 0 ? (
          <div className="flex flex-col items-center justify-center gap-3 py-12 text-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-slate-100">
              <Clock className="h-7 w-7 text-slate-300" />
            </div>
            <div>
              <p className="text-sm font-semibold text-slate-500">No attendance recorded today yet</p>
              <p className="text-xs text-slate-400 mt-1">Start marking attendance to see the live feed here.</p>
            </div>
            <Button size="sm" onClick={() => navigate('/attendance')} style={{ background: '#2563EB' }} className="text-white gap-2 mt-1">
              <Plus className="h-4 w-4" /> Mark Attendance
            </Button>
          </div>
        ) : (
          <div className="max-h-72 overflow-y-auto">
            <table className="w-full text-sm">
              <thead className="sticky top-0 border-b border-slate-100 bg-white">
                <tr>
                  {['Labour', 'Supervisor', 'Status', 'Via', 'OT Hrs'].map((h, i) => (
                    <th key={h} className={`px-5 py-2.5 text-xs font-bold uppercase tracking-wide text-slate-400 ${i === 4 ? 'text-right' : 'text-left'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {attendanceToday.map((r) => {
                  const labour = labourMap.get(r.labourId);
                  const supervisor = supervisorMap.get(r.supervisorId);
                  return (
                    <tr key={r.id} className="border-b border-slate-50 last:border-b-0 hover:bg-slate-50/60 transition-colors">
                      <td className="px-5 py-2.5">
                        <div className="flex items-center gap-2.5">
                          <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-700">
                            {(labour?.name || '?')[0].toUpperCase()}
                          </div>
                          <span className="font-semibold text-slate-900">{labour?.name || r.labourId?.slice(0, 8) || '—'}</span>
                        </div>
                      </td>
                      <td className="px-5 py-2.5 text-slate-500">{supervisor?.name || '—'}</td>
                      <td className="px-5 py-2.5"><StatusBadge status={r.status} /></td>
                      <td className="px-5 py-2.5"><MarkedViaBadge via={r.markedVia} /></td>
                      <td className="px-5 py-2.5 text-right font-semibold text-slate-700">{r.overtimeHours || 0}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
