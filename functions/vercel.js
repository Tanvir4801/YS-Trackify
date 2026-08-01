/**
 * functions/vercel.js
 * ─────────────────────────────────────────────────────────────────────────────
 * TrackOps Deployment Center — Firebase Cloud Functions
 *
 * Architecture:
 *   React → Firebase Auth → onCall() → Secret Manager → Vercel REST API
 *
 * Security:
 *   ✓ VERCEL_TOKEN only accessible inside process.env (never sent to client)
 *   ✓ Every function requires Firebase Auth
 *   ✓ Every function requires role === 'trackops' (verified against Firestore)
 *   ✓ Rate limiting: 30 req/min per UID (in-memory per instance)
 *   ✓ Input validation on all parameters
 *   ✓ Raw Vercel error text never forwarded to client
 *   ✓ Retry logic: 3 attempts with exponential backoff for transient failures
 *   ✓ Structured response: { success, data, timestamp } or HttpsError
 */

'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

// ─── Secret ──────────────────────────────────────────────────────────────────
// VERCEL_TOKEN is stored in Firebase Secret Manager.
// Accessed at runtime via VERCEL_TOKEN_SECRET.value() — NEVER in the client.
const VERCEL_TOKEN_SECRET = defineSecret('VERCEL_TOKEN');

// ─── Constants ────────────────────────────────────────────────────────────────
const VERCEL_API_BASE = 'https://api.vercel.com';
const RATE_LIMIT_MAX = 30;
const RATE_LIMIT_WINDOW_MS = 60_000;
const FUNCTION_CONFIG = {
  secrets: [VERCEL_TOKEN_SECRET],
  timeoutSeconds: 30,
  memory: '256MiB',
  region: 'us-central1',
};

// ─── In-Memory Rate Limiter ───────────────────────────────────────────────────
const _rl = new Map();

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
    throw new HttpsError(
      'resource-exhausted',
      'Rate limit: max 30 Vercel API requests per minute.'
    );
  }
  // Memory hygiene — prevent unbounded growth across warm instances
  if (_rl.size > 1000) _rl.clear();
}

// ─── Auth + Role Guard ────────────────────────────────────────────────────────
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

// ─── Vercel API Caller (with retry + error sanitization) ─────────────────────
async function vercelFetch(token, path, opts = {}) {
  const url = `${VERCEL_API_BASE}${path}`;
  const MAX_ATTEMPTS = 3;

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    let res;
    try {
      res = await fetch(url, {
        ...opts,
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
          ...(opts.headers || {}),
        },
      });
    } catch (netErr) {
      if (attempt === MAX_ATTEMPTS) {
        throw new HttpsError(
          'unavailable',
          'Could not reach Vercel API after retries.'
        );
      }
      await sleep(500 * attempt);
      continue;
    }

    // Vercel rate-limit — back off and retry
    if (res.status === 429) {
      if (attempt < MAX_ATTEMPTS) {
        await sleep(1000 * attempt);
        continue;
      }
      throw new HttpsError(
        'resource-exhausted',
        'Vercel API rate limit reached. Try again in a moment.'
      );
    }

    // Auth errors — fail fast, never retry
    if (res.status === 401 || res.status === 403) {
      throw new HttpsError(
        'permission-denied',
        'Vercel token is invalid or expired. Please rotate it in Secret Manager.'
      );
    }

    // Not-found — fail fast
    if (res.status === 404) {
      throw new HttpsError('not-found', `Vercel resource not found: ${path}`);
    }

    // Other non-OK responses
    if (!res.ok) {
      if (attempt === MAX_ATTEMPTS) {
        // Sanitize: log internally but never forward raw Vercel error to client
        const raw = await res.text().catch(() => '');
        console.error(`[vercelFetch] ${res.status} on ${path}: ${raw.slice(0, 500)}`);
        throw new HttpsError('internal', `Vercel API returned status ${res.status}.`);
      }
      await sleep(500 * attempt);
      continue;
    }

    return res.json();
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

// ─── Response Helper ──────────────────────────────────────────────────────────
function ok(data) {
  return { success: true, data, timestamp: new Date().toISOString() };
}

// ─── Input Sanitizer ─────────────────────────────────────────────────────────
function sanitizeId(value, field) {
  if (!value || typeof value !== 'string' || value.length > 120 || !/^[\w-]+$/.test(value)) {
    throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  }
  return value;
}

// ─── Team Query String ────────────────────────────────────────────────────────
function tqs(teamId, first = true) {
  if (!teamId) return '';
  return (first ? '?' : '&') + `teamId=${encodeURIComponent(teamId)}`;
}

// ═════════════════════════════════════════════════════════════════════════════
// FUNCTION 1: vercelGetProjectFull
// Returns: project info + latest 20 deployments + domains (one round trip each)
// ═════════════════════════════════════════════════════════════════════════════

const vercelCache = {
  projectFull: { data: null, timestamp: 0, projectId: null }
};
const TTL_VERCEL_DASHBOARD = 30 * 1000; // 30 seconds

exports.vercelGetProjectFull = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);

  const token = VERCEL_TOKEN_SECRET.value();
  const { projectId, teamId } = request.data || {};

  const now = Date.now();
  // Simple cache check matching projectId
  if (vercelCache.projectFull.data && 
      vercelCache.projectFull.projectId === projectId && 
      (now - vercelCache.projectFull.timestamp < TTL_VERCEL_DASHBOARD)) {
    return ok({ ...vercelCache.projectFull.data, fromCache: true });
  }

  // Resolve project
  let project;
  if (projectId) {
    const pid = sanitizeId(projectId, 'projectId');
    project = await vercelFetch(token, `/v9/projects/${pid}${tqs(teamId)}`);
  } else {
    // Auto-discover first project
    const list = await vercelFetch(token, `/v9/projects${tqs(teamId)}`);
    project = list.projects?.[0] || null;
  }

  if (!project) {
    throw new HttpsError('not-found', 'No Vercel project found for this token.');
  }

  const pid = project.id;
  const teamSep = tqs(teamId, false); // & form for chaining

  // Parallel: deployments + domains
  const [depsData, domsData] = await Promise.all([
    vercelFetch(token, `/v6/deployments?projectId=${pid}&limit=20${teamSep}`),
    vercelFetch(token, `/v9/projects/${pid}/domains${tqs(teamId)}`),
  ]);

  // Strip only what the frontend needs (no internal Vercel secrets)
  const deployments = (depsData.deployments || []).map((d) => ({
    uid: d.uid,
    url: d.url,
    name: d.name,
    readyState: d.readyState,
    target: d.target,
    regions: d.regions,
    createdAt: d.createdAt,
    buildingAt: d.buildingAt,
    ready: d.ready,
    outputFileSize: d.outputFileSize,
    meta: {
      githubCommitSha: d.meta?.githubCommitSha || null,
      githubCommitRef: d.meta?.githubCommitRef || null,
      githubCommitMessage: d.meta?.githubCommitMessage || null,
      githubCommitAuthorName: d.meta?.githubCommitAuthorName || null,
      githubCommitUrl: d.meta?.githubCommitUrl || null,
    },
    creator: { username: d.creator?.username || null },
    gitSource: d.gitSource
      ? { ref: d.gitSource.ref, sha: d.gitSource.sha }
      : null,
  }));

  const domains = (domsData.domains || []).map((d) => ({
    name: d.name,
    verified: d.verified,
    redirect: d.redirect || null,
    createdAt: d.createdAt,
    sslActive: (d.sslCertificate?.certs?.length || 0) > 0,
    sslExpiresAt: d.sslCertificate?.certs?.[0]?.expiresAt || null,
  }));

  const responseData = {
    project: {
      id: project.id,
      name: project.name,
      framework: project.framework || null,
      nodeVersion: project.nodeVersion || null,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
      latestDeployments: project.latestDeployments?.length || 0,
    },
    deployments,
    domains,
  };

  vercelCache.projectFull = { data: responseData, timestamp: now, projectId: projectId };
  return ok({ ...responseData, fromCache: false });
});

// ═════════════════════════════════════════════════════════════════════════════
// FUNCTION 2: vercelGetDeploymentLogs
// Returns: build event log lines for a specific deployment
// Called by: DeploymentCenter.jsx Build Logs Terminal (every 5s for active builds)
// ═════════════════════════════════════════════════════════════════════════════
exports.vercelGetDeploymentLogs = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);

  const token = VERCEL_TOKEN_SECRET.value();
  const { deploymentId, teamId } = request.data || {};

  const did = sanitizeId(deploymentId, 'deploymentId');
  const events = await vercelFetch(
    token,
    `/v2/deployments/${did}/events${tqs(teamId)}`
  );

  // Sanitize: strip ANSI codes, cap line length, limit total lines
  const lines = (Array.isArray(events) ? events : [])
    .slice(0, 500)
    .map((ev) => ({
      created: ev.created || null,
      type: ev.type || 'info',
      // Strip ANSI escape codes so they don't render as garbage
      text: (ev.text || JSON.stringify(ev))
        .replace(/\x1b\[[0-9;]*m/g, '')
        .slice(0, 1000),
    }));

  return ok({ deploymentId: did, events: lines });
});

// ═════════════════════════════════════════════════════════════════════════════
// FUNCTION 3: vercelGetDeploymentFiles
// Returns: file/function list for a deployment (to detect serverless functions)
// Called by: DeploymentCenter.jsx Functions panel (every 60s)
// ═════════════════════════════════════════════════════════════════════════════
exports.vercelGetDeploymentFiles = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);

  const token = VERCEL_TOKEN_SECRET.value();
  const { deploymentId, teamId } = request.data || {};

  const did = sanitizeId(deploymentId, 'deploymentId');
  const files = await vercelFetch(
    token,
    `/v2/deployments/${did}/files${tqs(teamId)}`
  );

  // Only return lambda (function) entries
  const functions_ = (Array.isArray(files) ? files : [])
    .filter((f) => f?.type === 'lambda')
    .map((f) => ({
      name: f.name,
      type: f.type,
      lambda: f.lambda
        ? { runtime: f.lambda.runtime || null, memory: f.lambda.memory || null }
        : null,
    }));

  return ok({ deploymentId: did, functions: functions_ });
});

// ═════════════════════════════════════════════════════════════════════════════
// FUNCTION 4: vercelRedeploy
// Triggers a redeploy of the given deployment ID
// Requires: TrackOps role, audits to mission_logs
// ═════════════════════════════════════════════════════════════════════════════
exports.vercelRedeploy = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);

  const token = VERCEL_TOKEN_SECRET.value();
  const { deploymentId, teamId } = request.data || {};

  const did = sanitizeId(deploymentId, 'deploymentId');
  const result = await vercelFetch(
    token,
    `/v13/deployments/${did}/redeploy${tqs(teamId)}`,
    { method: 'POST', body: JSON.stringify({}) }
  );

  // Audit trail
  await admin.firestore().collection('mission_logs').add({
    type: 'VERCEL_REDEPLOY',
    sourceDeploymentId: did,
    newDeploymentId: result.id || null,
    triggeredBy: uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return ok({
    newDeploymentId: result.id || null,
    url: result.url || null,
    readyState: result.readyState || null,
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// FUNCTION 5: vercelGetDeploymentAnalytics
// Computes chart data from a batch of deployments — done server-side
// so the browser never processes raw Vercel payloads
// ═════════════════════════════════════════════════════════════════════════════
exports.vercelGetDeploymentAnalytics = onCall(FUNCTION_CONFIG, async (request) => {
  const uid = await requireTrackOps(request);
  enforceRateLimit(uid);

  const token = VERCEL_TOKEN_SECRET.value();
  const { projectId, teamId } = request.data || {};

  let pid = projectId;
  if (!pid) {
    const list = await vercelFetch(token, `/v9/projects${tqs(teamId)}`);
    pid = list.projects?.[0]?.id;
    if (!pid) throw new HttpsError('not-found', 'No Vercel project found.');
  } else {
    pid = sanitizeId(projectId, 'projectId');
  }

  // Get 100 most recent deployments for analytics
  const teamSep = tqs(teamId, false);
  const data = await vercelFetch(
    token,
    `/v6/deployments?projectId=${pid}&limit=100${teamSep}`
  );

  const deps = data.deployments || [];

  // Aggregate by calendar day
  const byDay = {};
  for (const d of deps) {
    const day = new Date(d.createdAt).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
    });
    if (!byDay[day]) byDay[day] = { day, total: 0, success: 0, failed: 0, canceled: 0, durSum: 0, durCount: 0 };
    byDay[day].total++;
    if (d.readyState === 'READY') byDay[day].success++;
    if (d.readyState === 'ERROR') byDay[day].failed++;
    if (d.readyState === 'CANCELED') byDay[day].canceled++;
    if (d.buildingAt && d.ready) {
      byDay[day].durSum += (d.ready - d.buildingAt) / 1000;
      byDay[day].durCount++;
    }
  }

  const chartData = Object.values(byDay)
    .slice(-30)
    .map((d) => ({
      day: d.day,
      total: d.total,
      success: d.success,
      failed: d.failed,
      canceled: d.canceled,
      avgBuildTime: d.durCount > 0 ? Math.round(d.durSum / d.durCount) : 0,
      successRate: d.total > 0 ? Math.round((d.success / d.total) * 100) : 0,
    }));

  // Summary stats
  const totalDeps = deps.length;
  const successDeps = deps.filter((d) => d.readyState === 'READY').length;
  const failedDeps = deps.filter((d) => d.readyState === 'ERROR').length;
  const allDurations = deps
    .filter((d) => d.buildingAt && d.ready)
    .map((d) => d.ready - d.buildingAt);
  const avgBuildMs =
    allDurations.length > 0
      ? allDurations.reduce((a, b) => a + b, 0) / allDurations.length
      : 0;

  return ok({
    chartData,
    summary: {
      total: totalDeps,
      success: successDeps,
      failed: failedDeps,
      successRate: totalDeps > 0 ? Math.round((successDeps / totalDeps) * 100) : 0,
      avgBuildMs: Math.round(avgBuildMs),
    },
  });
});
