import fs from 'fs';

console.log("To seed the Mission Control Center, run this in your browser console:");
const seedCode = `
const { doc, setDoc, addDoc, collection, serverTimestamp } = await import('firebase/firestore');
const { db } = await import('./src/lib/firebase.js');

async function seedMissionDashboard() {
  let added = 0;
  
  // 1. Seed Contractors (for Revenue, Growth, Companies Active)
  const contractors = [
    { id: 'YS_Construction', name: 'YS Construction Pvt Ltd', status: 'active', subscriptionPlan: 'Premium', createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000) },
    { id: 'ABC_Infra', name: 'ABC Infrastructure', status: 'active', subscriptionPlan: 'Standard', createdAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000) },
    { id: 'L_and_T', name: 'L&T Construction', status: 'active', subscriptionPlan: 'Enterprise', createdAt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
    { id: 'DLF', name: 'DLF Sites', status: 'disabled', subscriptionPlan: 'Free', createdAt: new Date(Date.now() - 60 * 24 * 60 * 60 * 1000) },
    { id: 'New_Builder', name: 'New Age Builders', status: 'active', subscriptionPlan: 'Premium', createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000) },
  ];
  for (const c of contractors) {
    await setDoc(doc(db, 'contractors', c.id), { ...c });
    added++;
  }

  // 2. Seed Error Logs (for System Health & Unresolved Errors)
  const errors = [
    { module: 'Attendance', type: 'Unhandled Exception', status: 'NEW', severity: 'CRITICAL', timestamp: serverTimestamp() },
    { module: 'Export', type: 'OOM Error', status: 'INVESTIGATING', severity: 'HIGH', timestamp: serverTimestamp() },
    { module: 'Auth', type: 'Timeout', status: 'RESOLVED', severity: 'MEDIUM', timestamp: serverTimestamp() }
  ];
  for (const e of errors) {
    await addDoc(collection(db, 'error_logs'), e);
    added++;
  }
  
  console.log("Seeded " + added + " dashboard metrics!");
}

seedMissionDashboard();
`;
console.log(seedCode);
fs.writeFileSync('mission_dashboard_seed_command.txt', seedCode);
