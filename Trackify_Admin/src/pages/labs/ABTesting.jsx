import React, { useState, useEffect } from 'react';
import { Layers, Users, BarChart2 } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, doc, setDoc, updateDoc } from 'firebase/firestore';

const INITIAL_TESTS = [
  { 
    id: '1', 
    name: 'Suspension Navbar Test', 
    status: 'ACTIVE',
    versionA: { name: 'Bridge UI', users: 10, metrics: [{label: 'Average Session Time', val: '4m 12s', win: true}, {label: 'Feature Discovery', val: '45%', win: false}] },
    versionB: { name: 'Modern Navbar', users: 10, metrics: [{label: 'Average Session Time', val: '3m 45s', win: false}, {label: 'Feature Discovery', val: '62%', win: true}] },
    insight: 'Version B shows a 17% increase in feature discovery.'
  }
];

export default function ABTesting() {
  const [tests, setTests] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'lab_ab_tests'), async (snap) => {
      try {
        if (snap.empty) {
          // Seed initial data
          for (const test of INITIAL_TESTS) {
            await setDoc(doc(db, 'lab_ab_tests', test.id), test);
          }
          setTests(INITIAL_TESTS);
        } else {
          setTests(snap.docs.map(d => ({ id: d.id, ...d.data() })));
        }
        setLoading(false);
      } catch (e) {
        console.error("ABTesting fetch error:", e);
        setLoading(false);
      }
    }, (error) => {
      console.error("ABTesting snapshot error:", error);
      setLoading(false);
    });

    return () => unsub();
  }, []);

  const promoteVariant = async (testId, variantName) => {
    if(confirm(`Promote ${variantName} to Production?`)) {
      try {
        await updateDoc(doc(db, 'lab_ab_tests', testId), {
          status: 'PROMOTED',
          promotedVariant: variantName
        });
      } catch (e) {
        console.error("Failed to promote variant:", e);
      }
    }
  };

  return (
    <div className="space-y-6 max-w-5xl">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
          <Layers className="w-6 h-6 mr-3 text-cyan-400" />
          A/B Testing Center
        </h1>
      </div>

      {loading ? (
        <div className="p-8 text-center text-gray-500 font-mono bg-[#121214] border border-[#27272a] rounded-xl">Loading experiments...</div>
      ) : tests.length === 0 ? (
        <div className="p-8 text-center text-gray-500 font-mono bg-[#121214] border border-[#27272a] rounded-xl">No active experiments.</div>
      ) : (
        <div className="space-y-6">
          {tests.map(test => (
            <div key={test.id} className="bg-[#121214] border border-[#27272a] rounded-xl p-6">
              <div className="flex justify-between items-center mb-6">
                <h2 className="text-lg font-medium text-gray-200">{test.name}</h2>
                <span className={`text-xs font-mono px-3 py-1 rounded-full border tracking-wider ${
                  test.status === 'ACTIVE' 
                    ? 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30'
                    : 'bg-green-500/10 text-green-400 border-green-500/30'
                }`}>
                  {test.status === 'ACTIVE' ? 'ACTIVE EXPERIMENT' : `PROMOTED: ${test.promotedVariant}`}
                </span>
              </div>

              <div className="grid grid-cols-2 gap-8 relative">
                {/* Divider */}
                <div className="absolute left-1/2 top-0 bottom-0 w-px bg-gradient-to-b from-transparent via-[#27272a] to-transparent -translate-x-1/2" />

                {/* Version A */}
                <div className={`space-y-4 pr-4 ${test.status === 'PROMOTED' && test.promotedVariant !== 'Version A' ? 'opacity-40 grayscale' : ''}`}>
                  <div className="flex justify-between items-center">
                    <h3 className="text-gray-300 font-medium font-mono text-sm">Version A: {test.versionA.name}</h3>
                    <div className="flex items-center text-xs text-gray-500 bg-[#09090b] px-2 py-1 rounded border border-[#27272a]">
                      <Users className="w-3 h-3 mr-1" /> {test.versionA.users} Contractors
                    </div>
                  </div>
                  <div className="h-32 border-2 border-dashed border-[#27272a] rounded-lg flex items-center justify-center bg-[#09090b]">
                    <span className="text-gray-600 text-sm">Preview A</span>
                  </div>
                  <div className="bg-[#09090b] p-4 rounded-lg border border-[#27272a] space-y-3">
                    {(test.versionA.metrics || []).map((m, i) => (
                      <Metric key={i} label={m.label} val={m.val} win={m.win} />
                    ))}
                  </div>
                </div>

                {/* Version B */}
                <div className={`space-y-4 pl-4 ${test.status === 'PROMOTED' && test.promotedVariant !== 'Version B' ? 'opacity-40 grayscale' : ''}`}>
                  <div className="flex justify-between items-center">
                    <h3 className="text-gray-300 font-medium font-mono text-sm">Version B: {test.versionB.name}</h3>
                    <div className="flex items-center text-xs text-gray-500 bg-[#09090b] px-2 py-1 rounded border border-[#27272a]">
                      <Users className="w-3 h-3 mr-1" /> {test.versionB.users} Contractors
                    </div>
                  </div>
                  <div className="h-32 border-2 border-dashed border-[#27272a] rounded-lg flex items-center justify-center bg-[#09090b]">
                    <span className="text-gray-600 text-sm">Preview B</span>
                  </div>
                  <div className="bg-[#09090b] p-4 rounded-lg border border-[#27272a] space-y-3">
                    {(test.versionB.metrics || []).map((m, i) => (
                      <Metric key={i} label={m.label} val={m.val} win={m.win} />
                    ))}
                  </div>
                </div>
              </div>

              {test.status === 'ACTIVE' && (
                <div className="mt-8 pt-6 border-t border-[#27272a] flex items-center justify-between">
                  <div className="flex items-center text-gray-400 text-sm">
                    <BarChart2 className="w-5 h-5 mr-2 text-cyan-400" />
                    <span dangerouslySetInnerHTML={{__html: test.insight.replace(/([0-9]+%)/g, '<strong class="text-white mx-1">$1</strong>')}}></span>
                  </div>
                  <div className="flex space-x-3">
                    <button 
                      onClick={() => promoteVariant(test.id, 'Version A')}
                      className="px-4 py-2 bg-[#09090b] border border-[#27272a] text-gray-300 font-semibold text-sm rounded-lg hover:text-white transition-colors"
                    >
                      Promote A
                    </button>
                    <button 
                      onClick={() => promoteVariant(test.id, 'Version B')}
                      className="px-4 py-2 bg-cyan-500 text-black font-semibold text-sm rounded-lg hover:bg-cyan-400 transition-colors shadow-[0_0_15px_rgba(34,211,238,0.4)]"
                    >
                      Promote B to Production
                    </button>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function Metric({ label, val, win }) {
  return (
    <div className="flex justify-between items-center">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-sm font-mono ${win ? 'text-cyan-400 font-semibold' : 'text-gray-400'}`}>
        {val}
      </span>
    </div>
  );
}
