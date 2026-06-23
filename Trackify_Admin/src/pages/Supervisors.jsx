import React, { useEffect, useMemo, useState } from 'react';
import { UserCheck, Users as UsersIcon } from 'lucide-react';
import toast from 'react-hot-toast';
import { useScopeId } from '../store/authStore';
import { getUsers } from '../lib/services/users.service';
import { getLabours } from '../lib/services/labours.service';
import { getPayments } from '../lib/services/payments.service';
import { getAttendanceByDate } from '../lib/services/attendance.service';
import { formatCurrency, todayKey } from '../lib/utils';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import StatusBadge from '../components/shared/StatusBadge';

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
    setLoading(true);
    const safeGet = (fn) => fn.catch((e) => { console.warn('Supervisor page sub-query failed:', e?.message); return []; });
    Promise.all([
      safeGet(getUsers(scopeId, { role: 'supervisor' })),
      safeGet(getLabours(scopeId, { activeOnly: true })),
      safeGet(getAttendanceByDate(scopeId, today)),
      safeGet(getPayments(scopeId, { startDate: monthStart, endDate: today })),
    ])
      .then(([sups, labs, att, pays]) => {
        setSupervisors(sups);
        setLabours(labs);
        setAttendanceToday(att);
        setMonthPayments(pays);
      })
      .catch((e) => {
        console.error('SUPERVISOR PAGE ERROR:', e);
        toast.error(e?.message || 'Failed to load supervisors');
      })
      .finally(() => setLoading(false));
  }, [scopeId, today]);

  const rows = useMemo(() => {
    return supervisors.map((s) => {
      const labourCount = labours.filter((l) => l.supervisorId === s.id).length;
      const markedToday = attendanceToday.filter((a) => a.supervisorId === s.id).length;
      const monthPay = monthPayments
        .filter((p) => p.supervisorId === s.id)
        .reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
      return { ...s, labourCount, markedToday, monthPay };
    });
  }, [supervisors, labours, attendanceToday, monthPayments]);

  const stats = useMemo(() => {
    const active = supervisors.filter((s) => s.isActive !== false).length;
    return { total: supervisors.length, active };
  }, [supervisors]);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold tracking-tight text-slate-950">Supervisors</h2>
        <p className="mt-1 text-sm text-slate-500">
          {stats.active} active of {stats.total} supervisors.
        </p>
      </div>

      <div className="grid gap-3 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Total Supervisors</p>
          <p className="mt-1 text-2xl font-semibold text-slate-950">{stats.total}</p>
        </div>
        <div className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Active</p>
          <p className="mt-1 text-2xl font-semibold text-green-700">{stats.active}</p>
        </div>
        <div className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Total Labours</p>
          <p className="mt-1 text-2xl font-semibold text-slate-950">{labours.length}</p>
        </div>
      </div>

      <div className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm">
        {loading ? (
          <LoadingSpinner label="Loading supervisors…" />
        ) : rows.length === 0 ? (
          <EmptyState icon={UserCheck} title="No supervisors found" description="Create supervisors from the Users page." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th className="px-4 py-3">Name</th>
                  <th className="px-4 py-3">Phone</th>
                  <th className="px-4 py-3 text-right">Labours</th>
                  <th className="px-4 py-3 text-right">Marked Today</th>
                  <th className="px-4 py-3 text-right">Month Payroll</th>
                  <th className="px-4 py-3">Status</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((s) => (
                  <tr key={s.id} className="border-b border-slate-100 last:border-b-0 hover:bg-slate-50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="flex h-8 w-8 items-center justify-center rounded-full bg-purple-100 text-xs font-semibold text-purple-700">
                          {(s.name || '?')[0].toUpperCase()}
                        </div>
                        <div>
                          <p className="font-medium text-slate-900">{s.name}</p>
                          <p className="text-xs text-slate-500">{s.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-slate-700">{s.phone || '—'}</td>
                    <td className="px-4 py-3 text-right font-semibold text-slate-900">{s.labourCount}</td>
                    <td className="px-4 py-3 text-right text-slate-700">{s.markedToday}</td>
                    <td className="px-4 py-3 text-right font-semibold text-slate-900">{formatCurrency(s.monthPay)}</td>
                    <td className="px-4 py-3">
                      <StatusBadge status={s.isActive === false ? 'inactive' : 'active'} />
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
