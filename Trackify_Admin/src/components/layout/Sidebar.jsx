import React from 'react';
import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard, Users as UsersIcon, HardHat, ClipboardList, Wallet,
  FileText, Users2, Calculator, UserCheck, Settings, ChevronLeft, ChevronRight,
  Building2, Receipt, Zap,
} from 'lucide-react';
import { useAuthStore } from '../../store/authStore';

const GROUPS = [
  {
    label: 'WORKFORCE',
    links: [
      { to: '/dashboard',  label: 'Dashboard',  icon: LayoutDashboard, roles: ['super_admin', 'contractor'] },
      { to: '/attendance', label: 'Attendance',  icon: ClipboardList,   roles: ['super_admin', 'contractor', 'supervisor'] },
      { to: '/labours',    label: 'Labours',     icon: HardHat,         roles: ['super_admin', 'contractor', 'supervisor'] },
      { to: '/payroll',    label: 'Payroll',     icon: Calculator,      roles: ['super_admin', 'contractor'] },
      { to: '/payments',   label: 'Payments',    icon: Wallet,          roles: ['super_admin', 'contractor'] },
    ],
  },
  {
    label: 'OPERATIONS',
    links: [
      { to: '/sites',    label: 'Sites',    icon: Building2, roles: ['super_admin', 'contractor'] },
      { to: '/expenses', label: 'Expenses', icon: Receipt,   roles: ['super_admin', 'contractor'] },
    ],
  },
  {
    label: 'ANALYTICS',
    links: [
      { to: '/reports', label: 'Reports', icon: FileText, roles: ['super_admin', 'contractor'] },
    ],
  },
  {
    label: 'ADMINISTRATION',
    links: [
      { to: '/supervisors', label: 'Supervisors', icon: UserCheck,  roles: ['super_admin', 'contractor'] },
      { to: '/users',       label: 'Users',       icon: UsersIcon,  roles: ['super_admin', 'contractor'] },
      { to: '/settings',    label: 'Settings',    icon: Settings,   roles: ['super_admin', 'contractor'] },
    ],
  },
];

const SUPERVISOR_LINKS = [
  { to: '/attendance', label: 'Attendance', icon: ClipboardList },
  { to: '/labours',    label: 'My Labours', icon: Users2 },
];

const ROLE_COLOR = {
  super_admin: { bg: 'rgba(124,58,237,0.15)', text: '#C4B5FD', border: 'rgba(124,58,237,0.25)', label: 'Super Admin' },
  contractor:  { bg: 'rgba(37,99,235,0.15)',  text: '#93C5FD', border: 'rgba(37,99,235,0.25)',  label: 'Contractor'  },
  supervisor:  { bg: 'rgba(5,150,105,0.15)',  text: '#6EE7B7', border: 'rgba(5,150,105,0.25)',  label: 'Supervisor'  },
};

function NavItem({ link, collapsed }) {
  return (
    <NavLink
      to={link.to}
      end
      title={collapsed ? link.label : undefined}
      className={({ isActive }) =>
        `group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-all duration-150 ${
          collapsed ? 'justify-center' : ''
        } ${
          isActive
            ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/30'
            : 'text-slate-400 hover:bg-white/8 hover:text-white'
        }`
      }
      style={({ isActive }) => isActive ? { boxShadow: '0 4px 14px rgba(37,99,235,0.35)' } : {}}
    >
      {({ isActive }) => (
        <>
          <link.icon
            className={`h-4 w-4 shrink-0 transition-transform duration-150 group-hover:scale-110 ${
              isActive ? 'text-white' : 'text-slate-500 group-hover:text-white'
            }`}
          />
          {!collapsed && (
            <>
              <span className="flex-1">{link.label}</span>
              {isActive && <span className="h-1.5 w-1.5 rounded-full bg-white/70" />}
            </>
          )}
        </>
      )}
    </NavLink>
  );
}

export default function Sidebar({ collapsed, onToggle }) {
  const role  = useAuthStore((s) => s.role);
  const name  = useAuthStore((s) => s.name);
  const email = useAuthStore((s) => s.email);
  const activeContractorName = useAuthStore((s) => s.activeContractorName);

  const isSupervisor = role === 'supervisor';
  const rc = ROLE_COLOR[role] || ROLE_COLOR.contractor;

  const companyName = activeContractorName || name || 'Trackify';
  const companyInitials = companyName.split(' ').slice(0, 2).map((w) => w[0]?.toUpperCase()).join('');

  return (
    <aside
      className={`fixed left-0 top-0 z-30 flex h-screen flex-col text-white shadow-2xl transition-all duration-300 ${
        collapsed ? 'w-16' : 'w-64'
      }`}
      style={{ background: 'linear-gradient(180deg, #0B1020 0%, #0d1526 100%)', borderRight: '1px solid rgba(255,255,255,0.06)' }}
    >
      {/* Brand */}
      <div className={`flex-shrink-0 ${collapsed ? 'px-3 py-4' : 'px-4 py-4'}`}>
        {collapsed ? (
          <div className="flex justify-center">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-blue-600 shadow-lg shadow-blue-600/30">
              <Zap className="h-4 w-4 text-white" />
            </div>
          </div>
        ) : (
          <div className="space-y-3">
            {/* App brand */}
            <div className="flex items-center gap-2.5">
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-blue-600 shadow-lg shadow-blue-600/30">
                <Zap className="h-4 w-4 text-white" />
              </div>
              <div>
                <p className="text-sm font-bold tracking-widest text-white uppercase" style={{ letterSpacing: '0.15em' }}>TRACKIFY</p>
                <p className="text-[10px] text-slate-500" style={{ letterSpacing: '0.04em' }}>Workforce Management</p>
              </div>
            </div>

            {/* Company chip */}
            <div className="flex items-center gap-2 rounded-xl px-2.5 py-2" style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.07)' }}>
              <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg text-[10px] font-bold text-white" style={{ background: 'linear-gradient(135deg,#2563EB,#7C3AED)' }}>
                {companyInitials}
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-xs font-semibold text-white/90">{companyName}</p>
                <span
                  className="inline-block rounded-full px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider"
                  style={{ background: rc.bg, color: rc.text, border: `1px solid ${rc.border}` }}
                >
                  {rc.label}
                </span>
              </div>
            </div>
          </div>
        )}
      </div>

      <div className="mx-3 h-px" style={{ background: 'rgba(255,255,255,0.05)' }} />

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto py-2" style={{ scrollbarWidth: 'none' }}>
        {isSupervisor ? (
          <div className="px-2 space-y-0.5">
            {SUPERVISOR_LINKS.map((link) => (
              <NavItem key={link.to} link={link} collapsed={collapsed} />
            ))}
          </div>
        ) : (
          GROUPS.map((group) => {
            const visibleLinks = group.links.filter((l) => !role || l.roles.includes(role));
            if (visibleLinks.length === 0) return null;
            return (
              <div key={group.label} className="mb-1">
                {!collapsed && (
                  <p className="px-5 pb-1 pt-3 text-[10px] font-bold tracking-widest text-slate-600">{group.label}</p>
                )}
                <div className="px-2 space-y-0.5">
                  {visibleLinks.map((link) => (
                    <NavItem key={link.to} link={link} collapsed={collapsed} />
                  ))}
                </div>
              </div>
            );
          })
        )}
      </nav>

      <div className="mx-3 h-px" style={{ background: 'rgba(255,255,255,0.05)' }} />

      {/* Footer */}
      {!collapsed && (
        <div className="px-4 py-3">
          <div className="flex items-center gap-3 rounded-xl px-3 py-2.5" style={{ background: 'rgba(255,255,255,0.04)' }}>
            <div
              className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold text-white shadow"
              style={{ background: 'linear-gradient(135deg,#2563EB,#7C3AED)' }}
            >
              {(name?.[0] || '?').toUpperCase()}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-xs font-semibold text-white/90">{name || '—'}</p>
              <p className="truncate text-[10px] text-slate-500">{email || ''}</p>
            </div>
          </div>
          <div className="mt-2.5 text-center">
            <p className="text-[10px] font-bold text-slate-500 tracking-wider">TRACKIFY v2.0</p>
            <p className="text-[9px] text-slate-700 mt-0.5">Workforce Management Platform</p>
          </div>
        </div>
      )}

      {/* Collapse toggle */}
      <div className="px-3 pb-3">
        <button
          onClick={onToggle}
          title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          className="flex w-full items-center justify-center rounded-xl py-2 text-slate-600 transition-all hover:bg-white/6 hover:text-slate-300"
        >
          {collapsed
            ? <ChevronRight className="h-4 w-4" />
            : <span className="flex items-center gap-2 text-xs font-medium"><ChevronLeft className="h-4 w-4" /> Collapse</span>
          }
        </button>
      </div>
    </aside>
  );
}
