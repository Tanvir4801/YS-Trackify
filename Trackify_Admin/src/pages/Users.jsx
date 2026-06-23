import React, { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { createUserWithEmailAndPassword, signOut } from 'firebase/auth';
import { Plus, Ban, RotateCcw, Users as UsersIcon, Shield, Briefcase, UserCheck } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore } from '../store/authStore';
import { useUsers } from '../hooks/useUsers';
import { doc, setDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../lib/firebase';
import {
  createUser,
  deactivateUser,
  activateUser,
} from '../lib/services/users.service';
import { getSecondaryAuth } from '../lib/firebase';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import Modal from '../components/ui/Modal';

const EMPTY_FORM = { name: '', email: '', password: '', role: 'supervisor' };

function getRoleConfig(role) {
  switch (role) {
    case 'super_admin': return { label: 'Super Admin', bg: 'bg-purple-50', text: 'text-purple-700', border: 'border-purple-200', icon: Shield };
    case 'contractor':  return { label: 'Contractor',  bg: 'bg-blue-50',   text: 'text-blue-700',   border: 'border-blue-200',   icon: Briefcase };
    case 'supervisor':  return { label: 'Supervisor',  bg: 'bg-emerald-50', text: 'text-emerald-700', border: 'border-emerald-200', icon: UserCheck };
    default: return { label: role, bg: 'bg-slate-50', text: 'text-slate-600', border: 'border-slate-200', icon: UsersIcon };
  }
}

function AvatarInitial({ name, role }) {
  const colors = {
    super_admin: 'bg-purple-600',
    contractor:  'bg-blue-600',
    supervisor:  'bg-emerald-600',
  };
  return (
    <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-sm font-bold text-white ${colors[role] || 'bg-slate-500'}`}>
      {(name || '?')[0].toUpperCase()}
    </div>
  );
}

export default function Users() {
  const role = useAuthStore((s) => s.role);
  const activeContractorId = useAuthStore((s) => s.activeContractorId);
  const queryClient = useQueryClient();

  const { data: users = [], isLoading } = useUsers();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);

  const roleOptions = role === 'super_admin'
    ? [{ value: 'contractor', label: 'Contractor' }, { value: 'supervisor', label: 'Supervisor' }]
    : [{ value: 'supervisor', label: 'Supervisor' }];

  const openAdd = () => { setForm({ ...EMPTY_FORM, role: roleOptions[0].value }); setDialogOpen(true); };
  const closeDialog = () => { if (saving) return; setDialogOpen(false); };
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['users'] });

  const handleSubmit = async () => {
    if (!form.name.trim()) return toast.error('Name is required');
    if (!form.email.trim()) return toast.error('Email is required');
    if (form.password.length < 6) return toast.error('Password must be at least 6 characters');
    if (form.role !== 'contractor' && !activeContractorId) { toast.error('No contractor selected'); return; }
    setSaving(true);
    const secondary = getSecondaryAuth();
    try {
      const cred = await createUserWithEmailAndPassword(secondary, form.email.trim(), form.password);
      await createUser(cred.user.uid, {
        name: form.name.trim(),
        email: form.email.trim(),
        role: form.role,
        contractorId: form.role === 'contractor' ? cred.user.uid : activeContractorId,
        supervisorId: form.role === 'supervisor' ? cred.user.uid : null,
        isActive: true,
      });
      if (form.role === 'contractor') {
        await setDoc(doc(db, 'contractors', cred.user.uid), {
          name: form.name.trim(),
          email: form.email.trim(),
          phone: form.phone || '',
          plan: 'free',
          isActive: true,
          createdAt: serverTimestamp(),
        });
      }
      try { await signOut(secondary); } catch (_) {}
      toast.success('User created');
      invalidate();
      setDialogOpen(false);
    } catch (err) {
      console.error(err);
      const msg =
        err?.code === 'auth/email-already-in-use' ? 'That email is already in use'
        : err?.code === 'auth/invalid-email' ? 'Invalid email address'
        : 'Failed to create user';
      toast.error(msg);
    } finally {
      setSaving(false);
    }
  };

  const handleDeactivate = async (user) => {
    try { await deactivateUser(user.id); toast.success(`${user.name} deactivated`); invalidate(); }
    catch (err) { console.error(err); toast.error('Failed to deactivate'); }
  };

  const handleActivate = async (user) => {
    try { await activateUser(user.id); toast.success(`${user.name} reactivated`); invalidate(); }
    catch (err) { console.error(err); toast.error('Failed to activate'); }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">Administration</p>
          <p className="mt-1 text-sm text-slate-500">{users.length} user{users.length === 1 ? '' : 's'} for the active contractor.</p>
        </div>
        <Button onClick={openAdd} className="gap-2 text-white" style={{ background: '#2563EB' }}>
          <Plus className="h-4 w-4" /> Add User
        </Button>
      </div>

      <div className="rounded-2xl border border-slate-200/70 bg-white shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="py-12"><LoadingSpinner label="Loading users…" /></div>
        ) : users.length === 0 ? (
          <EmptyState
            icon={UsersIcon}
            title="No users yet"
            description="Add your first contractor or supervisor to get started."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-slate-100 bg-slate-50/50">
                <tr>
                  {['User', 'Email', 'Role', 'Status', 'Actions'].map((h, i) => (
                    <th key={h} className={`px-5 py-3 text-xs font-bold uppercase tracking-wide text-slate-400 ${i === 4 ? 'text-right' : 'text-left'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {users.map((u) => {
                  const cfg = getRoleConfig(u.role);
                  return (
                    <tr key={u.id} className="border-b border-slate-50 last:border-b-0 hover:bg-slate-50/60 transition-colors">
                      <td className="px-5 py-3.5">
                        <div className="flex items-center gap-3">
                          <AvatarInitial name={u.name} role={u.role} />
                          <div>
                            <p className="font-semibold text-slate-900">{u.name}</p>
                            <p className="text-xs text-slate-400 mt-0.5">{u.email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-5 py-3.5 text-slate-600 hidden md:table-cell">{u.email}</td>
                      <td className="px-5 py-3.5">
                        <span className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-semibold ${cfg.bg} ${cfg.text} ${cfg.border}`}>
                          <cfg.icon className="h-3 w-3" />
                          {cfg.label}
                        </span>
                      </td>
                      <td className="px-5 py-3.5">
                        {u.isActive === false ? (
                          <span className="inline-flex items-center rounded-full bg-red-50 px-2.5 py-1 text-xs font-semibold text-red-700 border border-red-200">Inactive</span>
                        ) : (
                          <span className="inline-flex items-center rounded-full bg-green-50 px-2.5 py-1 text-xs font-semibold text-green-700 border border-green-200">Active</span>
                        )}
                      </td>
                      <td className="px-5 py-3.5">
                        <div className="flex items-center justify-end gap-2">
                          {u.isActive === false ? (
                            <Button variant="outline" size="sm" onClick={() => handleActivate(u)} className="gap-1.5 text-green-700 border-green-200 hover:bg-green-50 h-8">
                              <RotateCcw className="h-3.5 w-3.5" /> Activate
                            </Button>
                          ) : (
                            <Button variant="outline" size="sm" onClick={() => handleDeactivate(u)} className="gap-1.5 text-red-600 border-red-200 hover:bg-red-50 h-8">
                              <Ban className="h-3.5 w-3.5" /> Deactivate
                            </Button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Modal isOpen={dialogOpen} title="Add User" onClose={closeDialog} onConfirm={handleSubmit} confirmText={saving ? 'Creating…' : 'Create user'}>
        <div className="space-y-4">
          <div className="space-y-1.5">
            <Label className="text-sm font-semibold text-slate-700">Full name *</Label>
            <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Full name" className="h-10" />
          </div>
          <div className="space-y-1.5">
            <Label className="text-sm font-semibold text-slate-700">Email address *</Label>
            <Input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="user@example.com" className="h-10" />
          </div>
          <div className="space-y-1.5">
            <Label className="text-sm font-semibold text-slate-700">Temporary password *</Label>
            <Input type="text" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} placeholder="Minimum 6 characters" className="h-10" />
          </div>
          <div className="space-y-1.5">
            <Label className="text-sm font-semibold text-slate-700">Role</Label>
            <select
              value={form.role}
              onChange={(e) => setForm({ ...form, role: e.target.value })}
              className="h-10 w-full rounded-lg border border-slate-200 bg-white px-3 text-sm text-slate-900 shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
            >
              {roleOptions.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
          </div>
        </div>
      </Modal>
    </div>
  );
}
