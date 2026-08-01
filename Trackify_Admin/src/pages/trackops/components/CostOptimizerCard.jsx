import React from 'react';
import { Database, Zap, Clock, ShieldAlert, Ban } from 'lucide-react';
import { useTrackOpsMonitoring } from '../../../context/TrackOpsMonitoringContext';
import { useQueryClient } from '@tanstack/react-query';

export default function CostOptimizerCard() {
  const { monitoringEnabled, isPaused, isMonitoringActive, lastStoppedAt } = useTrackOpsMonitoring();
  const queryClient = useQueryClient();

  // Very rough estimates for the UI based on React Query active queries
  const activeQueries = queryClient.getQueryCache().findAll({ type: 'active' }).length;
  
  // Simulated estimates
  const pollingJobs = isMonitoringActive ? Math.min(activeQueries, 10) : 0;
  const activeListeners = isMonitoringActive ? 3 : 0; // Telemetry, Support Tickets, Error Logs
  const apiPolling = isMonitoringActive ? 2 : 0; // Vercel, Analytics
  
  // Estimate avoided calls based on how long it's been off
  let avoidedCalls = 0;
  if (!isMonitoringActive && lastStoppedAt) {
    const hoursOff = (Date.now() - lastStoppedAt) / (1000 * 60 * 60);
    // Rough estimate: ~60 calls an hour across all pollers when left open
    avoidedCalls = Math.round(hoursOff * 60);
  }

  return (
    <div className={`bg-trackops-card border rounded-md p-4 font-mono relative overflow-hidden ${
      !monitoringEnabled ? 'border-trackops-amber' : 
      isPaused ? 'border-trackops-amber/50' : 'border-trackops-border'
    }`}>
      <div className="flex justify-between items-center mb-4">
        <h3 className="text-xs tracking-widest uppercase flex items-center text-trackops-green">
          <Database className="w-4 h-4 mr-2" /> Cost Optimizer
        </h3>
        <div className={`px-2 py-1 rounded text-[10px] font-bold ${
          !monitoringEnabled ? 'bg-trackops-amber/20 text-trackops-amber' :
          isPaused ? 'bg-trackops-amber/10 text-trackops-amber animate-pulse' :
          'bg-trackops-green/20 text-trackops-green'
        }`}>
          {isMonitoringActive ? 'OPTIMIZED SYNC ON' : isPaused ? 'MONITORING PAUSED' : 'MONITORING OFF'}
        </div>
      </div>

      <div className="space-y-3 text-sm">
        {!isMonitoringActive ? (
          <>
            <div className="flex justify-between items-center border-b border-trackops-border/30 pb-2">
              <span className="text-gray-500 flex items-center"><Ban className="w-3 h-3 mr-2" /> Polling Calls</span>
              <span className="text-white">0</span>
            </div>
            <div className="flex justify-between items-center border-b border-trackops-border/30 pb-2">
              <span className="text-gray-500 flex items-center"><Ban className="w-3 h-3 mr-2" /> Active Listeners</span>
              <span className="text-white">0</span>
            </div>
            <div className="flex justify-between items-center border-b border-trackops-border/30 pb-2">
              <span className="text-gray-500 flex items-center"><Ban className="w-3 h-3 mr-2" /> External API Polling</span>
              <span className="text-white">0</span>
            </div>
            <div className="flex justify-between items-center border-b border-trackops-border/30 pb-2">
              <span className="text-gray-500 flex items-center"><Ban className="w-3 h-3 mr-2" /> Gemini Background Calls</span>
              <span className="text-white">0</span>
            </div>
            
            <div className="mt-4 pt-2 text-trackops-amber flex items-start gap-2">
              <ShieldAlert className="w-4 h-4 mt-0.5 shrink-0" />
              <div className="text-[10px] leading-relaxed">
                Background traffic has been halted to save Firebase and API costs.
                {avoidedCalls > 0 && <span className="block mt-1 font-bold text-trackops-green">Estimated Calls Avoided: ~{avoidedCalls}</span>}
              </div>
            </div>
          </>
        ) : (
          <>
            <div className="flex justify-between items-center border-b border-trackops-border/30 pb-2">
              <span className="text-gray-500">Active Listeners</span>
              <span className="text-trackops-green">{activeListeners}</span>
            </div>
            <div className="flex justify-between items-center border-b border-trackops-border/30 pb-2">
              <span className="text-gray-500">Polling Jobs</span>
              <span className="text-trackops-green">{pollingJobs}</span>
            </div>
            <div className="flex justify-between items-center border-b border-trackops-border/30 pb-2">
              <span className="text-gray-500">Last Vercel Sync</span>
              <span className="text-white flex items-center"><Zap className="w-3 h-3 mr-1 text-trackops-amber" /> 5s</span>
            </div>
            <div className="flex justify-between items-center border-b border-trackops-border/30 pb-2">
              <span className="text-gray-500">Last Firebase Sync</span>
              <span className="text-white flex items-center"><Clock className="w-3 h-3 mr-1 text-blue-400" /> Live</span>
            </div>
            <div className="flex justify-between items-center pb-2">
              <span className="text-gray-500">Last Google Cloud Sync</span>
              <span className="text-white flex items-center"><Clock className="w-3 h-3 mr-1 text-blue-400" /> 15m</span>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
