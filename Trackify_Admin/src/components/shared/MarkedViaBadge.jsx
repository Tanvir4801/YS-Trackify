import React from 'react';

export default function MarkedViaBadge({ via }) {
  const map = {
    qr:           { label: 'QR',         cls: 'bg-success-bg text-success border border-success/30' },
    offline_qr:   { label: 'Offline QR', cls: 'bg-warning-bg  text-warning border border-warning/30'  },
    manual:       { label: 'Manual',     cls: 'bg-info-bg    text-info border border-info/30'    },
    admin_manual: { label: 'Admin',      cls: 'bg-bg-elevated  text-text-secondary border border-border-strong'  },
  };
  const { label, cls } = map[via] || { label: via || '—', cls: 'bg-bg-elevated text-text-muted border border-border-strong' };
  return (
    <span className={`inline-flex items-center rounded px-2 py-0.5 text-[11px] font-medium ${cls}`}>
      {label}
    </span>
  );
}
