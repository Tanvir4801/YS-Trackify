'use client';

import { type ReactNode } from 'react';

type BadgeVariant = 'default' | 'success' | 'warning' | 'info';

interface BadgeProps {
  children: ReactNode;
  variant?: BadgeVariant;
  className?: string;
}

const variantStyles: Record<BadgeVariant, string> = {
  default:
    'bg-trackify-amber/10 text-trackify-amber border border-trackify-amber/20',
  success:
    'bg-trackify-emerald/10 text-trackify-emerald border border-trackify-emerald/20',
  warning:
    'bg-red-500/10 text-red-400 border border-red-500/20',
  info:
    'bg-trackify-cyan/10 text-trackify-cyan border border-trackify-cyan/20',
};

export function Badge({
  children,
  variant = 'default',
  className = '',
}: BadgeProps) {
  return (
    <span
      className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-mono ${variantStyles[variant]} ${className}`}
    >
      {children}
    </span>
  );
}
