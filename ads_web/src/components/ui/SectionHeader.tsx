'use client';

import { useRef } from 'react';
import { motion, useInView } from 'framer-motion';
import { useReducedMotion } from '@/hooks/useReducedMotion';

interface SectionHeaderProps {
  sheetNumber: number;
  totalSheets?: number;
  eyebrow: string;
  title: string;
  description?: string;
  className?: string;
  id?: string;
}

export function SectionHeader({
  sheetNumber,
  totalSheets = 12,
  eyebrow,
  title,
  description,
  className = '',
  id,
}: SectionHeaderProps) {
  const ref = useRef<HTMLDivElement>(null);
  const isInView = useInView(ref, { once: true, margin: '-80px' });
  const prefersReduced = useReducedMotion();

  const padded = (n: number) => String(n).padStart(2, '0');

  return (
    <motion.header
      ref={ref}
      id={id}
      className={`max-w-3xl mx-auto text-center mb-10 sm:mb-12 ${className}`}
      initial={prefersReduced ? {} : { opacity: 0, y: 32 }}
      animate={
        isInView
          ? { opacity: 1, y: 0 }
          : prefersReduced
            ? {}
            : { opacity: 0, y: 32 }
      }
      transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
    >
      {/* Clean Category Badge */}
      {eyebrow && (
        <div className="inline-flex items-center gap-1.5 px-3.5 py-1 rounded-full bg-trackify-amber/10 border border-trackify-amber/25 text-trackify-amber text-xs font-mono font-semibold tracking-wider uppercase mb-3.5">
          <span>{eyebrow}</span>
        </div>
      )}

      {/* Title */}
      <h2 className="font-heading text-3xl sm:text-4xl lg:text-5xl font-bold text-trackify-textMain leading-tight">
        {title}
      </h2>

      {/* Optional description */}
      {description && (
        <p className="mt-4 text-base sm:text-lg text-trackify-textMuted leading-relaxed max-w-2xl mx-auto">
          {description}
        </p>
      )}
    </motion.header>
  );
}

export default SectionHeader;
