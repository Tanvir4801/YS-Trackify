import React, { useState, useMemo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ChevronLeft, Plus, Phone, MapPin, Mail, Calendar, Briefcase, FileText, Pencil, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';

import { useAuthStore, useScopeId } from '../../store/authStore';
import { useClients } from '../../hooks/useClients';
import { useProjects } from '../../hooks/useProjects';
import { addProject, updateProject, deleteProject, updateClient } from '../../lib/services/clients.service';
import { formatCurrency } from '../../lib/utils';

import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Label } from '../../components/ui/label';
import Modal from '../../components/ui/Modal';
import LoadingSpinner from '../../components/shared/LoadingSpinner';
import StatusBadge from '../../components/shared/StatusBadge';
import EmptyState from '../../components/shared/EmptyState';

const EMPTY_PROJECT_FORM = {
  name: '',
  type: 'residential',
  location: '',
  totalArea: '',
  contractValue: '',
  startDate: '',
  status: 'active',
  completionPercent: 0,
};

const EMPTY_CLIENT_FORM = {
  name: '',
  phone: '',
  email: '',
  address: '',
  city: '',
  notes: '',
};

export default function ClientProfile() {
  const { id: clientId } = useParams();
  const navigate = useNavigate();
  const scopeId = useScopeId();

  const { data: clients, isLoading: clientsLoading } = useClients();
  const { data: projects, isLoading: projectsLoading } = useProjects(clientId);

  const [dialogOpen, setDialogOpen] = useState(false);
  const [form, setForm] = useState(EMPTY_PROJECT_FORM);
  const [editingProjectId, setEditingProjectId] = useState(null);

  const [clientDialogOpen, setClientDialogOpen] = useState(false);
  const [clientForm, setClientForm] = useState(EMPTY_CLIENT_FORM);

  const [saving, setSaving] = useState(false);

  const client = useMemo(() => clients.find(c => c.id === clientId), [clients, clientId]);

  if (clientsLoading || projectsLoading) {
    return <LoadingSpinner label="Loading Client Profile..." />;
  }

  if (!client) {
    return (
      <div className="text-center py-10">
        <h2 className="text-xl text-text-primary">Client not found</h2>
        <Button onClick={() => navigate('/clients')} className="mt-4">Back to Clients</Button>
      </div>
    );
  }

  const handleAddProject = async () => {
    if (!form.name.trim()) return toast.error('Project name is required');
    if (!form.contractValue) return toast.error('Contract value is required');
    
    setSaving(true);
    const t = toast.loading(editingProjectId ? 'Updating project...' : 'Creating project...');
    try {
      if (editingProjectId) {
        await updateProject(editingProjectId, {
          ...form,
          contractValue: Number(form.contractValue),
          totalArea: Number(form.totalArea) || 0,
          completionPercent: Number(form.completionPercent) || 0,
        });
        toast.dismiss(t);
        toast.success('Project updated');
        setDialogOpen(false);
      } else {
        const projectId = await addProject({
          contractorId: scopeId,
          clientId: client.id,
          ...form,
          contractValue: Number(form.contractValue),
          totalArea: Number(form.totalArea) || 0,
          completionPercent: Number(form.completionPercent) || 0,
        });
        toast.dismiss(t);
        toast.success('Project created');
        setDialogOpen(false);
        navigate(`/clients/${client.id}/projects/${projectId}`);
      }
    } catch (error) {
      toast.dismiss(t);
      toast.error(editingProjectId ? 'Failed to update project' : 'Failed to create project');
      console.error(error);
    } finally {
      setSaving(false);
    }
  };

  const handleUpdateClient = async () => {
    if (!clientForm.name.trim()) return toast.error('Client name is required');
    if (!clientForm.phone.trim()) return toast.error('Phone number is required');
    
    setSaving(true);
    const t = toast.loading('Updating client...');
    try {
      await updateClient(client.id, clientForm);
      toast.dismiss(t);
      toast.success('Client updated successfully');
      setClientDialogOpen(false);
    } catch (error) {
      toast.dismiss(t);
      toast.error('Failed to update client');
    } finally {
      setSaving(false);
    }
  };

  const openAddProject = () => {
    setForm(EMPTY_PROJECT_FORM);
    setEditingProjectId(null);
    setDialogOpen(true);
  };

  const openEditProject = (e, project) => {
    e.stopPropagation();
    setForm({
      name: project.name || '',
      type: project.type || 'residential',
      location: project.location || '',
      totalArea: project.totalArea || '',
      contractValue: project.contractValue || '',
      startDate: project.startDate ? new Date(project.startDate).toISOString().split('T')[0] : '',
      status: project.status || 'active',
      completionPercent: project.completionPercent || 0,
    });
    setEditingProjectId(project.id);
    setDialogOpen(true);
  };

  const handleDeleteProject = async (e, projectId) => {
    e.stopPropagation();
    if (!window.confirm('Are you sure you want to delete this project?')) return;
    try {
      await deleteProject(projectId);
      toast.success('Project deleted');
    } catch (err) {
      toast.error('Failed to delete project');
    }
  };

  const openEditClient = () => {
    setClientForm({
      name: client.name || '',
      phone: client.phone || '',
      email: client.email || '',
      address: client.address || '',
      city: client.city || '',
      notes: client.notes || '',
    });
    setClientDialogOpen(true);
  };

  return (
    <div className="space-y-6">
      {/* Back button */}
      <button 
        onClick={() => navigate('/clients')}
        className="flex items-center text-[13px] text-text-muted hover:text-text-primary transition-colors"
      >
        <ChevronLeft className="w-4 h-4 mr-1" /> Back to Clients
      </button>

      {/* Profile Header */}
      <div className="bg-bg-card border border-border rounded-xl p-6 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-32 h-32 bg-gold/5 rounded-bl-[100px] -z-10" />
        
        <div className="flex flex-col md:flex-row md:items-start justify-between gap-6">
          <div className="flex items-start gap-5">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-bg-elevated to-bg-card border border-border-strong flex items-center justify-center text-text-primary font-bold text-2xl shadow-sm">
              {(client.name || '?')[0].toUpperCase()}
            </div>
            <div>
              <h2 className="text-2xl font-bold text-text-primary">{client.name}</h2>
              <div className="flex flex-wrap items-center gap-x-6 gap-y-2 mt-2 text-[13px] text-text-secondary">
                {client.phone && (
                  <div className="flex items-center gap-1.5">
                    <Phone className="w-4 h-4 text-text-muted" /> {client.phone}
                  </div>
                )}
                {client.email && (
                  <div className="flex items-center gap-1.5">
                    <Mail className="w-4 h-4 text-text-muted" /> {client.email}
                  </div>
                )}
                {client.city && (
                  <div className="flex items-center gap-1.5">
                    <MapPin className="w-4 h-4 text-text-muted" /> {client.address ? `${client.address}, ` : ''}{client.city}
                  </div>
                )}
              </div>
              {client.notes && (
                <div className="mt-3 text-[13px] text-text-muted bg-bg-elevated/50 p-3 rounded-lg border border-border-strong inline-block">
                  <FileText className="w-3.5 h-3.5 inline mr-1.5 -mt-0.5" />
                  {client.notes}
                </div>
              )}
            </div>
          </div>
          
          <div className="flex items-center gap-2 shrink-0">
            <button
              onClick={openEditClient}
              className="flex h-10 w-10 items-center justify-center rounded-lg border border-border-strong bg-bg-elevated text-text-muted hover:text-gold hover:border-gold/50 transition-colors"
            >
              <Pencil className="h-4 w-4" />
            </button>
            <button
              onClick={openAddProject}
              className="flex h-10 items-center gap-2 rounded-lg bg-gold px-5 text-[13px] font-semibold text-bg-primary shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-105 transition-all"
            >
              <Plus className="h-4 w-4" /> New Project
            </button>
          </div>
        </div>
      </div>

      {/* Projects Section */}
      <div>
        <h3 className="text-lg font-semibold text-text-primary mb-4 flex items-center gap-2">
          <Briefcase className="w-5 h-5 text-gold" /> Projects ({projects.length})
        </h3>
        
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {projects.length === 0 ? (
            <div className="col-span-full">
              <EmptyState 
                icon={Briefcase}
                title="No projects yet"
                description="Create a project to start tracking milestones and payments."
              />
            </div>
          ) : (
            projects.map(project => (
              <div 
                key={project.id}
                onClick={() => navigate(`/clients/${client.id}/projects/${project.id}`)}
                className="bg-bg-card border border-border rounded-xl p-5 hover:border-gold/50 cursor-pointer transition-all hover:-translate-y-1 hover:shadow-lg flex flex-col justify-between"
              >
                <div>
                  <div className="flex justify-between items-start mb-3">
                    <h4 className="font-semibold text-text-primary text-base group-hover:text-gold transition-colors">{project.name}</h4>
                    <div className="flex items-center gap-2">
                      <StatusBadge status={project.status === 'completed' ? 'inactive' : 'active'} label={project.status === 'completed' ? 'Completed' : 'Active'} />
                      <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button 
                          onClick={(e) => openEditProject(e, project)}
                          className="p-1 text-text-muted hover:text-gold rounded transition-colors"
                        >
                          <Pencil className="w-3.5 h-3.5" />
                        </button>
                        <button 
                          onClick={(e) => handleDeleteProject(e, project.id)}
                          className="p-1 text-text-muted hover:text-danger rounded transition-colors"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>
                  
                  <div className="grid grid-cols-2 gap-4 mb-4">
                    <div>
                      <p className="text-[11px] text-text-muted uppercase tracking-wider mb-0.5">Contract Value</p>
                      <p className="font-medium text-text-primary">{formatCurrency(project.contractValue)}</p>
                    </div>
                    <div>
                      <p className="text-[11px] text-text-muted uppercase tracking-wider mb-0.5">Location</p>
                      <p className="font-medium text-text-primary truncate">{project.location || '—'}</p>
                    </div>
                  </div>
                  
                  {/* Simple Progress Bar */}
                  <div className="mb-1 flex justify-between items-center text-[11px]">
                    <span className="text-text-muted">Completion</span>
                    <span className="font-medium text-text-primary">{project.completionPercent || 0}%</span>
                  </div>
                  <div className="w-full h-1.5 bg-bg-elevated rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-gold rounded-full transition-all duration-500"
                      style={{ width: `${project.completionPercent || 0}%` }}
                    />
                  </div>
                </div>
                
                <div className="mt-4 pt-4 border-t border-border-strong flex items-center justify-between text-[12px]">
                  <div className="text-text-secondary flex items-center gap-1.5">
                    <Calendar className="w-3.5 h-3.5 text-text-muted" />
                    Started: {project.startDate ? new Date(project.startDate).toLocaleDateString() : '—'}
                  </div>
                  <span className="text-gold font-medium hover:underline">View Ledger &rarr;</span>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Add/Edit Project Dialog */}
      <Modal
        isOpen={dialogOpen}
        title={editingProjectId ? "Edit Project" : "Create New Project"}
        onClose={() => !saving && setDialogOpen(false)}
        onConfirm={handleAddProject}
        confirmText={saving ? 'Saving...' : (editingProjectId ? 'Update Project' : 'Create Project')}
      >
        <div className="space-y-4">
          <div className="space-y-1">
            <Label>Project Name *</Label>
            <Input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="e.g. 3BHK Villa Construction"
            />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Type</Label>
              <select
                value={form.type}
                onChange={(e) => setForm({ ...form, type: e.target.value })}
                className="flex h-9 w-full rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary outline-none focus:border-gold focus:ring-1 focus:ring-gold"
              >
                <option value="residential">Residential</option>
                <option value="commercial">Commercial</option>
                <option value="renovation">Renovation</option>
                <option value="other">Other</option>
              </select>
            </div>
            <div className="space-y-1">
              <Label>Location</Label>
              <Input
                value={form.location}
                onChange={(e) => setForm({ ...form, location: e.target.value })}
                placeholder="Site location"
              />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Total Area (sq ft)</Label>
              <Input
                type="number"
                value={form.totalArea}
                onChange={(e) => setForm({ ...form, totalArea: e.target.value })}
                placeholder="e.g. 1500"
              />
            </div>
            <div className="space-y-1">
              <Label>Contract Value (₹) *</Label>
              <Input
                type="number"
                value={form.contractValue}
                onChange={(e) => setForm({ ...form, contractValue: e.target.value })}
                placeholder="Total contract amount"
              />
            </div>
          </div>
          
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Start Date</Label>
              <Input
                type="date"
                value={form.startDate}
                onChange={(e) => setForm({ ...form, startDate: e.target.value })}
              />
            </div>
            {editingProjectId && (
              <div className="space-y-1">
                <Label>Status</Label>
                <select
                  value={form.status}
                  onChange={(e) => setForm({ ...form, status: e.target.value })}
                  className="flex h-9 w-full rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary outline-none focus:border-gold focus:ring-1 focus:ring-gold"
                >
                  <option value="active">Active</option>
                  <option value="completed">Completed</option>
                </select>
              </div>
            )}
          </div>

          {editingProjectId && (
            <div className="space-y-1">
              <Label>Completion Percentage ({form.completionPercent}%)</Label>
              <input
                type="range"
                min="0"
                max="100"
                value={form.completionPercent}
                onChange={(e) => setForm({ ...form, completionPercent: e.target.value })}
                className="w-full accent-gold"
              />
            </div>
          )}
        </div>
      </Modal>

      {/* Edit Client Dialog */}
      <Modal
        isOpen={clientDialogOpen}
        title="Edit Client"
        onClose={() => !saving && setClientDialogOpen(false)}
        onConfirm={handleUpdateClient}
        confirmText={saving ? 'Updating...' : 'Update Client'}
      >
        <div className="space-y-4">
          <div className="space-y-1">
            <Label>Client Name *</Label>
            <Input
              value={clientForm.name}
              onChange={(e) => setClientForm({ ...clientForm, name: e.target.value })}
              placeholder="Full name or Company name"
            />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Phone Number *</Label>
              <Input
                value={clientForm.phone}
                onChange={(e) => setClientForm({ ...clientForm, phone: e.target.value })}
                placeholder="Primary phone"
              />
            </div>
            <div className="space-y-1">
              <Label>Email (Optional)</Label>
              <Input
                value={clientForm.email}
                onChange={(e) => setClientForm({ ...clientForm, email: e.target.value })}
                placeholder="Email address"
              />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>City</Label>
              <Input
                value={clientForm.city}
                onChange={(e) => setClientForm({ ...clientForm, city: e.target.value })}
                placeholder="City"
              />
            </div>
            <div className="space-y-1">
              <Label>Address</Label>
              <Input
                value={clientForm.address}
                onChange={(e) => setClientForm({ ...clientForm, address: e.target.value })}
                placeholder="Street address"
              />
            </div>
          </div>
          
          <div className="space-y-1">
            <Label>Notes (Optional)</Label>
            <Input
              value={clientForm.notes}
              onChange={(e) => setClientForm({ ...clientForm, notes: e.target.value })}
              placeholder="Any additional notes"
            />
          </div>
        </div>
      </Modal>
    </div>
  );
}
