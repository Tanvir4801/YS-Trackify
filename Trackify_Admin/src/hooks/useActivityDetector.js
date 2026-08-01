import { useState, useEffect, useRef } from 'react';

/**
 * Hook to detect if the user is active in the current browser tab.
 * Does NOT write anything to Firestore. Only maintains state locally.
 * Throttles event listeners to avoid performance issues.
 */
export function useActivityDetector(timeoutMs = 5 * 60 * 1000) {
  const [isActive, setIsActive] = useState(true);
  const timeoutRef = useRef(null);
  const lastEventRef = useRef(Date.now());

  useEffect(() => {
    const handleActivity = () => {
      // Throttle state updates to at most once every 5 seconds to avoid re-renders
      const now = Date.now();
      if (now - lastEventRef.current > 5000) {
        lastEventRef.current = now;
        setIsActive(true);
      }
      
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
      
      timeoutRef.current = setTimeout(() => {
        setIsActive(false);
      }, timeoutMs);
    };

    const handleVisibilityChange = () => {
      if (document.visibilityState === 'hidden') {
        setIsActive(false);
      } else {
        handleActivity();
      }
    };

    // Events to track
    const events = ['mousemove', 'mousedown', 'keydown', 'touchstart', 'scroll'];
    
    events.forEach((e) => window.addEventListener(e, handleActivity, { passive: true }));
    document.addEventListener('visibilitychange', handleVisibilityChange);

    // Initial setup
    handleActivity();

    return () => {
      events.forEach((e) => window.removeEventListener(e, handleActivity));
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    };
  }, [timeoutMs]);

  return isActive;
}
