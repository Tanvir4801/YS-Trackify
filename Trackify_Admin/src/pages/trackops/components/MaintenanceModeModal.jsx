import React, { useState, useEffect } from 'react';
import { AlertTriangle, Globe, Building2, Search, X } from 'lucide-react';
import { db } from '../../../lib/firebase';
import { collection, query, where, getDocs, doc, setDoc, serverTimestamp } from 'firebase/firestore';
import SafetyModal from './SafetyModal';

export default function MaintenanceModeModal({ isOpen, onClose }) {
  const [scope, setScope] = useState('global'); // global, company
  const [contractors, setContractors] = useState([]);
  const [selectedContractor, setSelectedContractor] = useState(null);
  const [loading, setLoading] = useState(false);
  
  const [toggles, setToggles] = useState({
    app: true,
    web: true,
    adminPanel: false, // TrackOps should generally stay up
    attendance: true,
    pdf: false,
    payroll: false
  });
  
  const [message, setMessage] = useState('Trackify is currently undergoing scheduled maintenance.');
  const [eta, setEta] = useState('15 minutes');
  
  const [isSafetyOpen, setIsSafetyOpen] = useState(false);

  useEffect(() => {
    if (isOpen && scope === 'company' && contractors.length === 0) {
      fetchContractors();
    }
  }, [isOpen, scope]);

  const fetchContractors = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, 'users'), where('role', '==', 'contractor'));
      const snapshot = await getDocs(q);
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      setContractors(data);
    } catch (error) {
      console.error('Error fetching contractors:', error);
    }
    setLoading(false);
  };

  const handleToggle = (key) => {
    setToggles(prev => ({ ...prev, [key]: !prev[key] }));
  };

  const executeAction = async (reason) => {
    if (scope === 'company' && !selectedContractor) return;

    try {
      // For global we write to maintenance_mode/global
      // For company we write to maintenance_mode/{contractorId}
      const docId = scope === 'global' ? 'global' : selectedContractor.id;
      const maintenanceRef = doc(db, 'maintenance_mode', docId);
      
      const configData = {
        enabled: true,
        scope,
        services: toggles,
        message,
        eta,
        initiatedBy: 'TrackOps_Admin',
        initiatedAt: serverTimestamp(),
        reason
      };

      await setDoc(maintenanceRef, configData);

      // Log the operation
      await setDoc(doc(collection(db, 'operation_logs')), {
        action: `Enabled ${scope === 'global' ? 'Global' : 'Company'} Maintenance`,
        targetId: docId,
        targetName: scope === 'global' ? 'All Users' : (selectedContractor.companyName || selectedContractor.email),
        reason: reason,
        performedBy: 'TrackOps_Admin',
        timestamp: serverTimestamp(),
        details: configData
      });

      setIsSafetyOpen(false);
      onClose();
    } catch (error) {
      console.error('Error executing maintenance mode:', error);
      alert('Failed to execute action. Check console.');
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <div className="bg-trackops-card border border-trackops-border rounded-lg w-full max-w-2xl overflow-hidden font-mono text-left animate-in fade-in zoom-in duration-200">
        
        <div className="bg-trackops-navy border-b border-trackops-border p-4 flex items-center justify-between">
          <h2 className="text-white font-bold uppercase flex items-center tracking-widest text-sm">
            <AlertTriangle className="w-5 h-5 mr-2 text-trackops-red" />
            Maintenance Mode
          </h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6">
          <div className="mb-6 grid grid-cols-2 gap-4">
            <button 
              onClick={() => setScope('global')}
              className={`p-4 rounded border flex flex-col items-center justify-center transition-colors ${scope === 'global' ? 'bg-trackops-red/10 border-trackops-red text-trackops-red' : 'bg-trackops-navy border-trackops-border text-gray-400 hover:border-gray-500'}`}
            >
              <Globe className="w-8 h-8 mb-2" />
              <div className="font-bold tracking-wider">GLOBAL</div>
              <div className="text-xs opacity-70 mt-1">Affects all users worldwide</div>
            </button>
            <button 
              onClick={() => setScope('company')}
              className={`p-4 rounded border flex flex-col items-center justify-center transition-colors ${scope === 'company' ? 'bg-trackops-amber/10 border-trackops-amber text-trackops-amber' : 'bg-trackops-navy border-trackops-border text-gray-400 hover:border-gray-500'}`}
            >
              <Building2 className="w-8 h-8 mb-2" />
              <div className="font-bold tracking-wider">SELECTED COMPANY</div>
              <div className="text-xs opacity-70 mt-1">Affects only one contractor</div>
            </button>
          </div>

          {scope === 'company' && (
            <div className="mb-6">
              <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Select Target Contractor</label>
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
                    <option key={c.id} value={c.id}>{c.companyName || c.name || c.id}</option>
                  ))}
                </select>
              </div>
            </div>
          )}

          <div className="mb-6">
            <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Services to Disable</label>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
              {[
                { key: 'app', label: 'Mobile App' },
                { key: 'web', label: 'Web Dashboard' },
                { key: 'adminPanel', label: 'Admin Panel' },
                { key: 'attendance', label: 'Attendance API' },
                { key: 'pdf', label: 'PDF Generation' },
                { key: 'payroll', label: 'Payroll Calc' },
              ].map(service => (
                <label key={service.key} className="flex items-center space-x-2 cursor-pointer p-2 bg-trackops-navy border border-trackops-border rounded group">
                  <div className="relative flex items-center">
                    <input 
                      type="checkbox" 
                      checked={toggles[service.key]}
                      onChange={() => handleToggle(service.key)}
                      className="peer sr-only"
                    />
                    <div className="w-4 h-4 border border-trackops-border rounded bg-trackops-bg peer-checked:bg-trackops-red peer-checked:border-trackops-red transition-colors flex items-center justify-center">
                      {toggles[service.key] && <div className="w-2 h-2 bg-white rounded-sm" />}
                    </div>
                  </div>
                  <span className={`text-xs uppercase tracking-wider ${toggles[service.key] ? 'text-white' : 'text-gray-500'}`}>{service.label}</span>
                </label>
              ))}
            </div>
          </div>

          <div className="space-y-4 mb-6">
            <div>
              <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Custom Maintenance Message</label>
              <textarea 
                rows="2"
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                className="w-full bg-trackops-navy border border-trackops-border rounded p-2 text-white text-sm focus:outline-none focus:border-trackops-red" 
              />
            </div>
            <div>
              <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">ETA (Expected Time)</label>
              <input 
                type="text" 
                value={eta}
                onChange={(e) => setEta(e.target.value)}
                className="w-full bg-trackops-navy border border-trackops-border rounded p-2 text-white text-sm focus:outline-none focus:border-trackops-red" 
              />
            </div>
          </div>

          <div className="flex justify-end pt-4 border-t border-trackops-border">
            <button onClick={onClose} className="px-6 py-2 text-gray-400 hover:text-white mr-4 text-sm font-bold uppercase tracking-widest">Cancel</button>
            <button 
              onClick={() => setIsSafetyOpen(true)}
              disabled={scope === 'company' && !selectedContractor}
              className={`px-6 py-2 rounded text-sm font-bold uppercase tracking-widest transition-colors flex items-center ${
                (scope === 'global' || selectedContractor)
                ? 'bg-trackops-red text-white shadow-[0_0_10px_rgba(255,51,102,0.3)] hover:bg-[#ff1a53]' 
                : 'bg-trackops-navy text-gray-500 cursor-not-allowed'
              }`}
            >
              <AlertTriangle className="w-4 h-4 mr-2" />
              Enable Maintenance
            </button>
          </div>
        </div>
      </div>

      <SafetyModal 
        isOpen={isSafetyOpen}
        onClose={() => setIsSafetyOpen(false)}
        onConfirm={executeAction}
        title={`Enable ${scope === 'global' ? 'Global' : 'Company'} Maintenance`}
        description={`You are about to block access to selected services. Active users will be presented with the maintenance screen immediately.`}
        actionName="ACTIVATE MAINTENANCE"
      />
    </div>
  );
}
