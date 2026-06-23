import React, { useMemo, useState } from 'react';
import {
  Calendar, Download, FileText, ClipboardList, TrendingUp, Wallet, Activity,
  Building2, Users, BarChart3, ChevronDown, ChevronUp,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { useLabours } from '../hooks/useLabours';
import { getAttendanceRange } from '../lib/services/attendance.service';
import { getPayments } from '../lib/services/payments.service';
import { exportCSV, formatCurrency } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import StatusBadge from '../components/shared/StatusBadge';

const MONTHS = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December',
];

const TABS = [
  { id: 'monthly',      label: 'Monthly Salary',  icon: Calendar },
  { id: 'attendance',   label: 'Attendance',       icon: ClipboardList },
  { id: 'overtime',     label: 'Overtime',         icon: TrendingUp },
  { id: 'payment',      label: 'Payments',         icon: Wallet },
  { id: 'productivity', label: 'Productivity',     icon: Activity },
  { id: 'sitewise',     label: 'Site-wise',        icon: Building2 },
  { id: 'labourwise',   label: 'Labour-wise',      icon: Users },
  { id: 'overall',      label: 'Overall',          icon: BarChart3 },
];

function monthBounds(month, year) {
  const start = `${year}-${String(month).padStart(2, '0')}-01`;
  const lastDay = new Date(year, month, 0).getDate();
  const end = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
  return { start, end };
}

function dateRangeBounds(from, to) { return { start: from, end: to }; }

export default function Reports() {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const isSupervisor = role === 'supervisor';
  const scopeId = useScopeId();
  const { data: labours = [] } = useLabours({ activeOnly: false });

  const now = new Date();
  const [activeTab, setActiveTab] = useState('monthly');
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [fromDate, setFromDate] = useState(`${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`);
  const [toDate, setToDate] = useState(`${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()).padStart(2, '0')}`);
  const [labourFilter, setLabourFilter] = useState('all');

  const [report, setReport] = useState([]);
  const [loaded, setLoaded] = useState(false);
  const [running, setRunning] = useState(false);
  const [expandedSite, setExpandedSite] = useState(null);

  const years = Array.from({ length: 5 }, (_, i) => now.getFullYear() - i);

  const labourMap = useMemo(() => {
    const m = new Map();
    labours.forEach((l) => m.set(l.id, l));
    return m;
  }, [labours]);

  const targetLabours = useMemo(
    () => labourFilter === 'all' ? labours : labours.filter((l) => l.id === labourFilter),
    [labours, labourFilter],
  );

  const handleGenerate = async () => {
    setRunning(true);
    try {
      const usesMonthPicker = ['monthly', 'overtime', 'productivity', 'sitewise', 'overall'].includes(activeTab);
      const usesLabourFilter = activeTab === 'labourwise';
      const bounds = usesMonthPicker ? monthBounds(month, year) : dateRangeBounds(fromDate, toDate);

      const labourIdForQuery = usesLabourFilter && labourFilter !== 'all' ? labourFilter : null;

      const [attendance, payments] = await Promise.all([
        getAttendanceRange(scopeId, bounds.start, bounds.end, labourIdForQuery, isSupervisor, isSupervisor ? uid : null),
        activeTab !== 'labourwise' && activeTab !== 'sitewise'
          ? getPayments(scopeId, { startDate: bounds.start, endDate: bounds.end })
          : Promise.resolve([]),
      ]);

      const advByLabour = new Map();
      payments.filter((p) => p.type === 'advance').forEach((p) =>
        advByLabour.set(p.labourId, (advByLabour.get(p.labourId) || 0) + (p.amount || 0)),
      );

      if (activeTab === 'monthly') {
        const rows = targetLabours.map((l) => {
          const recs = attendance.filter((r) => r.labourId === l.id);
          const present = recs.filter((r) => r.status === 'present').length;
          const half    = recs.filter((r) => r.status === 'half').length;
          const absent  = recs.filter((r) => r.status === 'absent').length;
          const otHours = recs.reduce((s, r) => s + (Number(r.overtimeHours) || 0), 0);
          const totalDays = present + half * 0.5;

          const avgWageAtTime = recs.length > 0
            ? recs.reduce((s, r) => s + (Number(r.wageAtTime) || Number(l.dailyWage) || 0), 0) / recs.length
            : Number(l.dailyWage) || 0;

          const gross = totalDays * avgWageAtTime + otHours * (Number(l.overtimeWagePerHour) || 0);
          const advances = advByLabour.get(l.id) || 0;
          return {
            labourId: l.id, name: l.name, phone: l.phone,
            dailyWage: l.dailyWage, wageAtTime: avgWageAtTime, otRate: l.overtimeWagePerHour,
            present, half, absent, otHours, totalDays, gross, advances, net: gross - advances,
          };
        });
        setReport(rows.sort((a, b) => String(a.name).localeCompare(String(b.name))));

      } else if (activeTab === 'attendance') {
        const totalDaysInRange = Math.round((new Date(bounds.end) - new Date(bounds.start)) / 86400000) + 1;
        const rows = targetLabours.map((l) => {
          const recs = attendance.filter((r) => r.labourId === l.id);
          const present = recs.filter((r) => r.status === 'present').length;
          const half    = recs.filter((r) => r.status === 'half').length;
          const absent  = recs.filter((r) => r.status === 'absent').length;
          const rate    = totalDaysInRange > 0 ? Math.round(((present + half * 0.5) / totalDaysInRange) * 100) : 0;
          return { labourId: l.id, name: l.name, present, half, absent, rate };
        });
        setReport(rows.sort((a, b) => b.rate - a.rate));

      } else if (activeTab === 'overtime') {
        const rows = targetLabours
          .map((l) => {
            const recs = attendance.filter((r) => r.labourId === l.id);
            const otHours = recs.reduce((s, r) => s + (Number(r.overtimeHours) || 0), 0);
            const otCost  = otHours * (Number(l.overtimeWagePerHour) || 0);
            return { labourId: l.id, name: l.name, otRate: l.overtimeWagePerHour, otHours, otCost };
          })
          .filter((r) => r.otHours > 0)
          .sort((a, b) => b.otHours - a.otHours);
        setReport(rows);

      } else if (activeTab === 'payment') {
        setReport(payments.sort((a, b) => {
          const da = a.date instanceof Date ? a.date : a.date?.toDate?.() || new Date(0);
          const db2 = b.date instanceof Date ? b.date : b.date?.toDate?.() || new Date(0);
          return db2 - da;
        }));

      } else if (activeTab === 'productivity') {
        const totalDays = Math.round((new Date(bounds.end) - new Date(bounds.start)) / 86400000) + 1;
        const rows = targetLabours.map((l) => {
          const recs = attendance.filter((r) => r.labourId === l.id);
          const present = recs.filter((r) => r.status === 'present').length;
          const half    = recs.filter((r) => r.status === 'half').length;
          const absent  = recs.filter((r) => r.status === 'absent').length;
          const rate    = totalDays > 0 ? Math.round(((present + half * 0.5) / totalDays) * 100) : 0;
          return { labourId: l.id, name: l.name, present, half, absent, rate, totalDays };
        });
        setReport(rows.sort((a, b) => b.rate - a.rate));

      } else if (activeTab === 'sitewise') {
        const bySite = new Map();
        attendance.forEach((r) => {
          const site = r.siteId || r.supervisorId || 'Unknown';
          if (!bySite.has(site)) bySite.set(site, []);
          bySite.get(site).push(r);
        });
        const rows = Array.from(bySite.entries()).map(([site, recs]) => {
          const present = recs.filter((r) => r.status === 'present').length;
          const half    = recs.filter((r) => r.status === 'half').length;
          const absent  = recs.filter((r) => r.status === 'absent').length;
          const totalWage = recs.reduce((s, r) => {
            const wage = Number(r.wageAtTime) || Number(labourMap.get(r.labourId)?.dailyWage) || 0;
            if (r.status === 'present') return s + wage;
            if (r.status === 'half') return s + wage * 0.5;
            return s;
          }, 0);
          const otHours = recs.reduce((s, r) => s + (Number(r.overtimeHours) || 0), 0);
          const totalAllowance = recs.reduce((s, r) => {
            const al = r.allowances || {};
            return s + (Number(al.petrol) || 0) + (Number(al.lunch) || 0) + (Number(al.breakfast) || 0) + (Number(al.tea) || 0);
          }, 0);
          const totalAdvance = recs.reduce((s, r) => s + (Number(r.advance) || 0), 0);
          const uniqueLabours = [...new Set(recs.map((r) => r.labourId))];
          return {
            siteId: site,
            siteName: `Site: ${site.slice(0, 8)}…`,
            present, half, absent,
            totalRecords: recs.length, uniqueLabours: uniqueLabours.length,
            totalWage, otHours, totalAllowance, totalAdvance,
            grandTotal: totalWage + totalAllowance - totalAdvance,
            records: recs,
          };
        });
        setReport(rows.sort((a, b) => b.totalWage - a.totalWage));

      } else if (activeTab === 'labourwise') {
        const filteredRecs = labourFilter === 'all' ? attendance : attendance.filter((r) => r.labourId === labourFilter);
        const rows = filteredRecs
          .map((r) => {
            const labour = labourMap.get(r.labourId);
            const wageAtTime = Number(r.wageAtTime) || Number(labour?.dailyWage) || 0;
            const earned = r.status === 'present' ? wageAtTime : r.status === 'half' ? wageAtTime * 0.5 : 0;
            const al = r.allowances || {};
            const totalAllowance = (Number(al.petrol) || 0) + (Number(al.lunch) || 0) + (Number(al.breakfast) || 0) + (Number(al.tea) || 0);
            const advance = Number(r.advance) || 0;
            return {
              date: r.date,
              labourId: r.labourId,
              labourName: labour?.name || r.labourId,
              status: r.status,
              overtimeHours: Number(r.overtimeHours) || 0,
              remark: r.remark || r.notes || '',
              wageAtTime,
              siteId: r.siteId || r.supervisorId || '—',
              earned,
              allowances: al,
              totalAllowance,
              advance,
              grandTotal: earned + totalAllowance - advance,
            };
          })
          .sort((a, b) => b.date.localeCompare(a.date));
        setReport(rows);

      } else if (activeTab === 'overall') {
        const [tempAttendance] = await Promise.all([
          getAttendanceRange(scopeId, bounds.start, bounds.end, null, isSupervisor, isSupervisor ? uid : null),
        ]);

        const regularRows = labours.filter((l) => l.type !== 'temporary').map((l) => {
          const recs = tempAttendance.filter((r) => r.labourId === l.id);
          const present = recs.filter((r) => r.status === 'present').length;
          const half    = recs.filter((r) => r.status === 'half').length;
          const otHours = recs.reduce((s, r) => s + (Number(r.overtimeHours) || 0), 0);
          const avgWage = recs.length > 0
            ? recs.reduce((s, r) => s + (Number(r.wageAtTime) || Number(l.dailyWage) || 0), 0) / recs.length
            : Number(l.dailyWage) || 0;
          const gross = (present + half * 0.5) * avgWage + otHours * (Number(l.overtimeWagePerHour) || 0);
          const advances = advByLabour.get(l.id) || 0;
          return { labourId: l.id, name: l.name, type: 'regular', present, half, otHours, gross, advances, net: gross - advances };
        });

        const tempRows = labours.filter((l) => l.type === 'temporary').map((l) => {
          const recs = tempAttendance.filter((r) => r.labourId === l.id);
          const present = recs.filter((r) => r.status === 'present').length;
          const half    = recs.filter((r) => r.status === 'half').length;
          const avgWage = recs.length > 0
            ? recs.reduce((s, r) => s + (Number(r.wageAtTime) || Number(l.dailyWage) || 0), 0) / recs.length
            : Number(l.dailyWage) || 0;
          const gross = (present + half * 0.5) * avgWage;
          return { labourId: l.id, name: l.name, type: 'temporary', present, half, otHours: 0, gross, advances: 0, net: gross };
        });

        const allRows = [...regularRows, ...tempRows].filter((r) => r.present + r.half > 0);
        setReport(allRows.sort((a, b) => b.gross - a.gross));
      }

      setLoaded(true);
      toast.success(`Report ready — ${attendance.length} records`);
    } catch (err) {
      console.error(err);
      toast.error('Failed to generate report: ' + err.message);
    } finally {
      setRunning(false);
    }
  };

  const switchTab = (tab) => { setActiveTab(tab); setReport([]); setLoaded(false); setExpandedSite(null); };

  const totals = useMemo(() => {
    if (activeTab === 'monthly') return report.reduce((acc, r) => ({ gross: acc.gross + r.gross, adv: acc.adv + r.advances, net: acc.net + r.net, ot: acc.ot + r.otHours }), { gross: 0, adv: 0, net: 0, ot: 0 });
    if (activeTab === 'overtime') return report.reduce((acc, r) => ({ ot: acc.ot + r.otHours, cost: acc.cost + r.otCost }), { ot: 0, cost: 0 });
    if (activeTab === 'payment') return report.reduce((acc, p) => ({ total: acc.total + (p.amount || 0) }), { total: 0 });
    if (activeTab === 'sitewise') return report.reduce((acc, r) => ({ wage: acc.wage + r.totalWage, ot: acc.ot + r.otHours, records: acc.records + r.totalRecords, totalAllowance: acc.totalAllowance + (r.totalAllowance || 0), grandTotal: acc.grandTotal + (r.grandTotal || 0) }), { wage: 0, ot: 0, records: 0, totalAllowance: 0, grandTotal: 0 });
    if (activeTab === 'overall') return report.reduce((acc, r) => ({ gross: acc.gross + r.gross, adv: acc.adv + r.advances, net: acc.net + r.net }), { gross: 0, adv: 0, net: 0 });
    if (activeTab === 'labourwise') return report.reduce((acc, r) => ({ earned: acc.earned + r.earned, ot: acc.ot + r.overtimeHours, totalAllowance: acc.totalAllowance + (r.totalAllowance || 0), grandTotal: acc.grandTotal + (r.grandTotal || 0) }), { earned: 0, ot: 0, totalAllowance: 0, grandTotal: 0 });
    return {};
  }, [report, activeTab]);

  const handleExport = () => {
    if (report.length === 0) return toast.error('Generate report first');
    const monthName = MONTHS[month - 1];
    let filename = `report-${activeTab}`;
    let rows = [];

    if (activeTab === 'monthly') {
      filename = `Salary_${monthName}_${year}.csv`;
      rows = report.map((r) => ({ Name: r.name, Phone: r.phone, 'Daily Wage': r.dailyWage, 'Wage At Time': r.wageAtTime?.toFixed(2), 'OT Rate': r.otRate, Present: r.present, Half: r.half, Absent: r.absent, 'OT Hours': r.otHours, Gross: Math.round(r.gross), Advances: Math.round(r.advances), Net: Math.round(r.net) }));
    } else if (activeTab === 'attendance') {
      filename = `Attendance_${fromDate}_to_${toDate}.csv`;
      rows = report.map((r) => ({ Name: r.name, Present: r.present, Half: r.half, Absent: r.absent, 'Attendance %': `${r.rate}%` }));
    } else if (activeTab === 'overtime') {
      filename = `Overtime_${monthName}_${year}.csv`;
      rows = report.map((r) => ({ Name: r.name, 'OT Rate/hr': r.otRate, 'Total OT Hours': r.otHours, 'OT Cost': Math.round(r.otCost) }));
    } else if (activeTab === 'payment') {
      filename = `Payments_${fromDate}_to_${toDate}.csv`;
      rows = report.map((p) => ({ Date: p.date instanceof Date ? p.date.toLocaleDateString('en-IN') : '', Labour: labourMap.get(p.labourId)?.name || p.labourId, Type: p.type, Method: p.paymentMethod || 'cash', Amount: p.amount, Notes: p.notes }));
    } else if (activeTab === 'productivity') {
      filename = `Productivity_${monthName}_${year}.csv`;
      rows = report.map((r) => ({ Name: r.name, Present: r.present, Half: r.half, Absent: r.absent, 'Attendance %': `${r.rate}%`, 'Total Days': r.totalDays }));
    } else if (activeTab === 'sitewise') {
      filename = `SiteWise_${monthName}_${year}.csv`;
      rows = report.map((r) => ({ Site: r.siteId, Present: r.present, Half: r.half, Absent: r.absent, 'Unique Labours': r.uniqueLabours, 'Total Wage': Math.round(r.totalWage), 'OT Hours': r.otHours, 'Total Allowance': Math.round(r.totalAllowance || 0), 'Total Advance': Math.round(r.totalAdvance || 0), 'Grand Total': Math.round(r.grandTotal || 0) }));
    } else if (activeTab === 'labourwise') {
      filename = `LabourWise_${fromDate}_to_${toDate}.csv`;
      rows = report.map((r) => ({ Date: r.date, Labour: r.labourName, Status: r.status, 'OT Hours': r.overtimeHours, Remark: r.remark, 'Wage At Time': r.wageAtTime, Site: r.siteId, Earned: Math.round(r.earned), 'Petrol': Math.round(r.allowances?.petrol || 0), 'Lunch': Math.round(r.allowances?.lunch || 0), 'Breakfast': Math.round(r.allowances?.breakfast || 0), 'Tea': Math.round(r.allowances?.tea || 0), 'Total Allowance': Math.round(r.totalAllowance || 0), 'Advance': Math.round(r.advance || 0), 'Grand Total': Math.round(r.grandTotal || 0) }));
    } else if (activeTab === 'overall') {
      filename = `Overall_${monthName}_${year}.csv`;
      rows = report.map((r) => ({ Name: r.name, Type: r.type, Present: r.present, Half: r.half, 'OT Hours': r.otHours, Gross: Math.round(r.gross), Advances: Math.round(r.advances), Net: Math.round(r.net) }));
    }
    exportCSV(filename, rows);
    toast.success('CSV downloaded');
  };

  const usesMonthPicker = ['monthly', 'overtime', 'productivity', 'sitewise', 'overall'].includes(activeTab);
  const usesDateRange   = ['attendance', 'payment', 'labourwise'].includes(activeTab);

  return (
    <div className="space-y-6">

      <div className="flex flex-wrap gap-2 rounded-2xl border border-slate-200/70 bg-white/90 p-1 shadow-sm">
        {TABS.map((t) => (
          <button
            key={t.id}
            onClick={() => switchTab(t.id)}
            className={`flex items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-medium transition ${
              activeTab === t.id ? 'bg-blue-600 text-white shadow' : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
            }`}
          >
            <t.icon className="h-4 w-4" />
            {t.label}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap items-end gap-3 rounded-2xl border border-slate-200/70 bg-white/90 p-4 shadow-sm">
        {usesMonthPicker ? (
          <>
            <div className="space-y-0.5">
              <Label className="text-xs text-slate-500">Month</Label>
              <select value={month} onChange={(e) => setMonth(Number(e.target.value))} className="h-10 rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500">
                {MONTHS.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
              </select>
            </div>
            <div className="space-y-0.5">
              <Label className="text-xs text-slate-500">Year</Label>
              <select value={year} onChange={(e) => setYear(Number(e.target.value))} className="h-10 rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500">
                {years.map((y) => <option key={y} value={y}>{y}</option>)}
              </select>
            </div>
          </>
        ) : (
          <>
            <div className="space-y-0.5">
              <Label className="text-xs text-slate-500">From</Label>
              <Input type="date" value={fromDate} onChange={(e) => setFromDate(e.target.value)} className="h-10 w-40" />
            </div>
            <div className="space-y-0.5">
              <Label className="text-xs text-slate-500">To</Label>
              <Input type="date" value={toDate} onChange={(e) => setToDate(e.target.value)} className="h-10 w-40" />
            </div>
          </>
        )}
        <div className="space-y-0.5">
          <Label className="text-xs text-slate-500">Labour</Label>
          <select value={labourFilter} onChange={(e) => setLabourFilter(e.target.value)} className="h-10 rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500">
            <option value="all">All labours</option>
            {labours.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
          </select>
        </div>
        <Button onClick={handleGenerate} disabled={running} className="gap-2 bg-blue-600 text-white hover:bg-blue-700">
          <FileText className="h-4 w-4" /> {running ? 'Generating…' : 'Generate'}
        </Button>
        <Button variant="outline" onClick={handleExport} disabled={report.length === 0} className="gap-2">
          <Download className="h-4 w-4" /> Export CSV
        </Button>
      </div>

      {loaded && activeTab === 'monthly' && (
        <div className="grid gap-3 sm:grid-cols-4">
          {[{ label: 'Gross', value: formatCurrency(totals.gross) }, { label: 'Advances', value: formatCurrency(totals.adv) }, { label: 'Net Payable', value: formatCurrency(totals.net) }, { label: 'OT Hours', value: totals.ot }].map((s) => (
            <div key={s.label} className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{s.label}</p>
              <p className="mt-1 text-xl font-semibold text-slate-950">{s.value}</p>
            </div>
          ))}
        </div>
      )}

      {loaded && activeTab === 'overtime' && (
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Total OT Hours</p>
            <p className="mt-1 text-xl font-semibold text-slate-950">{totals.ot}</p>
          </div>
          <div className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Total OT Cost</p>
            <p className="mt-1 text-xl font-semibold text-slate-950">{formatCurrency(totals.cost)}</p>
          </div>
        </div>
      )}

      {loaded && activeTab === 'payment' && (
        <div className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Total Payments</p>
          <p className="mt-1 text-xl font-semibold text-slate-950">{formatCurrency(totals.total)}</p>
        </div>
      )}

      {loaded && activeTab === 'sitewise' && (
        <div className="grid gap-3 sm:grid-cols-3">
          {[{ label: 'Total Wage', value: formatCurrency(totals.wage) }, { label: 'OT Hours', value: totals.ot }, { label: 'Total Records', value: totals.records }].map((s) => (
            <div key={s.label} className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{s.label}</p>
              <p className="mt-1 text-xl font-semibold text-slate-950">{s.value}</p>
            </div>
          ))}
        </div>
      )}

      {loaded && activeTab === 'overall' && (
        <div className="grid gap-3 sm:grid-cols-3">
          {[{ label: 'Grand Total Gross', value: formatCurrency(totals.gross) }, { label: 'Total Advances', value: formatCurrency(totals.adv) }, { label: 'Net Payable', value: formatCurrency(totals.net) }].map((s) => (
            <div key={s.label} className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{s.label}</p>
              <p className="mt-1 text-xl font-semibold text-slate-950">{s.value}</p>
            </div>
          ))}
        </div>
      )}

      {loaded && activeTab === 'labourwise' && (
        <div className="grid gap-3 sm:grid-cols-2">
          {[{ label: 'Total Earned', value: formatCurrency(totals.earned) }, { label: 'Total OT Hours', value: totals.ot }].map((s) => (
            <div key={s.label} className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{s.label}</p>
              <p className="mt-1 text-xl font-semibold text-slate-950">{s.value}</p>
            </div>
          ))}
        </div>
      )}

      <div className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm">
        {running ? (
          <LoadingSpinner label="Generating report…" />
        ) : !loaded ? (
          <EmptyState icon={FileText} title="No report yet" description="Select filters and click Generate." />
        ) : report.length === 0 ? (
          <EmptyState icon={FileText} title="No data for this period" description="Try different filters." />
        ) : (
          <div className="overflow-x-auto">
            {activeTab === 'monthly' && (
              <table className="w-full text-sm">
                <thead className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-4 py-3">Labour</th>
                    <th className="px-4 py-3 text-right">Daily Wage</th>
                    <th className="px-4 py-3 text-right" title="Wage at time of marking">Wage @Mark</th>
                    <th className="px-4 py-3 text-right">OT Rate</th>
                    <th className="px-4 py-3 text-right">P</th>
                    <th className="px-4 py-3 text-right">H</th>
                    <th className="px-4 py-3 text-right">A</th>
                    <th className="px-4 py-3 text-right">OT Hrs</th>
                    <th className="px-4 py-3 text-right">Gross</th>
                    <th className="px-4 py-3 text-right">Advances</th>
                    <th className="px-4 py-3 text-right">Net</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r) => (
                    <tr key={r.labourId} className="border-b border-slate-100 last:border-b-0 hover:bg-slate-50">
                      <td className="px-4 py-3 font-medium text-slate-900">{r.name}</td>
                      <td className="px-4 py-3 text-right text-slate-700">{formatCurrency(r.dailyWage)}</td>
                      <td className="px-4 py-3 text-right text-blue-700 font-medium">{formatCurrency(r.wageAtTime)}</td>
                      <td className="px-4 py-3 text-right text-slate-700">{r.otRate ? formatCurrency(r.otRate) : '—'}</td>
                      <td className="px-4 py-3 text-right text-slate-700">{r.present}</td>
                      <td className="px-4 py-3 text-right text-slate-700">{r.half}</td>
                      <td className="px-4 py-3 text-right text-slate-700">{r.absent}</td>
                      <td className="px-4 py-3 text-right text-slate-700">{r.otHours}</td>
                      <td className="px-4 py-3 text-right font-semibold">{formatCurrency(r.gross)}</td>
                      <td className="px-4 py-3 text-right text-slate-700">{formatCurrency(r.advances)}</td>
                      <td className={`px-4 py-3 text-right font-semibold ${r.net < 0 ? 'text-red-600' : 'text-green-700'}`}>{formatCurrency(r.net)}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr className="border-t border-slate-200 bg-slate-50 font-semibold text-slate-900">
                    <td className="px-4 py-3" colSpan={8}>Totals</td>
                    <td className="px-4 py-3 text-right">{formatCurrency(totals.gross)}</td>
                    <td className="px-4 py-3 text-right">{formatCurrency(totals.adv)}</td>
                    <td className="px-4 py-3 text-right text-green-700">{formatCurrency(totals.net)}</td>
                  </tr>
                </tfoot>
              </table>
            )}

            {activeTab === 'attendance' && (
              <table className="w-full text-sm">
                <thead className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-4 py-3">Labour</th>
                    <th className="px-4 py-3 text-right">Present</th>
                    <th className="px-4 py-3 text-right">Half</th>
                    <th className="px-4 py-3 text-right">Absent</th>
                    <th className="px-4 py-3">Attendance Rate</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r) => (
                    <tr key={r.labourId} className="border-b border-slate-100 last:border-b-0 hover:bg-slate-50">
                      <td className="px-4 py-3 font-medium text-slate-900">{r.name}</td>
                      <td className="px-4 py-3 text-right text-green-700">{r.present}</td>
                      <td className="px-4 py-3 text-right text-amber-700">{r.half}</td>
                      <td className="px-4 py-3 text-right text-red-600">{r.absent}</td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <div className="h-2 w-24 overflow-hidden rounded-full bg-slate-100">
                            <div className="h-full rounded-full bg-green-500" style={{ width: `${r.rate}%` }} />
                          </div>
                          <span className={`text-sm font-semibold ${r.rate >= 75 ? 'text-green-700' : r.rate >= 50 ? 'text-amber-700' : 'text-red-600'}`}>{r.rate}%</span>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {activeTab === 'overtime' && (
              <table className="w-full text-sm">
                <thead className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-4 py-3">Labour</th>
                    <th className="px-4 py-3 text-right">OT Rate/hr</th>
                    <th className="px-4 py-3 text-right">Total OT Hours</th>
                    <th className="px-4 py-3 text-right">OT Cost</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r) => (
                    <tr key={r.labourId} className="border-b border-slate-100 last:border-b-0 hover:bg-slate-50">
                      <td className="px-4 py-3 font-medium text-slate-900">{r.name}</td>
                      <td className="px-4 py-3 text-right text-slate-700">{r.otRate ? formatCurrency(r.otRate) : '—'}</td>
                      <td className="px-4 py-3 text-right font-semibold text-slate-900">{r.otHours}</td>
                      <td className="px-4 py-3 text-right font-semibold text-purple-700">{formatCurrency(r.otCost)}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr className="border-t border-slate-200 bg-slate-50 font-semibold text-slate-900">
                    <td className="px-4 py-3" colSpan={2}>Totals</td>
                    <td className="px-4 py-3 text-right">{totals.ot}</td>
                    <td className="px-4 py-3 text-right text-purple-700">{formatCurrency(totals.cost)}</td>
                  </tr>
                </tfoot>
              </table>
            )}

            {activeTab === 'payment' && (
              <table className="w-full text-sm">
                <thead className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-4 py-3">Date</th>
                    <th className="px-4 py-3">Labour</th>
                    <th className="px-4 py-3">Type</th>
                    <th className="px-4 py-3">Method</th>
                    <th className="px-4 py-3 text-right">Amount</th>
                    <th className="px-4 py-3">Notes</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((p) => (
                    <tr key={p.id} className="border-b border-slate-100 last:border-b-0 hover:bg-slate-50">
                      <td className="px-4 py-3 text-slate-700">{p.date instanceof Date ? p.date.toLocaleDateString('en-IN') : p.date?.toDate?.()?.toLocaleDateString?.('en-IN') || '—'}</td>
                      <td className="px-4 py-3 font-medium text-slate-900">{labourMap.get(p.labourId)?.name || p.labourId}</td>
                      <td className="px-4 py-3"><StatusBadge status={p.type || 'salary'} /></td>
                      <td className="px-4 py-3 capitalize text-slate-700">{p.paymentMethod || 'cash'}</td>
                      <td className="px-4 py-3 text-right font-semibold text-slate-900">{formatCurrency(p.amount)}</td>
                      <td className="px-4 py-3 text-slate-600">{p.notes || '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {activeTab === 'productivity' && (
              <table className="w-full text-sm">
                <thead className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-4 py-3">Rank</th>
                    <th className="px-4 py-3">Labour</th>
                    <th className="px-4 py-3 text-right">Present</th>
                    <th className="px-4 py-3 text-right">Half</th>
                    <th className="px-4 py-3 text-right">Absent</th>
                    <th className="px-4 py-3">Attendance Rate</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r, i) => (
                    <tr key={r.labourId} className="border-b border-slate-100 last:border-b-0 hover:bg-slate-50">
                      <td className="px-4 py-3 text-slate-500 font-medium">#{i + 1}</td>
                      <td className="px-4 py-3 font-medium text-slate-900">{r.name}</td>
                      <td className="px-4 py-3 text-right text-green-700">{r.present}</td>
                      <td className="px-4 py-3 text-right text-amber-700">{r.half}</td>
                      <td className="px-4 py-3 text-right text-red-600">{r.absent}</td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <div className="h-2 w-24 overflow-hidden rounded-full bg-slate-100">
                            <div className="h-full rounded-full bg-green-500" style={{ width: `${r.rate}%` }} />
                          </div>
                          <span className={`font-semibold ${r.rate >= 75 ? 'text-green-700' : r.rate >= 50 ? 'text-amber-700' : 'text-red-600'}`}>{r.rate}%</span>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {activeTab === 'sitewise' && (
              <table className="w-full text-sm">
                <thead className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-4 py-3">Site</th>
                    <th className="px-4 py-3 text-right">Labours</th>
                    <th className="px-4 py-3 text-right">Present</th>
                    <th className="px-4 py-3 text-right">Half</th>
                    <th className="px-4 py-3 text-right">Absent</th>
                    <th className="px-4 py-3 text-right">OT Hrs</th>
                    <th className="px-4 py-3 text-right">Total Wage</th>
                    <th className="px-4 py-3 text-right">Allowances</th>
                    <th className="px-4 py-3 text-right">Grand Total</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r) => (
                    <React.Fragment key={r.siteId}>
                      <tr
                        className="border-b border-slate-100 hover:bg-blue-50/50 cursor-pointer"
                        onClick={() => setExpandedSite(expandedSite === r.siteId ? null : r.siteId)}
                      >
                        <td className="px-4 py-3 font-medium text-slate-900 flex items-center gap-2">
                          <Building2 className="h-4 w-4 text-blue-500" />
                          {r.siteId.length > 20 ? r.siteId.slice(0, 16) + '…' : r.siteId}
                          {expandedSite === r.siteId ? <ChevronUp className="h-3.5 w-3.5 text-slate-400" /> : <ChevronDown className="h-3.5 w-3.5 text-slate-400" />}
                        </td>
                        <td className="px-4 py-3 text-right text-slate-700">{r.uniqueLabours}</td>
                        <td className="px-4 py-3 text-right text-green-700 font-medium">{r.present}</td>
                        <td className="px-4 py-3 text-right text-amber-700">{r.half}</td>
                        <td className="px-4 py-3 text-right text-red-600">{r.absent}</td>
                        <td className="px-4 py-3 text-right text-slate-700">{r.otHours}</td>
                        <td className="px-4 py-3 text-right font-semibold text-slate-900">{formatCurrency(r.totalWage)}</td>
                        <td className="px-4 py-3 text-right font-medium text-amber-700">{r.totalAllowance > 0 ? formatCurrency(r.totalAllowance) : '—'}</td>
                        <td className="px-4 py-3 text-right font-bold text-blue-700">{formatCurrency(r.grandTotal || r.totalWage)}</td>
                      </tr>
                      {expandedSite === r.siteId && (
                        <tr>
                          <td colSpan={9} className="bg-slate-50 px-4 py-2">
                            <table className="w-full text-xs">
                              <thead>
                                <tr className="text-slate-500">
                                  <th className="py-1 text-left">Labour</th>
                                  <th className="py-1 text-right">Date</th>
                                  <th className="py-1 text-right">Status</th>
                                  <th className="py-1 text-right">Wage @Mark</th>
                                  <th className="py-1 text-right">Allowances</th>
                                  <th className="py-1 text-right">Advance</th>
                                  <th className="py-1 text-right">Remark</th>
                                </tr>
                              </thead>
                              <tbody>
                                {r.records.slice(0, 20).map((rec, idx) => {
                                  const al = rec.allowances || {};
                                  const recAllowance = (Number(al.petrol)||0)+(Number(al.lunch)||0)+(Number(al.breakfast)||0)+(Number(al.tea)||0);
                                  return (
                                    <tr key={idx} className="border-t border-slate-100">
                                      <td className="py-1 text-slate-700">{labourMap.get(rec.labourId)?.name || rec.labourId}</td>
                                      <td className="py-1 text-right text-slate-600">{rec.date}</td>
                                      <td className="py-1 text-right"><StatusBadge status={rec.status} /></td>
                                      <td className="py-1 text-right text-blue-600">{formatCurrency(rec.wageAtTime || 0)}</td>
                                      <td className="py-1 text-right text-amber-600">{recAllowance > 0 ? formatCurrency(recAllowance) : '—'}</td>
                                      <td className="py-1 text-right text-red-500">{rec.advance > 0 ? `-${formatCurrency(rec.advance)}` : '—'}</td>
                                      <td className="py-1 text-right text-slate-500 italic">{rec.remark || '—'}</td>
                                    </tr>
                                  );
                                })}
                                {r.records.length > 20 && (
                                  <tr><td colSpan={7} className="py-1 text-center text-slate-400">+{r.records.length - 20} more records</td></tr>
                                )}
                              </tbody>
                            </table>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  ))}
                </tbody>
                <tfoot>
                  <tr className="border-t border-slate-200 bg-slate-50 font-semibold text-slate-900">
                    <td className="px-4 py-3" colSpan={5}>Totals</td>
                    <td className="px-4 py-3 text-right">{totals.ot}</td>
                    <td className="px-4 py-3 text-right text-blue-700">{formatCurrency(totals.wage)}</td>
                    <td className="px-4 py-3 text-right text-amber-700">{formatCurrency(totals.totalAllowance || 0)}</td>
                    <td className="px-4 py-3 text-right text-blue-900">{formatCurrency(totals.grandTotal || totals.wage)}</td>
                  </tr>
                </tfoot>
              </table>
            )}

            {activeTab === 'labourwise' && (
              <table className="w-full text-sm">
                <thead className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-4 py-3">Date</th>
                    <th className="px-4 py-3">Labour</th>
                    <th className="px-4 py-3">Status</th>
                    <th className="px-4 py-3 text-right">OT Hrs</th>
                    <th className="px-4 py-3 text-right">Wage @Mark</th>
                    <th className="px-4 py-3">Site</th>
                    <th className="px-4 py-3 text-right">Earned</th>
                    <th className="px-4 py-3 text-right">Allowances</th>
                    <th className="px-4 py-3 text-right">Advance</th>
                    <th className="px-4 py-3 text-right">Grand Total</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r, i) => (
                    <tr key={i} className="border-b border-slate-100 last:border-b-0 hover:bg-slate-50">
                      <td className="px-4 py-3 text-slate-700">{r.date}</td>
                      <td className="px-4 py-3 font-medium text-slate-900">{r.labourName}</td>
                      <td className="px-4 py-3"><StatusBadge status={r.status} /></td>
                      <td className="px-4 py-3 text-right text-slate-700">{r.overtimeHours || '—'}</td>
                      <td className="px-4 py-3 text-right text-blue-700 font-medium">{formatCurrency(r.wageAtTime)}</td>
                      <td className="px-4 py-3 text-xs text-slate-500">{r.siteId?.slice(0, 10) || '—'}</td>
                      <td className="px-4 py-3 text-right font-semibold text-slate-900">{formatCurrency(r.earned)}</td>
                      <td className="px-4 py-3 text-right text-amber-700">
                        {r.totalAllowance > 0 ? (
                          <span title={`Petrol: ₹${r.allowances?.petrol||0} · Lunch: ₹${r.allowances?.lunch||0} · Breakfast: ₹${r.allowances?.breakfast||0} · Tea: ₹${r.allowances?.tea||0}`}>
                            +{formatCurrency(r.totalAllowance)}
                          </span>
                        ) : '—'}
                      </td>
                      <td className="px-4 py-3 text-right text-red-600">{r.advance > 0 ? `-${formatCurrency(r.advance)}` : '—'}</td>
                      <td className="px-4 py-3 text-right font-bold text-blue-700">{r.totalAllowance > 0 || r.advance > 0 ? formatCurrency(r.grandTotal) : '—'}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr className="border-t border-slate-200 bg-slate-50 font-semibold text-slate-900">
                    <td className="px-4 py-3" colSpan={5}>Totals</td>
                    <td className="px-4 py-3 text-right">{totals.ot} OT hrs</td>
                    <td className="px-4 py-3 text-right text-green-700">{formatCurrency(totals.earned)}</td>
                    <td className="px-4 py-3 text-right text-amber-700">{formatCurrency(totals.totalAllowance || 0)}</td>
                    <td className="px-4 py-3" />
                    <td className="px-4 py-3 text-right text-blue-700">{formatCurrency(totals.grandTotal || totals.earned)}</td>
                  </tr>
                </tfoot>
              </table>
            )}

            {activeTab === 'overall' && (
              <table className="w-full text-sm">
                <thead className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-4 py-3">Labour</th>
                    <th className="px-4 py-3">Type</th>
                    <th className="px-4 py-3 text-right">Present</th>
                    <th className="px-4 py-3 text-right">Half</th>
                    <th className="px-4 py-3 text-right">OT Hrs</th>
                    <th className="px-4 py-3 text-right">Gross</th>
                    <th className="px-4 py-3 text-right">Advances</th>
                    <th className="px-4 py-3 text-right">Net</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r) => (
                    <tr key={r.labourId} className={`border-b border-slate-100 last:border-b-0 hover:bg-slate-50 ${r.type === 'temporary' ? 'bg-purple-50/40' : ''}`}>
                      <td className="px-4 py-3 font-medium text-slate-900">
                        {r.name}
                        {r.type === 'temporary' && (
                          <span className="ml-2 text-xs font-semibold text-purple-700 bg-purple-100 px-1.5 py-0.5 rounded">TEMP</span>
                        )}
                      </td>
                      <td className="px-4 py-3"><StatusBadge status={r.type} /></td>
                      <td className="px-4 py-3 text-right text-green-700">{r.present}</td>
                      <td className="px-4 py-3 text-right text-amber-700">{r.half}</td>
                      <td className="px-4 py-3 text-right text-slate-700">{r.otHours}</td>
                      <td className="px-4 py-3 text-right font-semibold">{formatCurrency(r.gross)}</td>
                      <td className="px-4 py-3 text-right text-slate-700">{formatCurrency(r.advances)}</td>
                      <td className={`px-4 py-3 text-right font-semibold ${r.net < 0 ? 'text-red-600' : 'text-green-700'}`}>{formatCurrency(r.net)}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr className="border-t-2 border-slate-300 bg-slate-50 font-bold text-slate-900">
                    <td className="px-4 py-3" colSpan={5}>Grand Total</td>
                    <td className="px-4 py-3 text-right">{formatCurrency(totals.gross)}</td>
                    <td className="px-4 py-3 text-right">{formatCurrency(totals.adv)}</td>
                    <td className="px-4 py-3 text-right text-green-700">{formatCurrency(totals.net)}</td>
                  </tr>
                </tfoot>
              </table>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
