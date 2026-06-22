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
          { label: 'Total Supervisors', value: stats.total,        color: 'text-text-primary' },
          { label: 'Active',            value: stats.active,       color: 'text-success' },
          { label: 'Total Labours',     value: labours.length,     color: 'text-text-primary' },
        ].map((s) => (
          <div key={s.label} className="rounded-2xl border border-border bg-bg-card p-5 shadow-sm">
            <p className="text-[10px] font-bold uppercase tracking-widest text-text-muted">{s.label}</p>
            <p className={`mt-2 text-3xl font-bold ${s.color}`}>{s.value}</p>
          </div>
        ))}
      </div>

      {/* Table */}
      <div className="rounded-2xl border border-border bg-bg-card shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-12"><LoadingSpinner label="Loading supervisors…" /></div>
        ) : rows.length === 0 ? (
          <EmptyState icon={UserCheck} title="No supervisors found" description="Create supervisors from the Users page." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-border bg-bg-elevated">
                <tr>
                  {['Supervisor', 'Phone', 'Labours', 'Marked Today', 'Month Payroll', 'Status'].map((h, i) => (
                    <th key={h} className={`px-5 py-3 text-[10px] font-medium uppercase tracking-widest text-text-muted ${i >= 2 && i <= 4 ? 'text-right' : 'text-left'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((s) => (
                  <tr key={s.id} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-info/20 border border-info/30 text-[12px] font-mono font-bold text-info shadow-sm">
                          {(s.name || '?')[0].toUpperCase()}
                        </div>
                        <div>
                          <p className="font-semibold text-text-primary">{s.name}</p>
                          <p className="text-[11px] text-text-muted mt-0.5">{s.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-3.5 text-text-secondary">{s.phone || '—'}</td>
                    <td className="px-5 py-3.5 text-right">
                      <span className="inline-flex items-center rounded-full bg-gold-bg border border-gold/30 px-2.5 py-1 text-[11px] font-bold text-gold tracking-wide">{s.labourCount}</span>
                    </td>
                    <td className="px-5 py-3.5 text-right text-text-primary font-medium font-mono">{s.markedToday}</td>
                    <td className="px-5 py-3.5 text-right font-bold text-text-primary font-mono">{formatCurrency(s.monthPay)}</td>
                    <td className="px-5 py-3.5">
                      {s.isActive === false ? (
                        <span className="inline-flex items-center rounded-full bg-danger-bg px-2.5 py-1 text-[11px] font-bold tracking-wide uppercase text-danger border border-danger/30">Inactive</span>
                      ) : (
                        <span className="inline-flex items-center rounded-full bg-success-bg px-2.5 py-1 text-[11px] font-bold tracking-wide uppercase text-success border border-success/30">Active</span>
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
