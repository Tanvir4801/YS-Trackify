import React, { useState, useEffect } from 'react';
import { Sparkles, BrainCircuit, Bot } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, doc, setDoc, updateDoc } from 'firebase/firestore';

const INITIAL_MODELS = [
  { id: '1', name: 'AI Labour Analytics', status: 'TESTING', desc: 'Predicting which sites need more workforce based on historical data.' },
  { id: '2', name: 'AI Attendance Prediction', status: 'TESTING', desc: 'Estimating tomorrow\'s attendance percentage for active sites.' },
  { id: '3', name: 'AI Site Cost Prediction', status: 'COMING SOON', desc: 'Forecasting material budget overruns.' },
  { id: '4', name: 'AI Contractor Health Score', status: 'BETA', desc: 'Generating health metrics based on usage.' },
  { id: '5', name: 'AI Revenue Forecast', status: 'TESTING', desc: 'Predicting SaaS churn and MRR changes.' },
];

export default function AILabs() {
  const [models, setModels] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'lab_ai_models'), async (snap) => {
      try {
        if (snap.empty) {
          // Seed initial data
          for (const model of INITIAL_MODELS) {
            await setDoc(doc(db, 'lab_ai_models', model.id), model);
          }
          setModels(INITIAL_MODELS);
        } else {
          setModels(snap.docs.map(d => ({ id: d.id, ...d.data() })).sort((a, b) => parseInt(a.id) - parseInt(b.id)));
        }
        setLoading(false);
      } catch (e) {
        console.error("AILabs fetch error:", e);
        setLoading(false);
      }
    }, (error) => {
      console.error("AILabs snapshot error:", error);
      setLoading(false);
    });

    return () => unsub();
  }, []);

  const cycleStatus = async (model) => {
    let newStatus = model.status;
    if (model.status === 'COMING SOON') newStatus = 'TESTING';
    else if (model.status === 'TESTING') newStatus = 'BETA';
    else if (model.status === 'BETA') newStatus = 'PRODUCTION';
    else if (model.status === 'PRODUCTION') newStatus = 'COMING SOON';

    try {
      await updateDoc(doc(db, 'lab_ai_models', model.id), { status: newStatus });
    } catch(e) {
      console.error("Error updating model status:", e);
    }
  };

  const testPrompt = (name) => {
    const prompt = window.prompt(`Enter a test prompt for ${name}:`);
    if (prompt) {
      alert(`Sent to ${name}:\n"${prompt}"\n\n(Simulated AI Response: "This is a placeholder response from the ${name} model.")`);
    }
  };

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
          <Sparkles className="w-6 h-6 mr-3 text-cyan-400" />
          AI Labs & Models
        </h1>
      </div>

      {loading ? (
        <div className="p-8 text-center text-gray-500 font-mono bg-[#121214] border border-[#27272a] rounded-xl">Loading AI models...</div>
      ) : (
        <div className="grid grid-cols-1 gap-4">
          {models.map(model => (
            <div key={model.id} className="bg-[#121214] border border-[#27272a] p-4 rounded-xl flex items-start group hover:border-purple-500/30 transition-colors">
              <div className="bg-[#09090b] p-3 rounded-lg border border-[#27272a] mr-4 text-purple-400 group-hover:text-cyan-400 transition-colors">
                <BrainCircuit className="w-5 h-5" />
              </div>
              <div className="flex-1">
                <div className="flex items-center space-x-3 mb-1">
                  <h3 className="text-gray-200 font-medium">{model.name}</h3>
                  <button 
                    onClick={() => cycleStatus(model)}
                    className={`text-[10px] px-2 py-0.5 rounded-full border font-mono tracking-wider transition-colors hover:opacity-80 ${
                      model.status === 'TESTING' ? 'text-amber-400 border-amber-400/30 bg-amber-400/10' :
                      model.status === 'BETA' ? 'text-purple-400 border-purple-400/30 bg-purple-400/10' :
                      model.status === 'PRODUCTION' ? 'text-cyan-400 border-cyan-400/30 bg-cyan-400/10' :
                      'text-gray-400 border-gray-600 bg-gray-800'
                    }`}
                  >
                    {model.status}
                  </button>
                </div>
                <p className="text-sm text-gray-500">{model.desc}</p>
              </div>
              <button 
                onClick={() => testPrompt(model.name)}
                className="px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-xs text-gray-300 hover:bg-purple-500/20 hover:text-purple-300 transition-colors flex items-center"
              >
                <Bot className="w-3 h-3 mr-2" />
                Test Prompt
              </button>
            </div>
          ))}
          {models.length === 0 && (
             <div className="p-8 text-center text-gray-500 font-mono">No AI models found.</div>
          )}
        </div>
      )}
    </div>
  );
}
