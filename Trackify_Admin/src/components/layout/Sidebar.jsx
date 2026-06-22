import React from 'react';
import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard, Users as UsersIcon, HardHat, ClipboardList, Wallet,
  FileText, Users2, Calculator, UserCheck, Settings, ChevronLeft, ChevronRight,
  Building2,
} from 'lucide-react';
import { useAuthStore } from '../../store/authStore';

const ALL_LINKS = [
  { to: '/dashboard',   label: 'Dashboard',   icon: LayoutDashboard, roles: ['super_admin', 'contractor'] },
  { to: '/sites',       label: 'Sites',        icon: Building2,       roles: ['super_admin', 'contractor'] },
  { to: '/labours',     label: 'Labours',      icon: HardHat,         roles: ['super_admin', 'contractor'] },
  { to: '/attendance',  label: 'Attendance',   icon: ClipboardList,   roles: ['super_admin', 'contractor', 'supervisor'] },
  { to: '/payroll',     label: 'Payroll',      icon: Calculator,      roles: ['super_admin', 'contractor'] },
  { to: '/payments',    label: 'Payments',     icon: Wallet,          roles: ['super_admin', 'contractor'] },
  { to: '/reports',     label: 'Reports',      icon: FileText,        roles: ['super_admin', 'contractor'] },
  { to: '/supervisors', label: 'Supervisors',  icon: UserCheck,       roles: ['super_admin', 'contractor'] },
  { to: '/users',       label: 'Users',        icon: UsersIcon,       roles: ['super_admin', 'contractor'] },
  { to: '/settings',    label: 'Settings',     icon: Settings,        roles: ['super_admin', 'contractor'] },
];

const SUPERVISOR_LINKS = [
  { to: '/attendance', label: 'Attendance', icon: ClipboardList },
  { to: '/labours',    label: 'My Labours', icon: Users2 },
];

export default function Sidebar({ collapsed, onToggle }) {
  const role = useAuthStore((s) => s.role);
  const name = useAuthStore((s) => s.name);
  const email = useAuthStore((s) => s.email);

  const links =
    role === 'supervisor'
      ? SUPERVISOR_LINKS
      : ALL_LINKS.filter((l) => !role || l.roles.includes(role));

  return (
    <aside
      className={`fixed left-0 top-0 z-30 flex h-screen flex-col border-r border-white/60 bg-slate-950/95 text-white shadow-[12px_0_48px_rgba(15,23,42,0.18)] backdrop-blur-xl transition-all duration-200 ${
        collapsed ? 'w-16 px-2 py-5' : 'w-64 px-4 py-5'
      }`}
    >
      {!collapsed && (
        <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-4">
          <p className="text-xs font-semibold uppercase tracking-[0.24em] text-blue-300">Trackify</p>
          <div className="mt-2 text-lg font-semibold">Admin Panel</div>
          <p className="mt-1 text-sm leading-6 text-slate-300">Workforce workspace</p>
        </div>
      )}
      {collapsed && (
        <div className="mb-3 flex justify-center">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600 text-xs font-bold text-white">T</div>
        </div>
      )}

      <nav className="mt-4 flex-1 space-y-1 overflow-y-auto">
        {links.map((link) => (
          <NavLink
            key={link.to}
            to={link.to}
            end
            title={collapsed ? link.label : undefined}
            className={({ isActive }) =>
              `flex items-center gap-3 rounded-xl px-3 py-3 text-sm font-medium transition ${
                collapsed ? 'justify-center' : ''
              } ${
                isActive
                  ? 'bg-white text-slate-950 shadow-lg'
                  : 'text-slate-300 hover:bg-white/10 hover:text-white'
              }`
            }
          >
            <link.icon className="h-4 w-4 shrink-0" />
            {!collapsed && link.label}
          </NavLink>
        ))}
      </nav>

      {!collapsed && name && (
        <div className="mt-4 border-t border-white/10 pt-4">
          <div className="flex items-center gap-3 rounded-xl px-3 py-2">
            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-600 text-xs font-semibold">
              {(name[0] || '?').toUpperCase()}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-white">{name}</p>
              <p className="truncate text-xs text-slate-400">{email}</p>
            </div>
          </div>
        </div>
      )}

      <button
        onClick={onToggle}
        title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        className="mt-2 flex w-full items-center justify-center rounded-xl py-2 text-slate-400 transition hover:bg-white/10 hover:text-white"
      >
        {collapsed ? <ChevronRight className="h-4 w-4" /> : (
          <span className="flex items-center gap-2 text-xs">
            <ChevronLeft className="h-4 w-4" /> Collapse
          </span>
        )}
      </button>
    </aside>
  );
}
