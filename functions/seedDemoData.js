/**
 * Trackify Demo Tenant Seeder
 * Deterministic and repeatable seed dataset for 'Trackify Demo Construction Pvt. Ltd.'
 * Tenant ID / Contractor ID: 'trackify_demo'
 */

const DEMO_TENANT_ID = 'trackify_demo';
const DEMO_SUPERVISOR_UID = 'demo_supervisor_uid';

const sampleSites = [
  {
    id: 'site_demo_01',
    name: 'Greenfield Heights — Tower A',
    location: 'Vesu Canal Road, Surat, Gujarat',
    type: 'Residential Highrise (14 Floors)',
    contractorId: DEMO_TENANT_ID,
    supervisorId: DEMO_SUPERVISOR_UID,
    supervisorName: 'Anil Sharma',
    status: 'active',
    budget: 45000000,
    spent: 18540000,
    totalWorkers: 14,
    code: 'GFH-A',
  },
  {
    id: 'site_demo_02',
    name: 'Diamond PEB Industrial Shed #04',
    location: 'GIDC Sachin, Surat, Gujarat',
    type: 'Commercial PEB Warehouse',
    contractorId: DEMO_TENANT_ID,
    supervisorId: DEMO_SUPERVISOR_UID,
    supervisorName: 'Anil Sharma',
    status: 'active',
    budget: 28000000,
    spent: 11200000,
    totalWorkers: 9,
    code: 'D-PEB',
  },
  {
    id: 'site_demo_03',
    name: 'Riverfront Luxury Bungalows #12-16',
    location: 'Adajan River Promenade, Surat',
    type: 'Premium G+2 Residential Villas',
    contractorId: DEMO_TENANT_ID,
    supervisorId: DEMO_SUPERVISOR_UID,
    supervisorName: 'Anil Sharma',
    status: 'active',
    budget: 32000000,
    spent: 7800000,
    totalWorkers: 5,
    code: 'RLB-03',
  },
];

const sampleWorkers = [
  // Site 1: Greenfield Heights (14 workers)
  { id: 'labour_demo_01', name: 'Rameshwar Patel', skill: 'Senior Mason', dailyWage: 900, otRate: 115, siteId: 'site_demo_01', phone: '+919876543201' },
  { id: 'labour_demo_02', name: 'Suresh Kumar Yadav', skill: 'Helper', dailyWage: 500, otRate: 65, siteId: 'site_demo_01', phone: '+919876543202' },
  { id: 'labour_demo_03', name: 'Mukeshbhai Prajapati', skill: 'Senior Mason', dailyWage: 900, otRate: 115, siteId: 'site_demo_01', phone: '+919876543203' },
  { id: 'labour_demo_04', name: 'Deepak Bind', skill: 'Helper', dailyWage: 500, otRate: 65, siteId: 'site_demo_01', phone: '+919876543204' },
  { id: 'labour_demo_05', name: 'Vikramjit Singh', skill: 'Bar Bender', dailyWage: 850, otRate: 105, siteId: 'site_demo_01', phone: '+919876543205' },
  { id: 'labour_demo_06', name: 'Mohammad Shahid', skill: 'Bar Bender', dailyWage: 850, otRate: 105, siteId: 'site_demo_01', phone: '+919876543206' },
  { id: 'labour_demo_07', name: 'Santosh Sahani', skill: 'Helper', dailyWage: 500, otRate: 65, siteId: 'site_demo_01', phone: '+919876543207' },
  { id: 'labour_demo_08', name: 'Hasmukh Mewada', skill: 'Shuttering Carpenter', dailyWage: 800, otRate: 100, siteId: 'site_demo_01', phone: '+919876543208' },
  { id: 'labour_demo_09', name: 'Bablu Gond', skill: 'Helper', dailyWage: 500, otRate: 65, siteId: 'site_demo_01', phone: '+919876543209' },
  { id: 'labour_demo_10', name: 'Chaganlal Vankar', skill: 'Mason', dailyWage: 850, otRate: 110, siteId: 'site_demo_01', phone: '+919876543210' },
  { id: 'labour_demo_11', name: 'Ajay Paswan', skill: 'Helper', dailyWage: 500, otRate: 65, siteId: 'site_demo_01', phone: '+919876543211' },
  { id: 'labour_demo_12', name: 'Kalu Ram Jat', skill: 'Bar Bender', dailyWage: 850, otRate: 105, siteId: 'site_demo_01', phone: '+919876543212' },
  { id: 'labour_demo_13', name: 'Dharmendra Nishad', skill: 'Helper', dailyWage: 500, otRate: 65, siteId: 'site_demo_01', phone: '+919876543213' },
  { id: 'labour_demo_14', name: 'Naresh Solanki', skill: 'Site Plumber', dailyWage: 850, otRate: 105, siteId: 'site_demo_01', phone: '+919876543214' },

  // Site 2: Diamond PEB Shed (9 workers)
  { id: 'labour_demo_15', name: 'Govind Ramji Suthar', skill: 'Shuttering Carpenter', dailyWage: 850, otRate: 105, siteId: 'site_demo_02', phone: '+919876543215' },
  { id: 'labour_demo_16', name: 'Rahul Kanojia', skill: 'Helper', dailyWage: 500, otRate: 65, siteId: 'site_demo_02', phone: '+919876543216' },
  { id: 'labour_demo_17', name: 'Jagdish Chandra', skill: 'Senior Mason', dailyWage: 900, otRate: 115, siteId: 'site_demo_02', phone: '+919876543217' },
  { id: 'labour_demo_18', name: 'Pankaj Mourya', skill: 'Helper', dailyWage: 500, otRate: 65, siteId: 'site_demo_02', phone: '+919876543218' },
  { id: 'labour_demo_19', name: 'Sanjay Barman', skill: 'Bar Bender', dailyWage: 850, otRate: 105, siteId: 'site_demo_02', phone: '+919876543219' },
  { id: 'labour_demo_20', name: 'Raju Ravidas', skill: 'Helper', dailyWage: 500, otRate: 65, siteId: 'site_demo_02', phone: '+919876543220' },
  { id: 'labour_demo_21', name: 'Manoj Kumar Giri', skill: 'Electrician', dailyWage: 850, otRate: 105, siteId: 'site_demo_02', phone: '+919876543221' },
  { id: 'labour_demo_22', name: 'Arjun Das', skill: 'Helper', dailyWage: 500, otRate: 65, siteId: 'site_demo_02', phone: '+919876543222' },
  { id: 'labour_demo_23', name: 'Sunil Rathore', skill: 'Mason', dailyWage: 850, otRate: 105, siteId: 'site_demo_02', phone: '+919876543223' },

  // Site 3: Riverfront Bungalows (5 workers)
  { id: 'labour_demo_24', name: 'Meera Devi', skill: 'Tile Specialist', dailyWage: 900, otRate: 115, siteId: 'site_demo_03', phone: '+919876543224' },
  { id: 'labour_demo_25', name: 'Sunita Soren', skill: 'Helper', dailyWage: 520, otRate: 65, siteId: 'site_demo_03', phone: '+919876543225' },
  { id: 'labour_demo_26', name: 'Pravin Luhar', skill: 'Shuttering Carpenter', dailyWage: 800, otRate: 100, siteId: 'site_demo_03', phone: '+919876543226' },
  { id: 'labour_demo_27', name: 'Kiran Bhai Parmar', skill: 'Tile Specialist', dailyWage: 850, otRate: 105, siteId: 'site_demo_03', phone: '+919876543227' },
  { id: 'labour_demo_28', name: 'Amit Kumar Mahato', skill: 'Helper', dailyWage: 500, otRate: 65, siteId: 'site_demo_03', phone: '+919876543228' },
];

/**
 * Seed all demo records into Firestore using Firebase Admin
 * @param {import('firebase-admin').firestore.Firestore} db
 */
async function seedDemoTenantData(db) {
  console.log('[DemoSeeder] Initializing demo company profile...');
  const batch = db.batch();

  // 1. Company / Contractor profile
  const contractorRef = db.collection('contractors').doc(DEMO_TENANT_ID);
  batch.set(contractorRef, {
    id: DEMO_TENANT_ID,
    name: 'Trackify Demo Construction Pvt. Ltd.',
    ownerName: 'Vikramaditya Singhania',
    phone: '+919876543210',
    email: 'demo@trackify.live',
    address: 'Plot 104, Diamond Industrial Zone, Surat, Gujarat 395007',
    gstNumber: '24AAACT1234F1Z8',
    city: 'Surat',
    isActive: true,
    isSuspended: false,
    createdAt: new Date(Date.now() - 90 * 86400000),
    updatedAt: new Date(),
    branding: {
      companyName: 'Trackify Demo Construction Pvt. Ltd.',
      brandColor: '#F59E0B',
      tagline: 'Precision Civil Engineering & Infrastructure',
    },
  });

  // 2. Demo Supervisor Profile (for mobile app testing)
  const supervisorRef = db.collection('users').doc(DEMO_SUPERVISOR_UID);
  batch.set(supervisorRef, {
    uid: DEMO_SUPERVISOR_UID,
    name: 'Anil Sharma (Site Head)',
    email: 'supervisor.demo@trackify.live',
    phone: '+919876543211',
    role: 'supervisor',
    contractorId: DEMO_TENANT_ID,
    isActive: true,
    createdAt: new Date(Date.now() - 60 * 86400000),
    updatedAt: new Date(),
  });

  // 3. Sites
  for (const site of sampleSites) {
    const siteRef = db.collection('sites').doc(site.id);
    batch.set(siteRef, {
      ...site,
      createdAt: new Date(Date.now() - 45 * 86400000),
      updatedAt: new Date(),
    });
  }

  // 4. Labours
  for (const worker of sampleWorkers) {
    const labourRef = db.collection('labours').doc(worker.id);
    batch.set(labourRef, {
      id: worker.id,
      name: worker.name,
      phone: worker.phone,
      phoneNumber: worker.phone,
      skill: worker.skill,
      role: worker.skill,
      dailyWage: worker.dailyWage,
      dailyRate: worker.dailyWage,
      overtimeWagePerHour: worker.otRate,
      defaultOvertimeHours: 0,
      contractorId: DEMO_TENANT_ID,
      supervisorId: DEMO_SUPERVISOR_UID,
      siteId: worker.siteId,
      assignedSiteId: worker.siteId,
      type: 'regular',
      isActive: true,
      joiningDate: new Date(Date.now() - 35 * 86400000),
      createdAt: new Date(Date.now() - 35 * 86400000),
      updatedAt: new Date(),
    });
  }

  await batch.commit();
  console.log('[DemoSeeder] Core company, supervisor, sites and workers committed.');

  // 5. Historical Attendance for previous 7 days
  const now = new Date();
  const attendanceBatch = db.batch();

  for (let d = 0; d < 7; d++) {
    const dateObj = new Date(now.getTime() - d * 86400000);
    const y = dateObj.getFullYear();
    const m = String(dateObj.getMonth() + 1).padStart(2, '0');
    const day = String(dateObj.getDate()).padStart(2, '0');
    const dateKey = `${y}-${m}-${day}`;

    // Mark attendance for all 28 workers
    sampleWorkers.forEach((w, index) => {
      // Deterministic shift pattern: mostly 1.0 (present), occasionally 0.5 (half-day) or 1.5 (overtime) or 0 (absent)
      let shift = 1.0;
      let status = 'present';
      let overtimeHours = 0;

      if ((index + d) % 9 === 0) {
        shift = 0.5;
        status = 'half_day';
      } else if ((index + d) % 7 === 0) {
        shift = 1.5;
        status = 'overtime';
        overtimeHours = 4;
      } else if ((index + d) % 15 === 0) {
        shift = 0;
        status = 'absent';
      }

      const recordId = `att_${DEMO_TENANT_ID}_${dateKey}_${w.id}`;
      const recordRef = db.collection('attendance').doc(recordId);

      attendanceBatch.set(recordRef, {
        id: recordId,
        contractorId: DEMO_TENANT_ID,
        siteId: w.siteId,
        labourId: w.id,
        labourName: w.name,
        supervisorId: DEMO_SUPERVISOR_UID,
        date: dateKey,
        dateStr: dateKey,
        timestamp: new Date(dateObj.setHours(8, 30 + (index % 25), 0)),
        status,
        shiftMultiplier: shift,
        overtimeHours,
        markedVia: index % 3 === 0 ? 'QR_SCAN' : 'MANUAL_BATCH',
        createdAt: new Date(),
      });
    });
  }

  // 6. Realistic Advance Payments & Weekly Settlements
  const samplePayments = [
    {
      id: 'pay_demo_01',
      contractorId: DEMO_TENANT_ID,
      siteId: 'site_demo_01',
      labourId: 'labour_demo_01',
      labourName: 'Rameshwar Patel',
      type: 'ADVANCE',
      amount: 1500,
      paymentMethod: 'CASH',
      status: 'paid',
      notes: 'Festival cash advance requested',
      date: new Date(Date.now() - 5 * 86400000),
      createdAt: new Date(Date.now() - 5 * 86400000),
    },
    {
      id: 'pay_demo_02',
      contractorId: DEMO_TENANT_ID,
      siteId: 'site_demo_01',
      labourId: 'labour_demo_02',
      labourName: 'Suresh Kumar Yadav',
      type: 'ADVANCE',
      amount: 500,
      paymentMethod: 'UPI',
      status: 'paid',
      notes: 'Medical advance for family medicine',
      date: new Date(Date.now() - 4 * 86400000),
      createdAt: new Date(Date.now() - 4 * 86400000),
    },
    {
      id: 'pay_demo_03',
      contractorId: DEMO_TENANT_ID,
      siteId: 'site_demo_01',
      labourId: 'labour_demo_05',
      labourName: 'Vikramjit Singh',
      type: 'ADVANCE',
      amount: 2000,
      paymentMethod: 'UPI',
      status: 'paid',
      notes: 'Steel bar bending crew advance',
      date: new Date(Date.now() - 3 * 86400000),
      createdAt: new Date(Date.now() - 3 * 86400000),
    },
    {
      id: 'pay_demo_04',
      contractorId: DEMO_TENANT_ID,
      siteId: 'site_demo_02',
      labourId: 'labour_demo_17',
      labourName: 'Jagdish Chandra',
      type: 'WAGE_PAYOUT',
      amount: 5400,
      paymentMethod: 'BANK_TRANSFER',
      status: 'paid',
      notes: 'Weekly payroll payout (6 days worked - ₹0 advances)',
      date: new Date(Date.now() - 2 * 86400000),
      createdAt: new Date(Date.now() - 2 * 86400000),
    },
    {
      id: 'pay_demo_05',
      contractorId: DEMO_TENANT_ID,
      siteId: 'site_demo_03',
      labourId: 'labour_demo_24',
      labourName: 'Meera Devi',
      type: 'WAGE_PAYOUT',
      amount: 4500,
      paymentMethod: 'UPI',
      status: 'paid',
      notes: 'Weekly tile flooring wage settlement',
      date: new Date(Date.now() - 1 * 86400000),
      createdAt: new Date(Date.now() - 1 * 86400000),
    },
  ];

  samplePayments.forEach((p) => {
    const pRef = db.collection('payments').doc(p.id);
    attendanceBatch.set(pRef, p);
  });

  // 7. Site Allowances
  const sampleAllowances = [
    {
      id: 'allow_demo_01',
      contractorId: DEMO_TENANT_ID,
      siteId: 'site_demo_01',
      labourId: 'labour_demo_01',
      labourName: 'Rameshwar Patel',
      amount: 200,
      type: 'TRAVEL',
      reason: 'Late evening foundation casting travel allowance',
      approvedBy: DEMO_SUPERVISOR_UID,
      date: new Date(Date.now() - 3 * 86400000),
    },
    {
      id: 'allow_demo_02',
      contractorId: DEMO_TENANT_ID,
      siteId: 'site_demo_02',
      labourId: 'labour_demo_15',
      labourName: 'Govind Ramji Suthar',
      amount: 150,
      type: 'FOOD',
      reason: 'Overtime PEB beam alignment meal stipend',
      approvedBy: DEMO_SUPERVISOR_UID,
      date: new Date(Date.now() - 2 * 86400000),
    },
  ];

  sampleAllowances.forEach((a) => {
    const aRef = db.collection('siteAllowances').doc(a.id);
    attendanceBatch.set(aRef, a);
  });

  await attendanceBatch.commit();
  console.log('[DemoSeeder] Attendance, payments, and allowances committed successfully.');
  return { success: true, tenantId: DEMO_TENANT_ID, workerCount: sampleWorkers.length, siteCount: sampleSites.length };
}

module.exports = {
  DEMO_TENANT_ID,
  DEMO_SUPERVISOR_UID,
  sampleSites,
  sampleWorkers,
  seedDemoTenantData,
};

