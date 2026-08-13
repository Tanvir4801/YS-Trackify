import React from 'react';
import { Outlet } from 'react-router-dom';
import LabsSidebar from './LabsSidebar';

export default function LabsLayout() {
  return (
    <div className="flex min-h-screen bg-[#09090b] font-sans text-gray-200 selection:bg-cyan-500/30"
      style={{
        backgroundImage: `
          linear-gradient(rgba(34, 211, 238, 0.03) 1px, transparent 1px),
          linear-gradient(90deg, rgba(34, 211, 238, 0.03) 1px, transparent 1px)
        `,
        backgroundSize: '30px 30px',
        backgroundPosition: 'center center'
      }}
    >
      <LabsSidebar />
      <div className="flex flex-1 flex-col transition-all duration-300 ml-64">
        {/* Main Content */}
        <main className="flex-1 p-8 relative">
          {/* Subtle glow effects in background */}
          <div className="absolute top-0 left-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-[100px] pointer-events-none" />
          <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-[100px] pointer-events-none" />
          <div className="mx-auto w-full max-w-[1600px] relative z-10">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
