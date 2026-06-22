import React, { useEffect, useMemo, useState } from 'react';
import { getDocs, query, collection, where } from 'firebase/firestore';
import { db } from '../../lib/firebase';

const STATUS_COLOR = {
  present: 'bg-green-500',
  absent: 'bg-red-400',
  half: 'bg-amber-400',
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

  const [statusMap, setStatusMap] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!labourId) return;
    setLoading(true);
    getDocs(
      query(
        collection(db, 'attendance'),
        where('labourId', '==', labourId),
        where('date', '>=', startDate),
        where('date', '<=', endDate),
      ),
    )
      .then((snap) => {
        const map = {};
        snap.docs.forEach((d) => {
          const data = d.data();
          if (data.date) map[data.date] = data.status || 'present';
        });
        setStatusMap(map);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [labourId, startDate, endDate]);

  return (
    <div>
      <div className="mb-2 flex flex-wrap items-center gap-3 text-xs text-slate-500">
        <span className="font-semibold">Last {dayCount} days</span>
        {[
          { key: 'present', label: 'Present' },
          { key: 'absent', label: 'Absent' },
          { key: 'half', label: 'Half day' },
        ].map((s) => (
          <span key={s.key} className="flex items-center gap-1">
            <span className={`h-3 w-3 rounded-sm ${STATUS_COLOR[s.key]}`} />
            {s.label}
          </span>
        ))}
        <span className="flex items-center gap-1">
          <span className="h-3 w-3 rounded-sm bg-slate-200" /> No record
        </span>
      </div>
      {loading ? (
        <div className="h-12 animate-pulse rounded-lg bg-slate-100" />
      ) : (
        <div className="flex flex-wrap gap-1">
          {days.map((day) => {
            const status = statusMap[day];
            const colorClass = status ? STATUS_COLOR[status] : 'bg-slate-200';
            const label = `${day}: ${status || 'No record'}`;
            return (
              <div
                key={day}
                title={label}
                className={`h-6 w-6 cursor-default rounded-sm transition-opacity hover:opacity-80 ${colorClass}`}
              />
            );
          })}
        </div>
      )}
    </div>
  );
}
