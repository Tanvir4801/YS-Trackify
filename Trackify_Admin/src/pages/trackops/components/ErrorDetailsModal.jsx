import React, { useState } from 'react';
import { AlertTriangle, Clock, Activity, Settings, User, X, ShieldAlert, Monitor, ChevronRight, Sparkles, Loader2 } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import { db } from '../../../lib/firebase';
import { doc, updateDoc, arrayUnion, serverTimestamp } from 'firebase/firestore';

export default function ErrorDetailsModal({ isOpen, onClose, error }) {
  const [updating, setUpdating] = useState(false);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [aiResponse, setAiResponse] = useState(null);

  if (!isOpen || !error) return null;

  const STATUS_FLOW = ['NEW', 'INVESTIGATING', 'IN_PROGRESS', 'FIXED', 'RESOLVED', 'IGNORED'];
  
  const getSeverityColor = (sev) => {
    switch (sev) {
      case 'CRITICAL': return 'bg-red-500/20 text-red-400 border-red-500/50';
      case 'HIGH': return 'bg-orange-500/20 text-orange-400 border-orange-500/50';
      case 'MEDIUM': return 'bg-yellow-500/20 text-yellow-400 border-yellow-500/50';
      case 'LOW': return 'bg-blue-500/20 text-blue-400 border-blue-500/50';
      default: return 'bg-gray-500/20 text-gray-400 border-gray-500/50';
    }
  };

  const handleStatusChange = async (newStatus) => {
    if (newStatus === error.status) return;
    setUpdating(true);
    try {
      const errorRef = doc(db, 'error_logs', error.id);
      await updateDoc(errorRef, {
        status: newStatus,
        updatedAt: serverTimestamp(),
        history: arrayUnion({
          status: newStatus,
          timestamp: new Date().toISOString(),
          updatedBy: 'TrackOps_Admin', // In real app, current user ID
          note: `Status updated to ${newStatus}`
        })
      });
      // Component will re-render due to snapshot listener in parent
    } catch (err) {
      console.error('Failed to update error status:', err);
      alert('Failed to update status. Check console.');
    }
    setUpdating(false);
  };

  const handleAnalyzeWithGemini = async () => {
    const apiKey = import.meta.env.VITE_GEMINI_API_KEY;
    if (!apiKey) {
      alert('VITE_GEMINI_API_KEY is missing in your .env file. Please add it to use the AI Auto-Fix feature.');
      return;
    }

    setIsAnalyzing(true);
    setAiResponse(null);

    const prompt = `You are an expert Flutter and Firebase developer diagnosing a production crash. Keep your response extremely concise and strictly formatted. DO NOT write long paragraphs.

Error Message: ${error.message}
Stack Trace: ${error.stackTrace || 'None'}
Module: ${error.module}

Respond STRICTLY in this format:
### 🎯 Root Cause
(1-2 sentences max explaining what failed)

### 🛠️ Code Fix
(The exact code snippet to fix it)

### 🛡️ Prevention
(1 sentence on how to prevent this in the future)`;

    try {
      const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }]
        })
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error("Gemini API Error Response:", errorText);
        throw new Error(`Gemini API Error (${response.status}): ${errorText}`);
      }

      const data = await response.json();
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
      
      if (text) {
        setAiResponse(text);
      } else {
        setAiResponse("Could not generate a response from the AI. Please try again.");
      }
    } catch (err) {
      console.error("AI Analysis failed:", err);
      setAiResponse(`Failed to analyze error: ${err.message}`);
    } finally {
      setIsAnalyzing(false);
    }
  };


  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <div className="bg-trackops-card border border-trackops-border rounded-lg shadow-2xl w-full max-w-4xl max-h-[90vh] flex flex-col font-mono animate-in fade-in zoom-in duration-200">
        
        {/* Header */}
        <div className="bg-trackops-navy border-b border-trackops-border p-4 flex items-center justify-between shrink-0">
          <div className="flex items-center space-x-4">
            <h2 className="text-white font-bold uppercase tracking-widest text-lg flex items-center">
              <ShieldAlert className="w-5 h-5 mr-2 text-trackops-red" />
              Error Details
            </h2>
            <span className="text-gray-500 text-sm">#{error.id}</span>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          
          {/* Quick Info Grid */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="bg-trackops-bg border border-trackops-border rounded p-3">
              <div className="text-[10px] text-gray-500 uppercase tracking-wider mb-1 flex items-center"><Activity className="w-3 h-3 mr-1" /> Type & Module</div>
              <div className="text-white font-bold text-sm">{error.type}</div>
              <div className="text-gray-400 text-xs">{error.module}</div>
            </div>
            <div className="bg-trackops-bg border border-trackops-border rounded p-3">
              <div className="text-[10px] text-gray-500 uppercase tracking-wider mb-1 flex items-center"><AlertTriangle className="w-3 h-3 mr-1" /> Severity</div>
              <span className={`inline-block px-2 py-1 rounded text-xs border ${getSeverityColor(error.severity)}`}>
                {error.severity || 'UNKNOWN'}
              </span>
            </div>
            <div className="bg-trackops-bg border border-trackops-border rounded p-3">
              <div className="text-[10px] text-gray-500 uppercase tracking-wider mb-1 flex items-center"><User className="w-3 h-3 mr-1" /> Affected User</div>
              <div className="text-white text-sm font-bold truncate">{error.userId || 'Unknown User'}</div>
              <div className="text-gray-400 text-xs truncate">{error.companyId || 'No Company'}</div>
            </div>
            <div className="bg-trackops-bg border border-trackops-border rounded p-3">
              <div className="text-[10px] text-gray-500 uppercase tracking-wider mb-1 flex items-center"><Clock className="w-3 h-3 mr-1" /> First Seen</div>
              <div className="text-trackops-amber text-sm font-bold">
                {error.createdAt?.toDate ? error.createdAt.toDate().toLocaleString() : 'N/A'}
              </div>
            </div>
          </div>

          {/* Error Message */}
          <div>
            <h3 className="text-xs text-gray-500 uppercase tracking-widest mb-2">Error Message</h3>
            <div className="bg-red-500/10 border border-red-500/30 rounded p-4 text-red-400 text-sm whitespace-pre-wrap font-bold">
              {error.message}
            </div>
          </div>

          {/* Stack Trace */}
          {error.stackTrace && (
            <div>
              <h3 className="text-xs text-gray-500 uppercase tracking-widest mb-2">Stack Trace</h3>
              <div className="bg-[#0D0D0F] border border-trackops-border rounded p-4 overflow-x-auto">
                <pre className="text-gray-400 text-[11px] leading-relaxed">
                  {error.stackTrace}
                </pre>
              </div>
            </div>
          )}

          {/* Device Info */}
          {error.deviceInfo && (
            <div>
              <h3 className="text-xs text-gray-500 uppercase tracking-widest mb-2 flex items-center"><Monitor className="w-3 h-3 mr-1" /> Device Context</h3>
              <div className="bg-trackops-bg border border-trackops-border rounded p-4 grid grid-cols-2 md:grid-cols-4 gap-4">
                {Object.entries(error.deviceInfo).map(([key, val]) => (
                  <div key={key}>
                    <div className="text-[10px] text-gray-500 uppercase">{key}</div>
                    <div className="text-white text-xs font-bold truncate">{String(val)}</div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Status History */}
          <div>
            <h3 className="text-xs text-gray-500 uppercase tracking-widest mb-2">Audit Trail</h3>
            <div className="bg-trackops-bg border border-trackops-border rounded p-4 space-y-3">
              {(error.history || []).map((h, i) => (
                <div key={i} className="flex items-start text-xs">
                  <div className="w-32 text-gray-500 shrink-0">
                    {new Date(h.timestamp).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
                  </div>
                  <div className="flex-1">
                    <span className="text-white font-bold">{h.updatedBy}</span> changed status to <span className="text-trackops-amber">{h.status}</span>
                    {h.note && <div className="text-gray-400 mt-0.5">{h.note}</div>}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* AI Analysis Section */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-xs text-gray-500 uppercase tracking-widest flex items-center">
                <Sparkles className="w-3 h-3 mr-1 text-purple-400" />
                AI Analysis & Auto-Fix
              </h3>
              {!aiResponse && !isAnalyzing && (
                <button 
                  onClick={handleAnalyzeWithGemini}
                  className="bg-purple-600/20 hover:bg-purple-600/40 text-purple-400 border border-purple-500/30 px-3 py-1 rounded text-[10px] uppercase font-bold tracking-wider transition-colors flex items-center"
                >
                  <Sparkles className="w-3 h-3 mr-1" />
                  Analyze Error
                </button>
              )}
            </div>
            
            {isAnalyzing && (
              <div className="bg-trackops-bg border border-purple-500/30 rounded p-6 flex flex-col items-center justify-center space-y-3">
                <Loader2 className="w-6 h-6 text-purple-400 animate-spin" />
                <div className="text-xs text-purple-400/70 font-bold uppercase tracking-widest animate-pulse">
                  Gemini is analyzing the stack trace...
                </div>
              </div>
            )}

            {aiResponse && (
              <div className="bg-trackops-bg border border-purple-500/30 rounded p-4">
                <div className="prose prose-invert prose-sm max-w-none prose-pre:bg-[#0D0D0F] prose-pre:border prose-pre:border-trackops-border prose-p:text-gray-300 prose-headings:text-white prose-a:text-purple-400 prose-code:text-purple-300">
                  <ReactMarkdown>{aiResponse}</ReactMarkdown>
                </div>
                <div className="mt-4 flex justify-end">
                  <button 
                    onClick={handleAnalyzeWithGemini}
                    className="text-[10px] text-gray-500 hover:text-purple-400 uppercase font-bold tracking-widest transition-colors flex items-center"
                  >
                    <Sparkles className="w-3 h-3 mr-1" />
                    Regenerate Analysis
                  </button>
                </div>
              </div>
            )}
          </div>

        </div>

        {/* Footer / Workflow Actions */}
        <div className="bg-trackops-navy border-t border-trackops-border p-4 shrink-0">
          <div className="flex items-center justify-between">
            <div className="text-xs text-gray-500 uppercase tracking-widest">Update Status:</div>
            <div className="flex space-x-2 overflow-x-auto pb-2 md:pb-0">
              {STATUS_FLOW.map((status, index) => (
                <React.Fragment key={status}>
                  <button
                    disabled={updating || error.status === status}
                    onClick={() => handleStatusChange(status)}
                    className={`px-3 py-1.5 rounded text-[10px] font-bold uppercase tracking-wider transition-colors ${
                      error.status === status 
                        ? 'bg-trackops-green text-black cursor-default' 
                        : 'bg-trackops-bg border border-trackops-border text-gray-400 hover:text-white hover:border-gray-500 disabled:opacity-50'
                    }`}
                  >
                    {status}
                  </button>
                  {index < STATUS_FLOW.length - 1 && (
                    <ChevronRight className="w-4 h-4 text-gray-600 self-center shrink-0" />
                  )}
                </React.Fragment>
              ))}
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
