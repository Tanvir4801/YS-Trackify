import React, { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { Lock, Mail, HardHat, Users, TrendingUp, Shield } from 'lucide-react';
import toast from 'react-hot-toast';
import { auth } from '../lib/firebase';
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

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email.trim(), password);
      toast.success('Welcome back');
    } catch (err) {
      console.error(err);
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

  return (
    <div className="min-h-screen flex" style={{ background: '#F8FAFC' }}>
      {/* Left panel */}
      <div
        className="hidden lg:flex lg:w-[55%] flex-col justify-between p-12 relative overflow-hidden"
        style={{ background: 'linear-gradient(135deg, #0B1020 0%, #0d1a3a 50%, #0f2051 100%)' }}
      >
        {/* Subtle grid */}
        <div className="absolute inset-0 opacity-[0.04]" style={{
          backgroundImage: 'linear-gradient(rgba(255,255,255,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.5) 1px, transparent 1px)',
          backgroundSize: '40px 40px'
        }} />

        {/* Glow */}
        <div className="absolute top-0 left-0 w-96 h-96 rounded-full opacity-10" style={{ background: 'radial-gradient(circle, #2563EB 0%, transparent 70%)' }} />
        <div className="absolute bottom-0 right-0 w-80 h-80 rounded-full opacity-8" style={{ background: 'radial-gradient(circle, #7c3aed 0%, transparent 70%)' }} />

        <div className="relative z-10">
          <div className="flex items-center gap-3 mb-12">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-600 shadow-lg shadow-blue-600/40">
              <span className="text-white font-bold text-sm">T</span>
            </div>
            <div>
              <p className="text-white font-bold text-sm tracking-widest uppercase">TRACKIFY</p>
              <p className="text-slate-500 text-xs">Workforce Management</p>
            </div>
          </div>

          <h1 className="text-4xl font-bold text-white leading-tight mb-4">
            Manage your entire<br />
            <span className="text-blue-400">workforce</span> from one place
          </h1>
          <p className="text-slate-400 text-base leading-relaxed max-w-md">
            Track attendance, calculate payroll, and manage labours across all your construction sites — in real time.
          </p>
        </div>

        <div className="relative z-10 grid grid-cols-2 gap-4">
          {features.map((f) => (
            <div
              key={f.label}
              className="rounded-2xl p-4"
              style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)' }}
            >
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600/20 mb-3">
                <f.icon className="h-4 w-4 text-blue-400" />
              </div>
              <p className="text-white text-sm font-semibold leading-tight">{f.label}</p>
              <p className="text-slate-500 text-xs mt-1">{f.desc}</p>
            </div>
          ))}
        </div>

        <div className="relative z-10 mt-8">
          <p className="text-slate-600 text-xs text-center">Developed by Tanvir Patel</p>
        </div>
      </div>

      {/* Right panel — login form */}
      <div className="flex flex-1 flex-col items-center justify-center px-6 py-12 lg:px-12">
        <div className="w-full max-w-md">
          {/* Mobile logo */}
          <div className="lg:hidden flex items-center gap-2 mb-8">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-blue-600">
              <span className="text-white font-bold text-sm">T</span>
            </div>
            <span className="text-slate-900 font-bold text-lg">Trackify</span>
          </div>

          <div className="mb-8">
            <h2 className="text-2xl font-bold text-slate-900">Sign in to your account</h2>
            <p className="mt-2 text-sm text-slate-500">Use the credentials issued by your administrator.</p>
          </div>

          <form onSubmit={handleLogin} className="space-y-5">
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1.5">Email address</label>
              <div className="relative">
                <Mail className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                <Input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="h-11 pl-10 rounded-xl border-slate-200 bg-white text-slate-900 focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
                  placeholder="admin@company.com"
                  autoComplete="email"
                  required
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1.5">Password</label>
              <div className="relative">
                <Lock className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                <Input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="h-11 pl-10 rounded-xl border-slate-200 bg-white text-slate-900 focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
                  placeholder="Enter your password"
                  autoComplete="current-password"
                  required
                />
              </div>
            </div>

            <Button
              type="submit"
              disabled={loading}
              className="h-11 w-full rounded-xl text-sm font-semibold text-white shadow-lg shadow-blue-600/25 transition"
              style={{ background: loading ? '#93c5fd' : 'linear-gradient(135deg, #2563EB 0%, #1D4ED8 100%)' }}
            >
              {loading ? 'Signing in…' : 'Sign in'}
            </Button>
          </form>

          <p className="mt-8 text-center text-xs text-slate-400">
            Trackify Admin · Developed by Tanvir Patel
          </p>
        </div>
      </div>
    </div>
  );
};

export default Login;
