import React from 'react';
import { cn } from '../../lib/utils';

const STATUS_STYLES = {
  present: 'bg-green-100 text-green-700',
  absent: 'bg-red-100 text-red-700',
  half: 'bg-amber-100 text-amber-700',
  super_admin: 'bg-purple-100 text-purple-700',
  contractor: 'bg-blue-100 text-blue-700',
  supervisor: 'bg-slate-100 text-slate-600',
  active: 'bg-green-100 text-green-700',
  inactive: 'bg-slate-100 text-slate-600',
  salary: 'bg-blue-100 text-blue-700',
  advance: 'bg-amber-100 text-amber-700',
  overtime_bonus: 'bg-violet-100 text-violet-700',
};

const LABELS = {
  half: 'Half day',
  super_admin: 'Super Admin',
  overtime_bonus: 'OT Bonus',
};

export default function StatusBadge({ status, className }) {
  const key = String(status || '').toLowerCase();
  const style = STATUS_STYLES[key] || 'bg-slate-100 text-slate-600';
  const label = LABELS[key] || key.charAt(0).toUpperCase() + key.slice(1);
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold capitalize',
        style,
        className,
      )}
    >
      {label}
    </span>
  );
}
