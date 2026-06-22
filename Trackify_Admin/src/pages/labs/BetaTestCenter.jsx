import React, { useState, useEffect } from 'react';
import { Zap, ShieldCheck, Users, Search } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, doc, setDoc, updateDoc, arrayUnion } from 'firebase/firestore';

const INITIAL_TESTS = [
  { id: '1', name: 'Attendance V3', status: 'BETA', activeFor: ['YS Construction', 'ABC Builders'], totalAvailable: 2 },
  { id: '2', name: 'AI Reports', status: 'BETA', activeFor: ['YS Construction', 'Apex Corp', 'Skyline Infra'], totalAvailable: 5 },
  { id: '3', name: 'Multi-Site Payroll', status: 'ALPHA', activeFor: ['YS Construction'], totalAvailable: 1 },
  { id: '4', name: 'Supervisor Dashboard V3', status: 'ROLLING OUT', activeFor: ['12 Contractors'], totalAvailable: 15 },
];

export default function BetaTestCenter() {
  const [tests, setTests] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'lab_beta_tests'), async (snap) => {
      try {
        if (snap.empty) {
          // Seed initial data
          for (const test of INITIAL_TESTS) {
            await setDoc(doc(db, 'lab_beta_tests', test.id), test);
          }
          setTests(INITIAL_TESTS);
        } else {
          setTests(snap.docs.map(d => ({ id: d.id, ...d.data() })).sort((a, b) => parseInt(a.id) - parseInt(b.id)));
        }
        setLoading(false);
      } catch (e) {
        console.error("BetaTestCenter fetch error:", e);
        setLoading(false);
      }
    }, (error) => {
      console.error("BetaTestCenter snapshot error:", error);
      setLoading(false);
    });

    return () => unsub();
  }, []);

  const setStatus = async (id, status) => {
    try {
      await updateDoc(doc(db, 'lab_beta_tests', id), { status });
    } catch(e) {
      console.error("Error setting status:", e);
    }
  };

  const addContractor = async (id) => {
    const name = prompt("Enter contractor name to add to this test:");
    if (!name || !name.trim()) return;
    try {
      await updateDoc(doc(db, 'lab_beta_tests', id), {
        activeFor: arrayUnion(name.trim())
      });
    } catch(e) {
      console.error("Error adding contractor:", e);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
          <Zap className="w-6 h-6 mr-3 text-purple-400" />
          Beta Test Center
        </h1>
      </div>

      {loading ? (
        <div className="p-8 text-center text-gray-500 font-mono bg-[#121214] border border-[#27272a] rounded-xl">Loading tests...</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {tests.map(test => (
            <div key={test.id} className="bg-[#121214] border border-[#27272a] rounded-xl p-5 relative overflow-hidden group">
              {/* Subtle glow */}
              <div className="absolute top-0 right-0 p-8 opacity-10 pointer-events-none transition-opacity group-hover:opacity-20">
                <div className="w-32 h-32 rounded-full bg-purple-500 blur-3xl" />
              </div>

              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-lg font-medium text-gray-200">{test.name}</h3>
                  <div className="text-xs text-gray-500 mt-1 flex items-center">
                    <ShieldCheck className="w-3 h-3 mr-1 text-purple-400" />
                    Status: <span className="ml-1 text-purple-400 font-mono tracking-wider">{test.status}</span>
                  </div>
                </div>
                <div className="flex space-x-2">
                  <button onClick={() => setStatus(test.id, 'ACTIVE')} className="px-3 py-1 text-xs font-medium rounded bg-cyan-500/10 text-cyan-400 border border-cyan-500/30 hover:bg-cyan-500/20 transition-colors">
                    Enable
                  </button>
                  <button onClick={() => setStatus(test.id, 'DISABLED')} className="px-3 py-1 text-xs font-medium rounded bg-[#09090b] text-gray-400 border border-[#27272a] hover:text-white transition-colors">
                    Disable
                  </button>
                </div>
              </div>

              <div className="bg-[#09090b] rounded-lg border border-[#27272a] p-3">
                <div className="text-xs text-gray-500 uppercase tracking-widest font-mono mb-2 flex items-center justify-between">
                  <span>Available For</span>
                  <span className="text-gray-400">{test.totalAvailable} Allowed</span>
                </div>
                <ul className="space-y-1">
                  {(test.activeFor || []).map((c, i) => (
                    <li key={i} className="text-sm text-gray-300 flex items-center">
                      <div className="w-1.5 h-1.5 rounded-full bg-cyan-400 mr-2 shadow-[0_0_5px_#22d3ee]" />
                      {c}
                    </li>
                  ))}
                </ul>
                <button onClick={() => addContractor(test.id)} className="mt-3 w-full py-2 border border-dashed border-[#27272a] rounded text-xs text-gray-500 hover:text-cyan-400 hover:border-cyan-500/50 transition-colors">
                  + Add Contractor
                </button>
              </div>
            </div>
          ))}
          {tests.length === 0 && (
            <div className="col-span-1 md:col-span-2 p-8 text-center text-gray-500 font-mono">No tests found.</div>
          )}
        </div>
      )}
    </div>
  );
}
