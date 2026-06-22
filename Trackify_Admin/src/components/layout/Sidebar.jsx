import React from 'react';
import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard, Users as UsersIcon, HardHat, ClipboardList, Wallet,
  FileText, Users2, Calculator, UserCheck, ChevronLeft, Building2, Menu,
  Settings, LogOut, ChevronRight, Compass, Receipt, Palette, LifeBuoy,
  IndianRupee, TrendingUp, CreditCard, Activity, BarChart2, UserMinus,
  Sparkles, Zap, FlaskConical,
} from 'lucide-react';
import { useAuthStore } from '../../store/authStore';
import { useBranding } from '../../context/BrandingContext';

// ─── Super Admin Nav ──────────────────────────────────────────────────────────
const SA_GROUPS = [
  {
    label: 'REVENUE',
    links: [
      { to: '/sa/dashboard',    label: 'Revenue Dashboard', icon: IndianRupee },
      { to: '/sa/revenue',      label: 'Financials',        icon: TrendingUp },
      { to: '/sa/subscriptions',label: 'Subscriptions',     icon: CreditCard },
    ],
  },
  {
    label: 'CUSTOMERS',
    links: [
      { to: '/sa/customers',    label: 'Companies',         icon: Building2 },
      { to: '/sa/growth',       label: 'Growth',            icon: LayoutDashboard },
      { to: '/sa/churn',        label: 'Churn Analysis',    icon: UserMinus },
    ],
  },
  {
    label: 'ANALYTICS',
    links: [
      { to: '/sa/usage',        label: 'Usage Analytics',   icon: Activity },
      { to: '/sa/features',     label: 'Feature Analytics', icon: BarChart2 },
      { to: '/sa/insights',     label: 'AI Insights',       icon: Sparkles },
    ],
  },
  {
    label: 'OPERATIONS',
    links: [
      { to: '/sa/support',      label: 'Support Center',    icon: LifeBuoy },
      { to: '/sa/users',        label: 'User Management',   icon: UserCheck },
    ],
  },
  {
    label: 'INNOVATION',
    links: [
      { to: '/labs', label: 'Trackify Labs', icon: FlaskConical },
    ],
  },
];

// ─── Contractor / Supervisor Nav ──────────────────────────────────────────────
const CONTRACTOR_GROUPS = [
  {
    label: 'WORKFORCE',
    links: [
      { to: '/dashboard',    label: 'Dashboard',    icon: LayoutDashboard, roles: ['contractor', 'supervisor'] },
      { to: '/attendance',   label: 'Attendance',   icon: ClipboardList,   roles: ['contractor', 'supervisor'] },
      { to: '/labours',      label: 'Labours',      icon: HardHat,         roles: ['contractor', 'supervisor'] },
      { to: '/temp-labours', label: 'Temp Labours', icon: Users2,          roles: ['contractor', 'supervisor'] },
      { to: '/payroll',      label: 'Payroll',      icon: Calculator,      roles: ['contractor'] },
      { to: '/payments',     label: 'Payments',     icon: Wallet,          roles: ['contractor'] },
    ],
  },
  {
    label: 'OPERATIONS',
    links: [
      { to: '/sites',       label: 'Sites',    icon: Building2, roles: ['contractor', 'supervisor'] },
      { to: '/site-costs',  label: 'Site Costs', icon: Calculator, roles: ['contractor'] },
      { to: '/expenses',    label: 'Expenses', icon: Receipt,   roles: ['contractor'] },
      { to: '/support-requests', label: 'Support', icon: LifeBuoy, roles: ['contractor', 'supervisor'] },
    ],
  },
  {
    label: 'ANALYTICS',
    links: [
      { to: '/reports', label: 'Reports', icon: FileText, roles: ['contractor'] },
    ],
  },
  {
    label: 'ADMINISTRATION',
    links: [
      { to: '/supervisors', label: 'Supervisors', icon: UserCheck,  roles: ['contractor'] },
      { to: '/users',       label: 'Users',       icon: UsersIcon,  roles: ['contractor'] },
      { to: '/branding',    label: 'Branding',    icon: Palette,    roles: ['contractor'] },
      { to: '/settings',    label: 'Settings',    icon: Settings,   roles: ['contractor'] },
    ],
  },
];

function NavItem({ link, collapsed }) {
  return (
    <NavLink
      to={link.to}
      end
      title={collapsed ? link.label : undefined}
      className={({ isActive }) =>
        `nav-item relative flex items-center gap-2.5 h-10 rounded-lg mx-2 transition-all cursor-pointer ${
          collapsed ? 'justify-center px-0' : 'pl-4 pr-3'
        } ${
          isActive
            ? 'bg-violet-500/10 border border-violet-500/20 text-violet-300 font-medium'
            : 'text-text-secondary hover:bg-bg-elevated hover:text-text-primary'
        }`
      }
    >
      {({ isActive }) => (
        <>
          {isActive && !collapsed && (
            <div className="absolute -left-2 w-[3px] h-6 bg-violet-500 rounded-r-sm" />
          )}
          <link.icon
            className={`h-[18px] w-[18px] shrink-0 transition-colors ${
              isActive ? 'text-violet-400' : 'text-text-muted'
            }`}
          />
          {!collapsed && (
            <span className="flex-1 text-[14px] leading-none">{link.label}</span>
          )}
        </>
      )}
    </NavLink>
  );
}

// Contractor NavItem uses gold accent
function ContractorNavItem({ link, collapsed, role }) {
  if (!link.roles.includes(role)) return null;
  return (
    <NavLink
      to={link.to}
      end
      title={collapsed ? link.label : undefined}
      className={({ isActive }) =>
        `nav-item relative flex items-center gap-2.5 h-10 rounded-lg mx-2 transition-all cursor-pointer ${
          collapsed ? 'justify-center px-0' : 'pl-4 pr-3'
        } ${
          isActive
            ? 'bg-gold-bg border border-gold-border text-gold font-medium'
            : 'text-text-secondary hover:bg-bg-elevated hover:text-text-primary'
        }`
      }
    >
      {({ isActive }) => (
        <>
          {isActive && !collapsed && (
            <div className="absolute -left-2 w-[3px] h-6 bg-gold rounded-r-sm" />
          )}
          <link.icon
            className={`h-[18px] w-[18px] shrink-0 transition-colors ${
              isActive ? 'text-gold' : 'text-text-muted'
            }`}
          />
          {!collapsed && (
            <span className="flex-1 text-[14px] leading-none">{link.label}</span>
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
  const { branding } = useBranding();

  const isSuperAdmin = role === 'super_admin';
  const companyName  = activeContractorName || name || 'Trackify';
  const companyInitials = companyName.split(' ').slice(0, 2).map((w) => w[0]?.toUpperCase()).join('');

  return (
    <aside
      className={`fixed left-0 top-0 z-30 flex h-screen flex-col bg-bg-secondary border-r border-border transition-all duration-300 ${
        collapsed ? 'w-16' : 'w-[260px]'
      }`}
    >
      {/* Brand Area */}
      <div className={`flex items-center gap-3 shrink-0 border-b border-border h-[72px] ${collapsed ? 'px-3 justify-center' : 'px-5'}`}>
        {branding?.logoUrl ? (
          <img src={branding.logoUrl} alt={branding.companyName || 'Logo'} className="h-10 w-10 shrink-0 rounded-xl object-contain bg-white border border-border" />
        ) : (
          <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border shadow-[0_4px_16px_rgba(139,92,246,0.2)] ${isSuperAdmin ? 'bg-gradient-to-br from-violet-600 to-purple-700 border-violet-500/40' : 'bg-gradient-to-br from-bg-secondary to-bg-card border-gold/40 shadow-[0_4px_16px_rgba(245,166,35,0.15)]'}`}>
            {isSuperAdmin ? <Zap className="h-5 w-5 text-white" /> : <Compass className="h-5 w-5 text-gold" />}
          </div>
        )}
        {!collapsed && (
          <div className="flex flex-col flex-1 min-w-0">
            <span className="text-[14px] font-semibold text-text-primary tracking-wide truncate">
              {isSuperAdmin ? 'TRACKIFY ADMIN' : (branding?.companyName ? branding.companyName.toUpperCase() : 'TRACKIFY')}
            </span>
            <span className="text-[11px] text-text-muted mt-0.5 truncate">
              {isSuperAdmin ? 'CEO Dashboard' : (branding?.tagline || 'v2.0')}
            </span>
          </div>
        )}
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto py-2" style={{ scrollbarWidth: 'none' }}>
        {isSuperAdmin ? (
          SA_GROUPS.map((group) => (
            <div key={group.label} className="mb-2">
              {!collapsed && (
                <p className="px-5 pt-5 pb-2 text-[10px] font-medium tracking-[1.5px] uppercase text-text-muted">
                  {group.label}
                </p>
              )}
              <div className="space-y-0.5 mt-1">
                {group.links.map((link) => (
                  <NavItem key={link.to} link={link} collapsed={collapsed} />
                ))}
              </div>
            </div>
          ))
        ) : (
          CONTRACTOR_GROUPS.map((group) => {
            const visibleLinks = group.links.filter(l => l.roles.includes(role));
            if (visibleLinks.length === 0) return null;
            return (
              <div key={group.label} className="mb-2">
                {!collapsed && (
                  <p className="px-5 pt-5 pb-2 text-[10px] font-medium tracking-[1.5px] uppercase text-text-muted">
                    {group.label}
                  </p>
                )}
                <div className="space-y-0.5 mt-1">
                  {visibleLinks.map((link) => (
                    <ContractorNavItem key={link.to} link={link} collapsed={collapsed} role={role} />
                  ))}
                </div>
              </div>
            );
          })
        )}
      </nav>

      {/* Bottom */}
      {!collapsed && (
        <div className="p-4 border-t border-border">
          <div className="flex items-center gap-3 mb-3">
            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-bg-elevated text-text-primary text-xs border border-border-strong">
              {(name?.[0] || '?').toUpperCase()}
            </div>
            <div className="min-w-0 flex-1 flex flex-col">
              <span className="truncate text-[13px] font-medium text-text-primary">{name || '—'}</span>
              <span className="truncate text-[11px] text-text-muted">{role}</span>
            </div>
          </div>
          <div className="text-center">
            <span className="text-[10px] text-text-muted tracking-[1px] uppercase">TRACKIFY v2.0</span>
          </div>
        </div>
      )}

      {/* Collapse toggle */}
      <div className="px-3 pb-3 pt-1 border-t border-border">
        <button
          onClick={onToggle}
          title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          className="flex w-full items-center justify-center rounded-lg h-9 text-text-muted transition-all hover:bg-bg-elevated hover:text-text-primary"
        >
          {collapsed
            ? <ChevronRight className="h-[18px] w-[18px]" />
            : <span className="flex items-center gap-2 text-[12px] font-medium"><ChevronLeft className="h-[18px] w-[18px]" /> Collapse</span>
          }
        </button>
      </div>
    </aside>
  );
}
