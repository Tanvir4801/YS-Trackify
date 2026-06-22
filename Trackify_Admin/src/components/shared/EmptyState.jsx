import React from 'react';
import { Inbox } from 'lucide-react';
import { cn } from '../../lib/utils';

export default function EmptyState({ title = 'No data', description, icon: Icon = Inbox, action, className }) {
  return (
    <div
      className={cn(
        'flex flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-border-strong bg-bg-card/50 px-6 py-12 text-center',
        className,
      )}
    >
      <div className="rounded-full bg-bg-elevated p-3 text-text-muted border border-border-strong">
        <Icon className="h-6 w-6" />
      </div>
      <h3 className="text-[14px] font-semibold text-text-primary tracking-wide">{title}</h3>
      {description ? <p className="max-w-sm text-[13px] text-text-secondary">{description}</p> : null}
      {action ? <div className="mt-3">{action}</div> : null}
    </div>
  );
}
