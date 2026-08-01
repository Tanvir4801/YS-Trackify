import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { doc, getDoc, setDoc, onSnapshot, serverTimestamp, collection, addDoc } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { useAuthStore } from '../store/authStore';
import { useActivityDetector } from '../hooks/useActivityDetector';
import toast from 'react-hot-toast';

const TrackOpsMonitoringContext = createContext();

export function TrackOpsMonitoringProvider({ children }) {
  const uid = useAuthStore((s) => s.uid);
  const role = useAuthStore((s) => s.role);
  const name = useAuthStore((s) => s.name);
  const [monitoringEnabled, setMonitoringEnabled] = useState(false);
  const [lastStoppedAt, setLastStoppedAt] = useState(null);
  
  // Smart auto-sleep: inactive for 10 minutes or hidden for 5 minutes
  const isUserActive = useActivityDetector(10 * 60 * 1000); 

  // Read configuration from Firestore
  useEffect(() => {
    if (role !== 'trackops' && role !== 'super_admin') return;

    const docRef = doc(db, 'trackops_config', 'monitoring');
    const unsubscribe = onSnapshot(docRef, (snap) => {
      if (snap.exists()) {
        const data = snap.data();
        const wasEnabled = monitoringEnabled;
        setMonitoringEnabled(data.enabled === true);
        
        // Track when it was turned off for the "While you were away" feature
        if (wasEnabled && !data.enabled) {
          setLastStoppedAt(Date.now());
        }
      }
    }, (err) => {
      console.warn("Failed to listen to TrackOps monitoring config:", err);
    });

    return () => unsubscribe();
  }, [role]);

  // Compute final state
  const isPaused = monitoringEnabled && !isUserActive;
  const isMonitoringActive = monitoringEnabled && !isPaused;

  const toggleMonitoring = useCallback(async () => {
    if (role !== 'super_admin' && role !== 'trackops') {
      toast.error('You do not have permission to change global monitoring state.');
      return;
    }

    try {
      const newState = !monitoringEnabled;
      const docRef = doc(db, 'trackops_config', 'monitoring');
      
      await setDoc(docRef, {
        enabled: newState,
        changedAt: serverTimestamp(),
        changedBy: uid
      }, { merge: true });

      // Audit log
      await addDoc(collection(db, 'mission_logs'), {
        type: 'MONITORING_TOGGLE',
        severity: newState ? 'INFO' : 'WARNING',
        message: `Master monitoring control turned ${newState ? 'ON' : 'OFF'}`,
        timestamp: serverTimestamp(),
        userId: uid,
        userName: name || role
      });
      
      if (!newState) {
        setLastStoppedAt(Date.now());
        toast.success('Monitoring disabled. Background traffic stopped.');
      } else {
        toast.success('Monitoring enabled. Systems live.');
      }
    } catch (err) {
      console.error("Failed to toggle monitoring:", err);
      toast.error('Failed to change monitoring state.');
    }
  }, [monitoringEnabled, role, uid, name]);

  return (
    <TrackOpsMonitoringContext.Provider value={{ 
      monitoringEnabled, 
      isPaused, 
      isMonitoringActive,
      toggleMonitoring,
      lastStoppedAt
    }}>
      {children}
    </TrackOpsMonitoringContext.Provider>
  );
}

export function useTrackOpsMonitoring() {
  const context = useContext(TrackOpsMonitoringContext);
  if (!context) {
    throw new Error('useTrackOpsMonitoring must be used within a TrackOpsMonitoringProvider');
  }
  return context;
}
