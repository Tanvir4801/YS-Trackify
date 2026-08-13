/**
 * functions/infralens.js
 * ─────────────────────────────────────────────────────────────────────────────
 * TrackOps InfraLens Integration — Firebase Cloud Functions
 *
 * Architecture:
 *   React → Firebase Auth → onCall() → Secret Manager → InfraLens API
 *
 * Security & Cost Control:
 *   ✓ INFRALENS_API_KEY only accessible inside process.env
 *   ✓ Every function requires Firebase Auth and trackops/super_admin role
 *   ✓ UID-based rate limiting
 *   ✓ Server-side in-memory caching to prevent duplicate API hits
 *   ✓ Strict upstream timeout (8s) so Firebase functions don't hang
 */

'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const admin = require('firebase-admin');

// ─── Configuration ─────────────────────────────────────────────────────────────
const INFRALENS_API_KEY = defineSecret('INFRALENS_API_KEY');
const INFRALENS_URL = defineString('INFRALENS_URL'); // No default, must be explicitly set

const FUNCTION_CONFIG = {
  secrets: [INFRALENS_API_KEY],
  timeoutSeconds: 30,
  memory: '256MiB',
  region: 'us-central1',
  enforceAppCheck: true,
};

// Rate Limiting Config
const RATE_LIMIT_MAX = 30; // Max 30 requests per minute per UID
const RATE_LIMIT_WINDOW_MS = 60_000;
const _rl = new Map();

// Caching Config
const cache = {
  overview: { data: null, timestamp: 0 },
  alerts: { data: null, timestamp: 0 },
  health: { data: null, timestamp: 0 },
  kubernetes: { data: null, timestamp: 0 },
  containers: { data: null, timestamp: 0 },
  forecast: { data: null, timestamp: 0 },
};
const TTL_OVERVIEW = 30 * 1000;
const TTL_ALERTS = 30 * 1000;
const TTL_FORECAST = 60 * 1000;

// ─── Rate Limiter ────────────────────────────────────────────────────────────
function enforceRateLimit(uid) {
  const now = Date.now();
  if (!_rl.has(uid)) {
    _rl.set(uid, { count: 1, start: now });
    return;
  }
  const entry = _rl.get(uid);
  if (now - entry.start > RATE_LIMIT_WINDOW_MS) {
    _rl.set(uid, { count: 1, start: now });
    return;
  }
  entry.count++;
  if (entry.count > RATE_LIMIT_MAX) {
    throw new HttpsError('resource-exhausted', 'InfraLens refresh temporarily limited.');
  }
  if (_rl.size > 1000) _rl.clear();
}

// ─── Auth + Role Guard ───────────────────────────────────────────────────────
async function requireTrackOps(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  const uid = request.auth.uid;
  const db = admin.firestore();
  const snap = await db.collection('users').doc(uid).get();
  
  if (!snap.exists) {
    throw new HttpsError('permission-denied', 'User profile not found.');
  }
  
  const role = snap.data().role;
  if (role !== 'trackops' && role !== 'super_admin') {
    throw new HttpsError('permission-denied', 'Requires TrackOps clearance.');
  }
  return uid;
}

// ─── InfraLens API Caller ────────────────────────────────────────────────────
async function fetchInfraLens(path, method = 'GET') {
  let baseUrl;
  try {
    baseUrl = INFRALENS_URL.value();
  } catch (err) {
    return { success: false, status: 'UNAVAILABLE', message: 'InfraLens URL is not configured on the server.' };
  }

  if (!baseUrl) {
    return { success: false, status: 'UNAVAILABLE', message: 'InfraLens URL configuration is empty.' };
  }

  // Prevent production from hitting localhost
  const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
  if (!isEmulator && (baseUrl.includes('localhost') || baseUrl.includes('127.0.0.1'))) {
    return { success: false, status: 'UNAVAILABLE', message: 'Configuration Error: Localhost is not permitted in production.' };
  }

  const url = `${baseUrl}${path}`;
  const token = INFRALENS_API_KEY.value();

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 8000); // 8s timeout

  try {
    const res = await fetch(url, {
      method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        'ngrok-skip-browser-warning': 'true'
      },
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    if (!res.ok) {
      if (res.status === 401 || res.status === 403) {
        throw new HttpsError('permission-denied', 'InfraLens authentication failed.');
      }
      return { success: false, status: 'UNAVAILABLE', message: `InfraLens returned status ${res.status}` };
    }

    const rawText = await res.text();
    let data;
    try {
      data = JSON.parse(rawText);
    } catch (parseError) {
      console.error("Tunnel error or invalid JSON received. Raw text:", rawText.substring(0, 500));
      return { success: false, status: 'UNAVAILABLE', message: 'Unable to reach InfraLens API. Received HTML instead of JSON.' };
    }

    return { success: true, data };
  } catch (error) {
    clearTimeout(timeoutId);
    console.error("Fetch threw an error:", error.message, "URL was:", url);
    if (error.name === 'AbortError') {
      return { success: false, status: 'TIMEOUT', message: 'InfraLens is taking too long to respond.' };
    }
    return { success: false, status: 'UNAVAILABLE', message: 'Unable to reach InfraLens API.' };
  }
}

// ─── Cloud Functions ─────────────────────────────────────────────────────────

exports.infralensGetOverview = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);

  const now = Date.now();
  if (cache.overview.data && (now - cache.overview.timestamp < TTL_OVERVIEW)) {
    return { success: true, data: cache.overview.data, fromCache: true };
  }

  const result = await fetchInfraLens('/api/v1/overview');
  if (result.success) {
    cache.overview = { data: result.data, timestamp: now };
  }
  return result;
});

exports.infralensGetAlerts = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);

  const now = Date.now();
  if (cache.alerts.data && (now - cache.alerts.timestamp < TTL_ALERTS)) {
    return { success: true, data: cache.alerts.data, fromCache: true };
  }

  const result = await fetchInfraLens('/api/v1/alerts');
  if (result.success) {
    cache.alerts = { data: result.data, timestamp: now };
  }
  return result;
});

exports.infralensGetIncidentDetails = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);

  const { incidentId } = request.data || {};
  if (!incidentId) throw new HttpsError('invalid-argument', 'Incident ID required');

  // Fetched on-demand
  return await fetchInfraLens(`/api/v1/incidents/${incidentId}`);
});

exports.infralensGetHealth = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);
  
  // Health is lightweight, short TTL
  const result = await fetchInfraLens('/api/v1/health');
  return result;
});

exports.infralensGetKubernetes = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);
  return await fetchInfraLens('/api/v1/kubernetes');
});

exports.infralensGetContainers = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);
  return await fetchInfraLens('/api/v1/containers');
});

exports.infralensGetForecast = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);

  const now = Date.now();
  if (cache.forecast.data && (now - cache.forecast.timestamp < TTL_FORECAST)) {
    return { success: true, data: cache.forecast.data, fromCache: true };
  }

  const result = await fetchInfraLens('/api/v1/forecast');
  if (result.success) {
    cache.forecast = { data: result.data, timestamp: now };
  }
  return result;
});
