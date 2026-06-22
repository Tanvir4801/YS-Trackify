import React, { useState, useEffect } from 'react';
import { Settings, Search, CreditCard, Calendar, Star, CheckCircle, X } from 'lucide-react';
import { db } from '../../../lib/firebase';
import { collection, query, where, getDocs, doc, setDoc, serverTimestamp } from 'firebase/firestore';
import SafetyModal from './SafetyModal';

export default function SubscriptionManagerModal({ isOpen, onClose, initialMode = 'premium' }) { // 'premium' or 'trial'
  const [contractors, setContractors] = useState([]);
  const [selectedContractor, setSelectedContractor] = useState(null);
  const [loading, setLoading] = useState(false);
  
  const [planType, setPlanType] = useState('Pro');
  const [trialDays, setTrialDays] = useState(14);
  const [isSafetyOpen, setIsSafetyOpen] = useState(false);

  useEffect(() => {
    if (isOpen) {
      fetchContractors();
    }
  }, [isOpen]);

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

  const executeAction = async (reason) => {
    if (!selectedContractor) return;

    try {
      const subRef = doc(db, 'subscriptions', selectedContractor.id);
      
      let actionName = '';
      let subData = {};

      if (initialMode === 'premium') {
        actionName = `Granted ${planType} Premium`;
        subData = {
          plan: planType,
          status: 'active',
          grantedBy: 'TrackOps_Admin',
          grantedAt: serverTimestamp(),
          isLifetime: planType === 'Enterprise'
        };
      } else {
        actionName = `Extended Trial by ${trialDays} Days`;
        subData = {
          trialEndsAt: new Date(Date.now() + trialDays * 24 * 60 * 60 * 1000).toISOString(),
          extendedBy: 'TrackOps_Admin',
          extendedReason: reason
        };
      }

      await setDoc(subRef, subData, { merge: true });

      // Notify contractor (write to notifications collection)
      await setDoc(doc(collection(db, 'notifications')), {
        userId: selectedContractor.id,
        title: initialMode === 'premium' ? 'Premium Activated' : 'Trial Extended',
        body: initialMode === 'premium' 
          ? `Your account has been upgraded to ${planType}.`
          : `Your trial has been extended by ${trialDays} days.`,
        createdAt: serverTimestamp(),
        read: false
      });

      // Log the operation
      await setDoc(doc(collection(db, 'operation_logs')), {
        action: actionName,
        targetId: selectedContractor.id,
        targetName: selectedContractor.companyName || selectedContractor.name || selectedContractor.email,
        reason: reason,
        performedBy: 'TrackOps_Admin',
        timestamp: serverTimestamp()
      });

      setIsSafetyOpen(false);
      onClose();
    } catch (error) {
      console.error('Error updating subscription:', error);
      alert('Failed to execute action. Check console.');
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <div className="bg-trackops-card border border-trackops-border rounded-lg w-full max-w-2xl overflow-hidden font-mono text-left animate-in fade-in zoom-in duration-200">
        
        <div className="bg-trackops-navy border-b border-trackops-border p-4 flex items-center justify-between">
          <h2 className="text-white font-bold uppercase flex items-center tracking-widest text-sm">
            {initialMode === 'premium' ? (
              <><Settings className="w-5 h-5 mr-2 text-trackops-green" /> Grant Premium</>
            ) : (
              <><Clock className="w-5 h-5 mr-2 text-white" /> Extend Trial</>
            )}
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
                className="w-full bg-trackops-bg border border-trackops-border rounded pl-10 pr-4 py-2 text-white text-sm focus:outline-none focus:border-trackops-green appearance-none"
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

          {selectedContractor && (
            <div className="mb-6 grid grid-cols-2 md:grid-cols-3 gap-4">
              <div className="bg-trackops-navy border border-trackops-border rounded p-4">
                <div className="text-gray-500 text-xs mb-1 flex items-center"><Star className="w-3 h-3 mr-1" /> Current Plan</div>
                <div className="text-white font-bold text-sm">Free Trial</div>
              </div>
              <div className="bg-trackops-navy border border-trackops-border rounded p-4">
                <div className="text-gray-500 text-xs mb-1 flex items-center"><Calendar className="w-3 h-3 mr-1" /> Expiry Date</div>
                <div className="text-trackops-amber font-bold text-sm">Ends in 2 days</div>
              </div>
              <div className="bg-trackops-navy border border-trackops-border rounded p-4">
                <div className="text-gray-500 text-xs mb-1 flex items-center"><CreditCard className="w-3 h-3 mr-1" /> Payment Status</div>
                <div className="text-gray-400 font-bold text-sm">Unpaid</div>
              </div>
            </div>
          )}

          {selectedContractor && initialMode === 'premium' && (
            <div className="space-y-4 mb-6">
              <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Select Plan</label>
              <div className="grid grid-cols-3 gap-3">
                {['Basic', 'Pro', 'Enterprise'].map(plan => (
                  <div 
                    key={plan}
                    onClick={() => setPlanType(plan)}
                    className={`cursor-pointer p-4 rounded border flex flex-col items-center justify-center transition-colors ${planType === plan ? 'bg-trackops-green/10 border-trackops-green' : 'bg-trackops-navy border-trackops-border hover:border-gray-500'}`}
                  >
                    <div className={`font-bold text-lg mb-1 ${planType === plan ? 'text-trackops-green' : 'text-white'}`}>{plan}</div>
                    <div className="text-xs text-gray-400">{plan === 'Enterprise' ? 'Lifetime' : 'Monthly'}</div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {selectedContractor && initialMode === 'trial' && (
            <div className="space-y-4 mb-6">
              <label className="text-xs text-gray-500 uppercase tracking-wider block mb-2">Extension Duration</label>
              <div className="grid grid-cols-3 gap-3">
                {[7, 14, 30].map(days => (
                  <div 
                    key={days}
                    onClick={() => setTrialDays(days)}
                    className={`cursor-pointer p-4 rounded border flex flex-col items-center justify-center transition-colors ${trialDays === days ? 'bg-white/10 border-white' : 'bg-trackops-navy border-trackops-border hover:border-gray-500'}`}
                  >
                    <div className={`font-bold text-xl mb-1 ${trialDays === days ? 'text-white' : 'text-gray-300'}`}>+{days}</div>
                    <div className="text-xs text-gray-400">Days</div>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="flex justify-end pt-4 border-t border-trackops-border">
            <button onClick={onClose} className="px-6 py-2 text-gray-400 hover:text-white mr-4 text-sm font-bold uppercase tracking-widest">Cancel</button>
            <button 
              onClick={() => setIsSafetyOpen(true)}
              disabled={!selectedContractor}
              className={`px-6 py-2 rounded text-sm font-bold uppercase tracking-widest transition-colors flex items-center ${
                selectedContractor 
                ? (initialMode === 'premium' 
                    ? 'bg-trackops-green text-black shadow-[0_0_10px_rgba(0,255,102,0.3)] hover:bg-[#00e65c]' 
                    : 'bg-white text-black hover:bg-gray-200')
                : 'bg-trackops-navy text-gray-500 cursor-not-allowed'
              }`}
            >
              <CheckCircle className="w-4 h-4 mr-2" />
              {initialMode === 'premium' ? 'Grant Premium' : 'Extend Trial'}
            </button>
          </div>
        </div>
      </div>

      <SafetyModal 
        isOpen={isSafetyOpen}
        onClose={() => setIsSafetyOpen(false)}
        onConfirm={executeAction}
        title={initialMode === 'premium' ? 'Activate Premium Subscription' : 'Extend Trial Period'}
        description={`You are about to manually ${initialMode === 'premium' ? `grant ${planType} plan` : `extend the trial by ${trialDays} days`} for ${selectedContractor?.companyName || 'this company'}. The user will be notified immediately.`}
        actionName="UPDATE SUBSCRIPTION"
      />
    </div>
  );
}
