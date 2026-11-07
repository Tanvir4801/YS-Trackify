import { Building2, Users, ClipboardCheck, FileText } from 'lucide-react';

export interface HowItWorksStep {
  step: number;
  title: string;
  description: string;
  icon: typeof Building2;
}

export const howItWorksSteps: HowItWorksStep[] = [
  {
    step: 1,
    title: 'Set Up Sites & Roles',
    description:
      'Add your company, create projects like "Greenfield Villa #345", define worker roles and daily rates, and invite site supervisors.',
    icon: Building2,
  },
  {
    step: 2,
    title: 'Register Your Workforce',
    description:
      'Add masons, helpers, and technicians with their daily wage rates. Print unique QR badges for instant identification.',
    icon: Users,
  },
  {
    step: 3,
    title: 'Record Daily Attendance',
    description:
      'Scan QR badges or use 1-tap muster roll. Works even offline — records sync automatically when connectivity returns.',
    icon: ClipboardCheck,
  },
  {
    step: 4,
    title: 'Settle Wages & Export Reports',
    description:
      'Run weekly payroll with advances auto-deducted. Generate branded pay slips and government-format muster roll sheets.',
    icon: FileText,
  },
];

