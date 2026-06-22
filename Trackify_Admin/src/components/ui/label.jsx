import React from 'react';
import clsx from 'clsx';

export function Label({ className, ...props }) {
  return <label className={clsx('text-[10px] uppercase tracking-widest text-text-muted font-medium ml-1', className)} {...props} />;
}
