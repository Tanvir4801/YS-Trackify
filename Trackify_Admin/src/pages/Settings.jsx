import React, { useEffect, useState } from 'react';
import { Settings as SettingsIcon, Building2, Bell, Database, RefreshCw } from 'lucide-react';
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
  try {
    return JSON.parse(localStorage.getItem(LS_KEY) || '{}');
  } catch {
    return {};
  }
}

function saveSettings(data) {
  localStorage.setItem(LS_KEY, JSON.stringify(data));
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

  useEffect(() => {
    // Count unsynced records
    setLoadingSync(true);
    const queries = [
      getDocs(query(collection(db, 'attendance'), where('isSynced', '==', false))),
      getDocs(query(collection(db, 'labours'), where('isSynced', '==', false))),
      getDocs(query(collection(db, 'payments'), where('isSynced', '==', false))),
    ];
    Promise.all(queries)
      .then(([att, lab, pay]) => {
        setUnsyncedCount(att.size + lab.size + pay.size);
      })
      .catch(console.error)
      .finally(() => setLoadingSync(false));
  }, []);

  const handleSave = () => {
    saveSettings(settings);
    toast.success('Settings saved');
  };

  const handleForceSync = async () => {
    if (unsyncedCount === 0) {
      toast('No unsynced records', { icon: 'ℹ️' });
      return;
    }
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

  const section = 'rounded-2xl border border-slate-200/70 bg-white/90 p-5 shadow-sm space-y-4';
  const heading = 'flex items-center gap-2 text-base font-semibold text-slate-900 border-b border-slate-100 pb-3 mb-2';

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold tracking-tight text-slate-950">Settings</h2>
        <p className="mt-1 text-sm text-slate-500">Configure your workspace preferences.</p>
      </div>

      <div className={section}>
        <div className={heading}>
          <Building2 className="h-4 w-4 text-slate-400" />
          Company Settings
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1">
            <Label>Company Name</Label>
            <Input
              value={settings.companyName}
              onChange={(e) => setSettings({ ...settings, companyName: e.target.value })}
              placeholder="YS Construction"
            />
          </div>
          <div className="space-y-1">
            <Label>Default Working Hours / day</Label>
            <Input
              type="number"
              value={settings.defaultWorkingHours}
              onChange={(e) => setSettings({ ...settings, defaultWorkingHours: Number(e.target.value) })}
            />
          </div>
          <div className="space-y-1">
            <Label>Weekly Off</Label>
            <select
              value={settings.weeklyOff}
              onChange={(e) => setSettings({ ...settings, weeklyOff: e.target.value })}
              className="h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
            >
              <option value="none">No weekly off</option>
              <option value="sunday">Sunday</option>
              <option value="saturday">Saturday</option>
              <option value="both">Saturday + Sunday</option>
            </select>
          </div>
          <div className="space-y-1">
            <Label>Overtime after (hrs)</Label>
            <Input
              type="number"
              value={settings.otThreshold}
              onChange={(e) => setSettings({ ...settings, otThreshold: Number(e.target.value) })}
            />
          </div>
        </div>
      </div>

      <div className={section}>
        <div className={heading}>
          <Bell className="h-4 w-4 text-slate-400" />
          Notification Settings
        </div>
        <div className="space-y-1">
          <Label>Alert after X consecutive absences</Label>
          <Input
            type="number"
            min="1"
            value={settings.absenceAlertDays}
            onChange={(e) => setSettings({ ...settings, absenceAlertDays: Number(e.target.value) })}
            className="w-32"
          />
        </div>
      </div>

      <div className={section}>
        <div className={heading}>
          <Database className="h-4 w-4 text-slate-400" />
          Data Sync
        </div>
        <p className="text-sm text-slate-600">
          Records created by the mobile app are flagged <code className="rounded bg-slate-100 px-1 text-xs">isSynced=false</code> until acknowledged.
        </p>
        <div className="flex flex-wrap items-center gap-4">
          <div className="rounded-xl border border-slate-200 bg-slate-50 px-4 py-3">
            <p className="text-xs text-slate-500 uppercase tracking-wide font-semibold">Unsynced Records</p>
            <p className="mt-1 text-2xl font-semibold text-slate-950">
              {loadingSync ? '…' : unsyncedCount}
            </p>
          </div>
          <Button
            variant="outline"
            onClick={handleForceSync}
            disabled={syncing || loadingSync}
            className="gap-2"
          >
            <RefreshCw className={`h-4 w-4 ${syncing ? 'animate-spin' : ''}`} />
            {syncing ? 'Syncing…' : 'Force Sync All'}
          </Button>
        </div>
      </div>

      <div className="flex justify-end">
        <Button onClick={handleSave} className="bg-blue-600 text-white hover:bg-blue-700 px-8">
          Save Settings
        </Button>
      </div>
    </div>
  );
}
