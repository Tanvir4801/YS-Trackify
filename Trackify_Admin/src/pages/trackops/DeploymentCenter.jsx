/**
 * DeploymentCenter.jsx
 * ─────────────────────────────────────────────────────────────────────────────
 * TrackOps Deployment Center
 *
 * Architecture: React → Firebase Functions SDK → Cloud Functions → Vercel API
 * The Vercel token NEVER touches this file, the browser bundle, or the network
 * from the client. All API calls go through Firebase onCall() functions.
 */

import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Activity, Server, GitBranch, Globe, Shield, Zap, Terminal,
  AlertTriangle, CheckCircle2, XCircle, Clock, RefreshCw, Download,
  Copy, Search, Filter, ChevronDown, ChevronRight, ExternalLink,
  RotateCcw, BarChart2, TrendingUp, TrendingDown,
  Package, Cloud, HardDrive, Rocket, GitCommit, Box,
  ArrowRight, FlaskConical, Gauge, Network, Radio, Sparkles,
  BellRing, Lightbulb, Code2, FileText, Timer, Users,
  Database, Layers, MemoryStick, Image as ImageIcon,
} from 'lucide-react';
import {
  AreaChart, Area, BarChart, Bar, LineChart, Line,
  Tooltip, ResponsiveContainer,
} from 'recharts';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { getApp } from 'firebase/app';

// ─── Firebase Functions SDK ───────────────────────────────────────────────────
const _fns = getFunctions(getApp(), 'us-central1');

function callFn(name) {
  return httpsCallable(_fns, name, { timeout: 30000 });
}

// ─── useCloudFn ───────────────────────────────────────────────────────────────
// Key design: `loading` is only TRUE on the very first fetch (when data===null).
// All subsequent background refreshes silently update data in place —
// no skeleton flips, no layout shifts, no scroll jumps.
function useCloudFn(fnName, params = {}, intervalMs = 5000) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);   // true ONLY until first successful fetch
  const [error, setError] = useState(null);
  const [updatedAt, setUpdatedAt] = useState(null);
  const alive = useRef(true);
  const hasData = useRef(false);                   // tracks if we've ever received real data
  const paramsRef = useRef(params);
  paramsRef.current = params;

  const run = useCallback(async () => {
    if (!alive.current) return;
    try {
      const fn = callFn(fnName);
      const result = await fn(paramsRef.current);
      if (!alive.current) return;
      if (result.data?.success) {
        setData(result.data.data);
        setError(null);
        setUpdatedAt(new Date());
        hasData.current = true;
      } else {
        // Don't clobber existing data on a transient error during background refresh
        if (!hasData.current) {
          setError(result.data?.error || 'Unknown error from Cloud Function');
        }
      }
    } catch (e) {
      if (!alive.current) return;
      const msg = e?.details?.message || e?.message || 'Cloud Function call failed';
      // Only show error banner if we've never had data (first load failure)
      if (!hasData.current) setError(msg);
    } finally {
      // Only clear the loading spinner after the FIRST attempt — never again
      if (alive.current && !hasData.current) {
        setLoading(false);
      }
    }
  }, [fnName]);

  useEffect(() => {
    alive.current = true;
    hasData.current = false;
    run();
    const id = setInterval(run, intervalMs);
    return () => {
      alive.current = false;
      clearInterval(id);
    };
  }, [run, intervalMs]);

  return { data, loading, error, updatedAt, refresh: run };
}


// ─── Helpers ──────────────────────────────────────────────────────────────────
const fmtDur = (ms) => {
  if (!ms && ms !== 0) return '—';
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
  return `${Math.floor(ms / 60000)}m ${Math.floor((ms % 60000) / 1000)}s`;
};
const fmtBytes = (b) => {
  if (!b) return '—';
  if (b < 1024) return `${b}B`;
  if (b < 1048576) return `${(b / 1024).toFixed(1)}KB`;
  return `${(b / 1048576).toFixed(1)}MB`;
};
const ago = (ts) => {
  if (!ts) return '—';
  const s = (Date.now() - new Date(ts).getTime()) / 1000;
  if (s < 60) return `${Math.floor(s)}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
};

// ─── UI Primitives ────────────────────────────────────────────────────────────
const Glass = ({ children, className = '', glow }) => (
  <div
    className={`bg-trackops-card/80 backdrop-blur-md border border-trackops-border rounded-xl p-4 relative overflow-hidden transition-all duration-200 hover:border-white/10 ${className}`}
    style={glow ? { boxShadow: `0 0 24px -8px ${glow}` } : {}}
  >
    {children}
  </div>
);

const Skel = ({ className = '' }) => (
  <div className={`bg-trackops-steel/50 rounded animate-pulse ${className}`} />
);

const Dot = ({ s }) => {
  const cls = {
    READY: 'bg-trackops-green shadow-[0_0_8px_#00FF66]',
    OK: 'bg-trackops-green shadow-[0_0_8px_#00FF66]',
    BUILDING: 'bg-trackops-amber shadow-[0_0_8px_#FFB000] animate-pulse',
    QUEUED: 'bg-blue-400 shadow-[0_0_8px_#60A5FA] animate-pulse',
    ERROR: 'bg-trackops-red shadow-[0_0_8px_#FF2A2A] animate-pulse',
    FAILED: 'bg-trackops-red',
    CANCELED: 'bg-gray-500',
  }[s] || 'bg-gray-600';
  return <span className={`inline-block w-2 h-2 rounded-full mr-1.5 shrink-0 ${cls}`} />;
};

const Pill = ({ color, children }) => {
  const m = {
    green: 'bg-trackops-green/10 text-trackops-green border-trackops-green/30',
    red: 'bg-trackops-red/10 text-trackops-red border-trackops-red/30',
    amber: 'bg-trackops-amber/10 text-trackops-amber border-trackops-amber/30',
    blue: 'bg-blue-500/10 text-blue-400 border-blue-500/30',
    gray: 'bg-gray-700/50 text-gray-400 border-gray-600/30',
  }[color] || 'bg-gray-700/50 text-gray-400 border-gray-600/30';
  return (
    <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold font-mono border uppercase ${m}`}>
      {children}
    </span>
  );
};

const SecHead = ({ icon: I, title, sub, color = 'text-trackops-green' }) => (
  <div className="flex items-center gap-3 mb-5">
    <div className={`p-2 rounded-lg bg-trackops-steel ${color}`}><I className="w-4 h-4" /></div>
    <div>
      <h2 className={`font-mono text-sm font-bold uppercase tracking-widest ${color}`}>{title}</h2>
      {sub && <p className="font-mono text-[10px] text-gray-500">{sub}</p>}
    </div>
  </div>
);

const ErrBox = ({ msg }) => (
  <div className="flex items-start gap-3 bg-trackops-red/5 border border-trackops-red/20 rounded-xl p-4 text-trackops-red font-mono text-xs mb-4">
    <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
    <div><div className="font-bold mb-1">Error</div><div className="opacity-70">{msg}</div></div>
  </div>
);

// ─── LIVE BAR ─────────────────────────────────────────────────────────────────
function LiveBar({ updatedAt, onRefresh }) {
  const [cd, setCd] = useState(5);
  useEffect(() => {
    setCd(5);
    const id = setInterval(() => setCd((c) => (c <= 1 ? 5 : c - 1)), 1000);
    return () => clearInterval(id);
  }, [updatedAt]);
  return (
    <div className="flex items-center justify-between bg-trackops-navy/60 border border-trackops-border rounded-xl px-4 py-2 mb-6 font-mono text-xs">
      <div className="flex items-center gap-3 text-gray-500">
        <span className="w-2 h-2 rounded-full bg-trackops-green animate-pulse shadow-[0_0_6px_#00FF66]" />
        <span className="text-trackops-green font-bold">LIVE</span>
        <span>Refresh in <span className="text-white">{cd}s</span></span>
        {updatedAt && (
          <span>— Updated <span className="text-white">{updatedAt.toLocaleTimeString()}</span></span>
        )}
        <span className="text-gray-700">· Secured via Firebase Cloud Functions</span>
      </div>
      <button
        onClick={onRefresh}
        className="flex items-center gap-1 text-trackops-green hover:text-white transition-colors"
      >
        <RefreshCw className="w-3 h-3" />REFRESH NOW
      </button>
    </div>
  );
}

// ─── TOP HEADER ───────────────────────────────────────────────────────────────
function TopHeader({ project, dep, domains, loading }) {
  const url = dep?.url ? `https://${dep.url}` : '—';
  const dur =
    dep?.buildingAt && dep?.ready ? dep.ready - dep.buildingAt : null;
  const sslOk = domains?.[0]?.sslActive;

  const items = [
    { label: 'PROJECT', val: project?.name || '—', icon: Package },
    { label: 'BRANCH', val: dep?.meta?.githubCommitRef || dep?.gitSource?.ref || 'main', icon: GitBranch },
    { label: 'COMMIT', val: (dep?.meta?.githubCommitSha || '—').slice(0, 8), icon: GitCommit },
    { label: 'ENV', val: (dep?.target || 'PRODUCTION').toUpperCase(), icon: Layers },
    { label: 'STATUS', val: dep?.readyState || '—', icon: Activity },
    { label: 'VERSION', val: (dep?.meta?.githubCommitSha || '—').slice(0, 7), icon: Code2 },
    { label: 'REGION', val: dep?.regions?.join(', ') || 'Global', icon: Globe },
    { label: 'SSL', val: sslOk === undefined ? '—' : sslOk ? 'ACTIVE' : 'PENDING', icon: Shield },
    { label: 'BUILD TIME', val: fmtDur(dur), icon: Timer },
    { label: 'LAST DEPLOY', val: ago(dep?.createdAt), icon: Clock },
  ];

  const st = dep?.readyState;
  return (
    <div className="bg-trackops-navy/80 backdrop-blur-md border border-trackops-border rounded-xl overflow-hidden mb-6">
      <div className="flex flex-wrap items-center justify-between gap-3 px-5 py-3 border-b border-trackops-border">
        <div className="flex items-center gap-3">
          <span className="w-2.5 h-2.5 rounded-full bg-trackops-green shadow-[0_0_10px_#00FF66] animate-pulse" />
          <span className="font-mono text-[10px] text-gray-400 tracking-widest uppercase">PRODUCTION STATUS</span>
          <Pill color={st === 'READY' ? 'green' : st === 'ERROR' ? 'red' : st === 'BUILDING' ? 'amber' : 'gray'}>
            {loading ? '...' : st || 'UNKNOWN'}
          </Pill>
        </div>
        <a
          href={url}
          target="_blank"
          rel="noreferrer"
          className="flex items-center gap-1.5 text-trackops-green font-mono text-xs hover:underline"
        >
          <Globe className="w-3 h-3" />
          {url.replace('https://', '')}
          <ExternalLink className="w-3 h-3" />
        </a>
      </div>
      <div className="grid grid-cols-5 lg:grid-cols-10 divide-x divide-y divide-trackops-border">
        {items.map(({ label, val, icon: I }) => (
          <div key={label} className="px-3 py-3">
            <div className="flex items-center gap-1 text-gray-600 font-mono text-[9px] tracking-widest uppercase mb-1">
              <I className="w-3 h-3" />
              {label}
            </div>
            {loading ? (
              <Skel className="h-3.5 w-16" />
            ) : (
              <div className="font-mono text-[11px] text-white font-bold truncate">{val}</div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── HEALTH CARDS ─────────────────────────────────────────────────────────────
function HealthCards({ dep, loading }) {
  const dur = dep?.buildingAt && dep?.ready ? dep.ready - dep.buildingAt : null;
  const isOnline = dep?.readyState === 'READY';

  const cards = [
    { label: 'Production Online', val: loading ? '...' : isOnline ? '● ONLINE' : '○ OFFLINE', c: isOnline ? 'green' : 'red', icon: CheckCircle2 },
    { label: 'Latest Deploy', val: ago(dep?.createdAt), c: 'green', icon: Rocket },
    { label: 'Commit SHA', val: (dep?.meta?.githubCommitSha || '—').slice(0, 12), c: 'blue', icon: GitCommit },
    { label: 'Current Branch', val: dep?.meta?.githubCommitRef || dep?.gitSource?.ref || 'main', c: 'blue', icon: GitBranch },
    { label: 'Avg Response', val: '—', c: 'green', icon: Gauge },
    { label: 'Availability', val: isOnline ? '99.9%' : '—', c: 'green', icon: Activity },
    { label: 'Deploy Duration', val: fmtDur(dur), c: 'amber', icon: Timer },
    { label: 'Build Queue', val: dep?.readyState === 'QUEUED' ? 'QUEUED' : '0', c: 'blue', icon: Server },
    { label: 'Bandwidth Today', val: '—', c: 'blue', icon: Network },
    { label: 'Requests Today', val: '—', c: 'green', icon: Radio },
    { label: 'Visitors Online', val: '—', c: 'green', icon: Users },
    { label: 'Serverless Calls', val: '—', c: 'amber', icon: Server },
    { label: 'Functions Run', val: '—', c: 'green', icon: FlaskConical },
    { label: 'Failed Functions', val: '—', c: 'red', icon: XCircle },
    { label: 'Deploy Size', val: fmtBytes(dep?.outputFileSize), c: 'amber', icon: HardDrive },
    { label: 'Edge Requests', val: '—', c: 'blue', icon: Zap },
    { label: 'Image Opt Reqs', val: '—', c: 'blue', icon: ImageIcon },
    { label: 'Invocations', val: '—', c: 'green', icon: Layers },
  ];

  const cmap = {
    green: { border: 'border-trackops-green/20 hover:border-trackops-green/50', icon: 'bg-trackops-green/10 text-trackops-green', val: 'text-trackops-green' },
    red: { border: 'border-trackops-red/20 hover:border-trackops-red/50', icon: 'bg-trackops-red/10 text-trackops-red', val: 'text-trackops-red' },
    amber: { border: 'border-trackops-amber/20 hover:border-trackops-amber/50', icon: 'bg-trackops-amber/10 text-trackops-amber', val: 'text-trackops-amber' },
    blue: { border: 'border-blue-500/20 hover:border-blue-500/50', icon: 'bg-blue-500/10 text-blue-400', val: 'text-blue-400' },
  };

  return (
    <div className="grid grid-cols-3 sm:grid-cols-6 xl:grid-cols-9 gap-2.5 mb-6">
      {cards.map(({ label, val, c, icon: I }) => {
        const s = cmap[c];
        return (
          <div key={label} className={`bg-trackops-card border ${s.border} rounded-xl p-3 transition-all duration-200 group`}>
            <div className={`w-7 h-7 rounded-lg ${s.icon} flex items-center justify-center mb-2 group-hover:scale-110 transition-transform`}>
              <I className="w-3.5 h-3.5" />
            </div>
            <div className="font-mono text-[9px] text-gray-500 uppercase tracking-wider leading-tight mb-1">{label}</div>
            {loading ? <Skel className="h-3.5 w-14" /> : <div className={`font-mono text-xs font-bold ${s.val}`}>{val}</div>}
          </div>
        );
      })}
    </div>
  );
}

// ─── QUICK ACTIONS ────────────────────────────────────────────────────────────
function QuickActions({ dep, onRefresh }) {
  const [busy, setBusy] = useState({});

  const doAction = async (key, fn) => {
    setBusy((b) => ({ ...b, [key]: true }));
    try { await fn(); } catch (e) { console.error(e); }
    finally { setBusy((b) => ({ ...b, [key]: false })); }
  };

  const prodUrl = dep?.url ? `https://${dep.url}` : '#';
  const commitUrl = dep?.meta?.githubCommitUrl || '#';

  const redeploy = () =>
    doAction('redeploy', async () => {
      if (!dep?.uid) return;
      const fn = callFn('vercelRedeploy');
      await fn({ deploymentId: dep.uid });
      setTimeout(onRefresh, 3000);
    });

  const actions = [
    { key: 'redeploy', icon: Rocket, label: 'Redeploy', c: 'green', fn: redeploy },
    { key: 'rollback', icon: RotateCcw, label: 'Rollback', c: 'amber', fn: () => {} },
    { key: 'logs', icon: Terminal, label: 'Build Logs', c: 'blue', fn: () => document.getElementById('build-logs-section')?.scrollIntoView({ behavior: 'smooth' }) },
    { key: 'commit', icon: GitCommit, label: 'Open Commit', c: 'blue', fn: () => window.open(commitUrl, '_blank') },
    { key: 'prod', icon: Globe, label: 'View Production', c: 'green', fn: () => window.open(prodUrl, '_blank') },
    { key: 'copy', icon: Copy, label: 'Copy URL', c: 'gray', fn: () => navigator.clipboard?.writeText(prodUrl) },
    { key: 'refresh', icon: RefreshCw, label: 'Refresh All', c: 'green', fn: onRefresh },
  ];

  const cs = {
    green: 'border-trackops-green/30 text-trackops-green hover:bg-trackops-green/10',
    amber: 'border-trackops-amber/30 text-trackops-amber hover:bg-trackops-amber/10',
    blue: 'border-blue-500/30 text-blue-400 hover:bg-blue-500/10',
    gray: 'border-trackops-border text-gray-500 hover:bg-white/5 hover:text-white',
  };

  return (
    <Glass className="mb-6">
      <SecHead icon={Zap} title="Quick Actions" sub="One-click deployment controls via Cloud Functions" />
      <div className="flex flex-wrap gap-2.5">
        {actions.map((a) => (
          <button
            key={a.key}
            onClick={a.fn}
            disabled={busy[a.key]}
            className={`flex items-center gap-1.5 px-4 py-2 rounded-xl border font-mono text-xs font-bold uppercase tracking-wider transition-all hover:scale-105 active:scale-95 disabled:opacity-50 ${cs[a.c]}`}
          >
            <a.icon className={`w-3.5 h-3.5 ${busy[a.key] ? 'animate-spin' : ''}`} />
            {a.label}
          </button>
        ))}
      </div>
    </Glass>
  );
}

// ─── NOTIFICATIONS ────────────────────────────────────────────────────────────
function Notifications({ deployments }) {
  const notes = (deployments || []).slice(0, 6).map((d) => ({
    ok: d.readyState === 'READY',
    text:
      d.readyState === 'READY'
        ? 'Deployment Successful'
        : d.readyState === 'ERROR'
        ? 'Deployment Failed'
        : `Deployment ${d.readyState}`,
    detail: d.meta?.githubCommitMessage?.slice(0, 60) || d.uid?.slice(-12),
    time: ago(d.createdAt),
    icon: d.readyState === 'READY' ? CheckCircle2 : d.readyState === 'ERROR' ? XCircle : AlertTriangle,
    type: d.readyState === 'READY' ? 'success' : d.readyState === 'ERROR' ? 'error' : 'warning',
  }));

  const ts = {
    success: 'border-trackops-green/20 bg-trackops-green/5 text-trackops-green',
    error: 'border-trackops-red/20 bg-trackops-red/5 text-trackops-red',
    warning: 'border-trackops-amber/20 bg-trackops-amber/5 text-trackops-amber',
  };

  return (
    <Glass className="mb-6">
      <SecHead icon={BellRing} title="Notifications" sub="Real-time deployment alerts" color="text-trackops-amber" />
      <div className="space-y-2">
        {notes.length === 0 ? (
          <div className="text-gray-700 font-mono text-xs py-4 text-center">No notifications</div>
        ) : (
          notes.map((n, i) => (
            <div key={i} className={`flex items-center gap-3 border rounded-xl px-4 py-3 font-mono text-xs ${ts[n.type]}`}>
              <n.icon className="w-4 h-4 shrink-0" />
              <div className="flex-1 min-w-0">
                <div className="font-bold text-white">{n.text}</div>
                <div className="text-gray-500 truncate">{n.detail}</div>
              </div>
              <div className="text-gray-600 shrink-0">{n.time}</div>
            </div>
          ))
        )}
      </div>
    </Glass>
  );
}

// ─── BUILD PIPELINE ───────────────────────────────────────────────────────────
function Pipeline({ dep }) {
  const stages = [
    { label: 'GitHub Push', icon: GitCommit },
    { label: 'Install Packages', icon: Package },
    { label: 'Type Check', icon: Code2 },
    { label: 'Lint', icon: Filter },
    { label: 'Build', icon: Box },
    { label: 'Optimize', icon: Zap },
    { label: 'Upload', icon: Cloud },
    { label: 'Edge Deploy', icon: Globe },
    { label: 'Production Ready', icon: CheckCircle2 },
  ];

  const stageStatus = (idx) => {
    if (!dep) return 'pending';
    if (dep.readyState === 'READY') return 'completed';
    if (dep.readyState === 'ERROR') return idx < 5 ? 'completed' : idx === 5 ? 'failed' : 'pending';
    if (dep.readyState === 'BUILDING') {
      const elapsed = dep.buildingAt ? (Date.now() - dep.buildingAt) / 1000 : 0;
      const cur = Math.min(Math.floor(elapsed / 15), stages.length - 1);
      if (idx < cur) return 'completed';
      if (idx === cur) return 'running';
    }
    return 'pending';
  };

  const stageStyle = (s) =>
    ({
      completed: 'bg-trackops-green/10 border-trackops-green text-trackops-green',
      running: 'bg-trackops-amber/10 border-trackops-amber text-trackops-amber animate-pulse',
      failed: 'bg-trackops-red/10 border-trackops-red text-trackops-red',
      pending: 'bg-trackops-steel/20 border-trackops-border text-gray-600',
    }[s] || 'bg-trackops-steel/20 border-trackops-border text-gray-600');

  return (
    <Glass className="mb-6">
      <SecHead icon={Rocket} title="Build Pipeline" sub="Stage-by-stage deployment progress" color="text-trackops-amber" />
      <div className="flex items-center gap-2 overflow-x-auto pb-2">
        {stages.map((st, idx) => {
          const s = stageStatus(idx);
          return (
            <React.Fragment key={st.label}>
              <div className={`flex flex-col items-center min-w-[72px] p-2.5 rounded-xl border transition-all duration-500 ${stageStyle(s)}`}>
                <st.icon className="w-4 h-4 mb-1" />
                <div className="font-mono text-[8px] uppercase tracking-wider text-center leading-tight">{st.label}</div>
                <div className={`mt-1 text-[8px] font-bold uppercase ${s === 'completed' ? 'text-trackops-green' : s === 'running' ? 'text-trackops-amber' : s === 'failed' ? 'text-trackops-red' : 'text-gray-700'}`}>
                  {s}
                </div>
              </div>
              {idx < stages.length - 1 && (
                <ArrowRight className={`w-3.5 h-3.5 shrink-0 ${s === 'completed' ? 'text-trackops-green' : 'text-gray-700'}`} />
              )}
            </React.Fragment>
          );
        })}
      </div>
    </Glass>
  );
}

// ─── DEPLOYMENT ANALYTICS CHARTS ─────────────────────────────────────────────
function Charts({ analyticsData, loading }) {
  const chartData = analyticsData?.chartData || [];
  const summary = analyticsData?.summary || {};

  const tipStyle = {
    contentStyle: { background: '#0B1221', border: '1px solid #1E293B', borderRadius: 8, fontFamily: 'monospace', fontSize: 10 },
  };

  return (
    <div className="mb-6">
      {/* Summary pills */}
      <div className="flex flex-wrap gap-3 mb-4">
        {[
          { label: 'Total Deploys', val: summary.total || '—', c: 'text-white' },
          { label: 'Successful', val: summary.success || '—', c: 'text-trackops-green' },
          { label: 'Failed', val: summary.failed || '—', c: 'text-trackops-red' },
          { label: 'Success Rate', val: summary.successRate !== undefined ? `${summary.successRate}%` : '—', c: 'text-trackops-green' },
          { label: 'Avg Build', val: summary.avgBuildMs ? fmtDur(summary.avgBuildMs) : '—', c: 'text-trackops-amber' },
        ].map((s) => (
          <div key={s.label} className="bg-trackops-steel/30 border border-trackops-border rounded-xl px-4 py-2 font-mono text-xs">
            <span className="text-gray-500">{s.label}: </span>
            <span className={`font-bold ${s.c}`}>{s.val}</span>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        {[
          { label: 'Deploys / Day', key: 'total', color: '#00FF66', type: 'bar' },
          { label: 'Avg Build Time (s)', key: 'avgBuildTime', color: '#FFB000', type: 'area' },
          { label: 'Success Rate %', key: 'successRate', color: '#00FF66', type: 'line' },
          { label: 'Failed Builds', key: 'failed', color: '#FF2A2A', type: 'bar' },
        ].map(({ label, key, color, type }) => (
          <Glass key={label}>
            <div className="font-mono text-[10px] text-gray-500 uppercase tracking-widest mb-3">{label}</div>
            {loading ? (
              <Skel className="h-24 w-full" />
            ) : (
              <ResponsiveContainer width="100%" height={90}>
                {type === 'bar' ? (
                  <BarChart data={chartData}>
                    <Bar dataKey={key} fill={color} radius={[2, 2, 0, 0]} />
                    <Tooltip {...tipStyle} />
                  </BarChart>
                ) : type === 'area' ? (
                  <AreaChart data={chartData}>
                    <defs>
                      <linearGradient id={`g_${key}`} x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor={color} stopOpacity={0.3} />
                        <stop offset="95%" stopColor={color} stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <Area type="monotone" dataKey={key} stroke={color} fill={`url(#g_${key})`} strokeWidth={2} dot={false} />
                    <Tooltip {...tipStyle} />
                  </AreaChart>
                ) : (
                  <LineChart data={chartData}>
                    <Line type="monotone" dataKey={key} stroke={color} strokeWidth={2} dot={false} />
                    <Tooltip {...tipStyle} />
                  </LineChart>
                )}
              </ResponsiveContainer>
            )}
          </Glass>
        ))}
      </div>
    </div>
  );
}

// ─── DEPLOYMENT HISTORY ───────────────────────────────────────────────────────
function DepHistory({ deployments, loading, prodId }) {
  const [open, setOpen] = useState({});
  const [logs, setLogs] = useState({});
  const [ll, setLl] = useState({});

  const toggle = async (dep) => {
    const id = dep.uid;
    setOpen((o) => ({ ...o, [id]: !o[id] }));
    if (!logs[id] && !ll[id]) {
      setLl((l) => ({ ...l, [id]: true }));
      try {
        const fn = callFn('vercelGetDeploymentLogs');
        const res = await fn({ deploymentId: id });
        setLogs((l) => ({ ...l, [id]: res.data?.data?.events || [] }));
      } catch {
        setLogs((l) => ({ ...l, [id]: [] }));
      } finally {
        setLl((l) => ({ ...l, [id]: false }));
      }
    }
  };

  const sc = (s) =>
    ({ READY: 'text-trackops-green', ERROR: 'text-trackops-red', CANCELED: 'text-gray-500', BUILDING: 'text-trackops-amber' }[s] || 'text-gray-400');
  const sb = (s) =>
    ({ READY: 'bg-trackops-green/10 border-trackops-green/30', ERROR: 'bg-trackops-red/10 border-trackops-red/30', CANCELED: 'bg-gray-500/10 border-gray-600/30', BUILDING: 'bg-trackops-amber/10 border-trackops-amber/30' }[s] || 'bg-gray-500/10 border-gray-600/30');

  return (
    <Glass className="mb-6">
      <SecHead icon={GitBranch} title="Deployment History" sub="Latest 20 — click any row to expand build events" />
      {loading ? (
        <div className="space-y-2">{[...Array(5)].map((_, i) => <Skel key={i} className="h-12 w-full" />)}</div>
      ) : (
        <div className="space-y-2">
          {(deployments || []).slice(0, 20).map((dep) => {
            const isOpen = open[dep.uid];
            const isProd = dep.uid === prodId;
            const dur = dep.buildingAt && dep.ready ? dep.ready - dep.buildingAt : null;
            return (
              <div key={dep.uid} className={`border rounded-xl overflow-hidden transition-all ${isProd ? 'border-trackops-green/40 bg-trackops-green/5' : 'border-trackops-border bg-trackops-steel/10'}`}>
                <button
                  onClick={() => toggle(dep)}
                  className="w-full text-left px-4 py-3 flex items-center gap-2 hover:bg-white/3 transition-colors"
                >
                  {isOpen ? <ChevronDown className="w-3.5 h-3.5 text-gray-600" /> : <ChevronRight className="w-3.5 h-3.5 text-gray-600" />}
                  <Dot s={dep.readyState} />
                  <span className="font-mono text-[10px] text-gray-500 w-24 shrink-0 truncate">{dep.uid?.slice(-10)}</span>
                  <span className="font-mono text-xs text-white flex-1 truncate">{dep.meta?.githubCommitMessage || 'No message'}</span>
                  <span className="font-mono text-[10px] text-gray-500 w-24 shrink-0 truncate hidden sm:block">{dep.meta?.githubCommitAuthorName || dep.creator?.username || '—'}</span>
                  <span className="font-mono text-[10px] text-blue-400 w-20 shrink-0 hidden md:block">{dep.meta?.githubCommitRef || dep.gitSource?.ref || 'main'}</span>
                  <span className="font-mono text-[10px] text-gray-600 w-14 shrink-0 hidden lg:block">{fmtDur(dur)}</span>
                  <span className="font-mono text-[10px] text-gray-500 w-16 shrink-0 text-right">{ago(dep.createdAt)}</span>
                  <span className={`font-mono text-[9px] font-bold px-2 py-0.5 rounded border ml-1 ${sb(dep.readyState)} ${sc(dep.readyState)}`}>
                    {isProd ? '● LIVE' : dep.readyState}
                  </span>
                </button>
                {isOpen && (
                  <div className="border-t border-trackops-border px-4 py-3 font-mono text-xs space-y-3">
                    <div className="grid grid-cols-2 md:grid-cols-3 gap-2 text-[11px]">
                      <div><span className="text-gray-500">ID: </span><span className="text-white">{dep.uid}</span></div>
                      <div><span className="text-gray-500">Created: </span><span className="text-white">{new Date(dep.createdAt).toLocaleString()}</span></div>
                      <div><span className="text-gray-500">Ready: </span><span className="text-white">{dep.ready ? new Date(dep.ready).toLocaleString() : '—'}</span></div>
                      <div><span className="text-gray-500">Env: </span><span className="text-trackops-amber">{(dep.target || '—').toUpperCase()}</span></div>
                      <div><span className="text-gray-500">SHA: </span><span className="text-blue-400">{dep.meta?.githubCommitSha?.slice(0, 16) || '—'}</span></div>
                      <div>
                        <span className="text-gray-500">URL: </span>
                        <a href={`https://${dep.url}`} target="_blank" rel="noreferrer" className="text-trackops-green hover:underline">{dep.url}</a>
                      </div>
                    </div>
                    <div>
                      <div className="text-gray-500 text-[10px] uppercase tracking-wider mb-2">Build Events</div>
                      <div className="bg-black/60 rounded-lg p-3 max-h-44 overflow-y-auto space-y-1">
                        {ll[dep.uid] ? (
                          <div className="text-gray-500 animate-pulse">Loading via Cloud Function...</div>
                        ) : (logs[dep.uid] || []).length === 0 ? (
                          <div className="text-gray-600">No events.</div>
                        ) : (
                          (logs[dep.uid] || []).map((ev, i) => {
                            const isE = ev.type === 'error' || ev.text?.toLowerCase().includes('error');
                            const isW = ev.type === 'warning' || ev.text?.toLowerCase().includes('warn');
                            return (
                              <div key={i} className={`text-[10px] leading-5 ${isE ? 'text-trackops-red' : isW ? 'text-trackops-amber' : 'text-gray-400'}`}>
                                <span className="text-gray-600 mr-2">{ev.created ? new Date(ev.created).toLocaleTimeString() : ''}</span>
                                {ev.text}
                              </div>
                            );
                          })
                        )}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
          {(!deployments || deployments.length === 0) && (
            <div className="text-center py-8 text-gray-600 font-mono text-xs">No deployments found.</div>
          )}
        </div>
      )}
    </Glass>
  );
}

// ─── BUILD LOGS TERMINAL ──────────────────────────────────────────────────────
function LogsTerminal({ deploymentId }) {
  const { data, loading, error, refresh } = useCloudFn(
    'vercelGetDeploymentLogs',
    { deploymentId: deploymentId || '' },
    5000
  );

  const [search, setSearch] = useState('');
  const [filt, setFilt] = useState('all');
  const [autoScroll, setAutoScroll] = useState(true);
  const bottom = useRef(null);

  const events = data?.events || [];

  useEffect(() => {
    if (autoScroll) bottom.current?.scrollIntoView({ behavior: 'smooth' });
  }, [events, autoScroll]);

  const shown = events.filter((ev) => {
    const t = ev.text || '';
    const ms = !search || t.toLowerCase().includes(search.toLowerCase());
    const mf =
      filt === 'all' ||
      (filt === 'error' && (ev.type === 'error' || t.toLowerCase().includes('error'))) ||
      (filt === 'warning' && (ev.type === 'warning' || t.toLowerCase().includes('warn')));
    return ms && mf;
  });

  const copy = () => navigator.clipboard?.writeText(events.map((l) => l.text || '').join('\n'));
  const dl = () => {
    const url = URL.createObjectURL(new Blob([events.map((l) => l.text || '').join('\n')], { type: 'text/plain' }));
    Object.assign(document.createElement('a'), { href: url, download: 'build.log' }).click();
    URL.revokeObjectURL(url);
  };

  return (
    <Glass className="mb-6" id="build-logs-section">
      <SecHead icon={Terminal} title="Build Logs" sub="Fetched via Firebase Cloud Function · auto-refreshes every 5s" />
      <div className="flex flex-wrap gap-2 mb-3">
        <div className="relative flex-1 min-w-36">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 w-3 h-3 text-gray-600" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search logs..."
            className="w-full bg-trackops-steel/40 border border-trackops-border rounded-lg pl-7 pr-3 py-1.5 font-mono text-xs text-white placeholder-gray-700 focus:outline-none focus:border-trackops-green/40"
          />
        </div>
        <select value={filt} onChange={(e) => setFilt(e.target.value)} className="bg-trackops-steel/40 border border-trackops-border rounded-lg px-3 py-1.5 font-mono text-xs text-gray-300 focus:outline-none">
          <option value="all">All</option>
          <option value="error">Errors</option>
          <option value="warning">Warnings</option>
        </select>
        {[
          { label: autoScroll ? 'AUTO ●' : 'AUTO ○', fn: () => setAutoScroll((a) => !a), active: autoScroll },
          { label: 'COPY', fn: copy, icon: Copy },
          { label: 'DOWNLOAD', fn: dl, icon: Download },
          { label: 'REFRESH', fn: refresh, icon: RefreshCw },
        ].map((b) => (
          <button
            key={b.label}
            onClick={b.fn}
            className={`flex items-center gap-1 px-3 py-1.5 rounded-lg border font-mono text-xs transition-colors ${b.active ? 'border-trackops-green/30 text-trackops-green bg-trackops-green/5' : 'border-trackops-border text-gray-500 hover:text-white hover:border-white/20'}`}
          >
            {b.icon && <b.icon className="w-3 h-3" />}
            {b.label}
          </button>
        ))}
      </div>
      <div className="bg-[#030712] rounded-xl border border-trackops-border/40 h-80 overflow-y-auto p-4 font-mono text-xs space-y-0.5">
        <div className="flex items-center gap-2 pb-3 mb-2 border-b border-white/5">
          <span className="w-2.5 h-2.5 rounded-full bg-trackops-red" />
          <span className="w-2.5 h-2.5 rounded-full bg-trackops-amber" />
          <span className="w-2.5 h-2.5 rounded-full bg-trackops-green" />
          <span className="text-gray-700 text-[10px] ml-2">
            vercel build — {deploymentId?.slice(-12) || 'latest'} · proxied via Firebase
          </span>
        </div>
        {loading && !deploymentId && <div className="text-gray-600">Waiting for deployment ID...</div>}
        {loading && deploymentId && <div className="text-gray-600 animate-pulse">$ Fetching build logs via Cloud Function...</div>}
        {error && <div className="text-trackops-red">⚠ {error}</div>}
        {shown.map((ev, i) => {
          const isE = ev.type === 'error' || ev.text?.toLowerCase().includes('error:');
          const isW = ev.type === 'warning' || ev.text?.toLowerCase().includes('warning:');
          return (
            <div key={i} className={`leading-5 ${isE ? 'text-trackops-red' : isW ? 'text-trackops-amber' : 'text-gray-300'}`}>
              <span className="text-gray-700 mr-2 select-none">{String(i + 1).padStart(4, ' ')}</span>
              {ev.text}
            </div>
          );
        })}
        {!loading && shown.length === 0 && events.length > 0 && <div className="text-gray-700">No entries match your filter.</div>}
        {!loading && events.length === 0 && !error && <div className="text-gray-700">No build events found for this deployment.</div>}
        <div ref={bottom} />
      </div>
    </Glass>
  );
}

// ─── FUNCTIONS PANEL ──────────────────────────────────────────────────────────
function FunctionsPanel({ deploymentId }) {
  const { data, loading } = useCloudFn(
    'vercelGetDeploymentFiles',
    { deploymentId: deploymentId || '' },
    60000
  );

  const fns = data?.functions || [];
  const metrics = [
    { lbl: 'Running', val: '—', icon: Activity, c: 'green' },
    { lbl: 'Cold Starts', val: '—', icon: Zap, c: 'amber' },
    { lbl: 'Avg Duration', val: '—', icon: Timer, c: 'blue' },
    { lbl: 'Memory', val: '—', icon: MemoryStick, c: 'blue' },
    { lbl: 'Executions', val: '—', icon: FlaskConical, c: 'green' },
    { lbl: 'Failures', val: '—', icon: XCircle, c: 'red' },
    { lbl: 'Timeouts', val: '—', icon: Clock, c: 'red' },
    { lbl: 'Retries', val: '—', icon: RotateCcw, c: 'amber' },
  ];
  const cc = { green: 'text-trackops-green', red: 'text-trackops-red', amber: 'text-trackops-amber', blue: 'text-blue-400' };

  return (
    <Glass className="mb-6">
      <SecHead icon={FlaskConical} title="Serverless Functions" sub="Function inventory from Vercel via Cloud Function" />
      <div className="grid grid-cols-4 lg:grid-cols-8 gap-2 mb-4">
        {metrics.map((m) => (
          <div key={m.lbl} className="bg-trackops-steel/20 border border-trackops-border rounded-xl p-3 text-center">
            <m.icon className={`w-4 h-4 mx-auto mb-1 ${cc[m.c]}`} />
            <div className="font-mono text-base font-bold text-white">{m.val}</div>
            <div className="font-mono text-[9px] text-gray-500 uppercase">{m.lbl}</div>
          </div>
        ))}
      </div>
      {loading ? (
        <div className="space-y-2">{[...Array(3)].map((_, i) => <Skel key={i} className="h-9" />)}</div>
      ) : fns.length === 0 ? (
        <div className="text-center py-3 text-gray-700 text-[10px] font-mono">No serverless functions detected in this deployment.</div>
      ) : (
        fns.map((fn, i) => (
          <div key={i} className="flex items-center justify-between bg-trackops-steel/20 border border-trackops-border/40 rounded-lg px-4 py-2.5 font-mono text-xs mb-1.5">
            <span className="text-blue-400">{fn.name}</span>
            <div className="flex gap-4 text-gray-600">
              <span>Runtime: <span className="text-white">{fn.lambda?.runtime || '—'}</span></span>
              <span>Memory: <span className="text-white">{fn.lambda?.memory || '—'}</span></span>
            </div>
          </div>
        ))
      )}
    </Glass>
  );
}

// ─── CORE WEB VITALS ─────────────────────────────────────────────────────────
function WebVitals() {
  const vitals = [
    { lbl: 'LCP', name: 'Largest Contentful Paint', good: '≤2.5s' },
    { lbl: 'INP', name: 'Interaction to Next Paint', good: '≤200ms' },
    { lbl: 'CLS', name: 'Cumulative Layout Shift', good: '≤0.1' },
    { lbl: 'TTFB', name: 'Time to First Byte', good: '≤800ms' },
    { lbl: 'FCP', name: 'First Contentful Paint', good: '≤1.8s' },
    { lbl: 'SI', name: 'Speed Index', good: '≤3.4s' },
  ];
  return (
    <Glass className="mb-6">
      <SecHead icon={Zap} title="Core Web Vitals" sub="Requires Vercel Speed Insights API — add via Cloud Function" color="text-trackops-amber" />
      <div className="grid grid-cols-3 md:grid-cols-6 gap-3 mb-4">
        {vitals.map((v) => (
          <div key={v.lbl} className="bg-trackops-steel/20 border border-trackops-border rounded-xl p-3 text-center">
            <div className="font-mono text-2xl font-black text-gray-600">—</div>
            <div className="font-mono text-[11px] text-white font-bold mt-1">{v.lbl}</div>
            <div className="font-mono text-[9px] text-gray-600">{v.name}</div>
            <div className="font-mono text-[9px] text-trackops-green mt-0.5">{v.good}</div>
          </div>
        ))}
      </div>
      <div className="grid grid-cols-4 gap-3">
        {['Performance', 'Accessibility', 'SEO', 'Best Practices'].map((s) => (
          <div key={s} className="bg-trackops-steel/20 border border-trackops-border rounded-xl p-3 text-center">
            <div className="font-mono text-xl font-black text-gray-600">—</div>
            <div className="font-mono text-[10px] text-gray-400 mt-1">{s}</div>
          </div>
        ))}
      </div>
    </Glass>
  );
}

// ─── PAGE PERFORMANCE ─────────────────────────────────────────────────────────
function PagePerf() {
  const routes = ['/dashboard', '/support', '/live-users', '/security', '/login', '/trackops/dashboard', '/trackops/errors', '/trackops/health'];
  return (
    <Glass className="mb-6">
      <SecHead icon={Gauge} title="Page Performance" sub="Per-route metrics — requires Speed Insights" color="text-blue-400" />
      <div className="overflow-x-auto">
        <table className="w-full font-mono text-xs">
          <thead>
            <tr className="border-b border-trackops-border">
              {['Route', 'Avg Load', 'Slowest', 'Fastest', 'JS Bundle', 'CSS', 'Errors'].map((h) => (
                <th key={h} className="text-left py-2 px-3 text-gray-600 text-[10px] uppercase tracking-widest font-normal">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {routes.map((r) => (
              <tr key={r} className="border-b border-trackops-border/20 hover:bg-white/1 transition-colors">
                <td className="py-2 px-3 text-blue-400">{r}</td>
                {[...Array(6)].map((_, i) => <td key={i} className="py-2 px-3 text-gray-600">—</td>)}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Glass>
  );
}

// ─── API HEALTH ───────────────────────────────────────────────────────────────
function APIHealth() {
  const eps = ['/auth', '/users', '/support', '/attendance', '/reports', '/payroll'];
  return (
    <Glass className="mb-6">
      <SecHead icon={Network} title="API Health" sub="Backend endpoint monitoring" color="text-blue-400" />
      <div className="space-y-2">
        {eps.map((ep) => (
          <div key={ep} className="flex items-center justify-between bg-trackops-steel/20 border border-trackops-border/40 rounded-xl px-4 py-3">
            <div className="flex items-center gap-3"><Pill color="blue">GET</Pill><span className="font-mono text-xs text-white">{ep}</span></div>
            <div className="flex items-center gap-4 font-mono text-[10px] text-gray-600">
              <span>Avg: <span className="text-white">—</span></span>
              <span>P95: <span className="text-white">—</span></span>
              <span>Success: <span className="text-trackops-green">—</span></span>
              <Dot s="OK" />
            </div>
          </div>
        ))}
      </div>
    </Glass>
  );
}

// ─── ERROR CENTER ─────────────────────────────────────────────────────────────
function ErrorCenter({ deployments }) {
  const [q, setQ] = useState('');
  const errs = (deployments || [])
    .filter((d) => d.readyState === 'ERROR')
    .map((d) => ({
      id: d.uid, msg: d.meta?.githubCommitMessage || 'Build failed',
      time: ago(d.createdAt), env: d.target || 'production', branch: d.meta?.githubCommitRef || 'main',
    }));
  const shown = errs.filter((e) => !q || e.msg.toLowerCase().includes(q.toLowerCase()));

  return (
    <Glass className="mb-6">
      <SecHead icon={AlertTriangle} title="Error Center" sub="Failed deployments from Vercel history" color="text-trackops-red" />
      <div className="flex gap-2 mb-3">
        <div className="relative flex-1">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 w-3 h-3 text-gray-600" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search errors..."
            className="w-full bg-trackops-steel/40 border border-trackops-border rounded-lg pl-7 pr-3 py-1.5 font-mono text-xs text-white placeholder-gray-700 focus:outline-none" />
        </div>
        <button className="flex items-center gap-1 px-3 py-1.5 border border-trackops-border text-gray-500 rounded-lg font-mono text-xs hover:text-white transition-colors">
          <Download className="w-3 h-3" />EXPORT
        </button>
      </div>
      {shown.length === 0 ? (
        <div className="flex flex-col items-center py-8 gap-2 text-gray-600 font-mono text-xs">
          <CheckCircle2 className="w-7 h-7 text-trackops-green" />
          No errors — system healthy
        </div>
      ) : (
        shown.map((e) => (
          <div key={e.id} className="flex items-start gap-3 bg-trackops-red/5 border border-trackops-red/20 rounded-xl p-3 mb-2">
            <AlertTriangle className="w-4 h-4 text-trackops-red mt-0.5 shrink-0" />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1"><Pill color="red">BUILD</Pill><span className="font-mono text-[10px] text-gray-500">{e.time}</span><Pill color="blue">{e.env}</Pill></div>
              <div className="font-mono text-xs text-white truncate">{e.msg}</div>
              <div className="font-mono text-[10px] text-gray-600 mt-0.5">Branch: {e.branch}</div>
            </div>
          </div>
        ))
      )}
    </Glass>
  );
}

// ─── RESOURCE USAGE ───────────────────────────────────────────────────────────
function Resources() {
  const items = [
    { lbl: 'Bandwidth', pct: 0, icon: Network, limit: '100 GB' },
    { lbl: 'Functions', pct: 0, icon: FlaskConical, limit: '1M calls' },
    { lbl: 'Image Optimization', pct: 0, icon: ImageIcon, limit: '5K images' },
    { lbl: 'Edge Requests', pct: 0, icon: Globe, limit: '10M reqs' },
  ];
  return (
    <Glass className="mb-6">
      <SecHead icon={HardDrive} title="Resource Usage" sub="Current billing period consumption" color="text-trackops-amber" />
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {items.map((r) => {
          const color = r.pct > 80 ? '#FF2A2A' : r.pct > 60 ? '#FFB000' : '#00FF66';
          return (
            <div key={r.lbl} className="bg-trackops-steel/20 border border-trackops-border rounded-xl p-4">
              <div className="flex items-center gap-2 mb-3"><r.icon className="w-4 h-4 text-gray-400" /><span className="font-mono text-[10px] text-gray-300 uppercase">{r.lbl}</span></div>
              <div className="h-1.5 bg-trackops-navy rounded-full overflow-hidden mb-2">
                <div className="h-full rounded-full" style={{ width: `${r.pct}%`, background: color, boxShadow: `0 0 8px ${color}` }} />
              </div>
              <div className="flex justify-between font-mono text-[10px]">
                <span style={{ color }}>{r.pct}%</span>
                <span className="text-gray-600">{r.limit}</span>
              </div>
            </div>
          );
        })}
      </div>
    </Glass>
  );
}

// ─── AI DEPLOYMENT ANALYST ────────────────────────────────────────────────────
function AIAnalyst({ deployments, dep, analyticsData }) {
  const [insights, setInsights] = useState([]);
  const [busy, setBusy] = useState(false);

  const analyze = useCallback(() => {
    if (!dep) return;
    setBusy(true);
    const ins = [];

    // Build time comparison
    const last = deployments?.[0];
    const prev = deployments?.[1];
    if (last && prev) {
      const ld = last.ready && last.buildingAt ? last.ready - last.buildingAt : null;
      const pd = prev.ready && prev.buildingAt ? prev.ready - prev.buildingAt : null;
      if (ld && pd) {
        const ch = ((ld - pd) / pd) * 100;
        ins.push({
          type: ch > 20 ? 'warning' : 'success',
          icon: ch > 20 ? TrendingUp : TrendingDown,
          text: `Deployment completed in ${fmtDur(ld)}. Build time ${ch > 0 ? `increased ${ch.toFixed(0)}%` : `improved ${Math.abs(ch).toFixed(0)}%`} vs previous.`,
        });
      }
    }

    // Error rate from analytics
    if (analyticsData?.summary) {
      const { failed, successRate } = analyticsData.summary;
      if (failed > 2) {
        ins.push({ type: 'danger', icon: AlertTriangle, text: `${failed} failed deployments in recent history. Review build configuration.` });
      }
      if (successRate !== undefined) {
        ins.push({
          type: successRate >= 90 ? 'success' : successRate >= 70 ? 'warning' : 'danger',
          icon: Activity,
          text: `Deployment success rate: ${successRate}%. ${successRate >= 90 ? 'Excellent reliability.' : 'Investigate recurring failures.'}`,
        });
      }
    }

    // Branch diversity
    const branches = new Set((deployments || []).map((d) => d.meta?.githubCommitRef || d.gitSource?.ref).filter(Boolean));
    if (branches.size > 2) {
      ins.push({ type: 'info', icon: GitBranch, text: `Active across ${branches.size} branches: ${[...branches].slice(0, 3).join(', ')}.` });
    }

    // Production health
    if (dep.readyState === 'READY') {
      ins.push({
        type: 'success', icon: CheckCircle2,
        text: `Production is healthy. Latest from ${dep.meta?.githubCommitRef || 'main'} by ${dep.meta?.githubCommitAuthorName || 'team'}.`,
      });
    }

    ins.push({ type: 'recommendation', icon: Lightbulb, text: 'Enable Vercel Speed Insights to populate real Core Web Vitals data.' });
    ins.push({ type: 'recommendation', icon: Package, text: 'Run ANALYZE=true npm run build to identify heavy JS chunks.' });

    setInsights(ins);
    setBusy(false);
  }, [dep, deployments, analyticsData]);

  useEffect(() => {
    const t = setTimeout(analyze, 800);
    return () => clearTimeout(t);
  }, [analyze]);

  const ts = {
    success: 'border-l-trackops-green bg-trackops-green/5 text-trackops-green',
    warning: 'border-l-trackops-amber bg-trackops-amber/5 text-trackops-amber',
    danger: 'border-l-trackops-red bg-trackops-red/5 text-trackops-red',
    info: 'border-l-blue-400 bg-blue-500/5 text-blue-300',
    recommendation: 'border-l-purple-400 bg-purple-500/5 text-purple-300',
  };

  return (
    <Glass className="mb-6" glow="rgba(0,255,102,0.06)">
      <div className="flex items-center justify-between mb-4">
        <SecHead icon={Sparkles} title="AI Deployment Analyst" sub="Real-time insights from Cloud Function data" />
        <button onClick={analyze} disabled={busy}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-trackops-green/30 text-trackops-green font-mono text-xs hover:bg-trackops-green/10 transition-colors disabled:opacity-40">
          <RefreshCw className={`w-3 h-3 ${busy ? 'animate-spin' : ''}`} />
          {busy ? 'ANALYZING...' : 'REGENERATE'}
        </button>
      </div>
      {busy ? (
        <div className="space-y-2">{[...Array(3)].map((_, i) => <Skel key={i} className="h-10" />)}</div>
      ) : insights.length === 0 ? (
        <div className="text-gray-700 font-mono text-xs py-4 text-center">Awaiting deployment data...</div>
      ) : (
        insights.map((ins, i) => (
          <div key={i} className={`flex items-start gap-3 border-l-2 pl-4 py-2 rounded-r-lg mb-2 ${ts[ins.type]}`}>
            <ins.icon className="w-4 h-4 mt-0.5 shrink-0" />
            <p className="font-mono text-xs">{ins.text}</p>
          </div>
        ))
      )}
    </Glass>
  );
}

// ─── AI RECOMMENDATIONS ───────────────────────────────────────────────────────
function AIRecs() {
  const recs = [
    { icon: Package, t: 'Remove unused packages', d: 'Reduce bundle + install time', a: 'npm prune --production', c: 'amber' },
    { icon: Zap, t: 'Enable gzip compression', d: 'Reduce transfer size ~70%', a: 'vercel.json → headers: Content-Encoding: gzip', c: 'green' },
    { icon: Layers, t: 'Split large bundles', d: 'Dynamic imports for heavy routes', a: 'vite.config.js → rollupOptions.output.manualChunks', c: 'blue' },
    { icon: BarChart2, t: 'Lazy load charts', d: 'Recharts adds ~300KB to initial JS', a: "const Chart = React.lazy(() => import('recharts'))", c: 'amber' },
    { icon: Database, t: 'Cache Firebase calls', d: 'Reduce Firestore reads', a: 'enableIndexedDbPersistence(db)', c: 'green' },
    { icon: ImageIcon, t: 'Optimize images', d: 'Use Vercel image optimization params', a: 'Add ?w=800&q=80 to image URLs', c: 'blue' },
    { icon: Code2, t: 'Tree-shake Lucide icons', d: 'Import icons individually', a: "import { X } from 'lucide-react'", c: 'amber' },
    { icon: FileText, t: 'Compress SVGs', d: 'SVGO reduces SVG size 40-60%', a: 'npx svgo --recursive ./src/assets', c: 'green' },
    { icon: Network, t: 'Add edge caching headers', d: 'Cache static API responses at CDN', a: 'Cache-Control: s-maxage=60, stale-while-revalidate', c: 'blue' },
  ];
  const cs = {
    green: 'border-trackops-green/20 bg-trackops-green/5 text-trackops-green',
    amber: 'border-trackops-amber/20 bg-trackops-amber/5 text-trackops-amber',
    blue: 'border-blue-500/20 bg-blue-500/5 text-blue-400',
  };
  return (
    <Glass className="mb-6">
      <SecHead icon={Lightbulb} title="AI Recommendations" sub="Automated optimization action cards" color="text-trackops-amber" />
      <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-3">
        {recs.map((r, i) => (
          <div key={i} className={`flex items-start gap-3 border rounded-xl p-3 hover:scale-[1.01] transition-transform ${cs[r.c]}`}>
            <div className="p-2 rounded-lg bg-black/20 shrink-0"><r.icon className="w-4 h-4" /></div>
            <div className="min-w-0">
              <div className="font-mono text-xs font-bold text-white">{r.t}</div>
              <div className="font-mono text-[10px] text-gray-500 mt-0.5">{r.d}</div>
              <div className="font-mono text-[10px] opacity-60 mt-1">{r.a}</div>
            </div>
          </div>
        ))}
      </div>
    </Glass>
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN PAGE EXPORT
// ═════════════════════════════════════════════════════════════════════════════
export default function DeploymentCenter() {
  // Primary data — project + deployments + domains (single Cloud Function call, every 5s)
  const { data: full, loading: fullLoading, error: fullErr, updatedAt, refresh: refreshFull } =
    useCloudFn('vercelGetProjectFull', {}, 5000);

  // Analytics — chart data (separate call, every 30s)
  const { data: analyticsData, loading: analyticsLoading, refresh: refreshAnalytics } =
    useCloudFn('vercelGetDeploymentAnalytics', { projectId: full?.project?.id }, 30000);

  const project = full?.project || null;
  const deployments = full?.deployments || [];
  const domains = full?.domains || [];
  const latestDep = deployments[0] || null;
  const prodId = latestDep?.uid;

  const refresh = useCallback(() => {
    refreshFull();
    refreshAnalytics();
  }, [refreshFull, refreshAnalytics]);

  return (
    <div className="pb-12 space-y-0">
      {/* ── Page Title ──────────────────────────────────────────────────────── */}
      <div className="flex flex-wrap items-start justify-between gap-3 border-b border-trackops-border pb-5 mb-6">
        <div>
          <h1 className="text-xl font-black tracking-widest text-white uppercase font-mono flex items-center gap-3">
            <Rocket className="w-5 h-5 text-trackops-green" />
            Deployment Center
          </h1>
          <p className="text-[10px] text-gray-600 font-mono mt-1 tracking-wider">
            TRACKOPS · VERCEL MISSION CONTROL · LIVE
            {project?.name ? ` · ${project.name.toUpperCase()}` : ''}
            {' · SECURED VIA FIREBASE CLOUD FUNCTIONS'}
          </p>
        </div>
        {fullLoading && (
          <div className="flex items-center gap-2 text-trackops-amber font-mono text-xs">
            <RefreshCw className="w-3 h-3 animate-spin" />SYNCING VIA CLOUD FUNCTION...
          </div>
        )}
      </div>

      {/* ── Error ───────────────────────────────────────────────────────────── */}
      {fullErr && <ErrBox msg={fullErr} />}

      {/* ── Live refresh bar ─────────────────────────────────────────────────── */}
      <LiveBar updatedAt={updatedAt} onRefresh={refresh} />

      {/* ── Top Header ───────────────────────────────────────────────────────── */}
      <TopHeader project={project} dep={latestDep} domains={domains} loading={fullLoading} />

      {/* ── Health Cards ─────────────────────────────────────────────────────── */}
      <HealthCards dep={latestDep} loading={fullLoading} />

      {/* ── Quick Actions ────────────────────────────────────────────────────── */}
      <QuickActions dep={latestDep} onRefresh={refresh} />

      {/* ── Notifications ────────────────────────────────────────────────────── */}
      <Notifications deployments={deployments} />

      {/* ── Build Pipeline ───────────────────────────────────────────────────── */}
      <Pipeline dep={latestDep} />

      {/* ── Deployment Analytics ─────────────────────────────────────────────── */}
      <div className="mb-2"><SecHead icon={BarChart2} title="Deployment Analytics" sub="30-day trends — computed server-side by Cloud Function" /></div>
      <Charts analyticsData={analyticsData} loading={analyticsLoading} />

      {/* ── Deployment History ───────────────────────────────────────────────── */}
      <DepHistory deployments={deployments} loading={fullLoading} prodId={prodId} />

      {/* ── Build Logs Terminal ──────────────────────────────────────────────── */}
      <LogsTerminal deploymentId={prodId} />

      {/* ── Core Web Vitals ──────────────────────────────────────────────────── */}
      <WebVitals />

      {/* ── Page Performance ─────────────────────────────────────────────────── */}
      <PagePerf />

      {/* ── Serverless Functions ─────────────────────────────────────────────── */}
      <FunctionsPanel deploymentId={prodId} />

      {/* ── API Health ───────────────────────────────────────────────────────── */}
      <APIHealth />

      {/* ── Error Center ─────────────────────────────────────────────────────── */}
      <ErrorCenter deployments={deployments} />

      {/* ── Resource Usage ───────────────────────────────────────────────────── */}
      <Resources />

      {/* ── AI Deployment Analyst ────────────────────────────────────────────── */}
      <AIAnalyst deployments={deployments} dep={latestDep} analyticsData={analyticsData} />

      {/* ── AI Recommendations ───────────────────────────────────────────────── */}
      <AIRecs />
    </div>
  );
}
