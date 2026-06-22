import React, { useState, useEffect } from 'react';
import { Activity, Database, Server, Key, Radio, CreditCard, RefreshCw, Users } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, query, orderBy, limit } from 'firebase/firestore';

export default function CostSimulator() {
  const [contractors, setContractors] = useState(100);
  const [realData, setRealData] = useState({ contractors: 0, telemetryEvents: 0, loading: true });

  useEffect(() => {
    // Fetch real contractor count
    const unsubContractors = onSnapshot(collection(db, 'contractors'), (snap) => {
      const count = snap.size;
      setRealData(prev => ({ ...prev, contractors: count }));
      setContractors(prev => prev === 100 ? Math.max(count, 10) : prev); // Pre-fill slider on first load
    }, (err) => console.error('CostSimulator contractors error:', err));

    // Fetch real telemetry count (last 500 events for usage estimation)
    const qTel = query(collection(db, 'telemetry_events'), orderBy('timestamp', 'desc'), limit(500));
    const unsubTelemetry = onSnapshot(qTel, (snap) => {
      setRealData(prev => ({ ...prev, telemetryEvents: snap.size, loading: false }));
    }, (err) => {
      console.error('CostSimulator telemetry error:', err);
      setRealData(prev => ({ ...prev, loading: false }));
    });

    return () => { unsubContractors(); unsubTelemetry(); };
  }, []);

  // Real usage-based multiplier (ratio of slider to actual contractors)
  const scaleFactor = realData.contractors > 0 ? contractors / realData.contractors : 1;
  
  // Base reads/writes from real telemetry, scaled by contractor count
  const baseReadsPerContractor = realData.telemetryEvents > 0 && realData.contractors > 0
    ? Math.round((realData.telemetryEvents * 30) / realData.contractors) // Extrapolate monthly from recent snapshot
    : 50000;
  const baseWritesPerContractor = Math.round(baseReadsPerContractor * 0.2); // Writes are ~20% of reads
  
  const reads = contractors * baseReadsPerContractor;
  const writes = contractors * baseWritesPerContractor;
  const storage = contractors * 0.5; // GB
  const bandwidth = contractors * 2; // GB
  
  const estimatedCost = (
    ((reads / 100000) * 3) + // ₹3 per 100k reads
    ((writes / 100000) * 9) + // ₹9 per 100k writes
    (storage * 12) + // ₹12 per GB storage
    (bandwidth * 8) // ₹8 per GB bandwidth
  );

  return (
    <div className="space-y-6 max-w-5xl">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
          <Activity className="w-6 h-6 mr-3 text-cyan-400" />
          Firebase Cost Simulator
        </h1>
        <div className="flex items-center gap-3">
          {realData.loading ? (
            <span className="text-xs text-gray-500 flex items-center"><RefreshCw className="w-3 h-3 mr-1 animate-spin" /> Loading live data...</span>
          ) : (
            <span className="text-xs text-gray-500 flex items-center font-mono">
              <Users className="w-3 h-3 mr-1 text-cyan-400" />
              {realData.contractors} live contractors · {realData.telemetryEvents} recent events
            </span>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Sliders Area */}
        <div className="lg:col-span-2 bg-[#121214] border border-[#27272a] rounded-xl p-6">
          <h2 className="text-lg font-medium text-gray-200 mb-6">Scale Predictor</h2>
          
          <div className="space-y-8">
            <div>
              <div className="flex justify-between mb-2">
                <label className="text-sm text-gray-400 font-mono">Total Active Contractors</label>
                <span className="text-cyan-400 font-bold font-mono">
                  {contractors.toLocaleString()}
                  {realData.contractors > 0 && contractors === realData.contractors && (
                    <span className="text-[10px] text-gray-500 ml-2">(CURRENT)</span>
                  )}
                </span>
              </div>
              <input 
                type="range" 
                min="10" 
                max="10000" 
                step="10"
                value={contractors} 
                onChange={(e) => setContractors(parseInt(e.target.value))}
                className="w-full h-1 bg-[#27272a] rounded-lg appearance-none cursor-pointer accent-cyan-500"
              />
              <div className="flex justify-between text-xs text-gray-600 mt-2 font-mono">
                <span>10</span>
                {realData.contractors > 0 && (
                  <span 
                    className="text-cyan-400/50 cursor-pointer hover:text-cyan-400" 
                    onClick={() => setContractors(realData.contractors)}
                  >
                    ↑ Current: {realData.contractors}
                  </span>
                )}
                <span>10,000</span>
              </div>
            </div>

            {/* Simulated Metrics based on Contractors */}
            <div className="grid grid-cols-2 gap-4 pt-4 border-t border-[#27272a]">
              <MetricItem icon={Database} label="Firestore Reads/mo" value={reads.toLocaleString()} />
              <MetricItem icon={Server} label="Firestore Writes/mo" value={writes.toLocaleString()} />
              <MetricItem icon={Activity} label="Storage (GB)" value={`${storage.toFixed(1)} GB`} />
              <MetricItem icon={Radio} label="Bandwidth (GB)" value={`${bandwidth.toFixed(1)} GB`} />
            </div>
          </div>
        </div>

        {/* Cost Summary Area */}
        <div className="bg-[#121214] border border-cyan-500/30 rounded-xl p-6 relative overflow-hidden flex flex-col justify-center">
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-48 h-48 bg-cyan-500/10 blur-[50px] rounded-full pointer-events-none" />
          
          <div className="relative z-10 text-center space-y-4">
            <CreditCard className="w-8 h-8 text-cyan-400 mx-auto mb-2 opacity-80" />
            <div className="text-sm text-gray-400 uppercase tracking-widest font-mono">Estimated Monthly Cost</div>
            <div className="text-5xl font-bold text-white tracking-tight">
              ₹{estimatedCost.toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </div>
            
            <div className="pt-6 mt-6 border-t border-[#27272a]/50 text-left space-y-2">
              <CostLine label="Reads Cost" val={`₹${((reads / 100000) * 3).toFixed(0)}`} />
              <CostLine label="Writes Cost" val={`₹${((writes / 100000) * 9).toFixed(0)}`} />
              <CostLine label="Storage Cost" val={`₹${(storage * 12).toFixed(0)}`} />
              <CostLine label="Bandwidth Cost" val={`₹${(bandwidth * 8).toFixed(0)}`} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function MetricItem({ icon: Icon, label, value }) {
  return (
    <div className="bg-[#09090b] border border-[#27272a] p-3 rounded-lg flex items-center">
      <Icon className="w-5 h-5 text-purple-400 mr-3" />
      <div>
        <div className="text-xs text-gray-500">{label}</div>
        <div className="text-sm font-medium text-gray-200 font-mono">{value}</div>
      </div>
    </div>
  );
}

function CostLine({ label, val }) {
  return (
    <div className="flex justify-between items-center text-xs font-mono">
      <span className="text-gray-500">{label}</span>
      <span className="text-gray-300">{val}</span>
    </div>
  );
}
