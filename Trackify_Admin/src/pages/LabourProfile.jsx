import React, { useEffect, useMemo, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ArrowLeft, Phone, Pencil, Download, IndianRupee, CalendarDays, TrendingUp } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { getLabour, updateLabour } from '../lib/services/labours.service';
import { getAttendanceRange } from '../lib/services/attendance.service';
import { getPayments } from '../lib/services/payments.service';
import { toDateKey, formatCurrency, initials, exportExcel, todayKey } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import AttendanceHeatmap from '../components/shared/AttendanceHeatmap';
import StatusBadge from '../components/shared/StatusBadge';
import Modal from '../components/ui/Modal';

function Stat({ label, value, sub, colorClass = "from-border to-border/50" }) {
  return (
    <div className="relative overflow-hidden rounded-xl border border-border bg-bg-card px-4 py-3 shadow-sm group hover:border-border-strong transition-all">
      <div className={`absolute bottom-0 left-0 h-1 w-full bg-gradient-to-r ${colorClass} opacity-80`} />
      <p className="text-[10px] font-medium uppercase tracking-widest text-text-muted">{label}</p>
      <p className="mt-1 text-2xl font-mono font-semibold text-text-primary group-hover:scale-105 origin-left transition-transform">{value}</p>
      {sub && <p className="mt-0.5 text-[11px] text-text-secondary">{sub}</p>}
    </div>
  );
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

      return;
    }
    
    setLoading(true);

    
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
    const s = { present: 0, three_quarter: 0, half: 0, quarter: 0, absent: 0 };
    let otHours = 0;
    attendance.forEach((r) => {
      if (s[r.status] !== undefined) s[r.status]++;
      otHours += Number(r.overtimeHours) || 0;
    });
    const totalDays = s.present + s.three_quarter * 0.75 + s.half * 0.5 + s.quarter * 0.25;
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
    exportExcel(`${labour?.name || id}_attendance.csv`, rows);
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
        <p className="text-text-secondary">Please select a contractor first, then view the labour profile.</p>
      </div>
    );
  }
  
  if (!labour) {
    return (
      <div className="space-y-4">
        <Button variant="outline" onClick={() => navigate('/labours')} className="gap-2">
          <ArrowLeft className="h-4 w-4" /> Back
        </Button>
        <p className="text-text-secondary">Labour not found.</p>
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
          <h2 className="text-2xl font-semibold tracking-tight text-text-primary">{labour.name}</h2>
          <p className="text-[13px] text-text-secondary">Labour profile · <span className="font-mono">{id.slice(0, 8)}</span>…</p>
        </div>
        <Button variant="outline" onClick={handleExport} className="gap-2 text-text-secondary hover:text-text-primary">
          <Download className="h-4 w-4" /> Export CSV
        </Button>
        <Button onClick={openEdit} className="gap-2 bg-gold text-bg-primary hover:bg-gold-hover shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-105 transition-all">
          <Pencil className="h-4 w-4" /> Edit
        </Button>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <div className="relative overflow-hidden rounded-2xl border border-border/50 bg-gradient-to-br from-indigo-950/40 via-bg-card to-bg-card p-5 shadow-sm lg:col-span-1">
          <div className="absolute top-0 right-0 -mt-10 -mr-10 h-32 w-32 rounded-full bg-indigo-500/10 blur-3xl"></div>
          <div className="relative flex items-center gap-4">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-gradient-to-tr from-gold to-orange-400 border border-gold-light/50 text-lg font-mono font-bold text-bg-primary shadow-[0_0_15px_rgba(245,166,35,0.3)]">
              {initials(labour.name)}
            </div>
            <div>
              <p className="text-lg font-semibold text-text-primary">{labour.name}</p>
              <p className="flex items-center gap-1.5 text-[13px] text-text-secondary">
                <Phone className="h-3.5 w-3.5" />
                <span className="font-mono">{labour.phone || 'No phone'}</span>
              </p>
              {labour.skill && (
                <p className="mt-0.5 text-[11px] font-medium tracking-wider uppercase text-text-muted">{labour.skill}</p>
              )}
            </div>
          </div>
          <div className="mt-4 space-y-3 text-[13px]">
            <div className="flex items-center justify-between">
              <span className="text-text-muted flex items-center gap-1.5 uppercase tracking-widest text-[10px] font-medium">
                <IndianRupee className="h-3.5 w-3.5" /> Daily Wage
              </span>
              <span className="font-mono font-semibold text-text-primary">{formatCurrency(labour.dailyWage)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-text-muted uppercase tracking-widest text-[10px] font-medium">OT Rate / hr</span>
              <span className="font-mono font-semibold text-text-primary">{formatCurrency(labour.overtimeWagePerHour)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-text-muted uppercase tracking-widest text-[10px] font-medium">Default OT hrs</span>
              <span className="font-mono font-semibold text-text-primary">{labour.defaultOvertimeHours || 0}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-text-muted uppercase tracking-widest text-[10px] font-medium">Status</span>
              <StatusBadge status={labour.isActive === false ? 'inactive' : 'active'} />
            </div>
          </div>
        </div>

        <div className="space-y-4 lg:col-span-2">
          <div className="grid gap-3 sm:grid-cols-3">
            <Stat label="Present (this month)" value={stats.present} colorClass="from-emerald-500 to-emerald-700" />
            <Stat label="Half day" value={stats.half} colorClass="from-amber-500 to-orange-500" />
            <Stat label="Absent" value={stats.absent} colorClass="from-rose-500 to-red-600" />
            <Stat label="OT Hours" value={stats.otHours} colorClass="from-blue-500 to-indigo-600" />
            <Stat label="Gross Earned" value={formatCurrency(stats.gross)} sub="this month" colorClass="from-gold to-gold-dark" />
            <Stat
              label="Net Payable"
              value={formatCurrency(stats.net)}
              sub={`after ${formatCurrency(stats.advances)} advances`}
              colorClass="from-violet-500 to-purple-600"
            />
          </div>
        </div>
      </div>

      <div className="rounded-2xl border border-border bg-bg-card p-5 shadow-sm">
        <div className="mb-4 flex items-center gap-2 text-text-primary">
          <CalendarDays className="h-4 w-4 text-gold" />
          <h3 className="text-base font-semibold">Attendance Heatmap — Last 30 days</h3>
        </div>
        <div className="rounded-xl border border-border-strong bg-bg-elevated p-4">
          <AttendanceHeatmap labourId={id} days={30} />
        </div>
      </div>

      <div className="rounded-2xl border border-border bg-bg-card shadow-sm overflow-hidden">
        <div className="flex items-center gap-2 border-b border-border-strong px-5 py-4 bg-bg-elevated text-text-primary">
          <TrendingUp className="h-4 w-4 text-gold" />
          <h3 className="text-base font-semibold">Payment History</h3>
        </div>
        {payments.length === 0 ? (
          <p className="px-5 py-8 text-center text-sm text-text-muted">No payments recorded.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-border bg-bg-elevated text-left text-[10px] uppercase tracking-widest text-text-muted">
                <tr>
                  <th className="px-6 py-4 font-medium">Date</th>
                  <th className="px-6 py-4 font-medium">Type</th>
                  <th className="px-6 py-4 font-medium text-right">Amount</th>
                  <th className="px-6 py-4 font-medium">Notes</th>
                </tr>
              </thead>
              <tbody>
                {payments.map((p) => (
                  <tr key={p.id} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                    <td className="px-6 py-4 font-mono text-text-secondary">{formatDate(p.date)}</td>
                    <td className="px-6 py-4">
                      <StatusBadge status={p.type || 'salary'} />
                    </td>
                    <td className="px-6 py-4 text-right font-mono font-medium text-text-primary">
                      {formatCurrency(p.amount)}
                    </td>
                    <td className="px-6 py-4 text-[13px] text-text-secondary">{p.notes || '—'}</td>
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
