import React, { useMemo, useState } from 'react';
import { Calculator, Download, CheckCircle } from 'lucide-react';
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
      payments
        .filter((p) => p.type === 'advance')
        .forEach((p) => advByLabour.set(p.labourId, (advByLabour.get(p.labourId) || 0) + (p.amount || 0)));

      const rows = labours.map((l) => {
        const recs = attendance.filter((r) => r.labourId === l.id);
        const present = recs.filter((r) => r.status === 'present').length;
        const half = recs.filter((r) => r.status === 'half').length;
        const absent = recs.filter((r) => r.status === 'absent').length;
        const otHours = recs.reduce((s, r) => s + (Number(r.overtimeHours) || 0), 0);
        const totalDays = present + half * 0.5;
        const dailyWage = Number(l.dailyWage) || 0;
        const otRate = Number(l.overtimeWagePerHour) || 0;
        const gross = totalDays * dailyWage + otHours * otRate;
        const advances = advByLabour.get(l.id) || 0;
        return {
          labourId: l.id,
          name: l.name,
          present,
          half,
          absent,
          otHours,
          totalDays,
          gross,
          advances,
          net: gross - advances,
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
    () =>
      report.reduce(
        (acc, r) => ({ gross: acc.gross + r.gross, advances: acc.advances + r.advances, net: acc.net + r.net }),
        { gross: 0, advances: 0, net: 0 },
      ),
    [report],
  );

  const toggleSelect = (id) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleAll = () => {
    setSelected((prev) =>
      prev.size === report.length ? new Set() : new Set(report.map((r) => r.labourId)),
    );
  };

  const markAsPaid = async () => {
    if (!writeScope) return toast.error('No scope selected');
    if (selected.size === 0) return toast.error('Select labours first');
    const dateStr = monthBounds(month, year).end;
    setPaying(true);
    const t = toast.loading(`Creating ${selected.size} salary payment(s)…`);
    try {
      await Promise.all(
        Array.from(selected).map((labourId) => {
          const row = report.find((r) => r.labourId === labourId);
          if (!row || row.net <= 0) return null;
          return addPayment({
            scopeId: writeScope,
            supervisorId: writeScope,
            contractorId: scopeId,
            labourId,
            type: 'salary',
            amount: Math.round(row.net),
            date: dateStr,
            notes: `Auto-generated salary for ${MONTHS[month - 1]} ${year}`,
          });
        }).filter(Boolean),
      );
      toast.dismiss(t);
      toast.success('Salary payments recorded');
      setSelected(new Set());
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
      Name: r.name,
      'Days Present': r.present,
      'Half Days': r.half,
      'Days Absent': r.absent,
      'OT Hours': r.otHours,
      'Total Days': r.totalDays,
      Gross: Math.round(r.gross),
      Advances: Math.round(r.advances),
      Net: Math.round(r.net),
    })));
    toast.success('CSV downloaded');
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight text-slate-950">Payroll Calculator</h2>
          <p className="mt-1 text-sm text-slate-500">Calculate monthly salary and mark as paid in bulk.</p>
        </div>
      </div>

      <div className="flex flex-wrap items-end gap-3 rounded-2xl border border-slate-200/70 bg-white/90 p-4 shadow-sm">
        <div className="space-y-1">
          <Label>Month</Label>
          <select value={month} onChange={(e) => setMonth(Number(e.target.value))} className="h-10 rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20">
            {MONTHS.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
          </select>
        </div>
        <div className="space-y-1">
          <Label>Year</Label>
          <select value={year} onChange={(e) => setYear(Number(e.target.value))} className="h-10 rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20">
            {years.map((y) => <option key={y} value={y}>{y}</option>)}
          </select>
        </div>
        <Button onClick={handleGenerate} disabled={running} className="gap-2 bg-blue-600 text-white hover:bg-blue-700">
          <Calculator className="h-4 w-4" /> {running ? 'Calculating…' : 'Calculate Payroll'}
        </Button>
        {loaded && (
          <>
            <Button variant="outline" onClick={handleExport} className="gap-2">
              <Download className="h-4 w-4" /> Export CSV
            </Button>
            <Button
              onClick={markAsPaid}
              disabled={paying || selected.size === 0}
              className="gap-2 bg-green-600 text-white hover:bg-green-700"
            >
              <CheckCircle className="h-4 w-4" />
              {paying ? 'Processing…' : `Mark ${selected.size > 0 ? selected.size : ''} as Paid`}
            </Button>
          </>
        )}
      </div>

      {loaded && (
        <div className="grid gap-4 sm:grid-cols-3">
          <div className="rounded-2xl border border-slate-200/70 bg-white/90 p-4 shadow-sm">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Total Gross</p>
            <p className="mt-1 text-xl font-semibold text-slate-950">{formatCurrency(totals.gross)}</p>
          </div>
          <div className="rounded-2xl border border-slate-200/70 bg-white/90 p-4 shadow-sm">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Total Advances</p>
            <p className="mt-1 text-xl font-semibold text-slate-950">{formatCurrency(totals.advances)}</p>
          </div>
          <div className="rounded-2xl border border-slate-200/70 bg-white/90 p-4 shadow-sm">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Net Payable</p>
            <p className="mt-1 text-xl font-semibold text-green-700">{formatCurrency(totals.net)}</p>
          </div>
        </div>
      )}

      <div className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm">
        {running ? (
          <LoadingSpinner label="Calculating payroll…" />
        ) : !loaded ? (
          <EmptyState icon={Calculator} title="No payroll generated" description="Select a month and click Calculate Payroll." />
        ) : report.length === 0 ? (
          <EmptyState icon={Calculator} title="No labours found" description="Add labours first." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th className="px-4 py-3">
                    <input type="checkbox" checked={selected.size === report.length && report.length > 0} onChange={toggleAll} className="rounded border-slate-300" />
                  </th>
                  <th className="px-4 py-3">Labour</th>
                  <th className="px-4 py-3 text-right">Days</th>
                  <th className="px-4 py-3 text-right">OT Hrs</th>
                  <th className="px-4 py-3 text-right">Gross</th>
                  <th className="px-4 py-3 text-right">Advances</th>
                  <th className="px-4 py-3 text-right">Net</th>
                </tr>
              </thead>
              <tbody>
                {report.map((r) => (
                  <tr key={r.labourId} className={`border-b border-slate-100 last:border-b-0 transition ${selected.has(r.labourId) ? 'bg-blue-50' : 'hover:bg-slate-50'}`}>
                    <td className="px-4 py-3">
                      <input type="checkbox" checked={selected.has(r.labourId)} onChange={() => toggleSelect(r.labourId)} className="rounded border-slate-300" />
                    </td>
                    <td className="px-4 py-3 font-medium text-slate-900">{r.name}</td>
                    <td className="px-4 py-3 text-right text-slate-700">{r.totalDays}</td>
                    <td className="px-4 py-3 text-right text-slate-700">{r.otHours}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{formatCurrency(r.gross)}</td>
                    <td className="px-4 py-3 text-right text-slate-700">{formatCurrency(r.advances)}</td>
                    <td className={`px-4 py-3 text-right font-semibold ${r.net < 0 ? 'text-red-600' : 'text-green-700'}`}>
                      {formatCurrency(r.net)}
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t border-slate-200 bg-slate-50 font-semibold text-slate-900">
                  <td className="px-4 py-3" colSpan={4}>Totals</td>
                  <td className="px-4 py-3 text-right">{formatCurrency(totals.gross)}</td>
                  <td className="px-4 py-3 text-right">{formatCurrency(totals.advances)}</td>
                  <td className="px-4 py-3 text-right text-green-700">{formatCurrency(totals.net)}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
