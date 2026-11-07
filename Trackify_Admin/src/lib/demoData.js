/**
 * Complete, Deterministic Mock Data for XYZ Construction Demo Environment.
 * Uses completely anonymized entities (Person A...Z, Site A...C, Supervisor A...C).
 */

export const DEMO_COMPANY_NAME = 'XYZ Construction';

export const DEMO_SITES = [
  {
    id: 'site_a',
    name: 'Site A - Commercial Complex',
    description: '14-Storey Commercial & IT Tower with Basement Parking',
    location: 'Sector 42, North Corridor',
    contractorId: 'trackify_demo',
    isActive: true,
    labourCount: 12,
    supervisorId: 'sup_a',
    supervisorName: 'Supervisor A',
    budget: 45000000,
    spent: 18500000,
    defaultAllowances: { petrol: 100, lunch: 80, breakfast: 40, tea: 20 },
  },
  {
    id: 'site_b',
    name: 'Site B - High-Rise Towers',
    description: 'Twin Luxury Residential Towers (24 Floors each)',
    location: 'Phase 2, Skyline Boulevard',
    contractorId: 'trackify_demo',
    isActive: true,
    labourCount: 10,
    supervisorId: 'sup_b',
    supervisorName: 'Supervisor B',
    budget: 85000000,
    spent: 42000000,
    defaultAllowances: { petrol: 120, lunch: 90, breakfast: 40, tea: 20 },
  },
  {
    id: 'site_c',
    name: 'Site C - Metro Corridor',
    description: 'Elevated Metro Viaduct & Station Concourse Project',
    location: 'Outer Ring Express Junction',
    contractorId: 'trackify_demo',
    isActive: true,
    labourCount: 6,
    supervisorId: 'sup_c',
    supervisorName: 'Supervisor C',
    budget: 62000000,
    spent: 29000000,
    defaultAllowances: { petrol: 150, lunch: 100, breakfast: 50, tea: 25 },
  },
];

export const DEMO_SUPERVISORS = [
  {
    id: 'sup_a',
    name: 'Supervisor A',
    phone: '+91 98765 00001',
    email: 'supervisor.a@xyz.com',
    role: 'supervisor',
    contractorId: 'trackify_demo',
    siteName: 'Site A - Commercial Complex',
  },
  {
    id: 'sup_b',
    name: 'Supervisor B',
    phone: '+91 98765 00002',
    email: 'supervisor.b@xyz.com',
    role: 'supervisor',
    contractorId: 'trackify_demo',
    siteName: 'Site B - High-Rise Towers',
  },
  {
    id: 'sup_c',
    name: 'Supervisor C',
    phone: '+91 98765 00003',
    email: 'supervisor.c@xyz.com',
    role: 'supervisor',
    contractorId: 'trackify_demo',
    siteName: 'Site C - Metro Corridor',
  },
];

const ROLES_SPEC = [
  { letter: 'A', role: 'Mason Lead', dailyWage: 850, siteId: 'site_a', supervisorId: 'sup_a', advance: 1500 },
  { letter: 'B', role: 'Bar Bender Senior', dailyWage: 800, siteId: 'site_a', supervisorId: 'sup_a', advance: 2000 },
  { letter: 'C', role: 'Carpenter Head', dailyWage: 780, siteId: 'site_a', supervisorId: 'sup_a', advance: 1200 },
  { letter: 'D', role: 'Electrician Tech', dailyWage: 750, siteId: 'site_a', supervisorId: 'sup_a', advance: 800 },
  { letter: 'E', role: 'Plumbing Specialist', dailyWage: 750, siteId: 'site_a', supervisorId: 'sup_a', advance: 500 },
  { letter: 'F', role: 'Structural Welder', dailyWage: 720, siteId: 'site_a', supervisorId: 'sup_a', advance: 0 },
  { letter: 'G', role: 'Tile & Marble Master', dailyWage: 800, siteId: 'site_b', supervisorId: 'sup_b', advance: 2500 },
  { letter: 'H', role: 'Scaffolding Expert', dailyWage: 680, siteId: 'site_b', supervisorId: 'sup_b', advance: 1000 },
  { letter: 'I', role: 'Mason Grade I', dailyWage: 700, siteId: 'site_b', supervisorId: 'sup_b', advance: 3000 },
  { letter: 'J', role: 'Concrete Finisher', dailyWage: 650, siteId: 'site_b', supervisorId: 'sup_b', advance: 500 },
  { letter: 'K', role: 'Painter Foreman', dailyWage: 650, siteId: 'site_b', supervisorId: 'sup_b', advance: 1200 },
  { letter: 'L', role: 'Steel Binder', dailyWage: 620, siteId: 'site_b', supervisorId: 'sup_b', advance: 0 },
  { letter: 'M', role: 'Excavation Operator', dailyWage: 850, siteId: 'site_c', supervisorId: 'sup_c', advance: 2000 },
  { letter: 'N', role: 'Survey Assistant', dailyWage: 700, siteId: 'site_c', supervisorId: 'sup_c', advance: 800 },
  { letter: 'O', role: 'Safety Marshal', dailyWage: 750, siteId: 'site_c', supervisorId: 'sup_c', advance: 0 },
  { letter: 'P', role: 'Skilled Helper', dailyWage: 520, siteId: 'site_a', supervisorId: 'sup_a', advance: 500 },
  { letter: 'Q', role: 'Civil Helper', dailyWage: 500, siteId: 'site_a', supervisorId: 'sup_a', advance: 800 },
  { letter: 'R', role: 'Material Handler', dailyWage: 480, siteId: 'site_a', supervisorId: 'sup_a', advance: 1000 },
  { letter: 'S', role: 'Mason Assistant', dailyWage: 550, siteId: 'site_a', supervisorId: 'sup_a', advance: 600 },
  { letter: 'T', role: 'Shuttering Helper', dailyWage: 500, siteId: 'site_a', supervisorId: 'sup_a', advance: 0 },
  { letter: 'U', role: 'Site Cleaner & Helper', dailyWage: 450, siteId: 'site_a', supervisorId: 'sup_a', advance: 400 },
  { letter: 'V', role: 'Concrete Helper', dailyWage: 480, siteId: 'site_b', supervisorId: 'sup_b', advance: 700 },
  { letter: 'W', role: 'Electrical Helper', dailyWage: 500, siteId: 'site_b', supervisorId: 'sup_b', advance: 900 },
  { letter: 'X', role: 'Steel Carrier', dailyWage: 480, siteId: 'site_b', supervisorId: 'sup_b', advance: 0 },
  { letter: 'Y', role: 'Drainage Helper', dailyWage: 460, siteId: 'site_b', supervisorId: 'sup_b', advance: 500 },
  { letter: 'Z', role: 'Heavy Rigging Helper', dailyWage: 520, siteId: 'site_c', supervisorId: 'sup_c', advance: 1100 },
];

export const DEMO_LABOURS = ROLES_SPEC.map((spec, index) => {
  const pad = (index + 1).toString().padStart(2, '0');
  const site = DEMO_SITES.find((s) => s.id === spec.siteId);
  return {
    id: `labour_${spec.letter.toLowerCase()}`,
    name: `Person ${spec.letter}`,
    phone: `+91 98765 000${pad}`,
    role: spec.role,
    trade: spec.role,
    dailyWage: spec.dailyWage,
    dailyRate: spec.dailyWage,
    overtimeWagePerHour: Math.round(spec.dailyWage / 8 * 1.5),
    defaultOvertimeHours: index % 3 === 0 ? 2 : 0,
    siteId: spec.siteId,
    siteName: site?.name || 'Site A - Commercial Complex',
    supervisorId: spec.supervisorId,
    contractorId: 'trackify_demo',
    isActive: true,
    advanceBalance: spec.advance,
    joiningDate: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000),
    type: 'regular',
    attendanceRate: 90 + (index % 10),
  };
});

export const DEMO_ATTENDANCE = DEMO_LABOURS.map((labour, index) => {
  const statuses = ['P', 'P', 'P', 'P', 'HD', 'P', 'P'];
  const status = index === 8 ? 'A' : statuses[index % statuses.length];
  return {
    id: `att_${labour.id}`,
    labourId: labour.id,
    labourName: labour.name,
    role: labour.role,
    contractorId: 'trackify_demo',
    siteId: labour.siteId,
    siteName: labour.siteName,
    supervisorId: labour.supervisorId,
    date: new Date().toISOString().split('T')[0],
    status,
    present: status === 'P' ? 1 : status === 'HD' ? 0.5 : 0,
    overtimeHours: status === 'P' && index % 2 === 0 ? 2 : 0,
    dailyWage: labour.dailyWage,
    payableAmount:
      status === 'P'
        ? labour.dailyWage + (index % 2 === 0 ? Math.round(labour.dailyWage / 8 * 3) : 0)
        : status === 'HD'
        ? Math.round(labour.dailyWage / 2)
        : 0,
    inTime: '08:30 AM',
    outTime: status === 'HD' ? '01:30 PM' : '05:30 PM',
  };
});

export const DEMO_PAYMENTS = [
  {
    id: 'pay_01',
    labourId: 'labour_a',
    labourName: 'Person A',
    amount: 1500,
    type: 'advance',
    mode: 'UPI',
    date: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    notes: 'Weekly emergency advance',
    contractorId: 'trackify_demo',
    siteName: 'Site A - Commercial Complex',
  },
  {
    id: 'pay_02',
    labourId: 'labour_b',
    labourName: 'Person B',
    amount: 2000,
    type: 'advance',
    mode: 'Cash',
    date: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    notes: 'Travel & grocery advance',
    contractorId: 'trackify_demo',
    siteName: 'Site A - Commercial Complex',
  },
  {
    id: 'pay_03',
    labourId: 'labour_g',
    labourName: 'Person G',
    amount: 2500,
    type: 'advance',
    mode: 'UPI',
    date: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    notes: 'Medical support advance',
    contractorId: 'trackify_demo',
    siteName: 'Site B - High-Rise Towers',
  },
  {
    id: 'pay_04',
    labourId: 'labour_i',
    labourName: 'Person I',
    amount: 3000,
    type: 'advance',
    mode: 'UPI',
    date: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    notes: 'Festival settlement advance',
    contractorId: 'trackify_demo',
    siteName: 'Site B - High-Rise Towers',
  },
];

export const DEMO_CLIENTS = [
  {
    id: 'client_01',
    name: 'Client A (Metro Corp)',
    company: 'Apex Metro Infra Ltd.',
    phone: '+91 98765 11111',
    email: 'projects@apexmetro.com',
    city: 'Surat',
    activeProjects: 1,
    contractorId: 'trackify_demo',
  },
  {
    id: 'client_02',
    name: 'Client B (Horizon Realty)',
    company: 'Horizon Living Spaces',
    phone: '+91 98765 22222',
    email: 'info@horizonrealty.com',
    city: 'Ahmedabad',
    activeProjects: 1,
    contractorId: 'trackify_demo',
  },
  {
    id: 'client_03',
    name: 'Client C (Industrial Park)',
    company: 'Sterling Logipark Developers',
    phone: '+91 98765 33333',
    email: 'director@sterlinglogi.com',
    city: 'Vadodara',
    activeProjects: 1,
    contractorId: 'trackify_demo',
  },
];

export const DEMO_PROJECTS = [
  {
    id: 'proj_01',
    clientId: 'client_01',
    clientName: 'Client A (Metro Corp)',
    name: 'Site A - Commercial Complex',
    status: 'in_progress',
    totalValue: 45000000,
    receivedAmount: 18500000,
    pendingAmount: 26500000,
    contractorId: 'trackify_demo',
  },
  {
    id: 'proj_02',
    clientId: 'client_02',
    clientName: 'Client B (Horizon Realty)',
    name: 'Site B - High-Rise Towers',
    status: 'in_progress',
    totalValue: 85000000,
    receivedAmount: 42000000,
    pendingAmount: 43000000,
    contractorId: 'trackify_demo',
  },
  {
    id: 'proj_03',
    clientId: 'client_03',
    clientName: 'Client C (Industrial Park)',
    name: 'Site C - Metro Corridor',
    status: 'in_progress',
    totalValue: 62000000,
    receivedAmount: 29000000,
    pendingAmount: 33000000,
    contractorId: 'trackify_demo',
  },
];

export const DEMO_PLANS = [
  {
    id: 'plan_01',
    projectName: 'Site A - Commercial Complex (Tower 1)',
    clientName: 'Client A (Metro Corp)',
    ownerName: 'Project Directorate',
    contractorId: 'trackify_demo',
    totalDrawings: 23,
    approvedDrawings: 22,
    status: 'Approved',
    updatedAt: new Date(),
  },
  {
    id: 'plan_02',
    projectName: 'Site B - High-Rise Towers (Wing B)',
    clientName: 'Client B (Horizon Realty)',
    ownerName: 'Executive Architect',
    contractorId: 'trackify_demo',
    totalDrawings: 23,
    approvedDrawings: 19,
    status: 'In Review',
    updatedAt: new Date(),
  },
  {
    id: 'plan_03',
    projectName: 'Site C - Metro Viaduct Section 4',
    clientName: 'Client C (Industrial Park)',
    ownerName: 'Chief Structural Engineer',
    contractorId: 'trackify_demo',
    totalDrawings: 23,
    approvedDrawings: 23,
    status: 'Approved',
    updatedAt: new Date(),
  },
];
