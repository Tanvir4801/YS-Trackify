import React from 'react';
import { Map, CheckCircle, Clock, ArrowRight } from 'lucide-react';

export default function Roadmap() {
  const roadmapItems = [
    { title: 'V2 Released', status: 'completed', time: 'Last Month', desc: 'Major overhaul of the UI and performance improvements.' },
    { title: 'Multi Site Attendance', status: 'completed', time: '3 Weeks Ago', desc: 'Supervisors can now manage multiple sites simultaneously.' },
    { title: 'Labour Contractors', status: 'completed', time: '2 Weeks Ago', desc: 'Added support for sub-contractor management.' },
    { title: 'Material Cost Tracking', status: 'completed', time: '1 Week Ago', desc: 'Integrated material expenses into the site cost module.' },
    { title: 'AI Insights', status: 'in-progress', time: 'Current Sprint', desc: 'Providing AI-driven business intelligence in Mission Control.' },
    { title: 'Advanced Export Builder', status: 'upcoming', time: 'Next Sprint', desc: 'Customizable PDF/Excel export layouts.' },
    { title: 'Offline Mode (Full)', status: 'upcoming', time: 'Q3 2026', desc: 'Full offline capabilities with background sync.' },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between border-b border-trackops-border pb-4">
        <h1 className="text-2xl font-bold tracking-widest text-white uppercase flex items-center">
          <Map className="w-6 h-6 mr-3 text-trackops-green animate-pulse" />
          Product Roadmap
        </h1>
      </div>

      <div className="bg-trackops-card border border-trackops-border rounded-md p-6 relative">
        <div className="absolute left-10 top-10 bottom-10 w-0.5 bg-trackops-border" />
        
        <div className="space-y-8 relative z-10">
          {roadmapItems.map((item, idx) => (
            <div key={idx} className="flex group">
              <div className="w-14 flex flex-col items-center">
                <div className={`w-8 h-8 rounded-full flex items-center justify-center border-2 ${
                  item.status === 'completed' ? 'bg-trackops-green/20 border-trackops-green text-trackops-green' :
                  item.status === 'in-progress' ? 'bg-trackops-amber/20 border-trackops-amber text-trackops-amber animate-pulse' :
                  'bg-trackops-navy border-trackops-border text-gray-500'
                }`}>
                  {item.status === 'completed' && <CheckCircle className="w-4 h-4" />}
                  {item.status === 'in-progress' && <Clock className="w-4 h-4" />}
                  {item.status === 'upcoming' && <ArrowRight className="w-4 h-4" />}
                </div>
              </div>
              <div className="flex-1 ml-4 pt-1">
                <div className="flex items-center justify-between mb-1">
                  <h3 className={`font-bold text-lg ${
                    item.status === 'completed' ? 'text-gray-300 line-through decoration-trackops-green/50' :
                    item.status === 'in-progress' ? 'text-white' :
                    'text-gray-400'
                  }`}>
                    {item.title}
                  </h3>
                  <span className="text-[10px] uppercase tracking-widest text-gray-500 font-mono border border-trackops-border px-2 py-1 rounded">
                    {item.time}
                  </span>
                </div>
                <p className="text-sm text-gray-500 font-mono">{item.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
