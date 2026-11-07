'use client';

import { useState, useRef } from 'react';
import { motion, useInView, AnimatePresence } from 'framer-motion';
import { AlertTriangle, CheckCircle2 } from 'lucide-react';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { problems } from '@/data/problems';
import { useReducedMotion } from '@/hooks/useReducedMotion';

/* ------------------------------------------------------------------ */
/*  Problem Card — flips between "Site Reality" and "Trackify Fix"     */
/* ------------------------------------------------------------------ */

function ProblemCard({
  title,
  reality,
  fix,
  index,
}: {
  title: string;
  reality: string;
  fix: string;
  index: number;
}) {
  const [showFix, setShowFix] = useState(false);
  const cardRef = useRef<HTMLDivElement>(null);
  const isInView = useInView(cardRef, { once: true, margin: '-60px' });
  const prefersReduced = useReducedMotion();

  const toggle = () => setShowFix((prev) => !prev);

  return (
    <motion.div
      ref={cardRef}
      initial={prefersReduced ? {} : { opacity: 0, y: 40 }}
      animate={
        isInView
          ? { opacity: 1, y: 0 }
          : prefersReduced
            ? {}
            : { opacity: 0, y: 40 }
      }
      transition={{
        duration: 0.5,
        delay: prefersReduced ? 0 : index * 0.15,
        ease: [0.22, 1, 0.36, 1],
      }}
      role="button"
      tabIndex={0}
      aria-label={`${title}: ${showFix ? 'showing Trackify fix' : 'showing site reality'}. Click to toggle.`}
      onClick={toggle}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          toggle();
        }
      }}
      className={`glass-card p-6 cursor-pointer transition-all duration-300 border-l-4 ${
        showFix
          ? 'border-l-trackify-emerald/50'
          : 'border-l-red-500/50'
      }`}
    >
      {/* Card Header */}
      <h3 className="font-heading text-lg font-semibold text-trackify-textMain mb-4">
        {title}
      </h3>

      {/* Toggle Indicator */}
      <div className="flex items-center gap-3 mb-4 text-xs font-mono tracking-wide select-none">
        <span
          className={`flex items-center gap-1.5 transition-colors duration-300 ${
            !showFix ? 'text-red-400' : 'text-trackify-textMuted/50'
          }`}
        >
          <span
            className={`inline-block w-2 h-2 rounded-full transition-colors duration-300 ${
              !showFix ? 'bg-red-400' : 'bg-trackify-textMuted/30'
            }`}
          />
          Site Reality
        </span>

        <span className="text-trackify-textMuted/30">↔</span>

        <span
          className={`flex items-center gap-1.5 transition-colors duration-300 ${
            showFix ? 'text-trackify-emerald' : 'text-trackify-textMuted/50'
          }`}
        >
          <span
            className={`inline-block w-2 h-2 rounded-full transition-colors duration-300 ${
              showFix ? 'bg-trackify-emerald' : 'bg-trackify-textMuted/30'
            }`}
          />
          Trackify Fix
        </span>
      </div>

      {/* Animated Content */}
      <div className="relative min-h-[90px]">
        <AnimatePresence mode="wait">
          {showFix ? (
            <motion.div
              key="fix"
              initial={prefersReduced ? {} : { opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={prefersReduced ? {} : { opacity: 0, y: -8 }}
              transition={{ duration: 0.25 }}
              className="flex gap-3"
            >
              <CheckCircle2 className="w-5 h-5 mt-0.5 flex-shrink-0 text-trackify-emerald" />
              <p className="text-sm text-trackify-textMuted leading-relaxed">
                {fix}
              </p>
            </motion.div>
          ) : (
            <motion.div
              key="reality"
              initial={prefersReduced ? {} : { opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={prefersReduced ? {} : { opacity: 0, y: -8 }}
              transition={{ duration: 0.25 }}
              className="flex gap-3"
            >
              <AlertTriangle className="w-5 h-5 mt-0.5 flex-shrink-0 text-red-400" />
              <p className="text-sm text-trackify-textMuted leading-relaxed">
                {reality}
              </p>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Tap hint */}
      <p className="mt-4 font-mono text-[10px] text-trackify-textMuted/40 tracking-wider uppercase">
        {showFix ? 'Tap to see reality' : 'Tap to see fix →'}
      </p>
    </motion.div>
  );
}

/* ------------------------------------------------------------------ */
/*  Problem Section                                                    */
/* ------------------------------------------------------------------ */

export default function Problem() {
  return (
    <section
      className="relative pt-10 pb-16 sm:pt-14 sm:pb-20 bg-trackify-darkSurface overflow-hidden"
      aria-label="Before vs After — Construction workforce pain points"
    >
      {/* Blueprint grid background */}
      <div className="absolute inset-0 blueprint-grid opacity-40 pointer-events-none" />

      <div className="relative max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <SectionHeader
          sheetNumber={3}
          eyebrow="THE HARSH REALITY"
          title="Construction Workforce Management Shouldn't Be Complicated"
        />

        {/* Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {problems.map((p, i) => (
            <ProblemCard
              key={p.id}
              title={p.title}
              reality={p.reality.description}
              fix={p.fix.description}
              index={i}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
