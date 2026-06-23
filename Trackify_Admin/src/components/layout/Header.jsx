import React from 'react';
import { useLocation } from 'react-router-dom';
import { signOut } from 'firebase/auth';
import { LogOut, Bell } from 'lucide-react';
import toast from 'react-hot-toast';
import { auth } from '../../lib/firebase';
import { useAuthStore } from '../../store/authStore';
import { Button } from '../ui/button';

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

function getRoleLabel(role) {
  switch (role) {
    case 'super_admin': return 'Super Admin';
    case 'contractor':  return 'Contractor';
    case 'supervisor':  return 'Supervisor';
    default: return '';
  }
}

function getRoleBadgeClass(role) {
  switch (role) {
    case 'super_admin': return 'bg-purple-50 text-purple-700 border border-purple-200';
    case 'contractor':  return 'bg-blue-50 text-blue-700 border border-blue-200';
    case 'supervisor':  return 'bg-emerald-50 text-emerald-700 border border-emerald-200';
    default: return 'bg-slate-100 text-slate-600 border border-slate-200';
  }
}

export default function Header() {
  const location = useLocation();
  const role = useAuthStore((s) => s.role);
  const name = useAuthStore((s) => s.name);
  const activeContractorId   = useAuthStore((s) => s.activeContractorId);
  const activeContractorName = useAuthStore((s) => s.activeContractorName);
  const contractorsList = useAuthStore((s) => s.contractorsList);
  const switchContractor = useAuthStore((s) => s.switchContractor);

  const path = '/' + location.pathname.split('/')[1];
  const meta = PAGE_META[path] || { title: 'Trackify', desc: 'Workforce Management Platform' };

  const handleLogout = async () => {
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

  let contractorControl = null;
  if (role === 'super_admin') {
    contractorControl = (
      <div className="flex items-center gap-2">
        <label className="text-xs font-semibold uppercase tracking-wide text-slate-400">Contractor</label>
        <select
          value={activeContractorId || ''}
          onChange={onContractorChange}
          className="h-9 rounded-lg border border-slate-200 bg-white px-3 text-sm text-slate-900 shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
        >
          <option value="">All contractors</option>
          {contractorsList.map((c) => (
            <option key={c.id} value={c.id}>{c.name}</option>
          ))}
        </select>
      </div>
    );
  } else if (role === 'contractor' && activeContractorName) {
    contractorControl = (
      <div className="hidden sm:flex items-center gap-2 rounded-lg border border-blue-200 bg-blue-50 px-3 py-1.5 text-sm font-semibold text-blue-700">
        {activeContractorName}
      </div>
    );
  }

  return (
    <header
      className="sticky top-0 z-20 border-b border-slate-200/60 bg-white/90 backdrop-blur-xl"
      style={{ paddingLeft: '1.5rem', paddingRight: '1.5rem', paddingTop: '0.75rem', paddingBottom: '0.75rem' }}
    >
      <div className="flex items-center justify-between gap-6">
        {/* Left — Page title */}
        <div className="min-w-0">
          <h1 className="text-lg font-bold tracking-tight text-slate-900 leading-tight">{meta.title}</h1>
          <p className="text-xs text-slate-500 mt-0.5 hidden sm:block">{meta.desc}</p>
        </div>

        {/* Right — Actions */}
        <div className="flex items-center gap-2.5 shrink-0">
          {contractorControl}

          {role && (
            <span className={`hidden sm:inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${getRoleBadgeClass(role)}`}>
              {getRoleLabel(role)}
            </span>
          )}

          {name && (
            <div className="hidden md:flex items-center gap-2">
              <div className="flex h-8 w-8 items-center justify-center rounded-full bg-blue-600 text-xs font-bold text-white shadow-sm">
                {(name[0] || '?').toUpperCase()}
              </div>
              <span className="text-sm font-semibold text-slate-700">{name}</span>
            </div>
          )}

          <button
            className="relative flex h-9 w-9 items-center justify-center rounded-lg border border-slate-200 bg-white text-slate-500 shadow-sm transition hover:bg-slate-50 hover:text-slate-700"
            title="Notifications"
          >
            <Bell className="h-4 w-4" />
            <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-blue-600" />
          </button>

          <Button
            onClick={handleLogout}
            variant="outline"
            size="sm"
            className="gap-1.5 border-slate-200 bg-white text-slate-700 shadow-sm hover:bg-slate-50 hover:text-red-600"
          >
            <LogOut className="h-3.5 w-3.5" />
            <span className="hidden sm:inline">Logout</span>
          </Button>
        </div>
      </div>
    </header>
  );
}
