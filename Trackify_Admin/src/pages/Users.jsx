import React, { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { createUserWithEmailAndPassword, signOut } from 'firebase/auth';
import { Plus, Ban, RotateCcw, Users as UsersIcon } from 'lucide-react';
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
import StatusBadge from '../components/shared/StatusBadge';
import Modal from '../components/ui/Modal';

const ROLE_OPTIONS = [
  { value: 'contractor', label: 'Contractor' },
  { value: 'supervisor', label: 'Supervisor' },
];

const EMPTY_FORM = {
  name: '',
  email: '',
  password: '',
  role: 'supervisor',
};

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

  const openAdd = () => {
    setForm({ ...EMPTY_FORM, role: roleOptions[0].value });
    setDialogOpen(true);
  };

  const closeDialog = () => {
    if (saving) return;
    setDialogOpen(false);
  };

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['users'] });

  const handleSubmit = async () => {
    if (!form.name.trim()) return toast.error('Name is required');
    if (!form.email.trim()) return toast.error('Email is required');
    if (form.password.length < 6) return toast.error('Password must be at least 6 characters');
    if (form.role !== 'contractor' && !activeContractorId) {
      toast.error('No contractor selected');
      return;
    }
    setSaving(true);
    const secondary = getSecondaryAuth();
    try {
      const cred = await createUserWithEmailAndPassword(
        secondary,
        form.email.trim(),
        form.password,
      );
      await createUser(cred.user.uid, {
        name: form.name.trim(),
        email: form.email.trim(),
        role: form.role,
        contractorId:
          form.role === 'contractor'
            ? cred.user.uid
            : activeContractorId, supervisorId: form.role === 'supervisor' ? cred.user.uid : null,
        isActive: true,
      });
      if (form.role === 'contractor') {
        await setDoc(
          doc(db, 'contractors', cred.user.uid),
          {
            name: form.name.trim(),
            email: form.email.trim(),
            phone: form.phone || '',
            plan: 'free',
            isActive: true,
            createdAt: serverTimestamp(),
          }
        );
      }
      try {
        await signOut(secondary);
      } catch (_) {
        /* noop */
      }
      toast.success('User created');
      invalidate();
      setDialogOpen(false);
    } catch (err) {
      console.error(err);
      const msg =
        err?.code === 'auth/email-already-in-use'
          ? 'That email is already in use'
          : err?.code === 'auth/invalid-email'
            ? 'Invalid email address'
            : 'Failed to create user';
      toast.error(msg);
    } finally {
      setSaving(false);
    }
  };

  const handleDeactivate = async (user) => {
    try {
      await deactivateUser(user.id);
      toast.success(`${user.name} deactivated`);
      invalidate();
    } catch (err) {
      console.error(err);
      toast.error('Failed to deactivate');
    }
  };

  const handleActivate = async (user) => {
    try {
      await activateUser(user.id);
      toast.success(`${user.name} reactivated`);
      invalidate();
    } catch (err) {
      console.error(err);
      toast.error('Failed to activate');
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-2xl font-semibold tracking-tight text-slate-950">Users</h2>
          <p className="mt-1 text-sm text-slate-500">
            {users.length} user{users.length === 1 ? '' : 's'} for the active contractor.
          </p>
        </div>
        <Button
          onClick={openAdd}
          className="gap-2 bg-blue-600 text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" /> Add User
        </Button>
      </div>

      <div className="rounded-2xl border border-slate-200/70 bg-white/90 shadow-sm">
        {isLoading ? (
          <LoadingSpinner label="Loading users…" />
        ) : users.length === 0 ? (
          <EmptyState
            icon={UsersIcon}
            title="No users yet"
            description="Add your first contractor or supervisor to get started."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th className="px-4 py-3">Name</th>
                  <th className="px-4 py-3">Email</th>
                  <th className="px-4 py-3">Role</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id} className="border-b border-slate-100 last:border-b-0">
                    <td className="px-4 py-3 font-medium text-slate-900">{u.name}</td>
                    <td className="px-4 py-3 text-slate-700">{u.email}</td>
                    <td className="px-4 py-3">
                      <StatusBadge status={u.role} />
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge status={u.isActive === false ? 'inactive' : 'active'} />
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center justify-end gap-2">
                        {u.isActive === false ? (
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => handleActivate(u)}
                            className="gap-1 text-green-700"
                          >
                            <RotateCcw className="h-3.5 w-3.5" /> Activate
                          </Button>
                        ) : (
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => handleDeactivate(u)}
                            className="gap-1 text-red-600"
                          >
                            <Ban className="h-3.5 w-3.5" /> Deactivate
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Modal
        isOpen={dialogOpen}
        title="Add User"
        onClose={closeDialog}
        onConfirm={handleSubmit}
        confirmText={saving ? 'Creating…' : 'Create user'}
      >
        <div className="space-y-4">
          <div className="space-y-1">
            <Label>Name *</Label>
            <Input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Full name"
            />
          </div>
          <div className="space-y-1">
            <Label>Email *</Label>
            <Input
              type="email"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
              placeholder="user@example.com"
            />
          </div>
          <div className="space-y-1">
            <Label>Temporary password *</Label>
            <Input
              type="text"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              placeholder="Minimum 6 characters"
            />
          </div>
          <div className="space-y-1">
            <Label>Role</Label>
            <select
              value={form.role}
              onChange={(e) => setForm({ ...form, role: e.target.value })}
              className="h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
            >
              {roleOptions.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>
        </div>
      </Modal>
    </div>
  );
}
