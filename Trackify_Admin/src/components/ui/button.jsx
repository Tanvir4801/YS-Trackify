import React from 'react';
import clsx from 'clsx';

const variantClasses = {
  default: 'bg-gold text-bg-primary shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-[1.02]',
  outline: 'border border-border-strong bg-bg-elevated text-text-secondary hover:text-text-primary hover:border-gold',
  ghost: 'bg-transparent text-text-secondary hover:text-text-primary hover:bg-bg-elevated',
};

const sizeClasses = {
  default: 'h-9 px-4',
  sm: 'h-8 px-3 text-[12px]',
  icon: 'h-9 w-9 p-0',
};

export function Button({
  className,
  variant = 'default',
  size = 'default',
  type = 'button',
  ...props
}) {
  return (
    <button
      type={type}
      className={clsx(
        'inline-flex items-center justify-center rounded-lg text-[13px] font-semibold transition-all disabled:pointer-events-none disabled:opacity-50',
        variantClasses[variant] || variantClasses.default,
        sizeClasses[size] || sizeClasses.default,
        className,
      )}
      {...props}
    />
  );
}
