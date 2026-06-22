import React, { useState } from 'react';
import { AlertTriangle, ShieldAlert, X } from 'lucide-react';

export default function SafetyModal({ isOpen, onClose, onConfirm, title, description, actionName }) {
  const [reason, setReason] = useState('');
  const [securityConfirmed, setSecurityConfirmed] = useState(false);
  const [confirmText, setConfirmText] = useState('');

  if (!isOpen) return null;

  const isFormValid = reason.trim().length > 5 && securityConfirmed && confirmText === 'CONFIRM';

  const handleConfirm = () => {
    if (isFormValid) {
      onConfirm(reason);
      // Reset state for next time
      setReason('');
      setSecurityConfirmed(false);
      setConfirmText('');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <div className="bg-trackops-card border border-trackops-red rounded-lg shadow-[0_0_20px_rgba(255,51,102,0.15)] w-full max-w-md overflow-hidden font-mono text-left animate-in fade-in zoom-in duration-200">
        <div className="bg-trackops-red/10 border-b border-trackops-red p-4 flex items-center justify-between">
          <h2 className="text-trackops-red font-bold uppercase flex items-center tracking-widest text-sm">
            <ShieldAlert className="w-5 h-5 mr-2" />
            Safety System
          </h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          <div>
            <h3 className="text-white text-lg font-bold mb-2">{title}</h3>
            <p className="text-gray-400 text-sm">{description}</p>
          </div>

          <div className="bg-trackops-navy p-4 rounded border border-trackops-amber/30 text-trackops-amber text-xs leading-relaxed flex items-start">
            <AlertTriangle className="w-4 h-4 mr-2 shrink-0 mt-0.5" />
            <p>This is a critical operation. It will take effect immediately in the production database and cannot be easily undone.</p>
          </div>

          <div className="space-y-4">
            <div>
              <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Reason for Action *</label>
              <input 
                type="text" 
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                className="w-full bg-trackops-navy border border-trackops-border rounded p-2.5 text-white text-sm focus:outline-none focus:border-trackops-red transition-colors"
                placeholder="e.g., Requested by billing team"
              />
            </div>

            <label className="flex items-start space-x-3 cursor-pointer group">
              <div className="relative flex items-start">
                <input 
                  type="checkbox" 
                  checked={securityConfirmed}
                  onChange={(e) => setSecurityConfirmed(e.target.checked)}
                  className="peer sr-only"
                />
                <div className="w-5 h-5 border-2 border-trackops-border rounded bg-trackops-navy peer-checked:bg-trackops-red peer-checked:border-trackops-red transition-colors flex items-center justify-center">
                  {securityConfirmed && <div className="w-2.5 h-2.5 bg-white rounded-sm" />}
                </div>
              </div>
              <span className="text-sm text-gray-400 group-hover:text-gray-300 transition-colors pt-0.5">
                I understand the consequences of this action and take full responsibility.
              </span>
            </label>

            <div>
              <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Type CONFIRM to proceed *</label>
              <input 
                type="text" 
                value={confirmText}
                onChange={(e) => setConfirmText(e.target.value)}
                className="w-full bg-trackops-navy border border-trackops-border rounded p-2.5 text-white text-sm focus:outline-none focus:border-trackops-red transition-colors"
                placeholder="CONFIRM"
              />
            </div>
          </div>

          <button 
            onClick={handleConfirm}
            disabled={!isFormValid}
            className={`w-full py-3 rounded font-bold text-xs uppercase tracking-widest transition-colors ${
              isFormValid 
                ? 'bg-trackops-red text-white shadow-[0_0_15px_rgba(255,51,102,0.4)] hover:bg-[#ff1a53]' 
                : 'bg-trackops-navy text-gray-500 border border-trackops-border cursor-not-allowed'
            }`}
          >
            Execute: {actionName}
          </button>
        </div>
      </div>
    </div>
  );
}
