import { useRef } from 'react';
import { motion, useInView } from 'framer-motion';
import { Zap, Rocket, ArrowDown, Check } from 'lucide-react';
import { siteConfig } from '@/config/siteConfig';
import { trustBarItems } from '@/data/demo';

interface HeroProps {
  onDemoClick: () => void;
}

/* ─── Animation Variants ─── */
const containerVariants = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.12, delayChildren: 0.2 },
  },
};

const fadeUp = {
  hidden: { opacity: 0, y: 28 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.6, ease: [0.22, 1, 0.36, 1] },
  },
};

const fadeIn = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { duration: 0.8, ease: 'easeOut' },
  },
};

const floatingChipVariants = {
  hidden: { opacity: 0, scale: 0.8 },
  visible: (delay: number) => ({
    opacity: 1,
    scale: 1,
    transition: { delay, duration: 0.5, ease: 'easeOut' },
  }),
};

/* ─── Laptop Mini Dashboard ─── */
function LaptopMockup() {
  // Simple SVG attendance chart: 7-point line
  const chartPoints = [80, 65, 90, 72, 95, 85, 92];
  const chartW = 260;
  const chartH = 50;
  const maxVal = 100;
  const points = chartPoints
    .map((v, i) => {
      const x = (i / (chartPoints.length - 1)) * chartW;
      const y = chartH - (v / maxVal) * chartH;
      return `${x},${y}`;
    })
    .join(' ');

  const sites = [
    { name: 'Surat HQ', count: 24, color: 'bg-trackify-emerald' },
    { name: 'Dumas Rd', count: 18, color: 'bg-trackify-cyan' },
    { name: 'Adajan', count: 12, color: 'bg-trackify-amber' },
  ];

  const payroll = [
    { name: 'Ravi K.', days: '6.0', amount: '₹5,400' },
    { name: 'Suresh M.', days: '5.5', amount: '₹2,750' },
    { name: 'Anil T.', days: '6.0', amount: '₹4,800' },
  ];

  return (
    <div className="relative animate-float">
      {/* Screen */}
      <div className="w-[320px] h-[210px] bg-trackify-card border border-trackify-cardBorder rounded-lg overflow-hidden shadow-2xl shadow-black/40">
        {/* Title bar */}
        <div className="flex items-center justify-between px-3 py-1.5 bg-trackify-darkSurface border-b border-trackify-cardBorder">
          <span className="font-mono text-[9px] text-trackify-textMuted">
            Trackify Admin
          </span>
          <div className="flex gap-1">
            <span className="w-2 h-2 rounded-full bg-red-500/70" />
            <span className="w-2 h-2 rounded-full bg-yellow-500/70" />
            <span className="w-2 h-2 rounded-full bg-green-500/70" />
          </div>
        </div>

        <div className="px-3 py-2 space-y-2">
          {/* Chart */}
          <div>
            <p className="font-mono text-[7px] text-trackify-textMuted/60 mb-1">
              ATTENDANCE TREND
            </p>
            <svg
              viewBox={`0 0 ${chartW} ${chartH}`}
              className="w-full h-[36px]"
              aria-hidden="true"
            >
              <defs>
                <linearGradient id="chartGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#F59E0B" stopOpacity="0.3" />
                  <stop offset="100%" stopColor="#F59E0B" stopOpacity="0" />
                </linearGradient>
              </defs>
              <polygon
                points={`0,${chartH} ${points} ${chartW},${chartH}`}
                fill="url(#chartGrad)"
              />
              <polyline
                points={points}
                fill="none"
                stroke="#F59E0B"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </div>

          {/* Site cards */}
          <div className="flex gap-1.5">
            {sites.map((s) => (
              <div
                key={s.name}
                className="flex-1 bg-trackify-darkSurface rounded px-1.5 py-1 border border-trackify-cardBorder/50"
              >
                <div className="flex items-center gap-1 mb-0.5">
                  <span
                    className={`w-1.5 h-1.5 rounded-full ${s.color}`}
                    aria-hidden="true"
                  />
                  <span className="font-mono text-[6px] text-trackify-textMuted truncate">
                    {s.name}
                  </span>
                </div>
                <span className="font-heading text-[11px] font-bold text-trackify-textMain">
                  {s.count}
                </span>
              </div>
            ))}
          </div>

          {/* Payroll micro-table */}
          <div className="bg-trackify-darkSurface rounded border border-trackify-cardBorder/50 overflow-hidden">
            <div className="grid grid-cols-3 px-1.5 py-0.5 border-b border-trackify-cardBorder/30">
              <span className="font-mono text-[5px] text-trackify-textMuted/50">
                WORKER
              </span>
              <span className="font-mono text-[5px] text-trackify-textMuted/50 text-center">
                DAYS
              </span>
              <span className="font-mono text-[5px] text-trackify-textMuted/50 text-right">
                PAYABLE
              </span>
            </div>
            {payroll.map((row) => (
              <div
                key={row.name}
                className="grid grid-cols-3 px-1.5 py-0.5 border-b border-trackify-cardBorder/20 last:border-0"
              >
                <span className="font-mono text-[7px] text-trackify-textMain/80 truncate">
                  {row.name}
                </span>
                <span className="font-mono text-[7px] text-trackify-textMuted text-center">
                  {row.days}
                </span>
                <span className="font-mono text-[7px] text-trackify-emerald text-right">
                  {row.amount}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Laptop base / stand */}
      <div className="mx-auto mt-0 flex justify-center" aria-hidden="true">
        <div
          className="h-[6px] bg-trackify-cardBorder/60 rounded-b-lg"
          style={{
            width: '200px',
            clipPath: 'polygon(10% 0%, 90% 0%, 100% 100%, 0% 100%)',
          }}
        />
      </div>
    </div>
  );
}

/* ─── Phone Mockup with QR Scanner ─── */
function PhoneMockup() {
  const workers = [
    { name: 'Ravi K.', status: 'Present' },
    { name: 'Anil T.', status: 'Present' },
    { name: 'Suresh M.', status: 'Present' },
  ];

  return (
    <div
      className="w-[130px] h-[230px] bg-trackify-card border border-trackify-cardBorder rounded-2xl overflow-hidden shadow-2xl shadow-black/50 animate-float-delayed"
      style={{ transform: 'rotate(12deg)' }}
    >
      {/* Notch */}
      <div className="flex justify-center pt-1.5" aria-hidden="true">
        <div className="w-12 h-1.5 bg-trackify-darkSurface rounded-full" />
      </div>

      <div className="px-2.5 pt-2 space-y-2">
        {/* Header */}
        <p className="font-mono text-[7px] text-trackify-amber text-center font-semibold tracking-wider">
          QR SCANNER
        </p>

        {/* Viewfinder */}
        <div className="relative mx-auto w-[72px] h-[72px] border-2 border-dashed border-trackify-amber/30 rounded-md">
          {/* Corner marks */}
          <span className="absolute -top-0.5 -left-0.5 w-3 h-3 border-t-2 border-l-2 border-trackify-amber rounded-tl-sm" />
          <span className="absolute -top-0.5 -right-0.5 w-3 h-3 border-t-2 border-r-2 border-trackify-amber rounded-tr-sm" />
          <span className="absolute -bottom-0.5 -left-0.5 w-3 h-3 border-b-2 border-l-2 border-trackify-amber rounded-bl-sm" />
          <span className="absolute -bottom-0.5 -right-0.5 w-3 h-3 border-b-2 border-r-2 border-trackify-amber rounded-br-sm" />
          {/* Scan line */}
          <div className="absolute left-1 right-1 h-[1.5px] bg-trackify-amber/80 animate-scan-line rounded-full shadow-[0_0_8px_rgba(245,158,11,0.6)]" />
        </div>

        {/* Workers list */}
        <div className="space-y-1">
          {workers.map((w) => (
            <div
              key={w.name}
              className="flex items-center justify-between px-1.5 py-0.5 bg-trackify-darkSurface rounded border border-trackify-cardBorder/40"
            >
              <span className="font-mono text-[7px] text-trackify-textMain/80">
                {w.name}
              </span>
              <span className="flex items-center gap-0.5">
                <Check
                  className="w-2 h-2 text-trackify-emerald"
                  aria-hidden="true"
                />
                <span className="font-mono text-[6px] text-trackify-emerald">
                  {w.status}
                </span>
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ─── Floating Chip ─── */
function FloatingChip({
  label,
  className,
  delay,
}: {
  label: string;
  className: string;
  delay: number;
}) {
  return (
    <motion.div
      custom={delay}
      variants={floatingChipVariants}
      className={`absolute glass-card px-3 py-1.5 text-[10px] font-mono text-trackify-textMain/80 whitespace-nowrap select-none ${className}`}
    >
      {label}
    </motion.div>
  );
}

/* ─── Device Mockup Composition ─── */
function DeviceMockup() {
  return (
    <motion.div variants={fadeIn} className="relative w-full max-w-[460px] mx-auto">
      {/* Laptop */}
      <div className="relative z-10">
        <LaptopMockup />
      </div>

      {/* Phone – overlapping bottom-right */}
      <div className="absolute -bottom-10 -right-4 z-20">
        <PhoneMockup />
      </div>

      {/* Floating chips */}
      <FloatingChip
        label="Mason · 1.0 day ✓"
        className="top-2 -right-8 z-30"
        delay={0.8}
      />
      <FloatingChip
        label="Advance ₹500 logged"
        className="-left-6 top-1/3 z-30"
        delay={1.0}
      />
      <FloatingChip
        label="Synced ✓"
        className="bottom-20 -left-4 z-30 animate-pulse-glow"
        delay={1.2}
      />
    </motion.div>
  );
}

/* ═══════════════════════════════════════════
   HERO SECTION
   ═══════════════════════════════════════════ */
export default function Hero({ onDemoClick }: HeroProps) {
  const sectionRef = useRef<HTMLElement>(null);
  const isInView = useInView(sectionRef, { once: true, amount: 0.15 });

  const handleScrollToFeatures = (e: React.MouseEvent) => {
    e.preventDefault();
    const target = document.getElementById('features');
    if (target) {
      const targetY = target.getBoundingClientRect().top + window.scrollY - 75;
      window.scrollTo({ top: Math.max(0, targetY), behavior: 'smooth' });
    }
  };

  return (
    <section
      ref={sectionRef}
      id="hero"
      className="relative min-h-screen blueprint-grid flex items-center overflow-hidden pt-20 pb-12 lg:pt-24 lg:pb-20"
      aria-label="Hero – Take Control of Your Construction Workforce"
    >
      {/* Subtle radial glow */}
      <div
        className="pointer-events-none absolute inset-0"
        aria-hidden="true"
        style={{
          background:
            'radial-gradient(ellipse 60% 50% at 30% 40%, rgba(245,158,11,0.06) 0%, transparent 70%)',
        }}
      />

      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate={isInView ? 'visible' : 'hidden'}
          className="flex flex-col lg:flex-row items-center lg:items-start gap-12 lg:gap-16"
        >
          {/* ── Left: Copy ── */}
          <div className="w-full lg:w-[60%] text-center lg:text-left">
            {/* Badge */}
            <motion.div variants={fadeUp} className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-trackify-amber/10 text-trackify-amber border border-trackify-amber/20 text-sm font-mono mb-6">
              <Zap className="w-3.5 h-3.5 flex-shrink-0" aria-hidden="true" />
              <span>{siteConfig.heroBadge}</span>
            </motion.div>

            {/* Headline */}
            <motion.h1
              variants={fadeUp}
              className="font-heading text-4xl sm:text-5xl lg:text-6xl font-bold leading-tight text-trackify-textMain"
            >
              Take{' '}
              <span className="relative inline-block">
                Control
                <motion.span
                  className="absolute bottom-1 left-0 h-1 bg-trackify-amber rounded-full"
                  initial={{ width: 0 }}
                  animate={isInView ? { width: '100%' } : { width: 0 }}
                  transition={{ delay: 0.8, duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
                  aria-hidden="true"
                />
              </span>{' '}
              of Your Construction Workforce.
            </motion.h1>

            {/* Description */}
            <motion.p
              variants={fadeUp}
              className="text-lg text-trackify-textMuted max-w-xl mt-6 mx-auto lg:mx-0 font-body"
            >
              {siteConfig.heroDescription}
            </motion.p>

            {/* CTA Buttons */}
            <motion.div
              variants={fadeUp}
              className="flex flex-col sm:flex-row gap-4 mt-8 justify-center lg:justify-start"
            >
              <button
                onClick={onDemoClick}
                className="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-lg bg-trackify-amber text-trackify-bg font-heading font-semibold text-sm hover:bg-trackify-amberDark transition-colors focus:outline-none focus:ring-2 focus:ring-trackify-amber/50 focus:ring-offset-2 focus:ring-offset-trackify-bg"
              >
                <Rocket className="w-4 h-4" aria-hidden="true" />
                Book a Free Live Demo
              </button>
              <a
                href="#features"
                onClick={handleScrollToFeatures}
                className="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-lg border border-trackify-cardBorder text-trackify-textMuted font-heading font-semibold text-sm hover:text-trackify-textMain hover:border-trackify-amber/40 transition-all focus:outline-none focus:ring-2 focus:ring-trackify-amber/50 focus:ring-offset-2 focus:ring-offset-trackify-bg"
              >
                <ArrowDown className="w-4 h-4" aria-hidden="true" />
                Explore Live Platform
              </a>
            </motion.div>

            {/* Trust Bar */}
            <motion.div
              variants={fadeUp}
              className="mt-12 grid grid-cols-2 lg:grid-cols-4 gap-4"
            >
              {trustBarItems.map((item) => (
                <div
                  key={item.label}
                  className="glass-card p-4 text-center lg:text-left"
                >
                  <p className="font-heading text-2xl font-bold text-trackify-amber">
                    {item.value}
                  </p>
                  <p className="font-mono text-xs text-trackify-textMain mt-1">
                    {item.label}
                  </p>
                  <p className="text-[11px] text-trackify-textMuted mt-0.5 font-body">
                    {item.description}
                  </p>
                </div>
              ))}
            </motion.div>
          </div>

          {/* ── Right: Device Mockups ── */}
          <div className="hidden lg:flex w-full lg:w-[40%] items-center justify-center relative mt-8 lg:mt-12">
            <DeviceMockup />
          </div>
        </motion.div>
      </div>
    </section>
  );
}
