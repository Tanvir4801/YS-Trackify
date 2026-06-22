import React, { useState, useEffect } from 'react';
import { LifeBuoy, MessageSquare, AlertCircle, CheckCircle, Clock, ServerCrash } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, query, orderBy, limit } from 'firebase/firestore';
import SupportTicketModal from './components/SupportTicketModal';

export default function SupportCenter() {
  const [tickets, setTickets] = useState([]);
  const [filter, setFilter] = useState('All');
  const [loading, setLoading] = useState(true);
  const [selectedTicket, setSelectedTicket] = useState(null);
  
  const [stats, setStats] = useState({
    total: 0,
    open: 0,
    resolved: 0,
    critical: 0,
    avgResponse: '15m'
  });

  useEffect(() => {
    let unsub = () => {};
    try {
      // Fetch latest 100 tickets
      const q = query(collection(db, 'support_tickets'), orderBy('createdAt', 'desc'), limit(100));
      unsub = onSnapshot(q, (snapshot) => {
        try {
          const fetchedTickets = [];
          let open = 0;
          let resolved = 0;
          let critical = 0;
          let totalResponseMs = 0;
          let respondedCount = 0;

          snapshot.forEach(doc => {
            const data = doc.data();
            const ticket = { id: doc.id, ...data };
            fetchedTickets.push(ticket);

            if (ticket.status === 'Open' || ticket.status === 'In Progress') open++;
            if (ticket.status === 'Resolved' || ticket.status === 'Closed') resolved++;
            if (ticket.priority === 'Critical') critical++;

            // Calculate real response time from createdAt → resolvedAt or first reply
            try {
              const createdDate = ticket.createdAt?.toDate ? ticket.createdAt.toDate() : null;
              if (createdDate) {
                // First check if there's a resolvedAt timestamp
                const resolvedDate = ticket.resolvedAt?.toDate ? ticket.resolvedAt.toDate() : null;
                // Or check first reply in history
                const firstReply = (ticket.history || []).find(h => h.type === 'reply');
                const firstReplyDate = firstReply?.timestamp ? new Date(firstReply.timestamp) : null;
                
                const responseDate = firstReplyDate || resolvedDate;
                if (responseDate && responseDate > createdDate) {
                  totalResponseMs += (responseDate - createdDate);
                  respondedCount++;
                }
              }
            } catch(e) {}
          });

          // Calculate real average response time
          let avgResponseText = 'N/A';
          if (respondedCount > 0) {
            const avgMins = Math.round(totalResponseMs / respondedCount / 60000);
            if (avgMins < 60) {
              avgResponseText = `${avgMins}m`;
            } else if (avgMins < 1440) {
              const hrs = Math.floor(avgMins / 60);
              const mins = avgMins % 60;
              avgResponseText = mins > 0 ? `${hrs}h ${mins}m` : `${hrs}h`;
            } else {
              const days = Math.floor(avgMins / 1440);
              const hrs = Math.floor((avgMins % 1440) / 60);
              avgResponseText = hrs > 0 ? `${days}d ${hrs}h` : `${days}d`;
            }
          }

          setTickets(fetchedTickets);
          setStats({
            total: fetchedTickets.length,
            open,
            resolved,
            critical,
            avgResponse: avgResponseText
          });
          setLoading(false);
        } catch (e) {
          console.error('Error processing support tickets:', e);
        }
      });
    } catch (e) {
      console.warn('Failed to start support tickets listener:', e);
    }
    
    return () => { try { unsub(); } catch(e) {} };
  }, []);

  const filteredTickets = filter === 'All' ? tickets : tickets.filter(t => t.type === filter);

  // Time formatter
  const formatTime = (ts) => {
    if (!ts) return 'Unknown';
    try {
      const date = typeof ts === 'string' ? new Date(ts) : ts.toDate();
      const diffMins = (new Date() - date) / 60000;
      if (diffMins < 60) return `${Math.floor(diffMins)} mins ago`;
      if (diffMins < 1440) return `${Math.floor(diffMins / 60)} hours ago`;
      return `${Math.floor(diffMins / 1440)} days ago`;
    } catch(e) {
      return 'Unknown';
    }
  };

  return (
    <div className="space-y-6 pb-10">
      <div className="flex flex-col md:flex-row md:items-center justify-between border-b border-trackops-border pb-4 gap-4">
        <h1 className="text-2xl font-bold tracking-widest text-white uppercase flex items-center">
          <LifeBuoy className="w-6 h-6 mr-3 text-trackops-green animate-pulse" />
          Support Center
        </h1>
        <div className="flex flex-wrap gap-2 font-mono text-xs">
          {['All', 'Attendance Issue', 'Payment Issue', 'Feature Request', 'Bug Report', 'App Crash'].map(f => (
            <button 
              key={f}
              onClick={() => setFilter(f)}
              className={`px-3 py-1.5 rounded border transition-colors ${
                filter === f ? 'bg-trackops-steel text-white border-trackops-green' : 'bg-trackops-navy text-gray-400 border-trackops-border hover:text-white'
              }`}
            >
              {f}
            </button>
          ))}
        </div>
      </div>

      {/* Analytics Cards */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="bg-trackops-card border border-trackops-border rounded-md p-4 flex flex-col justify-between">
          <div className="text-gray-500 text-xs uppercase tracking-wider font-mono">Total Tickets</div>
          <div className="text-3xl font-bold text-white font-mono mt-2">{stats.total}</div>
        </div>
        <div className="bg-trackops-card border border-trackops-border rounded-md p-4 flex flex-col justify-between">
          <div className="text-gray-500 text-xs uppercase tracking-wider font-mono">Open</div>
          <div className="text-3xl font-bold text-trackops-amber font-mono mt-2">{stats.open}</div>
        </div>
        <div className="bg-trackops-card border border-trackops-border rounded-md p-4 flex flex-col justify-between">
          <div className="text-gray-500 text-xs uppercase tracking-wider font-mono">Resolved</div>
          <div className="text-3xl font-bold text-trackops-green font-mono mt-2">{stats.resolved}</div>
        </div>
        <div className="bg-trackops-card border border-trackops-border rounded-md p-4 flex flex-col justify-between">
          <div className="text-gray-500 text-xs uppercase tracking-wider font-mono">Critical</div>
          <div className="text-3xl font-bold text-trackops-red font-mono mt-2 animate-pulse">{stats.critical}</div>
        </div>
        <div className="bg-trackops-card border border-trackops-border rounded-md p-4 flex flex-col justify-between">
          <div className="text-gray-500 text-xs uppercase tracking-wider font-mono">Avg Response</div>
          <div className="text-3xl font-bold text-gray-300 font-mono mt-2">{stats.avgResponse}</div>
        </div>
      </div>

      <div className="bg-trackops-card border border-trackops-border rounded-md overflow-hidden relative min-h-[400px]">
        {loading ? (
          <div className="absolute inset-0 flex flex-col items-center justify-center text-trackops-green font-mono">
            <ServerCrash className="w-8 h-8 mb-4 animate-bounce" />
            Loading live tickets...
          </div>
        ) : (
          <table className="w-full text-left text-sm font-mono text-gray-300 relative z-10">
            <thead className="bg-trackops-navy/50 text-[10px] uppercase tracking-wider text-gray-500 border-b border-trackops-border">
              <tr>
                <th className="px-6 py-4">Ticket</th>
                <th className="px-6 py-4">User & Company</th>
                <th className="px-6 py-4">Issue Description</th>
                <th className="px-6 py-4">Priority</th>
                <th className="px-6 py-4">Status</th>
                <th className="px-6 py-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-trackops-border">
              {filteredTickets.map((ticket) => (
                <tr key={ticket.id} className="hover:bg-trackops-navy/30 transition-colors">
                  <td className="px-6 py-4">
                    <div className="font-bold text-white mb-1" title={ticket.id}>{ticket.id.substring(0, 8).toUpperCase()}</div>
                    <span className={`px-2 py-0.5 rounded text-[9px] uppercase ${
                      ticket.type === 'App Crash' || ticket.type === 'Bug Report' ? 'bg-trackops-red/20 text-trackops-red border border-trackops-red/30' :
                      ticket.type === 'Feature Request' ? 'bg-trackops-green/20 text-trackops-green border border-trackops-green/30' :
                      'bg-trackops-steel text-gray-300 border border-trackops-border'
                    }`}>
                      {ticket.type || 'Unknown'}
                    </span>
                  </td>
                  <td className="px-6 py-4 max-w-[200px]">
                    <div className="text-white font-bold truncate" title={ticket.userName}>{ticket.userName || 'Unknown'}</div>
                    <div className="text-[10px] text-gray-500 mb-1">{ticket.userRole || 'User'}</div>
                    <div className="text-xs text-trackops-amber truncate" title={ticket.companyName}>{ticket.companyName || ticket.companyId || 'Unknown'}</div>
                  </td>
                  <td className="px-6 py-4 max-w-xs">
                    <div className="flex items-start">
                      <MessageSquare className="w-4 h-4 mr-2 text-gray-500 mt-0.5 shrink-0" />
                      <span className="text-gray-300 line-clamp-2" title={ticket.issue}>{ticket.issue || 'No description'}</span>
                    </div>
                    <div className="text-[10px] text-gray-500 mt-2">{formatTime(ticket.createdAt)}</div>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`flex items-center text-xs ${
                      ticket.priority === 'Critical' ? 'text-trackops-red font-bold' :
                      ticket.priority === 'High' ? 'text-trackops-amber' :
                      'text-gray-400'
                    }`}>
                      {ticket.priority === 'Critical' && <AlertCircle className="w-3 h-3 mr-1" />}
                      {ticket.priority || 'Low'}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center text-xs">
                      {ticket.status === 'Open' && <AlertCircle className="w-4 h-4 mr-1 text-trackops-red" />}
                      {ticket.status === 'In Progress' && <Clock className="w-4 h-4 mr-1 text-trackops-amber animate-pulse" />}
                      {(ticket.status === 'Resolved' || ticket.status === 'Closed') && <CheckCircle className="w-4 h-4 mr-1 text-trackops-green" />}
                      <span className={
                        ticket.status === 'Open' ? 'text-trackops-red' : 
                        ticket.status === 'In Progress' ? 'text-trackops-amber' : 
                        'text-trackops-green'
                      }>
                        {ticket.status || 'Open'}
                      </span>
                    </div>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <button 
                      onClick={() => setSelectedTicket(ticket)}
                      className="px-3 py-1.5 bg-trackops-navy border border-trackops-border text-trackops-green text-xs rounded hover:bg-trackops-steel transition-colors font-mono"
                    >
                      View / Reply
                    </button>
                  </td>
                </tr>
              ))}
              {filteredTickets.length === 0 && (
                <tr>
                  <td colSpan="6" className="px-6 py-8 text-center text-gray-500">No support tickets found.</td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>

      {selectedTicket && (
        <SupportTicketModal 
          ticket={selectedTicket} 
          onClose={() => setSelectedTicket(null)} 
        />
      )}
    </div>
  );
}
