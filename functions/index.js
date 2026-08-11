const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// ─── Vercel Deployment Center Functions ───────────────────────────────────────
// All Vercel API calls are proxied through these Cloud Functions.
// The VERCEL_TOKEN secret is accessed only inside these functions.
const vercelFunctions = require('./vercel');
exports.vercelGetProjectFull       = vercelFunctions.vercelGetProjectFull;
exports.vercelGetDeploymentLogs    = vercelFunctions.vercelGetDeploymentLogs;
exports.vercelGetDeploymentFiles   = vercelFunctions.vercelGetDeploymentFiles;
exports.vercelRedeploy             = vercelFunctions.vercelRedeploy;
exports.vercelGetDeploymentAnalytics = vercelFunctions.vercelGetDeploymentAnalytics;

// ─── TrackOps Dashboards & Analytics ──────────────────────────────────────────
const trackopsFunctions = require('./trackops');
exports.trackopsGetAnalytics     = trackopsFunctions.trackopsGetAnalytics;
exports.trackopsGetBilling       = trackopsFunctions.trackopsGetBilling;
exports.trackopsGetPaginatedLogs = trackopsFunctions.trackopsGetPaginatedLogs;

// Must match Flutter app constant.
const QR_SALT = 'TRACKIFY_QR_SECRET_2026';

// In-memory rate limiting for serverless instance
const rateLimitMap = new Map();

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

    // Basic rate limit: max 1 request per 3 seconds per supervisor (in-memory)
    const now = Date.now();
    if (rateLimitMap.has(supervisorId)) {
        if (now - rateLimitMap.get(supervisorId) < 3000) {
            // Log api abuse asynchronously
            db.collection('security_events').add({
                type: 'api_abuse',
                uid: supervisorId,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                reason: 'validateAndMarkAttendance rate limit exceeded (in-memory cooldown)'
            }).catch(console.error);
            throw new functions.https.HttpsError('resource-exhausted', 'Please wait before scanning again.');
        }
    }
    rateLimitMap.set(supervisorId, now);
    if (rateLimitMap.size > 1000) rateLimitMap.clear(); // Basic memory protection

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

    const attendanceRef = db.collection('attendance').doc(`att_${labourId}_${attendanceDate}`);
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

    try {
      await attendanceRef.create(attendanceRecord);
    } catch (error) {
      if (error.code === 6) { // ALREADY_EXISTS
        throw new functions.https.HttpsError(
          'already-exists',
          `${labourData.name} already marked for ${attendanceDate}`
        );
      }
      throw error;
    }

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



exports.cleanupOldLogs = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
    const batchSize = 500;
    
    async function deleteCollectionOld(collectionPath) {
      const query = db.collection(collectionPath)
        .where('timestamp', '<', ninetyDaysAgo)
        .limit(batchSize);

      const snapshot = await query.get();
      if (snapshot.size === 0) return;

      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      
      // If there are more, they will be deleted in the next run tomorrow.
    }

    await deleteCollectionOld('security_events');
    await deleteCollectionOld('activity_log');
    await deleteCollectionOld('telemetry_events'); // Also cleanup old telemetry
    
    console.log('Old logs cleanup ran');
    return null;
  });

exports.aggregateTelemetry = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async () => {
    try {
      const db = admin.firestore();
      const snap = await db.collection('telemetry_events')
        .orderBy('timestamp', 'desc')
        .limit(200)
        .get();

      let totalRequests = 0;
      let totalDuration = 0;
      let perfEventsCount = 0;
      const featureCounts = {};
      const featureSuccess = {};

      snap.forEach((docSnap) => {
        const data = docSnap.data();
        totalRequests++;

        if (data.eventType === 'performance_metric' && data.additionalMetadata?.durationMs) {
          totalDuration += data.additionalMetadata.durationMs;
          perfEventsCount++;
        }

        const feature = data.featureName || data.eventType;
        if (feature) {
          if (!featureCounts[feature]) featureCounts[feature] = 0;
          if (!featureSuccess[feature]) featureSuccess[feature] = 0;
          
          featureCounts[feature]++;
          const duration = data.additionalMetadata?.durationMs || 0;
          if (duration < 5000) {
            featureSuccess[feature]++;
          }
        }
      });

      const avgLatency = perfEventsCount > 0 ? Math.round(totalDuration / perfEventsCount) : 0;

      const infra = [
        { id: 'firestore_main', name: 'Firestore DB', status: avgLatency > 2000 ? 'YELLOW' : 'GREEN', latencyMs: avgLatency > 0 ? avgLatency : 45, details: 'Real-time sync latency based on client events.' },
        { id: 'auth_service', name: 'Firebase Auth', status: 'GREEN', latencyMs: avgLatency > 0 ? Math.round(avgLatency * 0.8) : 30, details: 'Authentication response times.' }
      ];

      for (const item of infra) {
        await db.collection('infrastructure_metrics').doc(item.id).set(item);
      }

      const services = [];
      const enginesToTrack = ['attendance_sync', 'screen_open', 'login'];
      
      enginesToTrack.forEach(engine => {
        const count = featureCounts[engine] || 0;
        const success = featureSuccess[engine] || 0;
        const rate = count > 0 ? Math.round((success / count) * 100) : 100;
        
        services.push({
          id: engine, name: engine.replace('_', ' ').toUpperCase(), status: rate < 90 ? 'YELLOW' : 'GREEN', successRate: rate, failedRequests: count - success,
        });
      });

      for (const item of services) {
        await db.collection('service_metrics').doc(item.id).set(item);
      }

      const health = {
        missionHealthPercentage: avgLatency > 2000 ? 85 : 100,
        totalRequests: totalRequests,
        estimatedCosts: (totalRequests * 0.0001).toFixed(2), 
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      await db.collection('system_health').doc('global').set(health);
      console.log('Telemetry Aggregation completed');
    } catch (e) {
      console.error('Telemetry Aggregation Failed:', e);
    }
    return null;
  });

exports.onSupportTicketUpdate = functions.firestore
  .document('support_tickets/{ticketId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const ticketId = context.params.ticketId;

    if (!after.userId) return null;

    let notificationTitle = null;
    let notificationBody = null;

    // Check for status change
    if (before.status !== after.status) {
      notificationTitle = 'Support Ticket Update';
      if (after.status === 'Resolved' || after.status === 'Closed') {
        notificationBody = `Your ticket (${ticketId.substring(0,8).toUpperCase()}) has been marked as ${after.status}.`;
      } else {
        notificationBody = `The status of your ticket has changed to ${after.status}.`;
      }
    }

    // Check for new replies
    const beforeHistory = before.history || [];
    const afterHistory = after.history || [];
    if (afterHistory.length > beforeHistory.length) {
      const latest = afterHistory[afterHistory.length - 1];
      if (latest.type === 'reply' && latest.createdBy !== after.userName) {
        notificationTitle = `New Reply from ${latest.createdBy}`;
        notificationBody = `"${latest.text.substring(0, 50)}${latest.text.length > 50 ? '...' : ''}"`;
      }
    }

    if (!notificationTitle) return null;

    // If it's a labour, save it as an in-app notification since they don't use FCM
    if (after.userRole === 'labour') {
      await db.collection('labours').doc(after.userId).collection('notifications').add({
        title: notificationTitle,
        message: notificationBody,
        type: 'support_ticket',
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`Saved in-app notification for Labour ${after.userId} for ticket ${ticketId}`);
      return null;
    }

    // Otherwise, it's a user/supervisor with FCM
    const userSnap = await db.collection('users').doc(after.userId).get();
    if (!userSnap.exists) return null;

    const fcmToken = userSnap.data().fcmToken;
    if (!fcmToken) return null;

    const payload = {
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        type: 'support_ticket',
        ticketId: ticketId
      }
    };

    try {
      await admin.messaging().sendToDevice(fcmToken, payload);
      console.log(`FCM sent to ${after.userId} for ticket ${ticketId}`);
    } catch (error) {
      console.error(`Failed to send FCM to ${after.userId}:`, error);
    }
    
    return null;
  });

exports.onSecurityEventCreated = functions.firestore
  .document('security_events/{eventId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    // To prevent infinite loops, check if aiAnalysis already exists
    if (data.aiAnalysis) return null;

    // Rate Limiting
    const rateLimitRef = admin.firestore().collection('system_status').doc('ai_rate_limit');
    const rateLimitDoc = await rateLimitRef.get();
    const now = Date.now();
    if (rateLimitDoc.exists) {
      const lastCall = rateLimitDoc.data().lastSecurityCall || 0;
      if (now - lastCall < 5000) {
        console.log('Skipping Gemini security analysis due to rate limit.');
        return null; // Skip if called within 5 seconds
      }
    }
    await rateLimitRef.set({ lastSecurityCall: now }, { merge: true });

    const prompt = `You are the Trackify AI Security Guard. Analyze this new security event:
Event Type: ${data.type || 'Unknown'}
User Email: ${data.email || 'Unknown'}
User ID: ${data.uid || 'Unknown'}
IP Address: ${data.ip || 'Unknown'}
Details/Reason: ${data.reason || JSON.stringify(data)}

Based on this, suggest ONE action from the following exact list: BLOCK_USER, FORCE_LOGOUT, LOCK_ACCOUNT, NOTIFY_ADMIN, or IGNORE.
Provide a short 1-sentence reason for your choice.
You MUST output ONLY a valid JSON object in this exact format, with no markdown formatting or extra text:
{"action": "BLOCK_USER", "reason": "Your reason here"}`;

    const aiResponse = await askGemini(prompt);
    
    if (aiResponse) {
      try {
        // Try to parse the JSON (removing any markdown backticks if Gemini added them)
        const cleanJson = aiResponse.replace(/```json/g, '').replace(/```/g, '').trim();
        const parsed = JSON.parse(cleanJson);
        
        await snap.ref.update({
          aiAnalysis: {
            action: parsed.action || 'IGNORE',
            reason: parsed.reason || 'AI analyzed the event but provided no specific reason.',
            timestamp: new Date().toISOString()
          }
        });
        console.log(`Added AI Analysis to security event ${context.params.eventId}: ${parsed.action}`);
      } catch (err) {
        console.error('Failed to parse Gemini security response as JSON:', aiResponse, err);
      }
    }
  });

exports.executeSecurityAction = functions.https.onCall(async (data, context) => {
  // Only Super Admins can execute this
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only Super Admins can execute security actions.');
  }

  const { action, targetUid, targetEmail, eventId } = data;
  if (!action || !targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing action or targetUid.');
  }

  try {
    if (action === 'BLOCK_USER' || action === 'LOCK_ACCOUNT') {
      await admin.auth().updateUser(targetUid, { disabled: true });
    } else if (action === 'FORCE_LOGOUT') {
      await admin.auth().revokeRefreshTokens(targetUid);
      // Also update Firestore to invalidate current sessions client-side
      await admin.firestore().collection('users').doc(targetUid).update({
        sessionValidSince: admin.firestore.FieldValue.serverTimestamp(),
        forceLogoutReason: 'Security guard enforcement'
      }).catch(() => {}); // Ignore if user doc doesn't exist
    }

    // Log the operation
    await admin.firestore().collection('operation_logs').add({
      action: action,
      targetId: targetUid,
      targetEmail: targetEmail || 'Unknown',
      performedBy: 'AI_Security_Guard_Executed_By_' + context.auth.uid,
      eventId: eventId,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, message: `Successfully executed ${action} on ${targetUid}` };
  } catch (error) {
    console.error(`Error executing ${action}:`, error);
    throw new functions.https.HttpsError('internal', `Failed to execute ${action}.`);
  }
});

// ==========================================
// AUTONOMOUS AI AGENTS (Sleep-Mode Ops)
// ==========================================

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

async function askGemini(prompt) {
  if (!GEMINI_API_KEY) {
    console.error("Missing GEMINI_API_KEY in environment variables.");
    return null;
  }
  
  try {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${GEMINI_API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }]
      })
    });
    
    if (!response.ok) {
      console.error('Gemini API Error:', await response.text());
      return null;
    }
    
    const data = await response.json();
    return data.candidates?.[0]?.content?.parts?.[0]?.text || null;
  } catch (error) {
    console.error('Failed to contact Gemini:', error);
    return null;
  }
}


exports.autoIncidentTriage = functions.firestore
  .document('error_logs/{errorId}')
  .onCreate(async (snap, context) => {
    const errorLog = snap.data();
    
    // Only analyze CRITICAL errors while admin is away
    if (errorLog.severity !== 'CRITICAL') return null;

    // Rate Limiting
    const rateLimitRef = admin.firestore().collection('system_status').doc('ai_rate_limit');
    const rateLimitDoc = await rateLimitRef.get();
    const now = Date.now();
    if (rateLimitDoc.exists) {
      const lastCall = rateLimitDoc.data().lastTriageCall || 0;
      if (now - lastCall < 5000) {
        console.log('Skipping Gemini incident triage due to rate limit.');
        return null; // Skip if called within 5 seconds
      }
    }
    await rateLimitRef.set({ lastTriageCall: now }, { merge: true });

    const stackTrace = errorLog.stackTrace ? errorLog.stackTrace.substring(0, 1500) : 'None';

    const prompt = `You are the Trackify Autonomous Security & Ops Agent. 
A CRITICAL error has just occurred in production. 

Error: ${errorLog.message}
Module: ${errorLog.module}
Stack Trace: ${stackTrace}

Does this error indicate a catastrophic failure that risks data corruption or severe security breaches (e.g. database dropped, firestore rules bypassed, massive memory leak)?
Respond with EXACTLY "MAINTENANCE_REQUIRED" if the system must be shut down immediately to protect user data.
Respond with "SAFE" if it is just a standard crash that can wait until morning.`;

    const aiResponse = await askGemini(prompt);
    
    if (aiResponse && aiResponse.includes('MAINTENANCE_REQUIRED')) {
      console.error(`🚨 AI Agent triggered MAINTENANCE MODE due to error: ${context.params.errorId}`);
      
      // Auto-trigger Maintenance Mode
      await db.collection('system_status').doc('health').set({
        maintenance: true,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        maintenanceReason: 'Autonomous AI Lockdown: Critical data safety threat detected.'
      }, { merge: true });
      
      // Update error status to show it was triaged
      await snap.ref.update({
        status: 'INVESTIGATING',
        history: admin.firestore.FieldValue.arrayUnion({
          status: 'INVESTIGATING',
          timestamp: new Date().toISOString(),
          updatedBy: 'AI Ops Agent',
          note: 'AI detected catastrophic threat and enabled Maintenance Mode.'
        })
      });
    }
  });

exports.onBillingAlert = functions.pubsub.topic('firebase-billing-alerts').onPublish(async (message) => {
  try {
    const dataString = message.data ? Buffer.from(message.data, 'base64').toString() : '{}';
    const data = JSON.parse(dataString);
    
    // Google Cloud Billing Pub/Sub JSON structure usually contains:
    // costAmount, budgetAmount, currencyCode
    await db.collection('system_status').doc('billing').set({
      costAmount: data.costAmount || 0,
      budgetAmount: data.budgetAmount || 0,
      currencyCode: data.currencyCode || 'USD',
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      rawData: data // just in case we want to see what else Google sends
    }, { merge: true });
    
    console.log('Successfully updated billing info from budget alert!');
  } catch (error) {
    console.error('Error processing billing alert:', error);
  }
});
