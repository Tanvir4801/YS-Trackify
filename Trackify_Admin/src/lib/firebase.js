import { initializeApp, getApps, getApp } from 'firebase/app';
import { initializeAppCheck, ReCaptchaV3Provider } from 'firebase/app-check';
import { getAuth } from 'firebase/auth';
import { initializeFirestore, persistentLocalCache, persistentMultipleTabManager } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';
import { getFunctions } from 'firebase/functions';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

const required = ['apiKey', 'authDomain', 'projectId', 'appId'];
const missing = required.filter((k) => !firebaseConfig[k]);
if (missing.length > 0) {
  if (typeof window !== 'undefined') {
    document.body.innerHTML = `
      <div style="color: white; background: #990000; padding: 40px; font-family: sans-serif; text-align: center; height: 100vh; display: flex; flex-direction: column; justify-content: center; align-items: center;">
        <h1 style="font-size: 24px; margin-bottom: 20px;">Vercel Deployment Error</h1>
        <p style="font-size: 16px;">Firebase Environment Variables are missing from your Vercel Project Settings.</p>
        <div style="background: rgba(0,0,0,0.5); padding: 20px; border-radius: 8px; margin-top: 20px; text-align: left; font-family: monospace;">
          VITE_FIREBASE_API_KEY<br/>
          VITE_FIREBASE_AUTH_DOMAIN<br/>
          VITE_FIREBASE_PROJECT_ID<br/>
          VITE_FIREBASE_STORAGE_BUCKET<br/>
          VITE_FIREBASE_MESSAGING_SENDER_ID<br/>
          VITE_FIREBASE_APP_ID
        </div>
        <p style="font-size: 14px; margin-top: 20px; max-width: 500px;">
          Go to Vercel -> Settings -> Environment Variables. Add these keys with the values from your local .env file, then Redepoy the project.
        </p>
      </div>
    `;
  }
  throw new Error(`Missing Firebase env vars: ${missing.join(', ')}`);
}

export const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);

if (typeof window !== 'undefined') {
  initializeAppCheck(app, {
    provider: new ReCaptchaV3Provider('recaptcha-v3-site-key'),
    isTokenAutoRefreshEnabled: true
  });
}

export const auth = getAuth(app);
export const db = initializeFirestore(app, {
  localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() })
});
export const storage = getStorage(app);
export const functions = getFunctions(app);

let secondaryApp = null;
export function getSecondaryAuth() {
  if (!secondaryApp) {
    secondaryApp = initializeApp(firebaseConfig, 'Secondary');
  }
  return getAuth(secondaryApp);
}
