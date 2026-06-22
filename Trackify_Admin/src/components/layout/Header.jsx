import React from 'react';
import { signOut } from 'firebase/auth';
import { LogOut } from 'lucide-react';
import toast from 'react-hot-toast';
import { auth } from '../../lib/firebase';
import { useAuthStore } from '../../store/authStore';
import { Button } from '../ui/button';
import GlobalSearch from '../shared/GlobalSearch';

function getRoleLabel(role) {
  switch (role) {
    case 'super_admin': return 'Super Admin';
    case 'contractor': return 'Contractor';
    case 'supervisor': return 'Supervisor';
    default: return '';
  }
}

function getRoleBadgeClass(role) {
  switch (role) {
    case 'super_admin': return 'bg-purple-100 text-purple-700';
    case 'contractor': return 'bg-blue-100 text-blue-700';
    case 'supervisor': return 'bg-slate-100 text-slate-700';
    default: return 'bg-slate-100 text-slate-600';
  }
}

export default function Header() {
  const role = useAuthStore((s) => s.role);
  const name = useAuthStore((s) => s.name);
  const email = useAuthStore((s) => s.email);
  const activeContractorId = useAuthStore((s) => s.activeContractorId);
  const activeContractorName = useAuthStore((s) => s.activeContractorName);
  const contractorsList = useAuthStore((s) => s.contractorsList);
  const switchContractor = useAuthStore((s) => s.switchContractor);

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

  let middle = null;
  if (role === 'super_admin') {
    middle = (
      <div className="flex items-center gap-2">
        <label className="text-xs font-semibold uppercase tracking-wide text-slate-500">
          Contractor
        </label>
        <select
          value={activeContractorId || ''}
          onChange={onContractorChange}
          className="h-9 rounded-md border border-slate-300 bg-white px-3 text-sm text-slate-900 shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
        >
          <option value="">All contractors</option>
          {contractorsList.map((c) => (
            <option key={c.id} value={c.id}>{c.name}</option>
          ))}
        </select>
      </div>
    );
  } else if (role === 'contractor') {
    middle = (
      <div className="flex items-center gap-2 rounded-full border border-blue-200 bg-blue-50 px-3 py-1.5 text-sm font-semibold text-blue-700">
        {activeContractorName || '—'}
      </div>
    );
  } else if (role === 'supervisor') {
    middle = (
      <div className="flex items-center gap-2 rounded-full border border-slate-200 bg-white px-3 py-1.5 text-sm font-semibold text-slate-700">
        {name || email || 'Supervisor'}
      </div>
    );
  }

  return (
    <header className="sticky top-0 z-20 border-b border-white/60 bg-white/80 px-6 py-3 backdrop-blur-xl lg:px-8">
      <div className="mx-auto flex max-w-7xl items-center justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.24em] text-blue-600">Trackify Admin</p>
          <h1 className="mt-0.5 text-lg font-semibold tracking-tight text-slate-950">
            {role === 'supervisor'
              ? 'Field Operations'
              : activeContractorName || (role === 'super_admin' ? 'All Contractors' : 'Operations Console')}
          </h1>
        </div>

        <div className="flex items-center gap-3">
          <GlobalSearch />
          {middle}
          {role ? (
            <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${getRoleBadgeClass(role)}`}>
              {getRoleLabel(role)}
            </span>
          ) : null}
          {name && (
            <span className="hidden text-sm font-medium text-slate-700 sm:inline">{name}</span>
          )}
          <Button
            onClick={handleLogout}
            variant="outline"
            className="gap-2 border-slate-200 bg-white/90 text-slate-700 shadow-sm hover:bg-slate-50"
          >
            <LogOut className="h-4 w-4" />
            Logout
          </Button>
        </div>
      </div>
    </header>
  );
}
