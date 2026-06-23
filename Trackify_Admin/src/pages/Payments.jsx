import React, { useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Plus, Wallet, Filter, Download } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { usePayments } from '../hooks/usePayments';
import { useLabours } from '../hooks/useLabours';
import { addPayment } from '../lib/services/payments.service';
import { formatCurrency, todayKey, toDateKeySafe, exportCSV } from '../lib/utils';
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
  cash: 'bg-green-100 text-green-700',
  bank: 'bg-blue-100 text-blue-700',
  upi: 'bg-purple-100 text-purple-700',
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
    exportCSV('payments.csv', rows);
    toast.success('CSV downloaded');
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
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight text-slate-950">Payments</h2>
          <p className="mt-1 text-sm text-slate-500">
            {payments.length} payment{payments.length === 1 ? '' : 's'} · Total{' '}
            <span className="font-semibold text-slate-900">{formatCurrency(totals.total)}</span>
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={handleExport} className="gap-2">
            <Download className="h-4 w-4" /> Export CSV
          </Button>
          <Button onClick={openAdd} className="gap-2 bg-blue-600 text-white hover:bg-blue-700">
            <Plus className="h-4 w-4" /> Add Payment
          </Button>
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-4">
        {[
          { label: 'Total', value: totals.total, color: 'text-slate-950' },
          { label: 'Salary', value: totals.salary, color: 'text-blue-700' },
          { label: 'Advances', value: totals.advance, color: 'text-amber-700' },
          { label: 'OT Bonus', value: totals.ot, color: 'text-purple-700' },
        ].map((s) => (
          <div key={s.label} className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{s.label}</p>
            <p className={`mt-1 text-xl font-semibold ${s.color}`}>{formatCurrency(s.value)}</p>
          </div>
        ))}
      </div>

      <div className="flex flex-wrap items-end gap-3 rounded-2xl border border-slate-200/70 bg-white/90 p-4 shadow-sm">
        <div className="flex items-center gap-2 text-slate-500">
          <Filter className="h-4 w-4" />
          <span className="text-sm font-semibold uppercase tracking-wide">Filters</span>
        </div>
        <div className="space-y-0.5">
          <Label className="text-xs text-slate-500">Type</Label>
          <select value={filters.type} onChange={(e) => setFilters({ ...filters, type: e.target.value })} className="h-10 rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500">
            <option value="all">All</option>
            {TYPE_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
        </div>
        <div className="space-y-0.5">
          <Label className="text-xs text-slate-500">Labour</Label>
          <select value={filters.labourId} onChange={(e) => setFilters({ ...filters, labourId: e.target.value })} className="h-10 rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500">
            <option value="all">All labours</option>
            {labours.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
          </select>
        </div>
        <div className="space-y-0.5">
          <Label className="text-xs text-slate-500">From</Label>
          <Input type="date" value={filters.startDate} onChange={(e) => setFilters({ ...filters, startDate: e.target.value })} className="h-10 w-40" />
        </div>
        <div className="space-y-0.5">
          <Label className="text-xs text-slate-500">To</Label>
          <Input type="date" value={filters.endDate} onChange={(e) => setFilters({ ...filters, endDate: e.target.value })} className="h-10 w-40" />
        </div>
      </div>

      <div className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm">
        {isLoading ? (
          <LoadingSpinner label="Loading payments…" />
        ) : payments.length === 0 ? (
          <EmptyState icon={Wallet} title="No payments found" description="Try adjusting filters or add a new payment." />
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="sticky top-0 border-b border-slate-200 bg-white text-left text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-4 py-3">Date</th>
                    <th className="px-4 py-3">Labour</th>
                    <th className="px-4 py-3">Type</th>
                    <th className="px-4 py-3">Method</th>
                    <th className="px-4 py-3 text-right">Amount</th>
                    <th className="px-4 py-3 text-right">Running Balance</th>
                    <th className="px-4 py-3">Notes</th>
                  </tr>
                </thead>
                <tbody>
                  {paginated.map((p) => {
                    const labour = labourMap.get(p.labourId);
                    const balance = runningByLabour.get(p.labourId) || 0;
                    return (
                      <tr key={p.id} className="border-b border-slate-100 last:border-b-0 hover:bg-slate-50">
                        <td className="px-4 py-3 text-slate-700">{toDateKeySafe(p.date)}</td>
                        <td className="px-4 py-3 font-medium text-slate-900">{labour?.name || p.labourId}</td>
                        <td className="px-4 py-3"><StatusBadge status={p.type || 'salary'} /></td>
                        <td className="px-4 py-3">
                          <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-semibold ${METHOD_BADGE[p.paymentMethod] || METHOD_BADGE.cash}`}>
                            {METHOD_OPTIONS.find((m) => m.value === p.paymentMethod)?.label || 'Cash'}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-right font-semibold text-slate-900">{formatCurrency(p.amount)}</td>
                        <td className="px-4 py-3 text-right text-slate-600">{formatCurrency(balance)}</td>
                        <td className="px-4 py-3 text-slate-600">{p.notes || '—'}</td>
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
            <select value={form.labourId} onChange={(e) => setForm({ ...form, labourId: e.target.value })} className="h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500">
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
              <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })} className="h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500">
                {TYPE_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
              </select>
            </div>
            <div className="space-y-1">
              <Label>Payment Method</Label>
              <select value={form.paymentMethod} onChange={(e) => setForm({ ...form, paymentMethod: e.target.value })} className="h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500">
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
