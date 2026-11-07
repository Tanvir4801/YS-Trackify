/**
 * Complete, Deterministic Mock Data for XYZ Construction Demo Environment.
 * Completely generic entities (Person A...Z, SITE X, SITE Y, SITE Z, Supervisor X...Z).
 * Strictly zero personal or proprietary names.
 */

export const DEMO_COMPANY_NAME = 'XYZ Construction';

export const DEMO_BRANDING = {
  companyName: 'XYZ Construction',
  tagline: 'Civil Engineering & Infrastructure Contractors',
  address: 'Corporate Tower, Tech Park Zone, Sector 4, Metro City',
  phone: '+91 98765 00000',
  email: 'contact@xyz-construction.demo',
  gstNumber: '24AAAAA0000A1Z5',
  logoUrl: null, // Uses clean gold Compass icon
  logoDataUrl: null,
  logoStoragePath: null,
  themeColor: '#F5A623',
  themeColorDark: '#D97706',
  themeColorLight: '#FEF3C7',
  pdfHeaderNote: 'Thank you for partnering with XYZ Construction',
  invoicePrefix: 'XYZ',
  isSetup: true,
};

export const DEMO_SITES = [
  {
    id: 'site_x',
    name: 'SITE X - Commercial Hub',
    description: '14-Storey Commercial & IT Tower with Multi-Level Basement Parking',
    location: 'Sector 42, North Corridor',
    contractorId: 'trackify_demo',
    isActive: true,
    labourCount: 12,
    supervisorId: 'sup_x',
    supervisorName: 'Supervisor X',
    budget: 45000000,
    spent: 18500000,
    defaultAllowances: { petrol: 100, lunch: 80, breakfast: 40, tea: 20 },
  },
  {
    id: 'site_y',
    name: 'SITE Y - High-Rise Towers',
    description: 'Twin Luxury Residential Towers (24 Floors each)',
    location: 'Phase 2, Skyline Boulevard',
    contractorId: 'trackify_demo',
    isActive: true,
    labourCount: 10,
    supervisorId: 'sup_y',
    supervisorName: 'Supervisor Y',
    budget: 85000000,
    spent: 42000000,
    defaultAllowances: { petrol: 120, lunch: 90, breakfast: 40, tea: 20 },
  },
  {
    id: 'site_z',
    name: 'SITE Z - Metro Expressway',
    description: 'Elevated Metro Viaduct & Station Concourse Project',
    location: 'Outer Ring Express Junction',
    contractorId: 'trackify_demo',
    isActive: true,
    labourCount: 6,
    supervisorId: 'sup_z',
    supervisorName: 'Supervisor Z',
    budget: 62000000,
    spent: 29000000,
    defaultAllowances: { petrol: 150, lunch: 100, breakfast: 50, tea: 25 },
  },
];

export const DEMO_SUPERVISORS = [
  {
    id: 'sup_x',
    name: 'Supervisor X',
    phone: '+91 98765 00001',
    email: 'supervisor.x@xyz.com',
    role: 'supervisor',
    contractorId: 'trackify_demo',
    siteName: 'SITE X - Commercial Hub',
  },
  {
    id: 'sup_y',
    name: 'Supervisor Y',
    phone: '+91 98765 00002',
    email: 'supervisor.y@xyz.com',
    role: 'supervisor',
    contractorId: 'trackify_demo',
    siteName: 'SITE Y - High-Rise Towers',
  },
  {
    id: 'sup_z',
    name: 'Supervisor Z',
    phone: '+91 98765 00003',
    email: 'supervisor.z@xyz.com',
    role: 'supervisor',
    contractorId: 'trackify_demo',
    siteName: 'SITE Z - Metro Expressway',
  },
];

const ROLES_SPEC = [
  { letter: 'A', role: 'Mason Lead', dailyWage: 850, siteId: 'site_x', supervisorId: 'sup_x', advance: 1500 },
  { letter: 'B', role: 'Bar Bender Senior', dailyWage: 800, siteId: 'site_x', supervisorId: 'sup_x', advance: 2000 },
  { letter: 'C', role: 'Carpenter Head', dailyWage: 780, siteId: 'site_x', supervisorId: 'sup_x', advance: 1200 },
  { letter: 'D', role: 'Electrician Tech', dailyWage: 750, siteId: 'site_x', supervisorId: 'sup_x', advance: 800 },
  { letter: 'E', role: 'Plumbing Specialist', dailyWage: 750, siteId: 'site_x', supervisorId: 'sup_x', advance: 500 },
  { letter: 'F', role: 'Structural Welder', dailyWage: 720, siteId: 'site_x', supervisorId: 'sup_x', advance: 0 },
  { letter: 'G', role: 'Tile & Marble Master', dailyWage: 800, siteId: 'site_y', supervisorId: 'sup_y', advance: 2500 },
  { letter: 'H', role: 'Scaffolding Expert', dailyWage: 680, siteId: 'site_y', supervisorId: 'sup_y', advance: 1000 },
  { letter: 'I', role: 'Mason Grade I', dailyWage: 700, siteId: 'site_y', supervisorId: 'sup_y', advance: 3000 },
  { letter: 'J', role: 'Concrete Finisher', dailyWage: 650, siteId: 'site_y', supervisorId: 'sup_y', advance: 500 },
  { letter: 'K', role: 'Painter Foreman', dailyWage: 650, siteId: 'site_y', supervisorId: 'sup_y', advance: 1200 },
  { letter: 'L', role: 'Steel Binder', dailyWage: 620, siteId: 'site_y', supervisorId: 'sup_y', advance: 0 },
  { letter: 'M', role: 'Excavation Operator', dailyWage: 850, siteId: 'site_z', supervisorId: 'sup_z', advance: 2000 },
  { letter: 'N', role: 'Survey Assistant', dailyWage: 700, siteId: 'site_z', supervisorId: 'sup_z', advance: 800 },
  { letter: 'O', role: 'Safety Marshal', dailyWage: 750, siteId: 'site_z', supervisorId: 'sup_z', advance: 0 },
  { letter: 'P', role: 'Skilled Helper', dailyWage: 520, siteId: 'site_x', supervisorId: 'sup_x', advance: 500 },
  { letter: 'Q', role: 'Civil Helper', dailyWage: 500, siteId: 'site_x', supervisorId: 'sup_x', advance: 800 },
  { letter: 'R', role: 'Material Handler', dailyWage: 480, siteId: 'site_x', supervisorId: 'sup_x', advance: 1000 },
  { letter: 'S', role: 'Mason Assistant', dailyWage: 550, siteId: 'site_x', supervisorId: 'sup_x', advance: 600 },
  { letter: 'T', role: 'Shuttering Helper', dailyWage: 500, siteId: 'site_x', supervisorId: 'sup_x', advance: 0 },
  { letter: 'U', role: 'Site Cleaner & Helper', dailyWage: 450, siteId: 'site_x', supervisorId: 'sup_x', advance: 400 },
  { letter: 'V', role: 'Concrete Helper', dailyWage: 480, siteId: 'site_y', supervisorId: 'sup_y', advance: 700 },
  { letter: 'W', role: 'Electrical Helper', dailyWage: 500, siteId: 'site_y', supervisorId: 'sup_y', advance: 900 },
  { letter: 'X', role: 'Steel Carrier', dailyWage: 480, siteId: 'site_y', supervisorId: 'sup_y', advance: 0 },
  { letter: 'Y', role: 'Drainage Helper', dailyWage: 460, siteId: 'site_y', supervisorId: 'sup_y', advance: 500 },
  { letter: 'Z', role: 'Heavy Rigging Helper', dailyWage: 520, siteId: 'site_z', supervisorId: 'sup_z', advance: 1100 },
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
    siteName: site?.name || 'SITE X - Commercial Hub',
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
    siteName: 'SITE X - Commercial Hub',
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
    siteName: 'SITE X - Commercial Hub',
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
    siteName: 'SITE Y - High-Rise Towers',
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
    siteName: 'SITE Y - High-Rise Towers',
  },
];

export const DEMO_CLIENTS = [
  {
    id: 'client_01',
    name: 'Client A (Commercial Properties)',
    company: 'Apex Metro Infra Ltd.',
    phone: '+91 98765 11111',
    email: 'projects@apexmetro.demo',
    city: 'Metro City',
    activeProjects: 1,
    contractorId: 'trackify_demo',
  },
  {
    id: 'client_02',
    name: 'Client B (Residential Developers)',
    company: 'Horizon Living Spaces',
    phone: '+91 98765 22222',
    email: 'info@horizonrealty.demo',
    city: 'Metro City',
    activeProjects: 1,
    contractorId: 'trackify_demo',
  },
  {
    id: 'client_03',
    name: 'Client C (Expressway Infrastructure)',
    company: 'Sterling Logipark Developers',
    phone: '+91 98765 33333',
    email: 'director@sterlinglogi.demo',
    city: 'Metro City',
    activeProjects: 1,
    contractorId: 'trackify_demo',
  },
];

export const DEMO_PROJECTS = [
  {
    id: 'proj_01',
    clientId: 'client_01',
    clientName: 'Client A (Commercial Properties)',
    name: 'SITE X - Commercial Hub',
    status: 'in_progress',
    totalValue: 45000000,
    receivedAmount: 18500000,
    pendingAmount: 26500000,
    contractorId: 'trackify_demo',
  },
  {
    id: 'proj_02',
    clientId: 'client_02',
    clientName: 'Client B (Residential Developers)',
    name: 'SITE Y - High-Rise Towers',
    status: 'in_progress',
    totalValue: 85000000,
    receivedAmount: 42000000,
    pendingAmount: 43000000,
    contractorId: 'trackify_demo',
  },
  {
    id: 'proj_03',
    clientId: 'client_03',
    clientName: 'Client C (Expressway Infrastructure)',
    name: 'SITE Z - Metro Expressway',
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
    projectName: 'SITE X - Commercial Hub (Tower 1)',
    clientName: 'Client A (Commercial Properties)',
    ownerName: 'Project Directorate',
    contractorId: 'trackify_demo',
    totalDrawings: 23,
    approvedDrawings: 22,
    status: 'Approved',
    updatedAt: new Date(),
  },
  {
    id: 'plan_02',
    projectName: 'SITE Y - High-Rise Towers (Wing B)',
    clientName: 'Client B (Residential Developers)',
    ownerName: 'Executive Architect',
    contractorId: 'trackify_demo',
    totalDrawings: 23,
    approvedDrawings: 19,
    status: 'In Review',
    updatedAt: new Date(),
  },
  {
    id: 'plan_03',
    projectName: 'SITE Z - Metro Expressway Section 4',
    clientName: 'Client C (Expressway Infrastructure)',
    ownerName: 'Chief Structural Engineer',
    contractorId: 'trackify_demo',
    totalDrawings: 23,
    approvedDrawings: 23,
    status: 'Approved',
    updatedAt: new Date(),
  },
];

export const DEMO_MATERIALS = [
  { id: 'mat_01', materialName: 'UltraTech Cement Grade 53', category: 'Cement', quantity: 250, unit: 'Bag', pricePerUnit: 380, totalAmount: 95000, siteId: 'site_x', purchaseDate: '2026-11-04' },
  { id: 'mat_02', materialName: 'TMT Steel Fe 550D (12mm)', category: 'Steel', quantity: 15, unit: 'Ton', pricePerUnit: 64000, totalAmount: 960000, siteId: 'site_y', purchaseDate: '2026-11-03' },
  { id: 'mat_03', materialName: 'River Sand Fine Coarse', category: 'Sand', quantity: 1200, unit: 'Cu.Ft', pricePerUnit: 55, totalAmount: 66000, siteId: 'site_z', purchaseDate: '2026-11-02' },
  { id: 'mat_04', materialName: 'Granite Aggregate (20mm)', category: 'Aggregate', quantity: 800, unit: 'Cu.Ft', pricePerUnit: 42, totalAmount: 33600, siteId: 'site_x', purchaseDate: '2026-11-01' },
];

export const DEMO_SITE_EXPENSES = [
  { id: 'exp_01', expenseType: 'machinery', description: 'JCB Earth Excavator (24 Hours)', amount: 48000, siteId: 'site_x', paidTo: 'Metro Heavy Rentals', date: '2026-11-05' },
  { id: 'exp_02', expenseType: 'transport', description: 'Transit Mixer Concrete Delivery', amount: 32000, siteId: 'site_y', paidTo: 'Apex Logistics Fleet', date: '2026-11-04' },
  { id: 'exp_03', expenseType: 'utility', description: 'Temporary Generator Power Fuel', amount: 14500, siteId: 'site_z', paidTo: 'National Energy Fuels', date: '2026-11-02' },
];

