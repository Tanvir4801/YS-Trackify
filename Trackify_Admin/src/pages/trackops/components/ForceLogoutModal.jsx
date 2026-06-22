import React, { useState, useEffect } from 'react';
import { Shield, Search, Smartphone, Monitor, Clock, LogOut, X } from 'lucide-react';
import { db } from '../../../lib/firebase';
import { collection, query, where, getDocs, doc, setDoc, serverTimestamp, updateDoc } from 'firebase/firestore';
import SafetyModal from './SafetyModal';

export default function ForceLogoutModal({ isOpen, onClose }) {
  const [users, setUsers] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [loading, setLoading] = useState(false);
  const [actionType, setActionType] = useState('current'); // current, all, delayed, security
  const [isSafetyOpen, setIsSafetyOpen] = useState(false);
  
  // Dummy data for device since session_logs might not be fully populated
  const dummySession = {
    deviceName: 'iPhone 14 Pro',
    platform: 'iOS',
    lastActive: 'Just now',
    currentSession: 'Active',
    loginIp: '192.168.1.104',
    appVersion: '2.0.1'
  };

  useEffect(() => {
    if (isOpen) {
      fetchUsers();
    }
  }, [isOpen]);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, 'users'));
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      setUsers(data);
    } catch (error) {
      console.error('Error fetching users:', error);
    }
    setLoading(false);
  };

  const executeAction = async (reason) => {
    if (!selectedUser) return;

    try {
      // Invalidate token / update session validity in user document
      const userRef = doc(db, 'users', selectedUser.id);
      await updateDoc(userRef, {
        sessionValidSince: serverTimestamp(),
        forceLogoutReason: actionType === 'security' ? 'Security breach detected' : reason
      });

      // Log the operation
      await setDoc(doc(collection(db, 'operation_logs')), {
        action: 'Force Logout',
        targetId: selectedUser.id,
        targetName: selectedUser.name || selectedUser.email,
        logoutType: actionType,
        reason: reason,
        performedBy: 'TrackOps_Admin',
        timestamp: serverTimestamp()
      });

      setIsSafetyOpen(false);
      onClose();
    } catch (error) {
      console.error('Error executing force logout:', error);
      alert('Failed to execute action. Check console.');
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <div className="bg-trackops-card border border-trackops-border rounded-lg w-full max-w-2xl overflow-hidden font-mono text-left animate-in fade-in zoom-in duration-200">
        
        <div className="bg-trackops-navy border-b border-trackops-border p-4 flex items-center justify-between">
          <h2 className="text-white font-bold uppercase flex items-center tracking-widest text-sm">
            <Shield className="w-5 h-5 mr-2 text-trackops-amber" />
            Force Logout User
          </h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6">
          <div className="mb-6">
            <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Search User (Contractor / Supervisor / Labour)</label>
            <div className="relative">
              <Search className="w-4 h-4 absolute left-3 top-3 text-gray-500" />
              <select 
                className="w-full bg-trackops-bg border border-trackops-border rounded pl-10 pr-4 py-2 text-white text-sm focus:outline-none focus:border-trackops-amber appearance-none"
                onChange={(e) => {
                  const found = users.find(u => u.id === e.target.value);
                  setSelectedUser(found || null);
                }}
                value={selectedUser?.id || ''}
              >
                <option value="">-- Choose a user --</option>
                {users.map(u => (
                  <option key={u.id} value={u.id}>{u.name || u.email || u.id} ({u.role || 'user'})</option>
                ))}
              </select>
            </div>
          </div>

          {selectedUser && (
            <div className="mb-6 grid grid-cols-2 md:grid-cols-3 gap-4">
              <div className="bg-trackops-navy border border-trackops-border rounded p-4">
                <div className="text-gray-500 text-xs mb-1 flex items-center"><Smartphone className="w-3 h-3 mr-1" /> Device</div>
                <div className="text-white font-bold text-sm">{dummySession.deviceName}</div>
              </div>
              <div className="bg-trackops-navy border border-trackops-border rounded p-4">
                <div className="text-gray-500 text-xs mb-1 flex items-center"><Monitor className="w-3 h-3 mr-1" /> Platform</div>
                <div className="text-white font-bold text-sm">{dummySession.platform} (v{dummySession.appVersion})</div>
              </div>
              <div className="bg-trackops-navy border border-trackops-border rounded p-4">
                <div className="text-gray-500 text-xs mb-1 flex items-center"><Clock className="w-3 h-3 mr-1" /> Last Active</div>
                <div className="text-trackops-green font-bold text-sm">{dummySession.lastActive}</div>
              </div>
            </div>
          )}

          {selectedUser && (
            <div className="space-y-4 mb-6">
              <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Logout Target</label>
              <div className="grid grid-cols-2 gap-2">
                <button onClick={() => setActionType('current')} className={`py-3 px-4 text-xs uppercase tracking-wider rounded border text-left ${actionType === 'current' ? 'bg-trackops-amber/20 border-trackops-amber text-trackops-amber' : 'bg-trackops-navy border-trackops-border text-gray-400'}`}>Current Device Only</button>
                <button onClick={() => setActionType('all')} className={`py-3 px-4 text-xs uppercase tracking-wider rounded border text-left ${actionType === 'all' ? 'bg-trackops-amber/20 border-trackops-amber text-trackops-amber' : 'bg-trackops-navy border-trackops-border text-gray-400'}`}>All Connected Devices</button>
                <button onClick={() => setActionType('delayed')} className={`py-3 px-4 text-xs uppercase tracking-wider rounded border text-left ${actionType === 'delayed' ? 'bg-trackops-amber/20 border-trackops-amber text-trackops-amber' : 'bg-trackops-navy border-trackops-border text-gray-400'}`}>Logout after 5 Minutes</button>
                <button onClick={() => setActionType('security')} className={`py-3 px-4 text-xs uppercase tracking-wider rounded border text-left ${actionType === 'security' ? 'bg-trackops-red/20 border-trackops-red text-trackops-red' : 'bg-trackops-navy border-trackops-border text-gray-400'}`}>Security Breach (Immediate)</button>
              </div>
            </div>
          )}

          <div className="flex justify-end pt-4 border-t border-trackops-border">
            <button onClick={onClose} className="px-6 py-2 text-gray-400 hover:text-white mr-4 text-sm font-bold uppercase tracking-widest">Cancel</button>
            <button 
              onClick={() => setIsSafetyOpen(true)}
              disabled={!selectedUser}
              className={`px-6 py-2 rounded text-sm font-bold uppercase tracking-widest transition-colors flex items-center ${
                selectedUser 
                ? 'bg-trackops-amber text-black shadow-[0_0_10px_rgba(255,176,0,0.3)] hover:bg-[#ffc233]' 
                : 'bg-trackops-navy text-gray-500 cursor-not-allowed'
              }`}
            >
              <LogOut className="w-4 h-4 mr-2" />
              Invalidate Session
            </button>
          </div>
        </div>
      </div>

      <SafetyModal 
        isOpen={isSafetyOpen}
        onClose={() => setIsSafetyOpen(false)}
        onConfirm={executeAction}
        title="Invalidate User Session"
        description={`You are about to force logout ${selectedUser?.name || 'this user'} on ${actionType === 'all' ? 'ALL devices' : 'their current device'}.`}
        actionName="LOGOUT USER"
      />
    </div>
  );
}
