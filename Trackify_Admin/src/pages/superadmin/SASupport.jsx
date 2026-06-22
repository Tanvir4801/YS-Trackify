import React, { useState, useEffect, useMemo } from 'react';
import { LifeBuoy, CheckCircle, Clock, AlertTriangle, ChevronDown } from 'lucide-react';
import { getSupportTickets } from '../../lib/services/saas.service';

const PRIORITY_STYLES = {
  critical: 'bg-rose-500/10 text-rose-400 border-rose-500/20',
  high:     'bg-amber-500/10 text-amber-400 border-amber-500/20',
  medium:   'bg-blue-500/10 text-blue-400 border-blue-500/20',
  low:      'bg-slate-500/10 text-slate-400 border-slate-500/20',
};
const STATUS_STYLES = {
  open:        'bg-rose-500/10 text-rose-400 border-rose-500/20',
  in_progress: 'bg-blue-500/10 text-blue-400 border-blue-500/20',
  resolved:    'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
};
const CAT_LABEL = { attendance: 'Attendance', payment: 'Payment', qr: 'QR Scanner', feature_request: 'Feature Request', billing: 'Billing', other: 'Other' };

export default function SASupport() {
  const [supportTickets, setSupportTickets] = useState([]);
  useEffect(() => {
    getSupportTickets().then(setSupportTickets);
  }, []);

  const [filterStatus, setFilterStatus] = useState('all');
  const [filterPriority, setFilterPriority] = useState('all');
  const [filterCat, setFilterCat] = useState('all');
  const [expanded, setExpanded] = useState(null);

  const filtered = useMemo(() => {
    let d = [...supportTickets];
    if (filterStatus !== 'all')   d = d.filter(t => t.status === filterStatus);
    if (filterPriority !== 'all') d = d.filter(t => t.priority === filterPriority);
    if (filterCat !== 'all')      d = d.filter(t => t.category === filterCat);
    return d;
  }, [filterStatus, filterPriority, filterCat]);

  const byStatus = {
    open:        supportTickets.filter(t => t.status === 'open').length,
    in_progress: supportTickets.filter(t => t.status === 'in_progress').length,
    resolved:    supportTickets.filter(t => t.status === 'resolved').length,
  };
  const byCat = Object.entries(
    supportTickets.reduce((acc, t) => { acc[t.category] = (acc[t.category] || 0) + 1; return acc; }, {})
  ).sort((a,b) => b[1]-a[1]);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-text-primary flex items-center gap-2">
          <LifeBuoy className="h-6 w-6 text-violet-400" /> Support Center
        </h2>
        <p className="text-[13px] text-text-muted mt-0.5">All support tickets from contractors</p>
      </div>

      {/* Status summary */}
      <div className="grid gap-4 sm:grid-cols-3">
        {[
          { key: 'open',        label: 'Open Tickets',     count: byStatus.open,        icon: AlertTriangle, color: '#EF4444' },
          { key: 'in_progress', label: 'In Progress',      count: byStatus.in_progress, icon: Clock,         color: '#3B82F6' },
          { key: 'resolved',    label: 'Resolved',         count: byStatus.resolved,    icon: CheckCircle,   color: '#10B981' },
        ].map(s => (
          <button key={s.key} onClick={() => setFilterStatus(filterStatus === s.key ? 'all' : s.key)}
            className={`relative overflow-hidden rounded-2xl border p-5 text-left transition-all ${filterStatus === s.key ? 'ring-2 ring-violet-500/30' : ''}`}
            style={{ borderColor: `${s.color}30`, background: `${s.color}08` }}>
            <div className="absolute top-0 right-0 h-16 w-16 rounded-full blur-2xl opacity-30" style={{ background: s.color }} />
            <s.icon className="h-5 w-5 mb-3" style={{ color: s.color }} />
            <p className="text-[11px] font-medium uppercase tracking-widest text-text-muted">{s.label}</p>
            <p className="text-3xl font-mono font-bold text-text-primary mt-1">{s.count}</p>
          </button>
        ))}
      </div>

      {/* Category breakdown */}
      <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] p-5">
        <p className="text-sm font-semibold text-text-primary mb-4">Tickets by Category</p>
        <div className="flex flex-wrap gap-3">
          {byCat.map(([cat, count]) => (
            <button key={cat} onClick={() => setFilterCat(filterCat === cat ? 'all' : cat)}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl border text-[13px] font-medium transition-all ${filterCat === cat ? 'bg-violet-500/20 text-violet-300 border-violet-500/30' : 'border-white/[0.06] text-text-secondary hover:text-text-primary hover:bg-bg-elevated'}`}>
              {CAT_LABEL[cat] || cat}
              <span className="font-mono font-bold text-[12px]">{count}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <select value={filterPriority} onChange={e => setFilterPriority(e.target.value)}
          className="h-10 rounded-xl border border-white/[0.06] bg-[#13102B] px-3 text-sm text-text-primary outline-none focus:border-violet-500/40">
          <option value="all">All Priorities</option>
          <option value="critical">Critical</option>
          <option value="high">High</option>
          <option value="medium">Medium</option>
          <option value="low">Low</option>
        </select>
        <p className="flex items-center text-[12px] text-text-muted ml-auto">{filtered.length} ticket{filtered.length !== 1 ? 's' : ''}</p>
      </div>

      {/* Ticket list */}
      <div className="space-y-3">
        {filtered.map(t => (
          <div key={t.id} className="rounded-2xl border border-white/[0.06] bg-[#13102B] overflow-hidden transition-all hover:border-violet-500/20">
            <button className="w-full flex items-start gap-4 px-5 py-4 text-left" onClick={() => setExpanded(expanded === t.id ? null : t.id)}>
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-violet-500/10 border border-violet-500/20 text-[10px] font-bold text-violet-300 mt-0.5">
                {t.contractorName.slice(0,2).toUpperCase()}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex flex-wrap items-center gap-2 mb-1">
                  <span className="text-[13px] font-semibold text-text-primary">{t.contractorName}</span>
                  <span className="text-[11px] text-text-muted">·</span>
                  <span className="text-[11px] text-text-muted">{CAT_LABEL[t.category]}</span>
                  <span className="text-[11px] text-text-muted">·</span>
                  <span className="text-[11px] text-text-muted">{t.createdAt}</span>
                </div>
                <p className="text-[13px] text-text-secondary truncate">{t.issue}</p>
              </div>
              <div className="flex items-center gap-2 shrink-0 ml-2">
                <span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold border ${PRIORITY_STYLES[t.priority]}`}>{t.priority}</span>
                <span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold border capitalize ${STATUS_STYLES[t.status]}`}>{t.status.replace('_',' ')}</span>
                <ChevronDown className={`h-4 w-4 text-text-muted transition-transform ${expanded === t.id ? 'rotate-180' : ''}`} />
              </div>
            </button>
            {expanded === t.id && (
              <div className="border-t border-white/[0.06] px-5 py-4">
                <p className="text-[13px] text-text-secondary mb-4">{t.issue}</p>
                <div className="flex gap-3">
                  <button className="px-4 py-2 rounded-xl bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-[12px] font-semibold hover:bg-emerald-500/20 transition-colors">
                    Mark Resolved
                  </button>
                  <button className="px-4 py-2 rounded-xl bg-blue-500/10 text-blue-400 border border-blue-500/20 text-[12px] font-semibold hover:bg-blue-500/20 transition-colors">
                    Set In Progress
                  </button>
                  <button className="px-4 py-2 rounded-xl bg-rose-500/10 text-rose-400 border border-rose-500/20 text-[12px] font-semibold hover:bg-rose-500/20 transition-colors">
                    Escalate
                  </button>
                </div>
              </div>
            )}
          </div>
        ))}
        {filtered.length === 0 && (
          <p className="py-12 text-center text-sm text-text-muted">No tickets match your filters.</p>
        )}
      </div>
    </div>
  );
}
