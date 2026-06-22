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
    <span className="inline-flex items-center gap-1 rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-400">
      <Minus className="h-3 w-3" /> Not Marked
    </span>
  );
  if (status === 'present') return (
    <span className="inline-flex items-center gap-1 rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-700">
      <CheckCircle className="h-3 w-3" /> Present
    </span>
  );
  if (status === 'absent') return (
    <span className="inline-flex items-center gap-1 rounded-full bg-red-100 px-2 py-0.5 text-xs font-semibold text-red-700">
      <XCircle className="h-3 w-3" /> Absent
    </span>
  );
  if (status === 'half') return (
    <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700">
      <Clock className="h-3 w-3" /> Half Day
    </span>
  );
  return (
    <span className="inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-500">{status}</span>
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
    let present = 0, absent = 0, half = 0, unmarked = 0;
    detailLabours.forEach((l) => {
      const r = attendanceMap[l.id];
      if (!r) unmarked++;
      else if (r.status === 'present') present++;
      else if (r.status === 'absent') absent++;
      else if (r.status === 'half') half++;
      else unmarked++;
    });
    return { present, absent, half, unmarked };
  }, [detailLabours, attendanceMap]);

  const openAdd = () => { setEditingId(null); setFormName(''); setFormDesc(''); setShowForm(true); };
  const openEdit = (site) => { setEditingId(site.id); setFormName(site.name); setFormDesc(site.description || ''); setShowForm(true); };
  const closeForm = () => { setShowForm(false); setEditingId(null); setFormName(''); setFormDesc(''); };

  const handleSave = async () => {
    if (!formName.trim()) return toast.error('Enter a site name');
    if (!scopeId) return toast.error('No contractor scope');
    setSaving(true);
    try {
      if (editingId) {
        await updateSite(editingId, { name: formName.trim(), description: formDesc.trim() });
        toast.success('Site updated');
      } else {
        await addSite(scopeId, formName.trim(), formDesc.trim());
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
      {/* Header */}
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight text-slate-950">Sites</h2>
          <p className="mt-1 text-sm text-slate-500">
            Manage work sites — view labours and daily attendance per site.
          </p>
        </div>
        <Button onClick={openAdd} className="gap-2 bg-blue-600 text-white hover:bg-blue-700">
          <Plus className="h-4 w-4" /> Add Site
        </Button>
      </div>

      {/* Add / Edit form */}
      {showForm && (
        <div className="rounded-2xl border border-blue-100 bg-blue-50/60 p-5 shadow-sm">
          <h3 className="mb-4 flex items-center gap-2 text-base font-semibold text-slate-900">
            <Building2 className="h-4 w-4 text-blue-600" />
            {editingId ? 'Edit Site' : 'Add New Site'}
          </h3>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <Label className="text-xs text-slate-600">Site Name *</Label>
              <Input value={formName} onChange={(e) => setFormName(e.target.value)}
                placeholder="e.g. Building A, Floor 3" className="mt-1 h-10"
                autoFocus onKeyDown={(e) => e.key === 'Enter' && handleSave()} />
            </div>
            <div>
              <Label className="text-xs text-slate-600">Description (optional)</Label>
              <Input value={formDesc} onChange={(e) => setFormDesc(e.target.value)}
                placeholder="Location details, notes…" className="mt-1 h-10" />
            </div>
          </div>
          <div className="mt-4 flex gap-2">
            <Button onClick={closeForm} variant="outline" className="gap-1"><X className="h-4 w-4" /> Cancel</Button>
            <Button onClick={handleSave} disabled={saving} className="gap-1 bg-blue-600 text-white hover:bg-blue-700">
              <Save className="h-4 w-4" /> {saving ? 'Saving…' : editingId ? 'Update' : 'Add Site'}
            </Button>
          </div>
        </div>
      )}

      {/* Sites list */}
      {loading ? (
        <LoadingSpinner label="Loading sites…" />
      ) : sites.length === 0 ? (
        <EmptyState icon={Building2} title="No sites yet" description="Add your first work site — then assign labours to each site." />
      ) : (
        <div className="space-y-3">
          {sites.map((site) => {
            const count = labourCountBySite[site.id] || 0;
            const isOpen = detailSiteId === site.id;

            return (
              <div key={site.id}
                className={`rounded-2xl border bg-white shadow-sm transition-all ${isOpen ? 'border-blue-300 ring-1 ring-blue-200' : 'border-slate-200/70'}`}>

                {/* ── Site card row ── */}
                <div className="flex items-center gap-3 p-4">
                  {/* Icon */}
                  <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl transition ${isOpen ? 'bg-blue-600' : 'bg-blue-100'}`}>
                    <MapPin className={`h-5 w-5 ${isOpen ? 'text-white' : 'text-blue-600'}`} />
                  </div>

                  {/* Name + info */}
                  <div className="flex-1 min-w-0">
                    <h3 className="truncate font-semibold text-slate-900">{site.name}</h3>
                    {site.description && (
                      <p className="mt-0.5 truncate text-xs text-slate-500">{site.description}</p>
                    )}
                    <div className="mt-1.5 flex flex-wrap items-center gap-2">
                      <span className="flex items-center gap-1 text-xs text-slate-500">
                        <Users className="h-3 w-3" /> {count} {count === 1 ? 'labour' : 'labours'}
                      </span>
                      {labours.filter((l) => l.siteId === site.id).slice(0, 4).map((l) => (
                        <span key={l.id} className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600">{l.name}</span>
                      ))}
                      {count > 4 && <span className="text-xs text-slate-400">+{count - 4} more</span>}
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="flex shrink-0 items-center gap-1.5">
                    <button onClick={() => toggleDetail(site.id)}
                      className={`flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition ${isOpen ? 'bg-blue-600 text-white' : 'bg-blue-50 text-blue-700 hover:bg-blue-100'}`}>
                      <Eye className="h-3.5 w-3.5" />
                      {isOpen ? 'Close' : 'View'}
                      <ChevronDown className={`h-3.5 w-3.5 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
                    </button>
                    <button onClick={() => openEdit(site)}
                      className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700" title="Edit">
                      <Pencil className="h-3.5 w-3.5" />
                    </button>
                    <button onClick={() => handleDelete(site)}
                      className={`rounded-lg p-1.5 transition ${deleteConfirm === site.id ? 'bg-red-600 text-white' : 'text-red-400 hover:bg-red-50 hover:text-red-600'}`}
                      title={deleteConfirm === site.id ? 'Confirm?' : 'Delete'}>
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                    {deleteConfirm === site.id && (
                      <button onClick={() => setDeleteConfirm(null)}
                        className="rounded-lg px-2 py-1 text-xs text-slate-400 hover:bg-slate-100">Cancel</button>
                    )}
                  </div>
                </div>

                {/* ── Attendance Detail Panel ── */}
                {isOpen && (
                  <div className="border-t border-blue-100">
                    {/* Date picker + summary */}
                    <div className="flex flex-wrap items-center gap-3 bg-blue-50/40 px-4 py-3">
                      <Calendar className="h-4 w-4 text-blue-500" />
                      <span className="text-sm font-medium text-slate-700">Attendance on</span>
                      <input
                        type="date"
                        value={detailDate}
                        max={todayStr()}
                        onChange={(e) => { setDetailDate(e.target.value); setAttendanceMap({}); setAttendanceLoading(true); }}
                        className="rounded-lg border border-slate-200 bg-white px-3 py-1 text-sm text-slate-800 shadow-sm focus:border-blue-400 focus:outline-none"
                      />
                      {detailLabours.length > 0 && !attendanceLoading && (
                        <div className="ml-auto flex flex-wrap gap-2">
                          <span className="inline-flex items-center gap-1 rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-semibold text-green-700">
                            <CheckCircle className="h-3 w-3" /> {detailSummary.present} Present
                          </span>
                          <span className="inline-flex items-center gap-1 rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-semibold text-red-700">
                            <XCircle className="h-3 w-3" /> {detailSummary.absent} Absent
                          </span>
                          <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2.5 py-0.5 text-xs font-semibold text-amber-700">
                            <Clock className="h-3 w-3" /> {detailSummary.half} Half
                          </span>
                          {detailSummary.unmarked > 0 && (
                            <span className="inline-flex items-center gap-1 rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-semibold text-slate-500">
                              <Minus className="h-3 w-3" /> {detailSummary.unmarked} Unmarked
                            </span>
                          )}
                        </div>
                      )}
                    </div>

                    {/* Labour attendance rows */}
                    {attendanceLoading ? (
                      <div className="px-4 py-8 text-center text-sm text-slate-400">Loading attendance…</div>
                    ) : detailLabours.length === 0 ? (
                      <div className="px-4 py-8 text-center">
                        <Users className="mx-auto mb-2 h-8 w-8 text-slate-200" />
                        <p className="text-sm text-slate-500">No labours assigned to this site.</p>
                        <p className="mt-1 text-xs text-slate-400">Go to Labours → edit → assign this site.</p>
                      </div>
                    ) : (
                      <div className="divide-y divide-slate-100">
                        {detailLabours.map((labour) => {
                          const rec = attendanceMap[labour.id];
                          return (
                            <div key={labour.id} className="flex items-center gap-3 px-4 py-3">
                              {/* Avatar */}
                              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-slate-100 text-sm font-bold text-slate-600">
                                {labour.name?.[0]?.toUpperCase() || '?'}
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="truncate text-sm font-semibold text-slate-900">{labour.name}</p>
                                <p className="text-xs text-slate-400">
                                  {labour.phone || '—'}
                                  {labour.dailyWage ? ` · ₹${Number(labour.dailyWage).toLocaleString()}/day` : ''}
                                  {rec?.overtimeHours > 0 ? ` · OT ${rec.overtimeHours}h` : ''}
                                </p>
                                {rec?.remark && (
                                  <p className="mt-0.5 truncate text-xs text-slate-400 italic">"{rec.remark}"</p>
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

      <div className="rounded-xl border border-blue-100 bg-blue-50 px-4 py-3 text-sm text-blue-700">
        <strong>Tip:</strong> Go to <strong>Labours</strong> → edit a labour → assign a <em>Site</em>.
        Then in the Flutter app, site tabs appear at the top of Attendance screen.
      </div>
    </div>
  );
}
