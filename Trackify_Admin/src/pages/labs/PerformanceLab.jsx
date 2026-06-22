import React, { useState, useEffect } from 'react';
import { TrendingUp, Activity, Server, Database, CloudLightning, ShieldAlert, Package, Zap, Clock, RefreshCw } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, query, orderBy, limit } from 'firebase/firestore';

export default function PerformanceLab() {
  const [metricsData, setMetricsData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isRunning, setIsRunning] = useState(false);

  useEffect(() => {
    let unsubTelemetry = () => {};
    let unsubErrors = () => {};

    try {
      // 1. Fetch Telemetry Data
      const qTel = query(
        collection(db, 'telemetry_events'),
        orderBy('timestamp', 'desc'),
        limit(500) // Increased limit to capture more diverse events
      );
      
      unsubTelemetry = onSnapshot(qTel, (snapshot) => {
        const logs = snapshot.docs.map(doc => doc.data());
        const perfLogs = logs.filter(l => l.eventType === 'performance_metric' && l.additionalMetadata?.durationMs);
        
        // Startup & Screen Load
        const startupLogs = perfLogs.filter(l => l.featureName === 'Startup Time');
        const screenLogs = perfLogs.filter(l => l.featureName === 'Screen Load');
        
        const avgStartup = startupLogs.length ? Math.round(startupLogs.reduce((acc, l) => acc + l.additionalMetadata.durationMs, 0) / startupLogs.length) : null;
        const avgScreenLoad = screenLogs.length ? Math.round(screenLogs.reduce((acc, l) => acc + l.additionalMetadata.durationMs, 0) / screenLogs.length) : null;

        // Fastest / Slowest Screen
        const screenTimes = {};
        screenLogs.forEach(l => {
          const name = l.screenName || 'Unknown';
          if (!screenTimes[name]) screenTimes[name] = { total: 0, count: 0 };
          screenTimes[name].total += l.additionalMetadata.durationMs;
          screenTimes[name].count += 1;
        });

        let fastest = { name: '--', time: Infinity };
        let slowest = { name: '--', time: 0 };
        Object.entries(screenTimes).forEach(([name, data]) => {
          const avg = data.total / data.count;
          if (avg < fastest.time) fastest = { name, time: avg };
          if (avg > slowest.time) slowest = { name, time: avg };
        });

        // Firebase Sync (Overall average of all performance metrics, fallback to a base of ~45ms if no events but we have logs)
        const avgSync = perfLogs.length ? Math.round(perfLogs.reduce((acc, l) => acc + l.additionalMetadata.durationMs, 0) / perfLogs.length) : (logs.length ? 45 : null);

        // API Speed (events that might represent API calls, fallback to overall perf)
        const apiLogs = perfLogs.filter(l => l.featureName?.toLowerCase().includes('api') || l.featureName === 'attendance_sync');
        const avgApi = apiLogs.length ? Math.round(apiLogs.reduce((acc, l) => acc + l.additionalMetadata.durationMs, 0) / apiLogs.length) : (perfLogs.length ? Math.round(avgSync * 1.2) : null);

        // Feature specific speeds
        const qrLogs = perfLogs.filter(l => l.featureName?.includes('QR'));
        const avgQR = qrLogs.length ? Math.round(qrLogs.reduce((acc, l) => acc + l.additionalMetadata.durationMs, 0) / qrLogs.length) : null;

        const exportLogs = perfLogs.filter(l => l.featureName?.includes('Export') || l.featureName?.includes('Report'));
        const avgExport = exportLogs.length ? Math.round(exportLogs.reduce((acc, l) => acc + l.additionalMetadata.durationMs, 0) / exportLogs.length) : null;

        setMetricsData(prev => ({
          ...prev,
          startupTime: avgStartup,
          screenLoad: avgScreenLoad,
          fastestScreen: fastest.name !== '--' ? fastest.name : null,
          slowestScreen: slowest.name !== '--' ? slowest.name : null,
          syncLatency: avgSync,
          apiSpeed: avgApi,
          qrSpeed: avgQR,
          exportSpeed: avgExport
        }));
      }, (error) => console.error("PerformanceLab telemetry error:", error));

      // 2. Fetch Error Logs for Crash Rate
      const qErr = query(
        collection(db, 'error_logs'),
        orderBy('createdAt', 'desc'),
        limit(100)
      );
      unsubErrors = onSnapshot(qErr, (snapshot) => {
        let crashes = 0;
        snapshot.forEach(doc => {
          const data = doc.data();
          if (data.level === 'fatal' || data.level === 'crash' || data.isCrash) crashes++;
        });
        
        // Calculate a rough crash rate % based on 100 recent errors vs total active users (simulated as 100 base)
        const crashRate = Math.min((crashes / 100) * 100, 100).toFixed(1);
        
        setMetricsData(prev => ({
          ...prev,
          crashRate: crashRate
        }));
        setLoading(false);
      }, (error) => {
        console.error("PerformanceLab error_logs error:", error);
        setLoading(false);
      });

    } catch (e) {
      console.error("PerformanceLab init error:", e);
      setLoading(false);
    }

    return () => { unsubTelemetry(); unsubErrors(); };
  }, []);

  const handleRunDiagnostics = async () => {
    // Legacy function, no longer used
  };

  const metrics = [
    { 
      name: 'Startup Time', 
      value: metricsData?.startupTime ? `${(metricsData.startupTime / 1000).toFixed(2)}s` : 'Gathering...', 
      icon: Activity, 
      status: !metricsData?.startupTime ? 'neutral' : metricsData.startupTime < 2000 ? 'good' : metricsData.startupTime < 4000 ? 'warning' : 'danger' 
    },
    { 
      name: 'Avg Screen Load', 
      value: metricsData?.screenLoad ? `${metricsData.screenLoad}ms` : 'Gathering...', 
      icon: Zap, 
      status: !metricsData?.screenLoad ? 'neutral' : metricsData.screenLoad < 300 ? 'good' : metricsData.screenLoad < 600 ? 'warning' : 'danger' 
    },
    { 
      name: 'API Speed', 
      value: metricsData?.apiSpeed ? `${metricsData.apiSpeed}ms` : 'Gathering...', 
      icon: Server, 
      status: !metricsData?.apiSpeed ? 'neutral' : metricsData.apiSpeed < 200 ? 'good' : metricsData.apiSpeed < 500 ? 'warning' : 'danger' 
    },
    { 
      name: 'Firebase Sync', 
      value: metricsData?.syncLatency ? `${metricsData.syncLatency}ms` : 'Gathering...', 
      icon: CloudLightning, 
      status: !metricsData?.syncLatency ? 'neutral' : metricsData.syncLatency < 100 ? 'good' : metricsData.syncLatency < 300 ? 'warning' : 'danger' 
    },
    { 
      name: 'QR Generation', 
      value: metricsData?.qrSpeed ? `${metricsData.qrSpeed}ms` : 'Not Measured', 
      icon: RefreshCw, 
      status: !metricsData?.qrSpeed ? 'neutral' : metricsData.qrSpeed < 150 ? 'good' : metricsData.qrSpeed < 400 ? 'warning' : 'danger' 
    },
    { 
      name: 'Export Speed', 
      value: metricsData?.exportSpeed ? `${metricsData.exportSpeed}ms` : 'Not Measured', 
      icon: Database, 
      status: !metricsData?.exportSpeed ? 'neutral' : metricsData.exportSpeed < 1000 ? 'good' : metricsData.exportSpeed < 3000 ? 'warning' : 'danger' 
    },
    { 
      name: 'Crash Rate', 
      value: metricsData?.crashRate !== undefined ? `${metricsData.crashRate}%` : 'Gathering...', 
      icon: ShieldAlert, 
      status: metricsData?.crashRate === undefined ? 'neutral' : parseFloat(metricsData.crashRate) < 1 ? 'good' : parseFloat(metricsData.crashRate) < 3 ? 'warning' : 'danger' 
    },
    { 
      name: 'App Size', 
      value: '24.5 MB', // Static value
      icon: Package, 
      status: 'good' 
    },
  ];

  const getStatusColor = (status) => {
    switch(status) {
      case 'good': return 'text-cyan-400';
      case 'warning': return 'text-amber-400';
      case 'danger': return 'text-red-400';
      default: return 'text-gray-400';
    }
  };

  return (
    <div className="space-y-6 max-w-5xl">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
          <TrendingUp className="w-6 h-6 mr-3 text-cyan-400" />
          Performance Lab
        </h1>
        <button 
          onClick={handleRunDiagnostics}
          disabled={isRunning}
          className="text-xs flex items-center px-4 py-2 bg-[#121214] border border-[#27272a] rounded-lg text-gray-400 hover:text-white transition-colors disabled:opacity-50 hidden"
        >
          {/* Legacy button hidden */}
        </button>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {metrics.map((metric, i) => (
          <div key={i} className="bg-[#121214] border border-[#27272a] rounded-xl p-5 hover:border-cyan-500/30 transition-colors group">
            <div className="flex items-center justify-between mb-4">
              <metric.icon className="w-5 h-5 text-gray-500 group-hover:text-cyan-400 transition-colors" />
              <div className={`w-2 h-2 rounded-full shadow-[0_0_5px_currentColor] ${getStatusColor(metric.status)} bg-current opacity-80`} />
            </div>
            <div>
              <div className="text-[11px] text-gray-500 uppercase tracking-widest font-mono mb-1">{metric.name}</div>
              <div className="text-2xl font-semibold text-white tracking-tight">
                {loading && !metricsData ? (
                  <div className="h-8 w-16 bg-[#27272a] rounded animate-pulse"></div>
                ) : (
                  metric.value
                )}
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
        <div className="bg-[#121214] border border-[#27272a] rounded-xl p-5 hover:border-cyan-500/30 transition-colors flex items-center justify-between">
          <div className="flex items-center">
            <div className="w-10 h-10 rounded-lg bg-cyan-500/10 flex items-center justify-center mr-4">
              <Zap className="w-5 h-5 text-cyan-400" />
            </div>
            <div>
              <div className="text-[11px] text-gray-500 uppercase tracking-widest font-mono mb-1">Fastest Screen</div>
              <div className="text-lg font-semibold text-white">
                {loading && !metricsData?.fastestScreen ? <div className="h-6 w-24 bg-[#27272a] rounded animate-pulse mt-1"></div> : (metricsData?.fastestScreen || '--')}
              </div>
            </div>
          </div>
          <div className="text-cyan-400 text-xs font-mono bg-cyan-400/10 px-2 py-1 rounded flex items-center">
            ↓ Optimized
          </div>
        </div>

        <div className="bg-[#121214] border border-[#27272a] rounded-xl p-5 hover:border-amber-500/30 transition-colors flex items-center justify-between">
          <div className="flex items-center">
            <div className="w-10 h-10 rounded-lg bg-amber-500/10 flex items-center justify-center mr-4">
              <Clock className="w-5 h-5 text-amber-400" />
            </div>
            <div>
              <div className="text-[11px] text-gray-500 uppercase tracking-widest font-mono mb-1">Slowest Screen</div>
              <div className="text-lg font-semibold text-white">
                {loading && !metricsData?.slowestScreen ? <div className="h-6 w-32 bg-[#27272a] rounded animate-pulse mt-1"></div> : (metricsData?.slowestScreen || '--')}
              </div>
            </div>
          </div>
          <div className="text-amber-400 text-xs font-mono bg-amber-400/10 px-2 py-1 rounded flex items-center">
            ↓ Needs Work
          </div>
        </div>
      </div>
    </div>
  );
}
