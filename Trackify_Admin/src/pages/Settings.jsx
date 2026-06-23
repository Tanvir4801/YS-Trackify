import React, { useEffect, useState } from 'react';
import { Building2, Bell, Database, RefreshCw, CheckCircle } from 'lucide-react';
import toast from 'react-hot-toast';
import { getDocs, collection, query, where, updateDoc, doc } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { useScopeId } from '../store/authStore';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';

const LS_KEY = 'trackify_settings';

function loadSettings() {
  try { return JSON.parse(localStorage.getItem(LS_KEY) || '{}'); }
  catch { return {}; }
}

function saveSettings(data) { localStorage.setItem(LS_KEY, JSON.stringify(data)); }

function Section({ icon: Icon, title, desc, children }) {
  return (
    <div className="rounded-2xl border border-slate-200/70 bg-white shadow-sm overflow-hidden">
      <div className="flex items-start gap-4 border-b border-slate-100 px-6 py-5">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-blue-50">
          <Icon className="h-4 w-4 text-blue-600" />
        </div>
        <div>
          <h3 className="text-sm font-bold text-slate-900">{title}</h3>
          {desc && <p className="mt-0.5 text-xs text-slate-500">{desc}</p>}
        </div>
      </div>
      <div className="px-6 py-5">{children}</div>
    </div>
  );
}

export default function Settings() {
  const scopeId = useScopeId();
  const [settings, setSettings] = useState({
    companyName: '',
    defaultWorkingHours: 8,
    weeklyOff: 'sunday',
    otThreshold: 8,
    absenceAlertDays: 3,
    ...loadSettings(),
  });
  const [unsyncedCount, setUnsyncedCount] = useState(null);
  const [loadingSync, setLoadingSync] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    setLoadingSync(true);
    const queries = [
      getDocs(query(collection(db, 'attendance'), where('isSynced', '==', false))),
      getDocs(query(collection(db, 'labours'), where('isSynced', '==', false))),
      getDocs(query(collection(db, 'payments'), where('isSynced', '==', false))),
    ];
    Promise.all(queries)
      .then(([att, lab, pay]) => { setUnsyncedCount(att.size + lab.size + pay.size); })
      .catch(console.error)
      .finally(() => setLoadingSync(false));
  }, []);

  const handleSave = () => {
    saveSettings(settings);
    toast.success('Settings saved');
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  const handleForceSync = async () => {
    if (unsyncedCount === 0) { toast('No unsynced records', { icon: 'ℹ️' }); return; }
    setSyncing(true);
    const t = toast.loading(`Marking ${unsyncedCount} records as synced…`);
    try {
      const collections = ['attendance', 'labours', 'payments'];
      await Promise.all(
        collections.map(async (col) => {
          const snap = await getDocs(query(collection(db, col), where('isSynced', '==', false)));
          return Promise.all(snap.docs.map((d) => updateDoc(doc(db, col, d.id), { isSynced: true })));
        }),
      );
      setUnsyncedCount(0);
      toast.dismiss(t);
      toast.success('All records marked as synced');
    } catch (e) {
      console.error(e);
      toast.dismiss(t);
      toast.error('Failed to sync');
    } finally {
      setSyncing(false);
    }
  };

  void scopeId;

  const fieldClass = "h-10 w-full rounded-xl border border-slate-200 bg-white px-3 text-sm text-slate-900 shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20";

  return (
    <div className="space-y-6">
      <Section
        icon={Building2}
        title="Company Settings"
        desc="Configure your organisation's basic information and work schedule"
      >
        <div className="grid gap-5 sm:grid-cols-2">
          <div className="space-y-1.5">
            <Label className="text-xs font-semibold text-slate-600">Company Name</Label>
            <Input
              value={settings.companyName}
              onChange={(e) => setSettings({ ...settings, companyName: e.target.value })}
              placeholder="YS Construction"
              className="h-10 rounded-xl"
            />
            <p className="text-xs text-slate-400">Displayed across reports and exports</p>
          </div>
          <div className="space-y-1.5">
            <Label className="text-xs font-semibold text-slate-600">Default Working Hours / day</Label>
            <Input
              type="number"
              value={settings.defaultWorkingHours}
              onChange={(e) => setSettings({ ...settings, defaultWorkingHours: Number(e.target.value) })}
              className="h-10 rounded-xl"
            />
            <p className="text-xs text-slate-400">Standard shift length used for payroll</p>
          </div>
          <div className="space-y-1.5">
            <Label className="text-xs font-semibold text-slate-600">Weekly Off</Label>
            <select
              value={settings.weeklyOff}
              onChange={(e) => setSettings({ ...settings, weeklyOff: e.target.value })}
              className={fieldClass}
            >
              <option value="none">No weekly off</option>
              <option value="sunday">Sunday</option>
              <option value="saturday">Saturday</option>
              <option value="both">Saturday + Sunday</option>
            </select>
            <p className="text-xs text-slate-400">Days excluded from attendance calculation</p>
          </div>
          <div className="space-y-1.5">
            <Label className="text-xs font-semibold text-slate-600">Overtime after (hrs)</Label>
            <Input
              type="number"
              value={settings.otThreshold}
              onChange={(e) => setSettings({ ...settings, otThreshold: Number(e.target.value) })}
              className="h-10 rounded-xl"
            />
            <p className="text-xs text-slate-400">Hours worked beyond this are counted as OT</p>
          </div>
        </div>
      </Section>

      <Section
        icon={Bell}
        title="Notification Settings"
        desc="Set thresholds for automated attendance alerts"
      >
        <div className="max-w-xs space-y-1.5">
          <Label className="text-xs font-semibold text-slate-600">Alert after X consecutive absences</Label>
          <Input
            type="number"
            min="1"
            value={settings.absenceAlertDays}
            onChange={(e) => setSettings({ ...settings, absenceAlertDays: Number(e.target.value) })}
            className="h-10 w-32 rounded-xl"
          />
          <p className="text-xs text-slate-400">Trigger a warning when a labour is absent for this many days in a row</p>
        </div>
      </Section>

      <Section
        icon={Database}
        title="Data Sync"
        desc="Records from the mobile app are queued until acknowledged by the admin panel"
      >
        <div className="flex flex-wrap items-center gap-5">
          <div className="rounded-2xl border border-slate-200 bg-slate-50 px-6 py-4 text-center">
            <p className="text-xs font-bold uppercase tracking-wide text-slate-400">Unsynced Records</p>
            <p className="mt-2 text-4xl font-bold text-slate-900">
              {loadingSync ? <span className="text-slate-300">…</span> : unsyncedCount}
            </p>
          </div>
          <div className="space-y-2">
            <p className="text-sm text-slate-600">
              Records flagged as <code className="rounded-md bg-slate-100 px-1.5 py-0.5 text-xs font-mono text-slate-700">isSynced=false</code> in Firestore.
            </p>
            <Button
              variant="outline"
              onClick={handleForceSync}
              disabled={syncing || loadingSync || unsyncedCount === 0}
              className="gap-2"
            >
              <RefreshCw className={`h-4 w-4 ${syncing ? 'animate-spin' : ''}`} />
              {syncing ? 'Syncing…' : 'Force Sync All'}
            </Button>
          </div>
        </div>
      </Section>

      <div className="flex justify-end">
        <Button
          onClick={handleSave}
          className="gap-2 px-8 text-sm font-semibold text-white"
          style={{ background: saved ? '#16A34A' : '#2563EB' }}
        >
          {saved ? (
            <><CheckCircle className="h-4 w-4" /> Saved!</>
          ) : (
            'Save Settings'
          )}
        </Button>
      </div>

      <p className="text-center text-xs text-slate-400">Developed by Tanvir Patel</p>
    </div>
  );
}
