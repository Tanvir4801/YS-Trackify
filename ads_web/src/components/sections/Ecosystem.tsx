import { motion } from 'framer-motion';
import SectionHeader from '@/components/ui/SectionHeader';
import SurveyMarker from '@/components/ui/SurveyMarker';
import { Smartphone, Monitor, Cloud, ShieldCheck, Database, KeyRound, Cpu, HardHat } from 'lucide-react';

export default function Ecosystem() {
  return (
    <section className="relative pt-8 pb-16 sm:pt-12 sm:pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      <SectionHeader
        sheetNumber={8}
        totalSheets={12}
        eyebrow="SYSTEM ARCHITECTURE"
        title="Enterprise-Grade Engineering. Zero Maintenance."
        description="Built with a dual-tier frontend architecture connected to military-grade encrypted cloud infrastructure. Real-time reactivity meets offline durability."
        className="mb-10 sm:mb-12"
      />

      {/* Main Diagram Glass Panel */}
      <div className="relative rounded-2xl p-6 sm:p-10 backdrop-blur-md bg-white/[0.03] border border-white/[0.08] shadow-2xl overflow-hidden">
        {/* Technical Coordinate Annotations */}
        <div className="absolute top-3 left-4 font-mono text-[10px] text-trackify-textMuted/40 select-none">
          CLOUD ARCHITECTURE
        </div>
        <div className="absolute top-3 right-4 font-mono text-[10px] text-trackify-textMuted/40 select-none">
          BANK-GRADE ENCRYPTION
        </div>

        {/* ── Visual Diagram Architecture ── */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 lg:gap-8 items-center relative my-6">
          {/* Node 1: Contractor / Admin Entry */}
          <div className="space-y-4">
            <div className="p-5 rounded-xl bg-trackify-card border border-trackify-cardBorder relative group hover:border-trackify-amber/50 transition-all">
              <div className="w-10 h-10 rounded-lg bg-trackify-amber/20 text-trackify-amber flex items-center justify-center mb-3">
                <HardHat className="w-5 h-5" />
              </div>
              <h4 className="font-heading font-bold text-lg text-trackify-textMain">
                Stakeholders & Roles
              </h4>
              <p className="text-xs text-trackify-textMuted mt-1 leading-relaxed">
                Project Owners, General Contractors, Resident Engineers, and Subcontracting Labor Chiefs.
              </p>
              <div className="mt-3 flex flex-wrap gap-1.5">
                <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-white/[0.05] text-trackify-amber">
                  Multi-Tenant
                </span>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-white/[0.05] text-trackify-cyan">
                  Role-Based RBAC
                </span>
              </div>
            </div>

            {/* Connecting visual indicator */}
            <div className="hidden md:flex justify-end pr-8">
              <div className="h-0.5 w-16 bg-gradient-to-r from-trackify-amber to-trackify-cyan animate-pulse" />
            </div>
          </div>

          {/* Node 2: Client Apps Tier (Dual Platform) */}
          <div className="space-y-4">
            {/* Mobile App */}
            <div className="p-4 rounded-xl bg-trackify-card border border-trackify-cardBorder hover:border-trackify-cyan/50 transition-all">
              <div className="flex items-center gap-3 mb-2">
                <div className="w-8 h-8 rounded-lg bg-trackify-cyan/20 text-trackify-cyan flex items-center justify-center">
                  <Smartphone className="w-4 h-4" />
                </div>
                <div>
                  <h5 className="font-heading font-bold text-sm text-trackify-textMain">
                    Site Mobile App
                  </h5>
                  <span className="text-[10px] font-mono text-trackify-textMuted">
                    Flutter / Android Native Engine
                  </span>
                </div>
              </div>
              <p className="text-[11px] text-trackify-textMuted">
                Optimized for ₹7,000 Android phones. Zero battery drain, 100% offline local buffer.
              </p>
            </div>

            {/* Admin Web */}
            <div className="p-4 rounded-xl bg-trackify-card border border-trackify-cardBorder hover:border-trackify-amber/50 transition-all">
              <div className="flex items-center gap-3 mb-2">
                <div className="w-8 h-8 rounded-lg bg-trackify-amber/20 text-trackify-amber flex items-center justify-center">
                  <Monitor className="w-4 h-4" />
                </div>
                <div>
                  <h5 className="font-heading font-bold text-sm text-trackify-textMain">
                    Contractor Web Console
                  </h5>
                  <span className="text-[10px] font-mono text-trackify-textMuted">
                    React 19 / TypeScript / Tailwind
                  </span>
                </div>
              </div>
              <p className="text-[11px] text-trackify-textMuted">
                Full-screen desktop analytics, payroll settlement batches, and blueprint revisions.
              </p>
            </div>
          </div>

          {/* Node 3: Cloud Infrastructure Tier */}
          <div className="p-6 rounded-xl bg-gradient-to-br from-[#121E36] to-[#0A1120] border-2 border-trackify-cyan/30 shadow-xl relative">
            <div className="w-12 h-12 rounded-xl bg-trackify-cyan/20 text-trackify-cyan flex items-center justify-center mb-4">
              <Cloud className="w-6 h-6" />
            </div>

            <h4 className="font-heading font-bold text-lg text-trackify-textMain mb-1">
              Secure Cloud Core
            </h4>
            <p className="font-mono text-xs text-trackify-cyan mb-4">
              Firebase Firestore Enterprise
            </p>

            <ul className="space-y-2.5 text-xs text-trackify-textMuted">
              <li className="flex items-center gap-2">
                <KeyRound className="w-3.5 h-3.5 text-trackify-amber flex-shrink-0" />
                <span>Granular Security Rules (No data leakage)</span>
              </li>
              <li className="flex items-center gap-2">
                <ShieldCheck className="w-3.5 h-3.5 text-trackify-emerald flex-shrink-0" />
                <span>End-to-End Encrypted Storage</span>
              </li>
              <li className="flex items-center gap-2">
                <Database className="w-3.5 h-3.5 text-trackify-cyan flex-shrink-0" />
                <span>Multi-tenant partitioned records</span>
              </li>
              <li className="flex items-center gap-2">
                <Cpu className="w-3.5 h-3.5 text-yellow-400 flex-shrink-0" />
                <span>Optimistic real-time socket updates</span>
              </li>
            </ul>
          </div>
        </div>

        {/* Dynamic Data Flow Bar */}
        <div className="mt-8 pt-4 border-t border-white/[0.06] flex flex-wrap items-center justify-between text-xs font-mono text-trackify-textMuted gap-4">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-trackify-emerald animate-ping" />
            <span className="text-trackify-textMain">Live WebSocket & Offline FIFO Queue Synchronized</span>
          </div>
          <div className="flex items-center gap-4 text-[11px]">
            <span>UPTIME: 99.98%</span>
            <span>BACKUP: Daily Automated</span>
          </div>
        </div>
      </div>

      <SurveyMarker className="mt-16" />
    </section>
  );
}

