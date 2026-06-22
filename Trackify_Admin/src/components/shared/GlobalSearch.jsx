import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getDocs, collection, query, where, limit, orderBy } from 'firebase/firestore';
import { Search, HardHat, Users, X } from 'lucide-react';
import { db } from '../../lib/firebase';
import { useScopeId } from '../../store/authStore';
import { formatCurrency } from '../../lib/utils';

function useDebounce(value, ms = 300) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), ms);
    return () => clearTimeout(t);
  }, [value, ms]);
  return debounced;
}

export default function GlobalSearch() {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState('');
  const [results, setResults] = useState({ labours: [], supervisors: [] });
  const [loading, setLoading] = useState(false);
  const inputRef = useRef(null);
  const navigate = useNavigate();
  const scopeId = useScopeId();
  const debouncedQ = useDebounce(q);

  useEffect(() => {
    const handleKey = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setOpen((o) => !o);
      }
      if (e.key === 'Escape') setOpen(false);
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, []);

  useEffect(() => {
    if (open) setTimeout(() => inputRef.current?.focus(), 50);
    else { setQ(''); setResults({ labours: [], supervisors: [] }); }
  }, [open]);

  const search = useCallback(async (term) => {
    if (!term || term.length < 2) {
      setResults({ labours: [], supervisors: [] });
      return;
    }
    setLoading(true);
    try {
      const upper = term.charAt(0).toUpperCase() + term.slice(1);

      const labourSnap = await getDocs(
        query(
          collection(db, 'labours'),
          where('isActive', '==', true),
          ...(scopeId ? [where('supervisorId', '==', scopeId)] : []),
          orderBy('name'),
          limit(20),
        ),
      );
      const labours = labourSnap.docs
        .map((d) => ({ id: d.id, ...d.data() }))
        .filter((l) =>
          l.name?.toLowerCase().includes(term.toLowerCase()) ||
          l.phone?.includes(term),
        )
        .slice(0, 6);

      const supSnap = await getDocs(
        query(
          collection(db, 'users'),
          where('role', '==', 'supervisor'),
          ...(scopeId ? [where('contractorId', '==', scopeId)] : []),
          orderBy('name'),
          limit(20),
        ),
      );
      const supervisors = supSnap.docs
        .map((d) => ({ id: d.id, ...d.data() }))
        .filter((s) => s.name?.toLowerCase().includes(term.toLowerCase()))
        .slice(0, 4);

      void upper;
      setResults({ labours, supervisors });
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }, [scopeId]);

  useEffect(() => {
    search(debouncedQ);
  }, [debouncedQ, search]);

  const go = (path) => {
    navigate(path);
    setOpen(false);
  };

  const total = results.labours.length + results.supervisors.length;

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="flex h-9 items-center gap-2 rounded-lg border border-slate-200 bg-white/80 px-3 text-sm text-slate-500 shadow-sm transition hover:border-blue-300 hover:text-slate-700"
      >
        <Search className="h-4 w-4" />
        <span>Search…</span>
        <kbd className="ml-1 rounded border border-slate-200 bg-slate-100 px-1.5 py-0.5 text-xs font-mono text-slate-400">
          ⌘K
        </kbd>
      </button>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center pt-24 px-4">
      <div className="absolute inset-0 bg-slate-950/40 backdrop-blur-sm" onClick={() => setOpen(false)} />
      <div className="relative w-full max-w-lg rounded-2xl border border-slate-200 bg-white shadow-2xl">
        <div className="flex items-center gap-3 border-b border-slate-100 px-4 py-3">
          <Search className="h-4 w-4 text-slate-400" />
          <input
            ref={inputRef}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search labours, supervisors…"
            className="flex-1 bg-transparent text-sm text-slate-900 placeholder:text-slate-400 outline-none"
          />
          {q && (
            <button onClick={() => setQ('')} className="text-slate-400 hover:text-slate-600">
              <X className="h-4 w-4" />
            </button>
          )}
          <kbd className="rounded border border-slate-200 bg-slate-100 px-1.5 py-0.5 text-xs font-mono text-slate-400">
            ESC
          </kbd>
        </div>

        <div className="max-h-80 overflow-y-auto py-2">
          {loading && (
            <div className="px-4 py-8 text-center text-sm text-slate-400">Searching…</div>
          )}
          {!loading && q.length >= 2 && total === 0 && (
            <div className="px-4 py-8 text-center text-sm text-slate-400">No results for "{q}"</div>
          )}
          {!loading && q.length < 2 && (
            <div className="px-4 py-8 text-center text-sm text-slate-400">Type at least 2 characters…</div>
          )}

          {results.labours.length > 0 && (
            <div>
              <p className="px-4 py-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400">
                Labours
              </p>
              {results.labours.map((l) => (
                <button
                  key={l.id}
                  onClick={() => go(`/labours/${l.id}`)}
                  className="flex w-full items-center gap-3 px-4 py-2.5 text-left hover:bg-slate-50"
                >
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-xs font-semibold text-blue-700">
                    {(l.name || '?')[0].toUpperCase()}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium text-slate-900">{l.name}</p>
                    <p className="text-xs text-slate-500">{l.phone || 'No phone'} · {formatCurrency(l.dailyWage)}/day</p>
                  </div>
                  <HardHat className="h-4 w-4 text-slate-300" />
                </button>
              ))}
            </div>
          )}

          {results.supervisors.length > 0 && (
            <div>
              <p className="px-4 py-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400">
                Supervisors
              </p>
              {results.supervisors.map((s) => (
                <button
                  key={s.id}
                  onClick={() => go(`/supervisors`)}
                  className="flex w-full items-center gap-3 px-4 py-2.5 text-left hover:bg-slate-50"
                >
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-purple-100 text-xs font-semibold text-purple-700">
                    {(s.name || '?')[0].toUpperCase()}
                  </div>
                  <div>
                    <p className="text-sm font-medium text-slate-900">{s.name}</p>
                    <p className="text-xs text-slate-500">{s.email}</p>
                  </div>
                  <Users className="h-4 w-4 text-slate-300" />
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
