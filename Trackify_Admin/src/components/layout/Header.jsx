import React, { useState, useRef, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { signOut } from 'firebase/auth';
import { Bell, ChevronDown, LogOut, User, Shield } from 'lucide-react';
import toast from 'react-hot-toast';
import { auth } from '../../lib/firebase';
import { useAuthStore } from '../../store/authStore';

const PAGE_META = {
  '/dashboard':   { title: 'Dashboard',   desc: 'Manage workforce activities and attendance' },
  '/attendance':  { title: 'Attendance',  desc: 'Mark and track daily attendance records' },
  '/labours':     { title: 'Labours',     desc: 'Manage your workforce and labour profiles' },
  '/payroll':     { title: 'Payroll',     desc: 'Calculate monthly salary and mark payments' },
  '/payments':    { title: 'Payments',    desc: 'Track advances and salary disbursements' },
  '/reports':     { title: 'Reports',     desc: 'Generate and export detailed workforce reports' },
  '/sites':       { title: 'Sites',       desc: 'Manage work sites and daily attendance' },
  '/expenses':    { title: 'Expenses',    desc: 'Track and manage project expenses' },
  '/supervisors': { title: 'Supervisors', desc: 'Monitor supervisor performance and teams' },
  '/users':       { title: 'Users',       desc: 'Manage contractors, supervisors and access' },
  '/settings':    { title: 'Settings',    desc: 'Configure your workspace preferences' },
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

  const path = '/' + location.pathname.split('/')[1];
  const meta = PAGE_META[path] || { title: 'Trackify', desc: 'Workforce Management Platform' };
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
    <header className="sticky top-0 z-20 border-b border-slate-200/60 bg-white/95 backdrop-blur-xl">
      <div className="flex h-14 items-center justify-between gap-6 px-6">

        {/* Left — Page title */}
        <div className="min-w-0 flex items-center gap-3">
          <div>
            <h1 className="text-base font-bold tracking-tight text-slate-900 leading-tight">{meta.title}</h1>
            <p className="text-[11px] text-slate-400 leading-tight hidden sm:block">{meta.desc}</p>
          </div>
        </div>

        {/* Right */}
        <div className="flex items-center gap-2 shrink-0">

          {/* Contractor switcher (super_admin only) */}
          {role === 'super_admin' && (
            <select
              value={activeContractorId || ''}
              onChange={onContractorChange}
              className="hidden md:block h-8 rounded-lg border border-slate-200 bg-slate-50 px-2.5 text-xs text-slate-700 outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-400/20"
            >
              <option value="">All contractors</option>
              {contractorsList.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          )}

          {/* Contractor chip (contractor role) */}
          {role === 'contractor' && activeContractorName && (
            <div className="hidden sm:flex items-center gap-1.5 rounded-lg border bg-blue-50 border-blue-200 px-2.5 py-1 text-xs font-semibold text-blue-700">
              <div className="h-4 w-4 rounded-sm flex items-center justify-center text-[9px] font-bold bg-blue-600 text-white">
                {activeContractorName[0]?.toUpperCase()}
              </div>
              {activeContractorName}
            </div>
          )}

          {/* Notification bell */}
          <button className="relative flex h-8 w-8 items-center justify-center rounded-lg text-slate-400 transition hover:bg-slate-100 hover:text-slate-700">
            <Bell className="h-4 w-4" />
            <span className="absolute right-1.5 top-1.5 h-1.5 w-1.5 rounded-full bg-blue-500" />
          </button>

          {/* Profile dropdown */}
          <div className="relative" ref={dropRef}>
            <button
              onClick={() => setDropOpen((o) => !o)}
              className="flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-2.5 py-1.5 shadow-sm transition hover:bg-slate-50 hover:border-slate-300"
            >
              <div
                className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-bold text-white shadow-sm"
                style={{ background: rc.color }}
              >
                {(name?.[0] || '?').toUpperCase()}
              </div>
              <div className="hidden md:block text-left">
                <p className="text-xs font-semibold text-slate-800 leading-tight">{name || 'User'}</p>
                <p className="text-[10px] text-slate-400 leading-tight">{rc.label}</p>
              </div>
              <ChevronDown className={`h-3.5 w-3.5 text-slate-400 transition-transform ${dropOpen ? 'rotate-180' : ''}`} />
            </button>

            {/* Dropdown panel */}
            {dropOpen && (
              <div className="absolute right-0 top-full mt-2 w-64 rounded-2xl border border-slate-200 bg-white shadow-xl shadow-slate-900/10 overflow-hidden">
                {/* User info */}
                <div className="px-4 py-3.5 border-b border-slate-100">
                  <div className="flex items-center gap-3">
                    <div
                      className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-sm font-bold text-white shadow"
                      style={{ background: rc.color }}
                    >
                      {(name?.[0] || '?').toUpperCase()}
                    </div>
                    <div className="min-w-0">
                      <p className="truncate font-semibold text-slate-900 text-sm">{name || 'User'}</p>
                      <p className="truncate text-xs text-slate-400">{email || ''}</p>
                    </div>
                  </div>
                  <div className="mt-2.5">
                    <span
                      className="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-semibold"
                      style={{ background: rc.bg, color: rc.color, border: `1px solid ${rc.border}` }}
                    >
                      <RoleIcon className="h-3 w-3" />
                      {rc.label}
                    </span>
                  </div>
                </div>

                {/* Actions */}
                <div className="p-1.5">
                  <button
                    onClick={handleLogout}
                    className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-sm text-red-600 transition hover:bg-red-50"
                  >
                    <LogOut className="h-4 w-4" />
                    Sign Out
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}
