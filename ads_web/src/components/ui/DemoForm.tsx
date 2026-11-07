import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { siteConfig } from '@/config/siteConfig';
import {
  CheckCircle2,
  Send,
  MessageCircle,
  AlertCircle,
  Loader2,
  ArrowRight,
  ShieldCheck,
  Clock,
  Download,
  Smartphone,
  Laptop,
  ExternalLink,
} from 'lucide-react';

interface DemoFormData {
  fullName: string;
  companyName: string;
  email: string;
  phone: string;
  workerCount: string;
  activeSites: string;
  notes: string;
}

interface FormErrors {
  fullName?: string;
  companyName?: string;
  email?: string;
  phone?: string;
  workerCount?: string;
}

interface DemoFormProps {
  onSuccessClose?: () => void;
  inModal?: boolean;
  onSuccessStateChange?: (success: boolean) => void;
}

const CLOUD_FUNCTION_URL =
  import.meta.env.VITE_SUBMIT_DEMO_URL ||
  'https://us-central1-ys-construction.cloudfunctions.net/submitDemoRequest';

export default function DemoForm({
  onSuccessClose,
  inModal = false,
  onSuccessStateChange,
}: DemoFormProps) {
  const [formData, setFormData] = useState<DemoFormData>({
    fullName: '',
    companyName: '',
    email: '',
    phone: '',
    workerCount: '25-50',
    activeSites: '3-5',
    notes: '',
  });

  const [errors, setErrors] = useState<FormErrors>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [submissionError, setSubmissionError] = useState<string | null>(null);
  const [demoUrl, setDemoUrl] = useState<string | null>(null);

  useEffect(() => {
    if (onSuccessStateChange) {
      onSuccessStateChange(isSuccess);
    }
  }, [isSuccess, onSuccessStateChange]);

  const validate = (): boolean => {
    const errs: FormErrors = {};

    if (!formData.fullName.trim()) {
      errs.fullName = 'Full name is required';
    }

    if (!formData.companyName.trim()) {
      errs.companyName = 'Company or firm name is required';
    }

    if (!formData.email.trim()) {
      errs.email = 'Business email is required';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email.trim())) {
      errs.email = 'Please enter a valid email address';
    }

    const cleanPhone = formData.phone.replace(/[\s-]/g, '');
    if (!cleanPhone) {
      errs.phone = 'Mobile or WhatsApp number is required';
    } else if (cleanPhone.replace(/[^0-9]/g, '').length < 10) {
      errs.phone = 'Please enter a valid 10-digit number';
    }

    setErrors(errs);
    return Object.keys(errs).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;

    setIsSubmitting(true);
    setSubmissionError(null);

    // Prepare WhatsApp notification payload
    const text = encodeURIComponent(
      `*New Demo Request — Trackify SaaS*\n\n` +
      `Name: ${formData.fullName.trim()}\n` +
      `Firm: ${formData.companyName.trim()}\n` +
      `Email: ${formData.email.trim()}\n` +
      `Phone: ${formData.phone.trim()}\n` +
      `Active Sites: ${formData.activeSites}\n` +
      `Workforce Size: ${formData.workerCount}\n` +
      (formData.notes.trim() ? `Notes: ${formData.notes.trim()}\n` : '')
    );
    const waUrl = `https://wa.me/${siteConfig.contact.whatsappNumber.replace('+', '')}?text=${text}`;

    try {
      const response = await fetch(CLOUD_FUNCTION_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          fullName: formData.fullName.trim(),
          companyName: formData.companyName.trim(),
          email: formData.email.trim(),
          phone: formData.phone.trim(),
          workerCount: formData.workerCount,
          activeSites: formData.activeSites,
          notes: formData.notes.trim(),
        }),
      });

      const data = await response.json().catch(() => ({}));

      let targetUrl = `${siteConfig.links.adminWebLogin}/demo`;

      if (data.success && data.token) {
        targetUrl = `${siteConfig.links.adminWebLogin}/demo?token=${encodeURIComponent(data.token)}`;
      }

      setDemoUrl(targetUrl);
      setIsSuccess(true);

      // Open WhatsApp pre-filled chat in background window
      window.open(waUrl, '_blank');
    } catch (err: any) {
      console.warn('Network call to Cloud Function fallback:', err);
      const fallbackUrl = `${siteConfig.links.adminWebLogin}/demo`;
      setDemoUrl(fallbackUrl);
      setIsSuccess(true);
      window.open(waUrl, '_blank');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isSuccess && demoUrl) {
    return (
      <div className="text-center py-4 px-2 sm:px-4 space-y-5">
        <div className="w-14 h-14 rounded-2xl bg-trackify-emerald/20 border border-trackify-emerald text-trackify-emerald mx-auto flex items-center justify-center animate-bounce">
          <CheckCircle2 className="w-7 h-7" />
        </div>

        <div>
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-trackify-emerald/10 border border-trackify-emerald/30 text-trackify-emerald text-xs font-mono mb-2">
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>24-Hour Demo Sandbox Activated</span>
          </span>
          <h4 className="font-heading font-bold text-2xl text-trackify-textMain">
            Welcome to Trackify Demo Sandbox!
          </h4>
          <p className="text-xs text-trackify-textMuted max-w-md mx-auto leading-relaxed mt-1.5">
            Instant read-only sandbox environment provisioned for{' '}
            <strong className="text-trackify-textMain">{formData.companyName || 'XYZ Construction'}</strong> with 3 live sites, 26 sample workers, and real-time attendance math.
          </p>
        </div>

        {/* Dual action cards: Web Demo & APK Download */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 max-w-md mx-auto text-left">
          {/* Web Admin Dashboard Card */}
          <div className="p-4 rounded-xl bg-white/[0.03] border border-trackify-amber/30 hover:border-trackify-amber/60 transition-colors flex flex-col justify-between space-y-3">
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <span className="flex items-center gap-1.5 text-xs font-mono text-trackify-amber font-semibold">
                  <Laptop className="w-4 h-4" />
                  <span>Web Dashboard</span>
                </span>
                <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-trackify-amber/10 text-trackify-amber">
                  Desktop
                </span>
              </div>
              <p className="text-[11px] text-trackify-textMuted leading-snug">
                Explore owner overview, 28-worker roster, Sunday wage settlements, and 23-drawing checklists.
              </p>
            </div>
            <a
              href={demoUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="w-full inline-flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-lg bg-trackify-amber hover:bg-trackify-amberDark text-trackify-bg font-heading font-bold text-xs transition-all shadow-md shadow-trackify-amber/20 active:scale-95"
            >
              <span>Launch Web Demo</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </div>

          {/* Supervisor APK Card */}
          <div className="p-4 rounded-xl bg-white/[0.03] border border-trackify-emerald/30 hover:border-trackify-emerald/60 transition-colors flex flex-col justify-between space-y-3">
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <span className="flex items-center gap-1.5 text-xs font-mono text-trackify-emerald font-semibold">
                  <Smartphone className="w-4 h-4" />
                  <span>Supervisor App</span>
                </span>
                <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-trackify-emerald/10 text-trackify-emerald">
                  Android APK
                </span>
              </div>
              <p className="text-[11px] text-trackify-textMuted leading-snug">
                Install on any Android phone to experience 3-second offline biometric attendance & QR check-in.
              </p>
            </div>
            <a
              href={siteConfig.links.apkDownload}
              download="Trackify-Supervisor-Release.apk"
              className="w-full inline-flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-lg bg-trackify-emerald hover:bg-trackify-emerald/90 text-white font-heading font-bold text-xs transition-all shadow-md shadow-trackify-emerald/20 active:scale-95"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Download APK (80MB)</span>
            </a>
          </div>
        </div>

        {/* WhatsApp & Footer options */}
        <div className="pt-2 flex flex-col sm:flex-row gap-2.5 justify-center items-center">
          <a
            href={`https://wa.me/${siteConfig.contact.whatsappNumber.replace('+', '')}?text=${encodeURIComponent(
              `Hi Tanvir, I just submitted the demo form for ${formData.companyName}. Please connect with me for an interactive walkthrough.`
            )}`}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-[#25D366]/20 hover:bg-[#25D366]/30 text-[#25D366] border border-[#25D366]/40 font-semibold text-xs transition-colors"
          >
            <MessageCircle className="w-4 h-4" />
            <span>Chat on WhatsApp</span>
          </a>

          {inModal && onSuccessClose && (
            <button
              onClick={onSuccessClose}
              className="px-4 py-2 rounded-lg bg-white/[0.05] hover:bg-white/[0.1] text-trackify-textMuted hover:text-trackify-textMain text-xs font-mono transition-colors cursor-pointer"
            >
              Close Window
            </button>
          )}
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-3.5 text-left">
      {submissionError && (
        <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400 text-xs font-mono flex items-center gap-2">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          <span>{submissionError}</span>
        </div>
      )}

      {/* Name and Company */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
        <div>
          <label className="block text-xs font-mono text-trackify-textMuted mb-1">
            Full Name <span className="text-trackify-amber">*</span>
          </label>
          <input
            type="text"
            required
            placeholder="e.g. Rajeshwar Varma"
            value={formData.fullName}
            onChange={(e) => {
              setFormData({ ...formData, fullName: e.target.value });
              if (errors.fullName) setErrors({ ...errors, fullName: undefined });
            }}
            className={`w-full px-3.5 py-2 rounded-lg bg-trackify-card border text-base sm:text-sm text-trackify-textMain placeholder:text-trackify-textMuted/40 focus:outline-none focus:ring-1 transition-colors ${
              errors.fullName
                ? 'border-red-500/70 focus:ring-red-500'
                : 'border-trackify-cardBorder focus:border-trackify-amber focus:ring-trackify-amber/50'
            }`}
          />
          {errors.fullName && (
            <span className="text-[11px] font-mono text-red-400 mt-0.5 flex items-center gap-1">
              <AlertCircle className="w-3 h-3" /> {errors.fullName}
            </span>
          )}
        </div>

        <div>
          <label className="block text-xs font-mono text-trackify-textMuted mb-1">
            Company / Firm Name <span className="text-trackify-amber">*</span>
          </label>
          <input
            type="text"
            required
            placeholder="e.g. Varma Infratech Pvt Ltd"
            value={formData.companyName}
            onChange={(e) => {
              setFormData({ ...formData, companyName: e.target.value });
              if (errors.companyName) setErrors({ ...errors, companyName: undefined });
            }}
            className={`w-full px-3.5 py-2 rounded-lg bg-trackify-card border text-base sm:text-sm text-trackify-textMain placeholder:text-trackify-textMuted/40 focus:outline-none focus:ring-1 transition-colors ${
              errors.companyName
                ? 'border-red-500/70 focus:ring-red-500'
                : 'border-trackify-cardBorder focus:border-trackify-amber focus:ring-trackify-amber/50'
            }`}
          />
          {errors.companyName && (
            <span className="text-[11px] font-mono text-red-400 mt-0.5 flex items-center gap-1">
              <AlertCircle className="w-3 h-3" /> {errors.companyName}
            </span>
          )}
        </div>
      </div>

      {/* Email & Phone */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
        <div>
          <label className="block text-xs font-mono text-trackify-textMuted mb-1">
            Business Email <span className="text-trackify-amber">*</span>
          </label>
          <input
            type="email"
            required
            placeholder="name@company.com"
            value={formData.email}
            onChange={(e) => {
              setFormData({ ...formData, email: e.target.value });
              if (errors.email) setErrors({ ...errors, email: undefined });
            }}
            className={`w-full px-3.5 py-2 rounded-lg bg-trackify-card border text-base sm:text-sm text-trackify-textMain placeholder:text-trackify-textMuted/40 focus:outline-none focus:ring-1 transition-colors ${
              errors.email
                ? 'border-red-500/70 focus:ring-red-500'
                : 'border-trackify-cardBorder focus:border-trackify-amber focus:ring-trackify-amber/50'
            }`}
          />
          {errors.email && (
            <span className="text-[11px] font-mono text-red-400 mt-0.5 flex items-center gap-1">
              <AlertCircle className="w-3 h-3" /> {errors.email}
            </span>
          )}
        </div>

        <div>
          <label className="block text-xs font-mono text-trackify-textMuted mb-1">
            Mobile Number <span className="text-trackify-amber">*</span>
          </label>
          <div className="relative">
            <span className="absolute left-3 top-2 text-sm font-mono text-trackify-textMuted select-none">
              +91
            </span>
            <input
              type="tel"
              required
              placeholder="98765 43210"
              value={formData.phone}
              onChange={(e) => {
                setFormData({ ...formData, phone: e.target.value });
                if (errors.phone) setErrors({ ...errors, phone: undefined });
              }}
              className={`w-full pl-12 pr-3.5 py-2 rounded-lg bg-trackify-card border text-base sm:text-sm text-trackify-textMain placeholder:text-trackify-textMuted/40 focus:outline-none focus:ring-1 transition-colors ${
                errors.phone
                  ? 'border-red-500/70 focus:ring-red-500'
                  : 'border-trackify-cardBorder focus:border-trackify-amber focus:ring-trackify-amber/50'
              }`}
            />
          </div>
          {errors.phone && (
            <span className="text-[11px] font-mono text-red-400 mt-0.5 flex items-center gap-1">
              <AlertCircle className="w-3 h-3" /> {errors.phone}
            </span>
          )}
        </div>
      </div>

      {/* Workforce Size & Sites */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
        <div>
          <label className="block text-xs font-mono text-trackify-textMuted mb-1">
            Number of Workers
          </label>
          <select
            value={formData.workerCount}
            onChange={(e) => setFormData({ ...formData, workerCount: e.target.value })}
            className="w-full px-3.5 py-2 rounded-lg bg-trackify-card border border-trackify-cardBorder text-base sm:text-sm text-trackify-textMain focus:outline-none focus:border-trackify-amber"
          >
            <option value="10-25">10 – 25 Workers</option>
            <option value="25-50">25 – 50 Workers</option>
            <option value="50-100">50 – 100 Workers</option>
            <option value="100-250">100 – 250 Workers</option>
            <option value="250+">250+ Workers</option>
          </select>
        </div>

        <div>
          <label className="block text-xs font-mono text-trackify-textMuted mb-1">
            Active Construction Sites
          </label>
          <select
            value={formData.activeSites}
            onChange={(e) => setFormData({ ...formData, activeSites: e.target.value })}
            className="w-full px-3.5 py-2 rounded-lg bg-trackify-card border border-trackify-cardBorder text-base sm:text-sm text-trackify-textMain focus:outline-none focus:border-trackify-amber"
          >
            <option value="1-2">1 – 2 Sites</option>
            <option value="3-5">3 – 5 Sites</option>
            <option value="6-10">6 – 10 Sites</option>
            <option value="10+">10+ Sites</option>
          </select>
        </div>
      </div>

      {/* Submit Button */}
      <div className="pt-2">
        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full inline-flex items-center justify-center gap-2 py-3 px-6 rounded-xl bg-trackify-amber hover:bg-trackify-amberDark text-trackify-bg font-heading font-bold text-sm tracking-wide transition-all shadow-lg shadow-trackify-amber/25 active:scale-95 disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer"
        >
          {isSubmitting ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              <span>Generating Demo Sandbox…</span>
            </>
          ) : (
            <>
              <ShieldCheck className="w-4 h-4" />
              <span>Explore Live Demo (Instant Access)</span>
            </>
          )}
        </button>
      </div>

      <p className="text-center text-[10px] font-mono text-trackify-textMuted/70">
        🔒 Instant access. No credit card required. 24-hour sandbox session.
      </p>
    </form>
  );
}
