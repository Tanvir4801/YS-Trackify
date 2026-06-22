import React, { useState, useEffect } from 'react';
import { Shield, AlertTriangle, Eye, Database, Lock, ServerCrash, Activity, Bot, CheckCircle } from 'lucide-react';
import { collection, query, orderBy, limit, onSnapshot, getDocs } from 'firebase/firestore';
import { db, functions } from '../../lib/firebase';
import { httpsCallable } from 'firebase/functions';

export default function SecurityCenter() {
  const [activeTab, setActiveTab] = useState('security'); // security, explorer

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between border-b border-trackops-border pb-4">
        <h1 className="text-2xl font-bold tracking-widest text-white uppercase flex items-center">
          <Shield className="w-6 h-6 mr-3 text-trackops-red animate-pulse" />
          Security & Database
        </h1>
        <div className="flex space-x-2 font-mono text-sm">
          <button onClick={() => setActiveTab('security')} className={`px-4 py-2 rounded border transition-colors ${activeTab === 'security' ? 'bg-trackops-steel text-white border-trackops-red' : 'bg-trackops-navy text-gray-400 border-trackops-border hover:text-white'}`}>Threat Monitor</button>
          <button onClick={() => setActiveTab('explorer')} className={`px-4 py-2 rounded border transition-colors ${activeTab === 'explorer' ? 'bg-trackops-steel text-white border-trackops-red' : 'bg-trackops-navy text-gray-400 border-trackops-border hover:text-white'}`}>DB Explorer</button>
        </div>
      </div>

      <div className="mt-4">
        {activeTab === 'security' && <ThreatMonitor />}
        {activeTab === 'explorer' && <DBExplorer />}
      </div>
    </div>
  );
}

function ThreatMonitor() {
  const [alerts, setAlerts] = useState([]);
  const [stats, setStats] = useState({ active: 0, failedLogins: 0, violations: 0 });

  useEffect(() => {
    const q = query(collection(db, 'security_events'), orderBy('timestamp', 'desc'), limit(50));
    return onSnapshot(q, (snap) => {
      const logs = snap.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        time: doc.data().timestamp?.toDate()?.toLocaleString() || 'Just now',
        level: doc.data().type === 'account_lockout' ? 'Critical' : 'High'
      }));
      setAlerts(logs);
      setStats({
        active: logs.filter(l => l.type === 'account_lockout').length,
        failedLogins: logs.filter(l => l.type === 'failed_login').length,
        violations: logs.filter(l => l.type === 'rule_violation').length,
      });
    }, (error) => {
      console.error("Firestore error:", error);
    });
  }, []);

  const [executingId, setExecutingId] = useState(null);

  const handleExecuteAction = async (alert) => {
    if (!alert.aiAnalysis || !alert.aiAnalysis.action || alert.aiAnalysis.action === 'IGNORE') return;
    
    setExecutingId(alert.id);
    try {
      const executeSecurityAction = httpsCallable(functions, 'executeSecurityAction');
      await executeSecurityAction({
        action: alert.aiAnalysis.action,
        targetUid: alert.uid || alert.email, // Best effort fallback
        targetEmail: alert.email,
        eventId: alert.id
      });
      alert('Action executed successfully.');
    } catch (error) {
      console.error('Error executing security action:', error);
      alert('Failed to execute action. Ensure the user exists and you have permissions.');
    }
    setExecutingId(null);
  };

  return (
    <div className="space-y-6 font-mono">
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-trackops-card border border-trackops-red p-4 rounded text-center">
          <div className="text-trackops-red text-3xl font-bold mb-1">{stats.active}</div>
          <div className="text-gray-500 text-xs uppercase tracking-wider">Active Threats</div>
        </div>
        <div className="bg-trackops-card border border-trackops-border p-4 rounded text-center">
          <div className="text-white text-3xl font-bold mb-1">{stats.failedLogins}</div>
          <div className="text-gray-500 text-xs uppercase tracking-wider">Failed Logins (50)</div>
        </div>
        <div className="bg-trackops-card border border-trackops-border p-4 rounded text-center">
          <div className="text-white text-3xl font-bold mb-1">{stats.violations}</div>
          <div className="text-gray-500 text-xs uppercase tracking-wider">Rule Violations</div>
        </div>
        <div className="bg-trackops-card border border-trackops-green p-4 rounded text-center">
          <div className="text-trackops-green text-3xl font-bold mb-1">SECURE</div>
          <div className="text-gray-500 text-xs uppercase tracking-wider">System Status</div>
        </div>
      </div>

      <div className="bg-trackops-card border border-trackops-border rounded-md overflow-hidden">
        <div className="p-4 bg-trackops-navy/50 border-b border-trackops-border flex items-center">
          <AlertTriangle className="w-4 h-4 text-trackops-red mr-2" />
          <span className="text-xs text-gray-400 uppercase tracking-widest">Security Log</span>
        </div>
        <div className="p-4 space-y-4">
          {alerts.map(alert => (
            <div key={alert.id} className="flex flex-col md:flex-row md:items-center justify-between p-3 border border-trackops-border rounded hover:bg-trackops-navy/30 transition-colors">
              <div className="flex items-center mb-2 md:mb-0">
                <span className={`px-2 py-1 text-[10px] uppercase rounded mr-4 ${
                  alert.level === 'Critical' ? 'bg-trackops-red text-white' :
                  alert.level === 'High' ? 'bg-trackops-red/20 text-trackops-red border border-trackops-red/50' :
                  'bg-trackops-amber/20 text-trackops-amber border border-trackops-amber/50'
                }`}>
                  {alert.level}
                </span>
                <div>
                  <div className="text-white font-bold text-sm">{alert.type}</div>
                  <div className="text-gray-400 text-xs">{alert.reason || alert.email || JSON.stringify(alert)}</div>
                  {alert.aiAnalysis && (
                    <div className="mt-2 flex items-start gap-2 bg-black/40 p-2 rounded border border-trackops-amber/30">
                      <Bot className="w-4 h-4 text-trackops-amber mt-0.5 shrink-0" />
                      <div>
                        <div className="text-xs font-bold text-trackops-amber mb-0.5">AI Security Guard Suggests: {alert.aiAnalysis.action.replace('_', ' ')}</div>
                        <div className="text-[10px] text-gray-400">{alert.aiAnalysis.reason}</div>
                      </div>
                    </div>
                  )}
                </div>
              </div>
              <div className="flex flex-col items-end space-y-2 text-xs">
                <span className="text-gray-500">{alert.time}</span>
                {alert.aiAnalysis && alert.aiAnalysis.action && alert.aiAnalysis.action !== 'IGNORE' && (
                  <button 
                    onClick={() => handleExecuteAction(alert)}
                    disabled={executingId === alert.id || !alert.uid}
                    className="px-3 py-1.5 bg-trackops-red/20 border border-trackops-red text-trackops-red hover:bg-trackops-red hover:text-white transition-colors rounded font-bold uppercase tracking-widest flex items-center gap-2 disabled:opacity-50"
                  >
                    {executingId === alert.id ? 'Executing...' : `Execute ${alert.aiAnalysis.action.split('_')[0]}`}
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function DBExplorer() {
  const collections = ['contractors', 'labours', 'subscriptions', 'support_tickets', 'mission_logs', 'security_logs', 'telemetry_events'];
  const [activeCollection, setActiveCollection] = useState('contractors');
  const [docsData, setDocsData] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    async function fetchDocs() {
      setLoading(true);
      try {
        const q = query(collection(db, activeCollection), limit(10));
        const snap = await getDocs(q);
        setDocsData(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      } catch (e) {
        setDocsData([{ error: e.message }]);
      }
      setLoading(false);
    }
    fetchDocs();
  }, [activeCollection]);

  return (
    <div className="grid grid-cols-1 md:grid-cols-4 gap-6 font-mono h-[600px]">
      <div className="col-span-1 border border-trackops-border bg-trackops-card rounded flex flex-col overflow-hidden">
        <div className="p-4 border-b border-trackops-border bg-trackops-navy/50 text-xs uppercase tracking-widest text-gray-400 flex items-center">
          <Database className="w-4 h-4 mr-2" /> Collections
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-1">
          {collections.map(c => (
            <button key={c} onClick={() => setActiveCollection(c)} className={`w-full text-left px-3 py-2 rounded text-sm transition-colors ${
              c === activeCollection ? 'bg-trackops-steel text-white border-l-2 border-trackops-green' : 'text-gray-400 hover:bg-trackops-navy'
            }`}>
              {c}
            </button>
          ))}
        </div>
      </div>
      
      <div className="col-span-3 border border-trackops-border bg-trackops-card rounded flex flex-col overflow-hidden relative">
        <div className="absolute top-4 right-4 text-[10px] text-trackops-amber flex items-center border border-trackops-amber/50 bg-trackops-amber/10 px-2 py-1 rounded z-10">
          <Lock className="w-3 h-3 mr-1" /> READ ONLY MODE
        </div>
        
        <div className="p-4 border-b border-trackops-border bg-trackops-navy/50 text-xs uppercase tracking-widest text-white">
          /{activeCollection}
        </div>
        <div className="flex-1 overflow-y-auto p-4 bg-[#0a0f18]">
          {loading ? (
             <div className="text-gray-500 animate-pulse">Querying Database...</div>
          ) : (
            <pre className="text-xs text-green-400 font-mono whitespace-pre-wrap">
              {JSON.stringify({
                docs: docsData,
                __meta__: { count: docsData.length, warning: "Never edit production data directly." }
              }, null, 2)}
            </pre>
          )}
        </div>
      </div>
    </div>
  );
}
