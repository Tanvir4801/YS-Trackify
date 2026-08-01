import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { signInWithEmailAndPassword, sendPasswordResetEmail } from 'firebase/auth';
import { Lock, Mail, HardHat, Users, TrendingUp, Shield, Compass } from 'lucide-react';
import toast from 'react-hot-toast';
import { auth, db } from '../lib/firebase';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';

const features = [
  { icon: Users,      label: 'Real-time attendance tracking',    desc: 'Monitor workforce presence instantly' },
  { icon: TrendingUp, label: 'Payroll & payments',               desc: 'Calculate and disburse salaries easily' },
  { icon: HardHat,    label: 'Labour management',                desc: 'Manage your entire workforce in one place' },
  { icon: Shield,     label: 'Role-based access control',        desc: 'Secure multi-level permissions' },
];

const Login = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email.trim(), password);
      toast.success('Welcome back');
      navigate('/');
    } catch (err) {
      console.error(err);
      try {
        await addDoc(collection(db, 'security_events'), {
          type: 'failed_login',
          email: email.trim().toLowerCase(),
          timestamp: serverTimestamp(),
          reason: err?.message || 'Login failed',
          platform: 'web_admin'
        });
      } catch (logErr) {}

      const msg =
        err?.code === 'auth/invalid-credential' || err?.code === 'auth/wrong-password'
          ? 'Invalid email or password'
          : err?.code === 'auth/user-not-found'
          ? 'No account with that email'
          : 'Sign in failed. Please try again.';
      toast.error(msg);
    } finally {
      setLoading(false);
    }
  };

  const handleForgotPassword = async () => {
    if (!email.trim()) {
      toast.error('Please enter your email address first to reset password');
      return;
    }
    setLoading(true);
    try {
      await sendPasswordResetEmail(auth, email.trim());
      toast.success('Password reset email sent! Check your inbox.');
    } catch (err) {
      console.error(err);
      toast.error('Failed to send reset email. Ensure your email is correct.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex bg-bg-primary">
      {/* Left panel */}
      <div
        className="hidden lg:flex lg:w-[55%] flex-col justify-between p-12 relative overflow-hidden"
        style={{ background: 'linear-gradient(135deg, #0A0E1A 0%, #111827 50%, #0A0E1A 100%)' }}
      >
        {/* Subtle grid */}
        <div className="absolute inset-0 opacity-[0.04]" style={{
          backgroundImage: 'linear-gradient(rgba(255,255,255,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.5) 1px, transparent 1px)',
          backgroundSize: '40px 40px'
        }} />

        {/* Glow */}
        <div className="absolute top-0 left-0 w-96 h-96 rounded-full opacity-10" style={{ background: 'radial-gradient(circle, var(--gold) 0%, transparent 70%)' }} />
        <div className="absolute bottom-0 right-0 w-80 h-80 rounded-full opacity-10" style={{ background: 'radial-gradient(circle, var(--gold) 0%, transparent 70%)' }} />

        <div className="relative z-10">
          <div className="flex items-center gap-3 mb-12">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br from-bg-secondary to-bg-card border border-gold/40 shadow-[0_4px_16px_rgba(245,166,35,0.15)]">
              <Compass className="h-6 w-6 text-gold" />
            </div>
            <div>
              <p className="text-gold font-bold text-[14px] tracking-[0.2em] uppercase">TRACKIFY</p>
              <p className="text-text-muted text-[10px] tracking-widest uppercase mt-0.5">Civil Engineering Console</p>
            </div>
          </div>

          <h1 className="text-4xl font-bold text-white leading-tight mb-4">
            Manage your entire<br />
            <span className="text-gold">workforce</span> from one place
          </h1>
          <p className="text-text-secondary text-base leading-relaxed max-w-md">
            Track attendance, calculate payroll, and manage labours across all your construction sites — in real time.
          </p>
        </div>

        <div className="relative z-10 grid grid-cols-2 gap-4">
          {features.map((f) => (
            <div
              key={f.label}
              className="rounded-2xl p-4 bg-bg-card/50 border border-border-strong backdrop-blur-sm"
            >
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gold/10 mb-3 border border-gold/20">
                <f.icon className="h-4 w-4 text-gold" />
              </div>
              <p className="text-text-primary text-[13px] font-semibold leading-tight">{f.label}</p>
              <p className="text-text-muted text-[11px] mt-1.5">{f.desc}</p>
            </div>
          ))}
        </div>

        <div className="relative z-10 mt-8">
          <p className="text-text-muted text-[10px] tracking-widest uppercase text-center font-medium">Developed by Tanvir Patel</p>
        </div>
      </div>

      {/* Right panel — login form */}
      <div className="flex flex-1 flex-col items-center justify-center px-6 py-12 lg:px-12 bg-bg-primary">
        <div className="w-full max-w-md">
          {/* Mobile logo */}
          <div className="lg:hidden flex items-center gap-2 mb-8">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-bg-secondary to-bg-card border border-gold/40 shadow-[0_4px_16px_rgba(245,166,35,0.15)]">
              <Compass className="h-5 w-5 text-gold" />
            </div>
            <span className="text-gold font-bold text-lg tracking-widest uppercase">Trackify</span>
          </div>

          <div className="mb-8">
            <h2 className="text-2xl font-bold text-text-primary tracking-tight">Sign in to Console</h2>
            <p className="mt-2 text-[13px] text-text-muted">Use the credentials issued by your administrator.</p>
          </div>

          <form onSubmit={handleLogin} className="space-y-5">
            <div>
              <label className="block text-[11px] font-medium uppercase tracking-widest text-text-muted mb-1.5">Email address</label>
              <div className="relative">
                <Mail className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
                <Input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="h-11 pl-10 rounded-xl bg-bg-input border-border-strong text-text-primary focus:border-gold focus:ring-1 focus:ring-gold"
                  placeholder="admin@company.com"
                  autoComplete="email"
                  required
                />
              </div>
            </div>

            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="block text-[11px] font-medium uppercase tracking-widest text-text-muted">Password</label>
                <button type="button" onClick={handleForgotPassword} className="text-[11px] font-medium text-gold hover:underline">Forgot password?</button>
              </div>
              <div className="relative">
                <Lock className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
                <Input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="h-11 pl-10 rounded-xl bg-bg-input border-border-strong text-text-primary focus:border-gold focus:ring-1 focus:ring-gold"
                  placeholder="Enter your password"
                  autoComplete="current-password"
                  required
                />
              </div>
            </div>

            <Button
              type="submit"
              disabled={loading}
              className={`h-11 w-full rounded-xl text-[14px] font-bold transition-all ${loading ? 'bg-bg-elevated text-text-muted cursor-not-allowed' : 'bg-gold text-bg-primary hover:bg-gold-hover hover:scale-[1.02] shadow-[0_0_15px_rgba(245,166,35,0.2)]'}`}
            >
              {loading ? 'Signing in…' : 'Sign in to Console'}
            </Button>
          </form>

          <p className="mt-8 text-center text-[10px] tracking-widest uppercase font-medium text-text-muted">
            Trackify Console · Developed by Tanvir Patel
          </p>
        </div>
      </div>
    </div>
  );
};

export default Login;
