import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import SectionHeader from '@/components/ui/SectionHeader';
import SurveyMarker from '@/components/ui/SurveyMarker';
import { faqItems } from '@/data/faq';
import { ChevronDown, HelpCircle } from 'lucide-react';

export default function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  const toggleAccordion = (index: number) => {
    setOpenIndex(openIndex === index ? null : index);
  };

  return (
    <section className="relative pt-8 pb-16 sm:pt-12 sm:pb-20 px-4 sm:px-6 lg:px-8 max-w-4xl mx-auto">
      <SectionHeader
        sheetNumber={10}
        totalSheets={12}
        eyebrow="TECHNICAL & OPERATIONAL FAQ"
        title="Frequently Answered Site Questions."
        description="Clear, no-nonsense answers on hardware compatibility, offline resilience, and operational rollout."
        className="mb-10 sm:mb-12"
      />

      <div className="space-y-3.5">
        {faqItems.map((item, index) => {
          const isOpen = openIndex === index;

          return (
            <div
              key={index}
              className={`rounded-xl border transition-all duration-200 overflow-hidden ${
                isOpen
                  ? 'bg-white/[0.04] border-trackify-amber/40 shadow-lg'
                  : 'bg-white/[0.015] border-white/[0.06] hover:border-white/[0.12] hover:bg-white/[0.03]'
              }`}
            >
              <button
                type="button"
                onClick={() => toggleAccordion(index)}
                aria-expanded={isOpen}
                aria-controls={`faq-panel-${index}`}
                id={`faq-btn-${index}`}
                className="w-full flex items-center justify-between p-5 text-left transition-colors focus:outline-none focus:ring-1 focus:ring-trackify-amber/50"
              >
                <div className="flex items-center gap-3 pr-4">
                  <span className="font-mono text-xs text-trackify-amber">
                    Q{String(index + 1).padStart(2, '0')}
                  </span>
                  <span className="font-heading font-semibold text-base sm:text-lg text-trackify-textMain">
                    {item.question}
                  </span>
                </div>

                <div
                  className={`w-7 h-7 rounded-full flex items-center justify-center bg-white/[0.05] text-trackify-textMuted flex-shrink-0 transition-transform duration-200 ${
                    isOpen ? 'rotate-180 text-trackify-amber bg-trackify-amber/10' : ''
                  }`}
                >
                  <ChevronDown className="w-4 h-4" />
                </div>
              </button>

              <AnimatePresence initial={false}>
                {isOpen && (
                  <motion.div
                    id={`faq-panel-${index}`}
                    role="region"
                    aria-labelledby={`faq-btn-${index}`}
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: 'auto', opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    transition={{ duration: 0.25, ease: 'easeInOut' }}
                  >
                    <div className="px-5 pb-5 pt-1 text-sm text-trackify-textMuted leading-relaxed font-body border-t border-white/[0.04]">
                      {item.answer}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          );
        })}
      </div>

      <SurveyMarker className="mt-16" />
    </section>
  );
}

