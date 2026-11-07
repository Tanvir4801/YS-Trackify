'use client';

import { useState, useRef, useCallback } from 'react';
import { motion, AnimatePresence, useInView } from 'framer-motion';
import { CheckCircle2 } from 'lucide-react';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { featureTabs, compactModules } from '@/data/features';
import { formatINR } from '@/utils/formatCurrency';
import { useReducedMotion } from '@/hooks/useReducedMotion';

/* ================================================================== */
/*  MINI-UI MOCKUPS                                                    */
/* ================================================================== */

/* ---------- Attendance ---------- */

const ATTENDANCE_WORKERS = [
  'Rajesh K.',
  'Amit P.',
  'Suresh M.',
  'Priya S.',
  'Dinesh R.',
];

const DAY_CYCLE = [0, 0.5, 1.0, 1.5] as const;
type DayValue = (typeof DAY_CYCLE)[number];

const DAY_COLORS: Record<DayValue, string> = {
  0: 'bg-trackify-textMuted/20 text-trackify-textMuted',
  0.5: 'bg-amber-500/20 text-amber-400',
  1.0: 'bg-trackify-emerald/20 text-trackify-emerald',
  1.5: 'bg-cyan-500/20 text-cyan-400',
};

function AttendanceMockup() {
  const [days, setDays] = useState<DayValue[]>([1.0, 0.5, 1.0, 0, 1.5]);

  const cycle = useCallback((idx: number) => {
    setDays((prev) => {
      const copy = [...prev];
      const current = copy[idx];
      const nextIdx = (DAY_CYCLE.indexOf(current) + 1) % DAY_CYCLE.length;
      copy[idx] = DAY_CYCLE[nextIdx];
      return copy;
    });
  }, []);

  const total = days.reduce<number>((s, d) => s + d, 0);

  return (
    <div className="space-y-2">
      <p className="font-mono text-[10px] text-trackify-textMuted/50 uppercase tracking-wider mb-2">
        Today&apos;s Muster Roll
      </p>
      {ATTENDANCE_WORKERS.map((name, i) => (
        <div
          key={name}
          className="flex items-center justify-between py-1.5 border-b border-trackify-cardBorder/30 last:border-b-0"
        >
          <span className="text-sm text-trackify-textMuted">{name}</span>
          <button
            onClick={() => cycle(i)}
            aria-label={`${name}: ${days[i]} days, click to change`}
            className={`px-3 py-0.5 rounded-full text-xs font-mono font-medium transition-colors duration-200 ${DAY_COLORS[days[i]]}`}
          >
            {days[i].toFixed(1)}
          </button>
        </div>
      ))}
      <div className="pt-2 flex justify-end">
        <span className="font-mono text-xs text-trackify-amber">
          Total: {total.toFixed(1)} days
        </span>
      </div>
    </div>
  );
}

/* ---------- Payroll ---------- */

function PayrollMockup() {
  const dailyRate = 900;
  const daysWorked = 6.0;
  const gross = dailyRate * daysWorked;
  const advance = 1500;
  const net = gross - advance;

  return (
    <div className="border border-dashed border-trackify-cardBorder rounded-lg p-4 space-y-3 font-mono text-xs">
      <div className="text-center border-b border-dashed border-trackify-cardBorder pb-3">
        <p className="text-trackify-textMain font-heading text-sm font-semibold">
          Rajesh Kumar
        </p>
        <p className="text-trackify-textMuted">Mason — Weekly Payslip</p>
      </div>

      <div className="space-y-1.5">
        <Row label="Daily Rate" value={formatINR(dailyRate)} />
        <Row label="Days Worked" value={daysWorked.toFixed(1)} />
        <div className="border-t border-dashed border-trackify-cardBorder my-1" />
        <Row label="Gross Wages" value={formatINR(gross)} highlight="emerald" />
        <Row label="Advance Deduction" value={`-${formatINR(advance)}`} highlight="red" />
        <div className="border-t border-dashed border-trackify-cardBorder my-1" />
        <Row label="Net Payable" value={formatINR(net)} highlight="amber" bold />
      </div>
    </div>
  );
}

function Row({
  label,
  value,
  highlight,
  bold,
}: {
  label: string;
  value: string;
  highlight?: 'emerald' | 'red' | 'amber';
  bold?: boolean;
}) {
  const colorMap = {
    emerald: 'text-trackify-emerald',
    red: 'text-red-400',
    amber: 'text-trackify-amber',
  };
  return (
    <div className="flex justify-between">
      <span className="text-trackify-textMuted">{label}</span>
      <span
        className={`${highlight ? colorMap[highlight] : 'text-trackify-textMain'} ${bold ? 'font-bold text-sm' : ''}`}
      >
        {value}
      </span>
    </div>
  );
}

/* ---------- Multi-Site ---------- */

const SITES = [
  { name: 'Greenfield Villa #345', workers: 12, dailyCost: 18400, usage: 62, color: 'bg-trackify-emerald', dot: 'bg-trackify-emerald' },
  { name: 'Skyline Tower B2', workers: 28, dailyCost: 42000, usage: 84, color: 'bg-amber-400', dot: 'bg-amber-400' },
  { name: 'Highway Bridge SR-7', workers: 8, dailyCost: 12800, usage: 38, color: 'bg-cyan-400', dot: 'bg-cyan-400' },
];

function MultisiteMockup() {
  return (
    <div className="space-y-3">
      {SITES.map((site) => (
        <div
          key={site.name}
          className="border border-trackify-cardBorder/50 rounded-lg p-3 space-y-2"
        >
          <div className="flex items-center gap-2">
            <span className={`w-2.5 h-2.5 rounded-full ${site.dot}`} />
            <span className="text-sm text-trackify-textMain font-medium truncate">
              {site.name}
            </span>
          </div>
          <div className="flex items-center justify-between text-xs text-trackify-textMuted font-mono">
            <span>{site.workers} workers</span>
            <span>{formatINR(site.dailyCost)}/day</span>
          </div>
          {/* Progress Bar */}
          <div className="h-1.5 w-full bg-trackify-cardBorder/30 rounded-full overflow-hidden">
            <div
              className={`h-full rounded-full ${site.color} transition-all duration-500`}
              style={{ width: `${site.usage}%` }}
            />
          </div>
          <p className="text-[10px] font-mono text-trackify-textMuted/50 text-right">
            {site.usage}% budget consumed
          </p>
        </div>
      ))}
    </div>
  );
}

/* ---------- Drawings ---------- */

const DRAWINGS = [
  { name: 'Foundation Layout', status: 'Delivered' },
  { name: 'Structural Framing', status: 'Delivered' },
  { name: 'Plumbing Rough-In', status: 'Completed' },
  { name: 'Electrical Layout', status: 'Completed' },
  { name: 'Elevation — North', status: 'Pending' },
];

const STATUS_BADGE: Record<string, string> = {
  Delivered: 'bg-trackify-emerald/20 text-trackify-emerald',
  Completed: 'bg-cyan-500/20 text-cyan-400',
  Pending: 'bg-amber-500/20 text-amber-400',
};

function DrawingsMockup() {
  const done = 18;
  const total = 23;
  const pct = Math.round((done / total) * 100);

  return (
    <div className="space-y-3">
      {DRAWINGS.map((d) => (
        <div
          key={d.name}
          className="flex items-center justify-between py-1.5 border-b border-trackify-cardBorder/30 last:border-b-0"
        >
          <span className="text-sm text-trackify-textMuted">{d.name}</span>
          <span
            className={`px-2 py-0.5 rounded-full text-[10px] font-mono font-medium ${STATUS_BADGE[d.status]}`}
          >
            {d.status}
          </span>
        </div>
      ))}

      {/* Progress */}
      <div className="pt-2 flex items-center gap-3">
        <div className="flex-1 h-2 bg-trackify-cardBorder/30 rounded-full overflow-hidden">
          <div
            className="h-full rounded-full bg-trackify-emerald transition-all duration-500"
            style={{ width: `${pct}%` }}
          />
        </div>
        <span className="font-mono text-xs text-trackify-amber whitespace-nowrap">
          {done}/{total} complete
        </span>
      </div>
    </div>
  );
}

/* ================================================================== */
/*  MINI-UI REGISTRY                                                   */
/* ================================================================== */

const MINI_UIS: Record<string, React.FC> = {
  attendance: AttendanceMockup,
  payroll: PayrollMockup,
  multisite: MultisiteMockup,
  drawings: DrawingsMockup,
};

/* ================================================================== */
/*  FEATURES SECTION                                                   */
/* ================================================================== */

export default function Features() {
  const [activeTab, setActiveTab] = useState(featureTabs[0].id);
  const sectionRef = useRef<HTMLDivElement>(null);
  const isInView = useInView(sectionRef, { once: true, margin: '-80px' });
  const prefersReduced = useReducedMotion();

  const active = featureTabs.find((t) => t.id === activeTab)!;
  const MiniUI = MINI_UIS[active.id];

  return (
    <section
      id="features"
      ref={sectionRef}
      className="relative pt-8 pb-16 sm:pt-12 sm:pb-20 bg-trackify-bg overflow-hidden"
      aria-label="Deep feature showcase"
    >
      <div className="absolute inset-0 blueprint-grid opacity-30 pointer-events-none" />

      <div className="relative max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <SectionHeader
          sheetNumber={4}
          eyebrow="DEEP FEATURE SHOWCASE"
          title="Every Tool Your Construction Operation Needs"
        />

        {/* ---- Tab Layout ---- */}
        <motion.div
          initial={prefersReduced ? {} : { opacity: 0, y: 30 }}
          animate={
            isInView
              ? { opacity: 1, y: 0 }
              : prefersReduced
                ? {}
                : { opacity: 0, y: 30 }
          }
          transition={{ duration: 0.6, delay: 0.15, ease: [0.22, 1, 0.36, 1] }}
          className="flex flex-col lg:flex-row gap-6"
        >
          {/* Left: Tab List */}
          {/* Mobile: horizontal scroll */}
          <div className="lg:hidden flex gap-2 overflow-x-auto pb-2 scrollbar-hide -mx-4 px-4">
            {featureTabs.map((tab) => {
              const Icon = tab.icon;
              const isActive = tab.id === activeTab;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  aria-selected={isActive}
                  role="tab"
                  className={`flex items-center gap-2 px-4 py-2.5 rounded-lg whitespace-nowrap text-sm font-medium transition-all duration-200 border ${
                    isActive
                      ? 'border-trackify-amber/50 bg-trackify-amber/10 text-trackify-textMain'
                      : 'border-trackify-cardBorder text-trackify-textMuted hover:text-trackify-textMain'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  {tab.title}
                </button>
              );
            })}
          </div>

          {/* Desktop: vertical tabs */}
          <div
            className="hidden lg:flex lg:flex-col lg:w-1/3 gap-1"
            role="tablist"
            aria-label="Feature tabs"
          >
            {featureTabs.map((tab) => {
              const Icon = tab.icon;
              const isActive = tab.id === activeTab;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  aria-selected={isActive}
                  role="tab"
                  className={`flex items-center gap-3 py-4 px-5 text-left w-full border-l-2 transition-all duration-200 ${
                    isActive
                      ? 'border-l-trackify-amber bg-trackify-amber/5 text-trackify-textMain'
                      : 'border-l-trackify-cardBorder text-trackify-textMuted hover:text-trackify-textMain'
                  }`}
                >
                  <Icon
                    className={`w-5 h-5 flex-shrink-0 ${
                      isActive ? 'text-trackify-amber' : ''
                    }`}
                  />
                  <span className="font-medium text-sm">{tab.title}</span>
                </button>
              );
            })}
          </div>

          {/* Right: Content Panel */}
          <div className="lg:w-2/3">
            <div className="glass-card p-4 sm:p-6 lg:p-8">
              <AnimatePresence mode="wait">
                <motion.div
                  key={active.id}
                  initial={prefersReduced ? {} : { opacity: 0, x: 12 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={prefersReduced ? {} : { opacity: 0, x: -12 }}
                  transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
                >
                  {/* Tagline */}
                  <h3 className="font-heading text-xl sm:text-2xl font-bold text-trackify-textMain mb-4">
                    {active.tagline}
                  </h3>

                  {/* Bullet Points */}
                  <ul className="space-y-2 mb-6">
                    {active.points.map((pt) => (
                      <li key={pt} className="flex items-start gap-2.5">
                        <CheckCircle2 className="w-4 h-4 mt-0.5 flex-shrink-0 text-trackify-emerald" />
                        <span className="text-sm text-trackify-textMuted leading-relaxed">
                          {pt}
                        </span>
                      </li>
                    ))}
                  </ul>

                  {/* Mini-UI Mockup */}
                  <div className="border-t border-dashed border-trackify-cardBorder pt-5">
                    <p className="font-mono text-[10px] text-trackify-textMuted/40 tracking-wider uppercase mb-3">
                      Interactive Preview
                    </p>
                    {MiniUI && <MiniUI />}
                  </div>
                </motion.div>
              </AnimatePresence>
            </div>
          </div>
        </motion.div>

        {/* ---- Compact Modules Grid ---- */}
        <div className="mt-16">
          <p className="font-mono text-xs text-trackify-textMuted/50 tracking-widest uppercase text-center mb-8">
            Additional Modules
          </p>

          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {compactModules.map((mod, i) => {
              const Icon = mod.icon;
              return (
                <motion.div
                  key={mod.title}
                  initial={prefersReduced ? {} : { opacity: 0, y: 20 }}
                  animate={
                    isInView
                      ? { opacity: 1, y: 0 }
                      : prefersReduced
                        ? {}
                        : { opacity: 0, y: 20 }
                  }
                  transition={{
                    duration: 0.4,
                    delay: prefersReduced ? 0 : 0.3 + i * 0.1,
                    ease: [0.22, 1, 0.36, 1],
                  }}
                  className="glass-card p-4 sm:p-5"
                >
                  <Icon className="w-5 h-5 text-trackify-amber mb-3" />
                  <h4 className="font-heading text-sm font-semibold text-trackify-textMain mb-1">
                    {mod.title}
                  </h4>
                  <p className="text-xs text-trackify-textMuted leading-relaxed">
                    {mod.description}
                  </p>
                </motion.div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
