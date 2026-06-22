import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db } from './firebase';

const generateSessionId = () => {
  return 'sess_' + Date.now() + '_' + Math.floor(Math.random() * 10000);
};

let currentSessionId = null;
const getSessionId = () => {
  if (!currentSessionId) {
    currentSessionId = generateSessionId();
  }
  return currentSessionId;
};

const getDeviceInfo = () => {
  const ua = navigator.userAgent;
  let platform = 'Web';
  if (/iPad|iPhone|iPod/.test(ua)) platform = 'iOS Web';
  else if (/Android/.test(ua)) platform = 'Android Web';
  else if (/Macintosh|Windows|Linux/.test(ua)) platform = 'Desktop Web';

  return {
    deviceName: 'Web Browser',
    appVersion: '1.0.0',
    platform: platform
  };
};

export const logTelemetryEvent = async ({
  eventType, // 'screen_open', 'feature_usage'
  featureName = 'Unknown',
  screenName = 'Unknown',
  userId,
  companyId,
  role,
  additionalMetadata = {}
}) => {
  if (!userId) return; // Need user context

  try {
    const deviceInfo = getDeviceInfo();
    
    const payload = {
      eventType,
      featureName,
      screenName,
      userId,
      companyId: companyId || userId,
      role: role || 'unknown',
      deviceName: deviceInfo.deviceName,
      appVersion: deviceInfo.appVersion,
      platform: deviceInfo.platform,
      timestamp: serverTimestamp(),
      sessionId: getSessionId(),
    };

    if (Object.keys(additionalMetadata).length > 0) {
      payload.additionalMetadata = additionalMetadata;
    }

    // Fire and forget
    addDoc(collection(db, 'telemetry_events'), payload).catch(() => {});
  } catch (err) {
    console.error('Telemetry Error:', err);
  }
};
