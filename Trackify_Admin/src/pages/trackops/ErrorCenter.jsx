import React, { useState, useEffect, useMemo } from 'react';
import { AlertTriangle, CheckCircle, Clock, Search, Filter, Bug, ShieldAlert, Activity } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, query, orderBy, limit, onSnapshot } from 'firebase/firestore';
import ErrorDetailsModal from './components/ErrorDetailsModal';
import { useTrackOpsMonitoring } from '../../context/TrackOpsMonitoringContext';

export default function ErrorCenter() {
  const [errors, setErrors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedErrorId, setSelectedErrorId] = useState(null);
  const activeError = useMemo(() => errors.find(e => e.id === selectedErrorId) || null, [errors, selectedErrorId]);

  // Filters
  const [searchTerm, setSearchTerm] = useState('');
  const [severityFilter, setSeverityFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [moduleFilter, setModuleFilter] = useState('ALL');
  const { isMonitoringActive } = useTrackOpsMonitoring();

  useEffect(() => {
    if (!isMonitoringActive) {
      setLoading(false);
      return () => {};
    }

    // Listen to recent 100 errors for the dashboard
    const q = query(collection(db, 'error_logs'), orderBy('createdAt', 'desc'), limit(100));
    let unsubscribe = () => {};
    try {
      unsubscribe = onSnapshot(q, (snapshot) => {
        try {
          const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
          setErrors(data);
          setLoading(false);
        } catch(e) { console.error('ErrorCenter snapshot processing error:', e); }
      });
    } catch(e) { console.error('ErrorCenter listener initialization error:', e); }
    return () => { try { unsubscribe(); } catch(e) {} };
  }, [isMonitoringActive]);

  // Analytics Calculation
  const { criticalCount, unresolvedCount, fixedToday } = useMemo(() => {
    let crit = 0;
    let unres = 0;
    let fixed = 0;
    const today = new Date().setHours(0,0,0,0);

    errors.forEach(err => {
      if (err.severity === 'CRITICAL' && err.status !== 'RESOLVED' && err.status !== 'IGNORED') crit++;
      if (err.status === 'NEW' || err.status === 'INVESTIGATING' || err.status === 'IN_PROGRESS') unres++;
      
      if (err.status === 'FIXED' || err.status === 'RESOLVED') {
        const updatedTime = err.updatedAt?.toDate ? err.updatedAt.toDate().getTime() : 0;
        if (updatedTime >= today) fixed++;
      }
    });

    return { criticalCount: crit, unresolvedCount: unres, fixedToday: fixed };
  }, [errors]);

  // Filtering Logic
  const filteredErrors = useMemo(() => {
    return errors.filter(err => {
      const matchSearch = (err.id.toLowerCase().includes(searchTerm.toLowerCase())) || 
                          (err.message && err.message.toLowerCase().includes(searchTerm.toLowerCase())) ||
                          (err.userId && err.userId.toLowerCase().includes(searchTerm.toLowerCase()));
      const matchSev = severityFilter === 'ALL' || err.severity === severityFilter;
      const matchStatus = statusFilter === 'ALL' || err.status === statusFilter;
      
      let matchModule = true;
      if (moduleFilter !== 'ALL') {
        matchModule = err.type === moduleFilter || err.module === moduleFilter;
      }

      return matchSearch && matchSev && matchStatus && matchModule;
    });
  }, [errors, searchTerm, severityFilter, statusFilter, moduleFilter]);

  const getSeverityColor = (sev) => {
    switch (sev) {
      case 'CRITICAL': return 'bg-red-500/20 text-red-400';
      case 'HIGH': return 'bg-orange-500/20 text-orange-400';
      case 'MEDIUM': return 'bg-yellow-500/20 text-yellow-400';
      case 'LOW': return 'bg-blue-500/20 text-blue-400';
      default: return 'bg-gray-500/20 text-gray-400';
    }
  };

  const getStatusIcon = (status) => {
    switch(status) {
      case 'NEW': return <AlertTriangle className="w-3 h-3 mr-1 text-trackops-red" />;
      case 'INVESTIGATING':
      case 'IN_PROGRESS': return <Clock className="w-3 h-3 mr-1 text-trackops-amber" />;
      case 'FIXED':
      case 'RESOLVED': return <CheckCircle className="w-3 h-3 mr-1 text-trackops-green" />;
      default: return null;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between border-b border-trackops-border pb-4 gap-4">
        <h1 className="text-2xl font-bold tracking-widest text-white uppercase flex items-center">
          <Bug className="w-6 h-6 mr-3 text-trackops-red" />
          Error Center
        </h1>
        <div className="flex space-x-4 font-mono text-sm">
          <div className="flex items-center text-gray-400">
            {isMonitoringActive ? (
              <><span className="w-2 h-2 rounded-full bg-trackops-green animate-pulse mr-2" />Live Sync Active</>
            ) : (
              <><span className="w-2 h-2 rounded-full bg-gray-600 mr-2" />Live Sync Paused</>
            )}
          </div>
        </div>
      </div>

      {/* Analytics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 font-mono">
        <div className="bg-trackops-card border border-trackops-border p-4 rounded-lg flex items-center justify-between">
          <div>
            <div className="text-gray-500 text-[10px] uppercase tracking-wider mb-1">Critical Issues</div>
            <div className="text-2xl font-bold text-trackops-red">{loading ? '-' : criticalCount}</div>
          </div>
          <ShieldAlert className="w-8 h-8 text-trackops-red opacity-20" />
        </div>
        <div className="bg-trackops-card border border-trackops-border p-4 rounded-lg flex items-center justify-between">
          <div>
            <div className="text-gray-500 text-[10px] uppercase tracking-wider mb-1">Total Unresolved</div>
            <div className="text-2xl font-bold text-trackops-amber">{loading ? '-' : unresolvedCount}</div>
          </div>
          <Activity className="w-8 h-8 text-trackops-amber opacity-20" />
        </div>
        <div className="bg-trackops-card border border-trackops-border p-4 rounded-lg flex items-center justify-between">
          <div>
            <div className="text-gray-500 text-[10px] uppercase tracking-wider mb-1">Fixed Today</div>
            <div className="text-2xl font-bold text-trackops-green">{loading ? '-' : fixedToday}</div>
          </div>
          <CheckCircle className="w-8 h-8 text-trackops-green opacity-20" />
        </div>
      </div>

      {/* Filters Bar */}
      <div className="bg-trackops-card border border-trackops-border p-4 rounded-lg flex flex-col lg:flex-row gap-4 font-mono text-sm">
        <div className="relative flex-1">
          <Search className="w-4 h-4 absolute left-3 top-2.5 text-gray-500" />
          <input 
            type="text" 
            placeholder="Search by ID, User, or Message..." 
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full bg-trackops-navy border border-trackops-border rounded pl-9 pr-4 py-2 text-white focus:outline-none focus:border-trackops-amber transition-colors"
          />
        </div>
        
        <div className="flex gap-4">
          <select 
            value={severityFilter}
            onChange={(e) => setSeverityFilter(e.target.value)}
            className="bg-trackops-navy border border-trackops-border rounded px-4 py-2 text-white focus:outline-none focus:border-trackops-amber appearance-none cursor-pointer"
          >
            <option value="ALL">All Severities</option>
            <option value="CRITICAL">Critical</option>
            <option value="HIGH">High</option>
            <option value="MEDIUM">Medium</option>
            <option value="LOW">Low</option>
          </select>
          
          <select 
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="bg-trackops-navy border border-trackops-border rounded px-4 py-2 text-white focus:outline-none focus:border-trackops-amber appearance-none cursor-pointer"
          >
            <option value="ALL">All Statuses</option>
            <option value="NEW">New</option>
            <option value="INVESTIGATING">Investigating</option>
            <option value="IN_PROGRESS">In Progress</option>
            <option value="FIXED">Fixed</option>
            <option value="RESOLVED">Resolved</option>
            <option value="IGNORED">Ignored</option>
          </select>
        </div>
      </div>

      {/* Data Table */}
      <div className="bg-trackops-card border border-trackops-border rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm font-mono text-gray-300">
            <thead className="bg-trackops-navy/50 text-[10px] uppercase tracking-wider text-gray-500 border-b border-trackops-border">
              <tr>
                <th className="px-6 py-4">Error ID</th>
                <th className="px-6 py-4">Severity</th>
                <th className="px-6 py-4">Context</th>
                <th className="px-6 py-4">Message Summary</th>
                <th className="px-6 py-4">Status</th>
                <th className="px-6 py-4">Time</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-trackops-border">
              {loading ? (
                <tr><td colSpan="6" className="px-6 py-8 text-center text-gray-500 animate-pulse">Fetching global error logs...</td></tr>
              ) : filteredErrors.length === 0 ? (
                <tr><td colSpan="6" className="px-6 py-8 text-center text-gray-500">No matching errors found.</td></tr>
              ) : (
                filteredErrors.map((err) => (
                  <tr 
                    key={err.id} 
                    onClick={() => setSelectedErrorId(err.id)}
                    className="hover:bg-trackops-navy/50 transition-colors cursor-pointer group"
                  >
                    <td className="px-6 py-4 font-bold text-gray-400 group-hover:text-white transition-colors text-xs truncate max-w-[120px]">
                      {err.id}
                    </td>
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 rounded text-[10px] uppercase font-bold tracking-wider ${getSeverityColor(err.severity)}`}>
                        {err.severity || 'UNKNOWN'}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="font-bold text-white text-xs">{err.type || 'Unknown Type'}</div>
                      <div className="text-[10px] text-gray-500 mt-1">{err.module || 'Unknown Module'}</div>
                    </td>
                    <td className="px-6 py-4 text-gray-300 text-xs truncate max-w-xs font-sans">
                      {err.message}
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center text-[10px] font-bold tracking-wider uppercase">
                        {getStatusIcon(err.status)}
                        <span className={
                          err.status === 'NEW' ? 'text-trackops-red' : 
                          (err.status === 'FIXED' || err.status === 'RESOLVED') ? 'text-trackops-green' : 
                          err.status === 'IGNORED' ? 'text-gray-500' : 'text-trackops-amber'
                        }>
                          {err.status}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-[10px] text-gray-500 whitespace-nowrap">
                      {err.createdAt?.toDate ? err.createdAt.toDate().toLocaleString() : 'N/A'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      <ErrorDetailsModal 
        isOpen={!!activeError}
        onClose={() => setSelectedErrorId(null)}
        error={activeError}
      />
    </div>
  );
}
