import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import SectionHeader from '@/components/ui/SectionHeader';
import SurveyMarker from '@/components/ui/SurveyMarker';
import PayrollCalculator from '@/components/demos/PayrollCalculator';
import OfflineSimulator from '@/components/demos/OfflineSimulator';
import DrawingChecklist from '@/components/demos/DrawingChecklist';
import { Calculator, WifiOff, FileCheck2, ArrowRight } from 'lucide-react';

const demos = [
  {
    id: 'payroll',
    title: 'Live Payroll Calculator',
    shortTitle: 'Payroll Engine',
    subtitle: 'Zero math mistakes. Auto-deduct advances and calculate wage settlements with fractional shift increments.',
    icon: Calculator,
    sheetTag: 'SHEET 05A / 12',
  },
  {
    id: 'offline',
    title: 'Offline-First Simulator',
    shortTitle: 'Offline Buffer',
    subtitle: 'Test how attendance and advance logs queue locally in remote excavations or basements with auto-sync.',
    icon: WifiOff,
    sheetTag: 'SHEET 05B / 12',
  },
  {
    id: 'drawings',
    title: '23-Drawing Matrix & Client Billing',
    shortTitle: 'Drawings & Billing',
    subtitle: 'Track architectural blueprints from foundation to 3D elevation, log site inspections, and export branded client statements.',
    icon: FileCheck2,
    sheetTag: 'SHEET 05C / 12',
  },
];

export default function InteractiveDemos() {
  const [activeTab, setActiveTab] = useState<'payroll' | 'offline' | 'drawings'>('drawings');

  // If navigated to #plans, ensure Drawings & Billing is shown
  useEffect(() => {
    const handleHash = () => {
      if (window.location.hash === '#plans') {
        setActiveTab('drawings');
      }
    };
    window.addEventListener('hashchange', handleHash);
    return () => window.removeEventListener('hashchange', handleHash);
  }, []);

  return (
    <section id="plans" className="relative pt-8 pb-16 sm:pt-12 sm:pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      <SectionHeader
        sheetNumber={5}
        totalSheets={12}
        eyebrow="LIVE INTERACTIVE MODULES"
        title="Experience the Trackify Engine Firsthand."
        description="Interact directly with our core mathematical algorithms and offline synchronization pipeline. No signup or credentials required."
        className="mb-12"
      />

      {/* Tab Navigation Pill Bar */}
      <div className="flex flex-wrap items-center justify-center gap-2 sm:gap-3 mb-10">
        {demos.map((d) => {
          const Icon = d.icon;
          const isActive = activeTab === d.id;
          return (
            <button
              key={d.id}
              onClick={() => setActiveTab(d.id as any)}
              className={`flex items-center gap-2.5 px-4 sm:px-5 py-3 rounded-xl font-heading text-sm font-semibold transition-all duration-200 border ${
                isActive
                  ? 'bg-trackify-amber text-trackify-bg border-trackify-amber shadow-lg shadow-trackify-amber/20 scale-[1.02]'
                  : 'bg-white/[0.03] text-trackify-textMuted border-white/[0.08] hover:border-trackify-cardBorder hover:text-trackify-textMain hover:bg-white/[0.05]'
              }`}
            >
              <Icon className={`w-4 h-4 ${isActive ? 'text-trackify-bg' : 'text-trackify-amber'}`} />
              <span>{d.title}</span>
            </button>
          );
        })}
      </div>

      {/* Main Interactive Demo Container */}
      <div className="relative rounded-2xl p-6 sm:p-8 lg:p-10 backdrop-blur-md bg-white/[0.03] border border-white/[0.08] shadow-2xl">
        {/* Demo Subtitle / Info */}
        <div className="mb-8 pb-6 border-b border-white/[0.06]">
          <h3 className="font-heading text-xl sm:text-2xl font-bold text-trackify-textMain">
            {demos.find((d) => d.id === activeTab)?.title}
          </h3>
          <p className="text-sm text-trackify-textMuted mt-1.5 max-w-2xl leading-relaxed">
            {demos.find((d) => d.id === activeTab)?.subtitle}
          </p>
        </div>

        {/* Component Display */}
        <div>
          {activeTab === 'payroll' && (
            <motion.div
              key="payroll"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3 }}
            >
              <PayrollCalculator />
            </motion.div>
          )}

          {activeTab === 'offline' && (
            <motion.div
              key="offline"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3 }}
            >
              <OfflineSimulator />
            </motion.div>
          )}

          {activeTab === 'drawings' && (
            <motion.div
              key="drawings"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3 }}
            >
              <DrawingChecklist />
            </motion.div>
          )}
        </div>
      </div>

      <SurveyMarker className="mt-16" />
    </section>
  );
}

