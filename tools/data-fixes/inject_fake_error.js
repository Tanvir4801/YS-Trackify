import { initializeApp } from 'firebase/app';
import { getFirestore, collection, addDoc, serverTimestamp } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyDC9fZJTOi455NsbN2AQRnGz_cjZvmwedc",
  authDomain: "ys-construction.firebaseapp.com",
  projectId: "ys-construction",
  storageBucket: "ys-construction.firebasestorage.app",
  messagingSenderId: "487752590406",
  appId: "1:487752590406:web:cd934161591117bc581647"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function inject() {
  await addDoc(collection(db, 'error_logs'), {
    message: '[FAKE ERROR] Connection to Main Tracking Node Lost.',
    stackTrace: 'Exception: SocketTimeout\\n  at TrackingService.sync (tracking_service.dart:45)',
    type: 'Network Error',
    severity: 'HIGH',
    status: 'NEW',
    module: 'Tracking Node',
    createdAt: serverTimestamp(),
    userId: 'admin_test'
  });
  console.log("Injected fake error!");
  process.exit(0);
}

inject();
