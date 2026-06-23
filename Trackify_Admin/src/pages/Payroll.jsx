import React, { useMemo, useState } from 'react';
import { Download, CheckCircle, Calculator, Wallet, TrendingDown, TrendingUp } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { useLabours } from '../hooks/useLabours';
import { getAttendanceRange } from '../lib/services/attendance.service';
import { getPayments, addPayment } from '../lib/services/payments.service';
import { formatCurrency, exportCSV } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';

const MONTHS = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December',
];

function monthBounds(month, year) {
  const start = `${year}-${String(month).padStart(2,'0')}-01`;
  const lastDay = new Date(year, month, 0).getDate();
  const end = `${year}-${String(month).padStart(2,'0')}-${String(lastDay).padStart(2,'0')}`;
  return { start, end };
}

function SummaryCard({ label, value, sub, color = '#2563EB', icon: Icon }) {
  return (
    <div className="rounded-2xl border border-slate-200/70 bg-white p-5 shadow-sm">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-bold uppercase tracking-wide text-slate-400">{label}</p>
          <p className="mt-2 text-2xl font-bold" style={{ color }}>{value}</p>
          {sub && <p className="mt-0.5 text-xs text-slate-400">{sub}</p>}
        </div>
        {Icon && (
          <div className="flex h-10 w-10 items-center justify-center rounded-xl" style={{ background: color + '15' }}>
            <Icon className="h-5 w-5" style={{ color }} />
          </div>
        )}
      </div>
    </div>
  );
}

export default function Payroll() {
  const now = new Date();
  const uid = useAuthStore((s) => s.uid);
  const role = useAuthStore((s) => s.role);
  const scopeId = useScopeId();
  const writeScope = role === 'supervisor' ? uid : scopeId;

  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [report, setReport] = useState([]);
  const [loaded, setLoaded] = useState(false);
  const [running, setRunning] = useState(false);
  const [paying, setPaying] = useState(false);
  const [selected, setSelected] = useState(new Set());

  const { data: labours } = useLabours();
  const years = Array.from({ length: 5 }, (_, i) => now.getFullYear() - i);

  const labourMap = useMemo(() => {
    const m = new Map();
    labours.forEach((l) => m.set(l.id, l));
    return m;
  }, [labours]);

  const handleGenerate = async () => {
    if (!month || !year) return;
    setRunning(true);
    try {
      const { start, end } = monthBounds(month, year);
      const [attendance, payments] = await Promise.all([
        getAttendanceRange(scopeId, start, end),
        getPayments(scopeId, { startDate: start, endDate: end }),
      ]);

      const advByLabour = new Map();
      const salByLabour = new Map();
      payments.forEach((p) => {
        const amt = Number(p.amount) || 0;
        if (p.type === 'advance') {
          advByLabour.set(p.labourId, (advByLabour.get(p.labourId) || 0) + amt);
        } else if (p.type === 'salary') {
          salByLabour.set(p.labourId, (salByLabour.get(p.labourId) || 0) + amt);
        }
      });

      const rows = labours.map((l) => {
        const recs = attendance.filter((r) => r.labourId === l.id);
        const present = recs.filter((r) => r.status === 'present').length;
        const half    = recs.filter((r) => r.status === 'half').length;
        const absent  = recs.filter((r) => r.status === 'absent').length;
        const otHours = recs.reduce((s, r) => s + (Number(r.overtimeHours) || 0), 0);
        const totalDays = present + half * 0.5;
        const dailyWage = Number(l.dailyWage) || 0;
        const otRate    = Number(l.overtimeWagePerHour) || 0;
        const gross     = totalDays * dailyWage + otHours * otRate;
        const advances  = advByLabour.get(l.id) || 0;
        const salaryPaid = salByLabour.get(l.id) || 0;
        const totalPaid  = advances + salaryPaid;
        const net        = Math.max(0, gross - totalPaid);
        return {
          labourId: l.id, name: l.name,
          present, half, absent, otHours, totalDays,
          gross, advances, salaryPaid, totalPaid,
          net,
          isPaid: salaryPaid >= gross && gross > 0,
        };
      });

      setReport(rows);
      setLoaded(true);
      setSelected(new Set());
      toast.success(`Payroll calculated for ${labours.length} labours`);
    } catch (e) {
      console.error(e);
      toast.error('Failed to calculate payroll');
    } finally {
      setRunning(false);
    }
  };

  const totals = useMemo(
    () => report.reduce(
      (acc, r) => ({
        gross:      acc.gross      + r.gross,
        advances:   acc.advances   + r.advances,
        salaryPaid: acc.salaryPaid + r.salaryPaid,
        totalPaid:  acc.totalPaid  + r.totalPaid,
        net:        acc.net        + r.net,
      }),
      { gross: 0, advances: 0, salaryPaid: 0, totalPaid: 0, net: 0 },
    ),
    [report],
  );

  const toggleSelect = (id) => {
    setSelected((prev) => { const next = new Set(prev); if (next.has(id)) next.delete(id); else next.add(id); return next; });
  };

  const toggleAll = () => {
    setSelected((prev) => prev.size === report.length ? new Set() : new Set(report.map((r) => r.labourId)));
  };

  const markAsPaid = async () => {
    if (!writeScope) return toast.error('No scope selected');
    if (selected.size === 0) return toast.error('Select labours first');

    const eligible = Array.from(selected).filter((labourId) => {
      const row = report.find((r) => r.labourId === labourId);
      return row && row.net > 0;
    });

    if (eligible.length === 0) {
      toast.error('All selected labours are already fully paid');
      return;
    }

    const skipped = selected.size - eligible.length;
    const dateStr = monthBounds(month, year).end;
    setPaying(true);
    const t = toast.loading(`Recording ${eligible.length} salary payment(s)…`);
    try {
      await Promise.all(
        eligible.map((labourId) => {
          const row = report.find((r) => r.labourId === labourId);
          return addPayment({
            scopeId: writeScope, supervisorId: writeScope, contractorId: scopeId, labourId,
            type: 'salary', amount: Math.round(row.net), date: dateStr,
            notes: `Auto-generated salary for ${MONTHS[month - 1]} ${year}`,
          });
        }),
      );
      toast.dismiss(t);
      toast.success(
        skipped > 0
          ? `${eligible.length} paid · ${skipped} skipped (already paid)`
          : `${eligible.length} salary payment(s) recorded`,
      );
      setSelected(new Set());
      await handleGenerate();
    } catch (e) {
      toast.dismiss(t);
      console.error(e);
      toast.error('Failed to mark as paid');
    } finally {
      setPaying(false);
    }
  };

  const handleExport = () => {
    if (report.length === 0) return;
    exportCSV(`Payroll_${MONTHS[month - 1]}_${year}.csv`, report.map((r) => ({
      Name: r.name, 'Days Present': r.present, 'Half Days': r.half, 'Days Absent': r.absent,
      'OT Hours': r.otHours, 'Total Days': r.totalDays, Gross: Math.round(r.gross),
      Advances: Math.round(r.advances), Net: Math.round(r.net),
    })));
    toast.success('CSV downloaded');
  };

  const selectClass = "h-10 rounded-xl border border-slate-200 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20";

  return (
    <div className="space-y-6">
      {/* Controls */}
      <div className="rounded-2xl border border-slate-200/70 bg-white p-5 shadow-sm">
        <p className="mb-4 text-xs font-bold uppercase tracking-wide text-slate-400">Select Period</p>
        <div className="flex flex-wrap items-end gap-3">
          <div className="space-y-1.5">
            <Label className="text-xs font-semibold text-slate-600">Month</Label>
            <select value={month} onChange={(e) => setMonth(Number(e.target.value))} className={selectClass}>
              {MONTHS.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
            </select>
          </div>
          <div className="space-y-1.5">
            <Label className="text-xs font-semibold text-slate-600">Year</Label>
            <select value={year} onChange={(e) => setYear(Number(e.target.value))} className={selectClass}>
              {years.map((y) => <option key={y} value={y}>{y}</option>)}
            </select>
          </div>
          <Button onClick={handleGenerate} disabled={running} className="gap-2 text-white h-10 px-5" style={{ background: '#2563EB' }}>
            <Calculator className="h-4 w-4" /> {running ? 'Calculating…' : 'Calculate Payroll'}
          </Button>
          {loaded && (
            <>
              <Button variant="outline" onClick={handleExport} className="gap-2 h-10">
                <Download className="h-4 w-4" /> Export CSV
              </Button>
              <Button
                onClick={markAsPaid}
                disabled={paying || selected.size === 0}
                className="gap-2 text-white h-10"
                style={{ background: '#16A34A' }}
              >
                <CheckCircle className="h-4 w-4" />
                {paying ? 'Processing…' : `Mark ${selected.size > 0 ? selected.size : ''} as Paid`}
              </Button>
            </>
          )}
        </div>
      </div>

      {/* Summary cards */}
      {loaded && (
        <div className="grid gap-4 sm:grid-cols-4">
          <SummaryCard label="Total Gross"    value={formatCurrency(totals.gross)}      icon={Wallet}      color="#2563EB" sub={`${MONTHS[month-1]} ${year}`} />
          <SummaryCard label="Advances Paid"  value={formatCurrency(totals.advances)}   icon={TrendingDown} color="#D97706" sub="cash advances given" />
          <SummaryCard label="Salary Paid"    value={formatCurrency(totals.salaryPaid)} icon={CheckCircle} color="#16A34A" sub="salary disbursed" />
          <SummaryCard label="Net Remaining"  value={formatCurrency(totals.net)}        icon={TrendingUp}  color={totals.net === 0 ? '#16A34A' : '#DC2626'} sub={totals.net === 0 ? 'all paid ✓' : 'still to pay'} />
        </div>
      )}

      {/* Table */}
      <div className="rounded-2xl border border-slate-200/70 bg-white shadow-sm overflow-hidden">
        {running ? (
          <div className="py-12"><LoadingSpinner label="Calculating payroll…" /></div>
        ) : !loaded ? (
          <EmptyState icon={Calculator} title="No payroll generated" description="Select a month and year, then click Calculate Payroll." />
        ) : report.length === 0 ? (
          <EmptyState icon={Calculator} title="No labours found" description="Add labours first to generate payroll." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-slate-100 bg-slate-50/50">
                <tr>
                  <th className="w-10 px-4 py-3">
                    <input type="checkbox" checked={selected.size === report.length && report.length > 0} onChange={toggleAll} className="rounded border-slate-300" />
                  </th>
                  {['Labour', 'Days', 'OT Hrs', 'Gross', 'Advances', 'Salary Paid', 'Net Due'].map((h, i) => (
                    <th key={h} className={`px-4 py-3 text-xs font-bold uppercase tracking-wide text-slate-400 ${i === 0 ? 'text-left' : 'text-right'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {report.map((r) => (
                  <tr key={r.labourId} className={`border-b border-slate-50 last:border-b-0 transition ${selected.has(r.labourId) ? 'bg-blue-50/60' : r.isPaid ? 'bg-green-50/40' : 'hover:bg-slate-50/60'}`}>
                    <td className="px-4 py-3.5">
                      <input
                        type="checkbox"
                        checked={selected.has(r.labourId)}
                        onChange={() => toggleSelect(r.labourId)}
                        disabled={r.isPaid}
                        className="rounded border-slate-300 disabled:opacity-40"
                      />
                    </td>
                    <td className="px-4 py-3.5">
                      <div className="flex items-center gap-2.5">
                        <div className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold ${r.isPaid ? 'bg-green-100 text-green-700' : 'bg-blue-100 text-blue-700'}`}>
                          {(r.name || '?')[0].toUpperCase()}
                        </div>
                        <div>
                          <span className="font-semibold text-slate-900">{r.name}</span>
                          {r.isPaid && (
                            <span className="ml-2 inline-flex items-center gap-1 rounded-full bg-green-100 px-2 py-0.5 text-xs font-bold text-green-700">
                              ✓ Paid
                            </span>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3.5 text-right text-slate-700">{r.totalDays}</td>
                    <td className="px-4 py-3.5 text-right text-slate-700">{r.otHours}</td>
                    <td className="px-4 py-3.5 text-right font-semibold text-slate-900">{formatCurrency(r.gross)}</td>
                    <td className="px-4 py-3.5 text-right text-amber-700">{r.advances > 0 ? formatCurrency(r.advances) : <span className="text-slate-300">—</span>}</td>
                    <td className="px-4 py-3.5 text-right text-green-700 font-semibold">{r.salaryPaid > 0 ? formatCurrency(r.salaryPaid) : <span className="text-slate-300">—</span>}</td>
                    <td className={`px-4 py-3.5 text-right font-bold ${r.net === 0 ? 'text-green-600' : r.net < 0 ? 'text-red-600' : 'text-slate-900'}`}>
                      {r.net === 0 ? <span className="text-green-600">₹0</span> : formatCurrency(r.net)}
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t-2 border-slate-200 bg-slate-50 font-bold text-slate-900">
                  <td className="px-4 py-3.5" colSpan={4}>Totals</td>
                  <td className="px-4 py-3.5 text-right">{formatCurrency(totals.gross)}</td>
                  <td className="px-4 py-3.5 text-right text-amber-700">{formatCurrency(totals.advances)}</td>
                  <td className="px-4 py-3.5 text-right text-green-700">{formatCurrency(totals.salaryPaid)}</td>
                  <td className={`px-4 py-3.5 text-right ${totals.net === 0 ? 'text-green-600' : 'text-slate-900'}`}>{formatCurrency(totals.net)}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
