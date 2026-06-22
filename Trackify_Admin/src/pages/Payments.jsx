import React, { useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Plus, Wallet, Filter, Download } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { usePayments } from '../hooks/usePayments';
import { useLabours } from '../hooks/useLabours';
import { addPayment } from '../lib/services/payments.service';
import { formatCurrency, todayKey, toDateKeySafe, exportExcel } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import StatusBadge from '../components/shared/StatusBadge';
import Modal from '../components/ui/Modal';
import Pagination, { usePagination } from '../components/shared/Pagination';

const TYPE_OPTIONS = [
  { value: 'salary', label: 'Salary' },
  { value: 'advance', label: 'Advance' },
  { value: 'overtime_bonus', label: 'OT Bonus' },
];

const METHOD_OPTIONS = [
  { value: 'cash', label: 'Cash' },
  { value: 'bank', label: 'Bank Transfer' },
  { value: 'upi', label: 'UPI' },
];

const METHOD_BADGE = {
  cash: 'bg-success-bg border border-success/30 text-success',
  bank: 'bg-info-bg border border-info/30 text-info',
  upi: 'bg-gold-bg border border-gold/30 text-gold',
};

const EMPTY_FORM = {
  labourId: '',
  amount: '',
  date: todayKey(),
  type: 'salary',
  paymentMethod: 'cash',
  notes: '',
};

export default function Payments() {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeFromStore = useScopeId();
  const writeScope = role === 'supervisor' ? uid : scopeFromStore;
  const queryClient = useQueryClient();

  const [filters, setFilters] = useState({ type: 'all', labourId: 'all', startDate: '', endDate: '' });
  const [pageSize, setPageSize] = useState(25);

  const queryOptions = useMemo(() => {
    const opts = {};
    if (filters.type !== 'all') opts.type = filters.type;
    if (filters.labourId !== 'all') opts.labourId = filters.labourId;
    if (filters.startDate) opts.startDate = filters.startDate;
    if (filters.endDate) opts.endDate = filters.endDate;
    return opts;
  }, [filters]);

  const { data: payments = [], isLoading } = usePayments(queryOptions);
  const { data: labours = [] } = useLabours();

  const labourMap = useMemo(() => {
    const map = new Map();
    labours.forEach((l) => map.set(l.id, l));
    return map;
  }, [labours]);

  const totals = useMemo(() => {
    const t = { total: 0, salary: 0, advance: 0, ot: 0 };
    payments.forEach((p) => {
      const amt = Number(p.amount) || 0;
      t.total += amt;
      if (p.type === 'salary') t.salary += amt;
      else if (p.type === 'advance') t.advance += amt;
      else if (p.type === 'overtime_bonus') t.ot += amt;
    });
    return t;
  }, [payments]);

  const { page, pageCount, paginated, setPage, total } = usePagination(payments, pageSize);

  const [dialogOpen, setDialogOpen] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);

  const openAdd = () => { setForm(EMPTY_FORM); setDialogOpen(true); };
  const closeDialog = () => { if (saving) return; setDialogOpen(false); };
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['payments'] });

  const handleSubmit = async () => {
    if (!form.labourId) return toast.error('Pick a labour');
    if (!form.amount || Number(form.amount) <= 0) return toast.error('Enter a valid amount');
    if (!form.date) return toast.error('Date is required');
    if (!writeScope) return toast.error('Pick a contractor in the header before recording');
    setSaving(true);
    const t = toast.loading('Recording payment…');
    try {
      await addPayment({
        scopeId: writeScope,
        supervisorId: writeScope,
        contractorId: scopeFromStore,
        labourId: form.labourId,
        amount: form.amount,
        date: form.date,
        type: form.type,
        paymentMethod: form.paymentMethod,
        notes: form.notes.trim() || '',
      });
      toast.dismiss(t);
      toast.success('Payment recorded');
      invalidate();
      setDialogOpen(false);
    } catch (err) {
      console.error(err);
      toast.dismiss(t);
      toast.error('Failed to record payment');
    } finally {
      setSaving(false);
    }
  };

  const handleExport = () => {
    if (payments.length === 0) return toast.error('Nothing to export');
    const rows = payments.map((p) => ({
      Date: toDateKeySafe(p.date),
      Labour: labourMap.get(p.labourId)?.name || p.labourId,
      Type: p.type,
      Method: p.paymentMethod || 'cash',
      Amount: p.amount,
      Notes: p.notes || '',
    }));
    exportExcel('payments.csv', rows);
    toast.success('Excel downloaded');
  };

  // Running balance per labour (for the filtered view)
  const runningByLabour = useMemo(() => {
    const map = new Map();
    payments.forEach((p) => {
      const prev = map.get(p.labourId) || 0;
      map.set(p.labourId, prev + (Number(p.amount) || 0));
    });
    return map;
  }, [payments]);

  return (
    <div className="space-y-6">
      <div className="rounded-2xl border border-border bg-bg-card p-4 shadow-sm flex flex-wrap items-center justify-between gap-3">
        <div className="text-[13px] text-text-secondary">
          <span className="font-mono font-bold text-text-primary">{payments.length}</span> payment{payments.length === 1 ? '' : 's'} · Total <span className="font-mono font-bold text-text-primary">{formatCurrency(totals.total)}</span>
        </div>
        <div className="flex gap-3">
          <Button variant="outline" onClick={handleExport} className="gap-2 h-9 rounded-lg text-[13px] text-text-secondary hover:text-text-primary border-border-strong hover:bg-bg-elevated">
            <Download className="h-4 w-4" /> Export CSV
          </Button>
          <Button onClick={openAdd} className="gap-2 bg-gold text-bg-primary hover:bg-gold-hover shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-105 transition-all h-9 rounded-lg text-[13px]">
            <Plus className="h-4 w-4" /> Add Payment
          </Button>
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-4">
        {[
          { label: 'Total', value: totals.total, color: 'text-text-primary' },
          { label: 'Salary', value: totals.salary, color: 'text-success' },
          { label: 'Advances', value: totals.advance, color: 'text-danger' },
          { label: 'OT Bonus', value: totals.ot, color: 'text-info' },
        ].map((s) => (
          <div key={s.label} className="rounded-xl border border-border bg-bg-card px-4 py-3 shadow-sm">
            <p className="text-[10px] font-medium uppercase tracking-widest text-text-muted">{s.label}</p>
            <p className={`mt-1 text-xl font-mono font-semibold ${s.color}`}>{formatCurrency(s.value)}</p>
          </div>
        ))}
      </div>

      <div className="flex flex-wrap items-end gap-3 rounded-2xl border border-border bg-bg-card p-4 shadow-sm">
        <div className="flex items-center gap-2 text-text-muted">
          <Filter className="h-4 w-4" />
          <span className="text-[10px] font-medium uppercase tracking-widest">Filters</span>
        </div>
        <div className="space-y-0.5">
          <Label className="text-[11px] uppercase tracking-wider text-text-muted">Type</Label>
          <select value={filters.type} onChange={(e) => setFilters({ ...filters, type: e.target.value })} className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary shadow-sm outline-none focus:border-gold">
            <option value="all">All</option>
            {TYPE_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
        </div>
        <div className="space-y-0.5">
          <Label className="text-[11px] uppercase tracking-wider text-text-muted">Labour</Label>
          <select value={filters.labourId} onChange={(e) => setFilters({ ...filters, labourId: e.target.value })} className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary shadow-sm outline-none focus:border-gold">
            <option value="all">All labours</option>
            {labours.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
          </select>
        </div>
        <div className="space-y-0.5">
          <Label className="text-[11px] uppercase tracking-wider text-text-muted">From</Label>
          <Input type="date" value={filters.startDate} onChange={(e) => setFilters({ ...filters, startDate: e.target.value })} className="h-9 w-40 bg-bg-input border-border-strong" />
        </div>
        <div className="space-y-0.5">
          <Label className="text-[11px] uppercase tracking-wider text-text-muted">To</Label>
          <Input type="date" value={filters.endDate} onChange={(e) => setFilters({ ...filters, endDate: e.target.value })} className="h-9 w-40 bg-bg-input border-border-strong" />
        </div>
      </div>

      <div className="rounded-2xl border border-border bg-bg-card shadow-sm overflow-hidden">
        {isLoading ? (
          <LoadingSpinner label="Loading payments…" />
        ) : payments.length === 0 ? (
          <EmptyState icon={Wallet} title="No payments found" description="Try adjusting filters or add a new payment." />
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full text-[13px]">
                <thead className="sticky top-0 border-b border-border bg-bg-elevated text-left text-[10px] uppercase tracking-widest text-text-muted">
                  <tr>
                    <th className="px-6 py-4 font-medium">Date</th>
                    <th className="px-6 py-4 font-medium">Labour</th>
                    <th className="px-6 py-4 font-medium">Type</th>
                    <th className="px-6 py-4 font-medium">Method</th>
                    <th className="px-6 py-4 font-medium text-right">Amount</th>
                    <th className="px-6 py-4 font-medium text-right">Running Balance</th>
                    <th className="px-6 py-4 font-medium">Notes</th>
                  </tr>
                </thead>
                <tbody>
                  {paginated.map((p) => {
                    const labour = labourMap.get(p.labourId);
                    const balance = runningByLabour.get(p.labourId) || 0;
                    return (
                      <tr key={p.id} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                        <td className="px-6 py-4 font-mono text-text-secondary">{toDateKeySafe(p.date)}</td>
                        <td className="px-6 py-4 font-medium text-text-primary text-[14px]">{labour?.name || p.labourId}</td>
                        <td className="px-6 py-4"><StatusBadge status={p.type || 'salary'} /></td>
                        <td className="px-6 py-4">
                          <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-[11px] tracking-wider uppercase font-bold ${METHOD_BADGE[p.paymentMethod] || METHOD_BADGE.cash}`}>
                            {METHOD_OPTIONS.find((m) => m.value === p.paymentMethod)?.label || 'Cash'}
                          </span>
                        </td>
                        <td className="px-6 py-4 text-right font-mono font-bold text-text-primary">{formatCurrency(p.amount)}</td>
                        <td className="px-6 py-4 text-right font-mono text-text-secondary">{formatCurrency(balance)}</td>
                        <td className="px-6 py-4 text-[13px] text-text-muted">{p.notes || '—'}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <Pagination page={page} pageCount={pageCount} setPage={setPage} total={total} pageSize={pageSize} onPageSizeChange={setPageSize} />
          </>
        )}
      </div>

      <Modal isOpen={dialogOpen} title="Add Payment" onClose={closeDialog} onConfirm={handleSubmit} confirmText={saving ? 'Saving…' : 'Add payment'}>
        <div className="space-y-4">
          <div className="space-y-1">
            <Label>Labour *</Label>
            <select value={form.labourId} onChange={(e) => setForm({ ...form, labourId: e.target.value })} className="h-10 w-full rounded-md border border-border-strong bg-bg-input text-text-primary px-3 text-sm shadow-sm outline-none focus:border-blue-500">
              <option value="">Select labour</option>
              {labours.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
            </select>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Amount (₹) *</Label>
              <Input type="number" min="0" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} placeholder="0" />
            </div>
            <div className="space-y-1">
              <Label>Date *</Label>
              <Input type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} />
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Type</Label>
              <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })} className="h-10 w-full rounded-md border border-border-strong bg-bg-input text-text-primary px-3 text-sm shadow-sm outline-none focus:border-blue-500">
                {TYPE_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
              </select>
            </div>
            <div className="space-y-1">
              <Label>Payment Method</Label>
              <select value={form.paymentMethod} onChange={(e) => setForm({ ...form, paymentMethod: e.target.value })} className="h-10 w-full rounded-md border border-border-strong bg-bg-input text-text-primary px-3 text-sm shadow-sm outline-none focus:border-blue-500">
                {METHOD_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
              </select>
            </div>
          </div>
          <div className="space-y-1">
            <Label>Notes</Label>
            <Input value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} placeholder="Optional" />
          </div>
        </div>
      </Modal>
    </div>
  );
}
