import { useState } from 'react';
import { siteConfig } from '@/config/siteConfig';
import { Modal } from '@/components/ui/Modal';
import { MapPin, Mail, MessageCircle, ExternalLink, ShieldCheck, Scale, Lock } from 'lucide-react';

export default function Footer() {
  const currentYear = new Date().getFullYear();

  // Legal Modal states
  const [legalModal, setLegalModal] = useState<'privacy' | 'terms' | 'rbac' | null>(null);

  const handleScrollTo = (e: React.MouseEvent<HTMLAnchorElement>, href: string) => {
    e.preventDefault();
    const id = href.replace('#', '');
    const el = document.getElementById(id);
    if (el) {
      const targetY = el.getBoundingClientRect().top + window.scrollY - 75;
      window.scrollTo({ top: Math.max(0, targetY), behavior: 'smooth' });
    }
  };

  return (
    <footer className="relative bg-[#050912] border-t border-trackify-cardBorder text-trackify-textMuted pt-16 pb-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Top 4-Column Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-12 gap-10 pb-12 border-b border-white/[0.08]">
          {/* Col 1: Brand & Identity (5 cols) */}
          <div className="lg:col-span-4 space-y-4">
            <div className="flex items-center gap-2.5">
              {/* Geometric T */}
              <svg width="32" height="32" viewBox="0 0 32 32" fill="none" aria-hidden="true">
                <rect x="2" y="4" width="6" height="6" rx="1" fill="#F59E0B" opacity="0.9" />
                <rect x="9" y="4" width="6" height="6" rx="1" fill="#F59E0B" />
                <rect x="16" y="4" width="6" height="6" rx="1" fill="#F59E0B" opacity="0.9" />
                <rect x="9" y="11" width="6" height="6" rx="1" fill="#F59E0B" opacity="0.7" />
                <rect x="9" y="18" width="6" height="6" rx="1" fill="#F59E0B" opacity="0.55" />
                <rect x="9" y="25" width="6" height="5" rx="1" fill="#F59E0B" opacity="0.4" />
                <rect x="23" y="4" width="5" height="6" rx="1" fill="#F59E0B" opacity="0.5" />
              </svg>
              <span className="font-heading font-bold text-xl text-trackify-textMain">
                {siteConfig.productName}
              </span>
            </div>

            <p className="text-sm text-trackify-textMuted max-w-sm leading-relaxed font-body">
              {siteConfig.tagline}
            </p>
            <p className="text-xs text-trackify-textMuted/70 max-w-sm font-mono">
              Empowering civil contractors, builders, and site supervisors with tamper-proof muster rolls, instant advance deductions, and drawing tracking.
            </p>
          </div>

          {/* Col 2: Navigation Links (2.5 cols) */}
          <div className="lg:col-span-3 space-y-3">
            <h5 className="font-heading font-semibold text-xs uppercase tracking-wider text-trackify-amber font-mono">
              Platform Modules
            </h5>
            <ul className="space-y-2 text-sm">
              <li>
                <a
                  href="#features"
                  onClick={(e) => handleScrollTo(e, '#features')}
                  className="hover:text-trackify-textMain transition-colors"
                >
                  Core Features
                </a>
              </li>
              <li>
                <a
                  href="#solutions"
                  onClick={(e) => handleScrollTo(e, '#solutions')}
                  className="hover:text-trackify-textMain transition-colors"
                >
                  Tailored Solutions
                </a>
              </li>
              <li>
                <a
                  href="#plans"
                  onClick={(e) => handleScrollTo(e, '#plans')}
                  className="hover:text-trackify-textMain transition-colors"
                >
                  Drawings & Client Billing
                </a>
              </li>
              <li>
                <a
                  href="#how-it-works"
                  onClick={(e) => handleScrollTo(e, '#how-it-works')}
                  className="hover:text-trackify-textMain transition-colors"
                >
                  How It Works
                </a>
              </li>
              <li>
                <a
                  href="#about"
                  onClick={(e) => handleScrollTo(e, '#about')}
                  className="hover:text-trackify-textMain transition-colors"
                >
                  About the Founder
                </a>
              </li>
            </ul>
          </div>

          {/* Col 3: Legal & Compliance (2.5 cols) */}
          <div className="lg:col-span-2 space-y-3">
            <h5 className="font-heading font-semibold text-xs uppercase tracking-wider text-trackify-cyan font-mono">
              Compliance & Trust
            </h5>
            <ul className="space-y-2 text-sm">
              <li>
                <button
                  type="button"
                  onClick={() => setLegalModal('privacy')}
                  className="hover:text-trackify-textMain transition-colors text-left"
                >
                  Privacy Policy
                </button>
              </li>
              <li>
                <button
                  type="button"
                  onClick={() => setLegalModal('terms')}
                  className="hover:text-trackify-textMain transition-colors text-left"
                >
                  Terms of Service
                </button>
              </li>
              <li>
                <button
                  type="button"
                  onClick={() => setLegalModal('rbac')}
                  className="hover:text-trackify-textMain transition-colors text-left"
                >
                  RBAC Security Notice
                </button>
              </li>
              <li>
                <a
                  href={siteConfig.links.adminWebLogin}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 text-trackify-amber hover:underline text-xs font-mono pt-1"
                >
                  <span>Admin Console Login</span>
                  <ExternalLink className="w-3 h-3" />
                </a>
              </li>
            </ul>
          </div>

          {/* Col 4: Contact & Engineering HQ (3 cols) */}
          <div className="lg:col-span-3 space-y-3">
            <h5 className="font-heading font-semibold text-xs uppercase tracking-wider text-trackify-emerald font-mono">
              Engineering Liaison
            </h5>
            <div className="space-y-2 text-xs font-mono">
              <div className="flex items-start gap-2 text-trackify-textMuted">
                <MapPin className="w-4 h-4 text-trackify-amber flex-shrink-0 mt-0.5" />
                <span>{siteConfig.contact.location}</span>
              </div>
              <div className="flex items-center gap-2">
                <Mail className="w-4 h-4 text-trackify-cyan flex-shrink-0" />
                <a
                  href={`mailto:${siteConfig.contact.email}`}
                  className="hover:text-trackify-textMain transition-colors"
                >
                  {siteConfig.contact.email}
                </a>
              </div>
              <div className="flex items-center gap-2">
                <MessageCircle className="w-4 h-4 text-[#25D366] flex-shrink-0" />
                <a
                  href={siteConfig.links.whatsappDemo}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-[#25D366] transition-colors"
                >
                  WhatsApp: {siteConfig.contact.whatsappNumber}
                </a>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Disclaimer and Copyright */}
        <div className="pt-8 flex flex-col md:flex-row items-center justify-between gap-4 text-xs font-mono text-trackify-textMuted/70">
          <p className="text-center md:text-left">
            Trackify is an independent software product engineered for the construction and civil engineering industry.
          </p>
          <p>© {currentYear} Trackify. Built with precision in Gujarat, India.</p>
        </div>
      </div>

      {/* ── Privacy Policy Modal ── */}
      <Modal
        isOpen={legalModal === 'privacy'}
        onClose={() => setLegalModal(null)}
        title="Privacy Policy & Workforce Data Security"
      >
        <div className="space-y-4 text-xs sm:text-sm text-trackify-textMuted font-body max-h-[60vh] overflow-y-auto pr-2">
          <p>
            At <strong>Trackify</strong>, we are committed to safeguarding contractor operational data, worker biometric identifiers, daily muster rolls, and proprietary project blueprints.
          </p>
          <h5 className="font-heading font-bold text-trackify-textMain text-sm">
            1. Data Storage & Encryption
          </h5>
          <p>
            All wage structures, attendance timestamps, and cash advance ledgers are encrypted in transit via TLS 1.3 and at rest with AES-256 standards. No raw financial credentials or credit card numbers are collected on our devices.
          </p>
          <h5 className="font-heading font-bold text-trackify-textMain text-sm">
            2. Offline Local Storage
          </h5>
          <p>
            Attendance stamps queued offline inside basements or remote locations are cryptographically salted in local application sandboxes and purged immediately following successful cloud synchronization.
          </p>
        </div>
      </Modal>

      {/* ── Terms of Service Modal ── */}
      <Modal
        isOpen={legalModal === 'terms'}
        onClose={() => setLegalModal(null)}
        title="Terms of Service & Licensing"
      >
        <div className="space-y-4 text-xs sm:text-sm text-trackify-textMuted font-body max-h-[60vh] overflow-y-auto pr-2">
          <p>
            By accessing or subscribing to the <strong>Trackify</strong> web console or site supervisor mobile applications, you agree to these operational provisions.
          </p>
          <h5 className="font-heading font-bold text-trackify-textMain text-sm">
            1. Organization Verification
          </h5>
          <p>
            Account holders must be legitimate contractors, construction companies, project developers, or certified civil engineering practices operating under applicable regional commercial frameworks.
          </p>
          <h5 className="font-heading font-bold text-trackify-textMain text-sm">
            2. Attendance Verification Guarantee
          </h5>
          <p>
            Trackify provides mathematical computation engines for wage settlements based on supervisor inputs. Contractors maintain sovereign responsibility for disbursing cash or bank transfers to their registered workers.
          </p>
        </div>
      </Modal>

      {/* ── RBAC Notice Modal ── */}
      <Modal
        isOpen={legalModal === 'rbac'}
        onClose={() => setLegalModal(null)}
        title="Role-Based Access Control (RBAC) Notice"
      >
        <div className="space-y-4 text-xs sm:text-sm text-trackify-textMuted font-body max-h-[60vh] overflow-y-auto pr-2">
          <p>
            Trackify enforces strict zero-trust data segregation across user categories on the construction site:
          </p>
          <ul className="list-disc pl-5 space-y-2">
            <li>
              <strong className="text-trackify-textMain">Supervisors:</strong> Restricted to marking attendance, scanning QR cards, and logging cash advances for their assigned sites only. No access to contractor profit margins or organization billing.
            </li>
            <li>
              <strong className="text-trackify-textMain">Contractors / Admins:</strong> Sovereign authorization over wage rates, client billing statements, drawing releases, and multi-site cost burns.
            </li>
            <li>
              <strong className="text-trackify-textMain">Workers:</strong> Read-only telephone authentication verifying their individual balance and attendance tally.
            </li>
          </ul>
        </div>
      </Modal>
    </footer>
  );
}

