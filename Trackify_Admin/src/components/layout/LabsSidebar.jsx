import React from 'react';
import { NavLink } from 'react-router-dom';
import { 
  FlaskConical, Flag, Sparkles, Activity, FileCode, Layers, 
  Map, Lightbulb, TrendingUp, Zap, FileText, UploadCloud, ArrowLeft
} from 'lucide-react';
import { useAuthStore } from '../../store/authStore';

const navItems = [
  { path: '/labs/feature-flags', icon: Flag, label: 'Feature Flags' },
  { path: '/labs/beta', icon: Zap, label: 'Beta Test Center' },
  { path: '/labs/cost-simulator', icon: Activity, label: 'Firebase Simulator' },
  { path: '/labs/ai', icon: Sparkles, label: 'AI Labs' },
  { path: '/labs/ab-testing', icon: Layers, label: 'A/B Testing' },
  { path: '/labs/ui', icon: FileCode, label: 'UI Labs' },
  { path: '/labs/roadmap', icon: Map, label: 'Roadmap' },
  { path: '/labs/experimental', icon: FlaskConical, label: 'Experimental' },
  { path: '/labs/performance', icon: TrendingUp, label: 'Performance Lab' },
  { path: '/labs/notes', icon: FileText, label: 'Internal Notes' },
  { path: '/labs/requests', icon: Lightbulb, label: 'Feature Requests' },
  { path: '/labs/release', icon: UploadCloud, label: 'Release Center' },
];

export default function LabsSidebar() {
  const role = useAuthStore((s) => s.role);
  const isSuperAdmin = role === 'super_admin';
  const homePath = isSuperAdmin ? '/sa/dashboard' : '/trackops/dashboard';

  return (
    <div className="fixed inset-y-0 left-0 z-50 w-64 bg-[#09090b] border-r border-[#27272a] flex flex-col font-sans text-sm text-gray-400">
      <div className="p-5 border-b border-[#27272a]">
        <div className="flex items-center space-x-3 mb-4">
          <div className="w-8 h-8 rounded bg-gradient-to-br from-cyan-500 to-purple-600 flex items-center justify-center shadow-[0_0_15px_rgba(34,211,238,0.3)]">
            <FlaskConical className="w-5 h-5 text-white" />
          </div>
          <div>
            <div className="text-white font-bold tracking-wide">TRACKIFY LABS</div>
            <div className="text-[10px] text-cyan-400 font-mono">INNOVATION HUB</div>
          </div>
        </div>
        <NavLink 
          to={homePath}
          className="flex items-center text-xs text-gray-500 hover:text-white transition-colors group"
        >
          <ArrowLeft className="w-3 h-3 mr-2 group-hover:-translate-x-1 transition-transform" />
          Exit to {isSuperAdmin ? 'Super Admin' : 'Mission Control'}
        </NavLink>
      </div>

      <nav className="flex-1 overflow-y-auto py-4 space-y-0.5 scrollbar-hide px-3">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) =>
              `flex items-center px-3 py-2.5 rounded-lg transition-all duration-200 ${
                isActive 
                  ? 'bg-white/5 text-cyan-400 border border-cyan-500/20 shadow-[inset_0_0_20px_rgba(34,211,238,0.05)]' 
                  : 'border border-transparent hover:bg-white/5 hover:text-gray-200'
              }`
            }
          >
            <item.icon className={`w-4 h-4 mr-3 ${'opacity-80'}`} />
            <span className="tracking-wide text-[13px] font-medium">{item.label}</span>
          </NavLink>
        ))}
      </nav>

      <div className="p-4 border-t border-[#27272a] bg-[#050505]">
        <div className="text-[10px] tracking-widest text-gray-500 uppercase mb-2 font-mono">Environment</div>
        <div className="flex items-center text-xs text-purple-400 font-mono">
          <div className="w-2 h-2 rounded-full bg-purple-500 animate-pulse mr-2 shadow-[0_0_8px_#c084fc]" />
          EXPERIMENTAL
        </div>
      </div>
    </div>
  );
}
