import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Calendar, Save, CheckCheck, ClipboardList, Download, ChevronLeft, ChevronRight, Search, X, Plus, Shield, ChevronDown, ChevronUp, MessageSquare, MapPin, Building2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { useLabours } from '../hooks/useLabours';
import { useAttendanceByDate } from '../hooks/useAttendance';
import { bulkMarkAttendance, getAttendanceRange, updateAttendanceRemark } from '../lib/services/attendance.service';
import { addTemporaryLabour } from '../lib/services/labours.service';
import { subscribeSites } from '../lib/services/sites.service';
import { todayKey, toDateKey, exportCSV, formatCurrency } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import StatusBadge from '../components/shared/StatusBadge';

const STATUS_CYCLE = ['present', 'absent', 'half'];
const STATUS_OPTIONS = [
  { value: 'present', label: 'Present' },
  { value: 'absent', label: 'Absent' },
  { value: 'half', label: 'Half day' },
];

function cycleStatus(current) {
  const idx = STATUS_CYCLE.indexOf(current);
  return STATUS_CYCLE[(idx + 1) % STATUS_CYCLE.length];
}

function shiftDate(dateStr, days) {
  const d = new Date(dateStr + 'T00:00:00');
  d.setDate(d.getDate() + days);
  return toDateKey(d);
}

function defaultRow(labour) {
  return {
    labourId: labour.id,
    status: 'present',
    overtimeHours: Number(labour.defaultOvertimeHours) || 0,
    remark: '',
    wageAtTime: Number(labour.dailyWage) || 0,
    siteId: '',
  };
}

function initials(name) {
  return (name || '?').split(' ').map((w) => w[0]).join('').toUpperCase().slice(0, 2);
}

export default function Attendance() {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeFromStore = useScopeId();
  const isSupervisor = role === 'supervisor';
  const writeScope = isSupervisor ? uid : scopeFromStore;

  const [date, setDate] = useState(todayKey());
  const [rows, setRows] = useState({});
  const [saving, setSaving] = useState(false);
  const [safetyNetOpen, setSafetyNetOpen] = useState(false);

  const [showTempDialog, setShowTempDialog] = useState(false);
  const [tempName, setTempName] = useState('');
  const [tempWage, setTempWage] = useState('');
  const [addingTemp, setAddingTemp] = useState(false);

  const [supervisorFilter, setSupervisorFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [editingOT, setEditingOT] = useState(null);
  const [editingRemark, setEditingRemark] = useState(null);
  const [sites, setSites] = useState([]);
  const [viewMode, setViewMode] = useState('all'); // 'all' | 'bysite'

  const { data: labours, isLoading: loadingLabours } = useLabours();
  const { records, isLoading: loadingRecords } = useAttendanceByDate(date);

  useEffect(() => {
    const contractorId = isSupervisor ? scopeFromStore : writeScope;
    if (!contractorId) return;
    const unsub = subscribeSites(contractorId, setSites);
    return unsub;
  }, [writeScope, scopeFromStore, isSupervisor]);

  useEffect(() => {
    const next = {};
    labours.forEach((l) => {
      const existing = records.find((r) => r.labourId === l.id);
      if (existing) {
        next[l.id] = {
          labourId: l.id,
          status: existing.status || 'present',
          overtimeHours: Number(existing.overtimeHours) || 0,
          remark: existing.remark || existing.notes || '',
          wageAtTime: Number(existing.wageAtTime) || Number(l.dailyWage) || 0,
          siteId: existing.siteId || '',
          recordId: existing.id,
        };
      } else {
        const localRow = rows[l.id];
        if (localRow) {
          next[l.id] = localRow;
        } else {
          next[l.id] = defaultRow(l);
        }
      }
    });
    setRows(next);
  }, [labours, records]);

  const updateRow = (labourId, patch) => {
    setRows((prev) => ({ ...prev, [labourId]: { ...prev[labourId], ...patch } }));
  };

  const clickStatus = (labourId) => {
    setRows((prev) => ({
      ...prev,
      [labourId]: { ...prev[labourId], status: cycleStatus(prev[labourId]?.status || 'present') },
    }));
  };

  const markAll = (status) => {
    const next = {};
    labours.forEach((l) => { next[l.id] = { ...rows[l.id], labourId: l.id, status }; });
    setRows(next);
    toast.success(`All marked ${status}`);
  };

  const copyYesterday = useCallback(async () => {
    const yesterday = shiftDate(date, -1);
    const t = toast.loading("Loading yesterday's attendance…");
    try {
      const contractorId = isSupervisor ? scopeFromStore : writeScope;
      const recs = await getAttendanceRange(contractorId, yesterday, yesterday, null, isSupervisor, isSupervisor ? uid : null);
      if (recs.length === 0) { toast.dismiss(t); toast.error('No attendance found for yesterday'); return; }
      const next = { ...rows };
      recs.forEach((r) => {
        if (next[r.labourId]) {
          next[r.labourId] = { ...next[r.labourId], status: r.status, overtimeHours: Number(r.overtimeHours) || 0, remark: r.remark || '' };
        }
      });
      setRows(next);
      toast.dismiss(t);
      toast.success('Copied yesterday\'s attendance');
    } catch (e) {
      toast.dismiss(t);
      toast.error('Failed to load yesterday');
    }
  }, [date, rows, writeScope, scopeFromStore, isSupervisor, uid]);

  const handleSave = async () => {
    if (!writeScope) { toast.error('Pick a contractor in the header before saving'); return; }
    if (labours.length === 0) { toast.error('No labours to mark'); return; }
    const dataToSave = labours.map((l) => {
      const r = rows[l.id] || defaultRow(l);
      return { ...r, wageAtTime: Number(l.dailyWage) || 0 };
    });
    const hasValidData = dataToSave.every((r) => r.status && r.labourId);
    if (!hasValidData) { toast.error('Invalid attendance data'); return; }
    setSaving(true);
    const t = toast.loading('Saving attendance…');
    try {
      const contractorId = isSupervisor ? scopeFromStore : writeScope;
      await bulkMarkAttendance(contractorId, date, dataToSave, isSupervisor, isSupervisor ? uid : null);
      toast.dismiss(t);
      toast.success('Attendance saved');
    } catch (err) {
      console.error('Save error:', err);
      toast.dismiss(t);
      toast.error('Failed to save: ' + (err.message || 'Unknown error'));
    } finally {
      setSaving(false);
    }
  };

  const handleRemarkSave = async (labourId) => {
    const row = rows[labourId];
    if (!row?.recordId) return;
    try {
      await updateAttendanceRemark(row.recordId, row.remark || '');
    } catch (e) {
      console.error('Failed to save remark:', e);
    }
    setEditingRemark(null);
  };

  const handleAddTempLabour = async () => {
    if (!tempName.trim()) { toast.error('Enter a name'); return; }
    const wage = parseFloat(tempWage);
    if (!wage || wage <= 0) { toast.error('Enter a valid daily wage'); return; }
    if (!writeScope) { toast.error('Select a contractor first'); return; }
    setAddingTemp(true);
    try {
      const contractorId = isSupervisor ? scopeFromStore : writeScope;
      const labour = await addTemporaryLabour(contractorId, uid || writeScope, tempName.trim(), wage);
      const dataToSave = [{ labourId: labour.id, status: 'present', overtimeHours: 0, remark: '', wageAtTime: wage, siteId: uid || writeScope }];
      await bulkMarkAttendance(contractorId, date, dataToSave, isSupervisor, isSupervisor ? uid : null);
      toast.success(`${tempName.trim()} added & marked present`);
      setTempName('');
      setTempWage('');
      setShowTempDialog(false);
    } catch (err) {
      toast.error('Failed to add temp labour: ' + err.message);
    } finally {
      setAddingTemp(false);
    }
  };

  const handleExport = () => {
    const rows2 = labours.map((l) => {
      const r = rows[l.id] || defaultRow(l);
      return { Date: date, Labour: l.name, Phone: l.phone || '', Status: r.status, 'OT Hours': r.overtimeHours, Remark: r.remark || '', 'Wage At Time': r.wageAtTime || l.dailyWage };
    });
    exportCSV(`attendance-${date}.csv`, rows2);
    toast.success('CSV downloaded');
  };

  const supervisorIds = useMemo(() => {
    const ids = [...new Set(labours.map((l) => l.supervisorId).filter(Boolean))];
    return ids;
  }, [labours]);

  const markedLabourIds = useMemo(() => new Set(records.map((r) => r.labourId)), [records]);

  const filtered = useMemo(() => {
    return labours.filter((l) => {
      if (search && !l.name?.toLowerCase().includes(search.toLowerCase()) && !l.phone?.includes(search)) return false;
      if (supervisorFilter !== 'all' && l.supervisorId !== supervisorFilter) return false;
      if (statusFilter !== 'all' && rows[l.id]?.status !== statusFilter) return false;
      return true;
    });
  }, [labours, rows, search, supervisorFilter, statusFilter]);

  const pendingLabours = useMemo(() => filtered.filter((l) => !markedLabourIds.has(l.id)), [filtered, markedLabourIds]);
  const alreadyMarked = useMemo(() => filtered.filter((l) => markedLabourIds.has(l.id)), [filtered, markedLabourIds]);

  const summary = useMemo(() => {
    const s = { present: 0, absent: 0, half: 0, totalOT: 0 };
    Object.values(rows).forEach((r) => {
      if (s[r.status] !== undefined) s[r.status]++;
      s.totalOT += Number(r.overtimeHours) || 0;
    });
    return s;
  }, [rows]);

  const wageLiability = useMemo(() => {
    let total = 0;
    labours.forEach((l) => {
      const r = rows[l.id];
      if (!r) return;
      const wage = Number(l.dailyWage) || 0;
      const otRate = Number(l.overtimeWagePerHour) || 0;
      if (r.status === 'present') total += wage + (Number(r.overtimeHours) || 0) * otRate;
      else if (r.status === 'half') total += wage / 2 + (Number(r.overtimeHours) || 0) * otRate;
    });
    return total;
  }, [labours, rows]);

  const dayName = useMemo(() => {
    try { return new Date(date + 'T00:00:00').toLocaleDateString('en-IN', { weekday: 'long' }); }
    catch { return ''; }
  }, [date]);

  const tableRows = (list) => list.map((l) => {
    const row = rows[l.id] || defaultRow(l);
    const dailyWage = Number(l.dailyWage) || 0;
    const otRate = Number(l.overtimeWagePerHour) || 0;
    const otHours = Number(row.overtimeHours) || 0;
    let dayEarnings = 0;
    if (row.status === 'present') dayEarnings = dailyWage + otHours * otRate;
    else if (row.status === 'half') dayEarnings = dailyWage / 2 + otHours * otRate;

    return (
      <tr key={l.id} className="border-b border-slate-100 last:border-b-0 hover:bg-slate-50/60">
        <td className="px-4 py-3">
          <div className="flex items-center gap-3">
            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-xs font-semibold text-blue-700">
              {initials(l.name)}
            </div>
            <div>
              <div className="font-medium text-slate-900">{l.name}</div>
              {l.skill && <div className="text-xs text-slate-500">{l.skill}</div>}
            </div>
          </div>
        </td>
        <td className="px-4 py-3 text-slate-700">{formatCurrency(dailyWage)}</td>
        <td className="px-4 py-3">
          <button onClick={() => clickStatus(l.id)} title="Click to cycle status" className="inline-block cursor-pointer transition-transform hover:scale-105 active:scale-95">
            <StatusBadge status={row.status} />
          </button>
          <select
            value={row.status}
            onChange={(e) => updateRow(l.id, { status: e.target.value })}
            className="ml-2 h-8 rounded border border-slate-200 bg-white px-2 text-xs text-slate-700 outline-none focus:border-blue-400"
          >
            {STATUS_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
        </td>
        <td className="px-4 py-3 text-right">
          {editingOT === l.id ? (
            <Input
              type="number" min="0" step="0.5"
              value={row.overtimeHours}
              onChange={(e) => updateRow(l.id, { overtimeHours: e.target.value })}
              onBlur={() => setEditingOT(null)}
              autoFocus
              className="h-8 w-20 text-right"
            />
          ) : (
            <button onClick={() => setEditingOT(l.id)} className="font-medium text-slate-900 underline-offset-2 hover:underline">
              {row.overtimeHours}
            </button>
          )}
        </td>
        <td className="px-4 py-3">
          {editingRemark === l.id ? (
            <Input
              type="text"
              value={row.remark || ''}
              onChange={(e) => updateRow(l.id, { remark: e.target.value })}
              onBlur={() => handleRemarkSave(l.id)}
              autoFocus
              placeholder="Add remark…"
              className="h-8 w-40 text-xs"
            />
          ) : (
            <button
              onClick={() => setEditingRemark(l.id)}
              className="flex items-center gap-1 text-xs text-slate-500 hover:text-slate-800"
              title="Click to add remark"
            >
              <MessageSquare className="h-3 w-3" />
              <span className="max-w-28 truncate">{row.remark || '—'}</span>
            </button>
          )}
        </td>
        <td className="px-4 py-3 text-right font-semibold text-slate-900">{formatCurrency(dayEarnings)}</td>
        <td className="px-4 py-3 text-center">
          {row.recordId ? <span className="text-xs font-medium text-green-700">✓</span> : <span className="text-xs text-slate-400">—</span>}
        </td>
      </tr>
    );
  });

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight text-slate-950">Attendance</h2>
          <p className="mt-1 text-sm text-slate-500">
            {dayName} · {labours.length} labour{labours.length !== 1 ? 's' : ''} · {records.length} marked · {pendingLabours.length} pending
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Button variant="outline" onClick={() => setDate(shiftDate(date, -1))} className="h-10 w-10 p-0"><ChevronLeft className="h-4 w-4" /></Button>
          <div className="flex items-center gap-2">
            <Calendar className="h-4 w-4 text-slate-500" />
            <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} className="h-10 w-44" />
          </div>
          <Button variant="outline" onClick={() => setDate(shiftDate(date, 1))} className="h-10 w-10 p-0"><ChevronRight className="h-4 w-4" /></Button>
          {date !== todayKey() && (
            <Button variant="outline" onClick={() => setDate(todayKey())} className="h-10 px-3 text-xs">Today</Button>
          )}
        </div>
      </div>

      <div className="flex flex-wrap items-end gap-3 rounded-2xl border border-slate-200/70 bg-white/90 p-4 shadow-sm">
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
          <Input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search name or phone…" className="h-10 w-48 pl-9" />
        </div>
        <div className="space-y-0.5">
          <Label className="text-xs text-slate-500">Status</Label>
          <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="h-10 rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500">
            <option value="all">All statuses</option>
            {STATUS_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button variant="outline" onClick={() => markAll('present')} className="gap-1 text-green-700 text-xs"><CheckCheck className="h-4 w-4" /> All present</Button>
          <Button variant="outline" onClick={() => markAll('absent')} className="gap-1 text-red-600 text-xs"><X className="h-4 w-4" /> All absent</Button>
          <Button variant="outline" onClick={copyYesterday} className="gap-1 text-xs"><Calendar className="h-4 w-4" /> Copy yesterday</Button>
          <Button variant="outline" onClick={() => setShowTempDialog(true)} className="gap-1 text-purple-700 text-xs border-purple-200 hover:bg-purple-50">
            <Plus className="h-4 w-4" /> Temp Labour
          </Button>
          <Button variant="outline" onClick={handleExport} className="gap-1 text-xs"><Download className="h-4 w-4" /> CSV</Button>
          {sites.length > 0 && (
            <div className="flex rounded-lg border border-slate-200 overflow-hidden">
              <button
                onClick={() => setViewMode('all')}
                className={`px-3 py-1.5 text-xs font-medium transition-colors ${viewMode === 'all' ? 'bg-blue-600 text-white' : 'bg-white text-slate-600 hover:bg-slate-50'}`}
              >All</button>
              <button
                onClick={() => setViewMode('bysite')}
                className={`px-3 py-1.5 text-xs font-medium transition-colors border-l border-slate-200 flex items-center gap-1 ${viewMode === 'bysite' ? 'bg-blue-600 text-white border-blue-600' : 'bg-white text-slate-600 hover:bg-slate-50'}`}
              >
                <MapPin className="h-3 w-3" /> By Site
              </button>
            </div>
          )}
          <Button onClick={handleSave} disabled={saving || labours.length === 0} className="gap-2 bg-blue-600 text-white hover:bg-blue-700">
            <Save className="h-4 w-4" /> {saving ? 'Saving…' : 'Save'}
          </Button>
        </div>
      </div>

      {showTempDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-2xl">
            <div className="flex items-center gap-2 mb-4">
              <div className="flex h-8 w-8 items-center justify-center rounded-full bg-purple-100">
                <Plus className="h-4 w-4 text-purple-700" />
              </div>
              <h3 className="text-base font-semibold text-slate-900">Add Temporary Labour</h3>
            </div>
            <p className="mb-4 text-xs text-slate-500">Temp labours are marked present for today only and don't appear in the regular pool.</p>
            <div className="space-y-3">
              <div>
                <Label className="text-xs text-slate-600">Name</Label>
                <Input value={tempName} onChange={(e) => setTempName(e.target.value)} placeholder="Full name" className="mt-1 h-9" autoFocus />
              </div>
              <div>
                <Label className="text-xs text-slate-600">Daily Wage (₹)</Label>
                <Input type="number" value={tempWage} onChange={(e) => setTempWage(e.target.value)} placeholder="e.g. 500" className="mt-1 h-9" />
              </div>
            </div>
            <div className="mt-5 flex gap-2">
              <Button variant="outline" onClick={() => { setShowTempDialog(false); setTempName(''); setTempWage(''); }} className="flex-1">Cancel</Button>
              <Button onClick={handleAddTempLabour} disabled={addingTemp} className="flex-1 bg-purple-600 text-white hover:bg-purple-700">
                {addingTemp ? 'Adding…' : 'Add & Mark Present'}
              </Button>
            </div>
          </div>
        </div>
      )}

      {isSupervisor && (
        <div className="rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-700">
          Showing your assigned labours only.
        </div>
      )}

      <div className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm text-sm">
        <div className="flex flex-wrap gap-4">
          <span>Total: <strong>{labours.length}</strong></span>
          <span className="text-green-700">Present: <strong>{summary.present}</strong></span>
          <span className="text-red-600">Absent: <strong>{summary.absent}</strong></span>
          <span className="text-amber-600">Half: <strong>{summary.half}</strong></span>
          <span className="text-slate-500">OT Hours: <strong>{summary.totalOT}</strong></span>
          <span className="text-slate-700 font-semibold">Wage liability: {formatCurrency(wageLiability)}</span>
          <span className="text-blue-700">Pending: <strong>{pendingLabours.length}</strong></span>
        </div>
      </div>

      {/* ── BY-SITE VIEW ──────────────────────────────────────────────── */}
      {viewMode === 'bysite' && (
        <div className="space-y-4">
          {loadingLabours || loadingRecords ? (
            <LoadingSpinner label="Loading attendance…" />
          ) : (
            <>
              {(() => {
                const siteMap = Object.fromEntries(sites.map((s) => [s.id, s.name]));
                const grouped = {};
                labours.forEach((l) => {
                  const key = l.siteId && siteMap[l.siteId] ? l.siteId : '__unassigned__';
                  if (!grouped[key]) grouped[key] = [];
                  grouped[key].push(l);
                });

                const renderSiteBlock = (siteId, siteLabours) => {
                  const siteName = siteId === '__unassigned__' ? 'Unassigned' : (siteMap[siteId] || siteId);
                  let siteTotal = 0;
                  let sitePresent = 0, siteAbsent = 0, siteHalf = 0;
                  siteLabours.forEach((l) => {
                    const row = rows[l.id] || defaultRow(l);
                    const wage = Number(l.dailyWage) || 0;
                    const otRate = Number(l.overtimeWagePerHour) || 0;
                    const otH = Number(row.overtimeHours) || 0;
                    if (row.status === 'present') { siteTotal += wage + otH * otRate; sitePresent++; }
                    else if (row.status === 'half')  { siteTotal += wage / 2 + otH * otRate; siteHalf++; }
                    else if (row.status === 'absent') { siteAbsent++; }
                  });

                  return (
                    <div key={siteId} className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm overflow-hidden">
                      <div className={`flex items-center justify-between px-5 py-3 ${siteId === '__unassigned__' ? 'bg-slate-50 border-b border-slate-200' : 'bg-blue-50 border-b border-blue-100'}`}>
                        <div className="flex items-center gap-2">
                          {siteId === '__unassigned__'
                            ? <Building2 className="h-4 w-4 text-slate-400" />
                            : <MapPin className="h-4 w-4 text-blue-600" />}
                          <span className={`font-semibold text-sm ${siteId === '__unassigned__' ? 'text-slate-500' : 'text-blue-800'}`}>{siteName}</span>
                          <span className="ml-1 rounded-full bg-white/80 border border-slate-200 px-2 py-0.5 text-xs font-medium text-slate-600">{siteLabours.length} labours</span>
                        </div>
                        <div className="flex items-center gap-3 text-xs">
                          <span className="text-green-700 font-medium">P: {sitePresent}</span>
                          <span className="text-red-600 font-medium">A: {siteAbsent}</span>
                          <span className="text-amber-600 font-medium">H: {siteHalf}</span>
                          <span className="font-bold text-slate-800">Net: {formatCurrency(siteTotal)}</span>
                        </div>
                      </div>
                      <div className="overflow-x-auto">
                        <table className="w-full text-sm">
                          <thead className="border-b border-slate-100 text-left text-xs uppercase tracking-wide text-slate-400">
                            <tr>
                              <th className="px-4 py-2">Labour</th>
                              <th className="px-4 py-2">Daily Wage</th>
                              <th className="px-4 py-2">Status</th>
                              <th className="px-4 py-2 text-right">OT Hrs</th>
                              <th className="px-4 py-2">Remark</th>
                              <th className="px-4 py-2 text-right font-semibold text-slate-600">Net Pay</th>
                              <th className="px-4 py-2 text-center">Saved</th>
                            </tr>
                          </thead>
                          <tbody>
                            {siteLabours.map((l) => {
                              const row = rows[l.id] || defaultRow(l);
                              const wage = Number(l.dailyWage) || 0;
                              const otRate = Number(l.overtimeWagePerHour) || 0;
                              const otH = Number(row.overtimeHours) || 0;
                              let net = 0;
                              if (row.status === 'present') net = wage + otH * otRate;
                              else if (row.status === 'half') net = wage / 2 + otH * otRate;
                              const isSaved = !!row.recordId;
                              return (
                                <tr key={l.id} className="border-b border-slate-50 last:border-b-0 hover:bg-slate-50/60">
                                  <td className="px-4 py-3">
                                    <div className="flex items-center gap-2">
                                      <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-blue-100 text-xs font-semibold text-blue-700">{initials(l.name)}</div>
                                      <div>
                                        <div className="font-medium text-slate-900">{l.name}</div>
                                        {l.skill && <div className="text-xs text-slate-400">{l.skill}</div>}
                                      </div>
                                    </div>
                                  </td>
                                  <td className="px-4 py-3 text-slate-600">{formatCurrency(wage)}</td>
                                  <td className="px-4 py-3">
                                    <button onClick={() => clickStatus(l.id)} className="inline-block cursor-pointer hover:scale-105 active:scale-95">
                                      <StatusBadge status={row.status} />
                                    </button>
                                    <select value={row.status} onChange={(e) => updateRow(l.id, { status: e.target.value })} className="ml-2 h-7 rounded border border-slate-200 bg-white px-1.5 text-xs outline-none focus:border-blue-400">
                                      {STATUS_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
                                    </select>
                                  </td>
                                  <td className="px-4 py-3 text-right">
                                    {editingOT === l.id ? (
                                      <Input type="number" min="0" step="0.5" value={row.overtimeHours} onChange={(e) => updateRow(l.id, { overtimeHours: e.target.value })} onBlur={() => setEditingOT(null)} autoFocus className="h-7 w-16 text-right" />
                                    ) : (
                                      <button onClick={() => setEditingOT(l.id)} className="text-slate-700 hover:underline">{row.overtimeHours}</button>
                                    )}
                                  </td>
                                  <td className="px-4 py-3">
                                    {editingRemark === l.id ? (
                                      <Input type="text" value={row.remark || ''} onChange={(e) => updateRow(l.id, { remark: e.target.value })} onBlur={() => handleRemarkSave(l.id)} autoFocus className="h-7 w-32 text-xs" />
                                    ) : (
                                      <button onClick={() => setEditingRemark(l.id)} className="flex items-center gap-1 text-xs text-slate-400 hover:text-slate-700">
                                        <MessageSquare className="h-3 w-3" />
                                        <span className="max-w-24 truncate">{row.remark || '—'}</span>
                                      </button>
                                    )}
                                  </td>
                                  <td className="px-4 py-3 text-right font-bold text-slate-900">{formatCurrency(net)}</td>
                                  <td className="px-4 py-3 text-center">
                                    {isSaved ? <span className="text-xs font-semibold text-green-600">✓ Saved</span> : <span className="text-xs text-slate-300">—</span>}
                                  </td>
                                </tr>
                              );
                            })}
                          </tbody>
                          <tfoot>
                            <tr className="border-t-2 border-slate-200 bg-slate-50">
                              <td colSpan={5} className="px-4 py-2 text-xs font-semibold text-slate-500 uppercase tracking-wider">Site Total</td>
                              <td className="px-4 py-2 text-right text-sm font-bold text-blue-700">{formatCurrency(siteTotal)}</td>
                              <td />
                            </tr>
                          </tfoot>
                        </table>
                      </div>
                    </div>
                  );
                };

                const orderedSites = sites.filter((s) => grouped[s.id]);
                const hasUnassigned = !!grouped['__unassigned__'];

                return (
                  <>
                    {orderedSites.map((s) => renderSiteBlock(s.id, grouped[s.id]))}
                    {hasUnassigned && renderSiteBlock('__unassigned__', grouped['__unassigned__'])}
                    {labours.length === 0 && (
                      <div className="rounded-2xl border border-slate-200/70 bg-white/90 p-10 text-center text-slate-400 shadow-sm">No labours found.</div>
                    )}
                  </>
                );
              })()}
            </>
          )}
        </div>
      )}

      {/* ── ALL-LABOURS VIEW ──────────────────────────────────────────── */}
      {viewMode === 'all' && (
      <div className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm">
        {loadingLabours || loadingRecords ? (
          <LoadingSpinner label="Loading attendance…" />
        ) : labours.length === 0 ? (
          <EmptyState icon={ClipboardList} title="No labours to mark" description={isSupervisor ? 'No labours assigned to you.' : 'Add labours from the Labours page first.'} />
        ) : (
          <>
            {pendingLabours.length > 0 && (
              <>
                <div className="px-4 pt-4 pb-2 flex items-center gap-2">
                  <span className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                    Pending — {pendingLabours.length}
                  </span>
                  <div className="h-px flex-1 bg-slate-100" />
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className="sticky top-0 border-b border-slate-200 bg-white text-left text-xs uppercase tracking-wide text-slate-500">
                      <tr>
                        <th className="px-4 py-3">Labour</th>
                        <th className="px-4 py-3">Daily Wage</th>
                        <th className="px-4 py-3">Status</th>
                        <th className="px-4 py-3 text-right">OT Hours</th>
                        <th className="px-4 py-3">Remark</th>
                        <th className="px-4 py-3 text-right">Day Earnings</th>
                        <th className="px-4 py-3 text-center">Saved</th>
                      </tr>
                    </thead>
                    <tbody>{tableRows(pendingLabours)}</tbody>
                  </table>
                </div>
              </>
            )}

            {alreadyMarked.length > 0 && (
              <div className="border-t border-amber-100 bg-amber-50/60">
                <button
                  onClick={() => setSafetyNetOpen((o) => !o)}
                  className="flex w-full items-center gap-3 px-4 py-3 text-left"
                >
                  <Shield className="h-4 w-4 text-amber-600" />
                  <div className="flex-1">
                    <span className="text-sm font-semibold text-amber-800">
                      Already Marked Today — {alreadyMarked.length}
                    </span>
                    <span className="ml-2 text-xs text-amber-600">Review &amp; fix before day locks</span>
                  </div>
                  {safetyNetOpen ? <ChevronUp className="h-4 w-4 text-amber-600" /> : <ChevronDown className="h-4 w-4 text-amber-600" />}
                </button>

                {safetyNetOpen && (
                  <div className="overflow-x-auto border-t border-amber-100">
                    <table className="w-full text-sm">
                      <thead className="border-b border-amber-100 text-left text-xs uppercase tracking-wide text-amber-700 bg-amber-50">
                        <tr>
                          <th className="px-4 py-2">Labour</th>
                          <th className="px-4 py-2">Daily Wage</th>
                          <th className="px-4 py-2">Status</th>
                          <th className="px-4 py-2 text-right">OT Hours</th>
                          <th className="px-4 py-2">Remark</th>
                          <th className="px-4 py-2 text-right">Day Earnings</th>
                          <th className="px-4 py-2">Site</th>
                        </tr>
                      </thead>
                      <tbody>
                        {alreadyMarked.map((l) => {
                          const row = rows[l.id] || defaultRow(l);
                          const dailyWage = Number(l.dailyWage) || 0;
                          const otRate = Number(l.overtimeWagePerHour) || 0;
                          const otHours = Number(row.overtimeHours) || 0;
                          let dayEarnings = 0;
                          if (row.status === 'present') dayEarnings = dailyWage + otHours * otRate;
                          else if (row.status === 'half') dayEarnings = dailyWage / 2 + otHours * otRate;
                          const siteLabel = row.siteId ? `Site: ${row.siteId.slice(0, 6)}…` : '—';

                          return (
                            <tr key={l.id} className="border-b border-amber-50 last:border-b-0 hover:bg-amber-50">
                              <td className="px-4 py-2">
                                <div className="flex items-center gap-2">
                                  <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-amber-200 text-xs font-semibold text-amber-800">{initials(l.name)}</div>
                                  <span className="font-medium text-slate-800">{l.name}</span>
                                </div>
                              </td>
                              <td className="px-4 py-2 text-slate-700">{formatCurrency(dailyWage)}</td>
                              <td className="px-4 py-2">
                                <button onClick={() => clickStatus(l.id)} className="inline-block cursor-pointer hover:scale-105">
                                  <StatusBadge status={row.status} />
                                </button>
                                <select value={row.status} onChange={(e) => updateRow(l.id, { status: e.target.value })} className="ml-2 h-7 rounded border border-amber-200 bg-white px-1.5 text-xs outline-none">
                                  {STATUS_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
                                </select>
                              </td>
                              <td className="px-4 py-2 text-right">
                                {editingOT === l.id ? (
                                  <Input type="number" min="0" step="0.5" value={row.overtimeHours} onChange={(e) => updateRow(l.id, { overtimeHours: e.target.value })} onBlur={() => setEditingOT(null)} autoFocus className="h-7 w-16 text-right" />
                                ) : (
                                  <button onClick={() => setEditingOT(l.id)} className="text-slate-700 hover:underline">{row.overtimeHours}</button>
                                )}
                              </td>
                              <td className="px-4 py-2">
                                {editingRemark === l.id ? (
                                  <Input type="text" value={row.remark || ''} onChange={(e) => updateRow(l.id, { remark: e.target.value })} onBlur={() => handleRemarkSave(l.id)} autoFocus className="h-7 w-36 text-xs" />
                                ) : (
                                  <button onClick={() => setEditingRemark(l.id)} className="text-xs text-slate-500 hover:text-slate-800 flex items-center gap-1">
                                    <MessageSquare className="h-3 w-3" />
                                    <span className="max-w-24 truncate">{row.remark || '—'}</span>
                                  </button>
                                )}
                              </td>
                              <td className="px-4 py-2 text-right font-semibold text-slate-900">{formatCurrency(dayEarnings)}</td>
                              <td className="px-4 py-2 text-xs text-slate-500">{siteLabel}</td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )}

            {filtered.length === 0 && (
              <p className="py-8 text-center text-sm text-slate-400">No labours match the current filters.</p>
            )}
          </>
        )}
      </div>
      )}
    </div>
  );
}
