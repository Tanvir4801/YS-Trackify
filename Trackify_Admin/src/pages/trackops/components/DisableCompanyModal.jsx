import React, { useState, useEffect } from 'react';
import { Power, Search, Building2, Users, Clock, AlertTriangle, X } from 'lucide-react';
import { db } from '../../../lib/firebase';
import { collection, query, where, getDocs, doc, setDoc, updateDoc, serverTimestamp } from 'firebase/firestore';
import SafetyModal from './SafetyModal';

export default function DisableCompanyModal({ isOpen, onClose }) {
  const [contractors, setContractors] = useState([]);
  const [selectedContractor, setSelectedContractor] = useState(null);
  const [loading, setLoading] = useState(false);
  const [actionType, setActionType] = useState('temporary'); // temporary, date, permanent, restore
  const [untilDate, setUntilDate] = useState('');
  
  const [isSafetyOpen, setIsSafetyOpen] = useState(false);

  useEffect(() => {
    if (isOpen) {
      fetchContractors();
    }
  }, [isOpen]);

  const fetchContractors = async () => {
    setLoading(true);
    try {
      // In a real app we might paginate or search, but for this admin tool we fetch active contractors
      const q = query(collection(db, 'users'), where('role', '==', 'contractor'));
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      setContractors(data);
    } catch (error) {
      console.error('Error fetching contractors:', error);
    }
    setLoading(false);
  };

  const executeAction = async (reason) => {
    if (!selectedContractor) return;

    try {
      const companyStatusRef = doc(db, 'company_status', selectedContractor.id);
      const userRef = doc(db, 'users', selectedContractor.id);
      
      const statusData = {
        status: actionType === 'restore' ? 'active' : 'disabled',
        disabledReason: actionType === 'restore' ? null : reason,
        disabledAt: actionType === 'restore' ? null : serverTimestamp(),
        disabledType: actionType === 'restore' ? null : actionType,
        disabledUntil: actionType === 'date' ? untilDate : null,
        updatedAt: serverTimestamp(),
        updatedBy: 'TrackOps_Admin' // Should be current user ID in real app
      };

      await setDoc(companyStatusRef, statusData, { merge: true });
      await updateDoc(userRef, { status: statusData.status });

      // Log the operation
      await setDoc(doc(collection(db, 'operation_logs')), {
        action: actionType === 'restore' ? 'Company Restored' : 'Company Disabled',
        targetId: selectedContractor.id,
        targetName: selectedContractor.name || selectedContractor.email,
        reason: reason,
        performedBy: 'TrackOps_Admin',
        timestamp: serverTimestamp(),
        details: statusData
      });

      setIsSafetyOpen(false);
      onClose();
    } catch (error) {
      console.error('Error executing company disable action:', error);
      alert('Failed to execute action. Check console.');
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <div className="bg-trackops-card border border-trackops-border rounded-lg w-full max-w-2xl overflow-hidden font-mono text-left animate-in fade-in zoom-in duration-200">
        
        <div className="bg-trackops-navy border-b border-trackops-border p-4 flex items-center justify-between">
          <h2 className="text-white font-bold uppercase flex items-center tracking-widest text-sm">
            <Power className="w-5 h-5 mr-2 text-trackops-red" />
            Disable Company
          </h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6">
          <div className="mb-6">
            <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Select Contractor</label>
            <div className="relative">
              <Search className="w-4 h-4 absolute left-3 top-3 text-gray-500" />
              <select 
                className="w-full bg-trackops-bg border border-trackops-border rounded pl-10 pr-4 py-2 text-white text-sm focus:outline-none focus:border-trackops-amber appearance-none"
                onChange={(e) => {
                  const found = contractors.find(c => c.id === e.target.value);
                  setSelectedContractor(found || null);
                }}
                value={selectedContractor?.id || ''}
              >
                <option value="">-- Choose a company --</option>
                {contractors.map(c => (
                  <option key={c.id} value={c.id}>{c.name || c.email || c.id}</option>
                ))}
              </select>
            </div>
          </div>

          {selectedContractor && (
            <div className="mb-6 grid grid-cols-2 gap-4">
              <div className="bg-trackops-navy border border-trackops-border rounded p-4">
                <div className="text-gray-500 text-xs mb-1 flex items-center"><Building2 className="w-3 h-3 mr-1" /> Company Name</div>
                <div className="text-white font-bold">{selectedContractor.companyName || 'N/A'}</div>
              </div>
              <div className="bg-trackops-navy border border-trackops-border rounded p-4">
                <div className="text-gray-500 text-xs mb-1 flex items-center"><Users className="w-3 h-3 mr-1" /> Contractor Name</div>
                <div className="text-white font-bold">{selectedContractor.name || selectedContractor.email}</div>
              </div>
              <div className="bg-trackops-navy border border-trackops-border rounded p-4">
                <div className="text-gray-500 text-xs mb-1 flex items-center"><Clock className="w-3 h-3 mr-1" /> Status</div>
                <div className={`font-bold ${selectedContractor.status === 'disabled' ? 'text-trackops-red' : 'text-trackops-green'}`}>
                  {(selectedContractor.status || 'ACTIVE').toUpperCase()}
                </div>
              </div>
              <div className="bg-trackops-navy border border-trackops-border rounded p-4">
                <div className="text-gray-500 text-xs mb-1 flex items-center"><AlertTriangle className="w-3 h-3 mr-1" /> ID</div>
                <div className="text-gray-400 font-bold text-xs truncate">{selectedContractor.id}</div>
              </div>
            </div>
          )}

          {selectedContractor && (
            <div className="space-y-4 mb-6">
              <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Action Type</label>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                <button onClick={() => setActionType('temporary')} className={`py-2 text-xs uppercase tracking-wider rounded border ${actionType === 'temporary' ? 'bg-trackops-amber/20 border-trackops-amber text-trackops-amber' : 'bg-trackops-navy border-trackops-border text-gray-400'}`}>Temporary</button>
                <button onClick={() => setActionType('date')} className={`py-2 text-xs uppercase tracking-wider rounded border ${actionType === 'date' ? 'bg-trackops-amber/20 border-trackops-amber text-trackops-amber' : 'bg-trackops-navy border-trackops-border text-gray-400'}`}>Until Date</button>
                <button onClick={() => setActionType('permanent')} className={`py-2 text-xs uppercase tracking-wider rounded border ${actionType === 'permanent' ? 'bg-trackops-red/20 border-trackops-red text-trackops-red' : 'bg-trackops-navy border-trackops-border text-gray-400'}`}>Permanent</button>
                <button onClick={() => setActionType('restore')} className={`py-2 text-xs uppercase tracking-wider rounded border ${actionType === 'restore' ? 'bg-trackops-green/20 border-trackops-green text-trackops-green' : 'bg-trackops-navy border-trackops-border text-gray-400'}`}>Restore</button>
              </div>

              {actionType === 'date' && (
                <div className="mt-4">
                  <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Disable Until</label>
                  <input type="date" value={untilDate} onChange={(e) => setUntilDate(e.target.value)} className="w-full bg-trackops-navy border border-trackops-border rounded p-2 text-white focus:outline-none focus:border-trackops-amber" />
                </div>
              )}
            </div>
          )}

          <div className="flex justify-end pt-4 border-t border-trackops-border">
            <button onClick={onClose} className="px-6 py-2 text-gray-400 hover:text-white mr-4 text-sm font-bold uppercase tracking-widest">Cancel</button>
            <button 
              onClick={() => setIsSafetyOpen(true)}
              disabled={!selectedContractor}
              className={`px-6 py-2 rounded text-sm font-bold uppercase tracking-widest transition-colors ${
                selectedContractor 
                ? (actionType === 'restore' ? 'bg-trackops-green text-black hover:bg-[#00e65c]' : 'bg-trackops-red text-white shadow-[0_0_10px_rgba(255,51,102,0.3)] hover:bg-[#ff1a53]')
                : 'bg-trackops-navy text-gray-500 cursor-not-allowed'
              }`}
            >
              {actionType === 'restore' ? 'Restore Company' : 'Execute Disable'}
            </button>
          </div>
        </div>
      </div>

      <SafetyModal 
        isOpen={isSafetyOpen}
        onClose={() => setIsSafetyOpen(false)}
        onConfirm={executeAction}
        title={actionType === 'restore' ? 'Restore Company Access' : 'Disable Company Access'}
        description={`You are about to ${actionType}ly ${actionType === 'restore' ? 'restore' : 'disable'} access for ${selectedContractor?.name || 'this contractor'}. This will immediately log out all associated active sessions.`}
        actionName={actionType === 'restore' ? 'RESTORE' : 'DISABLE'}
      />
    </div>
  );
}
