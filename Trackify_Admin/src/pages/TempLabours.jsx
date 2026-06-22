import React, { useState, useMemo, useEffect } from 'react';
import { Calendar, Search, Building2, Package, CheckCheck, FileDown, Edit3 } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { subscribeTempLabours, bulkUpdateTempLabourPayments } from '../lib/services/tempLabours.service';
import { getSites } from '../lib/services/sites.service';
import { formatCurrency } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import Modal from '../components/ui/Modal';
import Pagination, { usePagination } from '../components/shared/Pagination';
import EmptyState from '../components/shared/EmptyState';

export default function TempLabours() {
  const scopeId = useScopeId();
  const userName = useAuthStore(s => s.name);
  const [labours, setLabours] = useState([]);
  const [sites, setSites] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [siteFilter, setSiteFilter] = useState('all');
  const [pageSize, setPageSize] = useState(25);

  const [selectedIds, setSelectedIds] = useState(new Set());
  const [showBulkModal, setShowBulkModal] = useState(false);
  const [bulkMethod, setBulkMethod] = useState('Cash');
  const [bulkRemark, setBulkRemark] = useState('');
  const [isUpdating, setIsUpdating] = useState(false);

  useEffect(() => {
    if (!scopeId) return;
    
    getSites(scopeId).then(setSites).catch(console.error);

    const unsub = subscribeTempLabours(scopeId, (list) => {
      setLabours(list.sort((a, b) => new Date(b.date) - new Date(a.date)));
      setIsLoading(false);
    });

    return () => unsub();
  }, [scopeId]);

  const filteredLabours = useMemo(() => {
    return labours.filter(l => {
      if (search && !l.name.toLowerCase().includes(search.toLowerCase()) && !l.phone.includes(search)) return false;
      if (statusFilter !== 'all' && l.paymentStatus !== statusFilter) return false;
      if (siteFilter !== 'all' && l.siteId !== siteFilter) return false;
      return true;
    });
  }, [labours, search, statusFilter, siteFilter]);

  const { page, pageCount, paginated, setPage, total } = usePagination(filteredLabours, pageSize);

  const totals = useMemo(() => {
    return filteredLabours.reduce((acc, curr) => {
      acc.totalWorkers++;
      acc.totalWage += curr.totalWage || 0;
      acc.totalPaid += curr.paidAmount || 0;
      acc.totalLiability += curr.remainingAmount || 0;
      return acc;
    }, { totalWorkers: 0, totalWage: 0, totalPaid: 0, totalLiability: 0 });
  }, [filteredLabours]);

  const handleSelectAll = (e) => {
    if (e.target.checked) {
      setSelectedIds(new Set(filteredLabours.map(l => l.id)));
    } else {
      setSelectedIds(new Set());
    }
  };

  const handleSelectOne = (id) => {
    const next = new Set(selectedIds);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    setSelectedIds(next);
  };

  const handleBulkPay = async () => {
    if (selectedIds.size === 0) return toast.error('No records selected');
    setIsUpdating(true);
    try {
      const now = new Date();
      const dateStr = now.toISOString().split('T')[0];
      const timeStr = `${now.getHours().toString().padLeft(2, '0')}:${now.getMinutes().toString().padLeft(2, '0')}`;
      
      const toUpdate = Array.from(selectedIds).map(id => {
        const record = labours.find(l => l.id === id);
        return {
          id,
          paidAmount: record.totalWage,
          remainingAmount: 0,
          paymentStatus: 'paid',
          paymentDate: dateStr,
          paymentTime: timeStr,
          paymentMethod: bulkMethod,
          paymentRemark: bulkRemark,
          paidBy: userName || 'Admin'
        };
      });

      const batchData = {};
      for (const update of toUpdate) {
        const { id, ...data } = update;
        batchData[id] = data;
      }
      
      await bulkUpdateTempLabourPayments(Object.keys(batchData), batchData[Object.keys(batchData)[0]]);
      toast.success(`Successfully marked ${selectedIds.size} payments as paid`);
      setSelectedIds(new Set());
      setShowBulkModal(false);
      setBulkRemark('');
    } catch (e) {
      console.error(e);
      toast.error('Failed to process bulk payment');
    } finally {
      setIsUpdating(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header Stats */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-4">
        <div className="rounded-xl border border-border bg-bg-card p-5">
          <h3 className="text-[12px] font-semibold tracking-widest text-text-muted uppercase">Total Temp Workers</h3>
          <p className="mt-2 text-2xl font-bold text-text-primary">{totals.totalWorkers}</p>
        </div>
        <div className="rounded-xl border border-border bg-bg-card p-5">
          <h3 className="text-[12px] font-semibold tracking-widest text-text-muted uppercase">Total Temp Cost</h3>
          <p className="mt-2 text-2xl font-mono font-bold text-text-primary">{formatCurrency(totals.totalWage)}</p>
        </div>
        <div className="rounded-xl border border-border bg-bg-card p-5">
          <h3 className="text-[12px] font-semibold tracking-widest text-text-muted uppercase">Total Paid</h3>
          <p className="mt-2 text-2xl font-mono font-bold text-success">{formatCurrency(totals.totalPaid)}</p>
        </div>
        <div className="rounded-xl border border-border bg-bg-card p-5 relative overflow-hidden">
          <div className="absolute -right-4 -top-4 text-warning/10"><Building2 className="w-24 h-24" /></div>
          <h3 className="text-[12px] font-semibold tracking-widest text-text-muted uppercase relative">Total Liability</h3>
          <p className="mt-2 text-2xl font-mono font-bold text-warning relative">{formatCurrency(totals.totalLiability)}</p>
        </div>
      </div>

      {/* Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-4 rounded-xl border border-border bg-bg-card px-5 py-4">
        <div className="flex flex-wrap items-center gap-4">
          <div className="relative w-64">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
            <Input 
              value={search} 
              onChange={e => { setSearch(e.target.value); setPage(1); }} 
              placeholder="Search temp labour..." 
              className="pl-9 h-9" 
            />
          </div>
          <select 
            value={siteFilter} 
            onChange={e => { setSiteFilter(e.target.value); setPage(1); }}
            className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary focus:border-primary focus:outline-none"
          >
            <option value="all">All Sites</option>
            {sites.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
          <select 
            value={statusFilter} 
            onChange={e => { setStatusFilter(e.target.value); setPage(1); }}
            className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary focus:border-primary focus:outline-none"
          >
            <option value="all">All Statuses</option>
            <option value="paid">Paid</option>
            <option value="partial_paid">Partial Paid</option>
            <option value="unpaid">Unpaid</option>
          </select>
        </div>
        <div className="flex items-center gap-3">
          {selectedIds.size > 0 && (
            <Button onClick={() => setShowBulkModal(true)} className="h-9 text-[13px] bg-primary hover:bg-primary/90 text-white font-semibold">
              <CheckCheck className="w-4 h-4 mr-2" /> Pay Selected ({selectedIds.size})
            </Button>
          )}
        </div>
      </div>

      {/* Table */}
      <div className="rounded-xl border border-border bg-bg-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-[13px]">
            <thead className="border-b border-border bg-bg-elevated text-left text-[11px] uppercase tracking-widest text-text-muted">
              <tr>
                <th className="px-5 py-3 w-[40px]">
                  <input type="checkbox" checked={selectedIds.size > 0 && selectedIds.size === filteredLabours.length} onChange={handleSelectAll} className="rounded border-border bg-bg-input text-primary focus:ring-primary focus:ring-offset-bg-card" />
                </th>
                <th className="px-5 py-3 font-medium">Date</th>
                <th className="px-5 py-3 font-medium">Worker</th>
                <th className="px-5 py-3 font-medium">Site</th>
                <th className="px-5 py-3 font-medium text-right">Total Wage</th>
                <th className="px-5 py-3 font-medium text-right">Paid</th>
                <th className="px-5 py-3 font-medium text-right">Liability</th>
                <th className="px-5 py-3 font-medium text-center">Status</th>
              </tr>
            </thead>
            <tbody>
              {paginated.length === 0 ? (
                <tr><td colSpan="8" className="px-5 py-8 text-center text-text-muted">No temporary labours found</td></tr>
              ) : (
                paginated.map(l => (
                  <tr key={l.id} className="border-b border-border/50 hover:bg-bg-elevated transition-colors">
                    <td className="px-5 py-4">
                      <input type="checkbox" checked={selectedIds.has(l.id)} onChange={() => handleSelectOne(l.id)} className="rounded border-border bg-bg-input text-primary focus:ring-primary focus:ring-offset-bg-card" />
                    </td>
                    <td className="px-5 py-4 font-medium text-text-primary whitespace-nowrap">{l.date}</td>
                    <td className="px-5 py-4">
                      <div className="font-medium text-text-primary">{l.name}</div>
                      {l.phone && <div className="text-[11px] text-text-muted">{l.phone}</div>}
                    </td>
                    <td className="px-5 py-4 text-text-secondary">{sites.find(s => s.id === l.siteId)?.name || '—'}</td>
                    <td className="px-5 py-4 text-right font-mono text-text-primary">₹{l.totalWage.toFixed(0)}</td>
                    <td className="px-5 py-4 text-right font-mono text-success">₹{l.paidAmount.toFixed(0)}</td>
                    <td className="px-5 py-4 text-right font-mono text-warning">₹{l.remainingAmount.toFixed(0)}</td>
                    <td className="px-5 py-4 text-center">
                      <span className={`inline-block px-2.5 py-1 rounded-md text-[10px] font-bold ${l.paymentStatus === 'paid' ? 'bg-success/20 text-success' : l.paymentStatus === 'partial_paid' ? 'bg-orange-500/20 text-orange-400' : 'bg-danger/20 text-danger'}`}>
                        {l.paymentStatus?.replace('_', ' ').toUpperCase() || 'UNPAID'}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        <Pagination page={page} pageCount={pageCount} total={total} pageSize={pageSize} setPage={setPage} setPageSize={setPageSize} />
      </div>

      {/* Bulk Payment Modal */}
      <Modal isOpen={showBulkModal} onClose={() => setShowBulkModal(false)} title="Bulk Mark as Paid">
        <div className="space-y-4">
          <p className="text-[13px] text-text-secondary">
            You are about to mark <strong className="text-text-primary">{selectedIds.size}</strong> temporary worker(s) as <strong>fully paid</strong>. This will set their remaining liability to ₹0.
          </p>
          <div>
            <label className="block text-[11px] font-semibold uppercase tracking-widest text-text-muted mb-1.5">Payment Method</label>
            <select
              value={bulkMethod}
              onChange={(e) => setBulkMethod(e.target.value)}
              className="w-full h-10 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary focus:border-primary focus:outline-none"
            >
              <option value="Cash">Cash</option>
              <option value="UPI">UPI</option>
              <option value="Bank Transfer">Bank Transfer</option>
              <option value="Other">Other</option>
            </select>
          </div>
          <div>
            <label className="block text-[11px] font-semibold uppercase tracking-widest text-text-muted mb-1.5">Remark (Optional)</label>
            <Input value={bulkRemark} onChange={(e) => setBulkRemark(e.target.value)} placeholder="e.g. End of day bulk payment" />
          </div>
          <div className="pt-4 flex justify-end gap-3">
            <Button variant="outline" onClick={() => setShowBulkModal(false)}>Cancel</Button>
            <Button onClick={handleBulkPay} disabled={isUpdating} className="bg-success hover:bg-success/90 text-white font-semibold">
              {isUpdating ? 'Processing...' : 'Confirm Bulk Payment'}
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
