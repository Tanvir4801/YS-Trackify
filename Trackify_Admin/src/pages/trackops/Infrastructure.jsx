import React, { useState } from 'react';
import { 
  Network, Server, Activity, AlertTriangle, ShieldAlert,
  Cpu, HardDrive, Database, Globe, CheckCircle2, XCircle, Clock,
  RefreshCw, ChevronRight, Layers, Box, Flame, Info, MemoryStick
} from 'lucide-react';
import { 
  useInfraLensOverview, useInfraLensAlerts, useInfraLensHealth,
  useInfraLensKubernetes, useInfraLensContainers, useInfraLensForecast,
  useInfraLensIncident
} from '../../lib/services/trackopsQueryService';
import InfrastructureIncidentModal from './components/InfrastructureIncidentModal';

const Glass = ({ children, className = '', glow }) => (
  <div
    className={`bg-trackops-card/80 backdrop-blur-md border border-trackops-border rounded-xl p-4 relative overflow-hidden transition-all duration-200 hover:border-white/10 ${className}`}
    style={glow ? { boxShadow: `0 0 24px -8px ${glow}` } : {}}
  >
    {children}
  </div>
);

const MetricCard = ({ title, value, subtext, icon: Icon, colorClass }) => (
  <Glass className="flex flex-col">
    <div className="flex justify-between items-start mb-2">
      <div className="text-gray-400 font-mono text-xs uppercase tracking-wider">{title}</div>
      {Icon && <Icon className={`w-4 h-4 ${colorClass}`} />}
    </div>
    <div className="text-2xl font-semibold text-white font-mono mt-1">{value}</div>
    {subtext && <div className="text-xs text-gray-500 font-mono mt-2">{subtext}</div>}
  </Glass>
);

const StatusPill = ({ status, text }) => {
  const map = {
    'HEALTHY': 'bg-trackops-green/10 text-trackops-green border-trackops-green/30',
    'CONNECTED': 'bg-trackops-green/10 text-trackops-green border-trackops-green/30',
    'DEGRADED': 'bg-trackops-amber/10 text-trackops-amber border-trackops-amber/30',
    'UNAVAILABLE': 'bg-trackops-red/10 text-trackops-red border-trackops-red/30',
    'CRITICAL': 'bg-trackops-red/10 text-trackops-red border-trackops-red/30',
    'HIGH': 'bg-orange-500/10 text-orange-400 border-orange-500/30',
    'MEDIUM': 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30',
    'LOW': 'bg-blue-500/10 text-blue-400 border-blue-500/30'
  };
  return (
    <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold font-mono border uppercase ${map[status?.toUpperCase()] || map['UNAVAILABLE']}`}>
      {text || status}
    </span>
  );
};

export default function Infrastructure() {
  const [activeTab, setActiveTab] = useState('OVERVIEW');
  const [selectedIncidentId, setSelectedIncidentId] = useState(null);

  // React Query Hooks (respects caching & background sync config)
  const overviewQ = useInfraLensOverview();
  const alertsQ = useInfraLensAlerts();
  const healthQ = useInfraLensHealth();
  const k8sQ = useInfraLensKubernetes();
  const containersQ = useInfraLensContainers();
  const forecastQ = useInfraLensForecast();

  const isOffline = overviewQ.isError;
  const lastUpdated = overviewQ.dataUpdatedAt ? Math.floor((Date.now() - overviewQ.dataUpdatedAt) / 1000) + ' seconds ago' : 'Never';

  const handleRetry = () => {
    overviewQ.refetch();
    alertsQ.refetch();
    healthQ.refetch();
    k8sQ.refetch();
    containersQ.refetch();
    forecastQ.refetch();
  };

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white font-mono flex items-center">
            <Network className="w-6 h-6 mr-3 text-blue-400" />
            INFRASTRUCTURE
          </h1>
          <p className="text-sm text-gray-400 font-mono mt-1">Independent InfraLens Monitoring Integration</p>
        </div>
        
        <div className="flex items-center space-x-4">
          <div className="flex items-center text-xs font-mono">
            {isOffline ? (
              <span className="flex items-center text-trackops-red"><span className="w-2 h-2 rounded-full bg-trackops-red mr-2 animate-pulse" /> Offline</span>
            ) : overviewQ.isLoading ? (
              <span className="flex items-center text-trackops-amber"><RefreshCw className="w-3 h-3 mr-2 animate-spin" /> Syncing</span>
            ) : (
              <span className="flex items-center text-trackops-green"><span className="w-2 h-2 rounded-full bg-trackops-green mr-2 shadow-[0_0_8px_#00FF66]" /> Connected</span>
            )}
          </div>
          <div className="text-xs text-gray-500 font-mono hidden sm:block">
            Last updated: {lastUpdated}
          </div>
          <button onClick={handleRetry} className="p-2 hover:bg-trackops-card rounded-lg transition-colors group">
            <RefreshCw className={`w-4 h-4 text-gray-400 group-hover:text-white ${overviewQ.isFetching ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex space-x-1 bg-trackops-card/50 p-1 rounded-lg border border-trackops-border overflow-x-auto scrollbar-hide">
        {['OVERVIEW', 'ALERTS', 'HEALTH'].map(t => (
          <button
            key={t}
            onClick={() => setActiveTab(t)}
            className={`px-4 py-2 rounded-md font-mono text-xs tracking-wider transition-all whitespace-nowrap ${activeTab === t ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30' : 'text-gray-400 hover:text-gray-200 hover:bg-trackops-steel/50 border border-transparent'}`}
          >
            {t}
          </button>
        ))}
      </div>

      {/* Offline Banner */}
      {isOffline && (
        <Glass glow="#FF2A2A" className="border-trackops-red/30 bg-trackops-red/5">
          <div className="flex items-center">
            <AlertTriangle className="w-6 h-6 text-trackops-red mr-4" />
            <div className="flex-1">
              <h3 className="text-trackops-red font-bold font-mono">InfraLens Unavailable</h3>
              <p className="text-sm text-gray-400 font-mono mt-1">
                {overviewQ.error?.message || 'Unable to retrieve infrastructure metrics. The external monitoring service may be down.'}
              </p>
            </div>
            <button onClick={handleRetry} className="px-4 py-2 bg-trackops-red/10 hover:bg-trackops-red/20 text-trackops-red rounded font-mono text-xs font-bold transition-colors">
              RETRY
            </button>
          </div>
        </Glass>
      )}

      {/* OVERVIEW TAB */}
      {activeTab === 'OVERVIEW' && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <MetricCard 
              title="CPU Usage" 
              value={`${overviewQ.data?.data?.cpu_percent || 0}%`}
              icon={Cpu} colorClass="text-blue-400"
            />
            <MetricCard 
              title="Memory Usage" 
              value={`${overviewQ.data?.data?.ram_percent || 0}%`}
              icon={MemoryStick} colorClass="text-purple-400"
            />
            <MetricCard 
              title="Disk Usage" 
              value={`${overviewQ.data?.data?.disk_percent || 0}%`}
              icon={HardDrive} colorClass="text-teal-400"
            />
            <MetricCard 
              title="Network I/O" 
              value={overviewQ.data?.data?.network_status || 'Idle'}
              icon={Globe} colorClass="text-green-400"
            />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <Glass>
              <h3 className="text-sm font-bold text-white font-mono flex items-center mb-4">
                <Box className="w-4 h-4 mr-2 text-indigo-400" />
                Kubernetes Engine
              </h3>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <div className="text-xs text-gray-400 uppercase tracking-wider">Nodes</div>
                  <div className="text-xl text-white font-mono mt-1">
                    {k8sQ.data?.data?.healthy_nodes || overviewQ.data?.data?.healthy_nodes || 0} / {k8sQ.data?.data?.node_count || overviewQ.data?.data?.kubernetes_node_count || 0}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-400 uppercase tracking-wider">Pods</div>
                  <div className="text-xl text-white font-mono mt-1">
                    {k8sQ.data?.data?.pod_count || overviewQ.data?.data?.pod_count || 0}
                  </div>
                </div>
                <div className="col-span-2">
                  <div className="text-xs text-gray-400 uppercase tracking-wider">Failed/Restarting</div>
                  <div className="text-xl text-trackops-amber font-mono mt-1">
                    {Math.max(0, (k8sQ.data?.data?.pod_count || 0) - (k8sQ.data?.data?.running_pods || k8sQ.data?.data?.pod_count || 0))}
                  </div>
                </div>
              </div>
            </Glass>

            <Glass>
              <h3 className="text-sm font-bold text-white font-mono flex items-center mb-4">
                <Layers className="w-4 h-4 mr-2 text-cyan-400" />
                Docker Containers
              </h3>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <div className="text-xs text-gray-400 uppercase tracking-wider">Running</div>
                  <div className="text-xl text-white font-mono mt-1">
                    {overviewQ.data?.data?.running_containers || 0}
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-400 uppercase tracking-wider">Total</div>
                  <div className="text-xl text-white font-mono mt-1">
                    {overviewQ.data?.data?.container_count || 0}
                  </div>
                </div>
                <div className="col-span-2">
                  <div className="text-xs text-gray-400 uppercase tracking-wider">Failed</div>
                  <div className="text-xl text-trackops-red font-mono mt-1">
                    {Math.max(0, (overviewQ.data?.data?.container_count || 0) - (overviewQ.data?.data?.running_containers || 0))}
                  </div>
                </div>
              </div>
            </Glass>
          </div>

          {/* AI Forecast */}
          <Glass className="border-blue-500/30">
            <h3 className="text-sm font-bold text-white font-mono flex items-center mb-4">
              <Activity className="w-4 h-4 mr-2 text-blue-400" />
              Resource Forecast (InfraLens AI)
            </h3>
            <div className="flex items-center space-x-4">
              <StatusPill status={forecastQ.data?.data?.cpuRisk || 'LOW'} text={`${forecastQ.data?.data?.cpuRisk || 'LOW'} RISK`} />
              <span className="text-sm text-gray-300 font-mono">{forecastQ.data?.data?.summary || 'Resource usage is stable. No immediate scaling required.'}</span>
            </div>
          </Glass>
        </div>
      )}

      {/* ALERTS TAB */}
      {activeTab === 'ALERTS' && (
        <Glass>
          <div className="flex justify-between items-center mb-4">
            <h3 className="text-sm font-bold text-white font-mono flex items-center">
              <AlertTriangle className="w-4 h-4 mr-2 text-trackops-amber" />
              Active InfraLens Alerts
            </h3>
            <span className="text-xs text-gray-400 font-mono">
              Total: {alertsQ.data?.data?.length || 0}
            </span>
          </div>

          {!alertsQ.data?.data || alertsQ.data.data.length === 0 ? (
            <div className="text-center py-8">
              <CheckCircle2 className="w-8 h-8 text-trackops-green mx-auto mb-3 opacity-50" />
              <p className="text-gray-400 font-mono text-sm">No active alerts. System is stable.</p>
            </div>
          ) : (
            <div className="space-y-2">
              {alertsQ.data.data.map((alert, i) => (
                <div key={i} onClick={() => setSelectedIncidentId(alert.id)} className="flex items-center justify-between p-3 bg-trackops-steel/30 hover:bg-trackops-steel/50 rounded-lg cursor-pointer transition-colors group">
                  <div className="flex items-center">
                    <StatusPill status={alert.severity} />
                    <div className="ml-4">
                      <div className="text-sm font-mono text-white font-semibold">{alert.title}</div>
                      <div className="text-xs text-gray-500 font-mono mt-1">Source: {alert.source} • {alert.affectedService}</div>
                    </div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-gray-500 group-hover:text-white transition-colors" />
                </div>
              ))}
            </div>
          )}
        </Glass>
      )}

      {/* HEALTH TAB */}
      {activeTab === 'HEALTH' && (
        <Glass>
          <h3 className="text-sm font-bold text-white font-mono flex items-center mb-6">
            <ShieldAlert className="w-4 h-4 mr-2 text-purple-400" />
            Subsystem Health
          </h3>
          <div className="space-y-4">
            {[
              { name: 'InfraLens API', status: healthQ.data?.data?.infralens || 'HEALTHY' },
              { name: 'Prometheus', status: healthQ.data?.data?.prometheus || 'HEALTHY' },
              { name: 'Alertmanager', status: healthQ.data?.data?.alertmanager || 'HEALTHY' },
              { name: 'Kubernetes', status: healthQ.data?.data?.kubernetes || 'HEALTHY' },
              { name: 'Docker Engine', status: healthQ.data?.data?.docker || 'HEALTHY' },
            ].map((sys, i) => (
              <div key={i} className="flex justify-between items-center p-3 bg-trackops-steel/20 rounded-lg border border-trackops-border">
                <span className="text-sm text-gray-300 font-mono font-semibold">{sys.name}</span>
                <StatusPill status={sys.status} />
              </div>
            ))}
          </div>
        </Glass>
      )}

      {/* Incident Modal */}
      {selectedIncidentId && (
        <InfrastructureIncidentModal 
          incidentId={selectedIncidentId} 
          onClose={() => setSelectedIncidentId(null)} 
        />
      )}
    </div>
  );
}
