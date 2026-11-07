import { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Menu, X, ExternalLink, CalendarCheck } from 'lucide-react';
import { siteConfig } from '@/config/siteConfig';
import { navLinks } from '@/data/navigation';

interface NavbarProps {
  onDemoClick: () => void;
  activeSection?: string;
  onNavigate?: (id: string) => void;
}

export default function Navbar({ onDemoClick, activeSection, onNavigate }: NavbarProps) {
  const [scrolled, setScrolled] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 50);
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  // Lock body scroll when drawer is open
  useEffect(() => {
    if (drawerOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [drawerOpen]);

  const handleNavClick = useCallback(
    (e: React.MouseEvent<HTMLAnchorElement>, href: string) => {
      e.preventDefault();
      const id = href.replace('#', '');
      if (onNavigate) {
        onNavigate(id);
      } else {
        const target = document.getElementById(id);
        if (target) {
          const navbarOffset = 75;
          const targetY = target.getBoundingClientRect().top + window.scrollY - navbarOffset;
          window.scrollTo({ top: Math.max(0, targetY), behavior: 'smooth' });
        }
      }
      setDrawerOpen(false);
    },
    [onNavigate],
  );

  const handleScrollToTop = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    if (onNavigate) {
      onNavigate('');
    }
    window.scrollTo({ top: 0, behavior: 'smooth' });
    if (window.history.pushState) {
      window.history.pushState(null, '', ' ');
    }
    setDrawerOpen(false);
  }, [onNavigate]);

  return (
    <>
      <nav
        role="navigation"
        aria-label="Main navigation"
        className={`fixed top-0 left-0 right-0 z-40 transition-all duration-300 ${
          scrolled
            ? 'backdrop-blur-md bg-trackify-bg/80 border-b border-white/[0.05]'
            : 'bg-transparent'
        }`}
      >
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            {/* ── Logo ── */}
            <a
              href="#"
              onClick={handleScrollToTop}
              className="flex items-center gap-2.5 group"
              aria-label="Scroll to top"
            >
              {/* Geometric "T" built from grid squares */}
              <svg
                width="32"
                height="32"
                viewBox="0 0 32 32"
                fill="none"
                aria-hidden="true"
                className="flex-shrink-0"
              >
                {/* Top row – 5 squares forming the crossbar */}
                <rect x="2" y="4" width="6" height="6" rx="1" fill="#F59E0B" opacity="0.9" />
                <rect x="9" y="4" width="6" height="6" rx="1" fill="#F59E0B" />
                <rect x="16" y="4" width="6" height="6" rx="1" fill="#F59E0B" opacity="0.9" />
                {/* Stem – 3 stacked squares in the center */}
                <rect x="9" y="11" width="6" height="6" rx="1" fill="#F59E0B" opacity="0.7" />
                <rect x="9" y="18" width="6" height="6" rx="1" fill="#F59E0B" opacity="0.55" />
                <rect x="9" y="25" width="6" height="5" rx="1" fill="#F59E0B" opacity="0.4" />
                {/* Extra accent squares */}
                <rect x="23" y="4" width="5" height="6" rx="1" fill="#F59E0B" opacity="0.5" />
              </svg>
              <span className="font-heading font-bold text-xl text-trackify-textMain group-hover:text-trackify-amber transition-colors">
                {siteConfig.productName}
              </span>
            </a>

            {/* ── Center Nav Links (Desktop) ── */}
            <div className="hidden lg:flex items-center gap-6">
              {navLinks.map((link) => {
                const sectionId = link.href.replace('#', '');
                const isActive = activeSection === sectionId;
                return (
                  <a
                    key={link.href}
                    href={link.href}
                    onClick={(e) => handleNavClick(e, link.href)}
                    className={`font-mono text-sm transition-all py-1 relative ${
                      isActive
                        ? 'text-trackify-amber font-semibold'
                        : 'text-trackify-textMuted hover:text-trackify-amber'
                    }`}
                  >
                    {link.label}
                    {isActive && (
                      <motion.span
                        layoutId="activeNavIndicator"
                        className="absolute -bottom-1 left-0 right-0 h-0.5 bg-trackify-amber rounded-full"
                        transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                      />
                    )}
                  </a>
                );
              })}
            </div>

            {/* ── Right Buttons (Desktop) ── */}
            <div className="hidden lg:flex items-center gap-3">
              <a
                href={siteConfig.links.adminWebLogin}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-trackify-cardBorder text-sm font-mono text-trackify-textMuted hover:text-trackify-textMain hover:border-trackify-amber/40 transition-all"
              >
                Admin Login
                <ExternalLink className="w-3.5 h-3.5" aria-hidden="true" />
              </a>
              <button
                onClick={onDemoClick}
                className="inline-flex items-center gap-2 px-5 py-2 rounded-lg bg-trackify-amber text-trackify-bg text-sm font-heading font-semibold hover:bg-trackify-amberDark transition-colors focus:outline-none focus:ring-2 focus:ring-trackify-amber/50 focus:ring-offset-2 focus:ring-offset-trackify-bg"
              >
                <CalendarCheck className="w-4 h-4" aria-hidden="true" />
                Book a Free Demo
              </button>
            </div>

            {/* ── Hamburger (Mobile) ── */}
            <button
              onClick={() => setDrawerOpen(true)}
              className="lg:hidden p-2 text-trackify-textMuted hover:text-trackify-amber transition-colors focus:outline-none focus:ring-2 focus:ring-trackify-amber/50 rounded-lg"
              aria-label="Open menu"
            >
              <Menu className="w-6 h-6" />
            </button>
          </div>
        </div>

        {/* ── Hazard Stripe ── */}
        <div className="hazard-stripe hazard-stripe-thin" aria-hidden="true" />
      </nav>

      {/* ── Mobile Drawer ── */}
      <AnimatePresence>
        {drawerOpen && (
          <>
            {/* Backdrop */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.2 }}
              className="fixed inset-0 z-50 bg-black/60"
              onClick={() => setDrawerOpen(false)}
              aria-hidden="true"
            />

            {/* Drawer Panel */}
            <motion.div
              initial={{ x: '100%' }}
              animate={{ x: 0 }}
              exit={{ x: '100%' }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              className="fixed top-0 right-0 bottom-0 z-50 w-full max-w-sm bg-trackify-bg/95 backdrop-blur-lg border-l border-white/[0.05] flex flex-col"
              role="dialog"
              aria-modal="true"
              aria-label="Mobile navigation"
            >
              {/* Close */}
              <div className="flex items-center justify-between px-6 h-16">
                <span className="font-heading font-bold text-lg text-trackify-textMain">
                  Menu
                </span>
                <button
                  onClick={() => setDrawerOpen(false)}
                  className="p-2 text-trackify-textMuted hover:text-trackify-amber transition-colors focus:outline-none focus:ring-2 focus:ring-trackify-amber/50 rounded-lg"
                  aria-label="Close menu"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>

              <div className="hazard-stripe hazard-stripe-thin" aria-hidden="true" />

              {/* Nav Links */}
              <nav className="flex-1 px-6 py-6 overflow-y-auto">
                {navLinks.map((link, i) => {
                  const sectionId = link.href.replace('#', '');
                  const isActive = activeSection === sectionId;
                  return (
                    <motion.a
                      key={link.href}
                      href={link.href}
                      onClick={(e) => handleNavClick(e, link.href)}
                      initial={{ opacity: 0, x: 24 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: 0.05 * i }}
                      className={`block py-4 text-lg font-body border-b border-white/[0.05] transition-colors ${
                        isActive
                          ? 'text-trackify-amber'
                          : 'text-trackify-textMuted hover:text-trackify-amber'
                      }`}
                    >
                      <span className="font-mono text-xs text-trackify-textMuted/50 mr-3">
                        {String(i + 1).padStart(2, '0')}
                      </span>
                      {link.label}
                    </motion.a>
                  );
                })}
              </nav>

              {/* Bottom CTAs */}
              <div className="px-6 pb-8 space-y-3">
                <a
                  href={siteConfig.links.adminWebLogin}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-center gap-2 w-full px-4 py-3 rounded-lg border border-trackify-cardBorder text-sm font-mono text-trackify-textMuted hover:text-trackify-textMain hover:border-trackify-amber/40 transition-all"
                >
                  Admin Login
                  <ExternalLink className="w-3.5 h-3.5" aria-hidden="true" />
                </a>
                <button
                  onClick={() => {
                    setDrawerOpen(false);
                    onDemoClick();
                  }}
                  className="flex items-center justify-center gap-2 w-full px-5 py-3 rounded-lg bg-trackify-amber text-trackify-bg text-sm font-heading font-semibold hover:bg-trackify-amberDark transition-colors focus:outline-none focus:ring-2 focus:ring-trackify-amber/50"
                >
                  <CalendarCheck className="w-4 h-4" aria-hidden="true" />
                  Book a Free Demo
                </button>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </>
  );
}
