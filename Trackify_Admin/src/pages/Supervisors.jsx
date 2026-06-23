import React, { useEffect, useMemo, useState } from 'react';
import { UserCheck } from 'lucide-react';
import { useScopeId } from '../store/authStore';
import { getUsers } from '../lib/services/users.service';
import { getLabours } from '../lib/services/labours.service';
import { getPayments } from '../lib/services/payments.service';
import { getAttendanceByDate } from '../lib/services/attendance.service';
import { formatCurrency, todayKey } from '../lib/utils';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';

const now = new Date();
const monthStart = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
const today = todayKey();

export default function Supervisors() {
  const scopeId = useScopeId();
  const [supervisors, setSupervisors] = useState([]);
  const [labours, setLabours] = useState([]);
  const [attendanceToday, setAttendanceToday] = useState([]);
  const [monthPayments, setMonthPayments] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!scopeId) { setSupervisors([]); setLabours([]); setAttendanceToday([]); setMonthPayments([]); setLoading(false); return; }
    setLoading(true);
    const safe = (p) => p.catch((e) => { console.warn('Supervisor sub-query failed:', e?.code, e?.message); return []; });
    Promise.all([
      safe(getUsers(scopeId, { role: 'supervisor' })),
      safe(getLabours(scopeId, { activeOnly: true })),
      safe(getAttendanceByDate(scopeId, today)),
      safe(getPayments(scopeId, { startDate: monthStart, endDate: today })),
    ])
      .then(([sups, labs, att, pays]) => {
        setSupervisors(Array.isArray(sups) ? sups : []);
        setLabours(Array.isArray(labs) ? labs : []);
        setAttendanceToday(Array.isArray(att) ? att : []);
        setMonthPayments(Array.isArray(pays) ? pays : []);
      })
      .catch((e) => console.error('SUPERVISOR PAGE ERROR:', e))
      .finally(() => setLoading(false));
  }, [scopeId]);

  const rows = useMemo(() => supervisors.map((s) => ({
    ...s,
    labourCount:  labours.filter((l) => l.supervisorId === s.id).length,
    markedToday:  attendanceToday.filter((a) => a.supervisorId === s.id).length,
    monthPay:     monthPayments.filter((p) => p.supervisorId === s.id).reduce((sum, p) => sum + (Number(p.amount) || 0), 0),
  })), [supervisors, labours, attendanceToday, monthPayments]);

  const stats = useMemo(() => ({
    total:  supervisors.length,
    active: supervisors.filter((s) => s.isActive !== false).length,
  }), [supervisors]);

  return (
    <div className="space-y-6">
      {/* Stats */}
      <div className="grid gap-4 sm:grid-cols-3">
        {[
          { label: 'Total Supervisors', value: stats.total,        color: 'text-slate-900' },
          { label: 'Active',            value: stats.active,       color: 'text-green-700' },
          { label: 'Total Labours',     value: labours.length,     color: 'text-slate-900' },
        ].map((s) => (
          <div key={s.label} className="rounded-2xl border border-slate-200/70 bg-white p-5 shadow-sm">
            <p className="text-xs font-bold uppercase tracking-wide text-slate-400">{s.label}</p>
            <p className={`mt-2 text-3xl font-bold ${s.color}`}>{s.value}</p>
          </div>
        ))}
      </div>

      {/* Table */}
      <div className="rounded-2xl border border-slate-200/70 bg-white shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-12"><LoadingSpinner label="Loading supervisors…" /></div>
        ) : rows.length === 0 ? (
          <EmptyState icon={UserCheck} title="No supervisors found" description="Create supervisors from the Users page." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-slate-100 bg-slate-50/50">
                <tr>
                  {['Supervisor', 'Phone', 'Labours', 'Marked Today', 'Month Payroll', 'Status'].map((h, i) => (
                    <th key={h} className={`px-5 py-3 text-xs font-bold uppercase tracking-wide text-slate-400 ${i >= 2 && i <= 4 ? 'text-right' : 'text-left'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((s) => (
                  <tr key={s.id} className="border-b border-slate-50 last:border-b-0 hover:bg-slate-50/60 transition-colors">
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-purple-600 text-xs font-bold text-white shadow-sm">
                          {(s.name || '?')[0].toUpperCase()}
                        </div>
                        <div>
                          <p className="font-semibold text-slate-900">{s.name}</p>
                          <p className="text-xs text-slate-400 mt-0.5">{s.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-3.5 text-slate-500">{s.phone || '—'}</td>
                    <td className="px-5 py-3.5 text-right">
                      <span className="inline-flex items-center rounded-full bg-blue-50 px-2.5 py-1 text-xs font-bold text-blue-700">{s.labourCount}</span>
                    </td>
                    <td className="px-5 py-3.5 text-right text-slate-700 font-medium">{s.markedToday}</td>
                    <td className="px-5 py-3.5 text-right font-bold text-slate-900">{formatCurrency(s.monthPay)}</td>
                    <td className="px-5 py-3.5">
                      {s.isActive === false ? (
                        <span className="inline-flex items-center rounded-full bg-red-50 px-2.5 py-1 text-xs font-semibold text-red-700 border border-red-200">Inactive</span>
                      ) : (
                        <span className="inline-flex items-center rounded-full bg-green-50 px-2.5 py-1 text-xs font-semibold text-green-700 border border-green-200">Active</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
