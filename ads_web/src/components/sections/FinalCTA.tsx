import SectionHeader from '@/components/ui/SectionHeader';
import SurveyMarker from '@/components/ui/SurveyMarker';
import DemoForm from '@/components/ui/DemoForm';
import { siteConfig } from '@/config/siteConfig';
import { MessageCircle, ShieldCheck, Zap, Headphones } from 'lucide-react';

export default function FinalCTA() {
  return (
    <section id="demo" className="relative pt-8 pb-16 sm:pt-12 sm:pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      <SectionHeader
        sheetNumber={11}
        totalSheets={12}
        eyebrow="ON-SITE PILOT INITIATION"
        title="Ready to Bring Order to Your Construction Sites?"
        description="Join the forward-thinking contractors who have eliminated muster roll headaches, cash advance disputes, and lost site billing."
        className="mb-10 sm:mb-12"
      />

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-start">
        {/* ── Left 5 Cols: Guarantee & Direct Founder Line ── */}
        <div className="lg:col-span-5 space-y-6">
          <div className="rounded-2xl p-4 sm:p-8 bg-gradient-to-br from-[#121E36] to-[#0A1120] border border-white/[0.08] shadow-2xl relative">
            <h3 className="font-heading font-bold text-xl text-trackify-textMain mb-3">
              Direct Implementation Guarantee
            </h3>
            <p className="text-sm text-trackify-textMuted leading-relaxed mb-6 font-body">
              We don't hand you software and disappear. We personally set up your organization hierarchy, digitize your active wage tables, and train your site supervisors on-site or via WhatsApp video call.
            </p>

            <div className="space-y-3.5 mb-8">
              <div className="flex items-center gap-3 text-xs text-trackify-textMain font-mono">
                <div className="w-6 h-6 rounded-md bg-trackify-amber/20 text-trackify-amber flex items-center justify-center flex-shrink-0">
                  <Zap className="w-3.5 h-3.5" />
                </div>
                <span>Same-day project setup & QR card generation</span>
              </div>
              <div className="flex items-center gap-3 text-xs text-trackify-textMain font-mono">
                <div className="w-6 h-6 rounded-md bg-trackify-emerald/20 text-trackify-emerald flex items-center justify-center flex-shrink-0">
                  <ShieldCheck className="w-3.5 h-3.5" />
                </div>
                <span>100% offline muster fallback included</span>
              </div>
              <div className="flex items-center gap-3 text-xs text-trackify-textMain font-mono">
                <div className="w-6 h-6 rounded-md bg-trackify-cyan/20 text-trackify-cyan flex items-center justify-center flex-shrink-0">
                  <Headphones className="w-3.5 h-3.5" />
                </div>
                <span>Direct engineer support via phone & WhatsApp</span>
              </div>
            </div>

            {/* Direct WhatsApp Callout */}
            <div className="pt-6 border-t border-white/[0.08]">
              <p className="text-xs font-mono text-trackify-textMuted mb-3">
                Need an urgent pilot for a foundation starting this week?
              </p>
              <a
                href={siteConfig.links.whatsappDemo}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full flex items-center justify-center gap-2.5 py-3 px-4 rounded-xl bg-[#25D366] hover:bg-[#20BD5A] text-slate-950 font-heading font-bold text-xs sm:text-sm tracking-wide transition-all shadow-lg active:scale-95"
              >
                <MessageCircle className="w-5 h-5 flex-shrink-0" />
                <span>Chat Directly with Founder on WhatsApp</span>
              </a>
            </div>
          </div>
        </div>

        {/* ── Right 7 Cols: Full Pilot Booking Form ── */}
        <div className="lg:col-span-7 rounded-2xl backdrop-blur-md bg-white/[0.03] border border-white/[0.08] p-4 sm:p-10 shadow-2xl relative">
          <div className="flex items-center justify-between pb-4 border-b border-white/[0.08] mb-6">
            <div>
              <h4 className="font-heading font-bold text-lg text-trackify-textMain">
                Schedule a Guided Walkthrough
              </h4>
              <p className="text-xs text-trackify-textMuted mt-0.5">
                Takes 60 seconds · We respect your privacy
              </p>
            </div>
            <span className="font-mono text-[10px] text-trackify-amber bg-trackify-amber/10 px-2.5 py-1 rounded-full border border-trackify-amber/20">
              DISPATCH FORM
            </span>
          </div>

          <DemoForm />
        </div>
      </div>

      <SurveyMarker className="mt-16" />
    </section>
  );
}

