import React from 'react';
import { FlaskConical, MessageSquare, Mic, Fingerprint, MapPin, WifiOff, Smartphone } from 'lucide-react';

export default function ExperimentalModules() {
  const modules = [
    { name: 'AI Chatbot', icon: MessageSquare },
    { name: 'Voice Attendance', icon: Mic },
    { name: 'Face Attendance', icon: Fingerprint }, // Reusing Fingerprint as biometric proxy
    { name: 'WhatsApp Payroll', icon: Smartphone },
    { name: 'GPS Tracking', icon: MapPin },
    { name: 'Offline Sync', icon: WifiOff },
    { name: 'Biometric Attendance', icon: Fingerprint },
  ];

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
          <FlaskConical className="w-6 h-6 mr-3 text-cyan-400" />
          Experimental Modules
        </h1>
      </div>

      <div className="bg-[#121214] border border-[#27272a] rounded-xl overflow-hidden shadow-xl">
        <div className="p-4 bg-[#09090b] border-b border-[#27272a]">
          <p className="text-sm text-gray-400">Everything stays here until production-ready.</p>
        </div>
        <div className="grid grid-cols-1 divide-y divide-[#27272a]">
          {modules.map((mod, i) => (
            <div key={i} className="p-4 flex items-center justify-between hover:bg-white/[0.02] transition-colors group">
              <div className="flex items-center">
                <mod.icon className="w-5 h-5 text-gray-500 mr-4 group-hover:text-cyan-400 transition-colors" />
                <span className="text-gray-200 font-medium">{mod.name}</span>
              </div>
              <button className="text-xs px-3 py-1.5 rounded border border-[#27272a] text-gray-400 hover:text-white hover:border-gray-500 transition-all">
                Configure
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
