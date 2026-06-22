import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ArrowLeft, Phone, MapPin, Crown, Calendar, Building2, HardHat, IndianRupee, LifeBuoy, Activity } from 'lucide-react';
import { getAllCustomers, getRevenueTransactions, getSupportTickets } from '../../lib/services/saas.service';

const PLAN_STYLES = {
  enterprise:   'bg-violet-500/15 text-violet-200 border-violet-500/30',
  professional: 'bg-amber-500/15 text-amber-300 border-amber-500/30',
  starter:      'bg-slate-500/15 text-slate-300 border-slate-500/30',
};
const STATUS_STYLES = {
  active:    'text-emerald-400', trial: 'text-blue-400', expired: 'text-rose-400', suspended: 'text-red-400',
};

export default function SACustomerProfile() {
  const [revenueTransactions, setRevenueTransactions] = useState([]);
  const [supportTickets, setSupportTickets] = useState([]);
  useEffect(() => {
    getRevenueTransactions().then(setRevenueTransactions);
    getSupportTickets().then(setSupportTickets);
  }, []);

  const [allCustomers, setAllCustomers] = useState([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  useEffect(() => {
    getAllCustomers().then(data => {
      setAllCustomers(data);
      setLoadingCustomers(false);
    });
  }, []);

  const { id } = useParams();
  const c = allCustomers.find(x => x.id === id) || allCustomers[0];
  const txns     = revenueTransactions.filter(t => t.contractorId === c.id);
  const tickets  = supportTickets.filter(t => t.contractorId === c.id);
  const totalPaid = txns.filter(t=>t.status==='paid').reduce((s,t)=>s+t.amount,0);

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Link to="/sa/customers" className="flex items-center gap-2 px-3 py-2 rounded-xl border border-white/[0.06] text-text-secondary hover:text-text-primary hover:bg-bg-elevated text-sm transition-all">
          <ArrowLeft className="h-4 w-4" /> Back
        </Link>
        <div>
          <h2 className="text-2xl font-bold text-text-primary">{c.name}</h2>
          <p className="text-[13px] text-text-muted">Customer profile · {c.city}</p>
        </div>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        {/* Profile card */}
        <div className="relative overflow-hidden rounded-2xl border border-white/[0.06] bg-gradient-to-br from-violet-950/40 via-[#13102B] to-[#13102B] p-5">
          <div className="absolute top-0 right-0 h-32 w-32 rounded-full bg-violet-500/10 blur-3xl" />
          <div className="relative">
            <div className="flex items-center gap-4 mb-5">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-tr from-violet-600 to-purple-400 text-xl font-bold text-white shadow-[0_0_20px_rgba(139,92,246,0.4)]">
                {c.name.slice(0,2).toUpperCase()}
              </div>
              <div>
                <p className="font-bold text-text-primary text-lg leading-tight">{c.name}</p>
                <p className="text-[12px] text-text-muted flex items-center gap-1"><MapPin className="h-3 w-3" />{c.city}</p>
              </div>
            </div>
            <div className="space-y-3 text-[13px]">
              {[
                { icon: Crown, label: 'Plan', value: <span className={`px-2 py-0.5 rounded-full text-[11px] font-bold border capitalize ${PLAN_STYLES[c.plan]}`}>{c.plan}</span> },
                { icon: Activity, label: 'Status', value: <span className={`font-semibold capitalize ${STATUS_STYLES[c.status]}`}>{c.status}</span> },
                { icon: Phone, label: 'Owner', value: c.owner },
                { icon: Calendar, label: 'Joined', value: c.joined },
                { icon: IndianRupee, label: 'MRR', value: c.mrr > 0 ? `₹${c.mrr.toLocaleString()}/mo` : '—' },
              ].map(row => (
                <div key={row.label} className="flex items-center justify-between">
                  <span className="flex items-center gap-2 text-text-muted"><row.icon className="h-3.5 w-3.5"/>{row.label}</span>
                  <span className="text-text-primary">{row.value}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Stats */}
        <div className="lg:col-span-2 grid gap-3 grid-cols-2 sm:grid-cols-3">
          {[
            { label: 'Total Sites', value: c.sites, icon: Building2, color: '#8B5CF6' },
            { label: 'Total Labours', value: c.labours, icon: HardHat, color: '#F5A623' },
            { label: 'Total Revenue', value: `₹${totalPaid.toLocaleString()}`, icon: IndianRupee, color: '#10B981' },
            { label: 'Transactions', value: txns.length, icon: Activity, color: '#3B82F6' },
            { label: 'Support Tickets', value: tickets.length, icon: LifeBuoy, color: '#EF4444' },
            { label: 'Open Tickets', value: tickets.filter(t=>t.status!=='resolved').length, icon: LifeBuoy, color: '#F59E0B' },
          ].map(stat => (
            <div key={stat.label} className="relative overflow-hidden rounded-xl border border-white/[0.06] bg-[#13102B] p-4">
              <div className="absolute bottom-0 left-0 h-0.5 w-full" style={{ background: stat.color }} />
              <div className="flex h-7 w-7 items-center justify-center rounded-lg mb-3" style={{ background: `${stat.color}15` }}>
                <stat.icon className="h-3.5 w-3.5" style={{ color: stat.color }} />
              </div>
              <p className="text-[10px] font-medium uppercase tracking-widest text-text-muted">{stat.label}</p>
              <p className="mt-1 text-xl font-mono font-bold text-text-primary">{stat.value}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Transaction history */}
      {txns.length > 0 && (
        <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] overflow-hidden">
          <div className="flex items-center gap-2 border-b border-white/[0.06] px-5 py-4">
            <IndianRupee className="h-4 w-4 text-violet-400" />
            <p className="text-sm font-semibold text-text-primary">Payment History</p>
          </div>
          <table className="w-full text-sm">
            <thead><tr className="border-b border-white/[0.06] text-[10px] font-medium uppercase tracking-widest text-text-muted">
              {['Date', 'Type', 'Amount', 'GST', 'Status', 'Invoice'].map(h => <th key={h} className="px-5 py-3 text-left">{h}</th>)}
            </tr></thead>
            <tbody>
              {txns.map(t => (
                <tr key={t.id} className="border-b border-white/[0.04] hover:bg-violet-500/5">
                  <td className="px-5 py-3 font-mono text-[12px] text-text-muted">{t.date}</td>
                  <td className="px-5 py-3 capitalize text-text-secondary text-[12px]">{t.type.replace('_',' ')}</td>
                  <td className="px-5 py-3 font-mono font-semibold text-text-primary">₹{t.amount.toLocaleString()}</td>
                  <td className="px-5 py-3 font-mono text-[12px] text-text-muted">₹{t.gst}</td>
                  <td className="px-5 py-3"><span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold border ${t.status==='paid'?'bg-emerald-500/10 text-emerald-400 border-emerald-500/20':t.status==='pending'?'bg-amber-500/10 text-amber-400 border-amber-500/20':'bg-rose-500/10 text-rose-400 border-rose-500/20'}`}>{t.status}</span></td>
                  <td className="px-5 py-3 font-mono text-[11px] text-text-muted">{t.invoiceNo}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Support Tickets */}
      {tickets.length > 0 && (
        <div className="rounded-2xl border border-white/[0.06] bg-[#13102B] overflow-hidden">
          <div className="flex items-center gap-2 border-b border-white/[0.06] px-5 py-4">
            <LifeBuoy className="h-4 w-4 text-violet-400" />
            <p className="text-sm font-semibold text-text-primary">Support Tickets</p>
          </div>
          <div className="divide-y divide-white/[0.04]">
            {tickets.map(t => (
              <div key={t.id} className="px-5 py-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="text-[13px] text-text-primary font-medium">{t.issue}</p>
                    <p className="text-[11px] text-text-muted mt-1 capitalize">{t.category.replace('_',' ')} · {t.createdAt}</p>
                  </div>
                  <div className="flex gap-2 shrink-0">
                    <span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold border ${t.priority==='critical'?'bg-rose-500/10 text-rose-400 border-rose-500/20':t.priority==='high'?'bg-amber-500/10 text-amber-400 border-amber-500/20':'bg-slate-500/10 text-slate-400 border-slate-500/20'}`}>{t.priority}</span>
                    <span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold border capitalize ${t.status==='resolved'?'bg-emerald-500/10 text-emerald-400 border-emerald-500/20':t.status==='in_progress'?'bg-blue-500/10 text-blue-400 border-blue-500/20':'bg-slate-500/10 text-slate-300 border-slate-500/20'}`}>{t.status.replace('_',' ')}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
