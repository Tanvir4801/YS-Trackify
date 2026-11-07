export interface WorkerRole {
  name: string;
  dailyRate: number;
}

export const workerRoles: WorkerRole[] = [
  { name: 'Mason', dailyRate: 900 },
  { name: 'Helper', dailyRate: 500 },
  { name: 'Carpenter', dailyRate: 800 },
  { name: 'Electrician', dailyRate: 850 },
  { name: 'Bar Bender', dailyRate: 750 },
  { name: 'Plumber', dailyRate: 800 },
  { name: 'Painter', dailyRate: 700 },
  { name: 'Tile Fitter', dailyRate: 850 },
];

export const trustBarItems = [
  {
    value: '100%',
    label: 'Offline-First',
    description: 'Works without internet in basements & remote sites',
  },
  {
    value: '0',
    label: 'Mathematical Errors',
    description: 'Automated payroll with advance tracking',
  },
  {
    value: '3s',
    label: 'Attendance',
    description: 'QR scan or 1-tap batch muster',
  },
  {
    value: 'Dual',
    label: 'Platform',
    description: 'Mobile for supervisors + Web for contractors',
  },
];

