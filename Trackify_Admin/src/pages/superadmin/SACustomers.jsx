import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { Search, Building2, ChevronRight, Ban, RefreshCw, ArrowUpDown } from 'lucide-react';
import { getAllCustomers } from '../../lib/services/saas.service';

const PLAN_STYLES = {
  enterprise:   'bg-violet-500/10 text-violet-300 border-violet-500/20',
  professional: 'bg-amber-500/10 text-amber-400 border-amber-500/20',
  starter:      'bg-slate-500/10 text-slate-400 border-slate-500/20',
};
const STATUS_STYLES = {
  active:    'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
  trial:     'bg-blue-500/10 text-blue-400 border-blue-500/20',
  expired:   'bg-rose-500/10 text-rose-400 border-rose-500/20',
  suspended: 'bg-red-900/20 text-red-400 border-red-500/20',
};

export default function SACustomers() {
  const [allCustomers, setAllCustomers] = useState([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  useEffect(() => {
    getAllCustomers().then(data => {
      setAllCustomers(data);
      setLoadingCustomers(false);
    });
  }, []);

  const [q, setQ] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [filterPlan, setFilterPlan]     = useState('all');
  const [sortBy, setSortBy]             = useState('mrr');

  const list = useMemo(() => {
    let data = [...allCustomers];
    if (q)            data = data.filter(c => c.name.toLowerCase().includes(q.toLowerCase()) || c.owner.toLowerCase().includes(q.toLowerCase()) || c.city.toLowerCase().includes(q.toLowerCase()));
    if (filterStatus !== 'all') data = data.filter(c => c.status === filterStatus);
    if (filterPlan   !== 'all') data = data.filter(c => c.plan === filterPlan);
    data.sort((a, b) => sortBy === 'mrr' ? b.mrr - a.mrr : sortBy === 'labours' ? b.labours - a.labours : sortBy === 'sites' ? b.sites - a.sites : a.name.localeCompare(b.name));
    return data;
  }, [q, filterStatus, filterPlan, sortBy]);

  const totals = useMemo(() => ({
    active: allCustomers.filter(c=>c.status==='active').length,
    trial: allCustomers.filter(c=>c.status==='trial').length,
    expired: allCustomers.filter(c=>c.status==='expired').length,
    suspended: allCustomers.filter(c=>c.status==='suspended').length,
  }), []);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-text-primary flex items-center gap-2">
          <Building2 className="h-6 w-6 text-violet-400" /> Company Management
        </h2>
        <p className="text-[13px] text-text-muted mt-0.5">All Trackify contractor companies</p>
      </div>

      {/* Status summary pills */}
      <div className="flex flex-wrap gap-3">
        {[
          { key: 'all',       label: 'All',       count: allCustomers.length, color: 'border-white/10 text-text-secondary bg-bg-elevated' },
          { key: 'active',    label: 'Active',     count: totals.active,    color: 'border-emerald-500/30 text-emerald-400 bg-emerald-500/10' },
          { key: 'trial',     label: 'Trial',      count: totals.trial,     color: 'border-blue-500/30 text-blue-400 bg-blue-500/10' },
          { key: 'expired',   label: 'Expired',    count: totals.expired,   color: 'border-rose-500/30 text-rose-400 bg-rose-500/10' },
          { key: 'suspended', label: 'Suspended',  count: totals.suspended, color: 'border-red-500/30 text-red-400 bg-red-900/20' },
        ].map(s => (
          <button key={s.key} onClick={() => setFilterStatus(s.key)}
            className={`flex items-center gap-2 rounded-xl border px-4 py-2 text-[13px] font-medium transition-all ${s.color} ${filterStatus === s.key ? 'ring-2 ring-violet-500/30' : ''}`}>
            {s.label} <span className="font-mono font-bold">{s.count}</span>
          </button>
        ))}
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
          <input value={q} onChange={e => setQ(e.target.value)} placeholder="Search company, owner, city…"
            className="w-full h-10 rounded-xl border border-white/[0.06] bg-[#13102B] pl-9 pr-4 text-sm text-text-primary outline-none focus:border-violet-500/40 focus:ring-2 focus:ring-violet-500/10 placeholder:text-text-muted" />
        </div>
        <select value={filterPlan} onChange={e => setFilterPlan(e.target.value)}
          className="h-10 rounded-xl border border-white/[0.06] bg-[#13102B] px-3 text-sm text-text-primary outline-none focus:border-violet-500/40">
          <option value="all">All Plans</option>
          <option value="starter">Starter</option>
          <option value="professional">Professional</option>
          <option value="enterprise">Enterprise</option>
        </select>
        <select value={sortBy} onChange={e => setSortBy(e.target.value)}
          className="h-10 rounded-xl border border-white/[0.06] bg-[#13102B] px-3 text-sm text-text-primary outline-none focus:border-violet-500/40">
          <option value="mrr">Sort: Revenue</option>
          <option value="labours">Sort: Labours</option>
          <option value="sites">Sort: Sites</option>
          <option value="name">Sort: Name</option>
        </select>
      </div>

      {/* Table */}
      <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] overflow-hidden">
        <table className="w-full text-sm min-w-[700px]">
          <thead className="border-b border-white/[0.06]">
            <tr className="text-[10px] font-medium uppercase tracking-widest text-text-muted">
              {['Company', 'Owner', 'Plan', 'Status', 'MRR', 'Sites', 'Labours', 'City', ''].map(h => (
                <th key={h} className="px-5 py-3.5 text-left font-medium">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {list.map(c => (
              <tr key={c.id} className="border-b border-white/[0.04] hover:bg-violet-500/5 transition-colors group">
                <td className="px-5 py-3.5">
                  <div className="flex items-center gap-3">
                    <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-violet-500/10 border border-violet-500/20 text-[11px] font-bold text-violet-300 shrink-0">
                      {c.name.slice(0, 2).toUpperCase()}
                    </div>
                    <span className="font-medium text-text-primary text-[13px]">{c.name}</span>
                  </div>
                </td>
                <td className="px-5 py-3.5 text-[12px] text-text-secondary">{c.owner}</td>
                <td className="px-5 py-3.5">
                  <span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold border capitalize ${PLAN_STYLES[c.plan]}`}>{c.plan}</span>
                </td>
                <td className="px-5 py-3.5">
                  <span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold border capitalize ${STATUS_STYLES[c.status]}`}>{c.status}</span>
                </td>
                <td className="px-5 py-3.5 font-mono font-semibold text-violet-300">
                  {c.mrr > 0 ? `₹${c.mrr.toLocaleString()}` : <span className="text-text-muted">—</span>}
                </td>
                <td className="px-5 py-3.5 font-mono text-text-primary">{c.sites}</td>
                <td className="px-5 py-3.5 font-mono text-text-primary">{c.labours}</td>
                <td className="px-5 py-3.5 text-[12px] text-text-muted">{c.city}</td>
                <td className="px-5 py-3.5">
                  <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <Link to={`/sa/customers/${c.id}`}
                      className="flex items-center gap-1 px-2 py-1 rounded-lg text-[11px] font-medium text-violet-300 bg-violet-500/10 hover:bg-violet-500/20 border border-violet-500/20 transition-colors">
                      View <ChevronRight className="h-3 w-3" />
                    </Link>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {list.length === 0 && (
          <p className="py-12 text-center text-sm text-text-muted">No companies match your filters.</p>
        )}
      </div>
    </div>
  );
}
