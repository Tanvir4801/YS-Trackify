import React, { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Search, Users, Briefcase, IndianRupee, TrendingUp, AlertCircle, Phone, MapPin, Pencil, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';

import { useAuthStore, useScopeId } from '../../store/authStore';
import { useClients } from '../../hooks/useClients';
import { useProjects } from '../../hooks/useProjects';
import { addClient, updateClient, deleteClient } from '../../lib/services/clients.service';
import { formatCurrency } from '../../lib/utils';

import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Label } from '../../components/ui/label';
import Modal from '../../components/ui/Modal';
import EmptyState from '../../components/shared/EmptyState';
import LoadingSpinner from '../../components/shared/LoadingSpinner';
import StatusBadge from '../../components/shared/StatusBadge';

const EMPTY_FORM = {
  name: '',
  phone: '',
  email: '',
  address: '',
  city: '',
  notes: '',
};

export default function ClientList() {
  const navigate = useNavigate();
  const activeContractorId = useAuthStore((s) => s.activeContractorId);
  const scopeId = useScopeId();

  const { data: clients, isLoading: clientsLoading, error: clientsError } = useClients();
  const { data: projects, isLoading: projectsLoading, error: projectsError } = useProjects();

  const [search, setSearch] = useState('');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState(null);
  const [saving, setSaving] = useState(false);

  const isLoading = clientsLoading || projectsLoading;

  // Filter clients based on search
  const filteredClients = useMemo(() => {
    return clients.filter((c) => {
      if (!search) return true;
      const q = search.toLowerCase();
      return (
        c.name?.toLowerCase().includes(q) ||
        c.phone?.includes(q) ||
        c.city?.toLowerCase().includes(q)
      );
    });
  }, [clients, search]);

  // Summaries
  const stats = useMemo(() => {
    let totalContractValue = 0;
    let amountReceived = 0;
    // Note: since we don't have global payments hook yet, we'll approximate received if it's on project, 
    // or we'll just show contract value for now. 
    // Wait, the prompt says "Total contract value · Amount received · Amount pending". 
    // We can compute these if we store receivedAmount on the project level when a payment is added. 
    // For now we'll sum up contractValue from projects.
    
    let activeProjects = 0;

    projects.forEach(p => {
      if (p.status !== 'completed') activeProjects++;
      totalContractValue += Number(p.contractValue || 0);
      amountReceived += Number(p.receivedAmount || 0);
    });

    return {
      totalClients: clients.length,
      activeProjects,
      totalContractValue,
      amountReceived,
      amountPending: totalContractValue - amountReceived
    };
  }, [clients, projects]);

  const handleSubmit = async () => {
    if (!form.name.trim()) return toast.error('Client name is required');
    if (!form.phone.trim()) return toast.error('Phone number is required');
    
    setSaving(true);
    const t = toast.loading(editingId ? 'Updating client...' : 'Adding client...');
    try {
      if (editingId) {
        await updateClient(editingId, form);
        toast.dismiss(t);
        toast.success('Client updated successfully');
        setDialogOpen(false);
      } else {
        const clientId = await addClient({
          contractorId: scopeId,
          ...form,
        });
        toast.dismiss(t);
        toast.success('Client added successfully');
        setDialogOpen(false);
        navigate(`/clients/${clientId}`);
      }
    } catch (error) {
      toast.dismiss(t);
      toast.error(editingId ? 'Failed to update client' : 'Failed to add client');
      console.error(error);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (e, clientId) => {
    e.stopPropagation();
    if (!window.confirm('Are you sure you want to delete this client? This cannot be undone.')) return;
    try {
      await deleteClient(clientId);
      toast.success('Client deleted');
    } catch (err) {
      toast.error('Failed to delete client');
    }
  };

  const openAdd = () => {
    setForm(EMPTY_FORM);
    setEditingId(null);
    setDialogOpen(true);
  };

  const openEdit = (e, client) => {
    e.stopPropagation();
    setForm({
      name: client.name || '',
      phone: client.phone || '',
      email: client.email || '',
      address: client.address || '',
      city: client.city || '',
      notes: client.notes || '',
    });
    setEditingId(client.id);
    setDialogOpen(true);
  };

  if (clientsError || projectsError) {
    return (
      <div className="p-6 bg-danger/10 border border-danger/20 rounded-xl text-danger">
        <h3 className="font-bold mb-2">Error Loading Data</h3>
        <p className="text-sm">{clientsError?.message || projectsError?.message || 'Unknown error occurred. Check console or Firestore permissions.'}</p>
      </div>
    );
  }

  if (isLoading) {
    return <LoadingSpinner label="Loading Client Ledger..." />;
  }

  return (
    <div className="space-y-6">
      {/* Header Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-bg-card border border-border rounded-xl p-5 shadow-sm">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2 bg-gold/10 text-gold rounded-lg">
              <Users className="w-5 h-5" />
            </div>
            <p className="text-[13px] font-medium text-text-muted uppercase tracking-wider">Total Clients</p>
          </div>
          <h3 className="text-2xl font-bold text-text-primary">{stats.totalClients}</h3>
        </div>

        <div className="bg-bg-card border border-border rounded-xl p-5 shadow-sm">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2 bg-info/10 text-info rounded-lg">
              <Briefcase className="w-5 h-5" />
            </div>
            <p className="text-[13px] font-medium text-text-muted uppercase tracking-wider">Active Projects</p>
          </div>
          <h3 className="text-2xl font-bold text-text-primary">{stats.activeProjects}</h3>
        </div>

        <div className="bg-bg-card border border-border rounded-xl p-5 shadow-sm">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2 bg-success/10 text-success rounded-lg">
              <IndianRupee className="w-5 h-5" />
            </div>
            <p className="text-[13px] font-medium text-text-muted uppercase tracking-wider">Total Contract Val</p>
          </div>
          <h3 className="text-2xl font-bold text-text-primary">{formatCurrency(stats.totalContractValue)}</h3>
        </div>

        <div className="bg-bg-card border border-border rounded-xl p-5 shadow-sm">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2 bg-warning/10 text-warning rounded-lg">
              <AlertCircle className="w-5 h-5" />
            </div>
            <p className="text-[13px] font-medium text-text-muted uppercase tracking-wider">Pending Amount</p>
          </div>
          <h3 className="text-2xl font-bold text-warning">{formatCurrency(stats.amountPending)}</h3>
        </div>
      </div>

      {/* Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-4 rounded-xl border border-border bg-bg-card px-5 py-4">
        <div className="relative w-full max-w-sm">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search clients by name, phone, or city..."
            className="h-9 w-full rounded-lg border border-border-strong bg-bg-input pl-9 pr-3 text-[13px] text-text-primary placeholder:text-text-muted outline-none focus:border-gold focus:ring-1 focus:ring-gold"
          />
        </div>
        <button
          onClick={openAdd}
          className="flex h-9 items-center gap-2 rounded-lg bg-gold px-4 text-[13px] font-semibold text-bg-primary shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-105 transition-all"
        >
          <Plus className="h-4 w-4" /> Add Client
        </button>
      </div>

      {/* List */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filteredClients.length === 0 ? (
          <div className="col-span-full">
            <EmptyState 
              icon={Users}
              title="No clients found"
              description="Start by adding your first client to the ledger."
            />
          </div>
        ) : (
          filteredClients.map(client => {
            const clientProjects = projects.filter(p => p.clientId === client.id);
            const activeCount = clientProjects.filter(p => p.status !== 'completed').length;
            
            return (
              <div 
                key={client.id}
                onClick={() => navigate(`/clients/${client.id}`)}
                className="bg-bg-card border border-border rounded-xl p-5 hover:border-gold/50 cursor-pointer transition-all hover:-translate-y-1 hover:shadow-lg group relative overflow-hidden"
              >
                <div className="absolute top-0 right-0 w-24 h-24 bg-gold/5 rounded-bl-[100px] -z-10 group-hover:bg-gold/10 transition-colors" />
                <div className="flex justify-between items-start mb-4">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-bg-elevated border border-border-strong flex items-center justify-center text-text-primary font-bold text-lg">
                      {(client.name || '?')[0].toUpperCase()}
                    </div>
                    <div>
                      <h4 className="font-semibold text-text-primary text-base group-hover:text-gold transition-colors">{client.name}</h4>
                      <div className="flex items-center gap-1 text-[12px] text-text-secondary mt-0.5">
                        <Phone className="w-3 h-3" /> {client.phone}
                      </div>
                    </div>
                  </div>
                  <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button 
                      onClick={(e) => openEdit(e, client)}
                      className="p-1.5 text-text-muted hover:text-gold rounded-md hover:bg-bg-elevated transition-colors"
                    >
                      <Pencil className="w-4 h-4" />
                    </button>
                    <button 
                      onClick={(e) => handleDelete(e, client.id)}
                      className="p-1.5 text-text-muted hover:text-danger rounded-md hover:bg-bg-elevated transition-colors"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
                
                {client.city && (
                  <div className="flex items-center gap-1.5 text-[12px] text-text-secondary mb-4">
                    <MapPin className="w-3.5 h-3.5 text-text-muted" />
                    {client.address ? `${client.address}, ` : ''}{client.city}
                  </div>
                )}
                
                <div className="pt-4 border-t border-border-strong flex items-center justify-between">
                  <div className="text-[12px] text-text-secondary">
                    <span className="font-medium text-text-primary">{clientProjects.length}</span> Total Projects
                  </div>
                  {activeCount > 0 ? (
                    <StatusBadge status="active" label={`${activeCount} Active`} />
                  ) : (
                    <StatusBadge status="inactive" label="No Active" />
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Add/Edit Dialog */}
      <Modal
        isOpen={dialogOpen}
        title={editingId ? "Edit Client" : "Add New Client"}
        onClose={() => !saving && setDialogOpen(false)}
        onConfirm={handleSubmit}
        confirmText={saving ? 'Saving...' : (editingId ? 'Update Client' : 'Add Client')}
      >
        <div className="space-y-4">
          <div className="space-y-1">
            <Label>Client Name *</Label>
            <Input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Full name or Company name"
            />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Phone Number *</Label>
              <Input
                value={form.phone}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
                placeholder="Primary phone"
              />
            </div>
            <div className="space-y-1">
              <Label>Email (Optional)</Label>
              <Input
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
                placeholder="Email address"
              />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>City</Label>
              <Input
                value={form.city}
                onChange={(e) => setForm({ ...form, city: e.target.value })}
                placeholder="City"
              />
            </div>
            <div className="space-y-1">
              <Label>Address</Label>
              <Input
                value={form.address}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
                placeholder="Street address"
              />
            </div>
          </div>
          
          <div className="space-y-1">
            <Label>Notes (Optional)</Label>
            <Input
              value={form.notes}
              onChange={(e) => setForm({ ...form, notes: e.target.value })}
              placeholder="Any additional notes"
            />
          </div>
        </div>
      </Modal>
    </div>
  );
}
