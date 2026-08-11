import { initializeApp } from 'firebase/app';
import { getFirestore, doc, setDoc } from 'firebase/firestore';
import fs from 'fs';

// Read firebase config from existing .env or define fallback
// Using standard web SDK approach to seed some data for the demo
const firebaseConfig = {
  apiKey: process.env.VITE_FIREBASE_API_KEY || 'dummy_api_key',
  authDomain: process.env.VITE_FIREBASE_AUTH_DOMAIN || 'dummy_auth_domain',
  projectId: process.env.VITE_FIREBASE_PROJECT_ID || 'trackify-live-v2', // Will work if local emulator or permissive rules, but user has real DB
};

// Instead of setting up full node script which requires firebase-admin and credentials,
// I'll create a script that they can run, OR I can just run a python script if I install firebase-admin.
// Wait, in previous step I saw python firebase_admin was missing. 
// The user already has the web app running. Let me just create a simple node script using `firebase/app`?
// No, the web SDK cannot easily write without auth if rules are locked down, but let's assume they are open for this admin script, or we'll just provide the script for them to run in their browser console.

console.log("To seed data, run this in your browser console:");
const seedCode = `
const { doc, setDoc } = await import('firebase/firestore');
const { db } = await import('./src/lib/firebase.js'); // adjust path if needed or just use window.db if exported

await setDoc(doc(db, 'system_health', 'global'), {
  missionHealthPercentage: 98,
  totalRequests: 1450239,
  monthlyUsage: 1450239,
  estimatedCosts: 12.45
});

await setDoc(doc(db, 'infrastructure_metrics', 'firestore'), {
  name: 'Firestore Database', status: 'GREEN', latencyMs: 24, details: '100% Uptime • Normal Load'
});
await setDoc(doc(db, 'infrastructure_metrics', 'auth'), {
  name: 'Authentication', status: 'GREEN', latencyMs: 45, details: 'Normal • 0 Failed logins in last hour'
});
await setDoc(doc(db, 'infrastructure_metrics', 'storage'), {
  name: 'Firebase Storage', status: 'YELLOW', latencyMs: 150, details: 'Degraded • Slower upload speeds detected in AP-SOUTH-1'
});
await setDoc(doc(db, 'infrastructure_metrics', 'functions'), {
  name: 'Cloud Functions', status: 'RED', latencyMs: 5000, details: 'Failing • "generateReportPdf" returning 500 errors'
});
await setDoc(doc(db, 'infrastructure_metrics', 'notifications'), {
  name: 'Notification Service', status: 'GREEN', latencyMs: 18, details: 'FCM Connected • Queue empty'
});

const services = [
  { id: 'attendance_engine', name: 'Attendance Engine', status: 'GREEN', successRate: 99.9, failedRequests: 12 },
  { id: 'payroll_engine', name: 'Payroll Engine', status: 'GREEN', successRate: 100, failedRequests: 0 },
  { id: 'pdf_export', name: 'PDF Export Engine', status: 'RED', successRate: 64.2, failedRequests: 84 },
  { id: 'qr_attendance', name: 'QR Attendance Engine', status: 'GREEN', successRate: 98.5, failedRequests: 4 },
];

for(const s of services) {
  await setDoc(doc(db, 'service_metrics', s.id), s);
}

await setDoc(doc(db, 'live_users', 'admin_1'), {
  userId: 'admin_1', companyId: 'Trackify_HQ', appVersion: 'React_Admin_v2', platform: 'MacIntel', networkStatus: 'ONLINE', currentScreen: 'Product Health', latencyMs: 34, lastSeen: new Date()
});

console.log("Seeding complete!");
`;
console.log(seedCode);
fs.writeFileSync('seed_command.txt', seedCode);
