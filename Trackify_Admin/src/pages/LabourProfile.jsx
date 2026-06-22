import React, { useEffect, useMemo, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ArrowLeft, Phone, Pencil, Download, IndianRupee, CalendarDays, TrendingUp } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { getLabour, updateLabour } from '../lib/services/labours.service';
import { getAttendanceRange } from '../lib/services/attendance.service';
import { getPayments } from '../lib/services/payments.service';
import { formatCurrency, formatDate, exportCSV, todayKey, toDateKey } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import AttendanceHeatmap from '../components/shared/AttendanceHeatmap';
import StatusBadge from '../components/shared/StatusBadge';
import Modal from '../components/ui/Modal';

function Stat({ label, value, sub }) {
  return (
    <div className="rounded-xl border border-slate-200/70 bg-white/90 px-4 py-3 shadow-sm">
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-1 text-2xl font-semibold text-slate-950">{value}</p>
      {sub && <p className="mt-0.5 text-xs text-slate-400">{sub}</p>}
    </div>
  );
}

function initials(name) {
  return (name || '?').split(' ').map((w) => w[0]).join('').toUpperCase().slice(0, 2);
}

export default function LabourProfile() {
  const { id } = useParams();
  const navigate = useNavigate();
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeId = useScopeId();
  const isSupervisor = role === 'supervisor';

  const [labour, setLabour] = useState(null);
  const [attendance, setAttendance] = useState([]);
  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);

  const [editOpen, setEditOpen] = useState(false);
  const [form, setForm] = useState({});
  const [saving, setSaving] = useState(false);

  const now = new Date();
  const startOfMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
  const today = todayKey();

  useEffect(() => {
    if (!id || !scopeId) {
      console.log('LabourProfile: missing id or scopeId', { id, scopeId });
      return;
    }
    
    setLoading(true);
    console.log('LabourProfile: fetching labour', { id, scopeId, isSupervisor });
    
    Promise.all([
      getLabour(id).catch((e) => {
        console.error('Error fetching labour:', e);
        return null;
      }),
      getAttendanceRange(scopeId, startOfMonth, today, id, isSupervisor, isSupervisor ? uid : null).catch((e) => {
        console.error('Error fetching attendance:', e);
        return [];
      }),
      getPayments(scopeId, { labourId: id }).catch((e) => {
        console.error('Error fetching payments:', e);
        return [];
      }),
    ])
      .then(([l, att, pay]) => {
        console.log('LabourProfile: fetch success', { labour: !!l, attendanceCount: att?.length, paymentsCount: pay?.length });
        
        if (!l) {
          console.warn('LabourProfile: labour not found for id', id);
          toast.error('Labour not found');
          navigate('/labours');
          return;
        }
        setLabour(l);
        setAttendance(att || []);
        setPayments(pay || []);
      })
      .catch((e) => {
        console.error('LabourProfile: fetch error', e);
        toast.error('Failed to load labour: ' + (e.message || 'Unknown error'));
        navigate('/labours');
      })
      .finally(() => setLoading(false));
  }, [id, scopeId, startOfMonth, today, isSupervisor, uid, navigate]);

  const stats = useMemo(() => {
    const s = { present: 0, absent: 0, half: 0 };
    let otHours = 0;
    attendance.forEach((r) => {
      if (s[r.status] !== undefined) s[r.status]++;
      otHours += Number(r.overtimeHours) || 0;
    });
    const totalDays = s.present + s.half * 0.5;
    const dailyWage = Number(labour?.dailyWage) || 0;
    const otRate = Number(labour?.overtimeWagePerHour) || 0;
    const gross = totalDays * dailyWage + otHours * otRate;
    const advances = payments
      .filter((p) => p.type === 'advance')
      .reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
    return { ...s, otHours, gross, advances, net: gross - advances };
  }, [attendance, payments, labour]);

  const openEdit = () => {
    setForm({
      name: labour?.name || '',
      phone: labour?.phone || '',
      skill: labour?.skill || '',
      dailyWage: labour?.dailyWage ?? '',
      overtimeWagePerHour: labour?.overtimeWagePerHour ?? '',
      defaultOvertimeHours: labour?.defaultOvertimeHours ?? '',
    });
    setEditOpen(true);
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      await updateLabour(id, form);
      setLabour((prev) => ({ ...prev, ...form }));
      toast.success('Labour updated');
      setEditOpen(false);
    } catch (e) {
      console.error(e);
      toast.error('Failed to update');
    } finally {
      setSaving(false);
    }
  };

  const handleExport = () => {
    const rows = attendance.map((r) => ({
      Date: r.date,
      Status: r.status,
      'OT Hours': r.overtimeHours,
    }));
    const payRows = payments.map((p) => ({
      Date: p.date instanceof Date ? toDateKey(p.date) : '',
      Type: p.type,
      Amount: p.amount,
      Notes: p.notes,
    }));
    exportCSV(`${labour?.name || id}_attendance.csv`, rows);
    toast.success('Attendance CSV downloaded');
    void payRows;
  };

  if (loading) return <LoadingSpinner label="Loading labour profile…" />;
  
  if (!scopeId) {
    return (
      <div className="space-y-4">
        <Button variant="outline" onClick={() => navigate('/labours')} className="gap-2">
          <ArrowLeft className="h-4 w-4" /> Back
        </Button>
        <p className="text-slate-500">Please select a contractor first, then view the labour profile.</p>
      </div>
    );
  }
  
  if (!labour) {
    return (
      <div className="space-y-4">
        <Button variant="outline" onClick={() => navigate('/labours')} className="gap-2">
          <ArrowLeft className="h-4 w-4" /> Back
        </Button>
        <p className="text-slate-500">Labour not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Button variant="outline" onClick={() => navigate('/labours')} className="gap-2">
          <ArrowLeft className="h-4 w-4" /> Back
        </Button>
        <div className="flex-1">
          <h2 className="text-2xl font-semibold tracking-tight text-slate-950">{labour.name}</h2>
          <p className="text-sm text-slate-500">Labour profile · {id.slice(0, 8)}…</p>
        </div>
        <Button variant="outline" onClick={handleExport} className="gap-2">
          <Download className="h-4 w-4" /> Export CSV
        </Button>
        <Button onClick={openEdit} className="gap-2 bg-blue-600 text-white hover:bg-blue-700">
          <Pencil className="h-4 w-4" /> Edit
        </Button>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <div className="rounded-2xl border border-slate-200/70 bg-white/90 p-5 shadow-sm lg:col-span-1">
          <div className="flex items-center gap-4">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-blue-100 text-lg font-bold text-blue-700">
              {initials(labour.name)}
            </div>
            <div>
              <p className="text-lg font-semibold text-slate-900">{labour.name}</p>
              <p className="flex items-center gap-1 text-sm text-slate-500">
                <Phone className="h-3.5 w-3.5" />
                {labour.phone || 'No phone'}
              </p>
              {labour.skill && (
                <p className="mt-0.5 text-xs font-medium text-slate-400">{labour.skill}</p>
              )}
            </div>
          </div>
          <div className="mt-4 space-y-2 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-slate-500 flex items-center gap-1">
                <IndianRupee className="h-3.5 w-3.5" /> Daily Wage
              </span>
              <span className="font-semibold">{formatCurrency(labour.dailyWage)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-slate-500">OT Rate / hr</span>
              <span className="font-semibold">{formatCurrency(labour.overtimeWagePerHour)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-slate-500">Default OT hrs</span>
              <span className="font-semibold">{labour.defaultOvertimeHours || 0}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-slate-500">Status</span>
              <StatusBadge status={labour.isActive === false ? 'inactive' : 'active'} />
            </div>
          </div>
        </div>

        <div className="space-y-4 lg:col-span-2">
          <div className="grid gap-3 sm:grid-cols-3">
            <Stat label="Present (this month)" value={stats.present} />
            <Stat label="Half day" value={stats.half} />
            <Stat label="Absent" value={stats.absent} />
            <Stat label="OT Hours" value={stats.otHours} />
            <Stat label="Gross Earned" value={formatCurrency(stats.gross)} sub="this month" />
            <Stat
              label="Net Payable"
              value={formatCurrency(stats.net)}
              sub={`after ${formatCurrency(stats.advances)} advances`}
            />
          </div>
        </div>
      </div>

      <div className="rounded-2xl border border-slate-200/70 bg-white/90 p-5 shadow-sm">
        <div className="mb-4 flex items-center gap-2">
          <CalendarDays className="h-4 w-4 text-slate-400" />
          <h3 className="text-base font-semibold text-slate-900">Attendance Heatmap — Last 30 days</h3>
        </div>
        <AttendanceHeatmap labourId={id} days={30} />
      </div>

      <div className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm">
        <div className="flex items-center gap-2 border-b border-slate-100 px-5 py-4">
          <TrendingUp className="h-4 w-4 text-slate-400" />
          <h3 className="text-base font-semibold text-slate-900">Payment History</h3>
        </div>
        {payments.length === 0 ? (
          <p className="px-5 py-8 text-center text-sm text-slate-400">No payments recorded.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-slate-100 text-left text-xs uppercase tracking-wide text-slate-400">
                <tr>
                  <th className="px-5 py-3">Date</th>
                  <th className="px-5 py-3">Type</th>
                  <th className="px-5 py-3 text-right">Amount</th>
                  <th className="px-5 py-3">Notes</th>
                </tr>
              </thead>
              <tbody>
                {payments.map((p) => (
                  <tr key={p.id} className="border-b border-slate-100 last:border-b-0">
                    <td className="px-5 py-3 text-slate-700">{formatDate(p.date)}</td>
                    <td className="px-5 py-3">
                      <StatusBadge status={p.type || 'salary'} />
                    </td>
                    <td className="px-5 py-3 text-right font-semibold text-slate-900">
                      {formatCurrency(p.amount)}
                    </td>
                    <td className="px-5 py-3 text-slate-600">{p.notes || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Modal
        isOpen={editOpen}
        title="Edit Labour"
        onClose={() => !saving && setEditOpen(false)}
        onConfirm={handleSave}
        confirmText={saving ? 'Saving…' : 'Save changes'}
      >
        <div className="space-y-4">
          <div className="space-y-1">
            <Label>Name</Label>
            <Input value={form.name || ''} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Phone</Label>
              <Input value={form.phone || ''} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
            </div>
            <div className="space-y-1">
              <Label>Skill</Label>
              <Input value={form.skill || ''} onChange={(e) => setForm({ ...form, skill: e.target.value })} />
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <div className="space-y-1">
              <Label>Daily Wage (₹)</Label>
              <Input type="number" value={form.dailyWage || ''} onChange={(e) => setForm({ ...form, dailyWage: e.target.value })} />
            </div>
            <div className="space-y-1">
              <Label>OT Rate (₹/hr)</Label>
              <Input type="number" value={form.overtimeWagePerHour || ''} onChange={(e) => setForm({ ...form, overtimeWagePerHour: e.target.value })} />
            </div>
            <div className="space-y-1">
              <Label>Default OT hrs</Label>
              <Input type="number" step="0.5" value={form.defaultOvertimeHours || ''} onChange={(e) => setForm({ ...form, defaultOvertimeHours: e.target.value })} />
            </div>
          </div>
        </div>
      </Modal>
    </div>
  );
}
