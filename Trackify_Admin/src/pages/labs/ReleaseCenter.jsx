import React, { useState, useEffect } from 'react';
import { UploadCloud, Calendar, GitCommit, CheckSquare } from 'lucide-react';
import { db } from '../../lib/firebase';
import { doc, onSnapshot, setDoc, updateDoc } from 'firebase/firestore';

const INITIAL_RELEASE = {
  version: '2.2',
  targetDate: '25 July',
  status: 'DRAFT',
  features: [
    'Material Cost Tracker',
    'Multi Site Attendance',
    'AI Insights',
    'Support Center'
  ],
  notesDraft: '[Draft auto-generated from feature flags...]'
};

export default function ReleaseCenter() {
  const [release, setRelease] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isPublishing, setIsPublishing] = useState(false);

  useEffect(() => {
    const unsub = onSnapshot(doc(db, 'lab_releases', 'upcoming'), async (docSnap) => {
      try {
        if (!docSnap.exists()) {
          // Seed initial data
          await setDoc(doc(db, 'lab_releases', 'upcoming'), INITIAL_RELEASE);
          setRelease(INITIAL_RELEASE);
        } else {
          setRelease({ id: docSnap.id, ...docSnap.data() });
        }
        setLoading(false);
      } catch (e) {
        console.error("ReleaseCenter fetch error:", e);
        setLoading(false);
      }
    }, (error) => {
      console.error("ReleaseCenter snapshot error:", error);
      setLoading(false);
    });

    return () => unsub();
  }, []);

  const handlePublish = async () => {
    if(!release || release.status === 'PUBLISHED') return;
    if(confirm(`Publish Release ${release.version} to Production?`)) {
      setIsPublishing(true);
      try {
        await updateDoc(doc(db, 'lab_releases', 'upcoming'), {
          status: 'PUBLISHED'
        });
      } catch (e) {
        console.error("Failed to publish:", e);
      }
      setIsPublishing(false);
    }
  };

  if (loading) {
    return (
      <div className="space-y-6 max-w-4xl">
        <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
          <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
            <UploadCloud className="w-6 h-6 mr-3 text-cyan-400" />
            Release Center
          </h1>
        </div>
        <div className="p-8 text-center text-gray-500 font-mono bg-[#121214] border border-[#27272a] rounded-xl">Loading release info...</div>
      </div>
    );
  }

  const isPublished = release?.status === 'PUBLISHED';

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
          <UploadCloud className="w-6 h-6 mr-3 text-cyan-400" />
          Release Center
        </h1>
        <button 
          onClick={handlePublish}
          disabled={isPublished || isPublishing}
          className={`text-xs flex items-center px-4 py-2 border rounded-lg transition-colors ${
            isPublished 
              ? 'bg-[#09090b] border-[#27272a] text-gray-500 cursor-not-allowed' 
              : 'bg-purple-500/10 border-purple-500/30 text-purple-400 hover:bg-purple-500/20'
          }`}
        >
          <GitCommit className={`w-4 h-4 mr-2 ${isPublishing ? 'animate-spin' : ''}`} /> 
          {isPublished ? 'Published' : isPublishing ? 'Publishing...' : 'Publish Release'}
        </button>
      </div>

      <div className="bg-[#121214] border border-[#27272a] rounded-xl overflow-hidden shadow-xl">
        {/* Header Block */}
        <div className="p-6 bg-gradient-to-br from-[#09090b] to-[#121214] border-b border-[#27272a] relative overflow-hidden">
          <div className="absolute top-0 right-0 w-64 h-64 bg-cyan-500/5 rounded-full blur-[80px]" />
          <div className="flex justify-between items-start">
            <div>
              <h2 className="text-sm font-mono text-cyan-400 tracking-widest uppercase mb-1">Upcoming Release</h2>
              <div className="text-3xl font-bold text-white tracking-tight mb-4">Version {release?.version}</div>
            </div>
            {isPublished && (
              <span className="px-3 py-1 bg-green-500/10 text-green-400 border border-green-500/20 rounded-full text-xs font-mono font-bold tracking-wider">
                LIVE
              </span>
            )}
          </div>
          
          <div className="flex items-center text-sm text-gray-400">
            <Calendar className="w-4 h-4 mr-2" /> Target Release Date: <span className="text-gray-200 ml-1 font-medium">{release?.targetDate}</span>
          </div>
        </div>

        <div className="p-6">
          <h3 className="text-gray-300 font-medium mb-4 flex items-center">
            <CheckSquare className="w-4 h-4 mr-2 text-purple-400" />
            Features Included
          </h3>
          <ul className="space-y-3">
            {(release?.features || []).map((feat, i) => (
              <li key={i} className="flex items-center text-gray-400 text-sm">
                <div className="w-1.5 h-1.5 rounded-full bg-cyan-400 mr-3 shadow-[0_0_5px_#22d3ee]" />
                {feat}
              </li>
            ))}
            {(!release?.features || release.features.length === 0) && (
              <li className="text-gray-500 text-sm italic">No features specified.</li>
            )}
          </ul>

          <div className="mt-8 pt-6 border-t border-[#27272a]">
            <h3 className="text-gray-300 font-medium mb-3">Release Notes Draft</h3>
            <div className="bg-[#09090b] border border-[#27272a] rounded-lg p-4 h-32 text-gray-500 text-sm font-mono">
              {release?.notesDraft || 'No draft available.'}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
