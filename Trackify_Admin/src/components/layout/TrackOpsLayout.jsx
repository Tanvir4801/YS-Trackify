import React, { useState, useEffect } from 'react';
import { Outlet, Navigate } from 'react-router-dom';
import TrackOpsSidebar from './TrackOpsSidebar';
import { useAuthStore } from '../../store/authStore';
import { db } from '../../lib/firebase';
import { doc, onSnapshot } from 'firebase/firestore';

export default function TrackOpsLayout() {
  const role = useAuthStore((s) => s.role);
  const [time, setTime] = useState(new Date());
  const [healthData, setHealthData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const timer = setInterval(() => setTime(new Date()), 1000);
    
    // Listen to real-time system health
    const healthRef = doc(db, 'system_status', 'health');
    let unsubscribe = () => {};
    try {
      unsubscribe = onSnapshot(healthRef, (snapshot) => {
        try {
          if (snapshot.exists()) {
            setHealthData(snapshot.data());
          }
          setLoading(false);
        } catch (e) {
          console.warn('Error processing snapshot in TrackOpsLayout:', e);
        }
      }, (err) => {
        console.warn('onSnapshot error in TrackOpsLayout:', err);
      });
    } catch (e) {
      console.warn('Failed to start onSnapshot in TrackOpsLayout:', e);
    }

    return () => {
      clearInterval(timer);
      try {
        unsubscribe();
      } catch (e) {
        console.warn("Firestore unsubscribe error in TrackOpsLayout:", e);
      }
    };
  }, []);

  if (role !== 'trackops') {
    return <Navigate to="/" replace />;
  }

  const formattedTime = time.toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: true,
  }) + ' IST'; // Note: You can replace 'IST' with dynamic timezone if needed

  // Calculate health dynamically based on metrics if available
  let statusText = 'ONLINE';
  let statusColor = 'text-trackops-green';
  let statusBg = 'bg-trackops-green';
  let statusShadow = '0 0 8px #00FF66';
  let missionHealth = 100;

  if (healthData) {
    const crashRate = healthData.crashRate || 0;
    const latencyScore = healthData.latencyScore || 0;
    const apiFailures = healthData.apiFailures || 0;
    const criticalIssues = healthData.criticalIssues || 0;

    missionHealth = Math.max(0, 100 - (crashRate + latencyScore + apiFailures + criticalIssues));

    if (healthData.overrideStatus) {
      statusText = healthData.overrideStatus;
    } else {
      if (missionHealth < 50) {
        statusText = 'CRITICAL';
      } else if (missionHealth < 80) {
        statusText = 'WARNING';
      } else if (healthData.maintenance) {
        statusText = 'MAINTENANCE';
      }
    }

    if (statusText === 'CRITICAL' || statusText === 'MAINTENANCE') {
      statusColor = 'text-trackops-red';
      statusBg = 'bg-trackops-red';
      statusShadow = '0 0 8px #FF3366';
    } else if (statusText === 'WARNING' || statusText === 'PARTIAL OUTAGE') {
      statusColor = 'text-trackops-amber';
      statusBg = 'bg-trackops-amber';
      statusShadow = '0 0 8px #FFB000';
    }
  }

  return (
    <div className="flex min-h-screen bg-trackops-bg font-sans text-gray-200"
      style={{
        backgroundImage: `
          linear-gradient(rgba(30, 41, 59, 0.1) 1px, transparent 1px),
          linear-gradient(90deg, rgba(30, 41, 59, 0.1) 1px, transparent 1px)
        `,
        backgroundSize: '40px 40px',
        backgroundPosition: 'center center'
      }}
    >
      <TrackOpsSidebar />
      <div className="flex flex-1 flex-col transition-all duration-300 ml-64">
        {/* Top Bar */}
        <header className="h-14 border-b border-trackops-border bg-trackops-bg/80 backdrop-blur-md sticky top-0 z-40 flex items-center px-6 justify-between font-mono text-sm uppercase tracking-wider">
          <div className="flex items-center space-x-6">
            <div className={`flex items-center ${statusColor}`}>
              <div className={`w-2 h-2 rounded-full ${statusBg} animate-pulse mr-2`} style={{ boxShadow: statusShadow }} />
              SYSTEM STATUS: {loading ? '...' : statusText}
            </div>
            <div className="text-gray-500">|</div>
            <div className="text-gray-400">{formattedTime}</div>
          </div>
          <div className="flex items-center space-x-6">
            <div className={`${statusColor} flex items-center`}>
              MISSION HEALTH: {loading ? '...' : `${missionHealth.toFixed(0)}%`}
            </div>
          </div>
        </header>

        {/* Main Content */}
        <main className="flex-1 p-8 relative">
          <div className="mx-auto w-full max-w-7xl">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
