import { initializeApp } from 'firebase/app';
import { getFirestore, collection, addDoc, serverTimestamp } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyDC9fZJTOi455NsbN2AQRnGz_cjZvmwedc",
  authDomain: "ys-construction.firebaseapp.com",
  projectId: "ys-construction"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function inject() {
  const errorRef = await addDoc(collection(db, 'error_logs'), {
    message: 'Unhandled Exception: Firebase Rules Denied! Massive database corruption detected in payments table.',
    stackTrace: 'Exception: PermissionDenied\\n  at PaymentsService.sync (payments.dart:45)',
    type: 'Security Breach',
    severity: 'CRITICAL',
    status: 'NEW',
    module: 'Database',
    createdAt: serverTimestamp(),
    userId: 'user_123'
  });
  console.log("Injected CRITICAL Error for AI testing! Document ID:", errorRef.id);
  
  process.exit(0);
}

inject();
