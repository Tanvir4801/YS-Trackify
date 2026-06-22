import React from 'react';
import { Loader2 } from 'lucide-react';
import { cn } from '../../lib/utils';

export default function LoadingSpinner({ className, label }) {
  return (
    <div className={cn('flex items-center justify-center gap-2 py-10 text-gold', className)}>
      <Loader2 className="h-5 w-5 animate-spin drop-shadow-[0_0_8px_rgba(245,166,35,0.4)]" />
      {label ? <span className="text-[13px] font-medium tracking-wide">{label}</span> : null}
    </div>
  );
}
