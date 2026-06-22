// fix-firebase.mjs
// Run ONCE to fix all Firestore data issues
// Command: node fix-firebase.mjs

import { initializeApp } from 'firebase/app';
import {
  getFirestore,
  collection,
  doc,
  getDocs,
  updateDoc,
  getDoc,
} from 'firebase/firestore';

// ── PASTE YOUR FIREBASE CONFIG HERE ──────────
const firebaseConfig = {
  apiKey: "AIzaSyDC9fZJTOi455NsbN2AQRnGz_cjZvmwedc",
  authDomain: "ys-construction.firebaseapp.com",
  projectId: "ys-construction",
  storageBucket: "ys-construction.firebasestorage.app",
  messagingSenderId: "487752590406",
  appId: "1:487752590406:web:cd934161591117bc581647",
  measurementId: "G-3LH0KG5S5Z"
};
// ─────────────────────────────────────────────

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// ── PASTE YOUR VALUES HERE ────────────────────
// Go to Firebase Console → Firestore → contractors
// Copy the document ID of YS Constructions
const YS_CONTRACTOR_ID = 'bWu9d5Dnw6oI90flrIgE';

// Go to Firebase Console → Authentication → Users
// Find Ramesh and copy his UID
const RAMESH_UID = 'sLU1JOjX6uYo04NkDDHNYbyHDpZ2';
// ─────────────────────────────────────────────

async function main() {
  console.log('\n🚀 Starting Firebase fix script...\n');
  console.log('Using contractorId:', YS_CONTRACTOR_ID);
  console.log('Using Ramesh UID:', RAMESH_UID);

  // ══════════════════════════════════════════
  // FIX 1 — Fix Ramesh's user document
  // Ensure role, contractorId, isActive are correct
  // ══════════════════════════════════════════
  console.log('\n── FIX 1: Fixing Ramesh user document ──');

  const rameshRef = doc(db, 'users', RAMESH_UID);
  const rameshSnap = await getDoc(rameshRef);

  if (rameshSnap.exists()) {
    const data = rameshSnap.data();
    console.log('Current Ramesh data:', JSON.stringify(data, null, 2));

    await updateDoc(rameshRef, {
      role: 'supervisor',              // lowercase exactly
      contractorId: YS_CONTRACTOR_ID, // must match contractors doc ID
      isActive: true,                  // boolean true
      name: data.name || 'Ramesh',    // keep existing name
    });
    console.log('✅ Ramesh user doc fixed');
  } else {
    console.log('❌ Ramesh user doc NOT FOUND');
    console.log('   Check the UID is correct:', RAMESH_UID);
    console.log('   Go to Firebase Console → Authentication → Users');
  }

  // ══════════════════════════════════════════
  // FIX 2 — Fix all labour documents
  // Ensure supervisorRef is DocumentReference not string
  // Ensure contractorId is set correctly
  // ══════════════════════════════════════════
  console.log('\n── FIX 2: Fixing labour documents ──');

  const laboursSnap = await getDocs(collection(db, 'labours'));
  console.log(`Found ${laboursSnap.size} labour documents`);

  let fixedLabours = 0;
  let skippedLabours = 0;

  for (const labourDoc of laboursSnap.docs) {
    const data = labourDoc.data();
    const updates = {};
    let needsUpdate = false;

    // Fix 1: supervisorRef stored as string → convert to DocumentReference
    if (typeof data.supervisorRef === 'string') {
      const uid = data.supervisorRef.replace('users/', '');
      updates.supervisorRef = doc(db, 'users', uid);
      updates.supervisorId = uid; // also ensure string field is set
      needsUpdate = true;
      console.log(`  Labour "${data.name}": fixing supervisorRef string → DocumentReference`);
    }

    // Fix 2: missing contractorId → set to YS_CONTRACTOR_ID
    if (!data.contractorId || data.contractorId === '') {
      updates.contractorId = YS_CONTRACTOR_ID;
      needsUpdate = true;
      console.log(`  Labour "${data.name}": adding contractorId`);
    }

    // Fix 3: missing supervisorId string → set from Ramesh UID
    if (!data.supervisorId && data.supervisorRef) {
      updates.supervisorId = RAMESH_UID;
      needsUpdate = true;
      console.log(`  Labour "${data.name}": adding supervisorId`);
    }

    // Fix 4: ensure dailyRate alias exists (admin panel uses dailyRate)
    if (data.dailyWage && !data.dailyRate) {
      updates.dailyRate = data.dailyWage;
      needsUpdate = true;
    }

    // Fix 5: ensure skill alias exists (admin panel uses skill, Flutter uses role)
    if (data.role && !data.skill) {
      updates.skill = data.role;
      needsUpdate = true;
    }
    if (data.skill && !data.role) {
      updates.role = data.skill;
      needsUpdate = true;
    }

    if (needsUpdate) {
      await updateDoc(doc(db, 'labours', labourDoc.id), updates);
      fixedLabours++;
    } else {
      skippedLabours++;
    }
  }

  console.log(`✅ Fixed ${fixedLabours} labours, skipped ${skippedLabours} (already correct)`);

  // ══════════════════════════════════════════
  // FIX 3 — Verify contractors document exists
  // ══════════════════════════════════════════
  console.log('\n── FIX 3: Verifying contractors document ──');

  const contractorRef = doc(db, 'contractors', YS_CONTRACTOR_ID);
  const contractorSnap = await getDoc(contractorRef);

  if (contractorSnap.exists()) {
    console.log('✅ Contractors doc found:', contractorSnap.data().name);
  } else {
    console.log('❌ Contractors doc NOT FOUND for ID:', YS_CONTRACTOR_ID);
    console.log('   Go to Firebase Console → Firestore → contractors');
    console.log('   Copy the exact document ID and paste into YS_CONTRACTOR_ID above');
  }

  // ══════════════════════════════════════════
  // FIX 4 — Print all users for verification
  // ══════════════════════════════════════════
  console.log('\n── FIX 4: Current users in Firestore ──');

  const usersSnap = await getDocs(collection(db, 'users'));
  console.log(`Found ${usersSnap.size} users:\n`);

  for (const userDoc of usersSnap.docs) {
    const d = userDoc.data();
    console.log(`  ID: ${userDoc.id}`);
    console.log(`  Name: ${d.name}`);
    console.log(`  Role: ${d.role}`);
    console.log(`  contractorId: ${d.contractorId}`);
    console.log(`  isActive: ${d.isActive}`);
    console.log('  ---');
  }

  // ══════════════════════════════════════════
  // FIX 5 — Print all labours for verification
  // ══════════════════════════════════════════
  console.log('\n── FIX 5: Current labours in Firestore ──');

  const laboursSnap2 = await getDocs(collection(db, 'labours'));
  console.log(`Found ${laboursSnap2.size} labours:\n`);

  for (const labourDoc of laboursSnap2.docs) {
    const d = labourDoc.data();
    console.log(`  ID: ${labourDoc.id}`);
    console.log(`  Name: ${d.name}`);
    console.log(`  contractorId: ${d.contractorId}`);
    console.log(`  supervisorId: ${d.supervisorId}`);
    console.log(`  supervisorRef type: ${typeof d.supervisorRef}`);
    console.log(`  isActive: ${d.isActive}`);
    console.log('  ---');
  }

  console.log('\n✅ All fixes complete!');
  console.log('\nNEXT STEPS:');
  console.log('1. Check output above for any ❌ errors');
  console.log('2. Refresh your admin panel');
  console.log('3. Supervisor dropdown should now show Ramesh');
  console.log('4. Labours added from admin panel will appear in Flutter app');
}

main().catch((err) => {
  console.error('❌ Script failed:', err);
  process.exit(1);
});