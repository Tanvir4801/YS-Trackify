import React from 'react';
import clsx from 'clsx';

export function Card({ className, ...props }) {
  return <div className={clsx('rounded-lg border border-border bg-bg-card shadow-sm', className)} {...props} />;
}

export function CardContent({ className, ...props }) {
  return <div className={clsx('p-4', className)} {...props} />;
}
