import React, { useState, useMemo, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { 
  ChevronLeft, Plus, IndianRupee, FileText, CheckCircle2, Circle, 
  Calendar, Upload, Image as ImageIcon, Briefcase, MapPin, Trash2, Download
} from 'lucide-react';
import toast from 'react-hot-toast';

import { useAuthStore, useScopeId } from '../../store/authStore';
import { useBranding } from '../../context/BrandingContext';
import { useClients } from '../../hooks/useClients';
import { useProjects, useMilestones, useClientPayments, useProjectDocuments } from '../../hooks/useProjects';
import { 
  addMilestone, updateMilestone, addClientPayment, 
  uploadProjectDocument, updateProject, deleteMilestone, deleteProjectDocument
} from '../../lib/services/clients.service';
import { formatCurrency } from '../../lib/utils';
import { generatePDF } from '../../lib/pdfGenerator';

import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Label } from '../../components/ui/label';
import Modal from '../../components/ui/Modal';
import LoadingSpinner from '../../components/shared/LoadingSpinner';
import StatusBadge from '../../components/shared/StatusBadge';
import EmptyState from '../../components/shared/EmptyState';

const TABS = ['Overview', 'Milestones', 'Payments', 'Documents'];

export default function ProjectDetails() {
  const { clientId, projectId } = useParams();
  const navigate = useNavigate();
  const scopeId = useScopeId();
  const { branding } = useBranding();

  const { data: clients, isLoading: clientsLoading } = useClients();
  const { data: projects, isLoading: projectsLoading } = useProjects(clientId);
  const { data: milestones, isLoading: milestonesLoading } = useMilestones(projectId);
  const { data: payments, isLoading: paymentsLoading } = useClientPayments(projectId);
  const { data: documents, isLoading: docsLoading } = useProjectDocuments(projectId);

  const [activeTab, setActiveTab] = useState('Overview');

  // Modals state
  const [milestoneOpen, setMilestoneOpen] = useState(false);
  const [paymentOpen, setPaymentOpen] = useState(false);
  const [docOpen, setDocOpen] = useState(false);
  const [saving, setSaving] = useState(false);

  // Forms
  const [milestoneForm, setMilestoneForm] = useState({ title: '', amount: '', dueDate: '' });
  const [paymentForm, setPaymentForm] = useState({ amount: '', date: '', mode: 'bank', reference: '', notes: '', milestoneId: '' });
  const [docForm, setDocForm] = useState({ type: 'plan', file: null });
  const fileInputRef = useRef(null);

  const client = useMemo(() => clients.find(c => c.id === clientId), [clients, clientId]);
  const project = useMemo(() => projects.find(p => p.id === projectId), [projects, projectId]);

  const isLoading = clientsLoading || projectsLoading || milestonesLoading || paymentsLoading || docsLoading;

  if (isLoading) {
    return <LoadingSpinner label="Loading Project Details..." />;
  }

  if (!project || !client) {
    return (
      <div className="text-center py-10">
        <h2 className="text-xl text-text-primary">Project not found</h2>
        <Button onClick={() => navigate(`/clients/${clientId}`)} className="mt-4">Back to Client</Button>
      </div>
    );
  }

  const totalReceived = payments.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
  const totalContract = Number(project.contractValue || 0);
  const totalPending = totalContract - totalReceived;
  const completionPercent = project.completionPercent || 0;

  // -- Actions --

  const handleUpdateCompletion = async (e) => {
    const val = parseInt(e.target.value);
    if (isNaN(val) || val < 0 || val > 100) return;
    try {
      await updateProject(projectId, { completionPercent: val });
      toast.success('Completion updated');
    } catch (err) {
      toast.error('Failed to update');
    }
  };

  const handleExportPDF = async () => {
    const events = [];
    
    milestones.forEach(m => {
      events.push({
        date: m.dueDate || m.createdAt,
        description: `Milestone: ${m.title}`,
        debit: Number(m.amount) || 0,
        credit: 0
      });
    });
    
    payments.forEach(p => {
      events.push({
        date: p.date || p.createdAt,
        description: `Payment Received${p.mode ? ` (${p.mode})` : ''}`,
        debit: 0,
        credit: Number(p.amount) || 0
      });
    });
    
    // Sort chronologically
    events.sort((a, b) => new Date(a.date || 0) - new Date(b.date || 0));
    
    let runningBalance = 0;
    const rows = events.map(e => {
      runningBalance += e.debit;
      runningBalance -= e.credit;
      return [
        e.date ? new Date(e.date).toLocaleDateString() : '—',
        e.description,
        e.debit ? formatCurrency(e.debit) : '—',
        e.credit ? formatCurrency(e.credit) : '—',
        formatCurrency(runningBalance)
      ];
    });

    try {
      await generatePDF({
        title: 'Project Ledger Statement',
        subtitle: `Client: ${client.name} | Project: ${project.name} | Date: ${new Date().toLocaleDateString()}`,
        filename: `Ledger_${client.name.replace(/\\s+/g, '_')}_${project.name.replace(/\\s+/g, '_')}.pdf`,
        columns: ['Date', 'Description', 'Billed', 'Received', 'Balance'],
        rows,
        totals: {
          'Total Contract Value': formatCurrency(totalContract),
          'Total Received': formatCurrency(totalReceived),
          'Balance Due': formatCurrency(totalPending),
        },
        branding
      });
      toast.success('Ledger PDF generated');
    } catch (error) {
      console.error(error);
      toast.error('Failed to generate PDF');
    }
  };

  const handleAddMilestone = async () => {
    if (!milestoneForm.title || !milestoneForm.amount) return toast.error('Title and amount required');
    setSaving(true);
    const t = toast.loading('Adding milestone...');
    try {
      await addMilestone({
        projectId, clientId, contractorId: scopeId,
        title: milestoneForm.title,
        amount: Number(milestoneForm.amount),
        dueDate: milestoneForm.dueDate,
      });
      toast.dismiss(t);
      toast.success('Milestone added');
      setMilestoneOpen(false);
    } catch (error) {
      toast.dismiss(t);
      toast.error('Error adding milestone');
    } finally {
      setSaving(false);
    }
  };

  const handleAddPayment = async () => {
    if (!paymentForm.amount || !paymentForm.date) return toast.error('Amount and date required');
    setSaving(true);
    const t = toast.loading('Recording payment...');
    try {
      await addClientPayment({
        projectId, clientId, contractorId: scopeId,
        amount: Number(paymentForm.amount),
        date: paymentForm.date,
        mode: paymentForm.mode,
        reference: paymentForm.reference,
        notes: paymentForm.notes,
        milestoneId: paymentForm.milestoneId || null,
      });
      // Auto-update project received amount isn't strictly necessary since we calculate it on the fly,
      // but good if we need it for queries later. Let's rely on on the fly for now.
      toast.dismiss(t);
      toast.success('Payment recorded');
      setPaymentOpen(false);
    } catch (error) {
      toast.dismiss(t);
      toast.error('Error recording payment');
    } finally {
      setSaving(false);
    }
  };

  const handleUploadDoc = async () => {
    if (!docForm.file) return toast.error('Select a file');
    setSaving(true);
    const t = toast.loading('Uploading document...');
    try {
      await uploadProjectDocument(docForm.file, {
        projectId, clientId, contractorId: scopeId,
        type: docForm.type
      });
      toast.dismiss(t);
      toast.success('Document uploaded');
      setDocOpen(false);
      setDocForm({ type: 'plan', file: null });
      if (fileInputRef.current) fileInputRef.current.value = '';
    } catch (error) {
      toast.dismiss(t);
      toast.error('Upload failed');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Back button */}
      <button 
        onClick={() => navigate(`/clients/${clientId}`)}
        className="flex items-center text-[13px] text-text-muted hover:text-text-primary transition-colors"
      >
        <ChevronLeft className="w-4 h-4 mr-1" /> Back to {client.name}
      </button>

      {/* Project Header */}
      <div className="bg-bg-card border border-border rounded-xl p-6">
        <div className="flex flex-col md:flex-row justify-between md:items-center gap-4">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <h2 className="text-2xl font-bold text-text-primary">{project.name}</h2>
              <StatusBadge status={project.status === 'completed' ? 'inactive' : 'active'} label={project.status || 'Active'} />
            </div>
            <div className="flex flex-wrap items-center gap-x-6 gap-y-2 text-[13px] text-text-secondary">
              <span className="flex items-center gap-1.5"><Briefcase className="w-4 h-4 text-text-muted" /> {project.type}</span>
              <span className="flex items-center gap-1.5"><MapPin className="w-4 h-4 text-text-muted" /> {project.location || 'No location'}</span>
              <span className="flex items-center gap-1.5"><FileText className="w-4 h-4 text-text-muted" /> {project.totalArea || 0} sq ft</span>
            </div>
          </div>
          
          <div className="flex flex-wrap items-center gap-3 mt-4 md:mt-0">
            <Button onClick={handleExportPDF} variant="outline" className="border-gold text-gold hover:bg-gold/10 flex">
              <Download className="w-4 h-4 mr-2" /> Export Ledger
            </Button>
            <Button onClick={() => {
              setPaymentForm({ amount: '', date: new Date().toISOString().split('T')[0], mode: 'bank', reference: '', notes: '', milestoneId: '' });
              setPaymentOpen(true);
            }} className="bg-success hover:bg-success-dark text-white flex">
              <IndianRupee className="w-4 h-4 mr-2" /> Record Payment
            </Button>
          </div>
        </div>

        {/* Financial Summary */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mt-8 pt-6 border-t border-border-strong">
          <div>
            <p className="text-[12px] text-text-muted uppercase tracking-wider mb-1">Contract Value</p>
            <p className="text-xl font-bold text-text-primary">{formatCurrency(totalContract)}</p>
          </div>
          <div>
            <p className="text-[12px] text-text-muted uppercase tracking-wider mb-1">Total Received</p>
            <p className="text-xl font-bold text-success">{formatCurrency(totalReceived)}</p>
          </div>
          <div>
            <p className="text-[12px] text-text-muted uppercase tracking-wider mb-1">Balance Due</p>
            <p className="text-xl font-bold text-warning">{formatCurrency(totalPending)}</p>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex items-center gap-2 border-b border-border overflow-x-auto" style={{ scrollbarWidth: 'none' }}>
        {TABS.map(tab => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2.5 text-[14px] font-medium transition-colors border-b-2 whitespace-nowrap ${
              activeTab === tab 
                ? 'border-gold text-gold' 
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <div className="min-h-[400px]">
        {activeTab === 'Overview' && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-bg-card border border-border rounded-xl p-5">
              <h3 className="text-sm font-semibold text-text-primary mb-4 uppercase tracking-wider">Project Progress</h3>
              <div className="flex items-center gap-4 mb-2">
                <span className="text-3xl font-bold text-gold">{completionPercent}%</span>
                <span className="text-sm text-text-secondary">Completed</span>
              </div>
              <div className="w-full h-2 bg-bg-elevated rounded-full overflow-hidden mb-6">
                <div className="h-full bg-gold rounded-full transition-all duration-500" style={{ width: `${completionPercent}%` }} />
              </div>
              
              <div className="space-y-1">
                <Label>Update Completion %</Label>
                <div className="flex items-center gap-3">
                  <input 
                    type="range" 
                    min="0" max="100" 
                    value={completionPercent} 
                    onChange={handleUpdateCompletion}
                    className="flex-1 accent-gold"
                  />
                  <span className="text-sm text-text-primary font-medium w-8 text-right">{completionPercent}%</span>
                </div>
              </div>
            </div>

            <div className="bg-bg-card border border-border rounded-xl p-5">
              <h3 className="text-sm font-semibold text-text-primary mb-4 uppercase tracking-wider">Dates & Details</h3>
              <div className="space-y-4">
                <div className="flex justify-between items-center py-2 border-b border-border-strong">
                  <span className="text-text-secondary text-sm">Start Date</span>
                  <span className="text-text-primary font-medium text-sm">
                    {project.startDate ? new Date(project.startDate).toLocaleDateString() : 'Not set'}
                  </span>
                </div>
                <div className="flex justify-between items-center py-2 border-b border-border-strong">
                  <span className="text-text-secondary text-sm">Est. End Date</span>
                  <span className="text-text-primary font-medium text-sm">
                    {project.endDate ? new Date(project.endDate).toLocaleDateString() : 'Not set'}
                  </span>
                </div>
                <div className="flex justify-between items-center py-2 border-b border-border-strong">
                  <span className="text-text-secondary text-sm">Created On</span>
                  <span className="text-text-primary font-medium text-sm">
                    {project.createdAt ? new Date(project.createdAt).toLocaleDateString() : '—'}
                  </span>
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'Milestones' && (
          <div className="bg-bg-card border border-border rounded-xl p-5">
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-sm font-semibold text-text-primary uppercase tracking-wider">Payment Schedule</h3>
              <Button onClick={() => {
                setMilestoneForm({ title: '', amount: '', dueDate: '' });
                setMilestoneOpen(true);
              }} variant="outline" size="sm" className="h-8 text-xs border-gold text-gold hover:bg-gold/10">
                <Plus className="w-3.5 h-3.5 mr-1.5" /> Add Milestone
              </Button>
            </div>
            
            {milestones.length === 0 ? (
              <EmptyState icon={CheckCircle2} title="No milestones defined" description="Set up a payment schedule by adding milestones." />
            ) : (
              <div className="relative border-l-2 border-border-strong ml-3 space-y-6 pb-4">
                {milestones.map((m, i) => (
                  <div key={m.id} className="relative pl-6">
                    <div className={`absolute -left-[9px] top-1 w-4 h-4 rounded-full border-2 border-bg-card flex items-center justify-center
                      ${m.status === 'paid' ? 'bg-success' : 'bg-border-strong'}`}>
                      {m.status === 'paid' && <CheckCircle2 className="w-2.5 h-2.5 text-white" />}
                    </div>
                    
                    <div className="bg-bg-elevated border border-border-strong rounded-lg p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                      <div>
                        <h4 className="font-semibold text-text-primary text-sm flex items-center gap-2">
                          {m.title}
                          {m.status === 'paid' && <span className="bg-success/20 text-success text-[10px] px-1.5 py-0.5 rounded uppercase font-bold tracking-wider">Paid</span>}
                        </h4>
                        <div className="text-[12px] text-text-muted mt-1 flex items-center gap-3">
                          {m.dueDate && <span className="flex items-center gap-1"><Calendar className="w-3 h-3" /> Due: {new Date(m.dueDate).toLocaleDateString()}</span>}
                          {m.status === 'paid' && m.paidDate && <span className="flex items-center gap-1"><CheckCircle2 className="w-3 h-3 text-success" /> Paid: {new Date(m.paidDate).toLocaleDateString()}</span>}
                        </div>
                      </div>
                      <div className="flex items-center justify-between sm:justify-end gap-4 w-full sm:w-auto">
                        <span className="font-bold text-text-primary text-base">{formatCurrency(m.amount)}</span>
                        {m.status !== 'paid' && (
                          <div className="flex gap-2">
                            <Button size="sm" onClick={() => {
                               setPaymentForm({ amount: m.amount, date: new Date().toISOString().split('T')[0], mode: 'bank', reference: '', notes: '', milestoneId: m.id });
                               setPaymentOpen(true);
                            }} className="h-8 text-xs bg-success hover:bg-success-dark text-white">Pay</Button>
                            <button onClick={() => deleteMilestone(m.id)} className="p-1.5 text-text-muted hover:text-danger rounded-md hover:bg-danger/10 transition-colors">
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {activeTab === 'Payments' && (
          <div className="bg-bg-card border border-border rounded-xl p-5">
             <div className="flex justify-between items-center mb-6">
              <h3 className="text-sm font-semibold text-text-primary uppercase tracking-wider">Payment History</h3>
            </div>
            
            {payments.length === 0 ? (
              <EmptyState icon={IndianRupee} title="No payments received" description="Record payments when clients pay you." />
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-[13px]">
                  <thead className="border-b border-border bg-bg-elevated text-left text-[10px] uppercase tracking-widest text-text-muted">
                    <tr>
                      <th className="px-4 py-3 font-medium">Date</th>
                      <th className="px-4 py-3 font-medium">Amount</th>
                      <th className="px-4 py-3 font-medium">Mode</th>
                      <th className="px-4 py-3 font-medium">Reference</th>
                      <th className="px-4 py-3 font-medium">Milestone</th>
                      <th className="px-4 py-3 font-medium">Notes</th>
                    </tr>
                  </thead>
                  <tbody>
                    {payments.map(p => {
                      const mstone = milestones.find(m => m.id === p.milestoneId);
                      return (
                        <tr key={p.id} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                          <td className="px-4 py-3 text-text-primary whitespace-nowrap">
                            {p.date ? new Date(p.date).toLocaleDateString() : '—'}
                          </td>
                          <td className="px-4 py-3 font-bold text-success">{formatCurrency(p.amount)}</td>
                          <td className="px-4 py-3 text-text-secondary capitalize">{p.mode || '—'}</td>
                          <td className="px-4 py-3 font-mono text-text-muted text-xs">{p.reference || '—'}</td>
                          <td className="px-4 py-3 text-text-secondary">
                            {mstone ? <span className="text-gold text-xs font-medium bg-gold/10 px-2 py-0.5 rounded">{mstone.title}</span> : '—'}
                          </td>
                          <td className="px-4 py-3 text-text-muted truncate max-w-[200px]">{p.notes || '—'}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {activeTab === 'Documents' && (
          <div className="bg-bg-card border border-border rounded-xl p-5">
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-sm font-semibold text-text-primary uppercase tracking-wider">Project Documents & Photos</h3>
              <Button onClick={() => setDocOpen(true)} variant="outline" size="sm" className="h-8 text-xs border-gold text-gold hover:bg-gold/10">
                <Upload className="w-3.5 h-3.5 mr-1.5" /> Upload File
              </Button>
            </div>

            {documents.length === 0 ? (
              <EmptyState icon={ImageIcon} title="No documents" description="Upload floor plans, elevations, and site progress photos here." />
            ) : (
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
                {documents.map(doc => {
                  const isImage = doc.fileName?.match(/\.(jpg|jpeg|png|gif|webp)$/i);
                  return (
                    <div key={doc.id} className="group border border-border-strong rounded-xl overflow-hidden bg-bg-elevated relative">
                      <div className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity z-10">
                        <a href={doc.fileUrl} target="_blank" rel="noreferrer" className="w-7 h-7 rounded bg-bg-card/90 backdrop-blur border border-border flex items-center justify-center text-text-primary hover:text-gold transition-colors">
                          <Download className="w-3.5 h-3.5" />
                        </a>
                        <button onClick={() => deleteProjectDocument(doc.id, doc.storagePath)} className="w-7 h-7 rounded bg-bg-card/90 backdrop-blur border border-border flex items-center justify-center text-danger hover:bg-danger/20 transition-colors">
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                      
                      <div className="aspect-square bg-bg-card flex items-center justify-center border-b border-border-strong relative overflow-hidden">
                        {isImage ? (
                          <img src={doc.fileUrl} alt={doc.fileName} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
                        ) : (
                          <FileText className="w-12 h-12 text-text-muted" />
                        )}
                        <div className="absolute bottom-2 left-2 text-[9px] font-bold tracking-widest uppercase bg-black/60 text-white px-2 py-0.5 rounded backdrop-blur">
                          {doc.type}
                        </div>
                      </div>
                      <div className="p-3">
                        <p className="text-[11px] font-medium text-text-primary truncate" title={doc.fileName}>{doc.fileName}</p>
                        <p className="text-[10px] text-text-muted mt-0.5">{doc.uploadedAt ? new Date(doc.uploadedAt).toLocaleDateString() : '—'}</p>
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Milestone Modal */}
      <Modal isOpen={milestoneOpen} title="Add Payment Milestone" onClose={() => !saving && setMilestoneOpen(false)} onConfirm={handleAddMilestone} confirmText={saving ? 'Saving...' : 'Add Milestone'}>
        <div className="space-y-4">
          <div className="space-y-1">
            <Label>Milestone Title *</Label>
            <Input value={milestoneForm.title} onChange={e => setMilestoneForm({...milestoneForm, title: e.target.value})} placeholder="e.g. Foundation Complete" />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Amount (₹) *</Label>
              <Input type="number" value={milestoneForm.amount} onChange={e => setMilestoneForm({...milestoneForm, amount: e.target.value})} placeholder="0" />
            </div>
            <div className="space-y-1">
              <Label>Expected Date</Label>
              <Input type="date" value={milestoneForm.dueDate} onChange={e => setMilestoneForm({...milestoneForm, dueDate: e.target.value})} />
            </div>
          </div>
        </div>
      </Modal>

      {/* Payment Modal */}
      <Modal isOpen={paymentOpen} title="Record Payment" onClose={() => !saving && setPaymentOpen(false)} onConfirm={handleAddPayment} confirmText={saving ? 'Recording...' : 'Record Payment'}>
         <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Amount Received (₹) *</Label>
              <Input type="number" value={paymentForm.amount} onChange={e => setPaymentForm({...paymentForm, amount: e.target.value})} placeholder="0" />
            </div>
            <div className="space-y-1">
              <Label>Payment Date *</Label>
              <Input type="date" value={paymentForm.date} onChange={e => setPaymentForm({...paymentForm, date: e.target.value})} />
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1">
              <Label>Payment Mode</Label>
              <select value={paymentForm.mode} onChange={e => setPaymentForm({...paymentForm, mode: e.target.value})} className="flex h-9 w-full rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary outline-none focus:border-gold focus:ring-1 focus:ring-gold">
                <option value="bank">Bank Transfer / NEFT</option>
                <option value="upi">UPI</option>
                <option value="cash">Cash</option>
                <option value="cheque">Cheque</option>
              </select>
            </div>
            <div className="space-y-1">
              <Label>Reference No. / UTR</Label>
              <Input value={paymentForm.reference} onChange={e => setPaymentForm({...paymentForm, reference: e.target.value})} placeholder="Optional" />
            </div>
          </div>
          {!paymentForm.milestoneId && milestones.filter(m => m.status !== 'paid').length > 0 && (
            <div className="space-y-1">
              <Label>Link to Milestone (Optional)</Label>
              <select value={paymentForm.milestoneId} onChange={e => setPaymentForm({...paymentForm, milestoneId: e.target.value})} className="flex h-9 w-full rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary outline-none focus:border-gold focus:ring-1 focus:ring-gold">
                <option value="">Do not link</option>
                {milestones.filter(m => m.status !== 'paid').map(m => (
                  <option key={m.id} value={m.id}>{m.title} - {formatCurrency(m.amount)}</option>
                ))}
              </select>
            </div>
          )}
          <div className="space-y-1">
            <Label>Notes</Label>
            <Input value={paymentForm.notes} onChange={e => setPaymentForm({...paymentForm, notes: e.target.value})} placeholder="Optional remarks" />
          </div>
        </div>
      </Modal>

      {/* Upload Doc Modal */}
      <Modal isOpen={docOpen} title="Upload Document" onClose={() => !saving && setDocOpen(false)} onConfirm={handleUploadDoc} confirmText={saving ? 'Uploading...' : 'Upload'}>
         <div className="space-y-4">
           <div className="space-y-1">
              <Label>Document Type</Label>
              <select value={docForm.type} onChange={e => setDocForm({...docForm, type: e.target.value})} className="flex h-9 w-full rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary outline-none focus:border-gold focus:ring-1 focus:ring-gold">
                <option value="plan">Floor Plan</option>
                <option value="elevation">Elevation / Design</option>
                <option value="site_photo">Site Progress Photo</option>
                <option value="agreement">Contract / Agreement</option>
                <option value="other">Other Document</option>
              </select>
            </div>
            <div className="space-y-1">
              <Label>Select File</Label>
              <input 
                type="file" 
                ref={fileInputRef}
                onChange={e => setDocForm({...docForm, file: e.target.files[0]})}
                className="w-full text-sm text-text-secondary file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-bg-elevated file:text-text-primary hover:file:bg-bg-card-hover border border-border-strong rounded-lg p-1.5" 
              />
            </div>
         </div>
      </Modal>
    </div>
  );
}
