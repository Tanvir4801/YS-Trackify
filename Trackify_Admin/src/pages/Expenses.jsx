import React, { useEffect, useMemo, useState } from 'react';
import { Receipt, ChevronLeft, ChevronRight, TrendingDown, Fuel, Coffee, Utensils, Sandwich } from 'lucide-react';
import { useAuthStore, useScopeId } from '../store/authStore';
import { useLabours } from '../hooks/useLabours';
import { getAttendanceRange } from '../lib/services/attendance.service';
import { todayKey, toDateKey, formatCurrency } from '../lib/utils';
import LoadingSpinner from '../components/shared/LoadingSpinner';

function buildMonthRange(year, month) {
  const start = `${year}-${String(month).padStart(2, '0')}-01`;
  const last = new Date(year, month, 0).getDate();
  const end = `${year}-${String(month).padStart(2, '0')}-${String(last).padStart(2, '0')}`;
  return { start, end };
}

const MONTH_NAMES = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function AllowanceChip({ icon: Icon, label, value, color }) {
  return (
    <div className={`flex flex-col items-center gap-1.5 rounded-xl border p-4 ${color}`}>
      <Icon className="h-5 w-5 mb-1" />
      <span className="text-[11px] font-semibold uppercase tracking-widest text-text-muted">{label}</span>
      <span className="text-[15px] font-mono font-bold tracking-tight">{formatCurrency(value)}</span>
    </div>
  );
}

export default function Expenses() {
  const role = useAuthStore((s) => s.role);
  const scopeId = useScopeId();
  const { data: labours = [] } = useLabours();

  const now = new Date();
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);

  const isCurrentMonth = month === now.getMonth() + 1 && year === now.getFullYear();

  function shiftMonth(delta) {
    let m = month + delta;
    let y = year;
    if (m > 12) { m = 1; y++; }
    if (m < 1) { m = 12; y--; }
    setMonth(m);
    setYear(y);
  }

  useEffect(() => {
    if (!scopeId && role !== 'super_admin') {
      setRecords([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    const { start, end } = buildMonthRange(year, month);
    const today = todayKey();
    const effectiveEnd = isCurrentMonth ? today : end;
    getAttendanceRange(scopeId, start, effectiveEnd)
      .then(setRecords)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [scopeId, month, year, role, isCurrentMonth]);

  const labourMap = useMemo(() => {
    const m = new Map();
    labours.forEach((l) => m.set(l.id, l));
    return m;
  }, [labours]);

  const totals = useMemo(() => {
    let petrol = 0, lunch = 0, breakfast = 0, tea = 0, advance = 0;
    records.forEach((r) => {
      petrol    += Number(r.petrol)    || 0;
      lunch     += Number(r.lunch)     || 0;
      breakfast += Number(r.breakfast) || 0;
      tea       += Number(r.tea)       || 0;
      advance   += Number(r.advance)   || 0;
    });
    return { petrol, lunch, breakfast, tea, advance, allowances: petrol + lunch + breakfast + tea };
  }, [records]);

  const byLabour = useMemo(() => {
    const map = new Map();
    records.forEach((r) => {
      if (!r.labourId) return;
      const p = Number(r.petrol) || 0;
      const l = Number(r.lunch) || 0;
      const b = Number(r.breakfast) || 0;
      const t = Number(r.tea) || 0;
      const a = Number(r.advance) || 0;
      if (p + l + b + t + a === 0) return;
      const prev = map.get(r.labourId) || { petrol: 0, lunch: 0, breakfast: 0, tea: 0, advance: 0 };
      map.set(r.labourId, {
        petrol:    prev.petrol    + p,
        lunch:     prev.lunch     + l,
        breakfast: prev.breakfast + b,
        tea:       prev.tea       + t,
        advance:   prev.advance   + a,
      });
    });
    return [...map.entries()]
      .map(([labourId, vals]) => ({ labourId, ...vals, total: vals.petrol + vals.lunch + vals.breakfast + vals.tea }))
      .sort((a, b) => b.total - a.total);
  }, [records]);

  const byDate = useMemo(() => {
    const map = new Map();
    records.forEach((r) => {
      if (!r.date) return;
      const p = Number(r.petrol) || 0;
      const l = Number(r.lunch) || 0;
      const b = Number(r.breakfast) || 0;
      const t = Number(r.tea) || 0;
      if (p + l + b + t === 0) return;
      const prev = map.get(r.date) || { petrol: 0, lunch: 0, breakfast: 0, tea: 0, count: 0 };
      map.set(r.date, {
        petrol:    prev.petrol    + p,
        lunch:     prev.lunch     + l,
        breakfast: prev.breakfast + b,
        tea:       prev.tea       + t,
        count:     prev.count + 1,
      });
    });
    return [...map.entries()]
      .map(([date, vals]) => ({ date, ...vals, total: vals.petrol + vals.lunch + vals.breakfast + vals.tea }))
      .sort((a, b) => b.date.localeCompare(a.date));
  }, [records]);

  return (
    <div className="space-y-6">
      <div className="rounded-xl border border-border bg-bg-card px-6 py-5 flex flex-wrap items-center justify-between gap-4 shadow-sm">
        <div className="text-[13px] text-text-secondary uppercase tracking-widest font-medium">
          Labour-wise and day-wise breakdown of daily allowances for <span className="font-semibold text-text-primary ml-1">{MONTH_NAMES[month]} {year}</span>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => shiftMonth(-1)}
            className="flex h-9 w-9 items-center justify-center rounded-lg border border-border-strong bg-bg-elevated text-text-muted hover:text-text-primary hover:border-gold transition-colors"
          >
            <ChevronLeft className="h-4 w-4" />
          </button>
          <span className="min-w-28 text-center text-[13px] font-bold text-text-primary uppercase tracking-widest">
            {MONTH_NAMES[month]} {year}
          </span>
          <button
            onClick={() => shiftMonth(1)}
            disabled={isCurrentMonth}
            className="flex h-9 w-9 items-center justify-center rounded-lg border border-border-strong bg-bg-elevated text-text-muted hover:text-text-primary hover:border-gold transition-colors disabled:opacity-30 disabled:pointer-events-none"
          >
            <ChevronRight className="h-4 w-4" />
          </button>
        </div>
      </div>

      {loading ? (
        <LoadingSpinner label="Loading allowances…" />
      ) : (
        <>
          {/* ── SUMMARY CHIPS ─────────────────────────────────────── */}
          <div className="rounded-xl border border-border bg-bg-card p-6 shadow-sm">
            <h3 className="mb-5 text-[12px] font-semibold uppercase tracking-widest text-text-muted border-b border-border pb-3">
              Monthly totals — {MONTH_NAMES[month]} {year}
            </h3>
            {totals.allowances === 0 && totals.advance === 0 ? (
              <p className="text-[13px] text-text-muted py-4">No allowances recorded for this period.</p>
            ) : (
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
                <AllowanceChip icon={Fuel}     label="Petrol"    value={totals.petrol}    color="border-info/30   bg-info/5   text-info"   />
                <AllowanceChip icon={Utensils}  label="Lunch"     value={totals.lunch}     color="border-success/30  bg-success-bg  text-success"  />
                <AllowanceChip icon={Sandwich}  label="Breakfast" value={totals.breakfast} color="border-warning/30  bg-warning/10  text-warning"  />
                <AllowanceChip icon={Coffee}    label="Tea"       value={totals.tea}       color="border-gold/30 bg-gold/10 text-gold" />
                <div className="flex flex-col items-center gap-1.5 rounded-xl border border-danger/30 bg-danger-bg p-4 text-danger">
                  <TrendingDown className="h-5 w-5 mb-1" />
                  <span className="text-[11px] font-semibold uppercase tracking-widest text-danger">Advances</span>
                  <span className="text-[15px] font-mono font-bold tracking-tight">{formatCurrency(totals.advance)}</span>
                </div>
              </div>
            )}
            {totals.allowances > 0 && (
              <div className="mt-5 rounded-lg border border-border-strong bg-bg-elevated px-5 py-3 text-[13px] flex items-center gap-4">
                <span className="text-text-secondary uppercase tracking-widest text-[11px] font-medium">Total allowances:</span>
                <span className="font-mono font-bold text-text-primary text-[15px]">{formatCurrency(totals.allowances)}</span>
                {totals.advance > 0 && (
                  <>
                    <div className="h-5 w-px bg-border-strong mx-2"></div>
                    <span className="text-text-secondary uppercase tracking-widest text-[11px] font-medium">Total advances:</span>
                    <span className="font-mono font-bold text-danger text-[15px]">{formatCurrency(totals.advance)}</span>
                  </>
                )}
              </div>
            )}
          </div>

          {/* ── PER-LABOUR TABLE ──────────────────────────────────── */}
          {byLabour.length > 0 && (
            <div className="rounded-xl border border-border bg-bg-card shadow-sm overflow-hidden">
              <div className="border-b border-border px-6 py-5 bg-bg-elevated">
                <h3 className="text-[13px] font-semibold text-text-primary uppercase tracking-widest">Labour-wise Breakdown</h3>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-[13px]">
                  <thead className="border-b border-border text-left text-[10px] uppercase tracking-widest text-text-muted">
                    <tr>
                      <th className="px-6 py-4 font-medium">Labour</th>
                      <th className="px-6 py-4 font-medium text-right">🚗 Petrol</th>
                      <th className="px-6 py-4 font-medium text-right">🍽 Lunch</th>
                      <th className="px-6 py-4 font-medium text-right">🍳 Breakfast</th>
                      <th className="px-6 py-4 font-medium text-right">☕ Tea</th>
                      <th className="px-6 py-4 font-medium text-right text-text-primary">Total Allw.</th>
                      <th className="px-6 py-4 font-medium text-right text-danger">Advance</th>
                    </tr>
                  </thead>
                  <tbody>
                    {byLabour.map(({ labourId, petrol, lunch, breakfast, tea, advance, total }) => {
                      const labour = labourMap.get(labourId);
                      return (
                        <tr key={labourId} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                          <td className="px-6 py-4">
                            <div className="font-medium text-text-primary text-[14px]">{labour?.name || labourId.slice(0, 8)}</div>
                            {labour?.skill && <div className="text-[11px] text-text-muted mt-0.5 font-mono">{labour.skill}</div>}
                          </td>
                          <td className="px-6 py-4 text-right font-mono text-text-secondary">{petrol > 0 ? formatCurrency(petrol) : <span className="text-text-muted/50">—</span>}</td>
                          <td className="px-6 py-4 text-right font-mono text-text-secondary">{lunch > 0 ? formatCurrency(lunch) : <span className="text-text-muted/50">—</span>}</td>
                          <td className="px-6 py-4 text-right font-mono text-text-secondary">{breakfast > 0 ? formatCurrency(breakfast) : <span className="text-text-muted/50">—</span>}</td>
                          <td className="px-6 py-4 text-right font-mono text-text-secondary">{tea > 0 ? formatCurrency(tea) : <span className="text-text-muted/50">—</span>}</td>
                          <td className="px-6 py-4 text-right font-mono font-medium text-text-primary">{formatCurrency(total)}</td>
                          <td className="px-6 py-4 text-right font-mono font-medium text-danger">{advance > 0 ? formatCurrency(advance) : <span className="text-text-muted/50">—</span>}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                  <tfoot className="border-t-2 border-border-strong bg-bg-elevated/50 text-[12px] font-semibold text-text-secondary">
                    <tr>
                      <td className="px-6 py-4 uppercase tracking-widest text-text-muted">Total</td>
                      <td className="px-6 py-4 text-right font-mono text-text-primary">{formatCurrency(totals.petrol)}</td>
                      <td className="px-6 py-4 text-right font-mono text-text-primary">{formatCurrency(totals.lunch)}</td>
                      <td className="px-6 py-4 text-right font-mono text-text-primary">{formatCurrency(totals.breakfast)}</td>
                      <td className="px-6 py-4 text-right font-mono text-text-primary">{formatCurrency(totals.tea)}</td>
                      <td className="px-6 py-4 text-right font-mono font-bold text-gold text-[14px]">{formatCurrency(totals.allowances)}</td>
                      <td className="px-6 py-4 text-right font-mono font-bold text-danger text-[14px]">{formatCurrency(totals.advance)}</td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>
          )}

          {/* ── DAY-WISE TABLE ────────────────────────────────────── */}
          {byDate.length > 0 && (
            <div className="rounded-xl border border-border bg-bg-card shadow-sm overflow-hidden">
              <div className="border-b border-border px-6 py-5 bg-bg-elevated">
                <h3 className="text-[13px] font-semibold text-text-primary uppercase tracking-widest">Day-wise Breakdown</h3>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-[13px]">
                  <thead className="border-b border-border text-left text-[10px] uppercase tracking-widest text-text-muted">
                    <tr>
                      <th className="px-6 py-4 font-medium">Date</th>
                      <th className="px-6 py-4 font-medium text-right">Labours</th>
                      <th className="px-6 py-4 font-medium text-right">🚗 Petrol</th>
                      <th className="px-6 py-4 font-medium text-right">🍽 Lunch</th>
                      <th className="px-6 py-4 font-medium text-right">🍳 Breakfast</th>
                      <th className="px-6 py-4 font-medium text-right">☕ Tea</th>
                      <th className="px-6 py-4 font-medium text-right text-text-primary">Total</th>
                    </tr>
                  </thead>
                  <tbody>
                    {byDate.map(({ date, petrol, lunch, breakfast, tea, count, total }) => {
                      const parsed = new Date(date + 'T00:00:00');
                      const dateLabel = parsed.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' });
                      return (
                        <tr key={date} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                          <td className="px-6 py-4 font-medium text-text-primary tracking-wide">{dateLabel}</td>
                          <td className="px-6 py-4 text-right font-mono text-text-muted">{count}</td>
                          <td className="px-6 py-4 text-right font-mono text-text-secondary">{petrol > 0 ? formatCurrency(petrol) : <span className="text-text-muted/50">—</span>}</td>
                          <td className="px-6 py-4 text-right font-mono text-text-secondary">{lunch > 0 ? formatCurrency(lunch) : <span className="text-text-muted/50">—</span>}</td>
                          <td className="px-6 py-4 text-right font-mono text-text-secondary">{breakfast > 0 ? formatCurrency(breakfast) : <span className="text-text-muted/50">—</span>}</td>
                          <td className="px-6 py-4 text-right font-mono text-text-secondary">{tea > 0 ? formatCurrency(tea) : <span className="text-text-muted/50">—</span>}</td>
                          <td className="px-6 py-4 text-right font-mono font-medium text-gold">{formatCurrency(total)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {byLabour.length === 0 && byDate.length === 0 && (
            <div className="rounded-xl border border-dashed border-border-strong bg-bg-card/50 py-16 text-center">
              <Receipt className="mx-auto h-12 w-12 text-border-strong mb-4" />
              <p className="text-[14px] text-text-secondary font-medium">No allowances recorded for <span className="text-text-primary">{MONTH_NAMES[month]} {year}</span></p>
              <p className="mt-2 text-[11px] uppercase tracking-widest text-text-muted">Allowances are set per attendance record in the Attendance page.</p>
            </div>
          )}
        </>
      )}
    </div>
  );
}
