import React, { useEffect, useMemo, useState } from 'react';
import { useAuthStore, useScopeId } from '../../store/authStore';
import { getAttendanceRange } from '../../lib/services/attendance.service';


const STATUS_COLOR = {
  present: 'bg-success',
  three_quarter: 'bg-teal-500',
  half: 'bg-warning',
  quarter: 'bg-orange-400',
  absent: 'bg-danger',
  // pending = neutral gray (reset/unmarked state, earns ₹0)
  pending: 'bg-bg-elevated',
};

function buildDays(count = 30) {
  const days = [];
  for (let i = count - 1; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    days.push(d.toISOString().split('T')[0]);
  }
  return days;
}

export default function AttendanceHeatmap({ labourId, days: dayCount = 30 }) {
  const days = useMemo(() => buildDays(dayCount), [dayCount]);
  const startDate = days[0];
  const endDate = days[days.length - 1];

  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeId = useScopeId();
  const isSupervisor = role === 'supervisor';

  const [statusMap, setStatusMap] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!labourId || !scopeId) return;
    setLoading(true);

    getAttendanceRange(
      scopeId,
      startDate,
      endDate,
      labourId,
      isSupervisor,
      isSupervisor ? uid : null,
    )
      .then((records) => {
        const map = {};
        (records || []).forEach((r) => {
          if (!r?.date) return;
          const dateKey = r.date;
          map[dateKey] = r.status || 'present';
        });
        setStatusMap(map);
      })
      .catch((e) => {
        console.error('AttendanceHeatmap fetch error:', e);
        setStatusMap({});
      })
      .finally(() => setLoading(false));
  }, [labourId, scopeId, startDate, endDate, isSupervisor, uid]);

  return (
    <div>
      <div className="mb-2 flex flex-wrap items-center gap-3 text-[11px] font-medium tracking-wide text-text-muted uppercase">
        <span className="font-bold text-text-primary">Last {dayCount} days</span>
        {[
          { key: 'present', label: 'Present' },
          { key: 'absent', label: 'Absent' },
          { key: 'half', label: 'Half day' },
          { key: 'pending', label: 'Pending' },
        ].map((s) => (
          <span key={s.key} className="flex items-center gap-1.5">
            <span className={`h-3 w-3 rounded-[2px] ${STATUS_COLOR[s.key]}`} />
            {s.label}
          </span>
        ))}
        <span className="flex items-center gap-1.5">
          <span className="h-3 w-3 rounded-[2px] bg-bg-input" /> No record
        </span>
      </div>
      {loading ? (
        <div className="h-12 animate-pulse rounded-lg bg-bg-elevated" />
      ) : (
        <div className="flex flex-wrap gap-1">
          {days.map((day) => {
            const status = statusMap[day];
            const colorClass = status ? STATUS_COLOR[status] : 'bg-bg-input';
            const label = `${day}: ${status || 'No record'}`;
            return (
              <div
                key={day}
                title={label}
                className={`h-6 w-6 cursor-default rounded-[2px] transition-opacity hover:opacity-80 border border-black/10 ${colorClass}`}
              />
            );
          })}
        </div>
      )}
    </div>
  );
}

