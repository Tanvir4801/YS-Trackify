import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { 
  Activity, Users, AlertTriangle, LifeBuoy, 
  BarChart2, Server, Key, GitBranch, Crosshair, Shield, Map, FlaskConical, LogOut, Rocket
} from 'lucide-react';
import { auth } from '../../lib/firebase';
import { signOut } from 'firebase/auth';

const navItems = [
  { path: '/trackops/dashboard', icon: Activity, label: 'Mission Dashboard' },
  { path: '/trackops/deployment', icon: Rocket, label: 'Deployment Center' },
  { path: '/trackops/live-users', icon: Users, label: 'Live Users' },
  { path: '/trackops/mission-logs', icon: GitBranch, label: 'Mission Logs' },
  { path: '/trackops/health', icon: Server, label: 'Product Health' },
  { path: '/trackops/errors', icon: AlertTriangle, label: 'Error Center' },
  { path: '/trackops/support', icon: LifeBuoy, label: 'Support Center' },
  { path: '/trackops/analytics', icon: BarChart2, label: 'Usage Analytics' },
  { path: '/trackops/remote-actions', icon: Crosshair, label: 'Remote Actions' },
  { path: '/trackops/security', icon: Shield, label: 'Security & DB' },
  { path: '/trackops/roadmap', icon: Map, label: 'Roadmap' },
  { path: '/labs', icon: FlaskConical, label: 'Trackify Labs' },
];

export default function TrackOpsSidebar() {
  const navigate = useNavigate();

  const handleLogout = async () => {
    try {
      await signOut(auth);
      navigate('/login');
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  return (
    <div className="fixed inset-y-0 left-0 z-50 w-64 bg-trackops-navy border-r border-trackops-border flex flex-col font-mono text-sm text-gray-400">
      <div className="p-4 border-b border-trackops-border flex items-center justify-between">
        <div>
          <div className="text-white font-bold tracking-widest text-lg">TRACKOPS</div>
          <div className="text-[10px] text-trackops-green animate-pulse">MISSION CONTROL</div>
        </div>
      </div>

      <nav className="flex-1 overflow-y-auto py-4 space-y-1 scrollbar-hide">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) =>
              `flex items-center px-4 py-3 border-l-4 transition-all duration-200 ${
                isActive 
                  ? 'border-trackops-green bg-trackops-steel text-white shadow-[inset_4px_0_0_0_#00FF66]' 
                  : 'border-transparent hover:bg-trackops-card hover:text-gray-200'
              }`
            }
          >
            <item.icon className="w-5 h-5 mr-3 opacity-70" />
            <span className="uppercase tracking-wider text-[11px] font-semibold">{item.label}</span>
          </NavLink>
        ))}
      </nav>

      <div className="p-4 border-t border-trackops-border space-y-4">
        <div>
          <div className="text-[10px] tracking-widest text-gray-500 uppercase mb-2">System Auth</div>
          <div className="flex items-center text-xs text-trackops-green">
            <Key className="w-4 h-4 mr-2" />
            CLEARANCE: LEVEL 5
          </div>
        </div>
        
        <button
          onClick={handleLogout}
          className="w-full flex items-center justify-center px-4 py-2 bg-red-500/10 border border-red-500/20 text-red-400 hover:text-red-300 hover:bg-red-500/20 rounded-lg transition-colors font-semibold tracking-wider text-xs uppercase"
        >
          <LogOut className="w-4 h-4 mr-2" />
          Sign Out
        </button>
      </div>
    </div>
  );
}
