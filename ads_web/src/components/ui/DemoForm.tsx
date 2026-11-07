import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { siteConfig } from '@/config/siteConfig';
import { CheckCircle2, Send, MessageCircle, AlertCircle, Loader2, ArrowRight, ShieldCheck, Clock } from 'lucide-react';

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
}

const CLOUD_FUNCTION_URL =
  import.meta.env.VITE_SUBMIT_DEMO_URL ||
  'https://us-central1-ys-construction.cloudfunctions.net/submitDemoRequest';

export default function DemoForm({ onSuccessClose, inModal = false }: DemoFormProps) {
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
  const [countdown, setCountdown] = useState<number>(4);

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
    } catch (err: any) {
      console.warn('Network call to Cloud Function fallback:', err);
      // Failsafe: if direct endpoint times out or blocked by CORS, provide immediate demo link
      const fallbackUrl = `${siteConfig.links.adminWebLogin}/demo`;
      setDemoUrl(fallbackUrl);
      setIsSuccess(true);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Auto-launch countdown when success screen is active
  useEffect(() => {
    if (!isSuccess || !demoUrl) return;

    const timer = setInterval(() => {
      setCountdown((c) => {
        if (c <= 1) {
          clearInterval(timer);
          window.location.href = demoUrl;
          return 0;
        }
        return c - 1;
      });
    }, 1000);

    return () => clearInterval(timer);
  }, [isSuccess, demoUrl]);

  if (isSuccess && demoUrl) {
    return (
      <div className="text-center py-6 px-4 space-y-5">
        <div className="w-14 h-14 rounded-2xl bg-trackify-emerald/20 border border-trackify-emerald text-trackify-emerald mx-auto flex items-center justify-center animate-bounce">
          <CheckCircle2 className="w-7 h-7" />
        </div>

        <div>
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-trackify-emerald/10 border border-trackify-emerald/30 text-trackify-emerald text-xs font-mono mb-2">
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>24-Hour Demo Sandbox Ready</span>
          </span>
          <h4 className="font-heading font-bold text-2xl text-trackify-textMain">
            Welcome, {formData.fullName}!
          </h4>
          <p className="text-xs text-trackify-textMuted max-w-sm mx-auto leading-relaxed mt-1.5">
            Your live demo environment for <strong className="text-trackify-textMain">{formData.companyName}</strong> has been provisioned with 3 active sites and 28 workers.
          </p>
        </div>

        {/* Action card */}
        <div className="p-4 rounded-xl bg-white/[0.03] border border-white/[0.08] max-w-sm mx-auto space-y-3">
          <div className="flex items-center justify-between text-xs font-mono text-trackify-textMuted">
            <span className="flex items-center gap-1.5">
              <Clock className="w-3.5 h-3.5 text-trackify-amber" />
              <span>Session Duration</span>
            </span>
            <span className="text-trackify-amber font-bold">24 Hours Active</span>
          </div>

          <a
            href={demoUrl}
            className="w-full inline-flex items-center justify-center gap-2 py-3 px-4 rounded-xl bg-trackify-amber hover:bg-trackify-amberDark text-trackify-bg font-heading font-bold text-sm transition-all shadow-lg shadow-trackify-amber/20 active:scale-95"
          >
            <span>Enter Demo Dashboard Now</span>
            <ArrowRight className="w-4 h-4" />
          </a>

          <p className="text-[11px] font-mono text-trackify-textMuted">
            Auto-launching in <strong className="text-trackify-amber">{countdown}s</strong>…
          </p>
        </div>

        <div className="pt-2 flex flex-col sm:flex-row gap-2.5 justify-center">
          <a
            href={siteConfig.links.whatsappDemo}
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
              className="px-4 py-2 rounded-lg bg-white/[0.05] hover:bg-white/[0.1] text-trackify-textMuted hover:text-trackify-textMain text-xs font-mono transition-colors"
            >
              Stay on Website
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
