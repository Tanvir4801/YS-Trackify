import React, { useState } from 'react';
import { X, MessageSquare, AlertCircle, Clock, CheckCircle, Save, Send } from 'lucide-react';
import { doc, updateDoc, arrayUnion, serverTimestamp } from 'firebase/firestore';
import { db } from '../../../lib/firebase';


export default function SupportTicketModal({ ticket, onClose }) {
  const [reply, setReply] = useState('');
  const [status, setStatus] = useState(ticket?.status || 'Open');
  const [priority, setPriority] = useState(ticket?.priority || 'Low');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  if (!ticket) return null;

  const handleUpdate = async () => {
    setLoading(true);
    setError(null);
    try {
      const updates = {
        updatedAt: serverTimestamp()
      };
      
      const historyItems = [];

      if (reply.trim() !== '') {
        historyItems.push({
          type: 'reply',
          text: reply.trim(),
          createdBy: 'TrackOps Admin',
          timestamp: new Date().toISOString()
        });
      }

      if (status !== ticket.status) {
        updates.status = status;
        if (status === 'Resolved' || status === 'Closed') {
          updates.resolvedAt = serverTimestamp();
        }
        historyItems.push({
          type: 'status_change',
          old: ticket.status,
          newStatus: status,
          timestamp: new Date().toISOString()
        });
      }

      if (priority !== ticket.priority) {
        updates.priority = priority;
        historyItems.push({
          type: 'priority_change',
          old: ticket.priority,
          newPriority: priority,
          timestamp: new Date().toISOString()
        });
      }

      if (historyItems.length > 0) {
        updates.history = arrayUnion(...historyItems);
      }

      const ticketRef = doc(db, 'support_tickets', ticket.id);
      await updateDoc(ticketRef, updates);
      
      setReply('');
      onClose();
    } catch (err) {
      console.error(err);
      setError('Failed to update ticket.');
    }
    setLoading(false);
  };

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4 font-mono">
      <div className="bg-[#0A0F1C] border border-trackops-border rounded-lg shadow-2xl w-full max-w-3xl flex flex-col max-h-[90vh]">
        <div className="flex items-center justify-between p-4 border-b border-trackops-border">
          <h2 className="text-xl font-bold text-white flex items-center tracking-wider">
            Ticket Details: {ticket.id.substring(0, 8).toUpperCase()}
          </h2>
          <button onClick={onClose} className="text-gray-500 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>
        
        <div className="p-6 overflow-y-auto space-y-6">
        {error && (
          <div className="p-3 bg-red-900/50 border border-red-500/50 text-red-200 rounded text-sm">
            {error}
          </div>
        )}

        <div className="grid grid-cols-2 gap-4 text-sm font-mono">
          <div className="bg-trackops-navy p-3 rounded border border-trackops-border">
            <div className="text-gray-500 text-xs mb-1">User</div>
            <div className="text-white font-bold">{ticket.userName}</div>
            <div className="text-gray-400 text-xs">{ticket.userRole}</div>
          </div>
          <div className="bg-trackops-navy p-3 rounded border border-trackops-border">
            <div className="text-gray-500 text-xs mb-1">Company</div>
            <div className="text-white font-bold">{ticket.companyName || 'Unknown'}</div>
            <div className="text-trackops-amber text-xs truncate" title={ticket.companyId}>{ticket.companyId}</div>
          </div>
        </div>

        <div className="bg-trackops-navy p-4 rounded border border-trackops-border space-y-4">
          <div>
            <div className="text-gray-500 text-xs mb-1 uppercase tracking-wider font-mono">Issue Description</div>
            <div className="text-white text-sm bg-trackops-card p-3 rounded border border-trackops-border whitespace-pre-wrap">
              {ticket.issue}
            </div>
          </div>
          
          {ticket.deviceInfo && (
            <div>
              <div className="text-gray-500 text-xs mb-1 uppercase tracking-wider font-mono">Device Context</div>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-2 text-xs">
                <div className="bg-trackops-card p-2 rounded">
                  <span className="text-gray-500">Screen:</span> <span className="text-white">{ticket.deviceInfo.screen || 'N/A'}</span>
                </div>
                <div className="bg-trackops-card p-2 rounded">
                  <span className="text-gray-500">Platform:</span> <span className="text-white">{ticket.deviceInfo.platform || 'N/A'}</span>
                </div>
                <div className="bg-trackops-card p-2 rounded">
                  <span className="text-gray-500">App:</span> <span className="text-white">{ticket.deviceInfo.appVersion || 'N/A'}</span>
                </div>
                <div className="bg-trackops-card p-2 rounded">
                  <span className="text-gray-500">Device:</span> <span className="text-white truncate" title={ticket.deviceInfo.device}>{ticket.deviceInfo.device || 'N/A'}</span>
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-gray-400 text-xs mb-2 uppercase tracking-wider font-mono">Status</label>
            <select
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              className="w-full bg-trackops-card text-white border border-trackops-border rounded p-2 outline-none focus:border-trackops-green text-sm"
            >
              <option value="Open">Open</option>
              <option value="In Progress">In Progress</option>
              <option value="Assigned">Assigned</option>
              <option value="Resolved">Resolved</option>
              <option value="Closed">Closed</option>
            </select>
          </div>
          <div>
            <label className="block text-gray-400 text-xs mb-2 uppercase tracking-wider font-mono">Priority</label>
            <select
              value={priority}
              onChange={(e) => setPriority(e.target.value)}
              className="w-full bg-trackops-card text-white border border-trackops-border rounded p-2 outline-none focus:border-trackops-green text-sm"
            >
              <option value="Critical">Critical</option>
              <option value="High">High</option>
              <option value="Medium">Medium</option>
              <option value="Low">Low</option>
            </select>
          </div>
        </div>

        <div>
          <label className="block text-gray-400 text-xs mb-2 uppercase tracking-wider font-mono">Add Reply / Note</label>
          <textarea
            value={reply}
            onChange={(e) => setReply(e.target.value)}
            placeholder="Type your response or internal note here..."
            className="w-full h-24 bg-trackops-card text-white border border-trackops-border rounded p-3 text-sm focus:outline-none focus:border-trackops-green resize-none"
          />
        </div>
        
        {ticket.history && ticket.history.length > 0 && (
          <div>
            <label className="block text-gray-400 text-xs mb-2 uppercase tracking-wider font-mono">History</label>
            <div className="space-y-2 max-h-40 overflow-y-auto pr-2">
              {[...ticket.history].reverse().map((h, i) => (
                <div key={i} className="bg-trackops-navy p-2 rounded border border-trackops-border text-xs font-mono">
                  <div className="flex justify-between text-gray-500 mb-1">
                    <span>{h.createdBy || 'System'}</span>
                    <span>{new Date(h.timestamp).toLocaleString()}</span>
                  </div>
                  {h.type === 'reply' && <div className="text-white"><MessageSquare className="w-3 h-3 inline mr-1"/>{h.text}</div>}
                  {h.type === 'status_change' && <div className="text-trackops-amber">Status changed: {h.old} &rarr; {h.newStatus}</div>}
                  {h.type === 'priority_change' && <div className="text-trackops-red">Priority changed: {h.old} &rarr; {h.newPriority}</div>}
                  {h.type === 'note' && <div className="text-gray-300">Note: {h.text}</div>}
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex justify-end gap-3 pt-4 border-t border-trackops-border">
          <button 
            onClick={onClose}
            className="px-4 py-2 bg-trackops-navy text-gray-300 hover:text-white rounded border border-trackops-border transition-colors font-mono text-sm"
          >
            Cancel
          </button>
          <button 
            onClick={handleUpdate}
            disabled={loading || (reply.trim() === '' && status === ticket.status && priority === ticket.priority)}
            className="px-4 py-2 bg-trackops-green/20 text-trackops-green hover:bg-trackops-green/30 rounded border border-trackops-green/50 transition-colors font-mono text-sm flex items-center disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Saving...' : <><Save className="w-4 h-4 mr-2"/> Update Ticket</>}
          </button>
        </div>
        </div>
      </div>
    </div>
  );
}
