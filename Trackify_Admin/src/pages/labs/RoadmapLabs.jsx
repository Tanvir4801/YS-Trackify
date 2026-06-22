import React from 'react';
import { Map, CheckCircle2, Clock, Zap, Target } from 'lucide-react';

export default function RoadmapLabs() {
  const roadmap = [
    { name: 'Trackify V2', status: 'Completed', progress: 100, icon: CheckCircle2, color: 'text-cyan-400', bg: 'bg-cyan-400' },
    { name: 'Trackify V2.5', status: 'In Progress', progress: 85, icon: Clock, color: 'text-amber-400', bg: 'bg-amber-400' },
    { name: 'Trackify V3', status: 'Testing', progress: 20, icon: Target, color: 'text-purple-400', bg: 'bg-purple-400' },
    { name: 'Trackify AI', status: 'Planning', progress: 5, icon: Zap, color: 'text-pink-400', bg: 'bg-pink-400' },
  ];

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
          <Map className="w-6 h-6 mr-3 text-cyan-400" />
          Product Roadmap
        </h1>
      </div>

      <div className="space-y-6">
        {roadmap.map((item, i) => (
          <div key={i} className="bg-[#121214] border border-[#27272a] p-6 rounded-xl">
            <div className="flex justify-between items-center mb-4">
              <div className="flex items-center">
                <item.icon className={`w-5 h-5 mr-3 ${item.color}`} />
                <h3 className="text-lg font-medium text-gray-200">{item.name}</h3>
              </div>
              <span className={`text-[10px] uppercase tracking-widest font-mono ${item.color}`}>
                {item.status}
              </span>
            </div>
            
            <div className="relative h-2 w-full bg-[#09090b] rounded-full overflow-hidden border border-[#27272a]">
              <div 
                className={`absolute top-0 left-0 h-full ${item.bg} transition-all duration-1000 ease-out`}
                style={{ width: `${item.progress}%` }}
              >
                {/* Glow effect on the bar */}
                <div className="absolute top-0 right-0 bottom-0 w-10 bg-white/30 blur-[2px]" />
              </div>
            </div>
            <div className="mt-2 text-right">
              <span className="text-xs text-gray-500 font-mono">{item.progress}% Completed</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
