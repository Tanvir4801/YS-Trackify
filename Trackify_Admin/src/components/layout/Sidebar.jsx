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

function getRoleBadgeColor(role) {
  switch (role) {
    case 'super_admin': return 'bg-purple-500/20 text-purple-300 border border-purple-500/30';
    case 'contractor':  return 'bg-blue-500/20 text-blue-300 border border-blue-500/30';
    case 'supervisor':  return 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30';
    default:            return 'bg-slate-700 text-slate-300';
  }
}

function getRoleLabel(role) {
  switch (role) {
    case 'super_admin': return 'Super Admin';
    case 'contractor':  return 'Contractor';
    case 'supervisor':  return 'Supervisor';
    default:            return role || '';
  }
}

export default function Sidebar({ collapsed, onToggle }) {
  const role  = useAuthStore((s) => s.role);
  const name  = useAuthStore((s) => s.name);
  const email = useAuthStore((s) => s.email);

  const isSupervisor = role === 'supervisor';

  return (
    <aside
      className={`fixed left-0 top-0 z-30 flex h-screen flex-col text-white shadow-2xl transition-all duration-300 ${
        collapsed ? 'w-16' : 'w-64'
      }`}
      style={{ background: 'linear-gradient(180deg, #0B1020 0%, #0d1526 100%)', borderRight: '1px solid rgba(255,255,255,0.06)' }}
    >
      {/* Brand Header */}
      <div className={`flex-shrink-0 ${collapsed ? 'px-3 py-5' : 'px-5 py-5'}`}>
        {collapsed ? (
          <div className="flex justify-center">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-blue-600 shadow-lg shadow-blue-600/30">
              <Zap className="h-4 w-4 text-white" />
            </div>
          </div>
        ) : (
          <div>
            <div className="flex items-center gap-2.5">
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-blue-600 shadow-lg shadow-blue-600/30">
                <Zap className="h-4 w-4 text-white" />
              </div>
              <div>
                <p className="text-sm font-bold tracking-widest text-white uppercase" style={{ letterSpacing: '0.15em' }}>TRACKIFY</p>
                <p className="text-[10px] text-slate-400 font-medium" style={{ letterSpacing: '0.05em' }}>Workforce Management</p>
              </div>
            </div>
            {role && (
              <div className="mt-3">
                <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wider ${getRoleBadgeColor(role)}`}>
                  {getRoleLabel(role)}
                </span>
              </div>
            )}
          </div>
        )}
      </div>

      <div className="mx-3 h-px bg-white/5" />

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto py-3" style={{ scrollbarWidth: 'none' }}>
        {isSupervisor ? (
          <div className={`px-2 space-y-0.5`}>
            {SUPERVISOR_LINKS.map((link) => (
              <NavLink
                key={link.to}
                to={link.to}
                end
                title={collapsed ? link.label : undefined}
                className={({ isActive }) =>
                  `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-all duration-150 ${
                    collapsed ? 'justify-center px-0' : ''
                  } ${
                    isActive
                      ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/25'
                      : 'text-slate-400 hover:bg-white/6 hover:text-white'
                  }`
                }
              >
                <link.icon className="h-4 w-4 shrink-0" />
                {!collapsed && <span>{link.label}</span>}
              </NavLink>
            ))}
          </div>
        ) : (
          GROUPS.map((group) => {
            const visibleLinks = group.links.filter((l) => !role || l.roles.includes(role));
            if (visibleLinks.length === 0) return null;
            return (
              <div key={group.label} className="mb-2">
                {!collapsed && (
                  <p className="px-5 pb-1 pt-3 text-[10px] font-bold tracking-widest text-slate-600">{group.label}</p>
                )}
                <div className="px-2 space-y-0.5">
                  {visibleLinks.map((link) => (
                    <NavLink
                      key={link.to}
                      to={link.to}
                      end
                      title={collapsed ? link.label : undefined}
                      className={({ isActive }) =>
                        `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-all duration-150 ${
                          collapsed ? 'justify-center px-0' : ''
                        } ${
                          isActive
                            ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/25'
                            : 'text-slate-400 hover:bg-white/6 hover:text-white'
                        }`
                      }
                    >
                      {({ isActive }) => (
                        <>
                          <link.icon className={`h-4 w-4 shrink-0 ${isActive ? 'text-white' : 'text-slate-500'}`} />
                          {!collapsed && <span>{link.label}</span>}
                          {!collapsed && isActive && (
                            <span className="ml-auto h-1.5 w-1.5 rounded-full bg-white/60" />
                          )}
                        </>
                      )}
                    </NavLink>
                  ))}
                </div>
              </div>
            );
          })
        )}
      </nav>

      <div className="mx-3 h-px bg-white/5" />

      {/* Profile footer */}
      {!collapsed && name && (
        <div className="px-4 py-3">
          <div className="flex items-center gap-3 rounded-xl bg-white/4 px-3 py-2.5" style={{ background: 'rgba(255,255,255,0.04)' }}>
            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-600 text-xs font-bold text-white shadow">
              {(name[0] || '?').toUpperCase()}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold text-white">{name}</p>
              <p className="truncate text-xs text-slate-500">{email}</p>
            </div>
          </div>
          <p className="mt-2.5 text-center text-[10px] text-slate-600">Developed by Tanvir Patel</p>
        </div>
      )}

      {/* Collapse toggle */}
      <div className="px-3 pb-4">
        <button
          onClick={onToggle}
          title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          className="flex w-full items-center justify-center rounded-xl py-2.5 text-slate-500 transition-all hover:bg-white/6 hover:text-slate-300"
          style={{ background: 'transparent' }}
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
