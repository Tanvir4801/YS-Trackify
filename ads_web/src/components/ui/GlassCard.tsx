'use client';

import { type ElementType, type ReactNode, type ComponentPropsWithoutRef } from 'react';

interface GlassCardProps<T extends ElementType = 'div'> {
  children: ReactNode;
  className?: string;
  hover?: boolean;
  onClick?: () => void;
  as?: T;
}

export function GlassCard<T extends ElementType = 'div'>({
  children,
  className = '',
  hover = true,
  onClick,
  as,
  ...rest
}: GlassCardProps<T> & Omit<ComponentPropsWithoutRef<T>, keyof GlassCardProps<T>>) {
  const Component = as || 'div';
  const cardClass = hover ? 'glass-card-hover' : 'glass-card';

  return (
    <Component
      className={`${cardClass} p-6 rounded-xl active:scale-[0.98] transition-transform duration-150 ${className}`}
      onClick={onClick}
      {...rest}
    >
      {children}
    </Component>
  );
}
