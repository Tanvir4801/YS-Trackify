import React from 'react';
import { cn } from '../../lib/utils';

const STATUS_STYLES = {
  present: 'bg-success-bg text-success border border-success/30',
  absent: 'bg-danger-bg text-danger border border-danger/30',
  half: 'bg-warning-bg text-warning border border-warning/30',
  // pending = neutral/gray — "not yet correctly marked", earns ₹0
  pending: 'bg-bg-elevated text-text-secondary border border-border-strong',
  super_admin: 'bg-info-bg text-info border border-info/30',
  contractor: 'bg-gold-bg text-gold border border-gold/30',
  supervisor: 'bg-success-bg text-success border border-success/30',
  active: 'bg-success-bg text-success border border-success/30',
  inactive: 'bg-danger-bg text-danger border border-danger/30',
  salary: 'bg-success-bg text-success border border-success/30',
  advance: 'bg-warning-bg text-warning border border-warning/30',
  overtime_bonus: 'bg-info-bg text-info border border-info/30',
};

const LABELS = {
  half: 'Half day',
  pending: 'Pending',
  super_admin: 'Super Admin',
  overtime_bonus: 'OT Bonus',
};

export default function StatusBadge({ status, className }) {
  const key = String(status || '').toLowerCase();
  const style = STATUS_STYLES[key] || 'bg-bg-elevated text-text-secondary border border-border-strong';
  const label = LABELS[key] || key.charAt(0).toUpperCase() + key.slice(1);
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wider',
        style,
        className,
      )}
    >
      {label}
    </span>
  );
}
