import { db } from '../firebase';
import { doc, setDoc, serverTimestamp } from 'firebase/firestore';

/**
 * Service to ping the TrackOps 'live_users' collection to report Admin panel health.
 */
class HealthPingService {
  constructor() {
    this.pingTimer = null;
    this.currentUserId = null;
    this.currentCompanyId = 'Trackify_HQ';
    this.companyName = 'Trackify Internal';
    this.userName = 'Admin';
    this.role = 'super_admin';
    this.subscriptionPlan = 'Premium';
    this.loginTime = null;
    this.crashCount = 0;
    this.currentScreen = 'Dashboard';
  }

  /**
   * Start the periodic pinging
   */
  startPinging({ userId, companyId = 'Trackify_HQ', companyName = 'Trackify Internal', userName = 'Admin', role = 'super_admin', subscriptionPlan = 'Premium' }) {
    if (!userId) return;
    this.currentUserId = userId;
    this.currentCompanyId = companyId;
    this.companyName = companyName;
    this.userName = userName;
    this.role = role;
    this.subscriptionPlan = subscriptionPlan;
    if (!this.loginTime) this.loginTime = new Date();
    
    // Ping immediately
    this.sendPing();

    // Setup periodic ping every 60 seconds
    if (this.pingTimer) clearInterval(this.pingTimer);
    this.pingTimer = setInterval(() => this.sendPing(), 60000);
  }

  /**
   * Update the current screen the admin is viewing
   */
  updateScreen(screenName) {
    this.currentScreen = screenName;
  }

  /**
   * Stop pinging
   */
  stopPinging() {
    if (this.pingTimer) clearInterval(this.pingTimer);
    this.pingTimer = null;
    this.currentUserId = null;
    this.loginTime = null;
    this.crashCount = 0;
  }

  incrementCrashCount() {
    this.crashCount++;
  }

  async sendPing() {
    if (!this.currentUserId) return;

    try {
      // Very crude latency test just for telemetry flavor (pinging a small public asset)
      const start = Date.now();
      let latencyMs = -1;
      try {
        await fetch('https://www.google.com/favicon.ico', { mode: 'no-cors' });
        latencyMs = Date.now() - start;
      } catch (e) {
        // offline
      }

      const sessionDurationMins = this.loginTime ? Math.floor((new Date() - this.loginTime) / 60000) : 0;

      const pingPayload = {
        userId: this.currentUserId,
        companyId: this.currentCompanyId,
        companyName: this.companyName,
        userName: this.userName,
        role: this.role,
        subscriptionPlan: this.subscriptionPlan,
        appVersion: 'React_Admin_v2',
        platform: navigator.platform || 'Web_Admin',
        deviceModel: 'Desktop Web',
        networkStatus: latencyMs === -1 ? 'OFFLINE' : (latencyMs > 1000 ? 'SLOW' : 'ONLINE'),
        currentScreen: this.currentScreen,
        latencyMs: latencyMs,
        loginTime: this.loginTime ? this.loginTime.toISOString() : new Date().toISOString(),
        sessionDurationMins,
        batteryLevel: 'Unknown',
        crashCount: this.crashCount,
        firebaseConnectionStatus: latencyMs === -1 ? 'DISCONNECTED' : 'CONNECTED',
        lastSeen: serverTimestamp(),
      };

      // Upsert into live_users collection
      await setDoc(doc(db, 'live_users', this.currentUserId), pingPayload, { merge: true });
    } catch (err) {
      console.warn('Failed to send Admin health ping:', err);
    }
  }
}

export default new HealthPingService();
