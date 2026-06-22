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
  updateUser,
} from '../lib/services/users.service';
import { getSecondaryAuth } from '../lib/firebase';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import Modal from '../components/ui/Modal';

const EMPTY_FORM = { id: null, name: '', email: '', phone: '', password: '', role: 'supervisor' };

function getRoleConfig(role) {
  switch (role) {
    case 'super_admin': return { label: 'Super Admin', bg: 'bg-info-bg', text: 'text-info', border: 'border-info/30', icon: Shield };
    case 'contractor':  return { label: 'Contractor',  bg: 'bg-gold-bg',   text: 'text-gold',   border: 'border-gold/30',   icon: Briefcase };
    case 'supervisor':  return { label: 'Supervisor',  bg: 'bg-success-bg', text: 'text-success', border: 'border-success/30', icon: UserCheck };
    default: return { label: role, bg: 'bg-bg-elevated', text: 'text-text-secondary', border: 'border-border-strong', icon: UsersIcon };
  }
}

function AvatarInitial({ name, role }) {
  const colors = {
    super_admin: 'bg-info/20 text-info border border-info/30',
    contractor:  'bg-gold/20 text-gold border border-gold/30',
    supervisor:  'bg-success/20 text-success border border-success/30',
  };
  return (
    <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-[12px] font-mono font-medium ${colors[role] || 'bg-bg-elevated text-text-muted'}`}>
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
  const openEdit = (user) => {
    setForm({
      id: user.id,
      name: user.name || '',
      email: user.email || '',
      phone: user.phone || '',
      role: user.role,
      password: '', // Leave blank for edit
    });
    setDialogOpen(true);
  };
  const closeDialog = () => { if (saving) return; setDialogOpen(false); };
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['users'] });

  const handleSubmit = async () => {
    if (!form.name.trim()) return toast.error('Name is required');
    if (!form.id && !form.email.trim()) return toast.error('Email is required');
    if (!form.id && form.password.length < 6) return toast.error('Password must be at least 6 characters');
    if (!form.id && form.role !== 'contractor' && !activeContractorId) { toast.error('No contractor selected'); return; }
    
    setSaving(true);
    try {
      if (form.id) {
        // Edit existing user
        await updateUser(form.id, {
          name: form.name.trim(),
          phone: form.phone.trim(),
        });
        toast.success('User updated');
        invalidate();
        setDialogOpen(false);
      } else {
        // Create new user
        const secondary = getSecondaryAuth();
        const cred = await createUserWithEmailAndPassword(secondary, form.email.trim(), form.password);
        await createUser(cred.user.uid, {
          name: form.name.trim(),
          email: form.email.trim(),
          phone: form.phone.trim(),
          role: form.role,
          contractorId: form.role === 'contractor' ? cred.user.uid : activeContractorId,
          supervisorId: form.role === 'supervisor' ? cred.user.uid : null,
          isActive: true,
        });
        if (form.role === 'contractor') {
          await setDoc(doc(db, 'contractors', cred.user.uid), {
            name: form.name.trim(),
            email: form.email.trim(),
            phone: form.phone.trim(),
            plan: 'free',
            isActive: true,
            createdAt: serverTimestamp(),
          });
        }
        try { await signOut(secondary); } catch (_) {}
        toast.success('User created');
        invalidate();
        setDialogOpen(false);
      }
    } catch (err) {
      console.error(err);
      const msg =
        err?.code === 'auth/email-already-in-use' ? 'That email is already in use'
        : err?.code === 'auth/invalid-email' ? 'Invalid email address'
        : 'Failed to save user';
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
          <p className="text-[10px] font-medium uppercase tracking-widest text-text-muted">Administration</p>
          <p className="mt-1 text-[13px] text-text-secondary">{users.length} user{users.length === 1 ? '' : 's'} for the active contractor.</p>
        </div>
        <Button onClick={openAdd} className="gap-2 bg-gold text-bg-primary hover:bg-gold-hover shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-105 transition-all">
          <Plus className="h-4 w-4" /> Add User
        </Button>
      </div>

      <div className="rounded-2xl border border-border bg-bg-card shadow-sm overflow-hidden">
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
            <table className="w-full text-[13px]">
              <thead className="border-b border-border bg-bg-elevated">
                <tr>
                  {['User', 'Email', 'Role', 'Status', 'Actions'].map((h, i) => (
                    <th key={h} className={`px-6 py-4 text-[10px] font-medium uppercase tracking-widest text-text-muted ${i === 4 ? 'text-right' : 'text-left'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {users.map((u) => {
                  const cfg = getRoleConfig(u.role);
                  return (
                    <tr key={u.id} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <AvatarInitial name={u.name} role={u.role} />
                          <div>
                            <p className="font-medium text-text-primary text-[14px]">{u.name}</p>
                            <p className="text-[12px] text-text-muted mt-0.5">{u.email}</p>
                            {u.phone && <p className="text-[11px] text-text-muted mt-0.5">{u.phone}</p>}
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 font-mono text-text-secondary hidden md:table-cell">{u.email}</td>
                      <td className="px-6 py-4">
                        <span className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] uppercase tracking-wider font-bold ${cfg.bg} ${cfg.text} ${cfg.border}`}>
                          <cfg.icon className="h-3 w-3" />
                          {cfg.label}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        {u.isActive === false ? (
                          <span className="inline-flex items-center rounded-full bg-danger-bg px-2.5 py-1 text-[11px] uppercase tracking-wider font-bold text-danger border border-danger/30">Inactive</span>
                        ) : (
                          <span className="inline-flex items-center rounded-full bg-success-bg px-2.5 py-1 text-[11px] uppercase tracking-wider font-bold text-success border border-success/30">Active</span>
                        )}
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center justify-end gap-2">
                          <Button variant="outline" size="sm" onClick={() => openEdit(u)} className="gap-1.5 text-text-secondary border-border-strong hover:bg-bg-elevated h-8 text-[12px]">
                            Edit
                          </Button>
                          {u.isActive === false ? (
                            <Button variant="outline" size="sm" onClick={() => handleActivate(u)} className="gap-1.5 text-success border-success/30 hover:bg-success-bg h-8 text-[12px]">
                              <RotateCcw className="h-3.5 w-3.5" /> Activate
                            </Button>
                          ) : (
                            <Button variant="outline" size="sm" onClick={() => handleDeactivate(u)} className="gap-1.5 text-danger border-danger/30 hover:bg-danger-bg h-8 text-[12px]">
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

      <Modal isOpen={dialogOpen} title={form.id ? "Edit User" : "Add User"} onClose={closeDialog} onConfirm={handleSubmit} confirmText={saving ? 'Saving…' : (form.id ? 'Save changes' : 'Create user')}>
        <div className="space-y-4">
          <div className="space-y-1.5">
            <Label className="text-[11px] uppercase tracking-wider text-text-muted">Full name *</Label>
            <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Full name" className="h-10 bg-bg-input" />
          </div>
          <div className="space-y-1.5">
            <Label className="text-[11px] uppercase tracking-wider text-text-muted">Phone Number (Optional)</Label>
            <Input type="tel" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder="+91 9876543210" className="h-10 bg-bg-input" />
          </div>
          {!form.id && (
            <>
              <div className="space-y-1.5">
                <Label className="text-[11px] uppercase tracking-wider text-text-muted">Email address *</Label>
                <Input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="user@example.com" className="h-10 bg-bg-input" />
              </div>
              <div className="space-y-1.5">
                <Label className="text-[11px] uppercase tracking-wider text-text-muted">Temporary password *</Label>
                <Input type="text" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} placeholder="Minimum 6 characters" className="h-10 bg-bg-input" />
              </div>
              <div className="space-y-1.5">
                <Label className="text-[11px] uppercase tracking-wider text-text-muted">Role</Label>
                <select
                  value={form.role}
                  onChange={(e) => setForm({ ...form, role: e.target.value })}
                  className="h-10 w-full rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary shadow-sm outline-none focus:border-gold"
                >
                  {roleOptions.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
                </select>
              </div>
            </>
          )}
        </div>
      </Modal>
    </div>
  );
}
