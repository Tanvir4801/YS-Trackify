import React, { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import { logTelemetryEvent } from '../../lib/telemetry';

export default function TelemetryTracker() {
  const location = useLocation();
  const { uid, role, contractorId } = useAuthStore();

  useEffect(() => {
    if (uid) {
      const parts = location.pathname.split('/').filter(Boolean);
      let featureName = 'Dashboard';
      if (parts.length > 0) {
        if (['trackops', 'sa', 'labs'].includes(parts[0]) && parts.length > 1) {
          featureName = `${parts[0]}_${parts[1]}`;
        } else {
          featureName = parts[0];
        }
      }

      logTelemetryEvent({
        eventType: 'screen_open',
        screenName: location.pathname,
        featureName: featureName,
        userId: uid,
        companyId: contractorId || uid,
        role: role,
      });
    }
  }, [location.pathname, uid, role, contractorId]);

  return null;
}
