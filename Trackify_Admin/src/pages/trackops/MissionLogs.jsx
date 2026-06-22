import React, { useState, useEffect } from 'react';
import { GitBranch, Search, Filter, Download, ServerCrash, Shield, Briefcase, Zap, User, AlertTriangle, Pin } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, query, orderBy, limit } from 'firebase/firestore';

const MODULES = ['All', 'UserLogs', 'BusinessLogs', 'SecurityLogs', 'ProductLogs', 'SystemLogs'];
const SEVERITIES = ['All', 'Info', 'Success', 'Warning', 'Error', 'Critical'];

export default function MissionLogs() {
  const [logs, setLogs] = useState([]);
  const [search, setSearch] = useState('');
  const [moduleFilter, setModuleFilter] = useState('All');
  const [severityFilter, setSeverityFilter] = useState('All');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Listen to latest 200 operational events
    const q = query(collection(db, 'mission_logs'), orderBy('timestamp', 'desc'), limit(200));
    
    let unsub = () => {};
    try {
      unsub = onSnapshot(q, (snapshot) => {
        try {
          const fetchedLogs = [];

          snapshot.forEach(doc => {
            const data = doc.data();
            fetchedLogs.push({
              id: doc.id,
              time: data.timestamp ? new Date(data.timestamp.toDate()).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit', second:'2-digit'}) : 'Pending...',
              rawDate: data.timestamp ? data.timestamp.toDate() : new Date(),
              severity: data.severity || 'Info',
              module: data.module || 'SystemLogs',
              action: data.action || 'Unknown Event',
              companyId: data.companyId || 'N/A',
              userId: data.userId || 'System',
              role: data.role || 'Unknown',
              details: data.details || ''
            });
          });

          setLogs(fetchedLogs);
          setLoading(false);
        } catch (e) {
          console.warn('Error processing snapshot in MissionLogs:', e);
          setLoading(false);
        }
      }, (err) => {
        console.warn('onSnapshot error in MissionLogs:', err);
        setLoading(false);
      });
    } catch (e) {
      console.warn('Failed to start onSnapshot in MissionLogs:', e);
      setLoading(false);
    }

    return () => { try { unsub(); } catch(e) {} };
  }, []);

  const handleExport = () => {
    if (filteredLogs.length === 0) return;
    const headers = ['Time', 'Severity', 'Category', 'Action', 'Company', 'User', 'Role', 'Details'];
    const csvContent = [
      headers.join(','),
      ...filteredLogs.map(log => 
        [log.time, log.severity, log.module, `"${log.action}"`, log.companyId, log.userId, log.role, `"${log.details?.replace(/"/g, '""')}"`].join(',')
      )
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.setAttribute("download", `trackops_operational_logs_${new Date().getTime()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const filteredLogs = logs.filter(log => {
    const matchSearch = search === '' || 
      (log.action?.toLowerCase().includes(search.toLowerCase()) || 
       log.companyId?.toLowerCase().includes(search.toLowerCase()) || 
       log.userId?.toLowerCase().includes(search.toLowerCase()) ||
       log.role?.toLowerCase().includes(search.toLowerCase()) ||
       log.details?.toLowerCase().includes(search.toLowerCase()));
    
    const matchModule = moduleFilter === 'All' || log.module === moduleFilter;
    const matchSeverity = severityFilter === 'All' || log.severity === severityFilter;

    return matchSearch && matchModule && matchSeverity;
  });

  // Extract pinned criticals (from the last 24 hours)
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const pinnedCriticals = logs.filter(log => log.severity === 'Critical' && log.rawDate > oneDayAgo).slice(0, 5);

  const getSeverityStyles = (severity) => {
    switch(severity) {
      case 'Critical': return 'bg-trackops-red/20 text-trackops-red border border-trackops-red/50 animate-pulse';
      case 'Error': return 'bg-red-900/40 text-red-400 border border-red-900/50';
      case 'Warning': return 'bg-trackops-amber/20 text-trackops-amber border border-trackops-amber/50';
      case 'Success': return 'bg-trackops-green/20 text-trackops-green border border-trackops-green/50';
      case 'Info': return 'bg-trackops-steel text-gray-300 border border-trackops-border';
      default: return 'bg-trackops-steel text-gray-300 border border-trackops-border';
    }
  };

  const getTimelineDotStyles = (severity) => {
    if (severity === 'Critical' || severity === 'Error') return 'bg-trackops-red shadow-[0_0_8px_rgba(255,51,51,0.6)]';
    if (severity === 'Warning') return 'bg-trackops-amber';
    if (severity === 'Success') return 'bg-trackops-green';
    return 'bg-gray-500 group-hover:bg-trackops-green transition-colors';
  };

  const getModuleIcon = (module) => {
    switch (module) {
      case 'SecurityLogs': return <Shield className="w-4 h-4 text-purple-400" />;
      case 'BusinessLogs': return <Briefcase className="w-4 h-4 text-trackops-amber" />;
      case 'ProductLogs': return <Zap className="w-4 h-4 text-trackops-green" />;
      case 'UserLogs': return <User className="w-4 h-4 text-blue-400" />;
      case 'SystemLogs': return <ServerCrash className="w-4 h-4 text-gray-400" />;
      default: return <GitBranch className="w-4 h-4 text-gray-500" />;
    }
  };

  return (
    <div className="space-y-6 pb-10">
      <div className="flex flex-col md:flex-row md:items-center justify-between border-b border-trackops-border pb-4 gap-4">
        <h1 className="text-2xl font-bold tracking-widest text-white uppercase flex items-center">
          <GitBranch className="w-6 h-6 mr-3 text-trackops-green" />
          Mission Logs
        </h1>
        
        <div className="flex flex-wrap items-center gap-2">
          <div className="relative mr-2">
            <Search className="w-4 h-4 absolute left-3 top-2.5 text-gray-500" />
            <input 
              type="text" 
              placeholder="Search logs, IDs, roles..." 
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="bg-trackops-card border border-trackops-border rounded pl-9 pr-4 py-2 text-sm focus:outline-none focus:border-trackops-green text-white w-56 transition-colors"
            />
          </div>
          
          <select 
            value={moduleFilter}
            onChange={(e) => setModuleFilter(e.target.value)}
            className="bg-trackops-navy text-xs text-white border border-trackops-border rounded px-3 py-2 outline-none focus:border-trackops-green"
          >
            {MODULES.map(m => <option key={m} value={m}>{m === 'All' ? 'All Categories' : m.replace('Logs', ' Logs')}</option>)}
          </select>

          <select 
            value={severityFilter}
            onChange={(e) => setSeverityFilter(e.target.value)}
            className="bg-trackops-navy text-xs text-white border border-trackops-border rounded px-3 py-2 outline-none focus:border-trackops-green"
          >
            {SEVERITIES.map(s => <option key={s} value={s}>{s} Severity</option>)}
          </select>
          
          <button onClick={handleExport} className="px-3 py-2 text-xs rounded bg-trackops-navy text-trackops-green border border-trackops-border hover:bg-trackops-steel flex items-center transition-colors">
            <Download className="w-3 h-3 mr-1" /> Export CSV
          </button>
        </div>
      </div>

      {pinnedCriticals.length > 0 && (
        <div className="bg-trackops-red/5 border border-trackops-red/30 rounded-md p-4">
          <h2 className="text-trackops-red text-xs tracking-widest uppercase mb-3 flex items-center font-bold">
            <AlertTriangle className="w-4 h-4 mr-2 animate-pulse" />
            Pinned Critical Events (Last 24H)
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            {pinnedCriticals.map(log => (
              <div key={`pin-${log.id}`} className="bg-trackops-bg border border-trackops-red/20 p-3 rounded shadow-[0_0_10px_rgba(255,51,51,0.05)] relative overflow-hidden group hover:border-trackops-red/50 transition-colors">
                <Pin className="w-3 h-3 text-trackops-red/50 absolute top-2 right-2 rotate-45" />
                <div className="text-[10px] text-gray-500 mb-1">{log.time}</div>
                <div className="font-bold text-white text-sm truncate mb-1" title={log.action}>{log.action}</div>
                <div className="text-[10px] text-gray-400">Company: <span className="text-trackops-amber">{log.companyId}</span></div>
                <div className="text-[10px] text-gray-400">Role: <span className="text-trackops-green">{log.role}</span></div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="bg-trackops-card border border-trackops-border rounded-md overflow-hidden relative min-h-[500px]">
        <div className="absolute left-[8.5rem] top-0 bottom-0 w-px bg-trackops-border/50 hidden md:block"></div>
        <div className="p-4 space-y-4">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-20 text-trackops-green font-mono">
              <ServerCrash className="w-8 h-8 mb-4 animate-bounce" />
              Connecting to live operations stream...
            </div>
          ) : filteredLogs.length === 0 ? (
            <div className="text-center py-20 text-gray-500 font-mono">No operational logs match your filters.</div>
          ) : (
            filteredLogs.map((log) => (
              <div key={log.id} className="flex flex-col md:flex-row text-sm font-mono group hover:bg-trackops-navy/30 p-2 rounded transition-colors relative z-10">
                <div className="w-32 text-gray-500 text-[11px] flex items-center shrink-0">
                  <span className={`w-2 h-2 rounded-full mr-3 transition-colors ${getTimelineDotStyles(log.severity)}`}></span>
                  {log.time}
                </div>
                <div className="flex-1 grid grid-cols-1 md:grid-cols-12 gap-4 mt-2 md:mt-0 items-center">
                  <div className="md:col-span-2">
                    <span className={`px-2 py-0.5 rounded text-[9px] tracking-wider uppercase ${getSeverityStyles(log.severity)}`}>
                      {log.severity}
                    </span>
                  </div>
                  <div className="md:col-span-2 flex items-center text-gray-300 text-[11px]">
                    <div className="mr-2 opacity-70 bg-trackops-bg p-1 rounded-sm border border-trackops-border/50">
                      {getModuleIcon(log.module)}
                    </div>
                    <span className="truncate" title={log.module}>{log.module.replace('Logs', '')}</span>
                  </div>
                  <div className="md:col-span-3 text-white font-bold text-xs truncate" title={log.action}>{log.action}</div>
                  <div className="md:col-span-2 text-xs truncate">
                    <div className="text-trackops-amber" title={log.companyId}>{log.companyId}</div>
                    <div className="text-[9px] text-gray-500 uppercase mt-0.5 tracking-widest">{log.role}</div>
                  </div>
                  <div className="md:col-span-3 text-gray-400 text-xs truncate" title={log.details}>{log.details}</div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
