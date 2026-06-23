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
    <div className={`flex flex-col items-center gap-1 rounded-2xl border p-3 ${color}`}>
      <Icon className="h-4 w-4" />
      <span className="text-xs font-medium">{label}</span>
      <span className="text-base font-bold">{formatCurrency(value)}</span>
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
      <div className="rounded-2xl border border-slate-200/70 bg-white p-4 shadow-sm flex flex-wrap items-center justify-between gap-3">
        <div className="text-sm text-slate-600">
          Labour-wise and day-wise breakdown of daily allowances for <span className="font-bold text-slate-900">{MONTH_NAMES[month]} {year}</span>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => shiftMonth(-1)}
            className="flex h-9 w-9 items-center justify-center rounded-xl border border-slate-200 bg-white shadow-sm hover:bg-slate-50"
          >
            <ChevronLeft className="h-4 w-4 text-slate-600" />
          </button>
          <span className="min-w-28 text-center text-sm font-semibold text-slate-800">
            {MONTH_NAMES[month]} {year}
          </span>
          <button
            onClick={() => shiftMonth(1)}
            disabled={isCurrentMonth}
            className="flex h-9 w-9 items-center justify-center rounded-xl border border-slate-200 bg-white shadow-sm hover:bg-slate-50 disabled:opacity-40"
          >
            <ChevronRight className="h-4 w-4 text-slate-600" />
          </button>
        </div>
      </div>

      {loading ? (
        <LoadingSpinner label="Loading allowances…" />
      ) : (
        <>
          {/* ── SUMMARY CHIPS ─────────────────────────────────────── */}
          <div className="rounded-2xl border border-slate-200/70 bg-white/90 p-5 shadow-sm">
            <h3 className="mb-4 text-sm font-semibold uppercase tracking-wide text-slate-500">
              Monthly totals — {MONTH_NAMES[month]} {year}
            </h3>
            {totals.allowances === 0 && totals.advance === 0 ? (
              <p className="text-sm text-slate-400">No allowances recorded for this period.</p>
            ) : (
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
                <AllowanceChip icon={Fuel}     label="Petrol"    value={totals.petrol}    color="border-blue-100   bg-blue-50   text-blue-700"   />
                <AllowanceChip icon={Utensils}  label="Lunch"     value={totals.lunch}     color="border-green-100  bg-green-50  text-green-700"  />
                <AllowanceChip icon={Sandwich}  label="Breakfast" value={totals.breakfast} color="border-amber-100  bg-amber-50  text-amber-700"  />
                <AllowanceChip icon={Coffee}    label="Tea"       value={totals.tea}       color="border-orange-100 bg-orange-50 text-orange-700" />
                <div className="flex flex-col items-center gap-1 rounded-2xl border border-red-100 bg-red-50 p-3 text-red-700">
                  <TrendingDown className="h-4 w-4" />
                  <span className="text-xs font-medium">Advances</span>
                  <span className="text-base font-bold">{formatCurrency(totals.advance)}</span>
                </div>
              </div>
            )}
            {totals.allowances > 0 && (
              <div className="mt-3 rounded-xl bg-slate-50 px-4 py-2 text-sm">
                <span className="text-slate-500">Total allowances: </span>
                <span className="font-bold text-slate-800">{formatCurrency(totals.allowances)}</span>
                {totals.advance > 0 && (
                  <span className="ml-4 text-slate-500">Total advances: <span className="font-bold text-red-600">{formatCurrency(totals.advance)}</span></span>
                )}
              </div>
            )}
          </div>

          {/* ── PER-LABOUR TABLE ──────────────────────────────────── */}
          {byLabour.length > 0 && (
            <div className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm">
              <div className="border-b border-slate-100 px-5 py-4">
                <h3 className="text-base font-semibold text-slate-900">Labour-wise Breakdown</h3>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="border-b border-slate-100 text-left text-xs uppercase tracking-wide text-slate-400">
                    <tr>
                      <th className="px-5 py-3">Labour</th>
                      <th className="px-5 py-3 text-right">🚗 Petrol</th>
                      <th className="px-5 py-3 text-right">🍽 Lunch</th>
                      <th className="px-5 py-3 text-right">🍳 Breakfast</th>
                      <th className="px-5 py-3 text-right">☕ Tea</th>
                      <th className="px-5 py-3 text-right">Total Allw.</th>
                      <th className="px-5 py-3 text-right text-red-500">Advance</th>
                    </tr>
                  </thead>
                  <tbody>
                    {byLabour.map(({ labourId, petrol, lunch, breakfast, tea, advance, total }) => {
                      const labour = labourMap.get(labourId);
                      return (
                        <tr key={labourId} className="border-b border-slate-50 last:border-b-0 hover:bg-slate-50">
                          <td className="px-5 py-3">
                            <div className="font-medium text-slate-900">{labour?.name || labourId.slice(0, 8)}</div>
                            {labour?.skill && <div className="text-xs text-slate-400">{labour.skill}</div>}
                          </td>
                          <td className="px-5 py-3 text-right text-slate-700">{petrol > 0 ? formatCurrency(petrol) : '—'}</td>
                          <td className="px-5 py-3 text-right text-slate-700">{lunch > 0 ? formatCurrency(lunch) : '—'}</td>
                          <td className="px-5 py-3 text-right text-slate-700">{breakfast > 0 ? formatCurrency(breakfast) : '—'}</td>
                          <td className="px-5 py-3 text-right text-slate-700">{tea > 0 ? formatCurrency(tea) : '—'}</td>
                          <td className="px-5 py-3 text-right font-semibold text-slate-900">{formatCurrency(total)}</td>
                          <td className="px-5 py-3 text-right font-semibold text-red-600">{advance > 0 ? formatCurrency(advance) : '—'}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                  <tfoot className="border-t-2 border-slate-200 bg-slate-50 text-xs font-semibold text-slate-700">
                    <tr>
                      <td className="px-5 py-3 uppercase tracking-wide">Total</td>
                      <td className="px-5 py-3 text-right">{formatCurrency(totals.petrol)}</td>
                      <td className="px-5 py-3 text-right">{formatCurrency(totals.lunch)}</td>
                      <td className="px-5 py-3 text-right">{formatCurrency(totals.breakfast)}</td>
                      <td className="px-5 py-3 text-right">{formatCurrency(totals.tea)}</td>
                      <td className="px-5 py-3 text-right text-slate-900">{formatCurrency(totals.allowances)}</td>
                      <td className="px-5 py-3 text-right text-red-600">{formatCurrency(totals.advance)}</td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>
          )}

          {/* ── DAY-WISE TABLE ────────────────────────────────────── */}
          {byDate.length > 0 && (
            <div className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm">
              <div className="border-b border-slate-100 px-5 py-4">
                <h3 className="text-base font-semibold text-slate-900">Day-wise Breakdown</h3>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="border-b border-slate-100 text-left text-xs uppercase tracking-wide text-slate-400">
                    <tr>
                      <th className="px-5 py-3">Date</th>
                      <th className="px-5 py-3 text-right">Labours</th>
                      <th className="px-5 py-3 text-right">🚗 Petrol</th>
                      <th className="px-5 py-3 text-right">🍽 Lunch</th>
                      <th className="px-5 py-3 text-right">🍳 Breakfast</th>
                      <th className="px-5 py-3 text-right">☕ Tea</th>
                      <th className="px-5 py-3 text-right">Total</th>
                    </tr>
                  </thead>
                  <tbody>
                    {byDate.map(({ date, petrol, lunch, breakfast, tea, count, total }) => {
                      const parsed = new Date(date + 'T00:00:00');
                      const dateLabel = parsed.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' });
                      return (
                        <tr key={date} className="border-b border-slate-50 last:border-b-0 hover:bg-slate-50">
                          <td className="px-5 py-3 font-medium text-slate-900">{dateLabel}</td>
                          <td className="px-5 py-3 text-right text-slate-500">{count}</td>
                          <td className="px-5 py-3 text-right text-slate-700">{petrol > 0 ? formatCurrency(petrol) : '—'}</td>
                          <td className="px-5 py-3 text-right text-slate-700">{lunch > 0 ? formatCurrency(lunch) : '—'}</td>
                          <td className="px-5 py-3 text-right text-slate-700">{breakfast > 0 ? formatCurrency(breakfast) : '—'}</td>
                          <td className="px-5 py-3 text-right text-slate-700">{tea > 0 ? formatCurrency(tea) : '—'}</td>
                          <td className="px-5 py-3 text-right font-semibold text-slate-900">{formatCurrency(total)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {byLabour.length === 0 && byDate.length === 0 && (
            <div className="rounded-2xl border border-dashed border-slate-200 bg-white/60 py-16 text-center">
              <Receipt className="mx-auto h-10 w-10 text-slate-300" />
              <p className="mt-3 text-sm text-slate-400">No allowances recorded for {MONTH_NAMES[month]} {year}</p>
              <p className="mt-1 text-xs text-slate-300">Allowances are set per attendance record in the Attendance page.</p>
            </div>
          )}
        </>
      )}
    </div>
  );
}
