import { useState } from 'react';
import { motion } from 'framer-motion';
import SectionHeader from '@/components/ui/SectionHeader';
import SurveyMarker from '@/components/ui/SurveyMarker';
import { howItWorksSteps } from '@/data/howItWorks';
import { QrCode, Shield, Check, Printer, Sparkles, Building } from 'lucide-react';

export default function HowItWorks() {
  const [activeStep, setActiveStep] = useState(1);

  return (
    <section id="how-it-works" className="relative pt-8 pb-16 sm:pt-12 sm:pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      <SectionHeader
        sheetNumber={6}
        totalSheets={12}
        eyebrow="OPERATIONAL WORKFLOW"
        title="From Ground Zero to Automated Payroll in 4 Steps."
        description="Engineered to be simpler than keeping a paper diary. Onboard your sites and staff in less than 15 minutes."
        className="mb-10 sm:mb-12"
      />

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12 items-start">
        {/* ── Left 7 Cols: Timeline Steps ── */}
        <div className="lg:col-span-7 space-y-6">
          <div className="relative border-l-2 border-trackify-cardBorder ml-3.5 sm:ml-6 pl-5 sm:pl-8 space-y-6 sm:space-y-10">
            {howItWorksSteps.map((step) => {
              const Icon = step.icon;
              const isActive = activeStep === step.step;

              return (
                <div
                  key={step.step}
                  onClick={() => setActiveStep(step.step)}
                  className="relative group cursor-pointer"
                >
                  {/* Step Node Marker */}
                  <div
                    className={`absolute -left-[32px] sm:-left-[43px] top-0.5 w-7 h-7 sm:w-9 sm:h-9 rounded-full flex items-center justify-center font-mono text-[11px] sm:text-xs font-bold border-2 transition-all duration-300 ${
                      isActive
                        ? 'bg-trackify-amber text-trackify-bg border-trackify-amber shadow-lg shadow-trackify-amber/30 scale-110'
                        : 'bg-trackify-card text-trackify-textMuted border-trackify-cardBorder group-hover:border-trackify-amber/50 group-hover:text-trackify-textMain'
                    }`}
                  >
                    0{step.step}
                  </div>

                  {/* Step Card Content */}
                  <div
                    className={`p-4 sm:p-5 rounded-xl border transition-all duration-300 ${
                      isActive
                        ? 'bg-white/[0.04] border-trackify-amber/40 shadow-xl'
                        : 'bg-white/[0.015] border-white/[0.06] hover:border-white/[0.12] hover:bg-white/[0.03]'
                    }`}
                  >
                    <div className="flex items-center gap-3 mb-2">
                      <div
                        className={`p-2 rounded-lg ${
                          isActive
                            ? 'bg-trackify-amber/20 text-trackify-amber'
                            : 'bg-trackify-card text-trackify-textMuted'
                        }`}
                      >
                        <Icon className="w-4 h-4" />
                      </div>
                      <h4 className="font-heading font-bold text-base sm:text-lg text-trackify-textMain">
                        {step.title}
                      </h4>
                    </div>

                    <p className="text-sm text-trackify-textMuted leading-relaxed pl-1">
                      {step.description}
                    </p>

                    {isActive && (
                      <div className="mt-3 pt-3 border-t border-white/[0.06] flex items-center gap-2 text-xs font-mono text-trackify-amber">
                        <Check className="w-3.5 h-3.5" />
                        <span>Ready in minutes with zero hardware investment</span>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* ── Right 5 Cols: Printable Physical QR Worker ID Badge Mockup ── */}
        <div className="lg:col-span-5 flex flex-col items-center">
          <div className="text-center mb-4">
            <span className="font-mono text-xs text-trackify-amber flex items-center justify-center gap-1.5 uppercase tracking-wider">
              <Printer className="w-3.5 h-3.5" />
              Printable Physical QR Badge
            </span>
            <p className="text-xs text-trackify-textMuted mt-1">
              Export standard PDF badges for lanyards or hardhat stickers
            </p>
          </div>

          {/* Badge Visual */}
          <div className="w-full max-w-[290px] rounded-2xl bg-gradient-to-b from-[#1E2D4A] to-[#0D1525] p-1 border-2 border-trackify-amber/30 shadow-2xl relative group hover:rotate-1 transition-transform duration-300">
            {/* Lanyard Hole */}
            <div className="w-12 h-2.5 rounded-full bg-trackify-bg mx-auto my-2 border border-trackify-cardBorder flex items-center justify-center">
              <div className="w-8 h-1 rounded-full bg-trackify-cardBorder" />
            </div>

            <div className="rounded-xl bg-[#09101E] p-4 text-center border border-white/[0.06]">
              {/* Org Header */}
              <div className="flex items-center justify-between pb-2 mb-3 border-b border-white/[0.08]">
                <div className="flex items-center gap-1.5">
                  <div className="w-5 h-5 rounded bg-trackify-amber flex items-center justify-center font-bold text-[10px] text-trackify-bg">
                    T
                  </div>
                  <span className="font-heading font-bold text-xs tracking-wider text-trackify-textMain">
                    TRACKIFY ID
                  </span>
                </div>
                <span className="text-[9px] font-mono text-trackify-emerald bg-trackify-emerald/10 px-1.5 py-0.5 rounded border border-trackify-emerald/20">
                  VERIFIED
                </span>
              </div>

              {/* Worker Monogram Avatar */}
              <div className="w-20 h-20 rounded-full bg-gradient-to-tr from-trackify-amber/20 to-trackify-cyan/20 border-2 border-trackify-amber/40 mx-auto flex items-center justify-center mb-3">
                <span className="font-heading font-black text-2xl text-trackify-amber">RK</span>
              </div>

              {/* Worker Name & Role */}
              <h5 className="font-heading font-bold text-base text-trackify-textMain">
                Rajesh Kumar
              </h5>
              <div className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full bg-white/[0.05] border border-white/[0.1] text-xs font-mono text-trackify-amber mt-1 mb-2">
                Senior Mason
              </div>

              <div className="text-[11px] font-mono text-trackify-textMuted flex items-center justify-center gap-1 mb-4">
                <Building className="w-3 h-3 text-trackify-cyan" />
                <span>Greenfield Villa #345</span>
              </div>

              {/* QR Code Container (Pure CSS/SVG grid) */}
              <div className="p-3 bg-white rounded-lg inline-block shadow-inner">
                {/* 7x7 Styled Grid mimicking QR Code */}
                <div className="grid grid-cols-7 gap-1 w-24 h-24">
                  {/* Position detection pattern Top-Left */}
                  <div className="col-span-3 row-span-3 bg-slate-950 p-1 flex items-center justify-center">
                    <div className="w-3 h-3 bg-white flex items-center justify-center">
                      <div className="w-1.5 h-1.5 bg-slate-950" />
                    </div>
                  </div>
                  <div className="bg-slate-950" />
                  {/* Position detection pattern Top-Right */}
                  <div className="col-span-3 row-span-3 bg-slate-950 p-1 flex items-center justify-center">
                    <div className="w-3 h-3 bg-white flex items-center justify-center">
                      <div className="w-1.5 h-1.5 bg-slate-950" />
                    </div>
                  </div>

                  {/* Middle random pattern */}
                  <div className="bg-slate-950 col-start-4 row-start-4" />
                  <div className="bg-slate-950 col-start-2 row-start-4" />
                  <div className="bg-slate-950 col-start-6 row-start-4" />

                  {/* Position detection pattern Bottom-Left */}
                  <div className="col-span-3 row-span-3 col-start-1 row-start-5 bg-slate-950 p-1 flex items-center justify-center">
                    <div className="w-3 h-3 bg-white flex items-center justify-center">
                      <div className="w-1.5 h-1.5 bg-slate-950" />
                    </div>
                  </div>

                  <div className="bg-slate-950 col-start-4 row-start-6" />
                  <div className="bg-slate-950 col-start-5 row-start-5" />
                  <div className="bg-slate-950 col-start-7 row-start-7" />
                  <div className="bg-slate-950 col-start-6 row-start-6" />
                </div>
              </div>

              <div className="mt-3">
                <p className="font-mono text-xs font-semibold text-trackify-textMain">
                  TRK-2024-0847
                </p>
                <p className="text-[10px] text-trackify-textMuted mt-0.5">
                  Scan with supervisor app for 1-second muster stamp
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <SurveyMarker className="mt-16" />
    </section>
  );
}

