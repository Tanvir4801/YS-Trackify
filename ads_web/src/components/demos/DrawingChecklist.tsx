import { useState, useMemo } from 'react';
import { motion } from 'framer-motion';
import {
  drawings,
  type DrawingStatus,
  drawingStatusColors,
  drawingStatusLabels,
} from '@/data/drawings';
import {
  FileCheck2,
  CheckCircle2,
  Clock,
  Send,
  MessageCircle,
  FileText,
  Calendar,
  Layers,
  Sparkles,
} from 'lucide-react';
import { siteConfig } from '@/config/siteConfig';

export default function DrawingChecklist() {
  // Initial states: first 8 delivered, next 6 completed, rest pending
  const [statuses, setStatuses] = useState<Record<number, DrawingStatus>>(() => {
    const map: Record<number, DrawingStatus> = {};
    drawings.forEach((d) => {
      if (d.id <= 8) map[d.id] = 'delivered';
      else if (d.id <= 14) map[d.id] = 'completed';
      else map[d.id] = 'pending';
    });
    return map;
  });

  const [activeFilter, setActiveFilter] = useState<'all' | DrawingStatus>('all');

  const cycleStatus = (id: number) => {
    setStatuses((prev) => {
      const current = prev[id];
      const next: DrawingStatus =
        current === 'pending'
          ? 'completed'
          : current === 'completed'
          ? 'delivered'
          : 'pending';
      return { ...prev, [id]: next };
    });
  };

  const counts = useMemo(() => {
    let delivered = 0;
    let completed = 0;
    let pending = 0;
    Object.values(statuses).forEach((s) => {
      if (s === 'delivered') delivered++;
      else if (s === 'completed') completed++;
      else pending++;
    });
    return { delivered, completed, pending, total: drawings.length };
  }, [statuses]);

  const percentage = Math.round(((counts.delivered + counts.completed) / counts.total) * 100);

  const filteredDrawings = useMemo(() => {
    if (activeFilter === 'all') return drawings;
    return drawings.filter((d) => statuses[d.id] === activeFilter);
  }, [activeFilter, statuses]);

  // WhatsApp share link
  const shareWhatsAppMessage = () => {
    const msg = encodeURIComponent(
      `*Trackify Architectural Scope & Billing Statement*\n\n` +
      `Site: Greenfield Villa #345\n` +
      `Drawings Progress: ${counts.delivered + counts.completed}/23 Completed (${percentage}%)\n` +
      `Delivered: ${counts.delivered} | In-Progress: ${counts.completed} | Pending: ${counts.pending}\n\n` +
      `Site Visit Inspection: First floor slab reinforcement checked, column starter bars aligned, vibrator deployed systematically.\n` +
      `Advances Settled: ₹1,45,000 | Outstanding Due: ₹35,000`
    );
    window.open(`https://wa.me/${siteConfig.contact.whatsappNumber.replace('+', '')}?text=${msg}`, '_blank');
  };

  // Circular progress calculations
  const radius = 34;
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - (percentage / 100) * circumference;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
      {/* ── Left Column: 23-Drawing Checklist ── */}
      <div className="lg:col-span-7 space-y-4">
        {/* Metric & Ring Summary Header */}
        <div className="p-4 rounded-xl bg-trackify-card border border-trackify-cardBorder flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            {/* SVG Circular Ring */}
            <div className="relative w-20 h-20 flex-shrink-0 flex items-center justify-center">
              <svg className="w-full h-full -rotate-90" viewBox="0 0 80 80">
                <circle
                  cx="40"
                  cy="40"
                  r={radius}
                  className="stroke-trackify-cardBorder"
                  strokeWidth="6"
                  fill="transparent"
                />
                <motion.circle
                  cx="40"
                  cy="40"
                  r={radius}
                  className="stroke-trackify-amber"
                  strokeWidth="6"
                  strokeDasharray={circumference}
                  animate={{ strokeDashoffset }}
                  transition={{ duration: 0.8, ease: 'easeOut' }}
                  strokeLinecap="round"
                  fill="transparent"
                />
              </svg>
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <span className="font-heading text-sm font-bold text-trackify-textMain">
                  {percentage}%
                </span>
                <span className="text-[9px] font-mono text-trackify-textMuted uppercase">Done</span>
              </div>
            </div>

            <div>
              <div className="flex items-center gap-2">
                <Layers className="w-4 h-4 text-trackify-amber" />
                <h4 className="font-heading font-bold text-trackify-textMain text-base">
                  23-Drawing Scope Matrix
                </h4>
              </div>
              <p className="text-xs text-trackify-textMuted mt-0.5">
                Click any drawing row to cycle its status
              </p>
              <div className="flex items-center gap-3 mt-2 text-xs font-mono">
                <span className="text-trackify-emerald flex items-center gap-1">
                  <span className="w-2 h-2 rounded-full bg-trackify-emerald" />
                  {counts.delivered} Delivered
                </span>
                <span className="text-trackify-amber flex items-center gap-1">
                  <span className="w-2 h-2 rounded-full bg-trackify-amber" />
                  {counts.completed} Done
                </span>
                <span className="text-trackify-textMuted flex items-center gap-1">
                  <span className="w-2 h-2 rounded-full bg-trackify-cardBorder" />
                  {counts.pending} Queued
                </span>
              </div>
            </div>
          </div>

          {/* Filter Pills */}
          <div className="flex items-center gap-1.5 bg-trackify-bg/60 p-1 rounded-lg border border-white/[0.05]">
            {(['all', 'delivered', 'completed', 'pending'] as const).map((filter) => (
              <button
                key={filter}
                onClick={() => setActiveFilter(filter)}
                className={`px-2.5 py-1 rounded text-[11px] font-mono capitalize transition-all ${
                  activeFilter === filter
                    ? 'bg-trackify-amber text-trackify-bg font-semibold'
                    : 'text-trackify-textMuted hover:text-trackify-textMain'
                }`}
              >
                {filter}
              </button>
            ))}
          </div>
        </div>

        {/* Scrollable Drawing Rows */}
        <div className="max-h-[380px] overflow-y-auto space-y-1.5 pr-2 custom-scrollbar">
          {filteredDrawings.map((drawing) => {
            const status = statuses[drawing.id];
            return (
              <div
                key={drawing.id}
                onClick={() => cycleStatus(drawing.id)}
                className="group flex items-center justify-between p-3 rounded-lg bg-white/[0.02] border border-white/[0.05] hover:border-trackify-amber/40 hover:bg-white/[0.04] transition-all cursor-pointer select-none"
              >
                <div className="flex items-center gap-3">
                  <span className="w-7 h-7 rounded bg-trackify-card border border-trackify-cardBorder font-mono text-[11px] font-bold flex items-center justify-center text-trackify-textMuted group-hover:text-trackify-amber transition-colors">
                    {String(drawing.id).padStart(2, '0')}
                  </span>
                  <span className="text-sm font-medium text-trackify-textMain group-hover:text-white transition-colors">
                    {drawing.name}
                  </span>
                </div>

                <div className="flex items-center gap-2">
                  <span
                    className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-mono border transition-all ${
                      status === 'delivered'
                        ? 'bg-trackify-emerald/15 border-trackify-emerald/30 text-trackify-emerald'
                        : status === 'completed'
                        ? 'bg-trackify-amber/15 border-trackify-amber/30 text-trackify-amber'
                        : 'bg-white/[0.04] border-white/[0.08] text-trackify-textMuted'
                    }`}
                  >
                    {status === 'delivered' ? (
                      <CheckCircle2 className="w-3 h-3" />
                    ) : status === 'completed' ? (
                      <FileCheck2 className="w-3 h-3" />
                    ) : (
                      <Clock className="w-3 h-3" />
                    )}
                    {drawingStatusLabels[status]}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* ── Right Column: Client Billing Statement PDF-style Preview ── */}
      <div className="lg:col-span-5">
        <div className="rounded-xl bg-white/[0.03] border border-white/[0.1] shadow-2xl p-5 relative overflow-hidden text-trackify-textMain">
          {/* Subtle Watermark Stamp */}
          <div className="absolute right-4 top-24 pointer-events-none opacity-5 rotate-[-20deg] font-mono text-5xl font-black border-4 border-white p-3 rounded">
            TRACKIFY VERIFIED
          </div>

          {/* Reserved 44mm Letterhead Space */}
          <div className="border-2 border-dashed border-trackify-cardBorder rounded-lg p-3 text-center mb-4 bg-trackify-bg/40">
            <span className="font-mono text-[10px] text-trackify-textMuted uppercase tracking-wider block font-semibold">
              44mm Letterhead Space Reserved for Contractor Stationery
            </span>
            <p className="text-xs text-trackify-textMuted/60 mt-0.5">
              [Auto-inserts your firm logo, GSTIN, and registration badge upon export]
            </p>
          </div>

          {/* Statement Header */}
          <div className="flex justify-between items-start pb-3 border-b border-white/[0.08] mb-3">
            <div>
              <h5 className="font-heading font-bold text-sm tracking-wide text-trackify-amber">
                CLIENT BILLING & SITE PROGRESS
              </h5>
              <p className="text-[11px] font-mono text-trackify-textMuted">
                REF: ST-VILLA-2024-NOV · Rev 2
              </p>
            </div>
            <div className="text-right">
              <span className="text-[11px] font-mono text-trackify-emerald bg-trackify-emerald/10 px-2 py-0.5 rounded border border-trackify-emerald/20">
                ACTIVE PHASE
              </span>
            </div>
          </div>

          {/* Client & Project Meta */}
          <div className="grid grid-cols-2 gap-2 text-[11px] mb-3 p-2.5 rounded bg-black/20 font-mono">
            <div>
              <span className="text-trackify-textMuted block text-[10px]">CLIENT</span>
              <span className="font-semibold text-trackify-textMain">Shri Rajeshwar Varma</span>
            </div>
            <div>
              <span className="text-trackify-textMuted block text-[10px]">LOCATION</span>
              <span className="font-semibold text-trackify-textMain">Greenfield Villa #345</span>
            </div>
          </div>

          {/* Site Inspection Logger Entry */}
          <div className="mb-3 p-2.5 rounded bg-white/[0.02] border border-white/[0.05]">
            <div className="flex items-center gap-1.5 text-xs font-semibold text-trackify-cyan mb-1">
              <Calendar className="w-3.5 h-3.5" />
              <span>Certified Site Inspection Log (07 Nov 2026)</span>
            </div>
            <p className="text-xs text-trackify-textMuted italic leading-relaxed">
              "First floor slab reinforcement checked, column starter bars aligned, vibrator deployed systematically. Casting clearance authorized."
            </p>
            <div className="mt-1 flex items-center justify-between text-[10px] font-mono text-trackify-textMuted">
              <span>Supervised by: Er. Bhavin Mehta</span>
              <span className="text-trackify-emerald">Signed digitally ✓</span>
            </div>
          </div>

          {/* Advances Ledger Summary */}
          <div className="mb-4">
            <span className="text-[10px] font-mono uppercase text-trackify-textMuted block mb-1">
              Phase Advance & Escrow Ledger
            </span>
            <div className="space-y-1 text-xs">
              <div className="flex justify-between py-1 border-b border-white/[0.04] font-mono text-[11px]">
                <span className="text-trackify-textMuted">Plinth Level Completion</span>
                <span className="text-trackify-textMain">₹85,000</span>
              </div>
              <div className="flex justify-between py-1 border-b border-white/[0.04] font-mono text-[11px]">
                <span className="text-trackify-textMuted">GF Column & Beam Cast</span>
                <span className="text-trackify-textMain">₹60,000</span>
              </div>
              <div className="flex justify-between py-1 pt-2 font-mono text-xs font-bold text-trackify-textMain">
                <span>Total Advances Realized</span>
                <span className="text-trackify-emerald">₹1,45,000</span>
              </div>
            </div>
          </div>

          {/* WhatsApp Share CTA */}
          <button
            onClick={shareWhatsAppMessage}
            className="w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-lg bg-[#25D366] hover:bg-[#20BD5A] text-slate-950 font-semibold text-xs transition-all shadow-lg active:scale-95"
          >
            <MessageCircle className="w-4 h-4" />
            <span>Share Statement with Client on WhatsApp</span>
          </button>
        </div>
      </div>
    </div>
  );
}

