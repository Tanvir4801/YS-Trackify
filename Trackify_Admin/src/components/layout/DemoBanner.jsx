import React, { useState, useEffect } from 'react';
import { ShieldAlert, Clock, ExternalLink, LogOut, Sparkles } from 'lucide-react';
import { signOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../../lib/firebase';
import { useAuthStore } from '../../store/authStore';
import { useDemoPermissions } from '../../hooks/useDemoPermissions';

export default function DemoBanner() {
  const { isDemo } = useDemoPermissions();
  const uid = useAuthStore((s) => s.uid);
  const clearUser = useAuthStore((s) => s.clearUser);
  const [timeLeft, setTimeLeft] = useState('24h 00m');

  useEffect(() => {
    if (!isDemo || !uid) return;

    let timer;
    const fetchSessionExpiry = async () => {
      try {
        const snap = await getDoc(doc(db, 'demoSessions', uid));
        if (snap.exists()) {
          const expiresAt = snap.data().expiresAt?.toDate?.();
          if (expiresAt) {
            const updateTimer = () => {
              const diff = expiresAt.getTime() - Date.now();
              if (diff <= 0) {
                setTimeLeft('Expired');
              } else {
                const hours = Math.floor(diff / (1000 * 60 * 60));
                const mins = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
                setTimeLeft(`${hours}h ${mins.toString().padStart(2, '0')}m`);
              }
            };
            updateTimer();
            timer = setInterval(updateTimer, 60000);
          }
        }
      } catch (e) {
        console.warn('Could not read demo session timer:', e);
      }
    };

    fetchSessionExpiry();
    return () => {
      if (timer) clearInterval(timer);
    };
  }, [isDemo, uid]);

  if (!isDemo) return null;

  const handleExitDemo = async () => {
    try {
      await signOut(auth);
      clearUser();
      window.location.href = '/login';
    } catch (e) {
      console.error('Error signing out of demo:', e);
    }
  };

  const handleContactSales = () => {
    const text = encodeURIComponent(
      'Hi Trackify team, I explored the Live Demo Dashboard and would like to discuss implementing Trackify for my construction firm.'
    );
    window.open(`https://wa.me/917621984915?text=${text}`, '_blank', 'noopener,noreferrer');
  };

  return (
    <div className="w-full bg-gradient-to-r from-[#0F1A2E] via-[#16233B] to-[#0F1A2E] border-b border-amber-500/30 px-4 py-2.5 text-xs text-slate-200 shadow-lg relative z-30">
      <div className="max-w-[1600px] mx-auto flex flex-wrap items-center justify-between gap-3">
        {/* Left: Indicator & Description */}
        <div className="flex items-center gap-3">
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-amber-500/20 border border-amber-500/40 text-amber-400 font-mono text-[11px] font-bold tracking-wide">
            <span className="w-2 h-2 rounded-full bg-amber-400 animate-pulse" />
            DEMO MODE · READ-ONLY
          </span>
          <p className="text-slate-300 text-xs hidden sm:inline">
            Exploring sample workforce operations for{' '}
            <strong className="text-amber-300 font-semibold">Trackify Demo Construction Pvt. Ltd.</strong>{' '}
            (All data modifications are disabled).
          </p>
        </div>

        {/* Right: Timer & Action Buttons */}
        <div className="flex items-center gap-3 ml-auto">
          <div className="flex items-center gap-1.5 text-slate-400 font-mono text-[11px] bg-white/[0.04] px-2.5 py-1 rounded-md border border-white/[0.08]">
            <Clock className="w-3.5 h-3.5 text-amber-400" />
            <span>Session: <span className="text-slate-200 font-bold">{timeLeft}</span></span>
          </div>

          <button
            onClick={handleContactSales}
            className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md bg-amber-500 hover:bg-amber-600 text-slate-950 font-semibold text-xs transition-colors shadow-sm"
          >
            <Sparkles className="w-3.5 h-3.5" />
            <span>Book Full Platform</span>
          </button>

          <button
            onClick={handleExitDemo}
            className="inline-flex items-center gap-1 px-2.5 py-1 rounded-md bg-white/[0.06] hover:bg-white/[0.1] text-slate-300 hover:text-white border border-white/[0.1] text-xs transition-colors"
            title="Exit Demo Mode"
          >
            <LogOut className="w-3.5 h-3.5" />
            <span>Exit</span>
          </button>
        </div>
      </div>
    </div>
  );
}

