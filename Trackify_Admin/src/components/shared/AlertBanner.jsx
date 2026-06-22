import React from 'react';
import { AlertTriangle, Info, X } from 'lucide-react';

const STYLES = {
  warning: 'bg-amber-500/10 border-amber-500/20 text-amber-500',
  error: 'bg-red-500/10 border-red-500/20 text-red-500',
  info: 'bg-blue-500/10 border-blue-500/20 text-blue-400',
};

const ICONS = {
  warning: AlertTriangle,
  error: AlertTriangle,
  info: Info,
};

export default function AlertBanner({ type = 'info', message, actionLabel, onAction, onDismiss }) {
  const Icon = ICONS[type] || Info;
  return (
    <div
      className={`flex items-center justify-between rounded-xl border px-4 py-3 ${STYLES[type] || STYLES.info}`}
    >
      <div className="flex items-center gap-2">
        <Icon className="h-4 w-4 shrink-0" />
        <span className="text-sm">{message}</span>
        {actionLabel && onAction && (
          <button
            onClick={onAction}
            className="ml-2 text-xs font-semibold underline underline-offset-2 hover:no-underline"
          >
            {actionLabel}
          </button>
        )}
      </div>
      {onDismiss && (
        <button onClick={onDismiss} className="ml-4 shrink-0 opacity-60 hover:opacity-100">
          <X className="h-4 w-4" />
        </button>
      )}
    </div>
  );
}
