import React from 'react';
import clsx from 'clsx';

export function Input({ className, ...props }) {
  return (
    <input
      className={clsx(
        'flex h-9 w-full rounded-lg border border-border-strong bg-bg-input px-3 py-2 text-[13px] text-text-primary shadow-sm outline-none transition-colors placeholder:text-text-muted focus:border-gold focus:ring-1 focus:ring-gold disabled:cursor-not-allowed disabled:opacity-50',
        className,
      )}
      {...props}
    />
  );
}
