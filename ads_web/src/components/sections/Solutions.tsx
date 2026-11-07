import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import SectionHeader from '@/components/ui/SectionHeader';
import SurveyMarker from '@/components/ui/SurveyMarker';
import { personas } from '@/data/solutions';
import { AlertCircle, CheckCircle2, ArrowRight } from 'lucide-react';

export default function Solutions() {
  const [selectedPersonaId, setSelectedPersonaId] = useState(personas[0].id);

  const selectedPersona = personas.find((p) => p.id === selectedPersonaId) || personas[0];

  return (
    <section id="solutions" className="relative pt-8 pb-16 sm:pt-12 sm:pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      <SectionHeader
        sheetNumber={7}
        totalSheets={12}
        eyebrow="TAILORED SOLUTIONS"
        title="Engineered for Every Stakeholder on the Site."
        description="Whether you run 10 multi-story sites or operate a daily steel reinforcement crew, Trackify replaces ambiguity with real-time digital certainty."
        className="mb-10 sm:mb-12"
      />

      {/* Persona Selector Tabs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-10">
        {personas.map((persona) => {
          const Icon = persona.icon;
          const isSelected = persona.id === selectedPersonaId;

          return (
            <button
              key={persona.id}
              onClick={() => setSelectedPersonaId(persona.id)}
              className={`p-3 sm:p-4 rounded-xl border text-left transition-all duration-300 relative overflow-hidden ${
                isSelected
                  ? 'bg-white/[0.06] border-trackify-amber shadow-lg shadow-trackify-amber/10'
                  : 'bg-white/[0.02] border-white/[0.07] hover:border-white/[0.15] hover:bg-white/[0.04]'
              }`}
            >
              {isSelected && (
                <div className="absolute top-0 left-0 right-0 h-1 bg-trackify-amber" />
              )}
              <div
                className={`w-9 h-9 rounded-lg flex items-center justify-center mb-3 transition-colors ${
                  isSelected
                    ? 'bg-trackify-amber/20 text-trackify-amber'
                    : 'bg-trackify-card text-trackify-textMuted'
                }`}
              >
                <Icon className="w-5 h-5" />
              </div>
              <h4 className="font-heading font-bold text-sm sm:text-base text-trackify-textMain">
                {persona.title}
              </h4>
              <p className="text-[11px] font-mono text-trackify-textMuted mt-1 truncate">
                {persona.scale}
              </p>
            </button>
          );
        })}
      </div>

      {/* Selected Persona Deep Dive Card */}
      <div className="rounded-2xl backdrop-blur-md bg-white/[0.03] border border-white/[0.08] p-4 sm:p-8 lg:p-10 shadow-2xl">
        <AnimatePresence mode="wait">
          <motion.div
            key={selectedPersona.id}
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -12 }}
            transition={{ duration: 0.25 }}
            className="space-y-8"
          >
            {/* Header info */}
            <div className="flex flex-wrap items-center justify-between gap-4 pb-6 border-b border-white/[0.08]">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-xl bg-trackify-amber/20 border border-trackify-amber/30 flex items-center justify-center text-trackify-amber">
                  <selectedPersona.icon className="w-6 h-6" />
                </div>
                <div>
                  <h3 className="font-heading text-xl sm:text-2xl font-bold text-trackify-textMain">
                    {selectedPersona.title}
                  </h3>
                  <span className="font-mono text-xs text-trackify-textMuted">
                    Operational Scope: {selectedPersona.scale}
                  </span>
                </div>
              </div>

              <span className="px-3 py-1 rounded-full text-xs font-mono bg-trackify-amber/10 border border-trackify-amber/30 text-trackify-amber">
                Tailored Workflow
              </span>
            </div>

            {/* Split Grid: Daily Struggle vs Trackify Value */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Daily Struggle Card */}
              <div className="p-6 rounded-xl bg-red-950/20 border border-red-500/20">
                <div className="flex items-center gap-2 text-red-400 font-heading font-bold text-base mb-3">
                  <AlertCircle className="w-5 h-5 flex-shrink-0" />
                  <span>The Ground Pain</span>
                </div>
                <p className="text-sm text-red-200/80 leading-relaxed font-body">
                  {selectedPersona.struggle}
                </p>
                <div className="mt-4 pt-3 border-t border-red-500/15 text-[11px] font-mono text-red-400/70">
                  Result: Disputed payroll & unbillable site time
                </div>
              </div>

              {/* With Trackify Card */}
              <div className="p-6 rounded-xl bg-emerald-950/20 border border-trackify-emerald/30">
                <div className="flex items-center gap-2 text-trackify-emerald font-heading font-bold text-base mb-3">
                  <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
                  <span>The Trackify System</span>
                </div>
                <p className="text-sm text-emerald-100/90 leading-relaxed font-body">
                  {selectedPersona.value}
                </p>
                <div className="mt-4 pt-3 border-t border-trackify-emerald/20 text-[11px] font-mono text-trackify-emerald">
                  Result: 100% audit-proof digital records
                </div>
              </div>
            </div>
          </motion.div>
        </AnimatePresence>
      </div>

      <SurveyMarker className="mt-16" />
    </section>
  );
}

