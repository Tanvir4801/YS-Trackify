import { motion, AnimatePresence } from 'framer-motion';
import React, { useMemo, useState } from 'react';
import { Download, CheckCircle, Calculator, Wallet, TrendingDown, TrendingUp } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { useLabours } from '../hooks/useLabours';
import { getAttendanceRange } from '../lib/services/attendance.service';
import { getPayments, addPayment } from '../lib/services/payments.service';
import { formatCurrency, exportExcel, monthBounds } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import { useBranding } from '../context/BrandingContext';
import { generatePDF } from '../lib/pdfGenerator';

const MONTHS = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December',
];

function SummaryCard({ label, value, sub, color = 'var(--gold)', icon: Icon }) {
  return (
    <div className="rounded-xl border border-border bg-bg-card px-5 py-4 flex flex-col justify-between transition-colors hover:border-border-strong group">
      <div className="flex items-start justify-between">
        <p className="text-[11px] font-bold uppercase tracking-widest text-text-muted">{label}</p>
        {Icon && (
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-bg-elevated text-text-muted transition-colors group-hover:text-gold" style={{ color: color }}>
            <Icon className="h-[18px] w-[18px]" style={{ color }} />
          </div>
        )}
      </div>
      <div className="mt-4">
        <p className="text-2xl font-bold font-mono tracking-tight" style={{ color }}>{value}</p>
        {sub && <p className="mt-1 text-[11px] uppercase tracking-wider text-text-muted">{sub}</p>}
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
  const { branding } = useBranding();

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
        const three_quarter = recs.filter((r) => r.status === 'three_quarter').length;
        const half    = recs.filter((r) => r.status === 'half').length;
        const quarter = recs.filter((r) => r.status === 'quarter').length;
        const absent  = recs.filter((r) => r.status === 'absent').length;
        const otHours = recs.reduce((s, r) => s + (Number(r.overtimeHours) || 0), 0);
        const totalDays = present + three_quarter * 0.75 + half * 0.5 + quarter * 0.25;
        const dailyWage = Number(l.dailyWage) || 0;
        const otRate    = Number(l.overtimeWagePerHour) || 0;
        const gross     = totalDays * dailyWage + otHours * otRate;
        const advances  = advByLabour.get(l.id) || 0;
        const salaryPaid = salByLabour.get(l.id) || 0;
        const totalPaid  = advances + salaryPaid;
        const net        = gross - totalPaid;
        return {
          labourId: l.id, name: l.name,
          present, half, absent, otHours, totalDays,
          gross, advances, salaryPaid, totalPaid,
          net,
          isPaid: gross > 0 && net <= 0,
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
      return row && !row.isPaid;
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
            type: 'salary', amount: Math.max(0, Math.round(row.net)), date: dateStr,
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
    exportExcel(`Payroll_${MONTHS[month - 1]}_${year}.csv`, report.map((r) => ({
      Name: r.name, 'Days Present': r.present, 'Half Days': r.half, 'Days Absent': r.absent,
      'OT Hours': r.otHours, 'Total Days': r.totalDays, Gross: Math.round(r.gross),
      Advances: Math.round(r.advances), Net: Math.round(r.net),
    })));
    toast.success('Excel downloaded');
  };

  const handleExportPDF = () => {
    if (report.length === 0) return toast.error('Calculate payroll first');
    const monthName = MONTHS[month - 1];
    
    generatePDF({
      title: 'Payroll Report',
      subtitle: `For ${monthName} ${year}`,
      filename: `Payroll_${monthName}_${year}.pdf`,
      columns: ['Name', 'Days', 'OT Hrs', 'Gross', 'Advances', 'Net Due'],
      rows: report.map((r) => [
        r.name,
        r.totalDays,
        r.otHours,
        formatCurrency(r.gross),
        r.advances > 0 ? formatCurrency(r.advances) : '-',
        r.net <= 0 ? 'Paid' : formatCurrency(r.net),
      ]),
      totals: {
        'Total Gross': formatCurrency(totals.gross),
        'Total Advances': formatCurrency(totals.advances),
        'Salary Paid': formatCurrency(totals.salaryPaid),
        'Net Remaining': formatCurrency(totals.net)
      },
      branding
    });
    toast.success('PDF downloaded');
  };

  const selectClass = "h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary outline-none focus:border-gold focus:ring-1 focus:ring-gold";

  return (
    <div className="space-y-6">
      {/* Controls */}
      <div className="rounded-xl border border-border bg-bg-card px-6 py-5 flex flex-wrap items-center justify-between gap-4">
        <div className="flex flex-wrap items-end gap-3">
          <div className="space-y-1.5 flex flex-col">
            <label className="text-[10px] uppercase tracking-widest text-text-muted font-medium ml-1">Month</label>
            <select value={month} onChange={(e) => setMonth(Number(e.target.value))} className={selectClass}>
              {MONTHS.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
            </select>
          </div>
          <div className="space-y-1.5 flex flex-col">
            <label className="text-[10px] uppercase tracking-widest text-text-muted font-medium ml-1">Year</label>
            <select value={year} onChange={(e) => setYear(Number(e.target.value))} className={selectClass}>
              {years.map((y) => <option key={y} value={y}>{y}</option>)}
            </select>
          </div>
          <button 
            onClick={handleGenerate} 
            disabled={running} 
            className="flex h-9 items-center gap-2 rounded-lg bg-gold px-5 text-[13px] font-semibold text-bg-primary shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-105 transition-all disabled:opacity-50 disabled:hover:scale-100 ml-2"
          >
            <Calculator className="h-4 w-4" /> {running ? 'Calculating…' : 'Calculate Payroll'}
          </button>
        </div>
        {loaded && (
          <div className="flex items-center gap-3">
            <button onClick={handleExport} className="flex h-9 items-center gap-2 rounded-lg border border-border-strong bg-bg-elevated px-4 text-[13px] font-medium text-text-secondary hover:text-text-primary transition-colors">
              <Download className="h-4 w-4" /> CSV
            </button>
            <button onClick={handleExportPDF} className="flex h-9 items-center gap-2 rounded-lg border border-border-strong bg-bg-elevated px-4 text-[13px] font-medium text-text-secondary hover:text-text-primary transition-colors">
              <Download className="h-4 w-4" /> PDF
            </button>
            <button
              onClick={markAsPaid}
              disabled={paying || selected.size === 0}
              className="flex h-9 items-center gap-2 rounded-lg border border-success/30 bg-success-bg px-4 text-[13px] font-semibold text-success hover:bg-success hover:text-bg-primary transition-all disabled:opacity-50"
            >
              <CheckCircle className="h-4 w-4" />
              {paying ? 'Processing…' : `Mark ${selected.size > 0 ? selected.size : ''} as Paid`}
            </button>
          </div>
        )}
      </div>

      {/* Summary cards */}
      {loaded && (
        <div className="grid gap-4 sm:grid-cols-4">
          <SummaryCard label="Total Gross"    value={formatCurrency(totals.gross)}      icon={Wallet}      color="var(--gold)" sub={`${MONTHS[month-1]} ${year}`} />
          <SummaryCard label="Advances Paid"  value={formatCurrency(totals.advances)}   icon={TrendingDown} color="#D97706" sub="cash advances given" />
          <SummaryCard label="Salary Paid"    value={formatCurrency(totals.salaryPaid)} icon={CheckCircle} color="#16A34A" sub="salary disbursed" />
          <SummaryCard label="Net Remaining"  value={formatCurrency(totals.net)}        icon={TrendingUp}  color={totals.net === 0 ? '#16A34A' : '#DC2626'} sub={totals.net === 0 ? 'all paid ✓' : 'still to pay'} />
        </div>
      )}

      {/* Table */}
      <div className="rounded-xl border border-border bg-bg-card shadow-sm overflow-hidden">
        {running ? (
          <div className="py-12"><LoadingSpinner label="Calculating payroll…" /></div>
        ) : !loaded ? (
          <EmptyState icon={Calculator} title="No payroll generated" description="Select a month and year, then click Calculate Payroll." />
        ) : report.length === 0 ? (
          <EmptyState icon={Calculator} title="No labours found" description="Add labours first to generate payroll." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-[13px]">
              <thead className="border-b border-border bg-bg-elevated">
                <tr>
                  <th className="px-5 py-3 w-10">
                    <input type="checkbox" checked={selected.size === report.length && report.length > 0} onChange={toggleAll} className="accent-gold h-4 w-4 cursor-pointer" />
                  </th>
                  {['Labour', 'Days', 'OT Hrs', 'Gross', 'Advances', 'Salary Paid', 'Net Due'].map((h, i) => (
                    <th key={h} className={`px-5 py-3 text-[10px] font-bold uppercase tracking-widest text-text-muted ${i === 0 ? 'text-left' : 'text-right'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {report.map((r) => (
                  <tr key={r.labourId} className={`border-b border-border last:border-b-0 transition-colors ${selected.has(r.labourId) ? 'bg-gold/5' : r.isPaid ? 'bg-success/5' : 'hover:bg-bg-card-hover'}`}>
                    <td className="px-5 py-3.5">
                      <input
                        type="checkbox"
                        checked={selected.has(r.labourId)}
                        onChange={() => toggleSelect(r.labourId)}
                        disabled={r.isPaid}
                        className="accent-gold h-4 w-4 cursor-pointer disabled:opacity-40"
                      />
                    </td>
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-3">
                        <div className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-[12px] font-mono font-medium border ${r.isPaid ? 'bg-success/20 text-success border-success/30' : 'bg-info/20 text-info border-info/30'}`}>
                          {(r.name || '?')[0].toUpperCase()}
                        </div>
                        <div>
                          <span className="font-medium text-text-primary">{r.name}</span>
                          {r.isPaid && (
                            <span className="ml-2 inline-flex items-center gap-1 rounded bg-success-bg border border-success/30 px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wider text-success">
                              ✓ Paid
                            </span>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-3.5 text-right font-mono text-text-secondary">{r.totalDays}</td>
                    <td className="px-5 py-3.5 text-right font-mono text-text-secondary">{r.otHours}</td>
                    <td className="px-5 py-3.5 text-right font-mono font-medium text-text-primary">{formatCurrency(r.gross)}</td>
                    <td className="px-5 py-3.5 text-right font-mono text-warning">{r.advances > 0 ? formatCurrency(r.advances) : <span className="text-border-strong">—</span>}</td>
                    <td className="px-5 py-3.5 text-right font-mono font-medium text-success">{r.salaryPaid > 0 ? formatCurrency(r.salaryPaid) : <span className="text-border-strong">—</span>}</td>
                    <td className={`px-5 py-3.5 text-right font-mono font-bold ${r.net <= 0 ? (r.net < 0 ? 'text-danger' : 'text-success') : 'text-gold'}`}>
                      {r.net <= 0
                        ? <span className={r.net < 0 ? 'text-danger' : 'text-success'}>
                            {r.net < 0 ? `+${formatCurrency(Math.abs(r.net))} overpaid` : '✓ Paid'}
                          </span>
                        : formatCurrency(r.net)}
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t-2 border-border-strong bg-bg-elevated font-mono font-bold text-text-primary">
                  <td className="px-5 py-4 uppercase tracking-widest text-[11px]" colSpan={4}>Totals</td>
                  <td className="px-5 py-4 text-right">{formatCurrency(totals.gross)}</td>
                  <td className="px-5 py-4 text-right text-warning">{formatCurrency(totals.advances)}</td>
                  <td className="px-5 py-4 text-right text-success">{formatCurrency(totals.salaryPaid)}</td>
                  <td className={`px-5 py-4 text-right ${totals.net <= 0 ? 'text-success' : 'text-gold'}`}>{formatCurrency(totals.net)}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
