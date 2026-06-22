import React from 'react';
import clsx from 'clsx';

export function Label({ className, ...props }) {
  return <label className={clsx('text-sm font-medium text-slate-700', className)} {...props} />;
}
