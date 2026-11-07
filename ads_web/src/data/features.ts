import {
  Scan,
  Calculator,
  Building2,
  FileText,
  Users,
  Wallet,
  BarChart3,
  Palette,
} from 'lucide-react';

export interface FeatureTab {
  id: string;
  title: string;
  tagline: string;
  points: string[];
  icon: typeof Scan;
}

export const featureTabs: FeatureTab[] = [
  {
    id: 'attendance',
    title: 'Smart Site Attendance',
    tagline: 'Scan or Tap. 50 Workers Marked in Under a Minute.',
    points: [
      'QR badge scanning with instant timestamp',
      '1-tap muster roll for rapid batch marking',
      'Fractional days: 0.25, 0.5, 0.75, 1.0, 1.5 overtime',
      'Offline caching — syncs automatically on reconnect',
    ],
    icon: Scan,
  },
  {
    id: 'payroll',
    title: 'Automated 1-Click Payroll',
    tagline: 'Zero Calculators. Zero Disputes. Instant Wage Settlement.',
    points: [
      'Auto wage calculation from daily rates',
      'Instant advance deduction per worker',
      'UPI / cash payment tracking',
      'Branded PDF pay slips for every worker',
    ],
    icon: Calculator,
  },
  {
    id: 'multisite',
    title: 'Multi-Site Operations Hub',
    tagline: 'Centralized Oversight Across Every Active Foundation.',
    points: [
      'Commercial, residential, and infrastructure sites at once',
      'Assign supervisors per site with role-based access',
      'Track site expenditure and cost burn in real-time',
      'Prevent unauthorized personnel on any site',
    ],
    icon: Building2,
  },
  {
    id: 'drawings',
    title: 'Architectural Drawings & Site Visits',
    tagline: 'From Foundation to Terrace: Track Every Blueprint.',
    points: [
      '23-plan scope tracker from foundation to elevation',
      'Site inspection logger with visit records',
      'Client invoice PDF generation',
      'WhatsApp sharing for instant client updates',
    ],
    icon: FileText,
  },
];

export interface CompactModule {
  title: string;
  description: string;
  icon: typeof Users;
}

export const compactModules: CompactModule[] = [
  {
    title: 'Workforce Registry & ID Badges',
    description: 'Digital worker profiles with printable QR badges',
    icon: Users,
  },
  {
    title: 'Cash Advances Ledger',
    description: 'Track every advance with auto payroll offset',
    icon: Wallet,
  },
  {
    title: 'Executive Reports',
    description: 'Muster roll CSV/Excel, cost burn, audit logs',
    icon: BarChart3,
  },
  {
    title: 'Whitelabel Branding',
    description: 'Custom company name, logo, and pay slip headers',
    icon: Palette,
  },
];

