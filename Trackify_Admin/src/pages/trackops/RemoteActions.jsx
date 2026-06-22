import React, { useState, useEffect } from 'react';
import { Crosshair, Power, Shield, Settings, Bell, RefreshCw, AlertTriangle, Send, Activity } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, query, orderBy, limit, onSnapshot, addDoc, Timestamp } from 'firebase/firestore';

import DisableCompanyModal from './components/DisableCompanyModal';
import ForceLogoutModal from './components/ForceLogoutModal';
import SubscriptionManagerModal from './components/SubscriptionManagerModal';
import MaintenanceModeModal from './components/MaintenanceModeModal';

export default function RemoteActions() {
  const [activeTab, setActiveTab] = useState('actions'); // actions, logs, version, notifications

  const [activeModal, setActiveModal] = useState(null); // 'disable', 'logout', 'premium', 'trial', 'maintenance'

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between border-b border-trackops-border pb-4">
        <h1 className="text-2xl font-bold tracking-widest text-white uppercase flex items-center">
          <Crosshair className="w-6 h-6 mr-3 text-trackops-amber animate-pulse" />
          Remote Operations
        </h1>
        <div className="flex space-x-2 font-mono text-sm">
          <button onClick={() => setActiveTab('actions')} className={`px-4 py-2 rounded border transition-colors ${activeTab === 'actions' ? 'bg-trackops-steel text-white border-trackops-amber' : 'bg-trackops-navy text-gray-400 border-trackops-border hover:text-white'}`}>Action Center</button>
          <button onClick={() => setActiveTab('logs')} className={`px-4 py-2 rounded border transition-colors ${activeTab === 'logs' ? 'bg-trackops-steel text-white border-trackops-amber' : 'bg-trackops-navy text-gray-400 border-trackops-border hover:text-white'}`}>Action Logs</button>
          <button onClick={() => setActiveTab('version')} className={`px-4 py-2 rounded border transition-colors ${activeTab === 'version' ? 'bg-trackops-steel text-white border-trackops-amber' : 'bg-trackops-navy text-gray-400 border-trackops-border hover:text-white'}`}>Versioning</button>
          <button onClick={() => setActiveTab('notifications')} className={`px-4 py-2 rounded border transition-colors ${activeTab === 'notifications' ? 'bg-trackops-steel text-white border-trackops-amber' : 'bg-trackops-navy text-gray-400 border-trackops-border hover:text-white'}`}>Broadcasts</button>
        </div>
      </div>

      <div className="mt-4">
        {activeTab === 'actions' && <ActionCenter onOpenModal={setActiveModal} />}
        {activeTab === 'logs' && <ActionLogs />}
        {activeTab === 'version' && <VersionManagement />}
        {activeTab === 'notifications' && <NotificationCenter />}
      </div>

      <DisableCompanyModal 
        isOpen={activeModal === 'disable'} 
        onClose={() => setActiveModal(null)} 
      />
      <ForceLogoutModal 
        isOpen={activeModal === 'logout'} 
        onClose={() => setActiveModal(null)} 
      />
      <SubscriptionManagerModal 
        isOpen={activeModal === 'premium' || activeModal === 'trial'} 
        initialMode={activeModal}
        onClose={() => setActiveModal(null)} 
      />
      <MaintenanceModeModal 
        isOpen={activeModal === 'maintenance'} 
        onClose={() => setActiveModal(null)} 
      />
    </div>
  );
}

function ActionCenter({ onOpenModal }) {
  const actions = [
    { id: 'disable', title: 'Disable Company', desc: 'Instantly block all users of a specific company.', icon: Power, color: 'text-trackops-red' },
    { id: 'logout', title: 'Force Logout', desc: 'Invalidate active session for a specific user.', icon: Shield, color: 'text-trackops-amber' },
    { id: 'premium', title: 'Grant Premium', desc: 'Manually activate a professional subscription.', icon: Settings, color: 'text-trackops-green' },
    { id: 'trial', title: 'Extend Trial', desc: 'Add 7, 14, or 30 days to an active trial period.', icon: RefreshCw, color: 'text-white' },
    { id: 'maintenance', title: 'Maintenance Mode', desc: 'Block all non-TrackOps logins globally or per-company.', icon: AlertTriangle, color: 'text-trackops-red' },
  ];

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 font-mono">
      {actions.map((action) => (
        <div key={action.title} className="bg-trackops-card border border-trackops-border p-6 rounded hover:border-trackops-amber/50 transition-colors flex flex-col justify-between group">
          <div>
            <div className={`p-3 rounded inline-block bg-trackops-navy mb-4 border border-trackops-border group-hover:border-trackops-amber/30 transition-colors ${action.color}`}>
              <action.icon className="w-6 h-6" />
            </div>
            <h3 className="text-white font-bold tracking-wider uppercase mb-2">{action.title}</h3>
            <p className="text-gray-400 text-xs mb-6 h-10">{action.desc}</p>
          </div>
          <button 
            onClick={() => onOpenModal(action.id)}
            className={`w-full py-2 rounded font-bold text-xs uppercase tracking-widest transition-colors ${
              action.id === 'maintenance' || action.id === 'disable'
              ? 'bg-trackops-red/10 border border-trackops-red text-trackops-red hover:bg-trackops-red hover:text-white'
              : 'bg-trackops-steel text-white hover:bg-trackops-border hover:text-trackops-amber border border-transparent hover:border-trackops-border'
            }`}
          >
            Execute
          </button>
        </div>
      ))}
    </div>
  );
}

function ActionLogs() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'operation_logs'), orderBy('timestamp', 'desc'), limit(50));
    let unsubscribe = () => {};
    try {
      unsubscribe = onSnapshot(q, (snapshot) => {
        try {
          const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
          setLogs(data);
          setLoading(false);
        } catch(e) { console.error('ActionLogs snapshot processing error:', e); }
      });
    } catch (e) { console.error('ActionLogs listener initialization error:', e); }
    return () => { try { unsubscribe(); } catch(e) {} };
  }, []);

  if (loading) {
    return <div className="text-gray-400 font-mono animate-pulse">Loading action logs...</div>;
  }

  return (
    <div className="font-mono">
      <div className="bg-trackops-card border border-trackops-border rounded overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm text-gray-300">
            <thead className="bg-trackops-navy text-xs uppercase text-gray-500 border-b border-trackops-border">
              <tr>
                <th className="px-4 py-3">Time</th>
                <th className="px-4 py-3">Action</th>
                <th className="px-4 py-3">Target</th>
                <th className="px-4 py-3">Performed By</th>
                <th className="px-4 py-3">Reason</th>
              </tr>
            </thead>
            <tbody>
              {logs.length === 0 ? (
                <tr>
                  <td colSpan="5" className="px-4 py-8 text-center text-gray-500">No recent remote actions.</td>
                </tr>
              ) : logs.map((log) => (
                <tr key={log.id} className="border-b border-trackops-border hover:bg-trackops-navy/50 transition-colors">
                  <td className="px-4 py-3 whitespace-nowrap text-trackops-amber">
                    {log.timestamp?.toDate ? log.timestamp.toDate().toLocaleTimeString() : 'Just now'}
                  </td>
                  <td className="px-4 py-3 font-bold text-white">{log.action}</td>
                  <td className="px-4 py-3 text-gray-400">{log.targetName || log.targetId}</td>
                  <td className="px-4 py-3">{log.performedBy}</td>
                  <td className="px-4 py-3 text-gray-500 text-xs">{log.reason || '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function VersionManagement() {
  return (
    <div className="space-y-6 font-mono">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-trackops-card border border-trackops-green p-6 rounded relative overflow-hidden">
          <div className="absolute top-0 right-0 p-4">
            <div className="w-3 h-3 rounded-full bg-trackops-green animate-pulse" style={{ boxShadow: '0 0 10px #00FF66' }} />
          </div>
          <div className="text-gray-500 text-xs uppercase tracking-wider mb-2">Current Production Version</div>
          <div className="text-4xl font-bold text-white mb-4">2.0.1</div>
          <div className="text-trackops-green text-xs">Rolled out: 2 days ago</div>
        </div>
        
        <div className="bg-trackops-card border border-trackops-border p-6 rounded">
          <div className="text-gray-500 text-xs uppercase tracking-wider mb-2">Users Pending Update</div>
          <div className="text-4xl font-bold text-trackops-amber mb-4">17</div>
          <div className="text-gray-400 text-xs">Mostly on v2.0.0 and v1.9.8</div>
        </div>

        <div className="bg-trackops-card border border-trackops-border p-6 rounded flex flex-col justify-center items-center text-center">
          <div className="text-gray-500 text-xs uppercase tracking-wider mb-4">Global Force Update</div>
          <div className="text-white text-sm mb-4">Status: <span className="text-trackops-red font-bold">DISABLED</span></div>
          <button className="px-6 py-2 bg-trackops-red/20 border border-trackops-red text-trackops-red rounded text-xs tracking-widest uppercase hover:bg-trackops-red hover:text-white transition-colors">
            Enable Force Update
          </button>
        </div>
      </div>
    </div>
  );
}

function NotificationCenter() {
  const [audience, setAudience] = useState('All Users');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [loading, setLoading] = useState(false);
  const [broadcasts, setBroadcasts] = useState([]);

  useEffect(() => {
    const q = query(collection(db, 'trackops_broadcasts'), orderBy('timestamp', 'desc'), limit(10));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      setBroadcasts(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    }, (error) => {
      console.error("Error fetching broadcasts:", error);
    });
    return () => unsubscribe();
  }, []);

  const handleDispatch = async () => {
    if (!title.trim() || !body.trim()) {
      alert("Please enter a title and message body.");
      return;
    }
    setLoading(true);
    try {
      await addDoc(collection(db, 'trackops_broadcasts'), {
        audience,
        title,
        body,
        timestamp: Timestamp.now(),
        active: true,
        sentBy: 'TrackOps Admin'
      });
      setTitle('');
      setBody('');
    } catch (e) {
      console.error(e);
      alert("Failed to dispatch broadcast: " + e.message);
    }
    setLoading(false);
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 font-mono">
      <div className="bg-trackops-card border border-trackops-border p-6 rounded">
        <h3 className="text-trackops-green text-sm tracking-widest uppercase mb-6 flex items-center">
          <Bell className="w-5 h-5 mr-2" /> New Broadcast
        </h3>
        
        <div className="space-y-4">
          <div>
            <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Target Audience</label>
            <select 
              value={audience} 
              onChange={(e) => setAudience(e.target.value)}
              className="w-full bg-trackops-navy border border-trackops-border rounded p-2 text-white focus:outline-none focus:border-trackops-green">
              <option>All Users</option>
              <option>Contractors Only</option>
              <option>Supervisors Only</option>
              <option>Labours Only</option>
            </select>
          </div>
          <div>
            <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Notification Title</label>
            <input 
              type="text" 
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full bg-trackops-navy border border-trackops-border rounded p-2 text-white focus:outline-none focus:border-trackops-green" 
              placeholder="e.g. Server Maintenance Notice" 
            />
          </div>
          <div>
            <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Message Body</label>
            <textarea 
              rows="4" 
              value={body}
              onChange={(e) => setBody(e.target.value)}
              className="w-full bg-trackops-navy border border-trackops-border rounded p-2 text-white focus:outline-none focus:border-trackops-green" 
              placeholder="Enter message here...">
            </textarea>
          </div>
          <button 
            onClick={handleDispatch}
            disabled={loading}
            className={`w-full py-3 font-bold uppercase tracking-widest rounded transition-colors flex items-center justify-center ${loading ? 'bg-trackops-steel text-gray-400 cursor-not-allowed' : 'bg-trackops-green text-black hover:bg-[#00e65c]'}`}>
            {loading ? 'Dispatching...' : <><Send className="w-4 h-4 mr-2" /> Dispatch Notification</>}
          </button>
        </div>
      </div>

      <div className="bg-trackops-card border border-trackops-border p-6 rounded">
        <h3 className="text-gray-400 text-sm tracking-widest uppercase mb-6">Recent Broadcasts</h3>
        <div className="space-y-4">
          {broadcasts.length === 0 ? (
            <div className="text-gray-500 text-sm py-4">No broadcasts dispatched yet.</div>
          ) : (
            broadcasts.map((bcast) => (
              <div key={bcast.id} className="border-l-2 border-trackops-amber pl-4 py-1">
                <div className="text-white font-bold text-sm">{bcast.title}</div>
                <div className="text-gray-400 text-xs mt-1">To: {bcast.audience} • Sent: {bcast.timestamp?.toDate ? bcast.timestamp.toDate().toLocaleTimeString() : 'Just now'}</div>
                <div className="text-gray-500 text-xs mt-2">{bcast.body}</div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
