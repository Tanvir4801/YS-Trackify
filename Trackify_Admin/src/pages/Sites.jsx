import { motion, AnimatePresence } from 'framer-motion';
import React, { useEffect, useMemo, useState } from 'react';
import {
  Building2, Plus, Pencil, Trash2, Save, X, MapPin, Users,
  Calendar, Eye, ChevronDown, CheckCircle, XCircle, Clock, Minus,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { subscribeSites, addSite, updateSite, deleteSite } from '../lib/services/sites.service';
import { subscribeAttendanceByDate } from '../lib/services/attendance.service';
import { useLabours } from '../hooks/useLabours';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';

function todayStr() {
  return new Date().toISOString().split('T')[0];
}

function StatusBadge({ status }) {
  if (!status) return (
    <span className="inline-flex items-center gap-1.5 rounded bg-bg-input px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-text-muted border border-border-strong">
      <Minus className="h-3 w-3" /> Not Marked
    </span>
  );
  if (status === 'present') return (
    <span className="inline-flex items-center gap-1.5 rounded bg-success-bg px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-success border border-success/30">
      <CheckCircle className="h-3 w-3" /> Present
    </span>
  );
  if (status === 'absent') return (
    <span className="inline-flex items-center gap-1.5 rounded bg-danger-bg px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-danger border border-danger/30">
      <XCircle className="h-3 w-3" /> Absent
    </span>
  );
  if (status === 'half') return (
    <span className="inline-flex items-center gap-1.5 rounded bg-warning/10 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-warning border border-warning/30">
      <Clock className="h-3 w-3" /> Half Day
    </span>
  );
  return (
    <span className="inline-flex items-center rounded bg-bg-input px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-text-muted border border-border-strong">{status}</span>
  );
}

export default function Sites() {
  const scopeId = useScopeId();
  const { role, uid } = useAuthStore();
  const { data: labours = [] } = useLabours({ activeOnly: true });

  const [sites, setSites] = useState([]);
  const [loading, setLoading] = useState(true);

  // Add / Edit form state
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [formName, setFormName] = useState('');
  const [formDesc, setFormDesc] = useState('');
  const [formAllowances, setFormAllowances] = useState({ petrol: 0, lunch: 0, breakfast: 0, tea: 0 });
  const [saving, setSaving] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState(null);

  // Detail (attendance drill-down) state
  const [detailSiteId, setDetailSiteId] = useState(null);
  const [detailDate, setDetailDate] = useState(todayStr());
  const [attendanceMap, setAttendanceMap] = useState({});
  const [attendanceLoading, setAttendanceLoading] = useState(false);

  useEffect(() => {
    if (!scopeId) { setLoading(false); return; }
    setLoading(true);
    const unsub = subscribeSites(scopeId, (list) => {
      setSites(list);
      setLoading(false);
    });
    return unsub;
  }, [scopeId]);

  // Subscribe to attendance whenever detail view is open or date changes
  useEffect(() => {
    if (!detailSiteId || !scopeId || !detailDate) {
      setAttendanceMap({});
      return;
    }
    setAttendanceLoading(true);
    const isSup = role === 'supervisor';
    const supId = isSup ? uid : null;
    const unsub = subscribeAttendanceByDate(scopeId, detailDate, (records) => {
      const map = {};
      records.forEach((r) => { if (r.labourId) map[r.labourId] = r; });
      setAttendanceMap(map);
      setAttendanceLoading(false);
    }, isSup, supId);
    return unsub;
  }, [detailSiteId, detailDate, scopeId, role, uid]);

  const labourCountBySite = useMemo(() => {
    const counts = {};
    labours.forEach((l) => { if (l.siteId) counts[l.siteId] = (counts[l.siteId] || 0) + 1; });
    return counts;
  }, [labours]);

  const detailLabours = useMemo(() => {
    if (!detailSiteId) return [];
    return labours.filter((l) => l.siteId === detailSiteId);
  }, [detailSiteId, labours]);

  const detailSummary = useMemo(() => {
    let present = 0, three_quarter = 0, half = 0, quarter = 0, absent = 0, unmarked = 0;
    detailLabours.forEach((l) => {
      const r = attendanceMap[l.id];
      if (!r) unmarked++;
      else if (r.status === 'present') present++;
      else if (r.status === 'absent') absent++;
      else if (r.status === 'three_quarter') three_quarter++;
      else if (r.status === 'half') half++;
      else if (r.status === 'quarter') quarter++;
      else unmarked++;
    });
    return { present, three_quarter, half, quarter, absent, unmarked };
  }, [detailLabours, attendanceMap]);

  const EMPTY_DA = { petrol: 0, lunch: 0, breakfast: 0, tea: 0 };
  const openAdd = () => { setEditingId(null); setFormName(''); setFormDesc(''); setFormAllowances(EMPTY_DA); setShowForm(true); };
  const openEdit = (site) => {
    setEditingId(site.id);
    setFormName(site.name);
    setFormDesc(site.description || '');
    setFormAllowances(site.defaultAllowances ?? EMPTY_DA);
    setShowForm(true);
  };
  const closeForm = () => { setShowForm(false); setEditingId(null); setFormName(''); setFormDesc(''); setFormAllowances(EMPTY_DA); };

  const handleSave = async () => {
    if (!formName.trim()) return toast.error('Enter a site name');
    if (!scopeId) return toast.error('No contractor scope');
    setSaving(true);
    const da = {
      petrol:    Number(formAllowances.petrol    || 0),
      lunch:     Number(formAllowances.lunch     || 0),
      breakfast: Number(formAllowances.breakfast || 0),
      tea:       Number(formAllowances.tea       || 0),
    };
    try {
      if (editingId) {
        await updateSite(editingId, { name: formName.trim(), description: formDesc.trim(), defaultAllowances: da });
        toast.success('Site updated');
      } else {
        await addSite(scopeId, formName.trim(), formDesc.trim(), da);
        toast.success('Site added');
      }
      closeForm();
    } catch (e) { toast.error('Failed: ' + e.message); }
    finally { setSaving(false); }
  };

  const handleDelete = async (site) => {
    if (deleteConfirm !== site.id) { setDeleteConfirm(site.id); return; }
    try {
      await deleteSite(site.id);
      toast.success(`"${site.name}" deleted`);
      if (detailSiteId === site.id) setDetailSiteId(null);
    } catch (e) { toast.error('Failed to delete: ' + e.message); }
    setDeleteConfirm(null);
  };

  const toggleDetail = (siteId) => {
    setDetailSiteId((prev) => (prev === siteId ? null : siteId));
    setDetailDate(todayStr());
    setAttendanceMap({});
  };

  return (
    <div className="space-y-6">
      {/* Header bar */}
      <div className="rounded-xl border border-border bg-bg-card px-6 py-5 flex flex-wrap items-center justify-between gap-4">
        <div className="text-[13px] text-text-secondary uppercase tracking-widest font-medium">
          <span className="font-semibold text-text-primary mr-2">{sites.length}</span> site{sites.length !== 1 ? 's' : ''} <span className="text-text-muted">· assign labours to sites for per-site attendance tracking</span>
        </div>
        <button 
          onClick={openAdd} 
          className="flex h-9 items-center gap-2 rounded-lg bg-gold px-4 text-[13px] font-semibold text-bg-primary shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-105 transition-all ml-auto"
        >
          <Plus className="h-4 w-4" /> Add Site
        </button>
      </div>

      {/* Add / Edit form */}
      {showForm && (
        <div className="rounded-xl border border-info/30 bg-info/5 p-6 shadow-sm">
          <h3 className="mb-5 flex items-center gap-2 text-sm font-semibold uppercase tracking-widest text-info">
            <Building2 className="h-4 w-4" />
            {editingId ? 'Edit Site' : 'Add New Site'}
          </h3>
          <div className="grid gap-5 sm:grid-cols-2">
            <div className="space-y-1.5 flex flex-col">
              <label className="text-[10px] uppercase tracking-widest text-text-muted font-medium ml-1">Site Name *</label>
              <input value={formName} onChange={(e) => setFormName(e.target.value)}
                placeholder="e.g. Building A, Floor 3" className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary placeholder:text-text-muted outline-none focus:border-gold focus:ring-1 focus:ring-gold"
                autoFocus onKeyDown={(e) => e.key === 'Enter' && handleSave()} />
            </div>
            <div className="space-y-1.5 flex flex-col">
              <label className="text-[10px] uppercase tracking-widest text-text-muted font-medium ml-1">Description (optional)</label>
              <input value={formDesc} onChange={(e) => setFormDesc(e.target.value)}
                placeholder="Location details, notes…" className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary placeholder:text-text-muted outline-none focus:border-gold focus:ring-1 focus:ring-gold" />
            </div>
          </div>
          {/* Default Allowances */}
          <div className="mt-5 rounded-lg border border-warning/30 bg-warning/5 p-5">
            <p className="mb-4 flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-widest text-warning">
              <span>🪙</span> Default Daily Allowances (auto-filled in Flutter app)
            </p>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              {[
                { key: 'petrol', label: '🚗 Petrol', placeholder: '200' },
                { key: 'lunch', label: '🍽 Lunch', placeholder: '0' },
                { key: 'breakfast', label: '🍳 Breakfast', placeholder: '0' },
                { key: 'tea', label: '☕ Tea', placeholder: '0' },
              ].map(({ key, label, placeholder }) => (
                <div key={key} className="space-y-1.5 flex flex-col">
                  <label className="text-[10px] uppercase tracking-widest text-text-muted font-medium ml-1">{label}</label>
                  <div className="relative mt-1">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-[13px] text-text-muted font-mono">₹</span>
                    <input
                      type="number"
                      min="0"
                      value={formAllowances[key] || ''}
                      onChange={(e) => setFormAllowances((prev) => ({ ...prev, [key]: e.target.value }))}
                      placeholder={placeholder}
                      className="h-9 w-full rounded-lg border border-border-strong bg-bg-input pl-7 pr-3 text-[13px] font-mono text-text-primary placeholder:text-text-muted outline-none focus:border-gold focus:ring-1 focus:ring-gold"
                    />
                  </div>
                </div>
              ))}
            </div>
            <p className="mt-3 text-[11px] text-text-muted tracking-wide">
              These pre-fill the allowance sheet in the Flutter app — supervisor can still override per day.
            </p>
          </div>
          <div className="mt-6 flex gap-3">
            <button onClick={closeForm} className="flex h-9 items-center gap-2 rounded-lg border border-border-strong bg-bg-elevated px-4 text-[13px] font-medium text-text-secondary hover:text-text-primary transition-colors"><X className="h-4 w-4" /> Cancel</button>
            <button onClick={handleSave} disabled={saving} className="flex h-9 items-center gap-2 rounded-lg bg-info px-5 text-[13px] font-semibold text-white shadow-[0_0_15px_rgba(37,99,235,0.2)] hover:scale-105 transition-all disabled:opacity-50 disabled:hover:scale-100">
              <Save className="h-4 w-4" /> {saving ? 'Saving…' : editingId ? 'Update' : 'Add Site'}
            </button>
          </div>
        </div>
      )}

      {/* Sites list */}
      {loading ? (
        <LoadingSpinner label="Loading sites…" />
      ) : sites.length === 0 ? (
        <EmptyState icon={Building2} title="No sites yet" description="Add your first work site — then assign labours to each site." />
      ) : (
        <div className="space-y-4">
          {sites.map((site) => {
            const count = labourCountBySite[site.id] || 0;
            const isOpen = detailSiteId === site.id;

            return (
              <div key={site.id}
                className={`rounded-xl border bg-bg-card shadow-sm transition-all overflow-hidden ${isOpen ? 'border-gold ring-1 ring-gold/20' : 'border-border hover:border-border-strong'}`}>

                {/* ── Site card row ── */}
                <div className="flex items-center gap-4 p-5">
                  {/* Icon */}
                  <div className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-lg transition-colors ${isOpen ? 'bg-gold text-bg-primary' : 'bg-bg-elevated text-text-muted group-hover:text-gold'}`}>
                    <MapPin className="h-5 w-5" />
                  </div>

                  {/* Name + info */}
                  <div className="flex-1 min-w-0">
                    <h3 className="truncate font-semibold text-text-primary text-[15px]">{site.name}</h3>
                    {site.description && (
                      <p className="mt-1 truncate text-[12px] text-text-muted">{site.description}</p>
                    )}
                    <div className="mt-2 flex flex-wrap items-center gap-2">
                      <span className="flex items-center gap-1 text-[11px] font-bold uppercase tracking-widest text-text-muted bg-bg-elevated px-2 py-0.5 rounded">
                        <Users className="h-3 w-3" /> {count} {count === 1 ? 'labour' : 'labours'}
                      </span>
                      {labours.filter((l) => l.siteId === site.id).slice(0, 4).map((l) => (
                        <span key={l.id} className="rounded bg-bg-elevated border border-border-strong px-1.5 py-0.5 text-[10px] font-mono text-text-secondary">{l.name}</span>
                      ))}
                      {count > 4 && <span className="text-[10px] font-mono text-text-muted">+{count - 4} more</span>}
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="flex shrink-0 items-center gap-2">
                    <button onClick={() => toggleDetail(site.id)}
                      className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-[12px] font-medium transition-colors ${isOpen ? 'bg-gold border-gold text-bg-primary' : 'border-border-strong bg-bg-elevated text-text-secondary hover:text-text-primary hover:border-gold'}`}>
                      <Eye className="h-3.5 w-3.5" />
                      {isOpen ? 'Close' : 'View'}
                      <ChevronDown className={`h-3.5 w-3.5 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
                    </button>
                    <button onClick={() => openEdit(site)}
                      className="flex h-8 w-8 items-center justify-center rounded-lg border border-border-strong bg-bg-elevated text-text-secondary hover:text-text-primary hover:border-gold transition-colors" title="Edit">
                      <Pencil className="h-3.5 w-3.5" />
                    </button>
                    <button onClick={() => handleDelete(site)}
                      className={`flex h-8 w-8 items-center justify-center rounded-lg border transition-colors ${deleteConfirm === site.id ? 'border-danger/30 bg-danger-bg text-danger hover:bg-danger hover:text-white' : 'border-border-strong bg-bg-elevated text-text-secondary hover:text-danger hover:border-danger/50 hover:bg-danger-bg'}`}
                      title={deleteConfirm === site.id ? 'Confirm?' : 'Delete'}>
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                    {deleteConfirm === site.id && (
                      <button onClick={() => setDeleteConfirm(null)}
                        className="rounded-lg px-2 py-1 text-[11px] font-medium text-text-muted hover:text-text-primary transition-colors">Cancel</button>
                    )}
                  </div>
                </div>

                {/* ── Attendance Detail Panel ── */}
                {isOpen && (
                  <div className="border-t border-border bg-bg-elevated/50">
                    {/* Date picker + summary */}
                    <div className="flex flex-wrap items-center gap-3 border-b border-border bg-bg-elevated px-5 py-3">
                      <Calendar className="h-4 w-4 text-gold" />
                      <span className="text-[12px] font-semibold uppercase tracking-widest text-text-secondary">Attendance on</span>
                      <input
                        type="date"
                        value={detailDate}
                        max={todayStr()}
                        onChange={(e) => { setDetailDate(e.target.value); setAttendanceMap({}); setAttendanceLoading(true); }}
                        className="h-8 rounded-md border border-border-strong bg-bg-input px-2 py-1 text-[13px] font-mono text-text-primary outline-none focus:border-gold focus:ring-1 focus:ring-gold"
                      />
                      {detailLabours.length > 0 && !attendanceLoading && (
                        <div className="ml-auto flex flex-wrap gap-2">
                          <span className="inline-flex items-center gap-1 rounded bg-success-bg border border-success/30 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-success">
                            <CheckCircle className="h-3 w-3" /> {detailSummary.present} Present
                          </span>
                          <span className="inline-flex items-center gap-1 rounded bg-danger-bg border border-danger/30 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-danger">
                            <XCircle className="h-3 w-3" /> {detailSummary.absent} Absent
                          </span>
                          <span className="inline-flex items-center gap-1 rounded bg-warning/10 border border-warning/30 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-warning">
                            <Clock className="h-3 w-3" /> {detailSummary.half} Half
                          </span>
                          {detailSummary.unmarked > 0 && (
                            <span className="inline-flex items-center gap-1 rounded bg-bg-input border border-border-strong px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-text-muted">
                              <Minus className="h-3 w-3" /> {detailSummary.unmarked} Unmarked
                            </span>
                          )}
                        </div>
                      )}
                    </div>

                    {/* Labour attendance rows */}
                    {attendanceLoading ? (
                      <div className="px-5 py-10 text-center">
                        <LoadingSpinner label="Loading attendance…" />
                      </div>
                    ) : detailLabours.length === 0 ? (
                      <div className="px-5 py-10 text-center">
                        <Users className="mx-auto mb-3 h-8 w-8 text-border-strong" />
                        <p className="text-[13px] text-text-secondary">No labours assigned to this site.</p>
                        <p className="mt-1 text-[11px] text-text-muted uppercase tracking-widest">Go to Labours → edit → assign this site.</p>
                      </div>
                    ) : (
                      <div className="divide-y divide-border">
                        {detailLabours.map((labour) => {
                          const rec = attendanceMap[labour.id];
                          return (
                            <div key={labour.id} className="flex items-center gap-4 px-5 py-3 transition-colors hover:bg-bg-card-hover">
                              {/* Avatar */}
                              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-info/20 border border-info/30 text-[12px] font-mono font-medium text-info">
                                {labour.name?.[0]?.toUpperCase() || '?'}
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="truncate text-[13px] font-medium text-text-primary">{labour.name}</p>
                                <p className="text-[11px] font-mono text-text-muted mt-0.5">
                                  {labour.phone || '—'}
                                  {labour.dailyWage ? ` · ₹${Number(labour.dailyWage).toLocaleString()}/day` : ''}
                                  {rec?.overtimeHours > 0 ? ` · OT ${rec.overtimeHours}h` : ''}
                                </p>
                                {rec?.remark && (
                                  <p className="mt-1 truncate text-[11px] text-warning italic border-l-2 border-warning/50 pl-2">"{rec.remark}"</p>
                                )}
                              </div>
                              <StatusBadge status={rec?.status} />
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      <div className="rounded-xl border border-info/30 bg-info/5 px-5 py-4 text-[13px] text-info flex gap-3 items-start shadow-sm">
        <span className="text-[16px]">💡</span>
        <div>
          <strong className="tracking-wide uppercase text-[11px] block mb-1">Tip</strong>
          Go to <strong>Labours</strong> → edit a labour → assign a <em>Site</em>.
          Then in the Flutter app, site tabs appear at the top of Attendance screen.
        </div>
      </div>
    </div>
  );
}
