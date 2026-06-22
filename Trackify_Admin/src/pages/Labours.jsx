import React, { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Plus, Search, Pencil, Ban, RotateCcw, HardHat, ArrowUpDown,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { useLabours } from '../hooks/useLabours';
import { useSupervisors } from '../hooks/useSupervisors';
import {
  addLabour, updateLabour, deactivateLabour, activateLabour,
} from '../lib/services/labours.service';
import { formatCurrency } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import StatusBadge from '../components/shared/StatusBadge';
import Modal from '../components/ui/Modal';
import Pagination, { usePagination } from '../components/shared/Pagination';

const EMPTY_FORM = {
  name: '',
  phone: '',
  skill: '',
  dailyWage: '',
  overtimeWagePerHour: '',
  defaultOvertimeHours: '',
  supervisorId: '',   // ← always start empty, never pre-fill with contractor uid
  isActive: true,
};

const SORT_OPTIONS = [
  { value: 'name', label: 'Name' },
  { value: 'dailyWage', label: 'Daily Wage' },
  { value: 'overtimeWagePerHour', label: 'OT Rate' },
];

export default function Labours() {
  const navigate = useNavigate();
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);

  // activeContractorId is what all queries must use
  const activeContractorId = useAuthStore((s) => s.activeContractorId);
  const scopeId = useScopeId();

  const isSupervisor = role === 'supervisor';

  const { data: labours = [], isLoading } = useLabours({ activeOnly: false });

  // supervisors = users where role==supervisor AND contractorId==activeContractorId
  // This comes from useSupervisors hook which queries users collection
  const { data: supervisors = [] } = useSupervisors();

  const [search, setSearch] = useState('');
  const [supervisorFilter, setSupervisorFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('active');
  const [sortBy, setSortBy] = useState('name');
  const [sortDir, setSortDir] = useState('asc');
  const [pageSize, setPageSize] = useState(25);

  const [selected, setSelected] = useState(new Set());
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);

  // Build supervisorId → supervisor object map for display
  const supervisorMap = useMemo(() => {
    const m = new Map();
    supervisors.forEach((s) => m.set(s.id, s));
    return m;
  }, [supervisors]);

  // ── Filtering and sorting ──────────────────────────────────
  const filtered = useMemo(() => {
    let list = labours.filter((l) => {
      const q = search.toLowerCase();
      if (q && !l.name?.toLowerCase().includes(q) && !l.phone?.includes(q)) {
        return false;
      }
      if (supervisorFilter !== 'all' && l.supervisorId !== supervisorFilter) {
        return false;
      }
      if (statusFilter === 'active' && l.isActive === false) return false;
      if (statusFilter === 'inactive' && l.isActive !== false) return false;
      return true;
    });

    list.sort((a, b) => {
      let va = a[sortBy];
      let vb = b[sortBy];
      if (typeof va === 'string') va = va.toLowerCase();
      if (typeof vb === 'string') vb = vb.toLowerCase();
      if (va < vb) return sortDir === 'asc' ? -1 : 1;
      if (va > vb) return sortDir === 'asc' ? 1 : -1;
      return 0;
    });
    return list;
  }, [labours, search, supervisorFilter, statusFilter, sortBy, sortDir]);

  const totalWage = useMemo(
    () => labours
      .filter((l) => l.isActive !== false)
      .reduce((s, l) => s + (Number(l.dailyWage) || 0), 0),
    [labours],
  );

  const {
    page, pageCount, paginated, setPage, total,
  } = usePagination(filtered, pageSize);

  // ── Sort toggle ────────────────────────────────────────────
  const toggleSort = (key) => {
    if (sortBy === key) setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    else { setSortBy(key); setSortDir('asc'); }
  };

  // ── Checkbox select ────────────────────────────────────────
  const toggleSelect = (id) => {
    setSelected((prev) => {
      const n = new Set(prev);
      if (n.has(id)) n.delete(id); else n.add(id);
      return n;
    });
  };

  const toggleAll = () => {
    setSelected((prev) => (
      prev.size === paginated.length
        ? new Set()
        : new Set(paginated.map((l) => l.id))
    ));
  };

  // ── Bulk actions ───────────────────────────────────────────
  const bulkAction = async (action) => {
    if (selected.size === 0) return;
    const ids = [...selected];
    try {
      await Promise.all(
        ids.map((id) => (action === 'deactivate'
          ? deactivateLabour(id)
          : activateLabour(id))),
      );
      toast.success(
        `${ids.length} labour(s) ${action === 'deactivate' ? 'deactivated' : 'activated'}`,
      );
      setSelected(new Set());
    } catch {
      toast.error('Bulk action failed');
    }
  };

  // ── Dialog open ────────────────────────────────────────────
  const openAdd = () => {
    setEditing(null);
    // FIX: Do NOT pre-fill supervisorId with contractor uid
    // Always start empty so user must select a real supervisor
    setForm({ ...EMPTY_FORM });
    setDialogOpen(true);
  };

  const openEdit = (labour) => {
    setEditing(labour);
    setForm({
      name: labour.name || '',
      phone: labour.phone || '',
      skill: labour.skill || '',
      dailyWage: labour.dailyWage ?? '',
      overtimeWagePerHour: labour.overtimeWagePerHour ?? '',
      defaultOvertimeHours: labour.defaultOvertimeHours ?? '',
      supervisorId: labour.supervisorId || '',
      isActive: labour.isActive !== false,
    });
    setDialogOpen(true);
  };

  // ── Save labour ────────────────────────────────────────────
  const handleSubmit = async () => {
    if (!form.name.trim()) return toast.error('Name is required');
    if (!form.supervisorId) return toast.error('Supervisor is required');

    // Validate supervisorId is a real supervisor — not contractor uid
    const isValidSupervisor = supervisors.some((s) => s.id === form.supervisorId);
    if (!isValidSupervisor) {
      return toast.error('Please select a valid supervisor from the list');
    }

    if (!activeContractorId) {
      return toast.error('No contractor selected. Please refresh the page.');
    }

    setSaving(true);
    const t = toast.loading(editing ? 'Saving…' : 'Adding labour…');

    try {
      if (editing) {
        await updateLabour(editing.id, {
          name: form.name.trim(),
          phone: form.phone.trim() || null,
          skill: form.skill.trim() || null,
          dailyWage: form.dailyWage,
          overtimeWagePerHour: form.overtimeWagePerHour,
          defaultOvertimeHours: form.defaultOvertimeHours,
          supervisorId: form.supervisorId,
          contractorId: activeContractorId,  // ← always include
          isActive: form.isActive,
        });
      } else {
        // FIX: Pass BOTH supervisorId AND contractorId
        // supervisorId = Ramesh's UID (selected from dropdown)
        // contractorId = YS Constructions ID (from auth store)
        await addLabour({
          name: form.name.trim(),
          phone: form.phone.trim() || null,
          skill: form.skill.trim() || null,
          dailyWage: form.dailyWage,
          overtimeWagePerHour: form.overtimeWagePerHour,
          defaultOvertimeHours: form.defaultOvertimeHours,
          supervisorId: form.supervisorId,       // ← Ramesh's UID
          contractorId: activeContractorId,      // ← YS Constructions ID
        });
      }
      toast.dismiss(t);
      toast.success(editing ? 'Labour updated' : 'Labour added');
      setDialogOpen(false);
    } catch (err) {
      toast.dismiss(t);
      console.error('Save labour error:', err);
      toast.error(`Failed to save: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  const SortHeader = ({ field, label }) => (
    <button
      onClick={() => toggleSort(field)}
      className="flex items-center gap-1 hover:text-slate-900"
    >
      {label}
      <ArrowUpDown
        className={`h-3.5 w-3.5 ${sortBy === field ? 'text-blue-600' : 'text-slate-300'}`}
      />
    </button>
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight text-slate-950">
            Labours
          </h2>
          <p className="mt-1 text-sm text-slate-500">
            {labours.filter((l) => l.isActive !== false).length} active · Daily wage liability:{' '}
            <span className="font-semibold">{formatCurrency(totalWage)}</span>/day
          </p>
        </div>
        {!isSupervisor && (
          <Button
            onClick={openAdd}
            className="gap-2 bg-blue-600 text-white hover:bg-blue-700"
          >
            <Plus className="h-4 w-4" /> Add Labour
          </Button>
        )}
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-end gap-3 rounded-2xl border border-slate-200/70 bg-white/90 p-4 shadow-sm">
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search name or phone…"
            className="pl-9 h-10 w-56"
          />
        </div>

        {!isSupervisor && supervisors.length > 0 && (
          <div className="space-y-0.5">
            <Label className="text-xs text-slate-500">Supervisor</Label>
            <select
              value={supervisorFilter}
              onChange={(e) => setSupervisorFilter(e.target.value)}
              className="h-10 rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
            >
              <option value="all">All supervisors</option>
              {supervisors.map((s) => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
          </div>
        )}

        <div className="space-y-0.5">
          <Label className="text-xs text-slate-500">Status</Label>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="h-10 rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
          >
            <option value="all">All</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
          </select>
        </div>

        {selected.size > 0 && !isSupervisor && (
          <div className="flex gap-2">
            <Button
              variant="outline"
              onClick={() => bulkAction('activate')}
              className="gap-1 text-green-700 text-xs"
            >
              Activate {selected.size}
            </Button>
            <Button
              variant="outline"
              onClick={() => bulkAction('deactivate')}
              className="gap-1 text-red-600 text-xs"
            >
              Deactivate {selected.size}
            </Button>
          </div>
        )}
      </div>

      {/* Table */}
      <div className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm">
        {isLoading ? (
          <LoadingSpinner label="Loading labours…" />
        ) : filtered.length === 0 ? (
          <EmptyState
            icon={HardHat}
            title="No labours found"
            description={
              isSupervisor
                ? 'No labours assigned to you.'
                : 'Add your first labour to get started.'
            }
          />
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="sticky top-0 border-b border-slate-200 bg-white text-left text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    {!isSupervisor && (
                      <th className="px-4 py-3 w-10">
                        <input
                          type="checkbox"
                          checked={selected.size === paginated.length && paginated.length > 0}
                          onChange={toggleAll}
                          className="rounded border-slate-300"
                        />
                      </th>
                    )}
                    <th className="px-4 py-3">
                      <SortHeader field="name" label="Name" />
                    </th>
                    <th className="px-4 py-3">Phone</th>
                    <th className="px-4 py-3">Skill</th>
                    <th className="px-4 py-3 text-right">
                      <SortHeader field="dailyWage" label="Daily Wage" />
                    </th>
                    <th className="px-4 py-3 text-right">
                      <SortHeader field="overtimeWagePerHour" label="OT Rate/hr" />
                    </th>
                    <th className="px-4 py-3 text-right">Default OT Hrs</th>
                    <th className="px-4 py-3">Supervisor</th>
                    <th className="px-4 py-3">Status</th>
                    {!isSupervisor && (
                      <th className="px-4 py-3 text-right">Actions</th>
                    )}
                  </tr>
                </thead>
                <tbody>
                  {paginated.map((l) => {
                    const sup = l.supervisorId
                      ? supervisorMap.get(l.supervisorId)
                      : null;
                    return (
                      <tr
                        key={l.id}
                        onClick={() => navigate(`/labours/${l.id}`)}
                        className={`border-b border-slate-100 last:border-b-0 cursor-pointer transition hover:bg-blue-50/40 ${selected.has(l.id) ? 'bg-blue-50' : ''}`}
                      >
                        {!isSupervisor && (
                          <td
                            className="px-4 py-3 w-10"
                            onClick={(e) => e.stopPropagation()}
                          >
                            <input
                              type="checkbox"
                              checked={selected.has(l.id)}
                              onChange={() => toggleSelect(l.id)}
                              className="rounded border-slate-300"
                            />
                          </td>
                        )}
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2">
                            <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-blue-100 text-xs font-semibold text-blue-700">
                              {(l.name || '?')[0].toUpperCase()}
                            </div>
                            <span className="font-medium text-slate-900 hover:text-blue-700">
                              {l.name}
                            </span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-slate-700">{l.phone || '—'}</td>
                        <td className="px-4 py-3 text-slate-700">{l.skill || '—'}</td>
                        <td className="px-4 py-3 text-right text-slate-700">
                          {formatCurrency(l.dailyWage)}
                        </td>
                        <td className="px-4 py-3 text-right text-slate-700">
                          {l.overtimeWagePerHour
                            ? formatCurrency(l.overtimeWagePerHour)
                            : '—'}
                        </td>
                        <td className="px-4 py-3 text-right text-slate-700">
                          {l.defaultOvertimeHours || '—'}
                        </td>
                        <td className="px-4 py-3 text-slate-700">
                          {sup?.name || '—'}
                        </td>
                        <td className="px-4 py-3">
                          <StatusBadge
                            status={l.isActive === false ? 'inactive' : 'active'}
                          />
                        </td>
                        {!isSupervisor && (
                          <td
                            className="px-4 py-3"
                            onClick={(e) => e.stopPropagation()}
                          >
                            <div className="flex items-center justify-end gap-2">
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => openEdit(l)}
                                className="gap-1 h-7 px-2 text-xs"
                              >
                                <Pencil className="h-3 w-3" /> Edit
                              </Button>
                              {l.isActive === false ? (
                                <Button
                                  variant="outline"
                                  size="sm"
                                  onClick={() => activateLabour(l.id).then(
                                    () => toast.success(`${l.name} activated`),
                                  )}
                                  className="gap-1 h-7 px-2 text-xs text-green-700"
                                >
                                  <RotateCcw className="h-3 w-3" />
                                </Button>
                              ) : (
                                <Button
                                  variant="outline"
                                  size="sm"
                                  onClick={() => deactivateLabour(l.id).then(
                                    () => toast.success(`${l.name} deactivated`),
                                  )}
                                  className="gap-1 h-7 px-2 text-xs text-red-600"
                                >
                                  <Ban className="h-3 w-3" />
                                </Button>
                              )}
                            </div>
                          </td>
                        )}
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <Pagination
              page={page}
              pageCount={pageCount}
              setPage={setPage}
              total={total}
              pageSize={pageSize}
              onPageSizeChange={setPageSize}
            />
          </>
        )}
      </div>

      {/* Add / Edit Dialog */}
      <Modal
        isOpen={dialogOpen}
        title={editing ? 'Edit Labour' : 'Add Labour'}
        onClose={() => !saving && setDialogOpen(false)}
        onConfirm={handleSubmit}
        confirmText={saving ? 'Saving…' : editing ? 'Save changes' : 'Add labour'}
      >
        <div className="space-y-4">
          <div className="space-y-1">
            <Label>Name *</Label>
            <Input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Full name"
            />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Phone</Label>
              <Input
                value={form.phone}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
                placeholder="Optional"
              />
            </div>
            <div className="space-y-1">
              <Label>Skill</Label>
              <Input
                value={form.skill}
                onChange={(e) => setForm({ ...form, skill: e.target.value })}
                placeholder="e.g. Mason"
              />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-3">
            <div className="space-y-1">
              <Label>Daily Wage (₹)</Label>
              <Input
                type="number"
                value={form.dailyWage}
                onChange={(e) => setForm({ ...form, dailyWage: e.target.value })}
                placeholder="0"
              />
            </div>
            <div className="space-y-1">
              <Label>OT Rate (₹/hr)</Label>
              <Input
                type="number"
                value={form.overtimeWagePerHour}
                onChange={(e) => setForm({ ...form, overtimeWagePerHour: e.target.value })}
                placeholder="0"
              />
            </div>
            <div className="space-y-1">
              <Label>Default OT Hrs/day</Label>
              <Input
                type="number"
                step="0.5"
                value={form.defaultOvertimeHours}
                onChange={(e) => setForm({ ...form, defaultOvertimeHours: e.target.value })}
                placeholder="0"
              />
            </div>
          </div>

          {/* FIXED SUPERVISOR DROPDOWN */}
          <div className="space-y-1">
            <Label>Supervisor *</Label>
            {supervisors.length === 0 ? (
              // No supervisors found — show helpful message
              <div className="rounded-md border border-orange-200 bg-orange-50 p-3 text-sm text-orange-700">
                No supervisors found for this contractor.
                Go to Users page and add a supervisor first.
              </div>
            ) : (
              <select
                value={form.supervisorId}
                onChange={(e) => setForm({ ...form, supervisorId: e.target.value })}
                className="h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
              >
                <option value="">Select supervisor</option>
                {/* FIX: Only show real supervisors from users collection */}
                {/* REMOVED: "Self" option that was using contractor UID */}
                {supervisors.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name}
                  </option>
                ))}
              </select>
            )}
            {/* Debug info — remove after testing */}
            {process.env.NODE_ENV === 'development' && (
              <p className="text-xs text-slate-400">
                {supervisors.length} supervisor(s) loaded ·
                contractorId: {activeContractorId?.slice(0, 8)}…
              </p>
            )}
          </div>

          {editing && (
            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={form.isActive}
                onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
              />
              Active
            </label>
          )}
        </div>
      </Modal>
    </div>
  );
}