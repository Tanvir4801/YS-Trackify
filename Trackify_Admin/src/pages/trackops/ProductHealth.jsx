import React, { useState, useEffect } from 'react';
import { Server, Activity, Database, HardDrive, Key, Bell, Cpu, CheckCircle, AlertTriangle, CloudLightning, Users, Zap, Globe, FileText, Smartphone } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, query, orderBy, limit, doc } from 'firebase/firestore';
import telemetryAggregator from '../../lib/services/telemetryAggregator.service';

export default function ProductHealth() {
  const [infraMetrics, setInfraMetrics] = useState([]);
  const [serviceMetrics, setServiceMetrics] = useState([]);
  const [liveUsers, setLiveUsers] = useState([]);
  const [systemHealth, setSystemHealth] = useState({ missionHealthPercentage: 100, totalRequests: 0, monthlyUsage: 0 });
  const [contractorMap, setContractorMap] = useState({});

  useEffect(() => {
    // Start generating real aggregated telemetry metrics
    telemetryAggregator.start();

    let infraUnsub = () => {};
    let serviceUnsub = () => {};
    let usersUnsub = () => {};
    let healthUnsub = () => {};
    let contractorsUnsub = () => {};

    try {
      infraUnsub = onSnapshot(collection(db, 'infrastructure_metrics'), (snap) => {
        try {
          const metrics = snap.docs.map(d => ({ id: d.id, ...d.data() }));
          setInfraMetrics(metrics);
        } catch(e) { console.error('ProductHealth infra metrics error:', e); }
      });

      serviceUnsub = onSnapshot(collection(db, 'service_metrics'), (snap) => {
        try {
          const metrics = snap.docs.map(d => ({ id: d.id, ...d.data() }));
          setServiceMetrics(metrics);
        } catch(e) { console.error('ProductHealth service metrics error:', e); }
      });

      usersUnsub = onSnapshot(query(collection(db, 'live_users'), orderBy('lastSeen', 'desc'), limit(100)), (snap) => {
        try {
          let count = 0;
          snap.forEach(d => {
            if (d.data().lastSeen) {
              const diffMs = new Date() - d.data().lastSeen.toDate();
              if (diffMs / 60000 < 5) count++;
            }
          });
          setLiveUsers(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
        } catch(e) { console.error('ProductHealth live users error:', e); }
      });

      healthUnsub = onSnapshot(doc(db, 'system_health', 'global'), (docSnap) => {
        try {
          if (docSnap.exists()) {
            setSystemHealth(docSnap.data());
          }
        } catch(e) { console.error('ProductHealth system health error:', e); }
      });

      contractorsUnsub = onSnapshot(collection(db, 'contractors'), (snap) => {
        try {
          const map = {};
          snap.forEach(doc => {
            map[doc.id] = doc.data().companyName || doc.data().name || doc.id;
          });
          setContractorMap(map);
        } catch(e) { console.error('ProductHealth contractors error:', e); }
      });
    } catch(e) { console.error('ProductHealth listener initialization error:', e); }

    return () => {
      telemetryAggregator.stop();
      try { infraUnsub(); } catch(e) {}
      try { serviceUnsub(); } catch(e) {}
      try { usersUnsub(); } catch(e) {}
      try { healthUnsub(); } catch(e) {}
      try { contractorsUnsub(); } catch(e) {}
    };
  }, []);

  const getStatusIcon = (status) => {
    if (status === 'RED') return <CloudLightning className="w-5 h-5 text-trackops-red animate-bounce" />;
    if (status === 'YELLOW') return <AlertTriangle className="w-5 h-5 text-trackops-amber animate-pulse" />;
    return <CheckCircle className="w-5 h-5 text-trackops-green" />;
  };

  const getStatusText = (status) => {
    if (status === 'RED') return 'DOWN';
    if (status === 'YELLOW') return 'DEGRADED';
    return 'ONLINE';
  };

  const getIconForInfra = (id) => {
    if (id.includes('firestore')) return Database;
    if (id.includes('storage')) return HardDrive;
    if (id.includes('auth')) return Key;
    if (id.includes('function')) return Cpu;
    if (id.includes('notification')) return Bell;
    return Server;
  };

  const getIconForService = (id) => {
    if (id.includes('attendance')) return Activity;
    if (id.includes('payroll')) return Zap;
    if (id.includes('pdf') || id.includes('export')) return FileText;
    return Cpu;
  };

  return (
    <div className="space-y-6 pb-10">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between border-b border-trackops-border pb-4 gap-4">
        <h1 className="text-2xl font-bold tracking-widest text-white uppercase flex items-center">
          <Server className="w-6 h-6 mr-3 text-trackops-green animate-pulse" />
          Mission Control
        </h1>
        <div className="flex items-center text-xs font-mono text-gray-400">
          Global Telemetry: <span className="text-white ml-2">Active</span>
          <div className="w-2 h-2 rounded-full bg-trackops-green animate-pulse ml-3" />
        </div>
      </div>

      {/* Global Analytics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 font-mono">
        <div className="bg-trackops-card border border-trackops-border p-4 rounded flex justify-between items-center relative overflow-hidden">
          <div className={`absolute right-0 top-0 w-24 h-24 rounded-full blur-2xl opacity-20 pointer-events-none ${systemHealth.missionHealthPercentage < 90 ? 'bg-trackops-red' : 'bg-trackops-green'}`} />
          <div>
            <div className="text-gray-500 text-[10px] uppercase tracking-wider mb-1">Mission Health</div>
            <div className={`text-3xl font-bold ${systemHealth.missionHealthPercentage < 90 ? 'text-trackops-red' : 'text-trackops-green'}`}>
              {systemHealth.missionHealthPercentage || 100}%
            </div>
          </div>
          <Activity className="w-8 h-8 text-gray-700" />
        </div>
        <div className="bg-trackops-card border border-trackops-border p-4 rounded flex justify-between items-center">
          <div>
            <div className="text-gray-500 text-[10px] uppercase tracking-wider mb-1">Live Clients</div>
            <div className="text-3xl font-bold text-white">{liveUsers.length}</div>
          </div>
          <Users className="w-8 h-8 text-trackops-amber opacity-30" />
        </div>
        <div className="bg-trackops-card border border-trackops-border p-4 rounded flex justify-between items-center">
          <div>
            <div className="text-gray-500 text-[10px] uppercase tracking-wider mb-1">Total API Requests</div>
            <div className="text-3xl font-bold text-white">{(systemHealth.totalRequests || 0).toLocaleString()}</div>
          </div>
          <Globe className="w-8 h-8 text-blue-500 opacity-20" />
        </div>
        <div className="bg-trackops-card border border-trackops-border p-4 rounded flex justify-between items-center">
          <div>
            <div className="text-gray-500 text-[10px] uppercase tracking-wider mb-1">Est. Firebase Cost</div>
            <div className="text-3xl font-bold text-white">${systemHealth.estimatedCosts || '0.00'}</div>
          </div>
          <Database className="w-8 h-8 text-gray-700" />
        </div>
      </div>

      {/* Infrastructure Metrics (Firebase) */}
      <div>
        <h2 className="text-xs text-gray-500 uppercase tracking-widest font-bold mb-4 font-mono">Infrastructure (Firebase)</h2>
        {infraMetrics.length === 0 ? (
          <div className="text-gray-500 font-mono text-sm">Awaiting telemetry data...</div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 font-mono">
            {infraMetrics.map((service) => {
              const Icon = getIconForInfra(service.id);
              return (
                <div key={service.id} className={`bg-trackops-card border rounded p-5 relative overflow-hidden transition-colors ${
                  service.status === 'RED' ? 'border-trackops-red/50 hover:border-trackops-red' :
                  service.status === 'YELLOW' ? 'border-trackops-amber/50 hover:border-trackops-amber' :
                  'border-trackops-border hover:border-trackops-green/50'
                }`}>
                  <div className={`absolute top-0 right-0 w-32 h-32 rounded-full blur-3xl opacity-10 pointer-events-none ${
                    service.status === 'RED' ? 'bg-trackops-red' :
                    service.status === 'YELLOW' ? 'bg-trackops-amber' :
                    'bg-trackops-green'
                  }`} />
                  <div className="flex justify-between items-start mb-4 relative z-10">
                    <div className="flex items-center">
                      <div className={`p-2 rounded mr-3 ${
                        service.status === 'RED' ? 'bg-trackops-red/20 text-trackops-red' :
                        service.status === 'YELLOW' ? 'bg-trackops-amber/20 text-trackops-amber' :
                        'bg-trackops-green/20 text-trackops-green'
                      }`}>
                        <Icon className="w-5 h-5" />
                      </div>
                      <h3 className="text-white font-bold">{service.name}</h3>
                    </div>
                    <div className="flex flex-col items-end">
                      {getStatusIcon(service.status)}
                    </div>
                  </div>
                  <div className="space-y-2 relative z-10">
                    <div className="flex justify-between text-xs">
                      <span className="text-gray-500 uppercase">Status</span>
                      <span className={`font-bold ${
                        service.status === 'RED' ? 'text-trackops-red' :
                        service.status === 'YELLOW' ? 'text-trackops-amber' :
                        'text-trackops-green'
                      }`}>{getStatusText(service.status)}</span>
                    </div>
                    <div className="flex justify-between text-xs border-t border-trackops-border/50 pt-2">
                      <span className="text-gray-500 uppercase">Latency</span>
                      <span className="text-white">{service.latencyMs}ms</span>
                    </div>
                    <div className="flex justify-between text-xs border-t border-trackops-border/50 pt-2">
                      <span className="text-gray-500 uppercase">Details</span>
                      <span className="text-gray-400 text-right max-w-[60%] truncate">{service.details}</span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Product Engines */}
      <div>
        <h2 className="text-xs text-gray-500 uppercase tracking-widest font-bold mt-8 mb-4 font-mono">Core Product Engines</h2>
        {serviceMetrics.length === 0 ? (
          <div className="text-gray-500 font-mono text-sm">Awaiting telemetry data...</div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 font-mono">
            {serviceMetrics.map((engine) => {
              const Icon = getIconForService(engine.id);
              return (
                <div key={engine.id} className="bg-trackops-navy border border-trackops-border p-4 rounded hover:border-trackops-amber/30 transition-colors">
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center">
                      <Icon className="w-4 h-4 text-gray-400 mr-2" />
                      <h3 className="text-white text-xs font-bold uppercase">{engine.name}</h3>
                    </div>
                    {getStatusIcon(engine.status)}
                  </div>
                  <div className="grid grid-cols-2 gap-2 mt-4">
                    <div className="bg-trackops-bg p-2 rounded">
                      <div className="text-[9px] text-gray-500 uppercase">Success</div>
                      <div className="text-trackops-green text-sm font-bold">{engine.successRate}%</div>
                    </div>
                    <div className="bg-trackops-bg p-2 rounded">
                      <div className="text-[9px] text-gray-500 uppercase">Failed</div>
                      <div className="text-trackops-red text-sm font-bold">{engine.failedRequests}</div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Live User Traffic feed */}
      <div>
        <h2 className="text-xs text-gray-500 uppercase tracking-widest font-bold mt-8 mb-4 font-mono">Live Traffic (Recent Pings)</h2>
        <div className="bg-trackops-card border border-trackops-border rounded overflow-hidden font-mono">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm text-gray-300">
              <thead className="bg-trackops-navy/50 text-[10px] uppercase text-gray-500 border-b border-trackops-border">
                <tr>
                  <th className="px-4 py-3">Platform</th>
                  <th className="px-4 py-3">Company</th>
                  <th className="px-4 py-3">User ID</th>
                  <th className="px-4 py-3">Current Screen</th>
                  <th className="px-4 py-3">Latency</th>
                  <th className="px-4 py-3">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-trackops-border">
                {liveUsers.length === 0 ? (
                  <tr>
                    <td colSpan="6" className="px-4 py-6 text-center text-gray-500 text-xs">No active clients detected.</td>
                  </tr>
                ) : liveUsers.map((user) => (
                  <tr key={user.id} className="hover:bg-trackops-navy/50 transition-colors text-xs">
                    <td className="px-4 py-3 font-bold text-white flex items-center">
                      <Smartphone className="w-3 h-3 mr-2 text-gray-400" />
                      {user.platform} <span className="text-[9px] text-gray-500 ml-2">v{user.appVersion}</span>
                    </td>
                    <td className="px-4 py-3 text-trackops-amber">
                      {(user.companyName && user.companyName !== 'Unknown') ? user.companyName : (contractorMap[user.companyId] || user.companyId)}
                    </td>
                    <td className="px-4 py-3">{user.userId}</td>
                    <td className="px-4 py-3 text-gray-400">{user.currentScreen}</td>
                    <td className="px-4 py-3">{user.latencyMs}ms</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-0.5 rounded text-[9px] font-bold ${
                        user.networkStatus === 'ONLINE' ? 'bg-trackops-green/20 text-trackops-green' : 
                        user.networkStatus === 'SLOW' ? 'bg-trackops-amber/20 text-trackops-amber' : 
                        'bg-red-500/20 text-red-400'
                      }`}>
                        {user.networkStatus}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
