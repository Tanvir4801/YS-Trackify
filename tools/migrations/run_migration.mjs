import { initializeApp } from "firebase/app";
import { getFirestore, collectionGroup, getDocs, updateDoc, doc, deleteField } from "firebase/firestore";

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

async function migrateExpenses() {
  const querySnapshot = await getDocs(collectionGroup(db, 'expenses'));
  for (const document of querySnapshot.docs) {
    const data = document.data();
    let updates = {};
    if (data.title && !data.description) {
      updates.description = data.title;
      updates.title = deleteField();
    }
    if (data.expenseType && data.expenseType !== data.expenseType.toLowerCase()) {
      updates.expenseType = data.expenseType.toLowerCase();
    }
    
    // Check if we need to update
    if (Object.keys(updates).length > 0) {
      await updateDoc(doc(db, document.ref.path), updates);
      console.log(`Updated ${document.ref.path}`);
    }
  }
  console.log("Done migrating expenses.");
  process.exit(0);
}

migrateExpenses();
