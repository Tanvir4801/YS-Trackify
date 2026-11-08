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
  const [error, setError] = useState(null);

  const setUser = useAuthStore((s) => s.setUser);
  const switchContractor = useAuthStore((s) => s.switchContractor);

  useEffect(() => {
    try {
      // 1. Immediately store demo mode keys for zero-latency instant access
      sessionStorage.setItem('trackify_demo_mode', 'true');
      sessionStorage.setItem(
        'trackify_demo_expires_at',
        String(Date.now() + 24 * 60 * 60 * 1000)
      );
      sessionStorage.setItem('trackify_demo_company', 'XYZ Construction');

      // 2. Set global demo state immediately (instant rendering)
      setUser({
        uid: auth.currentUser?.uid || 'demo_user_visitor',
        role: 'contractor',
        name: 'Demo Admin',
        email: 'demo@xyz.com',
        contractorId: 'trackify_demo',
      });
      useAuthStore.setState({ isDemo: true, isLoading: false });
      switchContractor('trackify_demo', 'XYZ Construction');

      // 3. Background non-blocking authentication
      if (token) {
        signInWithCustomToken(auth, token).catch((e) =>
          console.warn('Custom token fallback:', e)
        );
      } else if (!auth.currentUser) {
        signInAnonymously(auth).catch((e) =>
          console.warn('Anonymous fallback:', e)
        );
      }

      // 4. Instantly enter the dashboard without artificial delay
      navigate('/dashboard', { replace: true });
    } catch (err) {
      console.error('DemoEntry error:', err);
      setError(err?.message || 'Failed to initialize demo session. Please try again.');
    }
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
        <p className="text-xs font-mono text-amber-400/90">Entering sandbox workspace...</p>
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

