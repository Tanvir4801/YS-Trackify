import React, { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts';
import {
  Users, UserCheck, UserX, Wallet, TrendingUp, Activity,
  AlertTriangle, RefreshCw, Plus, HardHat, FileText, Download,
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

function StatCard({ label, value, sub, icon: Icon, accent = 'bg-blue-50 text-blue-600' }) {
  return (
    <div className="flex items-center justify-between rounded-2xl border border-slate-200/70 bg-white/90 p-5 shadow-sm backdrop-blur">
      <div className="min-w-0 flex-1">
        <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</p>
        <p className="mt-1.5 text-2xl font-semibold text-slate-950">{value}</p>
        {sub && <p className="mt-0.5 text-xs text-slate-400">{sub}</p>}
      </div>
      <div className={`ml-3 shrink-0 rounded-xl p-3 ${accent}`}>
        <Icon className="h-5 w-5" />
      </div>
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

export default function Dashboard() {
  const navigate = useNavigate();
  const role = useAuthStore((s) => s.role);
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

  // Real-time today's attendance
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

  // 14-day trend
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

  // This month's payments
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
    const salary = monthPayments.filter((p) => p.type === 'salary').reduce((s, p) => s + (Number(p.amount) || 0), 0);
    const total = monthPayments.reduce((s, p) => s + (Number(p.amount) || 0), 0);
    const pending = Math.max(0, labours.reduce((s, l) => s + (Number(l.dailyWage) || 0), 0) * 26 - salary);
    return { total, advances, salary, pending };
  }, [monthPayments, labours]);

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

  // Build alerts
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
    toast.success('Today\'s attendance exported');
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight text-slate-950">Dashboard</h2>
          <p className="mt-1 text-sm text-slate-500">
            {new Date().toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button variant="outline" onClick={() => navigate('/attendance')} className="gap-2">
            <Activity className="h-4 w-4" /> Mark Attendance
          </Button>
          <Button variant="outline" onClick={() => navigate('/labours')} className="gap-2">
            <Plus className="h-4 w-4" /> Add Labour
          </Button>
          <Button variant="outline" onClick={() => navigate('/reports')} className="gap-2">
            <FileText className="h-4 w-4" /> Reports
          </Button>
          <Button variant="outline" onClick={handleExportToday} className="gap-2">
            <Download className="h-4 w-4" /> Export Today
          </Button>
        </div>
      </div>

      {alerts.filter((a) => !dismissed.has(a.id)).length > 0 && (
        <div className="space-y-2">
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
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Active Labours" value={labours.length} icon={HardHat} accent="bg-blue-50 text-blue-600" />
        <StatCard
          label="Present Today"
          value={todayCounts.present}
          sub={labours.length ? `${Math.round((todayCounts.present / labours.length) * 100)}% of total` : ''}
          icon={UserCheck}
          accent="bg-green-50 text-green-600"
        />
        <StatCard
          label="Absent Today"
          value={todayCounts.absent}
          sub={labours.length ? `${Math.round((todayCounts.absent / labours.length) * 100)}% of total` : ''}
          icon={UserX}
          accent="bg-red-50 text-red-600"
        />
        <StatCard label="Half Day Today" value={todayCounts.half} icon={Activity} accent="bg-amber-50 text-amber-600" />
        <StatCard label="Month Payroll" value={formatCurrency(payrollSummary.total)} icon={Wallet} accent="bg-purple-50 text-purple-600" sub="this month total" />
        <StatCard label="Pending Advances" value={formatCurrency(payrollSummary.advances)} icon={TrendingUp} accent="bg-yellow-50 text-yellow-600" sub="total advances" />
        <StatCard label="Supervisors" value={supervisors.length} icon={Users} accent="bg-slate-100 text-slate-600" />
        <StatCard
          label="OT Hours Today"
          value={todayCounts.totalOT}
          icon={RefreshCw}
          accent="bg-indigo-50 text-indigo-600"
          sub="total overtime"
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="rounded-2xl border border-slate-200/70 bg-white/90 p-5 shadow-sm lg:col-span-2">
          <h3 className="mb-4 text-base font-semibold text-slate-900">14-Day Attendance Trend</h3>
          {loadingTrend ? (
            <div className="flex h-48 items-center justify-center">
              <LoadingSpinner label="Loading trend…" />
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={trend14} margin={{ top: 4, right: 8, left: -10, bottom: 0 }} barCategoryGap="30%">
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="label" tick={{ fontSize: 11, fill: '#94a3b8' }} />
                <YAxis tick={{ fontSize: 11, fill: '#94a3b8' }} allowDecimals={false} />
                <Tooltip
                  contentStyle={{ borderRadius: 12, border: '1px solid #e2e8f0', fontSize: 12 }}
                  cursor={{ fill: '#f8fafc' }}
                />
                <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: 12 }} />
                <Bar dataKey="present" name="Present" fill="#22c55e" radius={[4, 4, 0, 0]} />
                <Bar dataKey="absent" name="Absent" fill="#ef4444" radius={[4, 4, 0, 0]} />
                <Bar dataKey="half" name="Half Day" fill="#f59e0b" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>

        <div className="rounded-2xl border border-slate-200/70 bg-white/90 p-5 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="text-base font-semibold text-slate-900">Payroll Summary</h3>
            <span className="text-xs text-slate-400">This month</span>
          </div>
          {loadingPay ? (
            <LoadingSpinner label="Loading…" />
          ) : (
            <div className="space-y-4">
              <div>
                <div className="flex justify-between text-sm mb-1">
                  <span className="text-slate-500">Gross</span>
                  <span className="font-semibold">{formatCurrency(payrollSummary.total)}</span>
                </div>
                <div className="flex justify-between text-sm mb-1">
                  <span className="text-slate-500">Advances</span>
                  <span className="font-semibold text-amber-600">{formatCurrency(payrollSummary.advances)}</span>
                </div>
                <div className="flex justify-between text-sm mb-3">
                  <span className="text-slate-500">Net Payable</span>
                  <span className="font-semibold text-green-700">
                    {formatCurrency(payrollSummary.total - payrollSummary.advances)}
                  </span>
                </div>
                {payrollSummary.total > 0 && (
                  <div className="h-2 w-full overflow-hidden rounded-full bg-slate-100">
                    <div
                      className="h-full rounded-full bg-amber-400 transition-all"
                      style={{ width: `${Math.min(100, (payrollSummary.advances / payrollSummary.total) * 100).toFixed(0)}%` }}
                    />
                  </div>
                )}
                {payrollSummary.total > 0 && (
                  <p className="mt-1 text-center text-xs text-slate-400">
                    {Math.round((payrollSummary.advances / payrollSummary.total) * 100)}% advance vs gross
                  </p>
                )}
              </div>
              <Button onClick={() => navigate('/payroll')} className="w-full gap-2 bg-blue-600 text-white hover:bg-blue-700" size="sm">
                <Calculator className="h-4 w-4" /> Open Payroll Calculator
              </Button>
            </div>
          )}
        </div>
      </div>

      <div className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm">
        <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
          <div className="flex items-center gap-3">
            <h3 className="text-base font-semibold text-slate-900">Today's Live Attendance Feed</h3>
            <span className="flex items-center gap-1 rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-700">
              <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-green-500" />
              Live
            </span>
          </div>
          <span className="text-xs text-slate-400">{attendanceToday.length} records</span>
        </div>
        {loadingToday ? (
          <LoadingSpinner label="Loading feed…" />
        ) : attendanceToday.length === 0 ? (
          <p className="px-5 py-8 text-center text-sm text-slate-400">No attendance recorded today yet.</p>
        ) : (
          <div className="max-h-64 overflow-y-auto">
            <table className="w-full text-sm">
              <thead className="sticky top-0 border-b border-slate-100 bg-white text-xs uppercase tracking-wide text-slate-400">
                <tr>
                  <th className="px-5 py-2 text-left">Labour</th>
                  <th className="px-5 py-2 text-left">Supervisor</th>
                  <th className="px-5 py-2 text-left">Status</th>
                  <th className="px-5 py-2 text-left">Via</th>
                  <th className="px-5 py-2 text-right">OT Hrs</th>
                </tr>
              </thead>
              <tbody>
                {attendanceToday.map((r) => {
                  const labour = labourMap.get(r.labourId);
                  const supervisor = supervisorMap.get(r.supervisorId);
                  return (
                    <tr key={r.id} className="border-b border-slate-100 last:border-b-0 hover:bg-slate-50">
                      <td className="px-5 py-2 font-medium text-slate-900">
                        {labour?.name || r.labourId?.slice(0, 8) || '—'}
                      </td>
                      <td className="px-5 py-2 text-slate-600">{supervisor?.name || '—'}</td>
                      <td className="px-5 py-2"><StatusBadge status={r.status} /></td>
                      <td className="px-5 py-2"><MarkedViaBadge via={r.markedVia} /></td>
                      <td className="px-5 py-2 text-right text-slate-700">{r.overtimeHours || 0}</td>
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

function Calculator({ className }) {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={className}>
      <rect width="16" height="20" x="4" y="2" rx="2" /><line x1="8" x2="16" y1="6" y2="6"/><line x1="16" x2="16" y1="14" y2="18"/><path d="M16 10h.01"/><path d="M12 10h.01"/><path d="M8 10h.01"/><path d="M12 14h.01"/><path d="M8 14h.01"/><path d="M12 18h.01"/><path d="M8 18h.01"/>
    </svg>
  );
}
