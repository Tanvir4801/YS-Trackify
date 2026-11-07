import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Calculator,
  Boxes,
  Layers,
  Sparkles,
  Plus,
  Minus,
  Check,
  Smartphone,
  Share2,
  Building,
  BadgePercent,
  CheckCircle2,
  RotateCcw,
} from 'lucide-react';
import { formatINR, formatIndianNumber } from '@/utils/formatCurrency';
import { siteConfig } from '@/config/siteConfig';

interface MaterialItem {
  id: string;
  name: string;
  spec: string;
  unit: string;
  ratePerUnit: number;
  qtyMultiplier: number; // multiplier per sq.ft
  color: string;
  badgeColor: string;
  enabled: boolean;
  extraAdded: number; // extra units added via interactive button
}

const defaultMaterials: MaterialItem[] = [
  {
    id: 'cement',
    name: 'OPC / PPC Cement',
    spec: '50 kg bags (Grade 53)',
    unit: 'bags',
    ratePerUnit: 385,
    qtyMultiplier: 0.4, // ~400 bags per 1000 sq.ft
    color: '#F59E0B',
    badgeColor: 'bg-amber-500/10 text-trackify-amber border-amber-500/20',
    enabled: true,
    extraAdded: 0,
  },
  {
    id: 'steel',
    name: 'TMT Steel Rebar',
    spec: 'Fe-500D (8mm to 20mm)',
    unit: 'kg',
    ratePerUnit: 68,
    qtyMultiplier: 3.6, // ~3600 kg per 1000 sq.ft (3.6 tons)
    color: '#0EA5E9',
    badgeColor: 'bg-cyan-500/10 text-trackify-cyan border-cyan-500/20',
    enabled: true,
    extraAdded: 0,
  },
  {
    id: 'sand',
    name: 'River / M-Sand',
    spec: 'Fine aggregate for mortar/concrete',
    unit: 'CFT',
    ratePerUnit: 54,
    qtyMultiplier: 1.8, // ~1800 CFT per 1000 sq.ft
    color: '#EAB308',
    badgeColor: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/20',
    enabled: true,
    extraAdded: 0,
  },
  {
    id: 'bricks',
    name: 'Red Clay Bricks',
    spec: 'Standard 9"×4.25"×2.75" class 1',
    unit: 'nos',
    ratePerUnit: 8.5,
    qtyMultiplier: 18, // ~18,000 bricks per 1000 sq.ft built-up
    color: '#F43F5E',
    badgeColor: 'bg-rose-500/10 text-rose-400 border-rose-500/20',
    enabled: true,
    extraAdded: 0,
  },
  {
    id: 'tiles',
    name: 'Vitrified Floor Tiles',
    spec: '2ft × 2ft GVT/PGVT (+10% wastage)',
    unit: 'sq.ft',
    ratePerUnit: 52,
    qtyMultiplier: 1.1, // area + 10% cutting margin
    color: '#10B981',
    badgeColor: 'bg-emerald-500/10 text-trackify-emerald border-emerald-500/20',
    enabled: true,
    extraAdded: 0,
  },
  {
    id: 'aggregate',
    name: 'Coarse Aggregate',
    spec: '10mm & 20mm blue metal granite',
    unit: 'CFT',
    ratePerUnit: 42,
    qtyMultiplier: 1.35, // ~1350 CFT per 1000 sq.ft
    color: '#94A3B8',
    badgeColor: 'bg-slate-500/10 text-slate-300 border-slate-500/20',
    enabled: true,
    extraAdded: 0,
  },
];

const presets = [
  { label: 'Room (250 sq.ft)', area: 250 },
  { label: '1 BHK (650 sq.ft)', area: 650 },
  { label: '2 BHK (1,000 sq.ft)', area: 1000 },
  { label: 'Villa (2,400 sq.ft)', area: 2400 },
];

// Cute custom SVG material icons
function MaterialIcon({ id, className = 'w-4 h-4' }: { id: string; className?: string }) {
  switch (id) {
    case 'cement':
      return (
        <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d="M6 4h12l2 4v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8l2-4z" />
          <path d="M4 8h16" />
          <path d="M9 13h6" />
        </svg>
      );
    case 'steel':
      return (
        <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d="M4 6h16M4 12h16M4 18h16" />
          <path d="M7 3l4 18M13 3l4 18" strokeDasharray="2 2" />
        </svg>
      );
    case 'sand':
      return (
        <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d="M3 20h18L17 9l-5-5-5 5-4 11z" />
          <circle cx="12" cy="14" r="1" fill="currentColor" />
          <circle cx="9" cy="16" r="1" fill="currentColor" />
          <circle cx="15" cy="16" r="1" fill="currentColor" />
        </svg>
      );
    case 'bricks':
      return (
        <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <rect x="3" y="4" width="18" height="16" rx="2" />
          <path d="M3 9h18M3 15h18M12 4v5M8 9v6M16 9v6M12 15v5" />
        </svg>
      );
    case 'tiles':
      return (
        <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <rect x="3" y="3" width="18" height="18" rx="2" />
          <path d="M3 12h18M12 3v18" />
          <path d="M5 5l2 2M14 5l2 2M5 14l2 2M14 14l2 2" />
        </svg>
      );
    case 'aggregate':
    default:
      return (
        <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <polygon points="5,15 9,9 15,10 18,17 12,20" />
          <polygon points="12,4 17,6 15,10 10,8" />
        </svg>
      );
  }
}

export default function ConstructionCalculator() {
  const [mode, setMode] = useState<'materials' | 'concrete'>('materials');
  const [builtUpArea, setBuiltUpArea] = useState<number>(1000);
  const [materials, setMaterials] = useState<MaterialItem[]>(defaultMaterials);
  const [feedbackToast, setFeedbackToast] = useState<string | null>(null);

  // Concrete Mix Parameters
  const [lengthFt, setLengthFt] = useState<number>(30);
  const [widthFt, setWidthFt] = useState<number>(20);
  const [depthInches, setDepthInches] = useState<number>(5);
  const [mixGrade, setMixGrade] = useState<'M15' | 'M20' | 'M25'>('M20');

  // Concrete calculation (IS 456)
  const depthFt = depthInches / 12;
  const wetM3 = lengthFt * widthFt * depthFt * 0.0283168;
  const dryVol = wetM3 * 1.54;

  let ratioParts = [1, 1.5, 3]; // M20
  if (mixGrade === 'M15') ratioParts = [1, 2, 4];
  if (mixGrade === 'M25') ratioParts = [1, 1, 2];

  const sumRatio = ratioParts[0] + ratioParts[1] + ratioParts[2];
  const concCementM3 = dryVol * (ratioParts[0] / sumRatio);
  const concCementBags = Math.round(concCementM3 / 0.03472);
  const concSandCft = Math.round(dryVol * (ratioParts[1] / sumRatio) * 35.315);
  const concAggCft = Math.round(dryVol * (ratioParts[2] / sumRatio) * 35.315);
  const concWaterLiters = concCementBags * 25;
  const concTotalCost =
    concCementBags * 385 + concSandCft * 54 + concAggCft * 42;

  // Toggle item enabled
  const toggleMaterial = (id: string) => {
    setMaterials((prev) =>
      prev.map((item) =>
        item.id === id ? { ...item, enabled: !item.enabled } : item
      )
    );
  };

  // Add extra batch to a material with cute toast
  const addExtraMaterial = (id: string, step: number) => {
    const item = materials.find((m) => m.id === id);
    if (!item) return;

    setMaterials((prev) =>
      prev.map((m) =>
        m.id === id ? { ...m, extraAdded: Math.max(0, m.extraAdded + step), enabled: true } : m
      )
    );

    if (step > 0) {
      setFeedbackToast(`+${step} ${item.unit} ${item.name} Added`);
      setTimeout(() => setFeedbackToast(null), 1800);
    }
  };

  // Quick button to add/enable all materials with cute cascade
  const handleAddAllMaterials = () => {
    setMaterials((prev) =>
      prev.map((m) => ({
        ...m,
        enabled: true,
        extraAdded: m.extraAdded + (m.id === 'bricks' ? 200 : m.id === 'steel' ? 50 : 5),
      }))
    );
    setFeedbackToast('⚡ Batch Materials Added across All Categories');
    setTimeout(() => setFeedbackToast(null), 2000);
  };

  const handleResetMaterials = () => {
    setMaterials(defaultMaterials);
    setFeedbackToast('↺ Reset Materials to Standard Base Estimates');
    setTimeout(() => setFeedbackToast(null), 1800);
  };

  // Calculate totals for materials mode
  const activeMaterials = materials.filter((m) => m.enabled);
  const totalMaterialCost = activeMaterials.reduce((sum, item) => {
    const baseQty = Math.round(builtUpArea * item.qtyMultiplier);
    const totalQty = baseQty + item.extraAdded;
    return sum + totalQty * item.ratePerUnit;
  }, 0);

  // WhatsApp share message
  const shareEstimate = () => {
    let msg = `*Trackify Site Material Estimate*\n`;
    if (mode === 'materials') {
      msg += `Built-up Area: ${builtUpArea} sq.ft\n`;
      msg += `Estimated Total: ${formatINR(totalMaterialCost)}\n\n`;
      activeMaterials.forEach((m) => {
        const qty = Math.round(builtUpArea * m.qtyMultiplier) + m.extraAdded;
        msg += `• ${m.name}: ${formatIndianNumber(qty)} ${m.unit} (~${formatINR(qty * m.ratePerUnit)})\n`;
      });
    } else {
      msg += `Slab Volume: ${lengthFt}' × ${widthFt}' × ${depthInches}" (${mixGrade} Mix)\n`;
      msg += `Estimated Total: ${formatINR(concTotalCost)}\n\n`;
      msg += `• Cement: ${concCementBags} bags\n`;
      msg += `• Sand: ${concSandCft} CFT\n`;
      msg += `• Aggregate: ${concAggCft} CFT\n`;
      msg += `• Water: ${concWaterLiters} L\n`;
    }
    msg += `\nGenerated via Trackify Civil Toolkit`;

    const url = `https://wa.me/${siteConfig.contact.whatsappNumber.replace(/[^0-9]/g, '')}?text=${encodeURIComponent(msg)}`;
    window.open(url, '_blank', 'noopener,noreferrer');
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 sm:gap-8 items-center">
      {/* ── Left Column: Architecture Context & Controls ── */}
      <div className="lg:col-span-5 space-y-5 sm:space-y-6">
        <div>
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-trackify-amber/10 border border-trackify-amber/30 text-trackify-amber text-xs font-mono mb-3">
            <Calculator className="w-3.5 h-3.5" />
            <span>IS 456:2000 & CPWD Standard Specifications</span>
          </div>
          <h3 className="font-heading text-xl sm:text-2xl font-bold text-trackify-textMain">
            Daily Construction Calculators at Site Level.
          </h3>
          <p className="text-sm text-trackify-textMuted mt-2 leading-relaxed">
            Eliminate messy notebook math, missing material trucks, and procurement disputes.
            Supervisors and contractors compute exact cement bags, steel tonnage, sand, bricks,
            and tiles on-site with standard Indian civil engineering formulas.
          </p>
        </div>

        {/* Mode Selector Tabs */}
        <div className="grid grid-cols-2 gap-2 p-1.5 rounded-xl bg-white/[0.03] border border-white/[0.08]">
          <button
            onClick={() => setMode('materials')}
            className={`flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-xs font-heading font-semibold transition-all ${
              mode === 'materials'
                ? 'bg-trackify-amber text-trackify-bg shadow-md shadow-trackify-amber/20'
                : 'text-trackify-textMuted hover:text-trackify-textMain hover:bg-white/[0.04]'
            }`}
          >
            <Boxes className="w-3.5 h-3.5" />
            <span>Materials Estimator</span>
          </button>
          <button
            onClick={() => setMode('concrete')}
            className={`flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-xs font-heading font-semibold transition-all ${
              mode === 'concrete'
                ? 'bg-trackify-amber text-trackify-bg shadow-md shadow-trackify-amber/20'
                : 'text-trackify-textMuted hover:text-trackify-textMain hover:bg-white/[0.04]'
            }`}
          >
            <Layers className="w-3.5 h-3.5" />
            <span>Concrete Mix Batcher</span>
          </button>
        </div>

        {/* Quick Area Presets (if materials mode) */}
        {mode === 'materials' ? (
          <div className="space-y-3">
            <div className="flex items-center justify-between text-xs">
              <span className="font-mono text-trackify-textMuted uppercase tracking-wider">
                Built-Up Floor Footprint
              </span>
              <span className="font-mono font-bold text-trackify-amber text-sm">
                {formatIndianNumber(builtUpArea)} sq.ft
              </span>
            </div>

            {/* Slider */}
            <input
              type="range"
              min={150}
              max={4000}
              step={50}
              value={builtUpArea}
              onChange={(e) => setBuiltUpArea(Number(e.target.value))}
              className="w-full h-2 bg-trackify-cardBorder rounded-lg appearance-none cursor-pointer accent-trackify-amber"
            />

            {/* Presets */}
            <div className="flex flex-wrap gap-2 pt-1">
              {presets.map((preset) => (
                <button
                  key={preset.label}
                  onClick={() => setBuiltUpArea(preset.area)}
                  className={`text-xs px-2.5 py-1 rounded-md font-mono transition-colors border ${
                    builtUpArea === preset.area
                      ? 'bg-trackify-amber/20 border-trackify-amber text-trackify-amber'
                      : 'bg-white/[0.02] border-white/[0.08] text-trackify-textMuted hover:text-trackify-textMain'
                  }`}
                >
                  {preset.label}
                </button>
              ))}
            </div>

            {/* Action buttons: Add All / Reset */}
            <div className="flex items-center gap-2 pt-1">
              <button
                onClick={handleAddAllMaterials}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-trackify-amber/15 hover:bg-trackify-amber/25 text-trackify-amber border border-trackify-amber/30 text-xs font-mono font-semibold transition-colors"
              >
                <Plus className="w-3 h-3" />
                <span>+ Add Batch to All</span>
              </button>
              <button
                onClick={handleResetMaterials}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/[0.03] hover:bg-white/[0.06] text-trackify-textMuted hover:text-trackify-textMain border border-white/[0.08] text-xs font-mono transition-colors"
              >
                <RotateCcw className="w-3 h-3" />
                <span>Reset</span>
              </button>
            </div>
          </div>
        ) : (
          <div className="space-y-3">
            <p className="text-xs font-mono text-trackify-textMuted uppercase tracking-wider">
              Slab / Footing Dimensions & Mix
            </p>
            <div className="grid grid-cols-3 gap-2">
              <div>
                <label className="text-[11px] font-mono text-trackify-textMuted">Length (ft)</label>
                <input
                  type="number"
                  value={lengthFt}
                  onChange={(e) => setLengthFt(Math.max(1, Number(e.target.value)))}
                  className="w-full mt-1 px-2.5 py-1.5 rounded-lg bg-white/[0.03] border border-white/[0.1] text-xs font-mono text-trackify-textMain focus:outline-none focus:border-trackify-amber"
                />
              </div>
              <div>
                <label className="text-[11px] font-mono text-trackify-textMuted">Width (ft)</label>
                <input
                  type="number"
                  value={widthFt}
                  onChange={(e) => setWidthFt(Math.max(1, Number(e.target.value)))}
                  className="w-full mt-1 px-2.5 py-1.5 rounded-lg bg-white/[0.03] border border-white/[0.1] text-xs font-mono text-trackify-textMain focus:outline-none focus:border-trackify-amber"
                />
              </div>
              <div>
                <label className="text-[11px] font-mono text-trackify-textMuted">Depth (in)</label>
                <input
                  type="number"
                  value={depthInches}
                  onChange={(e) => setDepthInches(Math.max(1, Number(e.target.value)))}
                  className="w-full mt-1 px-2.5 py-1.5 rounded-lg bg-white/[0.03] border border-white/[0.1] text-xs font-mono text-trackify-textMain focus:outline-none focus:border-trackify-amber"
                />
              </div>
            </div>

            {/* Mix Grade Radio Pills */}
            <div className="flex items-center gap-2 pt-1">
              {(['M15', 'M20', 'M25'] as const).map((grade) => (
                <button
                  key={grade}
                  onClick={() => setMixGrade(grade)}
                  className={`flex-1 py-1.5 px-2 rounded-lg text-xs font-mono font-semibold transition-all border ${
                    mixGrade === grade
                      ? 'bg-trackify-amber/20 border-trackify-amber text-trackify-amber'
                      : 'bg-white/[0.02] border-white/[0.08] text-trackify-textMuted hover:text-trackify-textMain'
                  }`}
                >
                  {grade} ({grade === 'M15' ? '1:2:4' : grade === 'M20' ? '1:1.5:3' : '1:1:2'})
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Telemetry Stat Cards */}
        <div className="grid grid-cols-2 gap-3">
          <div className="p-3.5 rounded-lg bg-white/[0.02] border border-white/[0.06]">
            <div className="flex items-center justify-between">
              <span className="text-xs font-mono text-trackify-textMuted">Wastage Buffer</span>
              <BadgePercent className="w-3.5 h-3.5 text-trackify-emerald" />
            </div>
            <p className="text-xl font-heading font-bold text-trackify-emerald mt-1">
              +10% <span className="text-xs font-normal text-trackify-textMuted">safety margin</span>
            </p>
            <p className="text-[11px] text-trackify-textMuted mt-0.5">IS 456 civil thumb rule</p>
          </div>

          <div className="p-3.5 rounded-lg bg-white/[0.02] border border-white/[0.06]">
            <div className="flex items-center justify-between">
              <span className="text-xs font-mono text-trackify-textMuted">Est. Material Cost</span>
              <Sparkles className="w-3.5 h-3.5 text-trackify-amber" />
            </div>
            <p className="text-xl font-heading font-bold text-trackify-amber mt-1">
              {formatINR(mode === 'materials' ? totalMaterialCost : concTotalCost)}
            </p>
            <p className="text-[11px] text-trackify-textMuted mt-0.5">Real-time market rates</p>
          </div>
        </div>

        {/* Share Button */}
        <button
          onClick={shareEstimate}
          className="w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl bg-trackify-emerald/10 hover:bg-trackify-emerald/20 text-trackify-emerald border border-trackify-emerald/30 text-xs font-heading font-bold transition-all duration-200"
        >
          <Share2 className="w-4 h-4" />
          <span>Send Material Specs via WhatsApp</span>
        </button>
      </div>

      {/* ── Right Column: Interactive Phone Mockup Simulator ── */}
      <div className="lg:col-span-7 flex justify-center">
        <div className="w-full max-w-[310px] sm:max-w-[390px] rounded-[30px] sm:rounded-[36px] p-2.5 sm:p-3.5 bg-gradient-to-b from-[#1F2D44] via-[#0E1726] to-[#0A101D] border-2 border-white/[0.12] shadow-2xl relative">
          {/* Phone Speaker Notch */}
          <div className="absolute top-4 sm:top-5 left-1/2 -translate-x-1/2 w-24 sm:w-28 h-3.5 sm:h-4 bg-[#080E1A] rounded-full flex items-center justify-center gap-2 z-20">
            <div className="w-2 sm:w-2.5 h-2 sm:h-2.5 rounded-full bg-trackify-cardBorder" />
            <div className="w-6 sm:w-8 h-1 sm:h-1.5 rounded-full bg-trackify-cardBorder" />
          </div>

          {/* Screen Container */}
          <div className="rounded-[22px] sm:rounded-[28px] bg-trackify-bg border border-white/[0.06] overflow-hidden pt-7 sm:pt-8 pb-3 sm:pb-3.5 px-2.5 sm:px-3 relative flex flex-col max-h-[560px]">
            {/* Phone App Header */}
            <div className="flex items-center justify-between pb-2 border-b border-white/[0.08] mb-2">
              <div className="flex items-center gap-1.5">
                <Smartphone className="w-3.5 h-3.5 text-trackify-amber" />
                <span className="font-heading font-bold text-xs text-trackify-textMain">
                  Trackify Toolkit v1.4
                </span>
              </div>
              <div className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-trackify-amber/10 border border-trackify-amber/20 text-[10px] font-mono text-trackify-amber">
                <Calculator className="w-2.5 h-2.5" />
                <span>CALC</span>
              </div>
            </div>

            {/* Mode Banner inside screen */}
            <div className="flex items-center justify-between px-2.5 py-1.5 rounded-lg bg-white/[0.03] border border-white/[0.06] mb-2">
              <div className="flex items-center gap-1.5">
                <Building className="w-3 h-3 text-trackify-cyan flex-shrink-0" />
                <span className="text-[11px] font-mono text-trackify-textMain font-medium truncate">
                  {mode === 'materials'
                    ? `Footprint: ${formatIndianNumber(builtUpArea)} sq.ft`
                    : `Slab: ${lengthFt}'×${widthFt}'×${depthInches}"`}
                </span>
              </div>
              <span className="text-[10px] font-mono text-trackify-emerald flex-shrink-0">
                {mode === 'materials' ? `${activeMaterials.length} Active` : `${wetM3.toFixed(2)} m³`}
              </span>
            </div>

            {/* Floating Toast notification */}
            <AnimatePresence>
              {feedbackToast && (
                <motion.div
                  initial={{ opacity: 0, y: -8, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -8, scale: 0.95 }}
                  className="mb-2 px-2.5 py-1 rounded-md bg-trackify-emerald/20 border border-trackify-emerald/40 text-trackify-emerald text-[10px] font-mono text-center"
                >
                  {feedbackToast}
                </motion.div>
              )}
            </AnimatePresence>

            {/* Scrollable Material List / Breakdown */}
            <div className="overflow-y-auto pr-1 space-y-2 flex-1 scrollbar-thin">
              {mode === 'materials' ? (
                materials.map((item) => {
                  const baseQty = Math.round(builtUpArea * item.qtyMultiplier);
                  const totalQty = baseQty + item.extraAdded;
                  const itemCost = totalQty * item.ratePerUnit;

                  return (
                    <div
                      key={item.id}
                      className={`p-2 sm:p-2.5 rounded-xl border transition-all ${
                        item.enabled
                          ? 'bg-white/[0.03] border-white/[0.08]'
                          : 'bg-white/[0.01] border-white/[0.03] opacity-40'
                      }`}
                    >
                      <div className="flex items-start justify-between gap-2">
                        <div className="flex items-start gap-2 flex-1 min-w-0">
                          <div
                            className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5 border"
                            style={{
                              backgroundColor: `${item.color}15`,
                              borderColor: `${item.color}35`,
                              color: item.color,
                            }}
                          >
                            <MaterialIcon id={item.id} className="w-3.5 h-3.5" />
                          </div>
                          <div className="min-w-0 flex-1">
                            <div className="flex items-center gap-1.5 flex-wrap">
                              <span className="font-heading font-semibold text-xs text-trackify-textMain truncate">
                                {item.name}
                              </span>
                              <span className={`text-[9px] font-mono px-1.5 py-0.2 rounded border ${item.badgeColor}`}>
                                ₹{item.ratePerUnit}/{item.unit}
                              </span>
                            </div>
                            <p className="text-[10px] text-trackify-textMuted truncate mt-0.5">
                              {item.spec}
                            </p>
                          </div>
                        </div>

                        {/* Toggle Checkbox */}
                        <button
                          onClick={() => toggleMaterial(item.id)}
                          className={`w-4 h-4 rounded flex items-center justify-center transition-colors flex-shrink-0 mt-0.5 ${
                            item.enabled
                              ? 'bg-trackify-emerald text-trackify-bg'
                              : 'border border-white/20 text-transparent'
                          }`}
                          aria-label={`Toggle ${item.name}`}
                        >
                          <Check className="w-2.5 h-2.5 stroke-[3]" />
                        </button>
                      </div>

                      {/* Quantity & Interactive Add */}
                      {item.enabled && (
                        <div className="mt-2 pt-1.5 border-t border-white/[0.04] flex items-center justify-between">
                          <div className="flex items-baseline gap-1">
                            <span className="text-xs sm:text-sm font-heading font-bold text-trackify-textMain">
                              {formatIndianNumber(totalQty)}
                            </span>
                            <span className="text-[10px] font-mono text-trackify-textMuted uppercase">
                              {item.unit}
                            </span>
                            <span className="text-[10px] font-mono text-trackify-amber ml-1">
                              ({formatINR(itemCost)})
                            </span>
                          </div>

                          {/* Quick Add +/- Button Chips */}
                          <div className="flex items-center gap-1">
                            <button
                              onClick={() => addExtraMaterial(item.id, item.id === 'bricks' ? -200 : item.id === 'steel' ? -50 : -5)}
                              disabled={item.extraAdded <= 0}
                              className="w-5 h-5 rounded bg-white/[0.04] hover:bg-white/[0.08] disabled:opacity-20 flex items-center justify-center text-trackify-textMuted hover:text-trackify-textMain text-xs"
                              title="Decrease"
                            >
                              <Minus className="w-2.5 h-2.5" />
                            </button>
                            <button
                              onClick={() => addExtraMaterial(item.id, item.id === 'bricks' ? 200 : item.id === 'steel' ? 50 : 5)}
                              className="px-1.5 h-5 rounded bg-trackify-amber/15 hover:bg-trackify-amber/25 text-trackify-amber border border-trackify-amber/30 flex items-center justify-center text-[10px] font-mono font-semibold"
                              title="Add material batch"
                            >
                              <Plus className="w-2.5 h-2.5 mr-0.5" />
                              {item.id === 'bricks' ? '200' : item.id === 'steel' ? '50' : '5'}
                            </button>
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })
              ) : (
                /* Concrete Breakdown Screen */
                <div className="space-y-2">
                  <div className="p-2.5 rounded-xl bg-white/[0.03] border border-white/[0.08]">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-1.5">
                        <MaterialIcon id="cement" className="w-3.5 h-3.5 text-trackify-amber" />
                        <span className="text-xs font-semibold text-trackify-textMain">OPC Cement</span>
                      </div>
                      <span className="text-xs font-mono font-bold text-trackify-amber">
                        {concCementBags} Bags
                      </span>
                    </div>
                    <div className="w-full bg-white/[0.05] h-1.5 rounded-full mt-1.5 overflow-hidden">
                      <div className="bg-trackify-amber h-full rounded-full" style={{ width: '45%' }} />
                    </div>
                    <p className="text-[10px] font-mono text-trackify-textMuted mt-1">
                      {concCementBags * 50} kg · Est. {formatINR(concCementBags * 385)}
                    </p>
                  </div>

                  <div className="p-2.5 rounded-xl bg-white/[0.03] border border-white/[0.08]">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-1.5">
                        <MaterialIcon id="sand" className="w-3.5 h-3.5 text-yellow-400" />
                        <span className="text-xs font-semibold text-trackify-textMain">Sand / M-Sand</span>
                      </div>
                      <span className="text-xs font-mono font-bold text-yellow-400">
                        {concSandCft} CFT
                      </span>
                    </div>
                    <div className="w-full bg-white/[0.05] h-1.5 rounded-full mt-1.5 overflow-hidden">
                      <div className="bg-yellow-400 h-full rounded-full" style={{ width: '60%' }} />
                    </div>
                    <p className="text-[10px] font-mono text-trackify-textMuted mt-1">
                      {(concSandCft / 35.315).toFixed(2)} m³ · Est. {formatINR(concSandCft * 54)}
                    </p>
                  </div>

                  <div className="p-2.5 rounded-xl bg-white/[0.03] border border-white/[0.08]">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-1.5">
                        <MaterialIcon id="aggregate" className="w-3.5 h-3.5 text-cyan-400" />
                        <span className="text-xs font-semibold text-trackify-textMain">20mm Aggregate</span>
                      </div>
                      <span className="text-xs font-mono font-bold text-cyan-400">
                        {concAggCft} CFT
                      </span>
                    </div>
                    <div className="w-full bg-white/[0.05] h-1.5 rounded-full mt-1.5 overflow-hidden">
                      <div className="bg-cyan-400 h-full rounded-full" style={{ width: '80%' }} />
                    </div>
                    <p className="text-[10px] font-mono text-trackify-textMuted mt-1">
                      {(concAggCft / 35.315).toFixed(2)} m³ · Est. {formatINR(concAggCft * 42)}
                    </p>
                  </div>

                  <div className="p-2.5 rounded-xl bg-white/[0.03] border border-white/[0.08]">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-semibold text-trackify-textMain">Water Batching</span>
                      <span className="text-xs font-mono font-bold text-trackify-emerald">
                        {concWaterLiters} L
                      </span>
                    </div>
                    <p className="text-[10px] font-mono text-trackify-textMuted mt-1">
                      W/C Ratio ~ 0.50 (25 Liters per 50kg bag)
                    </p>
                  </div>
                </div>
              )}
            </div>

            {/* Bottom Total Bar inside screen */}
            <div className="mt-2 pt-2 border-t border-white/[0.08] flex items-center justify-between">
              <div>
                <p className="text-[9px] font-mono uppercase tracking-wider text-trackify-textMuted">
                  Estimated Total
                </p>
                <p className="font-heading font-bold text-xs sm:text-sm text-trackify-textMain">
                  {formatINR(mode === 'materials' ? totalMaterialCost : concTotalCost)}
                </p>
              </div>

              <button
                onClick={shareEstimate}
                className="flex items-center gap-1 px-2.5 py-1 rounded-lg bg-trackify-amber text-trackify-bg text-[10px] font-heading font-bold hover:bg-trackify-amberDark transition-colors"
              >
                <CheckCircle2 className="w-3 h-3" />
                <span>Export BOM</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
