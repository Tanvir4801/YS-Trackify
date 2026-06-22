import React, { useState, useEffect } from 'react';
import { Lightbulb, Users, ThumbsUp } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, doc, setDoc, updateDoc, increment } from 'firebase/firestore';

const INITIAL_REQUESTS = [
  { id: '1', title: 'Material Cost', reqs: 12, trend: 'up' },
  { id: '2', title: 'Offline Mode', reqs: 7, trend: 'up' },
  { id: '3', title: 'Labour Contractors', reqs: 20, trend: 'up' },
  { id: '4', title: 'Payroll Improvements', reqs: 5, trend: 'stable' },
  { id: '5', title: 'Bulk Attendance', reqs: 15, trend: 'up' },
];

export default function FeatureRequests() {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'lab_feature_requests'), async (snap) => {
      try {
        if (snap.empty) {
          // Seed initial data
          for (const req of INITIAL_REQUESTS) {
            await setDoc(doc(db, 'lab_feature_requests', req.id), req);
          }
          setRequests(INITIAL_REQUESTS);
        } else {
          setRequests(snap.docs.map(d => ({ id: d.id, ...d.data() })));
        }
        setLoading(false);
      } catch (e) {
        console.error("FeatureRequests fetch error:", e);
        setLoading(false);
      }
    }, (error) => {
      console.error("FeatureRequests snapshot error:", error);
      setLoading(false);
    });

    return () => unsub();
  }, []);

  const handleUpvote = async (reqId) => {
    try {
      await updateDoc(doc(db, 'lab_feature_requests', reqId), {
        reqs: increment(1)
      });
    } catch (e) {
      console.error("Failed to upvote:", e);
    }
  };

  // Sort by requests desc
  const sorted = [...requests].sort((a, b) => b.reqs - a.reqs);

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
          <Lightbulb className="w-6 h-6 mr-3 text-cyan-400" />
          Feature Requests
        </h1>
      </div>

      <div className="bg-[#121214] border border-[#27272a] rounded-xl overflow-hidden shadow-xl">
        {loading ? (
          <div className="p-8 text-center text-gray-500 font-mono">Loading requests...</div>
        ) : (
          <div className="grid grid-cols-1 divide-y divide-[#27272a]">
            {sorted.map((req, i) => (
              <div key={req.id} className="p-5 flex items-center justify-between hover:bg-white/[0.02] transition-colors group">
                <div className="flex items-center">
                  <div className="w-10 h-10 rounded bg-[#09090b] border border-[#27272a] flex items-center justify-center mr-4 text-gray-500">
                    <span className="font-mono text-sm">{i + 1}</span>
                  </div>
                  <div>
                    <h3 className="text-gray-200 font-medium mb-1">{req.title}</h3>
                    <div className="flex items-center text-xs text-gray-500">
                      <Users className="w-3 h-3 mr-1" />
                      Requested by Contractors
                    </div>
                  </div>
                </div>
                
                <div className="flex flex-col items-end">
                  <button 
                    onClick={() => handleUpvote(req.id)}
                    className="flex items-center space-x-2 text-cyan-400 font-mono mb-1 bg-cyan-400/10 px-3 py-1 rounded-full border border-cyan-400/20 hover:bg-cyan-400/20 transition-colors"
                  >
                    <ThumbsUp className="w-3 h-3" />
                    <span>{req.reqs} Requests</span>
                  </button>
                </div>
              </div>
            ))}
            {sorted.length === 0 && (
              <div className="p-8 text-center text-gray-500 font-mono">No requests found.</div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
