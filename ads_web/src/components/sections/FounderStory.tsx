import SectionHeader from '@/components/ui/SectionHeader';
import SurveyMarker from '@/components/ui/SurveyMarker';
import { siteConfig } from '@/config/siteConfig';
import { useCountUp } from '@/hooks/useCountUp';
import { Award, Compass, MapPin, Mail, Quote, Terminal } from 'lucide-react';

export default function FounderStory() {
  const { value: accuracy, ref: refAccuracy } = useCountUp(100, 1600);
  const { value: offline, ref: refOffline } = useCountUp(100, 1600);
  const { value: drawings, ref: refDrawings } = useCountUp(23, 1400);

  return (
    <section id="about" className="relative pt-8 pb-16 sm:pt-12 sm:pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      <SectionHeader
        sheetNumber={9}
        totalSheets={12}
        eyebrow="ORIGIN STORY & ARCHITECTURE"
        title="Built From the Ground Up. Engineered for Real Construction."
        description="Not a bloated corporate template. A field-tested, mathematically rigorous operating system crafted specifically for job site realities."
        className="mb-10 sm:mb-12"
      />

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch mb-16">
        {/* ── Left 5 Cols: Engineer's Field Notebook / ID Dossier ── */}
        <div className="lg:col-span-5 rounded-2xl bg-gradient-to-b from-[#15233C] via-[#0E182A] to-[#0A111F] p-6 sm:p-8 border border-white/[0.1] shadow-2xl relative flex flex-col justify-between">
          {/* Subtle blueprint paper grid background inside card */}
          <div className="absolute inset-0 blueprint-grid opacity-30 rounded-2xl pointer-events-none" />

          {/* Dossier Header */}
          <div className="relative z-10 flex items-center justify-between pb-4 border-b border-white/[0.08] mb-6">
            <span className="font-mono text-[10px] text-trackify-amber uppercase tracking-wider flex items-center gap-1.5">
              <Terminal className="w-3.5 h-3.5" />
              FOUNDER DOSSIER
            </span>
            <span className="text-[10px] font-mono text-trackify-emerald bg-trackify-emerald/10 px-2 py-0.5 rounded border border-trackify-emerald/20">
              LEAD ARCHITECT
            </span>
          </div>

          {/* Monogram Avatar & Core Credentials */}
          <div className="relative z-10 text-center mb-6">
            <div className="w-24 h-24 rounded-2xl bg-gradient-to-tr from-trackify-amber/25 via-trackify-amber/10 to-trackify-cyan/20 border-2 border-trackify-amber/50 mx-auto flex items-center justify-center shadow-xl mb-4">
              <span className="font-heading font-black text-3xl text-trackify-amber">TA</span>
            </div>

            <h3 className="font-heading font-bold text-xl text-trackify-textMain">
              {siteConfig.founder.title}
            </h3>
            <p className="font-mono text-xs text-trackify-amber mt-1">
              {siteConfig.founder.education}
            </p>

            <div className="flex flex-wrap items-center justify-center gap-4 text-xs font-mono text-trackify-textMuted mt-4">
              <span className="flex items-center gap-1">
                <MapPin className="w-3.5 h-3.5 text-trackify-cyan" />
                {siteConfig.contact.location}
              </span>
              <a
                href={`mailto:${siteConfig.contact.email}`}
                className="flex items-center gap-1 hover:text-trackify-amber transition-colors"
              >
                <Mail className="w-3.5 h-3.5 text-trackify-amber" />
                {siteConfig.contact.email}
              </a>
            </div>
          </div>

          {/* Vision Quote */}
          <div className="relative z-10 p-4 rounded-xl bg-black/30 border border-white/[0.06] mt-auto">
            <div className="flex items-start gap-2 text-xs italic text-trackify-textMain font-body leading-relaxed">
              <Quote className="w-4 h-4 text-trackify-amber flex-shrink-0 mt-0.5" />
              <span>
                "Software for civil engineering must respect the dust, the basement basements with zero bars of signal, and the daily wage worker who deserves exact accounting for every quarter-day worked."
              </span>
            </div>
          </div>
        </div>

        {/* ── Right 7 Cols: The Story Narrative ── */}
        <div className="lg:col-span-7 rounded-2xl backdrop-blur-md bg-white/[0.03] border border-white/[0.08] p-6 sm:p-10 shadow-2xl flex flex-col justify-center space-y-6">
          <div className="space-y-4 text-trackify-textMuted text-base sm:text-lg leading-relaxed font-body">
            <p>
              <strong className="text-trackify-textMain font-heading">
                Trackify wasn't born in a corporate marketing boardroom.
              </strong>{' '}
              It was designed, architected, and coded by a 4th-year B.Tech Information Technology student who saw first-hand how construction sites still rely on soaked paper notebooks, mental math, and broken WhatsApp chains.
            </p>

            <p>
              Instead of building another generic classroom assignment, Trackify was built with production-grade engineering: offline-first reactive architecture, role-based access control, mathematical payroll precision, and responsive client billing engines.
            </p>

            <p className="text-trackify-textMain font-medium">
              Today, Trackify stands as an enterprise-grade platform ready to streamline construction workforce operations for contractors, builders, and developers.
            </p>
          </div>

          <div className="pt-6 border-t border-white/[0.08] flex flex-wrap items-center gap-6 text-xs font-mono text-trackify-textMuted">
            <div className="flex items-center gap-2">
              <Compass className="w-4 h-4 text-trackify-amber" />
              <span>Engineered in Gujarat, India</span>
            </div>
            <div className="flex items-center gap-2">
              <Award className="w-4 h-4 text-trackify-cyan" />
              <span>Field Tested on Multi-Unit Residential Projects</span>
            </div>
          </div>
        </div>
      </div>

      {/* ── 4 Animated Metrics Counters ── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Metric 1 */}
        <div className="p-6 rounded-xl bg-trackify-card border border-trackify-cardBorder hover:border-trackify-amber/40 transition-colors">
          <p className="font-mono text-3xl sm:text-4xl font-extrabold text-trackify-amber">
            &lt; 3s
          </p>
          <p className="font-heading font-semibold text-sm sm:text-base text-trackify-textMain mt-1">
            Attendance Speed
          </p>
          <p className="text-xs text-trackify-textMuted mt-0.5">
            QR badge scan or 1-tap muster stamp
          </p>
        </div>

        {/* Metric 2 */}
        <div
          ref={refAccuracy as any}
          className="p-6 rounded-xl bg-trackify-card border border-trackify-cardBorder hover:border-trackify-emerald/40 transition-colors"
        >
          <p className="font-mono text-3xl sm:text-4xl font-extrabold text-trackify-emerald">
            {accuracy}%
          </p>
          <p className="font-heading font-semibold text-sm sm:text-base text-trackify-textMain mt-1">
            Payroll Math Accuracy
          </p>
          <p className="text-xs text-trackify-textMuted mt-0.5">
            Automated advance deduction engine
          </p>
        </div>

        {/* Metric 3 */}
        <div
          ref={refOffline as any}
          className="p-6 rounded-xl bg-trackify-card border border-trackify-cardBorder hover:border-trackify-cyan/40 transition-colors"
        >
          <p className="font-mono text-3xl sm:text-4xl font-extrabold text-trackify-cyan">
            {offline}%
          </p>
          <p className="font-heading font-semibold text-sm sm:text-base text-trackify-textMain mt-1">
            Offline Capability
          </p>
          <p className="text-xs text-trackify-textMuted mt-0.5">
            Zero data loss in basements or tunnels
          </p>
        </div>

        {/* Metric 4 */}
        <div
          ref={refDrawings as any}
          className="p-6 rounded-xl bg-trackify-card border border-trackify-cardBorder hover:border-yellow-400/40 transition-colors"
        >
          <p className="font-mono text-3xl sm:text-4xl font-extrabold text-yellow-400">
            {drawings} Plans
          </p>
          <p className="font-heading font-semibold text-sm sm:text-base text-trackify-textMain mt-1">
            Drawings Tracked
          </p>
          <p className="text-xs text-trackify-textMuted mt-0.5">
            Full structural & architectural scope
          </p>
        </div>
      </div>

      <SurveyMarker className="mt-16" />
    </section>
  );
}

