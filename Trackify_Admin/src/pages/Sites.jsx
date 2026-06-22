import React, { useEffect, useMemo, useState } from 'react';
import { Building2, Plus, Pencil, Trash2, Save, X, MapPin, Users } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { subscribeSites, addSite, updateSite, deleteSite } from '../lib/services/sites.service';
import { useLabours } from '../hooks/useLabours';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';

export default function Sites() {
  const scopeId = useScopeId();
  const { data: labours = [] } = useLabours({ activeOnly: true });

  const [sites, setSites] = useState([]);
  const [loading, setLoading] = useState(true);

  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [formName, setFormName] = useState('');
  const [formDesc, setFormDesc] = useState('');
  const [saving, setSaving] = useState(false);

  const [deleteConfirm, setDeleteConfirm] = useState(null);

  useEffect(() => {
    if (!scopeId) { setLoading(false); return; }
    setLoading(true);
    const unsub = subscribeSites(scopeId, (list) => {
      setSites(list);
      setLoading(false);
    });
    return unsub;
  }, [scopeId]);

  // Count labours per site
  const labourCountBySite = useMemo(() => {
    const counts = {};
    labours.forEach((l) => {
      if (l.siteId) counts[l.siteId] = (counts[l.siteId] || 0) + 1;
    });
    return counts;
  }, [labours]);

  const openAdd = () => {
    setEditingId(null);
    setFormName('');
    setFormDesc('');
    setShowForm(true);
  };

  const openEdit = (site) => {
    setEditingId(site.id);
    setFormName(site.name);
    setFormDesc(site.description || '');
    setShowForm(true);
  };

  const closeForm = () => {
    setShowForm(false);
    setEditingId(null);
    setFormName('');
    setFormDesc('');
  };

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
    } catch (e) {
      toast.error('Failed: ' + e.message);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (site) => {
    if (deleteConfirm !== site.id) { setDeleteConfirm(site.id); return; }
    try {
      await deleteSite(site.id);
      toast.success(`"${site.name}" deleted`);
    } catch (e) {
      toast.error('Failed to delete: ' + e.message);
    }
    setDeleteConfirm(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight text-slate-950">Sites</h2>
          <p className="mt-1 text-sm text-slate-500">
            Manage work sites — assign labours to sites for organised attendance tracking.
          </p>
        </div>
        <Button onClick={openAdd} className="gap-2 bg-blue-600 text-white hover:bg-blue-700">
          <Plus className="h-4 w-4" /> Add Site
        </Button>
      </div>

      {/* Add / Edit Form */}
      {showForm && (
        <div className="rounded-2xl border border-blue-100 bg-blue-50/60 p-5 shadow-sm">
          <h3 className="mb-4 flex items-center gap-2 text-base font-semibold text-slate-900">
            <Building2 className="h-4 w-4 text-blue-600" />
            {editingId ? 'Edit Site' : 'Add New Site'}
          </h3>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <Label className="text-xs text-slate-600">Site Name *</Label>
              <Input
                value={formName}
                onChange={(e) => setFormName(e.target.value)}
                placeholder="e.g. Building A, Floor 3"
                className="mt-1 h-10"
                autoFocus
                onKeyDown={(e) => e.key === 'Enter' && handleSave()}
              />
            </div>
            <div>
              <Label className="text-xs text-slate-600">Description (optional)</Label>
              <Input
                value={formDesc}
                onChange={(e) => setFormDesc(e.target.value)}
                placeholder="Location details, notes…"
                className="mt-1 h-10"
              />
            </div>
          </div>
          <div className="mt-4 flex gap-2">
            <Button onClick={closeForm} variant="outline" className="gap-1">
              <X className="h-4 w-4" /> Cancel
            </Button>
            <Button onClick={handleSave} disabled={saving} className="gap-1 bg-blue-600 text-white hover:bg-blue-700">
              <Save className="h-4 w-4" /> {saving ? 'Saving…' : editingId ? 'Update' : 'Add Site'}
            </Button>
          </div>
        </div>
      )}

      {/* Sites Grid */}
      {loading ? (
        <LoadingSpinner label="Loading sites…" />
      ) : sites.length === 0 ? (
        <EmptyState
          icon={Building2}
          title="No sites yet"
          description="Add your first work site — then assign labours to each site."
        />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {sites.map((site) => {
            const count = labourCountBySite[site.id] || 0;
            return (
              <div
                key={site.id}
                className="group relative flex flex-col rounded-2xl border border-slate-200/70 bg-white/90 p-5 shadow-sm transition hover:shadow-md"
              >
                {/* Icon + Name */}
                <div className="flex items-start gap-3">
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-blue-100">
                    <MapPin className="h-5 w-5 text-blue-600" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <h3 className="truncate font-semibold text-slate-900">{site.name}</h3>
                    {site.description && (
                      <p className="mt-0.5 truncate text-xs text-slate-500">{site.description}</p>
                    )}
                  </div>
                </div>

                {/* Labour count */}
                <div className="mt-4 flex items-center gap-2">
                  <Users className="h-4 w-4 text-slate-400" />
                  <span className="text-sm font-medium text-slate-700">
                    {count} {count === 1 ? 'labour' : 'labours'} assigned
                  </span>
                </div>

                {/* Labours list in site */}
                {count > 0 && (
                  <div className="mt-2 flex flex-wrap gap-1">
                    {labours.filter((l) => l.siteId === site.id).slice(0, 6).map((l) => (
                      <span
                        key={l.id}
                        className="inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700"
                      >
                        {l.name}
                      </span>
                    ))}
                    {count > 6 && (
                      <span className="inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-500">
                        +{count - 6} more
                      </span>
                    )}
                  </div>
                )}

                {/* Action buttons */}
                <div className="mt-4 flex gap-2 border-t border-slate-100 pt-3">
                  <button
                    onClick={() => openEdit(site)}
                    className="flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-medium text-slate-600 transition hover:bg-slate-100 hover:text-slate-900"
                  >
                    <Pencil className="h-3.5 w-3.5" /> Edit
                  </button>
                  <button
                    onClick={() => handleDelete(site)}
                    className={`flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-medium transition ${
                      deleteConfirm === site.id
                        ? 'bg-red-600 text-white hover:bg-red-700'
                        : 'text-red-500 hover:bg-red-50 hover:text-red-700'
                    }`}
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                    {deleteConfirm === site.id ? 'Confirm delete' : 'Delete'}
                  </button>
                  {deleteConfirm === site.id && (
                    <button
                      onClick={() => setDeleteConfirm(null)}
                      className="rounded-lg px-2 py-1.5 text-xs text-slate-500 hover:bg-slate-100"
                    >
                      Cancel
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Info banner */}
      <div className="rounded-xl border border-blue-100 bg-blue-50 px-4 py-3 text-sm text-blue-700">
        <strong>Tip:</strong> Go to <strong>Labours</strong> → edit a labour → assign a <em>Site</em>.
        Then in the Flutter app, site tabs appear at the top of Attendance screen.
      </div>
    </div>
  );
}
