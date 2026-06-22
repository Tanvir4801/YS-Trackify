import React, { useState, useEffect } from 'react';
import { Flag, Search, Power } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, doc, setDoc, updateDoc } from 'firebase/firestore';

const INITIAL_FLAGS = [
  { id: '1', name: 'Multi Site Attendance', status: 'ON', desc: 'Allows labours to be marked present at multiple sites in one day.' },
  { id: '2', name: 'AI Insights', status: 'BETA', desc: 'Generate daily actionable insights using Gemini Pro.' },
  { id: '3', name: 'Material Management', status: 'COMING SOON', desc: 'Full inventory tracking and material purchase orders.' },
  { id: '4', name: 'Labour Contractor Module', status: 'OFF', desc: 'Allow sub-contractors to manage their own petty cash.' },
  { id: '5', name: 'Firebase Notifications V2', status: 'TESTING', desc: 'Reliable push notifications via FCM HTTP v1 API.' },
  { id: '6', name: 'Offline Attendance', status: 'ON', desc: 'Allow supervisors to take attendance without internet via local SQLite.' },
];

export default function FeatureFlags() {
  const [flags, setFlags] = useState([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'lab_feature_flags'), async (snap) => {
      try {
        if (snap.empty) {
          // Seed initial data
          for (const flag of INITIAL_FLAGS) {
            await setDoc(doc(db, 'lab_feature_flags', flag.id), flag);
          }
          setFlags(INITIAL_FLAGS);
        } else {
          setFlags(snap.docs.map(d => ({ id: d.id, ...d.data() })).sort((a, b) => parseInt(a.id) - parseInt(b.id)));
        }
        setLoading(false);
      } catch (e) {
        console.error("FeatureFlags fetch error:", e);
        setLoading(false);
      }
    }, (error) => {
      console.error("FeatureFlags snapshot error:", error);
      setLoading(false);
    });

    return () => unsub();
  }, []);

  const getStatusColor = (status) => {
    switch(status) {
      case 'ON': return 'text-cyan-400 bg-cyan-400/10 border-cyan-400/20';
      case 'OFF': return 'text-gray-400 bg-gray-400/10 border-gray-400/20';
      case 'BETA': return 'text-purple-400 bg-purple-400/10 border-purple-400/20';
      case 'TESTING': return 'text-amber-400 bg-amber-400/10 border-amber-400/20';
      case 'COMING SOON': return 'text-blue-400 bg-blue-400/10 border-blue-400/20';
      default: return 'text-gray-400 bg-gray-800';
    }
  };

  const toggleFlag = async (flag) => {
    let newStatus = flag.status;
    if (flag.status === 'ON') newStatus = 'OFF';
    else if (flag.status === 'OFF') newStatus = 'ON';
    else if (flag.status === 'BETA') newStatus = 'ON';
    else if (flag.status === 'TESTING') newStatus = 'ON';
    else if (flag.status === 'COMING SOON') newStatus = 'TESTING';

    try {
      // Optimistic update
      setFlags(prev => prev.map(f => f.id === flag.id ? { ...f, status: newStatus } : f));
      await updateDoc(doc(db, 'lab_feature_flags', flag.id), { status: newStatus });
    } catch (e) {
      console.error("Failed to update flag:", e);
      // Revert optimistic update
      setFlags(prev => prev.map(f => f.id === flag.id ? { ...f, status: flag.status } : f));
    }
  };

  const filteredFlags = flags.filter(f => 
    f.name.toLowerCase().includes(search.toLowerCase()) || 
    f.desc.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
          <Flag className="w-6 h-6 mr-3 text-cyan-400" />
          Feature Flags
        </h1>
        <div className="relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-500" />
          <input 
            type="text" 
            placeholder="Search flags..." 
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="bg-[#121214] border border-[#27272a] text-sm rounded-lg pl-9 pr-4 py-2 text-white focus:outline-none focus:border-cyan-500/50 w-64 transition-colors"
          />
        </div>
      </div>

      <div className="bg-[#121214] border border-[#27272a] rounded-xl overflow-hidden shadow-xl">
        {loading ? (
          <div className="p-8 text-center text-gray-500 font-mono">Loading feature flags...</div>
        ) : (
          <div className="grid grid-cols-1 divide-y divide-[#27272a]">
            {filteredFlags.map(flag => (
              <div key={flag.id} className="p-5 flex items-center justify-between hover:bg-white/[0.02] transition-colors group">
                <div className="flex-1">
                  <div className="flex items-center space-x-3 mb-1">
                    <h3 className="text-base font-medium text-gray-200">{flag.name}</h3>
                    <span className={`text-[10px] px-2 py-0.5 rounded-full border font-mono tracking-wider ${getStatusColor(flag.status)}`}>
                      {flag.status}
                    </span>
                  </div>
                  <p className="text-sm text-gray-500">{flag.desc}</p>
                </div>
                <div className="pl-4">
                  <button 
                    onClick={() => toggleFlag(flag)}
                    className={`p-2 rounded-lg border transition-all ${
                      flag.status === 'ON' || flag.status === 'BETA'
                        ? 'bg-cyan-500/10 border-cyan-500/30 text-cyan-400 shadow-[0_0_10px_rgba(34,211,238,0.2)]'
                        : 'bg-[#09090b] border-[#27272a] text-gray-500 hover:text-white hover:border-gray-600'
                    }`}
                  >
                    <Power className="w-5 h-5" />
                  </button>
                </div>
              </div>
            ))}
            {filteredFlags.length === 0 && (
              <div className="p-8 text-center text-gray-500 font-mono">No flags found.</div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
