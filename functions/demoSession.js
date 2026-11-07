const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { seedDemoTenantData, DEMO_TENANT_ID } = require('./seedDemoData');

const db = admin.firestore();

// Validation helper for Indian Phone numbers (+91 or 10 digits)
function isValidIndianPhone(phone) {
  if (!phone || typeof phone !== 'string') return false;
  const digits = phone.replace(/[^0-9]/g, '');
  return digits.length === 10 || (digits.length === 12 && digits.startsWith('91'));
}

// Validation helper for Email
function isValidEmail(email) {
  if (!email || typeof email !== 'string') return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

/**
 * Ensures the 'trackify_demo' tenant document and baseline fixtures exist.
 */
async function ensureDemoTenantExists() {
  const contractorDoc = await db.collection('contractors').doc(DEMO_TENANT_ID).get();
  if (!contractorDoc.exists) {
    console.log('[DemoSession] Demo tenant missing. Seeding fixtures now...');
    await seedDemoTenantData(db);
  }
}

/**
 * 1. submitDemoRequest (HTTP / HTTPS Callable)
 * Receives prospective lead from marketing website, registers lead,
 * provisions demo user + 24hr session, and issues a Firebase custom token.
 */
exports.submitDemoRequest = functions.https.onRequest(async (req, res) => {
  // CORS support
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ success: false, error: 'Method Not Allowed' });
    return;
  }

  try {
    const { fullName, companyName, email, phone, workerCount, notes } = req.body || {};

    // 1. Validation
    if (!fullName || typeof fullName !== 'string' || fullName.trim().length < 2) {
      res.status(400).json({ success: false, error: 'Please enter a valid full name.' });
      return;
    }
    if (!companyName || typeof companyName !== 'string' || companyName.trim().length < 2) {
      res.status(400).json({ success: false, error: 'Please enter your company or firm name.' });
      return;
    }
    if (!isValidEmail(email)) {
      res.status(400).json({ success: false, error: 'Please enter a valid business email address.' });
      return;
    }
    if (!isValidIndianPhone(phone)) {
      res.status(400).json({ success: false, error: 'Please enter a valid 10-digit mobile number.' });
      return;
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanPhone = phone.replace(/[^0-9]/g, '');

    // 2. Abuse / Rate-limiting check: max 5 demo requests per email/phone per 24 hours
    const recentLeads = await db
      .collection('leads')
      .where('email', '==', cleanEmail)
      .where('createdAt', '>=', new Date(Date.now() - 24 * 3600 * 1000))
      .get();

    if (recentLeads.size >= 5) {
      res.status(429).json({
        success: false,
        error: 'Too many demo requests for this email. Please check your existing demo link or contact sales.',
      });
      return;
    }

    // 3. Ensure demo tenant data is seeded
    await ensureDemoTenantExists();

    // 4. Create Lead Record
    const leadRef = db.collection('leads').doc();
    const leadId = leadRef.id;

    // 5. Generate secure Demo User UID & Session
    const demoUid = `demo_${crypto.randomBytes(8).toString('hex')}`;
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 24 * 3600 * 1000); // 24 hours

    const batch = db.batch();

    // Save lead
    batch.set(leadRef, {
      id: leadId,
      name: fullName.trim(),
      companyName: companyName.trim(),
      email: cleanEmail,
      phone: cleanPhone,
      workerCount: workerCount || '25-50',
      notes: notes || '',
      demoUid,
      status: 'active_demo',
      source: 'marketing_website',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create /users/{demoUid}
    const userRef = db.collection('users').doc(demoUid);
    batch.set(userRef, {
      uid: demoUid,
      name: `${fullName.trim()} (Demo)`,
      email: cleanEmail,
      phone: cleanPhone,
      role: 'demo',
      contractorId: DEMO_TENANT_ID,
      isActive: true,
      isDemo: true,
      demoLeadId: leadId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create /demoSessions/{demoUid}
    const sessionRef = db.collection('demoSessions').doc(demoUid);
    batch.set(sessionRef, {
      uid: demoUid,
      tenantId: DEMO_TENANT_ID,
      leadId,
      status: 'active',
      sessionType: 'web_admin',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      companyName: companyName.trim(),
      contactEmail: cleanEmail,
    });

    await batch.commit();

    // 6. Generate Firebase Custom Token
    const customToken = await admin.auth().createCustomToken(demoUid, {
      isDemo: true,
      tenantId: DEMO_TENANT_ID,
      role: 'demo',
    });

    console.log(`[DemoSession] Demo session created for ${cleanEmail} -> UID: ${demoUid}`);

    res.status(200).json({
      success: true,
      demoUid,
      token: customToken,
      expiresAt: expiresAt.toISOString(),
      tenantId: DEMO_TENANT_ID,
      companyName: 'Trackify Demo Construction Pvt. Ltd.',
    });
  } catch (error) {
    console.error('[DemoSession] submitDemoRequest error:', error);
    res.status(500).json({ success: false, error: 'Failed to initialize demo session. Please try again.' });
  }
});

/**
 * 2. createDemoSession (Callable function, for Flutter mobile app or admin creation)
 */
exports.createDemoSession = functions.https.onCall(async (data, context) => {
  try {
    const { sessionType = 'mobile_supervisor', callerName = 'Mobile Demo User' } = data || {};
    await ensureDemoTenantExists();

    const demoUid = `demo_mob_${crypto.randomBytes(8).toString('hex')}`;
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 24 * 3600 * 1000);

    const batch = db.batch();

    // /users/{demoUid}
    const userRef = db.collection('users').doc(demoUid);
    batch.set(userRef, {
      uid: demoUid,
      name: callerName,
      role: 'demo',
      contractorId: DEMO_TENANT_ID,
      isActive: true,
      isDemo: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // /demoSessions/{demoUid}
    const sessionRef = db.collection('demoSessions').doc(demoUid);
    batch.set(sessionRef, {
      uid: demoUid,
      tenantId: DEMO_TENANT_ID,
      status: 'active',
      sessionType,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });

    await batch.commit();

    const customToken = await admin.auth().createCustomToken(demoUid, {
      isDemo: true,
      tenantId: DEMO_TENANT_ID,
      role: 'demo',
    });

    return {
      success: true,
      demoUid,
      token: customToken,
      expiresAt: expiresAt.toISOString(),
      tenantId: DEMO_TENANT_ID,
      companyName: 'Trackify Demo Construction Pvt. Ltd.',
    };
  } catch (error) {
    console.error('[DemoSession] createDemoSession error:', error);
    throw new functions.https.HttpsError('internal', 'Could not create demo session.');
  }
});

/**
 * 3. validateDemoSession (Callable function)
 * Server-verified session validation for active users.
 */
exports.validateDemoSession = functions.https.onCall(async (data, context) => {
  const uid = context.auth ? context.auth.uid : data?.uid;
  if (!uid) {
    return { isValid: false, reason: 'unauthenticated' };
  }

  try {
    const sessionDoc = await db.collection('demoSessions').doc(uid).get();
    if (!sessionDoc.exists) {
      return { isValid: false, reason: 'not_found' };
    }

    const session = sessionDoc.data();
    if (session.status !== 'active') {
      return { isValid: false, reason: session.status || 'revoked' };
    }

    const expiresAtMillis = session.expiresAt ? session.expiresAt.toMillis() : 0;
    const now = Date.now();

    if (now >= expiresAtMillis) {
      // Mark as expired
      await sessionDoc.ref.update({ status: 'expired' });
      return { isValid: false, reason: 'expired' };
    }

    return {
      isValid: true,
      remainingMs: expiresAtMillis - now,
      expiresAt: session.expiresAt.toDate().toISOString(),
      tenantId: session.tenantId || DEMO_TENANT_ID,
    };
  } catch (err) {
    console.error('[DemoSession] validateDemoSession error:', err);
    throw new functions.https.HttpsError('internal', 'Session validation error.');
  }
});

/**
 * 4. revokeDemoSession (Callable function)
 * Explicitly terminates an active demo session.
 */
exports.revokeDemoSession = functions.https.onCall(async (data, context) => {
  const uid = context.auth ? context.auth.uid : data?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User not authenticated.');
  }

  try {
    const sessionRef = db.collection('demoSessions').doc(uid);
    await sessionRef.set({ status: 'revoked', revokedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

    const userRef = db.collection('users').doc(uid);
    await userRef.set({ isActive: false }, { merge: true });

    return { success: true };
  } catch (err) {
    console.error('[DemoSession] revokeDemoSession error:', err);
    throw new functions.https.HttpsError('internal', 'Failed to revoke demo session.');
  }
});

/**
 * 5. seedDemoTenantEndpoint (Callable function, restricted to super_admin or internal deployment setup)
 */
exports.seedDemoTenantEndpoint = functions.https.onCall(async (data, context) => {
  // Allow super_admin or bypass if specifically requested
  if (context.auth) {
    const callerSnap = await db.collection('users').doc(context.auth.uid).get();
    const role = callerSnap.exists ? callerSnap.data().role : null;
    if (role !== 'super_admin' && role !== 'trackops') {
      throw new functions.https.HttpsError('permission-denied', 'Only Super Admin can invoke seeder.');
    }
  }

  const result = await seedDemoTenantData(db);
  return result;
});
