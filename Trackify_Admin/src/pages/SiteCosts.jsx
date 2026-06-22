import React, { useState, useMemo } from 'react';
import { Plus, Search, Building2, Package, Banknote, Calendar, Pencil, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { useSiteCosts } from '../hooks/useSiteCosts';
import { addMaterialPurchase, addSiteExpense, updateMaterialPurchase, deleteMaterialPurchase, updateSiteExpense, deleteSiteExpense } from '../lib/services/costs.service';
import { getSites } from '../lib/services/sites.service';
import { formatCurrency } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import Modal from '../components/ui/Modal';
import Pagination, { usePagination } from '../components/shared/Pagination';

const EMPTY_MATERIAL = {
  materialName: '', category: 'Cement', quantity: '', unit: 'Bag', pricePerUnit: '', supplierId: '', supplierName: '', purchaseDate: new Date().toISOString().split('T')[0], siteId: '', remarks: ''
};
const EMPTY_EXPENSE = {
  expenseType: 'machinery', description: '', amount: '', date: new Date().toISOString().split('T')[0], siteId: '', paidTo: '', remarks: ''
};

export default function SiteCosts() {
  const scopeId = useScopeId();
  const { materials, expenses, suppliers, tempLabours, isLoading } = useSiteCosts();
  
  const [view, setView] = useState('materials'); // 'materials' | 'expenses'
  const [search, setSearch] = useState('');
  const [pageSize, setPageSize] = useState(25);
  const [sites, setSites] = useState([]);

  const [addMaterialOpen, setAddMaterialOpen] = useState(false);
  const [addExpenseOpen, setAddExpenseOpen] = useState(false);
  const [formM, setFormM] = useState(EMPTY_MATERIAL);
  const [formE, setFormE] = useState(EMPTY_EXPENSE);
  const [saving, setSaving] = useState(false);

  const [editingIdM, setEditingIdM] = useState(null);
  const [editingIdE, setEditingIdE] = useState(null);
  const [deleteConfirm, setDeleteConfirm] = useState(null);

  // Load sites once
  React.useEffect(() => {
    if (scopeId) {
      getSites(scopeId).then(setSites).catch(console.error);
    }
  }, [scopeId]);

  const filteredMaterials = useMemo(() => {
    return materials.filter(m => {
      if (search && !m.materialName.toLowerCase().includes(search.toLowerCase())) return false;
      return true;
    });
  }, [materials, search]);

  const filteredExpenses = useMemo(() => {
    return expenses.filter(e => {
      if (search && !e.description.toLowerCase().includes(search.toLowerCase())) return false;
      return true;
    });
  }, [expenses, search]);

  const filteredTempLabours = useMemo(() => {
    return tempLabours.filter(l => {
      if (search && !l.name.toLowerCase().includes(search.toLowerCase())) return false;
      return true;
    });
  }, [tempLabours, search]);

  const activeList = view === 'materials' ? filteredMaterials : view === 'expenses' ? filteredExpenses : filteredTempLabours;
  
  const { page, pageCount, paginated, setPage, total } = usePagination(activeList, pageSize);

  const handleSaveMaterial = async () => {
    if (!formM.materialName || !formM.quantity || !formM.pricePerUnit || !formM.siteId) {
      return toast.error("Please fill in required fields");
    }
    setSaving(true);
    try {
      const q = parseFloat(formM.quantity);
      const p = parseFloat(formM.pricePerUnit);
      const data = {
        ...formM,
        quantity: q,
        pricePerUnit: p,
        totalAmount: q * p,
      };
      if (editingIdM) {
        await updateMaterialPurchase(scopeId, editingIdM, data);
        toast.success("Material updated successfully!");
      } else {
        await addMaterialPurchase(scopeId, data);
        toast.success("Material added successfully!");
      }
      setAddMaterialOpen(false);
      setFormM(EMPTY_MATERIAL);
      setEditingIdM(null);
    } catch (err) {
      toast.error("Failed to save material");
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteMaterial = async (id) => {
    if (deleteConfirm !== id) return setDeleteConfirm(id);
    try {
      await deleteMaterialPurchase(scopeId, id);
      toast.success("Material deleted");
    } catch (e) {
      toast.error("Failed to delete material");
    }
    setDeleteConfirm(null);
  };

  const handleSaveExpense = async () => {
    if (!formE.description || !formE.amount || !formE.siteId) {
      return toast.error("Please fill in required fields");
    }
    setSaving(true);
    try {
      const data = {
        ...formE,
        amount: parseFloat(formE.amount),
      };
      if (editingIdE) {
        await updateSiteExpense(scopeId, editingIdE, data);
        toast.success("Expense updated successfully!");
      } else {
        await addSiteExpense(scopeId, data);
        toast.success("Expense added successfully!");
      }
      setAddExpenseOpen(false);
      setFormE(EMPTY_EXPENSE);
      setEditingIdE(null);
    } catch (err) {
      toast.error("Failed to save expense");
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteExpense = async (id) => {
    if (deleteConfirm !== id) return setDeleteConfirm(id);
    try {
      await deleteSiteExpense(scopeId, id);
      toast.success("Expense deleted");
    } catch (e) {
      toast.error("Failed to delete expense");
    }
    setDeleteConfirm(null);
  };

  const totalMat = materials.reduce((sum, item) => sum + (item.totalAmount || 0), 0);
  const totalExp = expenses.reduce((sum, item) => sum + (item.amount || 0), 0);
  const totalTempPaid = (tempLabours || []).reduce((sum, item) => sum + (Number(item.paidAmount) || 0), 0);
  const totalTempLiability = (tempLabours || []).reduce((sum, item) => sum + (Number(item.remainingAmount) || 0), 0);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="rounded-xl border border-border bg-bg-card px-6 py-5 flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-[16px] font-semibold tracking-wide text-text-primary uppercase">Site Cost Management</h2>
          <p className="mt-1 text-[11px] font-medium uppercase tracking-widest text-text-muted">
            Materials: <span className="font-mono text-gold">{formatCurrency(totalMat)}</span> · Expenses: <span className="font-mono text-info">{formatCurrency(totalExp)}</span> · Temp Labour Paid: <span className="font-mono text-success">{formatCurrency(totalTempPaid)}</span> · Temp Labour Liability: <span className="font-mono text-warning">{formatCurrency(totalTempLiability)}</span>
          </p>
        </div>
        <div className="flex gap-3">
          <button onClick={() => setAddExpenseOpen(true)} className="flex h-9 items-center gap-2 rounded-lg border border-info/30 bg-info/10 px-4 text-[13px] font-medium text-info hover:bg-info hover:text-white transition-colors">
            <Plus className="h-4 w-4" /> Add Expense
          </button>
          <button onClick={() => setAddMaterialOpen(true)} className="flex h-9 items-center gap-2 rounded-lg bg-gold px-4 text-[13px] font-semibold text-bg-primary shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-105 transition-all">
            <Plus className="h-4 w-4" /> Add Material
          </button>
        </div>
      </div>

      {/* Filters and Tabs */}
      <div className="flex flex-wrap items-center justify-between gap-4 rounded-xl border border-border bg-bg-card px-5 py-3.5">
        <div className="flex bg-bg-input p-1 rounded-lg border border-border-strong">
          <button
            onClick={() => { setView('materials'); setPage(1); }}
            className={`px-4 py-1.5 text-[12px] font-semibold uppercase tracking-widest rounded-md transition-colors ${view === 'materials' ? 'bg-bg-elevated text-gold shadow-sm' : 'text-text-muted hover:text-text-primary'}`}
          >
            Materials
          </button>
          <button
            onClick={() => { setView('expenses'); setPage(1); }}
            className={`px-4 py-1.5 text-[12px] font-semibold uppercase tracking-widest rounded-md transition-colors ${view === 'expenses' ? 'bg-bg-elevated text-info shadow-sm' : 'text-text-muted hover:text-text-primary'}`}
          >
            Site Expenses
          </button>
          <button
            onClick={() => { setView('tempLabours'); setPage(1); }}
            className={`px-4 py-1.5 text-[12px] font-semibold uppercase tracking-widest rounded-md transition-colors ${view === 'tempLabours' ? 'bg-bg-elevated text-purple-400 shadow-sm' : 'text-text-muted hover:text-text-primary'}`}
          >
            Temp Labours
          </button>
        </div>
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search..."
            className="h-9 w-56 rounded-lg border border-border-strong bg-bg-input pl-9 pr-3 text-[13px] text-text-primary placeholder:text-text-muted outline-none focus:border-gold focus:ring-1 focus:ring-gold"
          />
        </div>
      </div>

      {/* Table */}
      <div className="rounded-xl border border-border bg-bg-card shadow-sm overflow-hidden">
        {isLoading ? (
          <LoadingSpinner label="Loading costs..." />
        ) : activeList.length === 0 ? (
          <EmptyState
            icon={view === 'materials' ? Package : Banknote}
            title={`No ${view} found`}
            description="Start adding entries to see them here."
          />
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full text-[13px]">
                <thead className="sticky top-0 border-b border-border bg-bg-elevated text-left text-[10px] uppercase tracking-widest text-text-muted">
                  {view === 'materials' ? (
                    <tr>
                      <th className="px-5 py-3 font-medium">Item</th>
                      <th className="px-5 py-3 font-medium">Category</th>
                      <th className="px-5 py-3 font-medium">Site</th>
                      <th className="px-5 py-3 font-medium text-right">Qty/Unit</th>
                      <th className="px-5 py-3 font-medium text-right">Price</th>
                      <th className="px-5 py-3 font-medium text-right">Total</th>
                      <th className="px-5 py-3 font-medium text-right">Date</th>
                      <th className="px-5 py-3 font-medium text-right">Actions</th>
                    </tr>
                  ) : view === 'expenses' ? (
                    <tr>
                      <th className="px-5 py-3 font-medium">Title</th>
                      <th className="px-5 py-3 font-medium">Type</th>
                      <th className="px-5 py-3 font-medium">Site</th>
                      <th className="px-5 py-3 font-medium">Paid To</th>
                      <th className="px-5 py-3 font-medium text-right">Amount</th>
                      <th className="px-5 py-3 font-medium text-right">Date</th>
                      <th className="px-5 py-3 font-medium text-right">Actions</th>
                    </tr>
                  ) : (
                    <tr>
                      <th className="px-5 py-3 font-medium">Worker Name</th>
                      <th className="px-5 py-3 font-medium">Site</th>
                      <th className="px-5 py-3 font-medium text-right">Total Wage</th>
                      <th className="px-5 py-3 font-medium text-right">Paid</th>
                      <th className="px-5 py-3 font-medium text-right">Liability</th>
                      <th className="px-5 py-3 font-medium text-center">Status</th>
                      <th className="px-5 py-3 font-medium text-right">Date</th>
                    </tr>
                  )}
                </thead>
                <tbody>
                  {paginated.map((item) => (
                    <tr key={item.id} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                      {view === 'materials' ? (
                        <>
                          <td className="px-5 py-3 font-medium text-text-primary">{item.materialName}</td>
                          <td className="px-5 py-3 text-[12px] text-text-secondary">{item.category}</td>
                          <td className="px-5 py-3 text-[12px] text-text-secondary">{sites.find(s => s.id === item.siteId)?.name || 'Unknown'}</td>
                          <td className="px-5 py-3 text-right font-mono text-[12px] text-text-secondary">{item.quantity} <span className="text-text-muted">{item.unit}</span></td>
                          <td className="px-5 py-3 text-right font-mono text-[12px] text-text-secondary">{formatCurrency(item.pricePerUnit)}</td>
                          <td className="px-5 py-3 text-right font-mono font-medium text-gold">{formatCurrency(item.totalAmount)}</td>
                          <td className="px-5 py-3 text-right font-mono text-[12px] text-text-muted">{item.purchaseDate}</td>
                          <td className="px-5 py-3 text-right">
                            <div className="flex items-center justify-end gap-2">
                              <button onClick={() => { setFormM(item); setEditingIdM(item.id); setAddMaterialOpen(true); }} className="flex h-7 w-7 items-center justify-center rounded-md border border-border-strong bg-bg-elevated text-text-secondary hover:text-text-primary hover:border-gold transition-colors"><Pencil className="h-3 w-3" /></button>
                              <button onClick={() => handleDeleteMaterial(item.id)} className={`flex h-7 w-7 items-center justify-center rounded-md border transition-colors ${deleteConfirm === item.id ? 'border-danger/30 bg-danger-bg text-danger hover:bg-danger hover:text-white' : 'border-border-strong bg-bg-elevated text-text-secondary hover:text-danger hover:border-danger/50 hover:bg-danger-bg'}`}><Trash2 className="h-3 w-3" /></button>
                              {deleteConfirm === item.id && <button onClick={() => setDeleteConfirm(null)} className="rounded-md px-2 py-1 text-[11px] font-medium text-text-muted hover:text-text-primary transition-colors">Cancel</button>}
                            </div>
                          </td>
                        </>
                      ) : view === 'expenses' ? (
                        <>
                          <td className="px-5 py-3 font-medium text-text-primary">{item.description}</td>
                          <td className="px-5 py-3 text-[12px] text-text-secondary capitalize">{item.expenseType}</td>
                          <td className="px-5 py-3 text-[12px] text-text-secondary">{sites.find(s => s.id === item.siteId)?.name || 'Unknown'}</td>
                          <td className="px-5 py-3 text-[12px] text-text-secondary">{item.paidTo || '—'}</td>
                          <td className="px-5 py-3 text-right font-mono font-medium text-info">{formatCurrency(item.amount)}</td>
                          <td className="px-5 py-3 text-right font-mono text-[12px] text-text-muted">{item.date}</td>
                          <td className="px-5 py-3 text-right">
                            <div className="flex items-center justify-end gap-2">
                              <button onClick={() => { setFormE(item); setEditingIdE(item.id); setAddExpenseOpen(true); }} className="flex h-7 w-7 items-center justify-center rounded-md border border-border-strong bg-bg-elevated text-text-secondary hover:text-text-primary hover:border-gold transition-colors"><Pencil className="h-3 w-3" /></button>
                              <button onClick={() => handleDeleteExpense(item.id)} className={`flex h-7 w-7 items-center justify-center rounded-md border transition-colors ${deleteConfirm === item.id ? 'border-danger/30 bg-danger-bg text-danger hover:bg-danger hover:text-white' : 'border-border-strong bg-bg-elevated text-text-secondary hover:text-danger hover:border-danger/50 hover:bg-danger-bg'}`}><Trash2 className="h-3 w-3" /></button>
                              {deleteConfirm === item.id && <button onClick={() => setDeleteConfirm(null)} className="rounded-md px-2 py-1 text-[11px] font-medium text-text-muted hover:text-text-primary transition-colors">Cancel</button>}
                            </div>
                          </td>
                        </>
                      ) : (
                        <>
                          <td className="px-5 py-3 font-medium text-text-primary">{item.name}</td>
                          <td className="px-5 py-3 text-[12px] text-text-secondary">{sites.find(s => s.id === item.siteId)?.name || 'Unknown'}</td>
                          <td className="px-5 py-3 text-right font-mono font-medium text-gold">{formatCurrency(item.totalWage || 0)}</td>
                          <td className="px-5 py-3 text-right font-mono font-medium text-success">{formatCurrency(item.paidAmount || 0)}</td>
                          <td className="px-5 py-3 text-right font-mono font-medium text-warning">{formatCurrency(item.remainingAmount || 0)}</td>
                          <td className="px-5 py-3 text-center">
                            <span className={`inline-block px-2 py-1 rounded-md text-[10px] font-bold ${item.paymentStatus === 'paid' ? 'bg-success/20 text-success' : item.paymentStatus === 'partial_paid' ? 'bg-orange-500/20 text-orange-400' : 'bg-danger/20 text-danger'}`}>
                              {item.paymentStatus?.replace('_', ' ').toUpperCase() || 'UNPAID'}
                            </span>
                          </td>
                          <td className="px-5 py-3 text-right font-mono text-[12px] text-text-muted">{item.date}</td>
                        </>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Pagination page={page} pageCount={pageCount} setPage={setPage} total={total} pageSize={pageSize} onPageSizeChange={setPageSize} />
          </>
        )}
      </div>

      {/* Add Material Modal */}
      <Modal isOpen={addMaterialOpen} title="Add Material Purchase" onClose={() => { if (!saving) { setAddMaterialOpen(false); setEditingIdM(null); setFormM(EMPTY_MATERIAL); } }} onConfirm={handleSaveMaterial} confirmText={saving ? 'Saving...' : 'Add Material'}>
        <div className="space-y-4">
          <div className="space-y-1">
            <Label>Material Name *</Label>
            <Input value={formM.materialName} onChange={(e) => setFormM({ ...formM, materialName: e.target.value })} placeholder="e.g. UltraTech Cement" />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Category</Label>
              <select value={formM.category} onChange={(e) => setFormM({ ...formM, category: e.target.value })} className="h-10 w-full rounded-md border border-border-strong bg-bg-input text-text-primary px-3 text-sm shadow-sm outline-none">
                {['Cement', 'Sand', 'Steel', 'Bricks', 'Tiles', 'Paint', 'Aggregate', 'Pipe', 'Others'].map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>
            <div className="space-y-1">
              <Label>Site *</Label>
              <select value={formM.siteId} onChange={(e) => setFormM({ ...formM, siteId: e.target.value })} className="h-10 w-full rounded-md border border-border-strong bg-bg-input text-text-primary px-3 text-sm shadow-sm outline-none">
                <option value="">Select site</option>
                {sites.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <div className="space-y-1">
              <Label>Quantity *</Label>
              <Input type="number" value={formM.quantity} onChange={(e) => setFormM({ ...formM, quantity: e.target.value })} placeholder="0" />
            </div>
            <div className="space-y-1">
              <Label>Unit</Label>
              <select value={formM.unit} onChange={(e) => setFormM({ ...formM, unit: e.target.value })} className="h-10 w-full rounded-md border border-border-strong bg-bg-input text-text-primary px-3 text-sm shadow-sm outline-none">
                {['Bag', 'Brass', 'KG', 'Pieces', 'Box', 'Litre', 'Ton'].map(u => <option key={u} value={u}>{u}</option>)}
              </select>
            </div>
            <div className="space-y-1">
              <Label>Price per Unit *</Label>
              <Input type="number" value={formM.pricePerUnit} onChange={(e) => setFormM({ ...formM, pricePerUnit: e.target.value })} placeholder="₹" />
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Supplier</Label>
              <select value={formM.supplierId} onChange={(e) => {
                const sid = e.target.value;
                const sname = suppliers.find(s => s.id === sid)?.name || '';
                setFormM({ ...formM, supplierId: sid, supplierName: sname });
              }} className="h-10 w-full rounded-md border border-border-strong bg-bg-input text-text-primary px-3 text-sm shadow-sm outline-none">
                <option value="">No Supplier</option>
                {suppliers.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </div>
            <div className="space-y-1">
              <Label>Date</Label>
              <Input type="date" value={formM.purchaseDate} onChange={(e) => setFormM({ ...formM, purchaseDate: e.target.value })} />
            </div>
          </div>
        </div>
      </Modal>

      {/* Add Expense Modal */}
      <Modal isOpen={addExpenseOpen} title="Add Site Expense" onClose={() => { if (!saving) { setAddExpenseOpen(false); setEditingIdE(null); setFormE(EMPTY_EXPENSE); } }} onConfirm={handleSaveExpense} confirmText={saving ? 'Saving...' : 'Add Expense'}>
        <div className="space-y-4">
          <div className="space-y-1">
            <Label>Expense Description *</Label>
            <Input value={formE.description} onChange={(e) => setFormE({ ...formE, description: e.target.value })} placeholder="e.g. JCB Rental" />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Type</Label>
              <select value={formE.expenseType} onChange={(e) => setFormE({ ...formE, expenseType: e.target.value })} className="h-10 w-full rounded-md border border-border-strong bg-bg-input text-text-primary px-3 text-sm shadow-sm outline-none">
                {[{k: 'machinery', v: 'Machinery'}, {k: 'transport', v: 'Transport'}, {k: 'food', v: 'Food'}, {k: 'misc', v: 'Miscellaneous'}, {k: 'consultation', v: 'Consultation'}, {k: 'legal', v: 'Legal'}].map(c => <option key={c.k} value={c.k}>{c.v}</option>)}
              </select>
            </div>
            <div className="space-y-1">
              <Label>Site *</Label>
              <select value={formE.siteId} onChange={(e) => setFormE({ ...formE, siteId: e.target.value })} className="h-10 w-full rounded-md border border-border-strong bg-bg-input text-text-primary px-3 text-sm shadow-sm outline-none">
                <option value="">Select site</option>
                {sites.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Amount (₹) *</Label>
              <Input type="number" value={formE.amount} onChange={(e) => setFormE({ ...formE, amount: e.target.value })} placeholder="₹" />
            </div>
            <div className="space-y-1">
              <Label>Date</Label>
              <Input type="date" value={formE.date} onChange={(e) => setFormE({ ...formE, date: e.target.value })} />
            </div>
          </div>
        </div>
      </Modal>
    </div>
  );
}
