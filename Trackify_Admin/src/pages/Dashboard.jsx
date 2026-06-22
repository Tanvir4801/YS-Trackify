import React, { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts';
import {
  Users, UserCheck, UserX, Wallet, TrendingUp, Activity,
  AlertTriangle, RefreshCw, Plus, HardHat, FileText, Download,
  Clock, ArrowRight, Building2, BarChart2, Star,
} from 'lucide-react';

import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { useSubscriptionStore } from '../store/subscriptionStore';
import { useLabours } from '../hooks/useLabours';
import { useSites } from '../hooks/useSites';
import { getAttendanceRange, subscribeAttendanceByDate } from '../lib/services/attendance.service';
import { subscribePayments } from '../lib/services/payments.service';
import { useSupervisors } from '../hooks/useSupervisors';

import { todayKey, toDateKey, formatCurrency, exportExcel } from '../lib/utils';
import { Button } from '../components/ui/button';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import StatusBadge from '../components/shared/StatusBadge';
import AlertBanner from '../components/shared/AlertBanner';
import MarkedViaBadge from '../components/shared/MarkedViaBadge';
import BrandingSetupWizard from '../components/BrandingSetupWizard';
import { useBranding } from '../context/BrandingContext';



function StatCard({ label, value, sub, icon: Icon, color = 'blue', trend }) {
  const colors = {
    blue:   { bg: 'var(--info-bg)', icon: 'var(--info)', borderLeft: 'var(--info)' },
    green:  { bg: 'var(--success-bg)', icon: 'var(--success)', borderLeft: 'var(--success)' },
    red:    { bg: 'var(--danger-bg)', icon: 'var(--danger)', borderLeft: 'var(--danger)' },
    amber:  { bg: 'var(--warning-bg)', icon: 'var(--warning)', borderLeft: 'var(--warning)' },
    purple: { bg: 'rgba(139,92,246,0.1)', icon: '#8B5CF6', borderLeft: '#8B5CF6' },
    slate:  { bg: 'var(--bg-elevated)', icon: 'var(--text-secondary)', borderLeft: 'transparent' },
    indigo: { bg: 'rgba(99,102,241,0.1)', icon: '#6366F1', borderLeft: '#6366F1' },
    gold:   { bg: 'var(--gold-bg)', icon: 'var(--gold)', borderLeft: 'var(--gold)' },
  };
  const c = colors[color] || colors.blue;
  return (
    <motion.div
      className="group relative rounded-xl border border-border bg-bg-card p-5 cursor-default transition-all hover:bg-bg-card-hover overflow-hidden shadow-sm"
    >
      {/* Subtle top accent bar */}
      <div className="absolute top-0 left-0 w-full h-[2px]" style={{ background: c.borderLeft !== 'transparent' ? c.borderLeft : 'transparent', opacity: 0.7 }} />
      {/* Hover glow effect */}
      <div className="absolute -top-10 -right-10 w-32 h-32 rounded-full blur-3xl opacity-10 group-hover:opacity-20 transition-opacity duration-500" style={{ background: c.borderLeft !== 'transparent' ? c.borderLeft : 'transparent' }} />
      
      <div className="flex justify-between items-start mb-3 relative z-10">
        <p className="text-[11px] font-semibold uppercase tracking-[1px] text-text-muted">{label}</p>
        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg" style={{ background: c.bg }}>
          <Icon className="h-4 w-4" style={{ color: c.icon }} />
        </div>
      </div>
      
      <div className="relative z-10 flex flex-col justify-end">
        <p className="text-[32px] font-bold font-mono tracking-tight leading-none mb-2" style={{ color: c.borderLeft !== 'transparent' ? c.borderLeft : 'var(--text-primary)' }}>
          {value}
        </p>
        <div className="flex items-center min-h-[20px]">
          {trend ? (
            <span className="text-[10px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded flex items-center" style={{ 
              background: trend.startsWith('↑') ? 'var(--success-bg)' : trend.startsWith('↓') ? 'var(--danger-bg)' : 'var(--bg-elevated)',
              color: trend.startsWith('↑') ? 'var(--success)' : trend.startsWith('↓') ? 'var(--danger)' : 'var(--text-secondary)' 
            }}>
              {trend}
            </span>
          ) : (
            <p className="text-[11px] text-text-muted font-medium">{sub}</p>
          )}
        </div>
      </div>
    </motion.div>
  );
}

function QuickAction({ icon: Icon, label, desc, color, onClick }) {
  return (
    <button
      onClick={onClick}
      className="flex items-center gap-2 rounded-[10px] border border-border-strong bg-bg-elevated px-4 py-3 text-left transition hover:border-gold-border hover:bg-gold-bg group"
    >
      <Icon className="h-[18px] w-[18px] text-gold transition-transform group-hover:scale-110" />
      <span className="text-[12px] font-medium text-text-secondary group-hover:text-gold">{label}</span>
    </button>
  );
}

function SummaryChip({ icon, label, value, color }) {
  return (
    <div className="flex items-center gap-2 rounded-lg border border-white/5 bg-white/5 px-3.5 py-1.5 backdrop-blur-md shadow-sm">
      <span className="text-sm opacity-80">{icon}</span>
      <span className="text-[10px] text-gray-400 font-bold uppercase tracking-wider">{label}</span>
      <span className="text-[13px] font-mono font-bold text-white ml-1">{value}</span>
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
  const uid = useAuthStore((s) => s.uid);
  const name = useAuthStore((s) => s.name);
  const activeContractorName = useAuthStore((s) => s.activeContractorName);
  const scopeId = useScopeId();
  const { subscription, featureFlags } = useSubscriptionStore();
  const today = todayKey();
  const { branding, loading: brandingLoading } = useBranding();

  const now = new Date();
  const monthStart = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
  const days14 = useMemo(() => buildLast14(), []);
  const days14Start = days14[0].date;

  const { data: labours = [], isLoading: loadingLabours } = useLabours();
  const { data: supervisors = [] } = useSupervisors();
  const { data: sites = [] } = useSites();

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
    if (!scopeId) return;
    
    // Defer heavy history loading by 500ms so main UI renders instantly
    const timer = setTimeout(() => {
      getAttendanceRange(scopeId, days14Start, today)
        .then((records) => {
        const byDate = new Map();
        records.forEach((r) => {
          const entry = byDate.get(r.date) || { present: 0, three_quarter: 0, half: 0, quarter: 0, absent: 0, pending: 0 };
          if (r.status === 'present') entry.present++;
          else if (r.status === 'absent') entry.absent++;
          else if (r.status === 'three_quarter') entry.three_quarter++;
          else if (r.status === 'half') entry.half++;
          else if (r.status === 'quarter') entry.quarter++;
          else if (r.status === 'pending') entry.pending++;
          byDate.set(r.date, entry);
        });
        setTrend14(
          days14.map((d) => ({
            label: d.label,
            ...({ present: 0, three_quarter: 0, half: 0, quarter: 0, absent: 0, pending: 0, ...(byDate.get(d.date) || {}) }),
          })),
        );
      })
      .catch(console.error)
      .finally(() => setLoadingTrend(false));
    }, 500);
    return () => clearTimeout(timer);
  }, [scopeId, days14Start, today, days14]);

  useEffect(() => {
    if (!scopeId && role !== 'super_admin') {
      setMonthPayments([]);
      setLoadingPay(false);
      return undefined;
    }
    setLoadingPay(true);
    const unsub = subscribePayments(
      scopeId,
      (rows) => {
        setMonthPayments(rows);
        setLoadingPay(false);
      },
      { startDate: monthStart, endDate: today },
    );
    return () => unsub();
  }, [scopeId, monthStart, today, role]);

  const todayCounts = useMemo(() => {
    // 'pending' = admin-reset state (labour had a record but was cleared back to neutral).
    // "No doc yet" labours are captured by (labours.length - attendanceToday.length) in the
    // alerts block below — they are conceptually the same "not yet correctly marked" bucket
    // but we do NOT merge them here to avoid double-counting.
    const s = { present: 0, three_quarter: 0, half: 0, quarter: 0, absent: 0, pending: 0, totalOT: 0, totalShiftFactor: 0, uniquePresent: 0 };
    const uniquePresentIds = new Set();
    attendanceToday.forEach((r) => {
      const factor = r.shiftFactor !== undefined ? Number(r.shiftFactor) : (r.status === 'present' ? 1.0 : r.status === 'three_quarter' ? 0.75 : r.status === 'half' ? 0.5 : r.status === 'quarter' ? 0.25 : 0.0);
      if (factor > 0) uniquePresentIds.add(r.labourId);
      s.totalShiftFactor += factor;

      if (r.status === 'present') s.present++;
      else if (r.status === 'absent') s.absent++;
      else if (r.status === 'three_quarter') s.three_quarter++;
      else if (r.status === 'half') s.half++;
      else if (r.status === 'quarter') s.quarter++;
      else if (r.status === 'pending') s.pending++;
      s.totalOT += Number(r.overtimeHours) || 0;
    });
    s.uniquePresent = uniquePresentIds.size;
    return s;
  }, [attendanceToday, role, uid]);

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
    const myAttendance = attendanceToday;
    const unmarked = labours.length - myAttendance.length;
    if (!loadingToday && unmarked > 0) {
      list.push({ id: 'unmarked', type: 'warning', message: `${unmarked} labour${unmarked > 1 ? 's have' : ' has'} no attendance marked today.`, actionLabel: 'Mark now', action: () => navigate('/attendance') });
    }
    setAlerts(list);
  }, [labours.length, attendanceToday, loadingToday, navigate, role, uid]);

  const handleExportToday = () => {
    const rows = attendanceToday.map((r) => {
      const labour = labourMap.get(r.labourId);
      return { Labour: labour?.name || r.labourId, Status: r.status, 'OT Hours': r.overtimeHours, Date: today };
    });
    exportExcel(`attendance-${today}.csv`, rows);
    toast.success("Today's attendance exported");
  };

  const dateStr = now.toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  const displayName = branding?.companyName || activeContractorName || name || 'your workspace';
  const presentPct = labours.length ? Math.round((todayCounts.uniquePresent / labours.length) * 100) : 0;
  const absentPct  = labours.length ? Math.round((todayCounts.absent  / labours.length) * 100) : 0;

  if (!brandingLoading && branding && !branding.isSetup && !loadingLabours && labours.length === 0 && role !== 'super_admin') {
    return <BrandingSetupWizard />;
  }

  return (
    <div className="space-y-6">

      {/* Compact hero */}
      <div className="rounded-xl border border-border bg-bg-card px-7 py-6 mb-6">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
          <div>
            <p className="text-[12px] font-medium text-gold tracking-wide uppercase mb-1">{getGreeting()} 👋</p>
            <div className="flex flex-col sm:flex-row sm:items-center gap-3">
              <h2 className="text-[24px] font-medium text-text-primary mt-1">Welcome back, {displayName}</h2>
              {subscription?.isTrial && (
                <div className="mt-2 sm:mt-0 px-3 py-1 rounded-full bg-gold/20 border border-gold/40 text-gold text-xs font-semibold flex items-center gap-2">
                  <Star className="w-3 h-3" />
                  Professional Trial · {Math.max(0, Math.ceil((new Date(subscription.expiryDate) - new Date()) / (1000 * 60 * 60 * 24)))} days remaining
                </div>
              )}
            </div>
            <p className="text-[13px] text-text-muted mt-1">{dateStr}</p>
          </div>
          <div className="flex flex-wrap gap-3 lg:justify-end">
            <QuickAction icon={Activity}  label="Mark Attendance" color="var(--gold)" onClick={() => navigate('/attendance')} />
            <QuickAction icon={Plus}      label="Add Labour"      color="var(--gold)" onClick={() => navigate('/labours')} />
            <QuickAction icon={FileText}  label="Reports"         color="var(--gold)" onClick={() => navigate('/reports')} />
            <QuickAction icon={Download}  label="Export Today"    color="var(--gold)" onClick={handleExportToday} />
          </div>
        </div>
      </div>

      {/* Summary Strip */}
      <div className="flex flex-wrap gap-4 mb-6">
        <SummaryChip icon="👷" label="Active Labours" value={labours.length} />
        <SummaryChip icon="🏗️" label="Active Sites" value={sites.length} />
        <SummaryChip icon="👨‍💼" label="Supervisors" value={supervisors.length} />
        <SummaryChip icon="💰" label="Monthly Payroll" value={formatCurrency(payrollSummary.total)} />
      </div>

      {alerts.filter((a) => !dismissed.has(a.id)).map((a) => (
        <div key={a.id} className="rounded-lg border border-warning/25 bg-warning-bg px-4 py-3 border-l-[3px] border-l-warning flex items-center justify-between gap-4 mb-4">
          <div className="flex items-center gap-3">
            <AlertTriangle className="h-[18px] w-[18px] text-warning" />
            <span className="text-[13px] font-medium text-text-primary">{a.message}</span>
          </div>
          <button 
            onClick={() => {
              a.action();
              setDismissed((p) => new Set([...p, a.id]));
            }}
            className="text-[13px] font-medium text-gold hover:underline"
          >
            {a.actionLabel}
          </button>
        </div>
      ))}

      {/* KPI cards */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {[
          { label: 'Active Labours',   value: labours.length,               icon: HardHat,    color: 'gold',   trend: labours.length > 0 ? `${labours.length} registered` : 'No labours yet' },
          { label: 'Present Today',    value: todayCounts.uniquePresent,           icon: UserCheck,  color: 'green',  trend: `${todayCounts.totalShiftFactor} total days` },
          { label: 'Absent Today',     value: todayCounts.absent,            icon: UserX,      color: 'red',    trend: `${absentPct}% workforce` },
          { label: 'Half Day Today',   value: todayCounts.half,              icon: Activity,   color: 'amber',  sub: 'half-day records' },
          ...(todayCounts.pending > 0 ? [{ label: 'Pending (reset)',  value: todayCounts.pending, icon: RefreshCw,  color: 'amber',  sub: 'reset – needs re-marking' }] : []),
          { label: 'Month Payroll',    value: formatCurrency(payrollSummary.total),    icon: Wallet,     color: 'gold', sub: 'this month total' },
          { label: 'Pending Advances', value: formatCurrency(payrollSummary.advances), icon: TrendingUp, color: 'amber',  sub: 'total advances given' },
          { label: 'Supervisors',      value: supervisors.length,            icon: Users,      color: 'slate',  sub: 'active supervisors' },
          { label: 'OT Hours Today',   value: todayCounts.totalOT,          icon: Clock,      color: 'blue', sub: 'total overtime hrs' },
        ].slice(0, 8).map((card) => (
          <StatCard key={card.label} {...card} />
        ))}
      </div>

      {/* Chart + Payroll */}
      <div className="grid gap-5 lg:grid-cols-3">
        <div className="rounded-xl border border-border bg-bg-card p-5 lg:col-span-2">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h3 className="text-[16px] font-medium text-text-primary">14-Day Attendance Trend</h3>
              <p className="text-[12px] text-text-muted mt-0.5">Last 2 weeks overview</p>
            </div>
            <span className="text-[12px] text-text-muted hidden sm:block">Last 2 weeks</span>
          </div>
          {loadingTrend ? (
            <div className="flex h-52 items-center justify-center">
              <LoadingSpinner label="Loading trend…" />
            </div>
          ) : trend14.every((d) => d.present === 0 && d.absent === 0 && d.half === 0) ? (
            <div className="flex h-52 flex-col items-center justify-center gap-3 text-center">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-bg-elevated border border-border">
                <BarChart2 className="h-7 w-7 text-text-muted" />
              </div>
              <div>
                <p className="text-[13px] font-medium text-text-secondary">Not enough attendance history</p>
                <p className="text-[12px] text-text-muted mt-1">Attendance trends will appear after several days of records.</p>
              </div>
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={trend14} margin={{ top: 4, right: 8, left: -10, bottom: 0 }} barCategoryGap="35%">
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border-strong)" vertical={false} />
                <XAxis dataKey="label" tick={{ fontSize: 11, fill: 'var(--text-muted)' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 11, fill: 'var(--text-muted)' }} allowDecimals={false} axisLine={false} tickLine={false} />
                <Tooltip
                  contentStyle={{ borderRadius: 8, border: '1px solid var(--border-strong)', fontSize: 12, backgroundColor: 'var(--bg-elevated)', color: 'var(--text-primary)' }}
                  cursor={{ fill: 'var(--bg-elevated)' }}
                />
                <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: 12, color: 'var(--text-secondary)' }} />
                <Bar dataKey="present" name="Present" fill="var(--success)" radius={[4, 4, 0, 0]} />
                <Bar dataKey="absent"  name="Absent"  fill="var(--danger)" radius={[4, 4, 0, 0]} />
                <Bar dataKey="half"    name="Half Day" fill="var(--warning)" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>

        <div className="rounded-xl border border-border bg-bg-card p-5">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h3 className="text-[16px] font-medium text-text-primary">Payroll Summary</h3>
              <p className="text-[12px] text-text-muted mt-0.5">This month</p>
            </div>
          </div>
          {loadingPay ? (
            <LoadingSpinner label="Loading…" />
          ) : (
            <div className="space-y-3">
              {[
                { label: 'Gross Salary', value: payrollSummary.total, color: 'var(--gold)', bg: 'var(--gold-bg)', bar: null },
                { label: 'Advances',     value: payrollSummary.advances, color: 'var(--warning)', bg: 'var(--warning-bg)', bar: null },
                { label: 'Salary Paid',  value: payrollSummary.salary,   color: 'var(--success)', bg: 'var(--success-bg)', bar: null },
              ].map((row) => (
                <div key={row.label} className="flex items-center justify-between rounded-lg px-4 py-3" style={{ background: row.bg }}>
                  <span className="text-[13px] text-text-secondary font-medium">{row.label}</span>
                  <span className="text-[14px] font-mono font-medium" style={{ color: row.color }}>{formatCurrency(row.value)}</span>
                </div>
              ))}

              {payrollSummary.total > 0 && (
                <div className="mt-4">
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-[11px] uppercase tracking-wider text-text-muted">Advance ratio</span>
                    <span className="text-[12px] font-mono font-medium text-warning">{Math.round((payrollSummary.advances / payrollSummary.total) * 100)}%</span>
                  </div>
                  <div className="h-2 w-full overflow-hidden rounded-full bg-bg-elevated border border-border-strong">
                    <div
                      className="h-full rounded-full transition-all bg-warning"
                      style={{ width: `${Math.min(100, (payrollSummary.advances / payrollSummary.total) * 100).toFixed(0)}%` }}
                    />
                  </div>
                </div>
              )}

              <button
                onClick={() => navigate('/payroll')}
                className="w-full mt-4 flex items-center justify-center gap-2 rounded-lg bg-gold text-bg-primary font-medium text-[13px] py-2.5 transition-transform hover:scale-[1.02]"
              >
                Open Payroll Calculator
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Live attendance feed */}
      <div className="rounded-xl border border-border bg-bg-card overflow-hidden">
        <div className="flex items-center justify-between border-b border-border px-5 py-4">
          <div className="flex items-center gap-3">
            <h3 className="text-[16px] font-medium text-text-primary">Today's Live Attendance Feed</h3>
            <span className="flex items-center gap-1.5 rounded-full bg-success-bg border border-success/30 px-2.5 py-1 text-[11px] font-medium text-success uppercase tracking-wider">
              <span className="h-1.5 w-1.5 rounded-full bg-success live-dot" />
              Live
            </span>
          </div>
          <span className="text-[12px] font-medium text-text-muted uppercase tracking-wider">{attendanceToday.length} records</span>
        </div>

        {loadingToday ? (
          <div className="py-10"><LoadingSpinner label="Loading feed…" /></div>
        ) : attendanceToday.length === 0 ? (
          <div className="flex flex-col items-center justify-center gap-3 py-12 text-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-xl bg-bg-elevated border border-border-strong">
              <Clock className="h-7 w-7 text-text-muted" />
            </div>
            <div>
              <p className="text-[14px] font-medium text-text-secondary">No attendance recorded today yet</p>
              <p className="text-[12px] text-text-muted mt-1">Start marking attendance to see the live feed here.</p>
            </div>
            <button onClick={() => navigate('/attendance')} className="mt-2 flex items-center gap-2 rounded-lg bg-gold text-bg-primary font-medium text-[13px] px-4 py-2 transition-transform hover:scale-105 shadow-[0_0_15px_rgba(245,166,35,0.15)]">
              <Plus className="h-4 w-4" /> Mark Attendance
            </button>
          </div>
        ) : (
          <div className="max-h-72 overflow-y-auto">
            <table className="w-full text-[13px]">
              <thead className="sticky top-0 border-b border-border bg-bg-elevated">
                <tr>
                  {['Labour', 'Supervisor', 'Status', 'Via', 'OT Hrs'].map((h, i) => (
                    <th key={h} className={`px-5 py-3 text-[10px] font-medium uppercase tracking-widest text-text-muted ${i === 4 ? 'text-right' : 'text-left'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {attendanceToday.map((r) => {
                  const labour = labourMap.get(r.labourId);
                  const supervisor = supervisorMap.get(r.supervisorId);
                  return (
                    <tr key={r.id} className="border-b border-border last:border-b-0 hover:bg-bg-elevated transition-colors">
                      <td className="px-5 py-3">
                        <div className="flex items-center gap-3">
                          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-bg-elevated border border-border-strong text-[12px] font-mono font-medium text-text-secondary">
                            {(labour?.name || '?')[0].toUpperCase()}
                          </div>
                          <span className="font-medium text-text-primary">{labour?.name || r.labourId?.slice(0, 8) || '—'}</span>
                        </div>
                      </td>
                      <td className="px-5 py-3 text-text-secondary">{supervisor?.name || '—'}</td>
                      <td className="px-5 py-3"><StatusBadge status={r.status} /></td>
                      <td className="px-5 py-3"><MarkedViaBadge via={r.markedVia} /></td>
                      <td className="px-5 py-3 text-right font-mono font-medium text-text-secondary">{r.overtimeHours || 0}</td>
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
