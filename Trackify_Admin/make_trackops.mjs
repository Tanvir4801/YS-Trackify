import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { readFileSync } from 'fs';

// Use standard service account
const serviceAccount = JSON.parse(readFileSync('./firebase-adminsdk.json', 'utf8'));

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();
const auth = getAuth();

async function makeTrackOps(email) {
  try {
    const userRecord = await auth.getUserByEmail(email);
    const uid = userRecord.uid;

    await db.collection('users').doc(uid).update({
      role: 'trackops',
      updatedAt: new Date()
    });

    console.log(`Successfully made ${email} a trackops user (UID: ${uid})`);
  } catch (err) {
    console.error('Error:', err);
  }
}

// Example usage: node make_trackops.mjs your-email@example.com
const email = process.argv[2];
if (email) {
  makeTrackOps(email);
} else {
  console.log("Please provide an email. Example: node make_trackops.mjs test@test.com");
}
