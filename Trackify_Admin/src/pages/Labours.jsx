import { motion, AnimatePresence } from 'framer-motion';
import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import QRCode from 'qrcode';
import {
  Plus, Search, Pencil, Ban, RotateCcw, HardHat, ArrowUpDown, QrCode, Download, Printer,
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
  supervisorId: '',
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
  const [qrLabour, setQrLabour] = useState(null);
  const [qrDataUrl, setQrDataUrl] = useState('');
  const qrCanvasRef = useRef(null);
  const [bulkDownloading, setBulkDownloading] = useState(false);

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
          contractorId: activeContractorId,
          isActive: form.isActive,
        });
      } else {
        await addLabour({
          name: form.name.trim(),
          phone: form.phone.trim() || null,
          skill: form.skill.trim() || null,
          dailyWage: form.dailyWage,
          overtimeWagePerHour: form.overtimeWagePerHour,
          defaultOvertimeHours: form.defaultOvertimeHours,
          supervisorId: form.supervisorId,
          contractorId: activeContractorId,
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

  const openQr = async (labour) => {
    setQrLabour(labour);
    setQrDataUrl('');
    try {
      const payload = JSON.stringify({
        labourId: labour.id,
        name: labour.name,
        type: 'labour_qr',
        appId: import.meta.env.VITE_FIREBASE_PROJECT_ID || 'ys-construction',
      });
      const url = await QRCode.toDataURL(payload, {
        errorCorrectionLevel: 'H',
        margin: 2,
        width: 400,
        color: { dark: '#1e293b', light: '#ffffff' },
      });
      setQrDataUrl(url);
    } catch (e) {
      toast.error('QR generation failed');
    }
  };

  const downloadQr = () => {
    if (!qrDataUrl || !qrLabour) return;
    const a = document.createElement('a');
    a.href = qrDataUrl;
    a.download = `qr_${qrLabour.name.replace(/\s+/g, '_')}.png`;
    a.click();
  };

  const printQr = () => {
    if (!qrDataUrl || !qrLabour) return;
    const win = window.open('', '_blank');
    win.document.write(`<html><head><title>QR – ${qrLabour.name}</title><style>body{text-align:center;font-family:sans-serif;padding:20px}img{max-width:300px}h2{margin:10px 0 4px}p{color:#64748b;font-size:13px;margin:0}</style></head><body><h2>${qrLabour.name}</h2><p>${qrLabour.skill || 'Labour'} · ₹${qrLabour.dailyWage || 0}/day</p><br><img src="${qrDataUrl}" /><br><button onclick="window.print()">🖨 Print</button></body></html>`);
    win.document.close();
  };

  const bulkDownloadQR = async () => {
    const targets = selected.size > 0
      ? filtered.filter((l) => selected.has(l.id))
      : filtered.filter((l) => l.isActive !== false);
    if (targets.length === 0) return toast.error('No labours to download');
    if (targets.length > 200) return toast.error('Too many labours — select a subset first');

    setBulkDownloading(true);
    const t = toast.loading(`Generating QR codes for ${targets.length} labours…`);
    try {
      const JSZip = (await import('jszip')).default;
      const zip = new JSZip();
      const appId = import.meta.env.VITE_FIREBASE_PROJECT_ID || 'ys-construction';

      await Promise.all(
        targets.map(async (l) => {
          const payload = JSON.stringify({
            labourId: l.id,
            name: l.name,
            type: 'labour_qr',
            appId,
          });
          const dataUrl = await QRCode.toDataURL(payload, {
            errorCorrectionLevel: 'H',
            margin: 2,
            width: 400,
            color: { dark: '#1e293b', light: '#ffffff' },
          });
          const base64 = dataUrl.split(',')[1];
          const safeName = l.name.replace(/[^a-zA-Z0-9_\- ]/g, '').trim().replace(/\s+/g, '_');
          zip.file(`${safeName}_${l.id.slice(0, 6)}.png`, base64, { base64: true });
        }),
      );

      const blob = await zip.generateAsync({ type: 'blob' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `labour_qr_codes_${new Date().toISOString().slice(0, 10)}.zip`;
      a.click();
      URL.revokeObjectURL(url);
      toast.dismiss(t);
      toast.success(`Downloaded ${targets.length} QR codes`);
    } catch (e) {
      console.error('Bulk QR error:', e);
      toast.dismiss(t);
      toast.error('Bulk QR download failed');
    } finally {
      setBulkDownloading(false);
    }
  };

  const SortHeader = ({ field, label }) => (
    <button
      onClick={() => toggleSort(field)}
      className="flex items-center gap-1 hover:text-text-primary transition-colors"
    >
      {label}
      <ArrowUpDown
        className={`h-3.5 w-3.5 ${sortBy === field ? 'text-gold' : 'text-text-muted'}`}
      />
    </button>
  );

  return (
    <div className="space-y-6">
      
      <div className="bg-purple-900/20 border border-purple-500/30 text-purple-300 px-4 py-3 rounded-lg flex items-start gap-3">
        <svg className="w-5 h-5 mt-0.5 text-purple-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
        </svg>
        <div>
          <p className="font-medium text-sm text-purple-200">Temporary Labours Auto-Hide</p>
          <p className="text-xs opacity-80 mt-1">
            Labours marked as "temporary" in the app are only visible for the day they are added. 
            They will automatically be hidden tomorrow to keep your list clean.
          </p>
        </div>
      </div>

      {/* Header bar */}
      <div className="rounded-xl border border-border bg-bg-card px-6 py-5 flex flex-wrap items-center justify-between gap-4">
        <div className="text-[13px] text-text-secondary uppercase tracking-widest font-medium">
          <span className="font-semibold text-text-primary mr-2">{labours.filter((l) => l.isActive !== false).length}</span> active labours · 
          Daily wage liability: <span className="font-semibold text-gold ml-1">{formatCurrency(totalWage)}</span><span className="text-text-muted">/day</span>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={bulkDownloadQR}
            disabled={bulkDownloading}
            title={selected.size > 0 ? `Download QR for ${selected.size} selected` : 'Download QR for all active labours'}
            className="flex h-9 items-center gap-2 rounded-lg border border-border-strong bg-bg-elevated px-4 text-[13px] font-medium text-text-secondary hover:text-text-primary transition-colors disabled:opacity-50"
          >
            <Download className="h-4 w-4" />
            {bulkDownloading ? 'Generating…' : selected.size > 0 ? `QR (${selected.size})` : 'Bulk QR'}
          </button>
          {!isSupervisor && (
            <button
              onClick={openAdd}
              className="flex h-9 items-center gap-2 rounded-lg bg-gold px-4 text-[13px] font-semibold text-bg-primary shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-105 transition-all"
            >
              <Plus className="h-4 w-4" /> Add Labour
            </button>
          )}
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-end gap-3 rounded-xl border border-border bg-bg-card px-5 py-3.5 mb-3">
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search name or phone…"
            className="h-9 w-56 rounded-lg border border-border-strong bg-bg-input pl-9 pr-3 text-[13px] text-text-primary placeholder:text-text-muted outline-none focus:border-gold focus:ring-1 focus:ring-gold"
          />
        </div>

        {!isSupervisor && supervisors.length > 0 && (
          <div className="space-y-1.5 flex flex-col">
            <label className="text-[10px] uppercase tracking-widest text-text-muted font-medium ml-1">Supervisor</label>
            <select
              value={supervisorFilter}
              onChange={(e) => setSupervisorFilter(e.target.value)}
              className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary outline-none focus:border-gold focus:ring-1 focus:ring-gold"
            >
              <option value="all">All supervisors</option>
              {supervisors.map((s) => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
          </div>
        )}

        <div className="space-y-1.5 flex flex-col">
          <label className="text-[10px] uppercase tracking-widest text-text-muted font-medium ml-1">Status</label>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary outline-none focus:border-gold focus:ring-1 focus:ring-gold"
          >
            <option value="all">All</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
          </select>
        </div>

        {selected.size > 0 && !isSupervisor && (
          <div className="flex gap-2 ml-auto">
            <button
              onClick={() => bulkAction('activate')}
              className="flex h-9 items-center gap-1.5 rounded-lg border border-success/30 bg-success-bg px-4 text-[12px] font-medium text-success hover:bg-success hover:text-bg-primary transition-colors"
            >
              Activate {selected.size}
            </button>
            <button
              onClick={() => bulkAction('deactivate')}
              className="flex h-9 items-center gap-1.5 rounded-lg border border-danger/30 bg-danger-bg px-4 text-[12px] font-medium text-danger hover:bg-danger hover:text-white transition-colors"
            >
              Deactivate {selected.size}
            </button>
          </div>
        )}
      </div>

      {/* Table */}
      <div className="rounded-xl border border-border bg-bg-card overflow-hidden">
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
              <table className="w-full text-[13px]">
                <thead className="sticky top-0 border-b border-border bg-bg-elevated text-left text-[10px] uppercase tracking-widest text-text-muted">
                  <tr>
                    {!isSupervisor && (
                      <th className="px-5 py-3 w-10">
                        <input
                          type="checkbox"
                          checked={selected.size === paginated.length && paginated.length > 0}
                          onChange={toggleAll}
                          className="accent-gold h-4 w-4 cursor-pointer"
                        />
                      </th>
                    )}
                    <th className="px-5 py-3 font-medium">
                      <SortHeader field="name" label="Name" />
                    </th>
                    <th className="px-5 py-3 font-medium">Phone</th>
                    <th className="px-5 py-3 font-medium">Skill</th>
                    <th className="px-5 py-3 font-medium text-right">
                      <SortHeader field="dailyWage" label="Daily Wage" />
                    </th>
                    <th className="px-5 py-3 font-medium text-right">
                      <SortHeader field="overtimeWagePerHour" label="OT Rate/hr" />
                    </th>
                    <th className="px-5 py-3 font-medium text-right">Default OT Hrs</th>
                    <th className="px-5 py-3 font-medium">Supervisor</th>
                    <th className="px-5 py-3 font-medium">Status</th>
                    {!isSupervisor && (
                      <th className="px-5 py-3 font-medium text-right">Actions</th>
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
                        className={`border-b border-border last:border-b-0 cursor-pointer transition-colors hover:bg-bg-card-hover ${selected.has(l.id) ? 'bg-gold/5' : ''}`}
                      >
                        {!isSupervisor && (
                          <td
                            className="px-5 py-3 w-10"
                            onClick={(e) => e.stopPropagation()}
                          >
                            <input
                              type="checkbox"
                              checked={selected.has(l.id)}
                              onChange={() => toggleSelect(l.id)}
                              className="accent-gold h-4 w-4 cursor-pointer"
                            />
                          </td>
                        )}
                        <td className="px-5 py-3">
                          <div className="flex items-center gap-3">
                            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-info/20 border border-info/30 text-[12px] font-mono font-medium text-info">
                              {(l.name || '?')[0].toUpperCase()}
                            </div>
                            <span className="font-medium text-text-primary group-hover:text-gold transition-colors">
                              {l.name}
                            </span>
                          </div>
                        </td>
                        <td className="px-5 py-3 font-mono text-text-secondary">{l.phone || '—'}</td>
                        <td className="px-5 py-3 text-text-secondary">{l.skill || '—'}</td>
                        <td className="px-5 py-3 text-right font-mono text-text-secondary">
                          {formatCurrency(l.dailyWage)}
                        </td>
                        <td className="px-5 py-3 text-right font-mono text-text-secondary">
                          {l.overtimeWagePerHour
                            ? formatCurrency(l.overtimeWagePerHour)
                            : '—'}
                        </td>
                        <td className="px-5 py-3 text-right font-mono text-text-secondary">
                          {l.defaultOvertimeHours || '—'}
                        </td>
                        <td className="px-5 py-3 text-text-secondary">
                          {sup?.name || '—'}
                        </td>
                        <td className="px-5 py-3">
                          <StatusBadge
                            status={l.isActive === false ? 'inactive' : 'active'}
                          />
                        </td>
                        <td
                          className="px-5 py-3"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <div className="flex items-center justify-end gap-2">
                            <button
                              onClick={() => openQr(l)}
                              className="flex h-7 items-center gap-1.5 rounded-md border border-purple-500/30 bg-purple-500/10 px-2 text-[11px] font-medium text-purple-400 hover:bg-purple-500 hover:text-white transition-colors"
                              title="Show QR code"
                            >
                              <QrCode className="h-3 w-3" /> QR
                            </button>
                            {!isSupervisor && (
                              <>
                                <button
                                  onClick={() => openEdit(l)}
                                  className="flex h-7 items-center gap-1.5 rounded-md border border-border-strong bg-bg-elevated px-2 text-[11px] font-medium text-text-secondary hover:text-text-primary hover:border-gold transition-colors"
                                >
                                  <Pencil className="h-3 w-3" /> Edit
                                </button>
                                {l.isActive === false ? (
                                  <button
                                    onClick={() => activateLabour(l.id).then(
                                      () => toast.success(`${l.name} activated`),
                                    )}
                                    className="flex h-7 items-center gap-1.5 rounded-md border border-success/30 bg-success-bg px-2 text-[11px] font-medium text-success hover:bg-success hover:text-bg-primary transition-colors"
                                  >
                                    <RotateCcw className="h-3 w-3" />
                                  </button>
                                ) : (
                                  <button
                                    onClick={() => deactivateLabour(l.id).then(
                                      () => toast.success(`${l.name} deactivated`),
                                    )}
                                    className="flex h-7 items-center gap-1.5 rounded-md border border-danger/30 bg-danger-bg px-2 text-[11px] font-medium text-danger hover:bg-danger hover:text-white transition-colors"
                                  >
                                    <Ban className="h-3 w-3" />
                                  </button>
                                )}
                              </>
                            )}
                          </div>
                        </td>
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
              <div className="rounded-md border border-warning/25 bg-warning-bg p-3 text-[13px] text-warning">
                No supervisors found for this contractor.
                Go to Users page and add a supervisor first.
              </div>
            ) : (
              <select
                value={form.supervisorId}
                onChange={(e) => setForm({ ...form, supervisorId: e.target.value })}
                className="flex h-9 w-full rounded-lg border border-border-strong bg-bg-input px-3 py-2 text-[13px] text-text-primary shadow-sm outline-none transition-colors focus:border-gold focus:ring-1 focus:ring-gold"
              >
                <option value="" className="text-text-muted">Select supervisor</option>
                {supervisors.map((s) => (
                  <option key={s.id} value={s.id} className="text-text-primary">
                    {s.name}
                  </option>
                ))}
              </select>
            )}
          </div>

          {editing && (
            <label className="flex items-center gap-2 text-[13px] text-text-primary">
              <input
                type="checkbox"
                checked={form.isActive}
                onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
                className="accent-gold h-4 w-4 cursor-pointer"
              />
              Active
            </label>
          )}
        </div>
      </Modal>

      {/* QR Code Modal */}
      <AnimatePresence>
        {qrLabour && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4" onClick={() => setQrLabour(null)}>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.2 }}
              className="absolute inset-0 bg-bg-primary/80 backdrop-blur-sm"
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.9, y: 10 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.9, y: 10 }}
              transition={{ type: 'spring', damping: 25, stiffness: 300 }}
              className="relative w-full max-w-xs rounded-2xl border border-border bg-bg-card p-6 shadow-[0_25px_60px_rgba(0,0,0,0.6)]"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="mb-4 text-center">
                <div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-xl bg-info-bg border border-info/20">
                  <QrCode className="h-6 w-6 text-info" />
                </div>
                <h3 className="text-[16px] font-semibold text-text-primary">{qrLabour.name}</h3>
                <p className="text-[12px] text-text-secondary mt-1">{qrLabour.skill || 'Labour'} · {formatCurrency(qrLabour.dailyWage || 0)}/day</p>
              </div>
              <div className="flex justify-center rounded-xl border border-border-strong bg-white p-4 mx-auto w-[210px]">
                {qrDataUrl ? (
                  <img src={qrDataUrl} alt={`QR for ${qrLabour.name}`} className="h-40 w-40" />
                ) : (
                  <div className="flex h-40 w-40 items-center justify-center">
                    <span className="text-[12px] text-text-muted">Generating…</span>
                  </div>
                )}
              </div>
              <p className="mt-4 text-center text-[11px] text-text-muted tracking-wide">Scan with the Trackify mobile app</p>
              <div className="mt-5 grid grid-cols-2 gap-3">
                <Button onClick={printQr} variant="secondary" className="w-full h-10 text-[13px] bg-bg-elevated border-border-strong hover:bg-bg-card-hover hover:text-text-primary">
                  <Printer className="mr-2 h-4 w-4" /> Print
                </Button>
                <Button onClick={downloadQr} className="w-full h-10 text-[13px] bg-gold hover:bg-gold-dark text-bg-primary">
                  <Download className="mr-2 h-4 w-4" /> Save
                </Button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}