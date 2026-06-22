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
  await addDoc(collection(db, 'support_tickets'), {
    issue: "My app keeps crashing when I scan a QR code! I'm stuck on site, please help me immediately!",
    status: 'Open',
    priority: 'High',
    userId: 'user_123',
    history: [{
      type: 'status_change',
      text: 'Ticket created',
      timestamp: new Date().toISOString()
    }],
    createdAt: serverTimestamp()
  });
  console.log("Injected Support Ticket for AI Auto-Responder!");
  process.exit(0);
}

inject();
