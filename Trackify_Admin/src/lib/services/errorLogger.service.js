import { db } from '../firebase';
import { collection, addDoc, serverTimestamp, setDoc, doc } from 'firebase/firestore';

/**
 * Service to globally log errors from the React Admin panel to Firestore.
 */
class ErrorLoggerService {
  /**
   * Log an error to the global error_logs collection.
   * @param {Object} params
   * @param {Error|string} params.error - The error object or string message
   * @param {string} [params.module='Admin Panel'] - Where the error occurred
   * @param {string} [params.severity='MEDIUM'] - LOW, MEDIUM, HIGH, CRITICAL
   * @param {string} [params.userId=null] - Affected user ID if known
   * @param {string} [params.companyId=null] - Affected company ID if known
   * @param {Object} [params.additionalData={}] - Any extra context
   */
  static async logError({
    error,
    module = 'Admin Panel',
    severity = 'MEDIUM',
    userId = null,
    companyId = null,
    additionalData = {}
  }) {
    try {
      const message = error instanceof Error ? error.message : String(error);
      const stackTrace = error instanceof Error ? error.stack : null;

      // Extract basic device/browser info
      const deviceInfo = {
        userAgent: navigator.userAgent,
        platform: navigator.platform,
        language: navigator.language,
        screenWidth: window.innerWidth,
        screenHeight: window.innerHeight
      };

      const errorPayload = {
        message,
        stackTrace,
        type: 'React Error',
        module,
        severity,
        status: 'NEW',
        userId,
        companyId,
        deviceInfo,
        additionalData,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        history: [
          {
            status: 'NEW',
            timestamp: new Date().toISOString(),
            updatedBy: 'system',
            note: 'Error logged automatically'
          }
        ]
      };

      // We use addDoc to auto-generate the document ID
      const docRef = await addDoc(collection(db, 'error_logs'), errorPayload);
      
      // We also update the system_status/health to potentially increment crash rates
      // In a real production system, this would ideally be done via Cloud Functions reacting to error_logs.
      // For now, we just log it.
      
      return docRef.id;
    } catch (loggingError) {
      // Fallback if Firebase logging itself fails
      console.error('Failed to log error to Firestore:', loggingError);
      console.error('Original Error:', error);
      return null;
    }
  }

  /**
   * Helper to wrap async functions and catch/log errors automatically.
   */
  static withLogging(fn, contextParams = {}) {
    return async (...args) => {
      try {
        return await fn(...args);
      } catch (error) {
        await this.logError({ error, ...contextParams });
        throw error; // Re-throw to allow component handling
      }
    };
  }
}

export default ErrorLoggerService;
