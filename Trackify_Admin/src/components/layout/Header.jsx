import React, { useState, useRef, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { signOut } from 'firebase/auth';
import { Bell, ChevronDown, LogOut, User, Shield } from 'lucide-react';
import toast from 'react-hot-toast';
import { auth } from '../../lib/firebase';
import { useAuthStore } from '../../store/authStore';
import { AnimatePresence, motion } from 'framer-motion';

const PAGE_META = {
  // Contractor pages
  '/dashboard':   { title: 'Dashboard',   desc: 'Manage workforce activities and attendance' },
  '/attendance':  { title: 'Attendance',  desc: 'Mark and track daily attendance records' },
  '/labours':     { title: 'Labours',     desc: 'Manage your workforce and labour profiles' },
  '/payroll':     { title: 'Payroll',     desc: 'Calculate monthly salary and mark payments' },
  '/payments':    { title: 'Payments',    desc: 'Track advances and salary disbursements' },
  '/reports':     { title: 'Reports',     desc: 'Generate and export detailed workforce reports' },
  '/sites':       { title: 'Sites',       desc: 'Manage work sites and daily attendance' },
  '/expenses':    { title: 'Expenses',    desc: 'Track and manage project expenses' },
  '/site-costs':  { title: 'Site Costs',  desc: 'Manage material and project costs' },
  '/supervisors': { title: 'Supervisors', desc: 'Monitor supervisor performance and teams' },
  '/users':       { title: 'Users',       desc: 'Manage contractors, supervisors and access' },
  '/settings':    { title: 'Settings',    desc: 'Configure your workspace preferences' },
  // Super Admin pages
  '/sa':          { title: 'CEO Dashboard',     desc: 'Trackify SaaS revenue and business overview' },
};

const ROLE_CONFIG = {
  super_admin: { label: 'Super Admin', color: '#7C3AED', bg: '#FAF5FF', border: '#DDD6FE', icon: Shield },
  contractor:  { label: 'Contractor',  color: '#2563EB', bg: '#EFF6FF', border: '#BFDBFE', icon: User },
  supervisor:  { label: 'Supervisor',  color: '#059669', bg: '#ECFDF5', border: '#A7F3D0', icon: User },
};

export default function Header() {
  const location = useLocation();
  const role  = useAuthStore((s) => s.role);
  const name  = useAuthStore((s) => s.name);
  const email = useAuthStore((s) => s.email);
  const activeContractorId   = useAuthStore((s) => s.activeContractorId);
  const activeContractorName = useAuthStore((s) => s.activeContractorName);
  const contractorsList = useAuthStore((s) => s.contractorsList);
  const switchContractor = useAuthStore((s) => s.switchContractor);

  const [dropOpen, setDropOpen] = useState(false);
  const dropRef = useRef(null);

  const segments = location.pathname.split('/');
  // For /sa/* routes, use the /sa key
  const path = segments[1] === 'sa' ? '/sa' : '/' + segments[1];
  const SA_PAGE_TITLES = {
    'dashboard':    { title: 'Revenue Dashboard',  desc: 'MRR, ARR, and SaaS revenue overview' },
    'revenue':      { title: 'Financials',          desc: 'Revenue, GST, and transaction history' },
    'customers':    { title: 'Companies',           desc: 'All Trackify contractor companies' },
    'subscriptions':{ title: 'Subscriptions',       desc: 'Plans, renewals, and subscription status' },
    'usage':        { title: 'Usage Analytics',     desc: 'Platform-wide usage metrics today' },
    'features':     { title: 'Feature Analytics',   desc: 'Feature adoption across all companies' },
    'support':      { title: 'Support Center',      desc: 'All support tickets from contractors' },
    'growth':       { title: 'Contractor Growth',   desc: 'Top customers and expansion metrics' },
    'churn':        { title: 'Churn Analysis',      desc: 'Lost customers and at-risk accounts' },
    'insights':     { title: 'AI Insights',         desc: 'Smart suggestions based on usage data' },
  };
  const meta = segments[1] === 'sa' && segments[2]
    ? (SA_PAGE_TITLES[segments[2]] || { title: 'Super Admin', desc: 'CEO Dashboard' })
    : (PAGE_META[path] || { title: 'Trackify', desc: 'Workforce Management Platform' });
  const rc = ROLE_CONFIG[role] || ROLE_CONFIG.contractor;
  const RoleIcon = rc.icon;

  useEffect(() => {
    function onClickOutside(e) {
      if (dropRef.current && !dropRef.current.contains(e.target)) setDropOpen(false);
    }
    document.addEventListener('mousedown', onClickOutside);
    return () => document.removeEventListener('mousedown', onClickOutside);
  }, []);

  const handleLogout = async () => {
    setDropOpen(false);
    try {
      await signOut(auth);
      toast.success('Signed out');
    } catch (_) {
      toast.error('Failed to sign out');
    }
  };

  const onContractorChange = (e) => {
    const id = e.target.value;
    const found = contractorsList.find((c) => c.id === id);
    switchContractor(id || null, found?.name ?? null);
  };

  return (
    <header className="sticky top-0 z-20 h-[64px] bg-bg-secondary border-b border-border flex items-center px-8">
      <div className="flex w-full items-center justify-between gap-6">

        {/* Left — Page title */}
        <div className="min-w-0 flex flex-col">
          <h1 className="text-[20px] font-medium text-text-primary leading-tight">{meta.title}</h1>
          <p className="text-[13px] text-text-muted leading-tight hidden sm:block mt-0.5">{meta.desc}</p>
        </div>

        {/* Center - Switcher */}
        <div className="flex-1 flex justify-center">
          {role === 'super_admin' && (
            <div className="relative">
              <select
                value={activeContractorId || ''}
                onChange={onContractorChange}
                className="appearance-none h-10 rounded-lg border border-border-strong bg-bg-input px-3.5 pr-10 text-[13px] font-medium text-text-primary outline-none transition-colors hover:border-border-gold focus:border-border-gold focus:ring-0"
              >
                <option value="">All contractors</option>
                {contractorsList.map((c) => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
              </select>
              <ChevronDown className="absolute right-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted pointer-events-none" />
            </div>
          )}
        </div>

        {/* Right */}
        <div className="flex items-center gap-4 shrink-0">

          {/* Notification bell */}
          <button className="relative flex h-[36px] w-[36px] items-center justify-center rounded-lg text-text-secondary transition hover:text-text-primary">
            <Bell className="h-5 w-5" />
            <span className="absolute right-[6px] top-[6px] h-2 w-2 rounded-full bg-gold shadow-[0_0_8px_rgba(245,166,35,0.6)] live-dot" />
          </button>

          {/* Profile dropdown */}
          <div className="relative" ref={dropRef}>
            <button
              onClick={() => setDropOpen((o) => !o)}
              className="flex items-center gap-2.5 rounded-xl border border-transparent px-1.5 py-1 transition-all hover:bg-bg-elevated"
            >
              <div className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full font-mono text-[14px] font-bold ${role === 'super_admin' ? 'bg-violet-500/10 border border-violet-500/20 text-violet-300' : 'bg-gold-bg border border-gold-border text-gold'}`}>
                {(name?.[0] || '?').toUpperCase()}
              </div>
              <div className="hidden md:flex flex-col items-start">
                <p className="text-[13px] font-medium text-text-primary leading-tight">{name || 'User'}</p>
                <p className="text-[11px] text-text-muted leading-tight uppercase tracking-wide mt-0.5">{role}</p>
              </div>
              <ChevronDown className={`h-3.5 w-3.5 text-text-muted transition-transform ${dropOpen ? 'rotate-180' : ''}`} />
            </button>

            {/* Dropdown panel */}
            <AnimatePresence>
              {dropOpen && (
                <motion.div
                  initial={{ opacity: 0, y: -10, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -10, scale: 0.95 }}
                  transition={{ duration: 0.15, ease: 'easeOut' }}
                  className="absolute right-0 top-full mt-2 w-64 rounded-xl border border-border-strong bg-bg-card shadow-[0_25px_60px_rgba(0,0,0,0.4)] overflow-hidden origin-top-right"
                >
                  {/* User info */}
                  <div className="px-5 py-4 border-b border-border">
                    <div className="flex items-center gap-3">
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gold-bg border border-gold-border font-mono text-[15px] font-bold text-gold">
                        {(name?.[0] || '?').toUpperCase()}
                      </div>
                      <div className="min-w-0">
                        <p className="truncate font-medium text-text-primary text-[14px]">{name || 'User'}</p>
                        <p className="truncate text-[11px] text-text-muted">{email || ''}</p>
                      </div>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="p-2">
                    <button
                      onClick={handleLogout}
                      className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-[13px] font-medium text-danger transition hover:bg-danger-bg"
                    >
                      <LogOut className="h-[18px] w-[18px]" />
                      Sign Out
                    </button>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>
      </div>
    </header>
  );
}
