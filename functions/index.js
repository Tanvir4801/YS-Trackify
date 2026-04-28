const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// Must match Flutter app constant.
const QR_SALT = 'TRACKIFY_QR_SECRET_2026';

// Format date as YYYY-MM-DD.
function todayString() {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

// Decode token and verify time + HMAC signature.
function verifyToken(token) {
  try {
    const decoded = Buffer.from(token, 'base64url').toString('utf8');
    const parts = decoded.split('|');
    if (parts.length !== 3) {
      return null;
    }

    const [labourId, windowStr, signature] = parts;
    const windowSeconds = parseInt(windowStr, 10);

    const nowWindow = Math.floor(Date.now() / 30000);
    if (Math.abs(nowWindow - windowSeconds) > 2) {
      return { error: 'expired' };
    }

    const payload = `${labourId}|${windowSeconds}`;
    const expectedSig = crypto
      .createHmac('sha256', QR_SALT)
      .update(payload)
      .digest('hex')
      .substring(0, 16);

    if (signature !== expectedSig) {
      return { error: 'invalid_signature' };
    }

    return { labourId, windowSeconds };
  } catch (_) {
    return { error: 'decode_failed' };
  }
}

exports.validateAndMarkAttendance = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be logged in'
      );
    }

    const { token, supervisorId, date, status, offlineSync } = data;

    if (context.auth.uid !== supervisorId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Supervisor ID mismatch'
      );
    }

    const supervisorDoc = await db.collection('users').doc(supervisorId).get();

    if (!supervisorDoc.exists || supervisorDoc.data().role !== 'supervisor') {
      throw new functions.https.HttpsError('permission-denied', 'Not a supervisor');
    }

    let labourId;
    if (!offlineSync) {
      const verification = verifyToken(token);

      if (verification && verification.error === 'expired') {
        throw new functions.https.HttpsError(
          'deadline-exceeded',
          'QR code expired. Ask labour to refresh.'
        );
      }

      if (!verification || verification.error) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid QR code');
      }

      labourId = verification.labourId;
    } else {
      labourId = data.labourId;
    }

    const attendanceDate = date || todayString();

    const labourSnap = await db
      .collection('labours')
      .where('id', '==', labourId)
      .where('supervisorId', '==', supervisorId)
      .where('isActive', '==', true)
      .limit(1)
      .get();

    if (labourSnap.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        'Labour not found or not assigned to you'
      );
    }

    const labourData = labourSnap.docs[0].data();

    const existingSnap = await db
      .collection('attendance')
      .where('labourId', '==', labourId)
      .where('date', '==', attendanceDate)
      .where('supervisorId', '==', supervisorId)
      .limit(1)
      .get();

    if (!existingSnap.empty) {
      throw new functions.https.HttpsError(
        'already-exists',
        `${labourData.name} already marked for ${attendanceDate}`
      );
    }

    const attendanceRef = db.collection('attendance').doc();
    const attendanceRecord = {
      id: attendanceRef.id,
      labourId,
      supervisorId,
      date: attendanceDate,
      status: status || 'present',
      overtimeHours: 0,
      isSynced: true,
      markedVia: offlineSync ? 'offline_qr' : 'qr_scan',
      syncedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await attendanceRef.set(attendanceRecord);

    return {
      success: true,
      attendanceId: attendanceRef.id,
      labourName: labourData.name,
      labourId,
      date: attendanceDate,
      status: attendanceRecord.status,
      message: `${labourData.name} marked present`,
    };
  }
);

exports.cleanupOldAttendance = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    console.log('Cleanup job ran');
    return null;
  });
