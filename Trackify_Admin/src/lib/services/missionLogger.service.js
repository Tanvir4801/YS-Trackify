import { db } from '../firebase';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';

export const MissionSeverity = {
  INFO: 'INFO',
  SUCCESS: 'SUCCESS',
  WARNING: 'WARNING',
  ERROR: 'ERROR',
  CRITICAL: 'CRITICAL',
  SECURITY: 'SECURITY'
};

export const MissionModule = {
  Attendance: 'Attendance',
  Payroll: 'Payroll',
  Reports: 'Reports',
  Subscription: 'Subscription',
  Security: 'Security',
  Firebase: 'Firebase',
  TrackOps: 'TrackOps',
  Errors: 'Errors',
  Contractors: 'Contractors',
  Labours: 'Labours',
  Critical: 'Critical'
};

/**
 * Centralized service to push audit logs to the Trackify Mission Control stream.
 */
class MissionLoggerService {
  /**
   * Log an action to the `mission_logs` collection.
   */
  async logAction({ severity, module, action, companyId, userId, details }) {
    try {
      const payload = {
        timestamp: serverTimestamp(),
        severity: severity,
        module: module,
        action: action,
        companyId: companyId,
        userId: userId,
        details: details || ''
      };

      await addDoc(collection(db, 'mission_logs'), payload);
    } catch (err) {
      console.warn('Failed to send mission log:', err);
    }
  }
}

export default new MissionLoggerService();
