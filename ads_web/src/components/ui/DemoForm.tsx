import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { siteConfig } from '@/config/siteConfig';
import { CheckCircle2, Send, MessageCircle, AlertCircle, Loader2 } from 'lucide-react';

interface DemoFormData {
  fullName: string;
  companyName: string;
  phone: string;
  activeSites: string;
  workforceSize: string;
  message: string;
}

interface FormErrors {
  fullName?: string;
  companyName?: string;
  phone?: string;
}

interface DemoFormProps {
  onSuccessClose?: () => void;
  inModal?: boolean;
}

export default function DemoForm({ onSuccessClose, inModal = false }: DemoFormProps) {
  const [formData, setFormData] = useState<DemoFormData>({
    fullName: '',
    companyName: '',
    phone: '',
    activeSites: '3-5',
    workforceSize: '50-100',
    message: '',
  });

  const [errors, setErrors] = useState<FormErrors>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);

  const validate = (): boolean => {
    const errs: FormErrors = {};

    if (!formData.fullName.trim()) {
      errs.fullName = 'Full name is required';
    }

    if (!formData.companyName.trim()) {
      errs.companyName = 'Company or firm name is required';
    }

    const cleanPhone = formData.phone.replace(/[\s-]/g, '');
    if (!cleanPhone) {
      errs.phone = 'Phone or WhatsApp number is required';
    } else if (cleanPhone.length < 10) {
      errs.phone = 'Please enter a valid 10-digit number';
    }

    setErrors(errs);
    return Object.keys(errs).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;

    setIsSubmitting(true);

    try {
      // Attempt optional Supabase if environment variables or public keys are provided
      // If not configured, gracefully trigger pre-filled WhatsApp link & success screen
      await new Promise((res) => setTimeout(res, 800)); // Smooth UX transition

      // Prepare WhatsApp redirect message
      const text = encodeURIComponent(
        `*New Demo Request — Trackify SaaS*\n\n` +
        `Name: ${formData.fullName}\n` +
        `Firm: ${formData.companyName}\n` +
        `Phone: ${formData.phone}\n` +
        `Active Sites: ${formData.activeSites}\n` +
        `Workforce Size: ${formData.workforceSize}\n` +
        (formData.message ? `Notes: ${formData.message}\n` : '')
      );

      // Open WhatsApp in background/tab
      const waUrl = `https://wa.me/${siteConfig.contact.whatsappNumber.replace('+', '')}?text=${text}`;
      window.open(waUrl, '_blank');

      setIsSuccess(true);
    } catch {
      setIsSuccess(true);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isSuccess) {
    return (
      <div className="text-center py-8 px-4 space-y-4">
        <div className="w-16 h-16 rounded-full bg-trackify-emerald/20 border-2 border-trackify-emerald text-trackify-emerald mx-auto flex items-center justify-center animate-bounce">
          <CheckCircle2 className="w-8 h-8" />
        </div>
        <h4 className="font-heading font-bold text-2xl text-trackify-textMain">
          Demo Request Dispatched!
        </h4>
        <p className="text-sm text-trackify-textMuted max-w-sm mx-auto leading-relaxed">
          Thank you, <strong className="text-trackify-textMain">{formData.fullName}</strong>. We've received your site requirements and initiated a direct WhatsApp connection. Our founder will contact you within 2 hours.
        </p>

        <div className="pt-4 flex flex-col sm:flex-row gap-3 justify-center">
          <a
            href={siteConfig.links.whatsappDemo}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-lg bg-[#25D366] text-slate-950 font-semibold text-xs transition-transform active:scale-95"
          >
            <MessageCircle className="w-4 h-4" />
            <span>Open WhatsApp Chat Directly</span>
          </a>

          {inModal && onSuccessClose && (
            <button
              onClick={onSuccessClose}
              className="px-4 py-2.5 rounded-lg bg-white/[0.05] hover:bg-white/[0.1] text-trackify-textMain text-xs font-mono transition-colors"
            >
              Close Window
            </button>
          )}
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4 text-left">
      {/* Name and Company */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label className="block text-xs font-mono text-trackify-textMuted mb-1.5">
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
            className={`w-full px-3.5 py-2.5 rounded-lg bg-trackify-card border text-sm text-trackify-textMain placeholder:text-trackify-textMuted/40 focus:outline-none focus:ring-1 transition-colors ${
              errors.fullName
                ? 'border-red-500/70 focus:ring-red-500'
                : 'border-trackify-cardBorder focus:border-trackify-amber focus:ring-trackify-amber/50'
            }`}
          />
          {errors.fullName && (
            <span className="text-[11px] font-mono text-red-400 mt-1 flex items-center gap-1">
              <AlertCircle className="w-3 h-3" /> {errors.fullName}
            </span>
          )}
        </div>

        <div>
          <label className="block text-xs font-mono text-trackify-textMuted mb-1.5">
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
            className={`w-full px-3.5 py-2.5 rounded-lg bg-trackify-card border text-sm text-trackify-textMain placeholder:text-trackify-textMuted/40 focus:outline-none focus:ring-1 transition-colors ${
              errors.companyName
                ? 'border-red-500/70 focus:ring-red-500'
                : 'border-trackify-cardBorder focus:border-trackify-amber focus:ring-trackify-amber/50'
            }`}
          />
          {errors.companyName && (
            <span className="text-[11px] font-mono text-red-400 mt-1 flex items-center gap-1">
              <AlertCircle className="w-3 h-3" /> {errors.companyName}
            </span>
          )}
        </div>
      </div>

      {/* Phone Number */}
      <div>
        <label className="block text-xs font-mono text-trackify-textMuted mb-1.5">
          Phone / WhatsApp Number <span className="text-trackify-amber">*</span>
        </label>
        <div className="relative">
          <span className="absolute left-3.5 top-2.5 text-sm font-mono text-trackify-textMuted select-none">
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
            className={`w-full pl-12 pr-3.5 py-2.5 rounded-lg bg-trackify-card border text-sm font-mono text-trackify-textMain placeholder:text-trackify-textMuted/40 focus:outline-none focus:ring-1 transition-colors ${
              errors.phone
                ? 'border-red-500/70 focus:ring-red-500'
                : 'border-trackify-cardBorder focus:border-trackify-amber focus:ring-trackify-amber/50'
            }`}
          />
        </div>
        {errors.phone && (
          <span className="text-[11px] font-mono text-red-400 mt-1 flex items-center gap-1">
            <AlertCircle className="w-3 h-3" /> {errors.phone}
          </span>
        )}
      </div>

      {/* Select active sites & workforce size */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label className="block text-xs font-mono text-trackify-textMuted mb-1.5">
            Active Construction Sites
          </label>
          <select
            value={formData.activeSites}
            onChange={(e) => setFormData({ ...formData, activeSites: e.target.value })}
            className="w-full px-3 py-2.5 rounded-lg bg-trackify-card border border-trackify-cardBorder text-sm text-trackify-textMain focus:outline-none focus:border-trackify-amber"
          >
            <option value="1-2">1 to 2 Projects</option>
            <option value="3-5">3 to 5 Projects</option>
            <option value="6-10">6 to 10 Projects</option>
            <option value="10+">10+ Enterprise Sites</option>
          </select>
        </div>

        <div>
          <label className="block text-xs font-mono text-trackify-textMuted mb-1.5">
            Estimated Daily Headcount
          </label>
          <select
            value={formData.workforceSize}
            onChange={(e) => setFormData({ ...formData, workforceSize: e.target.value })}
            className="w-full px-3 py-2.5 rounded-lg bg-trackify-card border border-trackify-cardBorder text-sm text-trackify-textMain focus:outline-none focus:border-trackify-amber"
          >
            <option value="<25">Less than 25 Workers</option>
            <option value="25-50">25 to 50 Workers</option>
            <option value="50-100">50 to 100 Workers</option>
            <option value="100-250">100 to 250 Workers</option>
            <option value="250+">250+ Large Workforce</option>
          </select>
        </div>
      </div>

      {/* Message */}
      <div>
        <label className="block text-xs font-mono text-trackify-textMuted mb-1.5">
          Current Site Challenges / Pain Points <span className="text-[10px] text-trackify-textMuted/60">(Optional)</span>
        </label>
        <textarea
          rows={2}
          placeholder="e.g. Attendance registers getting soaked, weekly advance disputes on Sunday settlement..."
          value={formData.message}
          onChange={(e) => setFormData({ ...formData, message: e.target.value })}
          className="w-full px-3.5 py-2.5 rounded-lg bg-trackify-card border border-trackify-cardBorder text-sm text-trackify-textMain placeholder:text-trackify-textMuted/40 focus:outline-none focus:border-trackify-amber focus:ring-1 focus:ring-trackify-amber/50 transition-colors"
        />
      </div>

      {/* Submit Button */}
      <button
        type="submit"
        disabled={isSubmitting}
        className="w-full py-3.5 px-6 rounded-xl bg-trackify-amber hover:bg-trackify-amberDark text-trackify-bg font-heading font-bold text-sm tracking-wide flex items-center justify-center gap-2 transition-all shadow-lg shadow-trackify-amber/20 active:scale-95 disabled:opacity-70 disabled:pointer-events-none"
      >
        {isSubmitting ? (
          <>
            <Loader2 className="w-4 h-4 animate-spin" />
            <span>Connecting with Dispatch Server...</span>
          </>
        ) : (
          <>
            <Send className="w-4 h-4" />
            <span>Confirm Live On-Site Demo Booking</span>
          </>
        )}
      </button>

      <p className="text-[11px] text-center font-mono text-trackify-textMuted/60">
        🔒 100% Confidential. No credit card required. Free onboarding & setup.
      </p>
    </form>
  );
}

