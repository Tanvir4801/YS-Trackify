import React from 'react';
import { AlertTriangle, Info, X } from 'lucide-react';

const STYLES = {
  warning: 'bg-yellow-50 border-yellow-200 text-yellow-800',
  error: 'bg-red-50 border-red-200 text-red-800',
  info: 'bg-blue-50 border-blue-200 text-blue-700',
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
