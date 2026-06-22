import React from 'react';
import clsx from 'clsx';

export function Card({ className, ...props }) {
  return <div className={clsx('rounded-lg border border-slate-200 bg-white shadow-sm', className)} {...props} />;
}

export function CardContent({ className, ...props }) {
  return <div className={clsx('p-4', className)} {...props} />;
}
