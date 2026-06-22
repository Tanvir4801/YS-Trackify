import React from 'react';
import { Loader2 } from 'lucide-react';
import { cn } from '../../lib/utils';

export default function LoadingSpinner({ className, label }) {
  return (
    <div className={cn('flex items-center justify-center gap-2 py-10 text-slate-500', className)}>
      <Loader2 className="h-5 w-5 animate-spin" />
      {label ? <span className="text-sm">{label}</span> : null}
    </div>
  );
}
