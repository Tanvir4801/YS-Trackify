import React, { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { Lock, Mail, ShieldCheck, Sparkles } from 'lucide-react';
import toast from 'react-hot-toast';
import { auth } from '../lib/firebase';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';

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
    <div className="relative min-h-screen overflow-hidden bg-[radial-gradient(circle_at_top_left,_rgba(37,99,235,0.14),_transparent_34%),radial-gradient(circle_at_top_right,_rgba(124,58,237,0.16),_transparent_28%),linear-gradient(180deg,#f8fafc_0%,#eef2ff_100%)] px-4 py-8 sm:px-6 lg:px-8">
      <div className="absolute inset-0 bg-[linear-gradient(135deg,rgba(255,255,255,0.35),transparent_35%,rgba(255,255,255,0.12))]" />
      <div className="relative mx-auto grid min-h-[calc(100vh-4rem)] max-w-6xl items-center gap-8 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="hidden lg:block">
          <div className="max-w-xl space-y-6 text-slate-900">
            <div className="inline-flex items-center gap-2 rounded-full border border-white/60 bg-white/70 px-4 py-2 text-sm font-medium text-slate-700 shadow-sm backdrop-blur">
              <Sparkles className="h-4 w-4 text-blue-600" />
              Premium labour operations dashboard
            </div>
            <div>
              <h1 className="text-5xl font-semibold tracking-tight text-slate-950 sm:text-6xl">
                Trackify Admin
              </h1>
              <p className="mt-4 max-w-lg text-lg leading-8 text-slate-600">
                Manage attendance, payroll, and workforce activity with a calm,
                high-trust interface that stays readable in every state.
              </p>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              {[
                'Real-time attendance with role-based access',
                'Soft glass panels with strong contrast',
                'Designed for fast daily admin workflows',
                'Powered by Firebase Auth + Firestore',
              ].map((item) => (
                <div
                  key={item}
                  className="flex items-start gap-3 rounded-2xl border border-white/60 bg-white/70 p-4 shadow-sm backdrop-blur"
                >
                  <ShieldCheck className="mt-0.5 h-5 w-5 text-emerald-600" />
                  <p className="text-sm leading-6 text-slate-700">{item}</p>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="mx-auto w-full max-w-md">
          <div className="overflow-hidden rounded-2xl border border-white/60 bg-white/80 shadow-xl backdrop-blur">
            <div className="border-b border-slate-200/70 bg-white/80 px-8 py-6">
              <p className="text-xs font-semibold uppercase tracking-[0.24em] text-blue-600">
                Secure access
              </p>
              <h2 className="mt-2 text-3xl font-semibold tracking-tight text-slate-950">
                Sign in to Trackify
              </h2>
              <p className="mt-2 text-sm leading-6 text-slate-500">
                Use the credentials issued by your administrator.
              </p>
            </div>

            <div className="space-y-6 px-8 py-8">
              <form className="space-y-5" onSubmit={handleLogin}>
                <div className="space-y-2 text-left">
                  <label className="text-sm font-medium text-slate-700">Email</label>
                  <div className="relative">
                    <Mail className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                    <Input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="h-12 pl-10"
                      placeholder="admin@trackify.app"
                      autoComplete="email"
                      required
                    />
                  </div>
                </div>
                <div className="space-y-2 text-left">
                  <label className="text-sm font-medium text-slate-700">Password</label>
                  <div className="relative">
                    <Lock className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                    <Input
                      type="password"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="h-12 pl-10"
                      placeholder="Enter your password"
                      autoComplete="current-password"
                      required
                    />
                  </div>
                </div>
                <Button
                  type="submit"
                  disabled={loading}
                  className="h-12 w-full rounded-xl bg-gradient-to-r from-blue-600 via-indigo-600 to-violet-600 text-base font-semibold text-white shadow-lg shadow-blue-600/20 transition hover:opacity-95"
                >
                  {loading ? 'Signing in…' : 'Sign in'}
                </Button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;
