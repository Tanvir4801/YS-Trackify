import React, { useEffect, useState } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { signInWithCustomToken, signInAnonymously } from 'firebase/auth';
import { auth } from '../lib/firebase';
import { useAuthStore } from '../store/authStore';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import { ShieldCheck, AlertCircle, ArrowLeft } from 'lucide-react';

export default function DemoEntry() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const token = searchParams.get('token');
  const [statusText, setStatusText] = useState('Initializing demo environment...');
  const [error, setError] = useState(null);

  const setUser = useAuthStore((s) => s.setUser);
  const switchContractor = useAuthStore((s) => s.switchContractor);

  useEffect(() => {
    let isMounted = true;

    async function handleDemoLogin() {
      try {
        if (isMounted) setStatusText('Configuring sandbox tenant (trackify_demo)...');

        // Always set demo flags in storage
        sessionStorage.setItem('trackify_demo_mode', 'true');
        sessionStorage.setItem(
          'trackify_demo_expires_at',
          String(Date.now() + 24 * 60 * 60 * 1000)
        );
        sessionStorage.setItem('trackify_demo_company', 'XYZ Construction');

        // Attempt custom token if passed in query parameter
        if (token) {
          try {
            if (isMounted) setStatusText('Verifying signed demo session token...');
            await signInWithCustomToken(auth, token);
          } catch (tokenErr) {
            console.warn('Custom token verify fallback to anonymous/local demo session:', tokenErr);
          }
        }

        // Ensure a valid Firebase Auth session via anonymous sign-in if not signed in
        if (!auth.currentUser) {
          try {
            await signInAnonymously(auth);
          } catch (anonErr) {
            console.warn('Anonymous signin optional fallback:', anonErr);
          }
        }

        // Set global demo user context in authStore
        setUser({
          uid: auth.currentUser?.uid || 'demo_user_visitor',
          role: 'contractor',
          name: 'Demo Admin',
          email: 'demo@xyz.com',
          contractorId: 'trackify_demo',
        });
        useAuthStore.setState({ isDemo: true });
        switchContractor('trackify_demo', 'XYZ Construction');

        if (isMounted) {
          setStatusText('Demo environment activated! Entering dashboard...');
          setTimeout(() => {
            navigate('/dashboard', { replace: true });
          }, 350);
        }
      } catch (err) {
        console.error('DemoEntry error:', err);
        if (isMounted) {
          setError(err?.message || 'Failed to initialize demo session. Please try again.');
        }
      }
    }

    handleDemoLogin();

    return () => {
      isMounted = false;
    };
  }, [token, navigate, setUser, switchContractor]);

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
          Connecting to sandbox workspace: <span className="text-slate-200 font-mono">XYZ Construction</span>
        </p>
      </div>
    </div>
  );
}

