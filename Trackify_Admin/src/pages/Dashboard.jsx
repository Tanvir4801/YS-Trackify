import React, { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts';
import {
  Users, UserCheck, UserX, Wallet, TrendingUp, Activity,
  AlertTriangle, RefreshCw, Plus, HardHat, FileText, Download,
  Clock, ArrowRight,
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

function StatCard({ label, value, sub, icon: Icon, color = 'blue' }) {
  const colors = {
    blue:   { bg: '#EFF6FF', icon: '#2563EB', bar: '#2563EB' },
    green:  { bg: '#F0FDF4', icon: '#16A34A', bar: '#22C55E' },
    red:    { bg: '#FEF2F2', icon: '#DC2626', bar: '#EF4444' },
    amber:  { bg: '#FFFBEB', icon: '#D97706', bar: '#F59E0B' },
    purple: { bg: '#FAF5FF', icon: '#7C3AED', bar: '#7C3AED' },
    slate:  { bg: '#F8FAFC', icon: '#475569', bar: '#64748B' },
    indigo: { bg: '#EEF2FF', icon: '#4338CA', bar: '#4338CA' },
  };
  const c = colors[color] || colors.blue;
  return (
    <div className="rounded-2xl border border-slate-200/70 bg-white p-5 shadow-sm hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between">
        <div className="min-w-0 flex-1">
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{value}</p>
          {sub && <p className="mt-0.5 text-xs text-slate-400">{sub}</p>}
        </div>
        <div className="ml-3 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl" style={{ background: c.bg }}>
          <Icon className="h-5 w-5" style={{ color: c.icon }} />
        </div>
      </div>
    </div>
  );
}

function QuickAction({ icon: Icon, label, desc, color, onClick }) {
  return (
    <button
      onClick={onClick}
      className="flex items-center gap-3 rounded-xl border border-slate-200 bg-white p-4 text-left shadow-sm transition hover:border-blue-300 hover:shadow-md group w-full"
    >
      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg" style={{ background: color + '15' }}>
        <Icon className="h-4 w-4" style={{ color }} />
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold text-slate-900">{label}</p>
        <p className="text-xs text-slate-500">{desc}</p>
      </div>
      <ArrowRight className="h-4 w-4 text-slate-300 group-hover:text-blue-500 transition shrink-0" />
    </button>
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

  return (
    <div className="space-y-6">
      {/* Hero greeting */}
      <div className="rounded-2xl border border-slate-200/70 bg-white p-6 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="text-sm font-medium text-slate-500">{getGreeting()} 👋</p>
            <h2 className="mt-1 text-2xl font-bold text-slate-900">Welcome back, {displayName}</h2>
            <p className="mt-1 text-sm text-slate-500">
              Today is <span className="font-semibold text-slate-700">{dateStr}</span>
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button variant="outline" size="sm" onClick={() => navigate('/attendance')} className="gap-2 text-sm">
              <Activity className="h-4 w-4" /> Mark Attendance
            </Button>
            <Button variant="outline" size="sm" onClick={() => navigate('/labours')} className="gap-2 text-sm">
              <Plus className="h-4 w-4" /> Add Labour
            </Button>
            <Button variant="outline" size="sm" onClick={() => navigate('/reports')} className="gap-2 text-sm">
              <FileText className="h-4 w-4" /> Reports
            </Button>
            <Button variant="outline" size="sm" onClick={handleExportToday} className="gap-2 text-sm">
              <Download className="h-4 w-4" /> Export Today
            </Button>
          </div>
        </div>
      </div>

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
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Active Labours"   value={labours.length}           icon={HardHat}   color="blue" />
        <StatCard label="Present Today"    value={todayCounts.present}      sub={labours.length ? `${Math.round((todayCounts.present / labours.length) * 100)}% of workforce` : ''} icon={UserCheck} color="green" />
        <StatCard label="Absent Today"     value={todayCounts.absent}       sub={labours.length ? `${Math.round((todayCounts.absent / labours.length) * 100)}% of workforce` : ''} icon={UserX}    color="red" />
        <StatCard label="Half Day Today"   value={todayCounts.half}         icon={Activity}  color="amber" />
        <StatCard label="Month Payroll"    value={formatCurrency(payrollSummary.total)}   sub="this month total" icon={Wallet}    color="purple" />
        <StatCard label="Pending Advances" value={formatCurrency(payrollSummary.advances)} sub="total advances"   icon={TrendingUp} color="amber" />
        <StatCard label="Supervisors"      value={supervisors.length}       icon={Users}     color="slate" />
        <StatCard label="OT Hours Today"   value={todayCounts.totalOT}      sub="total overtime" icon={RefreshCw} color="indigo" />
      </div>

      {/* Chart + Payroll */}
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="rounded-2xl border border-slate-200/70 bg-white p-5 shadow-sm lg:col-span-2">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="text-base font-bold text-slate-900">14-Day Attendance Trend</h3>
            <span className="text-xs text-slate-400">Last 2 weeks</span>
          </div>
          {loadingTrend ? (
            <div className="flex h-48 items-center justify-center">
              <LoadingSpinner label="Loading trend…" />
            </div>
          ) : trend14.every((d) => d.present === 0 && d.absent === 0 && d.half === 0) ? (
            <div className="flex h-48 flex-col items-center justify-center gap-2 text-center">
              <Activity className="h-10 w-10 text-slate-200" />
              <p className="text-sm font-semibold text-slate-400">No data available yet</p>
              <p className="text-xs text-slate-300">Attendance data will appear here once records are saved</p>
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
            <h3 className="text-base font-bold text-slate-900">Payroll Summary</h3>
            <span className="text-xs text-slate-400">This month</span>
          </div>
          {loadingPay ? (
            <LoadingSpinner label="Loading…" />
          ) : (
            <div className="space-y-4">
              {[
                { label: 'Gross',      value: payrollSummary.total,   color: '#0F172A' },
                { label: 'Advances',   value: payrollSummary.advances, color: '#D97706' },
                { label: 'Net Payable', value: payrollSummary.total - payrollSummary.advances, color: '#16A34A' },
              ].map((row) => (
                <div key={row.label} className="flex items-center justify-between rounded-xl bg-slate-50 px-4 py-3">
                  <span className="text-sm text-slate-500 font-medium">{row.label}</span>
                  <span className="text-sm font-bold" style={{ color: row.color }}>{formatCurrency(row.value)}</span>
                </div>
              ))}

              {payrollSummary.total > 0 && (
                <div>
                  <div className="h-2 w-full overflow-hidden rounded-full bg-slate-100">
                    <div
                      className="h-full rounded-full transition-all"
                      style={{ width: `${Math.min(100, (payrollSummary.advances / payrollSummary.total) * 100).toFixed(0)}%`, background: '#F59E0B' }}
                    />
                  </div>
                  <p className="mt-1 text-center text-xs text-slate-400">
                    {Math.round((payrollSummary.advances / payrollSummary.total) * 100)}% advance vs gross
                  </p>
                </div>
              )}

              <Button
                onClick={() => navigate('/payroll')}
                className="w-full gap-2 text-white text-sm"
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
        <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
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
            <Clock className="h-10 w-10 text-slate-200" />
            <p className="text-sm font-semibold text-slate-400">No attendance recorded today yet</p>
            <Button size="sm" onClick={() => navigate('/attendance')} style={{ background: '#2563EB' }} className="text-white gap-2">
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
