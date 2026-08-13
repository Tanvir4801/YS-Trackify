import React from 'react';
import { X, AlertTriangle, Activity, Brain, Compass, Clock, ShieldAlert } from 'lucide-react';
import { useInfraLensIncident } from '../../../lib/services/trackopsQueryService';

const StatusPill = ({ status }) => {
  const map = {
    'CRITICAL': 'bg-trackops-red/20 text-trackops-red border-trackops-red/50',
    'HIGH': 'bg-orange-500/20 text-orange-400 border-orange-500/50',
    'MEDIUM': 'bg-yellow-500/20 text-yellow-400 border-yellow-500/50',
    'LOW': 'bg-blue-500/20 text-blue-400 border-blue-500/50'
  };
  return (
    <span className={`px-2 py-0.5 rounded text-xs font-bold font-mono border uppercase ${map[status?.toUpperCase()] || 'bg-gray-700 text-gray-300'}`}>
      {status || 'UNKNOWN'}
    </span>
  );
};

export default function InfrastructureIncidentModal({ incidentId, onClose }) {
  const { data, isLoading, isError } = useInfraLensIncident(incidentId);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="bg-trackops-navy border border-trackops-border w-full max-w-2xl rounded-xl shadow-2xl flex flex-col overflow-hidden max-h-[90vh]">
        
        {/* Header */}
        <div className="flex justify-between items-center p-4 border-b border-trackops-border bg-trackops-card/50">
          <div className="flex items-center">
            <ShieldAlert className="w-5 h-5 text-trackops-red mr-3" />
            <h2 className="text-white font-mono font-bold">Incident Details</h2>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="p-6 overflow-y-auto font-mono text-sm space-y-6">
          {isLoading ? (
            <div className="flex justify-center items-center py-12">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
            </div>
          ) : isError || !data?.data ? (
            <div className="text-center py-8">
              <AlertTriangle className="w-10 h-10 text-trackops-amber mx-auto mb-4" />
              <p className="text-gray-300">Unable to load incident details.</p>
              <p className="text-gray-500 text-xs mt-2">The incident may have been resolved or the service is offline.</p>
            </div>
          ) : (
            <>
              {/* Top Info */}
              <div className="flex items-start justify-between bg-trackops-card p-4 rounded-lg border border-trackops-border">
                <div>
                  <h3 className="text-lg font-bold text-white mb-2">{data.data.title}</h3>
                  <div className="flex space-x-4 text-xs text-gray-400">
                    <span>Source: <span className="text-gray-200">{data.data.source}</span></span>
                    <span>Service: <span className="text-gray-200">{data.data.affectedService}</span></span>
                  </div>
                </div>
                <StatusPill status={data.data.severity} />
              </div>

              {/* Timeline */}
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-trackops-steel/20 p-4 rounded-lg border border-trackops-steel/50">
                  <div className="text-xs text-gray-500 uppercase flex items-center mb-1">
                    <Clock className="w-3 h-3 mr-1" /> First Detected
                  </div>
                  <div className="text-gray-200">{data.data.firstDetected ? new Date(data.data.firstDetected).toLocaleString() : 'N/A'}</div>
                </div>
                <div className="bg-trackops-steel/20 p-4 rounded-lg border border-trackops-steel/50">
                  <div className="text-xs text-gray-500 uppercase flex items-center mb-1">
                    <Activity className="w-3 h-3 mr-1" /> Occurrences
                  </div>
                  <div className="text-gray-200">{data.data.occurrences || 1} times</div>
                </div>
              </div>

              {/* AI Summary */}
              {data.data.aiSummary && (
                <div className="bg-blue-900/20 p-4 rounded-lg border border-blue-500/30">
                  <div className="text-xs text-blue-400 font-bold uppercase flex items-center mb-2">
                    <Brain className="w-3 h-3 mr-1" /> InfraLens AI Summary
                  </div>
                  <p className="text-gray-300 leading-relaxed">{data.data.aiSummary}</p>
                </div>
              )}

              {/* Probable Cause & Recommended Action */}
              <div className="space-y-4">
                <div>
                  <h4 className="text-gray-400 text-xs uppercase mb-1">Probable Cause</h4>
                  <p className="text-gray-200 bg-trackops-steel/10 p-3 rounded border border-trackops-steel/30">
                    {data.data.probableCause || 'Unknown'}
                  </p>
                </div>
                <div>
                  <h4 className="text-gray-400 text-xs uppercase mb-1 flex items-center">
                    <Compass className="w-3 h-3 mr-1" /> Recommended Action
                  </h4>
                  <p className="text-gray-200 bg-trackops-steel/10 p-3 rounded border border-trackops-steel/30">
                    {data.data.recommendedAction || 'Investigate source system.'}
                  </p>
                </div>
              </div>
            </>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-trackops-border bg-trackops-card/50 flex justify-end space-x-3">
          <button 
            onClick={onClose}
            className="px-4 py-2 bg-trackops-steel hover:bg-gray-600 text-white rounded text-sm font-mono transition-colors"
          >
            CLOSE
          </button>
          <a 
            href={import.meta.env.VITE_INFRALENS_DASHBOARD_URL || '#'} 
            target="_blank" 
            rel="noreferrer"
            className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded text-sm font-mono font-bold transition-colors flex items-center"
          >
            OPEN INFRALENS <AlertTriangle className="w-4 h-4 ml-2 opacity-50" />
          </a>
        </div>
      </div>
    </div>
  );
}
