import React, { useEffect, useState } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { signInWithCustomToken } from 'firebase/auth';
import { httpsCallable } from 'firebase/functions';
import { auth, functions } from '../lib/firebase';
import { useAuthStore } from '../store/authStore';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import { ShieldCheck, AlertCircle, ArrowLeft } from 'lucide-react';

export default function DemoEntry() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const token = searchParams.get('token');
  const [statusText, setStatusText] = useState('Initializing demo environment...');
  const [error, setError] = useState(null);

  useEffect(() => {
    let isMounted = true;

    async function handleDemoLogin() {
      try {
        if (token) {
          if (isMounted) setStatusText('Verifying signed demo session token...');
          await signInWithCustomToken(auth, token);
          if (isMounted) {
            setStatusText('Access granted. Entering dashboard...');
            navigate('/dashboard', { replace: true });
          }
          return;
        }

        // If no token in URL, request a direct demo session from Cloud Functions
        if (isMounted) setStatusText('Provisioning instant demo sandbox...');
        const createSessionFn = httpsCallable(functions, 'createDemoSession');
        const res = await createSessionFn({ sessionType: 'web_admin', callerName: 'Direct Demo Visitor' });

        if (res.data?.token) {
          if (isMounted) setStatusText('Authenticating demo sandbox session...');
          await signInWithCustomToken(auth, res.data.token);
          if (isMounted) {
            navigate('/dashboard', { replace: true });
          }
        } else {
          throw new Error('No session token received from demo engine.');
        }
      } catch (err) {
        console.error('DemoEntry error:', err);
        if (isMounted) {
          setError(err.message || 'Failed to initialize demo session. Please try again.');
        }
      }
    }

    handleDemoLogin();

    return () => {
      isMounted = false;
    };
  }, [token, navigate]);

  if (error) {
    return (
      <div className="min-h-screen bg-[#080E1A] flex items-center justify-center p-4">
        <div className="max-w-md w-full bg-[#0F1A2E] border border-red-500/30 rounded-2xl p-6 text-center shadow-2xl">
          <div className="w-12 h-12 rounded-full bg-red-500/20 text-red-400 mx-auto flex items-center justify-center mb-4">
            <AlertCircle className="w-6 h-6" />
          </div>
          <h2 className="text-xl font-heading font-bold text-white mb-2">Demo Session Error</h2>
          <p className="text-xs text-slate-300 mb-6 leading-relaxed">{error}</p>
          <div className="flex gap-3 justify-center">
            <button
              onClick={() => window.location.reload()}
              className="px-4 py-2 rounded-lg bg-amber-500 hover:bg-amber-600 text-slate-950 font-semibold text-xs transition-colors"
            >
              Retry Connection
            </button>
            <a
              href="/login"
              className="px-4 py-2 rounded-lg bg-white/[0.05] hover:bg-white/[0.1] text-white text-xs font-mono transition-colors flex items-center gap-1.5"
            >
              <ArrowLeft className="w-3.5 h-3.5" />
              <span>Back to Login</span>
            </a>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#080E1A] flex flex-col items-center justify-center p-4">
      <div className="max-w-sm w-full bg-[#0F1A2E] border border-amber-500/30 rounded-2xl p-8 text-center shadow-2xl space-y-4">
        <div className="w-12 h-12 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-400 mx-auto flex items-center justify-center">
          <ShieldCheck className="w-6 h-6" />
        </div>
        <h3 className="text-lg font-heading font-bold text-white">Trackify Demo Sandbox</h3>
        <p className="text-xs font-mono text-amber-400/90">{statusText}</p>
        <div className="pt-2">
          <LoadingSpinner label="" />
        </div>
        <p className="text-[11px] text-slate-400 pt-2">
          Connecting to sandbox tenant: <span className="text-slate-200 font-mono">trackify_demo</span>
        </p>
      </div>
    </div>
  );
}

