import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getFirestore, collection, addDoc, serverTimestamp } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyDC9fZJTOi455NsbN2AQRnGz_cjZvmwedc",
  authDomain: "ys-construction.firebaseapp.com",
  projectId: "ys-construction"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

async function inject() {
  await signInAnonymously(auth);
  
  const ticketRef = await addDoc(collection(db, 'support_tickets'), {
    issue: "My app keeps crashing when I scan a QR code! I'm stuck on site, please help me immediately!",
    status: 'Open',
    priority: 'High',
    userId: auth.currentUser.uid,
    history: [{
      type: 'status_change',
      text: 'Ticket created',
      timestamp: new Date().toISOString()
    }],
    createdAt: serverTimestamp()
  });
  console.log("Injected Support Ticket:", ticketRef.id);

  const errorRef = await addDoc(collection(db, 'error_logs'), {
    message: 'Unhandled Exception: Firebase Rules Denied! Massive database corruption detected in payments table.',
    stackTrace: 'Exception: PermissionDenied\\n  at PaymentsService.sync (payments.dart:45)',
    type: 'Security Breach',
    severity: 'CRITICAL',
    status: 'NEW',
    module: 'Database',
    createdAt: serverTimestamp(),
    userId: auth.currentUser.uid
  });
  console.log("Injected CRITICAL Error:", errorRef.id);
  
  process.exit(0);
}

inject();
