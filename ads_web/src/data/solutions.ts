import { HardHat, Building, ClipboardCheck, User } from 'lucide-react';

export interface Persona {
  id: string;
  title: string;
  icon: typeof HardHat;
  scale: string;
  struggle: string;
  value: string;
}

export const personas: Persona[] = [
  {
    id: 'contractor',
    title: 'General Contractor',
    icon: HardHat,
    scale: '50–500 workers, 3–10 sites',
    struggle:
      'Sunday payroll takes 6 hours of manual calculations, cross-referencing paper registers, and arguing over advance deductions.',
    value:
      '1-click weekly payroll with auto-deductions, live headcount across every site by 9:30 AM, and branded pay slips ready for distribution.',
  },
  {
    id: 'builder',
    title: 'Residential Builder & Developer',
    icon: Building,
    scale: 'Multiple active projects with engineering teams',
    struggle:
      'Coordinating engineers, supervisors, and buyers across phases. No system to track drawings delivery or bill clients for site visits.',
    value:
      '23-drawing delivery tracking plus professional client billing statements so no visit goes unbilled and every blueprint is accounted for.',
  },
  {
    id: 'supervisor',
    title: 'Site Supervisor / Civil Engineer',
    icon: ClipboardCheck,
    scale: '20–80 workers per site daily',
    struggle:
      'Writing 40 names in a notebook every morning, tallying half-days manually, and logging advances on loose paper that goes missing.',
    value:
      'Mark attendance in 30 seconds with QR scan or 1-tap muster, log advances instantly, and never lose a single record again.',
  },
  {
    id: 'worker',
    title: 'Construction Worker',
    icon: User,
    scale: 'Individual daily-wage worker',
    struggle:
      'Unsure if the half-day was recorded. No way to verify advance balance. Disputes at settlement time with no proof.',
    value:
      'Login by phone number to see total days worked, advances taken, and exact net balance due. Full transparency, zero disputes.',
  },
];

