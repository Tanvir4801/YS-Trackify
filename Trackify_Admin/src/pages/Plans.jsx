import React, { useState, useMemo, useEffect } from 'react';
import { createPortal } from 'react-dom';
import {
  Compass,
  Plus,
  Search,
  Building,
  Home,
  IndianRupee,
  Layers,
  HardHat,
  Phone,
  MapPin,
  Pencil,
  Trash2,
  Eye,
  Download,
  Filter,
  CheckCircle2,
  Clock,
  AlertCircle,
  Sparkles,
  Copy,
  ExternalLink,
  LayoutGrid,
  List,
  FileText,
  X,
  CreditCard,
  Settings2,
  ChevronRight,
  ChevronLeft,
  Check,
  RotateCcw,
  Receipt,
  Wallet,
  ArrowUpRight,
  Printer,
  Calendar,
  Send,
  Share2,
} from 'lucide-react';
import toast from 'react-hot-toast';
import * as XLSX from 'xlsx';
import { motion, AnimatePresence } from 'framer-motion';

import { useAuthStore, useScopeId } from '../store/authStore';
import { useHousePlans, useMasterPlanCatalog } from '../hooks/useHousePlans';
import { useBranding } from '../context/BrandingContext';
import { generateHousePlanInvoicePDF } from '../lib/services/plansPdf.service';
import {
  addHousePlan,
  updateHousePlan,
  deleteHousePlan,
  addPlanToOwner,
  updatePlanInOwner,
  togglePlanStatus,
  deletePlanFromOwner,
  resetOwnerPlansToExact21,
  resetOwnerPlansToExact16,
  addPaymentToOwner,
  updatePaymentInOwner,
  deletePaymentFromOwner,
  saveMasterPlanCatalog,
  DEFAULT_MASTER_PLANS,
  extractMainPlanName,
  extractPureMainName,
  formatWindowsFileName,
} from '../lib/services/plans.service';
import { formatCurrency, formatDate } from '../lib/utils';

import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import Modal from '../components/ui/Modal';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';

// Plan status colors
const PLAN_STATUS_CONFIG = {
  not_started: { label: 'Not Started', bg: 'bg-zinc-800 text-zinc-400 border-zinc-700' },
  pending: { label: 'Pending', bg: 'bg-warning/10 text-warning border-warning/30' },
  in_progress: { label: 'In Progress', bg: 'bg-info/10 text-info border-info/30' },
  completed: { label: 'Completed', bg: 'bg-success/10 text-success border-success/30' },
};

// Payment status badge for plan fees
function getPaymentStatusBadge(totalAmount, totalPaid) {
  if (!totalAmount || totalAmount <= 0) {
    return {
      label: 'No Fee Set',
      bg: 'bg-zinc-500/10 text-zinc-400 border-zinc-500/20',
      dot: 'bg-zinc-400',
    };
  }
  if (totalPaid >= totalAmount) {
    return {
      label: 'PLAN FEE CLEARED (100%)',
      bg: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/30',
      dot: 'bg-emerald-500',
    };
  }
  if (totalPaid >= totalAmount * 0.5) {
    return {
      label: 'HALF PAID (50%+)',
      bg: 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-500/30',
      dot: 'bg-amber-500',
    };
  }
  if (totalPaid > 0) {
    return {
      label: 'ADVANCE RECEIVED',
      bg: 'bg-sky-500/10 text-sky-600 dark:text-sky-400 border-sky-500/30',
      dot: 'bg-sky-500',
    };
  }
  return {
    label: 'PLAN FEE PENDING',
    bg: 'bg-rose-500/10 text-rose-600 dark:text-rose-400 border-rose-500/30',
    dot: 'bg-rose-500',
  };
}

// Extracts clean 10-digit mobile number, handling +91, leading 0, spaces, and formatting
export function extract10DigitPhone(phone) {
  if (!phone) return '';
  let digits = String(phone).replace(/\D/g, '');
  if (digits.startsWith('91') && digits.length === 12) {
    digits = digits.slice(2);
  } else if (digits.startsWith('0') && digits.length === 11) {
    digits = digits.slice(1);
  }
  return digits.slice(0, 10);
}

// Safely normalize any Indian or international phone number for WhatsApp direct unsaved chat
function normalizeWhatsAppNumber(phone) {
  if (!phone) return '';
  const clean10 = extract10DigitPhone(phone);
  if (clean10 && clean10.length === 10) {
    return `91${clean10}`;
  }
  const rawDigits = String(phone).replace(/\D/g, '');
  if (rawDigits.startsWith('91')) {
    return rawDigits.length === 12 ? rawDigits : '';
  }
  if (rawDigits.length >= 11 && rawDigits.length <= 15) {
    return rawDigits;
  }
  return '';
}

const EMPTY_OWNER_FORM = {
  ownerName: '',
  ownerPhone: '',
  ownerEmail: '',
  ownerAddress: '',
  city: '',
  town: '',
  planNumber: '',
  serialNumber3D: '',
  title: '',
  totalSqFt: '',
  plotAreaSqFt: '',
  houseAmount: '',
  ratePerSqFt: '',
  floors: 'G+1',
  facing: 'East',
  bhk: '3 BHK',
  engineerName: '',
  engineerPhone: '',
  engineerNotes: '',
  initialAdvanceAmount: '',
  initialAdvanceMode: 'UPI',
};

export default function Plans() {
  const scopeId = useScopeId();
  const userName = useAuthStore((s) => s.name);
  const { branding } = useBranding();

  // Real-time house owners/projects and customizable master plan catalog
  const { data: owners = [], isLoading, error } = useHousePlans();
  const { catalog: masterCatalog = DEFAULT_MASTER_PLANS } = useMasterPlanCatalog();

  // PDF Export and WhatsApp Share state
  const [downloadingPdfId, setDownloadingPdfId] = useState(null);
  const [sharingPdfId, setSharingPdfId] = useState(null);
  const [whatsappShareData, setWhatsappShareData] = useState(null);
  const [customSharePhone, setCustomSharePhone] = useState('');
  const [savingWorkspace, setSavingWorkspace] = useState(false);
  const [saveSuccessNotice, setSaveSuccessNotice] = useState(false);

  // Search, filter, view mode
  const [search, setSearch] = useState('');
  const [viewMode, setViewMode] = useState('grid'); // 'grid' | 'table'

  // Dedicated Active Owner Workspace ("One Screen for this Owner")
  const [activeOwnerId, setActiveOwnerId] = useState(null);
  const [ownerTab, setOwnerTab] = useState('plans'); // 'plans' | 'payments' | 'info'
  const [planNameFormat, setPlanNameFormat] = useState('clean'); // 'clean' (01 - FINAL PLAN) | 'filename' (01-OWNER-FINAL PLAN)

  // Mount state for portal rendering
  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    setMounted(true);
    return () => setMounted(false);
  }, []);

  // Modals
  const [ownerModalOpen, setOwnerModalOpen] = useState(false);
  const [editingOwnerId, setEditingOwnerId] = useState(null);
  const [ownerForm, setOwnerForm] = useState(EMPTY_OWNER_FORM);
  const [savingOwner, setSavingOwner] = useState(false);

  // Master Catalog Manager Modal
  const [catalogModalOpen, setCatalogModalOpen] = useState(false);
  const [localCatalog, setLocalCatalog] = useState(masterCatalog);
  const [newCatalogItemName, setNewCatalogItemName] = useState('');
  const [newCatalogCategory, setNewCatalogCategory] = useState('Architectural');
  const [savingCatalog, setSavingCatalog] = useState(false);

  // Add Plan to Owner Modal
  const [addPlanModalOpen, setAddPlanModalOpen] = useState(false);
  const [selectedCatalogPlanId, setSelectedCatalogPlanId] = useState('');
  const [customPlanName, setCustomPlanName] = useState('');
  const [planCategory, setPlanCategory] = useState('Architectural');
  const [planNotes, setPlanNotes] = useState('');
  const [planFileUrl, setPlanFileUrl] = useState('');

  // Add Payment to Owner Modal
  const [addPaymentModalOpen, setAddPaymentModalOpen] = useState(false);
  const [paymentForm, setPaymentForm] = useState({
    installmentName: 'Half Payment (Part 1)',
    type: 'half_payment',
    amount: '',
    date: new Date().toISOString().split('T')[0],
    mode: 'UPI',
    referenceNo: '',
    notes: '',
  });

  // Active Owner Data
  const activeOwner = useMemo(() => {
    if (!activeOwnerId) return null;
    return owners.find((o) => o.id === activeOwnerId) || null;
  }, [owners, activeOwnerId]);

  // Overall Statistics
  const overallStats = useMemo(() => {
    let totalSqFt = 0;
    let totalValuation = 0;
    let totalPaid = 0;
    let totalPlansCount = 0;
    let completedPlansCount = 0;

    owners.forEach((o) => {
      totalSqFt += Number(o.totalSqFt || 0);
      totalValuation += Number(o.houseAmount || 0);
      totalPaid += Number(o.totalPaid || 0);

      const pList = o.plansList || [];
      totalPlansCount += pList.length;
      completedPlansCount += pList.filter((p) => p.status === 'completed').length;
    });

    return {
      totalOwners: owners.length,
      totalSqFt,
      totalValuation,
      totalPaid,
      totalPending: Math.max(0, totalValuation - totalPaid),
      totalPlansCount,
      completedPlansCount,
      planCompletionRate: totalPlansCount > 0 ? Math.round((completedPlansCount / totalPlansCount) * 100) : 0,
    };
  }, [owners]);

  // Filtered Owners
  const filteredOwners = useMemo(() => {
    return owners.filter((o) => {
      if (!search.trim()) return true;
      const q = search.toLowerCase();
      return (
        o.ownerName?.toLowerCase().includes(q) ||
        o.city?.toLowerCase().includes(q) ||
        o.town?.toLowerCase().includes(q) ||
        o.planNumber?.toLowerCase().includes(q) ||
        o.serialNumber3D?.toLowerCase().includes(q) ||
        o.ownerPhone?.includes(q) ||
        o.engineerName?.toLowerCase().includes(q)
      );
    });
  }, [owners, search]);

  // Auto-calculate rate per sq.ft
  const handleOwnerAmountOrSqFtChange = (field, value) => {
    setOwnerForm((prev) => {
      const next = { ...prev, [field]: value };
      const amt = Number(field === 'houseAmount' ? value : next.houseAmount);
      const sqft = Number(field === 'totalSqFt' ? value : next.totalSqFt);
      if (amt > 0 && sqft > 0) {
        next.ratePerSqFt = Math.round(amt / sqft);
      }
      return next;
    });
  };

  // Open Add Owner Modal
  const openAddOwner = () => {
    const year = new Date().getFullYear();
    const count = (owners.length + 1).toString().padStart(3, '0');
    setOwnerForm({
      ...EMPTY_OWNER_FORM,
      planNumber: `PLN-${year}-${count}`,
      serialNumber3D: `3D-${year}-${Math.floor(1000 + Math.random() * 9000)}`,
      engineerName: userName ? `Er. ${userName.replace(/^Er\.\s*/i, '')}` : 'Er. Engineer',
    });
    setEditingOwnerId(null);
    setOwnerModalOpen(true);
  };

  // Open Edit Owner Modal (supports either (e, owner), (owner, e), or (owner))
  const openEditOwner = (arg1, arg2) => {
    if (arg1 && typeof arg1.stopPropagation === 'function') {
      arg1.stopPropagation();
    }
    if (arg2 && typeof arg2.stopPropagation === 'function') {
      arg2.stopPropagation();
    }

    const target = (arg1 && typeof arg1 === 'object' && arg1.id)
      ? arg1
      : (arg2 && typeof arg2 === 'object' && arg2.id ? arg2 : activeOwner);

    if (!target) return;

    setOwnerForm({
      ownerName: target.ownerName || '',
      ownerPhone: extract10DigitPhone(target.ownerPhone),
      ownerEmail: target.ownerEmail || '',
      ownerAddress: target.ownerAddress || '',
      city: target.city || target.town || '',
      town: target.town || target.city || '',
      planNumber: target.planNumber || '',
      serialNumber3D: target.serialNumber3D || '',
      title: target.title || '',
      totalSqFt: target.totalSqFt ? String(target.totalSqFt) : '',
      plotAreaSqFt: target.plotAreaSqFt ? String(target.plotAreaSqFt) : '',
      houseAmount: target.houseAmount ? String(target.houseAmount) : '',
      ratePerSqFt: target.ratePerSqFt ? String(target.ratePerSqFt) : '',
      floors: target.floors || 'G+1',
      facing: target.facing || 'East',
      bhk: target.bhk || '3 BHK',
      engineerName: target.engineerName || '',
      engineerPhone: target.engineerPhone || '',
      engineerNotes: target.engineerNotes || '',
      initialAdvanceAmount: '',
      initialAdvanceMode: 'UPI',
    });
    setEditingOwnerId(target.id);
    setOwnerModalOpen(true);
  };

  // Save Owner
  const handleSaveOwner = async () => {
    if (!ownerForm.ownerName.trim()) return toast.error('Owner / Customer Name is required');
    
    const cleanPhone = extract10DigitPhone(ownerForm.ownerPhone);
    if (!cleanPhone) {
      return toast.error('Owner 10-digit Mobile Number is required');
    }
    if (cleanPhone.length !== 10) {
      return toast.error(`Mobile number must be exactly 10 digits (currently ${cleanPhone.length} digits)`);
    }
    if (!/^[6-9]\d{9}$/.test(cleanPhone)) {
      return toast.error('Mobile number must be a valid 10-digit Indian number starting with 6, 7, 8, or 9');
    }
    if (!ownerForm.houseAmount || Number(ownerForm.houseAmount) <= 0) {
      return toast.error('Total Plan Fee is required (e.g. ₹20,000 or ₹35,000)');
    }
    if (!ownerForm.totalSqFt || Number(ownerForm.totalSqFt) <= 0) {
      return toast.error('Total House Sq. Ft. is required');
    }

    setSavingOwner(true);
    const toastId = toast.loading(editingOwnerId ? 'Updating owner project...' : 'Adding new client project for plans...');

    try {
      const sanitizedPayload = {
        ...ownerForm,
        ownerPhone: `+91 ${cleanPhone}`,
      };

      if (editingOwnerId) {
        await updateHousePlan(editingOwnerId, {
          ...sanitizedPayload,
          contractorId: scopeId,
        });
        toast.dismiss(toastId);
        toast.success('Owner project updated successfully');
        setOwnerModalOpen(false);
      } else {
        const initialPayments = [];
        if (Number(ownerForm.initialAdvanceAmount) > 0) {
          initialPayments.push({
            id: `pay_adv_${Date.now()}`,
            installmentName: 'Advance Booking Payment',
            type: 'advance',
            amount: Number(ownerForm.initialAdvanceAmount),
            date: new Date().toISOString().split('T')[0],
            mode: ownerForm.initialAdvanceMode || 'UPI',
            notes: 'Advance recorded on project creation',
            recordedAt: new Date().toISOString(),
          });
        }

        // Automatically attach all 21 standard engineering drawings to newly created owner
        const initial21Plans = DEFAULT_MASTER_PLANS.map((template) => ({
          id: `plan_${Date.now()}_${template.num}`,
          num: template.num,
          name: template.name,
          category: template.category,
          status: 'not_started',
          createdAt: new Date().toISOString(),
          completedDate: null,
        }));

        const newId = await addHousePlan({
          ...sanitizedPayload,
          contractorId: scopeId,
          plansList: initial21Plans,
          payments: initialPayments,
        });

        toast.dismiss(toastId);
        toast.success(`Owner ${ownerForm.ownerName} added successfully!`);
        setOwnerModalOpen(false);
        // Automatically open the new owner workspace so engineer can add plans
        setActiveOwnerId(newId);
        setOwnerTab('plans');
      }
    } catch (err) {
      console.error(err);
      toast.dismiss(toastId);
      toast.error(err.message || 'Failed to save owner');
    } finally {
      setSavingOwner(false);
    }
  };

  // Delete Owner
  const handleDeleteOwner = async (e, ownerId, ownerName) => {
    if (e && typeof e.stopPropagation === 'function') e.stopPropagation();
    if (!window.confirm(`Are you sure you want to delete ${ownerName}? This will permanently remove all plans and payments for this owner.`)) {
      return;
    }
    try {
      await deleteHousePlan(ownerId);
      toast.success(`Deleted ${ownerName}`);
      if (activeOwnerId === ownerId) setActiveOwnerId(null);
    } catch (err) {
      console.error(err);
      toast.error('Failed to delete owner');
    }
  };

  // ── BRANDED PDF BILL GENERATION ────────────────────────────────────
  const handleDownloadPdfBill = async (arg1, arg2) => {
    if (arg1 && typeof arg1.stopPropagation === 'function') arg1.stopPropagation();
    if (arg2 && typeof arg2.stopPropagation === 'function') arg2.stopPropagation();
    const ownerToBill = (arg1 && typeof arg1 === 'object' && arg1.id)
      ? arg1
      : (arg2 && typeof arg2 === 'object' && arg2.id ? arg2 : activeOwner);
    if (!ownerToBill) {
      toast.error('No owner selected for PDF bill generation');
      return;
    }

    setDownloadingPdfId(ownerToBill.id);
    const toastId = toast.loading(`Generating official branded PDF bill for ${ownerToBill.ownerName}...`);
    try {
      await generateHousePlanInvoicePDF({
        owner: { ...ownerToBill, contractorId: ownerToBill.contractorId || scopeId },
        branding,
        saveImmediately: true,
      });
      toast.success(`Official PDF Bill downloaded for ${ownerToBill.ownerName}!`, { id: toastId });
    } catch (err) {
      console.error('Failed to generate PDF Bill:', err);
      toast.error(`Failed to generate PDF Bill: ${err.message || 'Error'}`, { id: toastId });
    } finally {
      setDownloadingPdfId(null);
    }
  };

  // ── SHARE PDF BILL & THANKS MESSAGE TO WHATSAPP ─────────────────────
  const handleSharePdfToWhatsApp = async (arg1, arg2) => {
    if (arg1 && typeof arg1.stopPropagation === 'function') arg1.stopPropagation();
    if (arg2 && typeof arg2.stopPropagation === 'function') arg2.stopPropagation();
    const ownerToBill = (arg1 && typeof arg1 === 'object' && arg1.id)
      ? arg1
      : (arg2 && typeof arg2 === 'object' && arg2.id ? arg2 : activeOwner);
    if (!ownerToBill) {
      toast.error('No owner selected for WhatsApp sharing');
      return;
    }

    // 1. CRITICAL: Open window synchronously on the click gesture to defeat browser popup blockers!
    let waTab = null;
    try {
      waTab = window.open('', '_blank');
      if (waTab) {
        waTab.document.write(`
          <!DOCTYPE html>
          <html>
            <head>
              <title>Opening WhatsApp...</title>
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #09090b; color: #f4f4f5; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
                .card { background: #18181b; border: 1px solid #27272a; border-radius: 16px; padding: 28px 32px; text-align: center; max-width: 400px; box-shadow: 0 20px 40px rgba(0,0,0,0.6); }
                .spinner { width: 40px; height: 40px; border: 3px solid #27272a; border-top-color: #10b981; border-radius: 50%; animation: spin 0.8s linear infinite; margin: 0 auto 16px; }
                @keyframes spin { to { transform: rotate(360deg); } }
                h3 { margin: 0 0 8px; font-size: 17px; color: #10b981; }
                p { margin: 0; font-size: 13px; color: #a1a1aa; line-height: 1.5; }
              </style>
            </head>
            <body>
              <div class="card">
                <div class="spinner"></div>
                <h3>Preparing WhatsApp Bill...</h3>
                <p>Generating official PDF bill for <strong>${ownerToBill.ownerName || 'Client'}</strong> and opening WhatsApp chat...</p>
              </div>
            </body>
          </html>
        `);
      }
    } catch (_) {}

    setSharingPdfId(ownerToBill.id);
    const toastId = toast.loading(`Preparing PDF bill & opening WhatsApp for ${ownerToBill.ownerName}...`);
    try {
      // 2. Generate jsPDF instance in memory
      const doc = await generateHousePlanInvoicePDF({
        owner: { ...ownerToBill, contractorId: ownerToBill.contractorId || scopeId },
        branding,
        saveImmediately: false,
      });

      const ownerName = ownerToBill.ownerName || 'Client';
      const cleanOwnerFileName = ownerName.replace(/[^A-Za-z0-9_-]/g, '_');
      const planNumber = ownerToBill.planNumber || 'PLN';
      const safeFilename = `YS_Construction_Bill_${cleanOwnerFileName}_${planNumber}.pdf`;

      // 3. Prepare professional Thank You message with complete project and billing details
      const totalFee = formatCurrency(ownerToBill.houseAmount);
      const paid = formatCurrency(ownerToBill.totalPaid);
      const pending = formatCurrency(ownerToBill.pendingBalance);
      const coName = branding?.companyName || 'YS Construction';
      const siteLoc = [ownerToBill.ownerAddress, ownerToBill.city || ownerToBill.town].filter(Boolean).join(', ') || ownerToBill.city || '-';
      const builtUpArea = ownerToBill.totalSqFt ? `${Number(ownerToBill.totalSqFt).toLocaleString('en-IN')} sq.ft` : '-';
      const plansCount = (ownerToBill.plansList || []).length || 21;

      const thanksMessage = `Namaste *${ownerName}* ji, 🙏\n\nThank you for choosing *${coName}* for your house planning and architectural engineering drawings! We truly appreciate your trust and partnership.\n\n📋 *PROJECT DETAILS:*\n• *Plan Ref:* ${planNumber}\n• *Site Location:* ${siteLoc}\n• *Built-up Area:* ${builtUpArea}\n• *Scope of Drawings:* ${plansCount} Deliverables\n\n💰 *PAYMENT STATUS:*\n• *Total Plan Fee:* ${totalFee}\n• *Advance Cleared:* ${paid}\n• *Net Remaining Balance:* ${pending}\n\n📄 *Please find your official Planning Invoice & Deliverables Bill (PDF) attached.* Thank you for your business!\n\nWarm regards,\n*${coName}*\n_Architecture • Planner • Consultant • Interior Designer_\n📞 Mo: 80003 40720, 99044 45077\n📍 Gokuldham Complex, Angaldhara, Surat`;

      const cleanPhone = normalizeWhatsAppNumber(ownerToBill.ownerPhone);
      const clean10 = extract10DigitPhone(ownerToBill.ownerPhone);
      setCustomSharePhone(clean10 || '');

      // 4. Download PDF automatically for attaching into chat
      doc.save(safeFilename);

      // WhatsApp URL supporting any unsaved number
      const waUrl = cleanPhone
        ? `https://api.whatsapp.com/send?phone=${cleanPhone}&text=${encodeURIComponent(thanksMessage)}`
        : null;

      const waWebUrl = cleanPhone
        ? `https://web.whatsapp.com/send?phone=${cleanPhone}&text=${encodeURIComponent(thanksMessage)}`
        : null;

      // 5. Automatically redirect the synchronously opened tab IF phone number is valid 10 digits
      if (cleanPhone && waTab && !waTab.closed) {
        waTab.location.href = waUrl;
      } else if (!cleanPhone && waTab && !waTab.closed) {
        try {
          waTab.document.write(`
            <html>
              <head><title>10-Digit Mobile Number Required</title></head>
              <body style="font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#0f172a;color:#f8fafc;text-align:center;">
                <div style="background:#1e293b;border:1px solid #334155;border-radius:16px;padding:32px;max-width:440px;box-shadow:0 20px 40px rgba(0,0,0,0.5);">
                  <div style="font-size:36px;margin-bottom:12px;">📱</div>
                  <h3 style="margin:0 0 10px;font-size:18px;color:#f5a623;">10-Digit Mobile Number Required</h3>
                  <p style="font-size:13px;color:#94a3b8;line-height:1.5;margin:0 0 16px;">
                    <b>${ownerName}</b>'s registered phone number has only ${clean10.length} digits (${ownerToBill.ownerPhone || 'Incomplete'}).
                  </p>
                  <p style="font-size:13px;color:#cbd5e1;line-height:1.5;margin:0;">
                    Please enter the full 10-digit number in the popup on Trackify to open WhatsApp chat.
                  </p>
                </div>
              </body>
            </html>
          `);
        } catch (_) {}
      }

      // 6. Open the foreground modal so the user has full control (can send to new numbers, copy, etc.)
      setWhatsappShareData({
        owner: ownerToBill,
        ownerName,
        ownerPhone: ownerToBill.ownerPhone,
        cleanPhone,
        safeFilename,
        thanksMessage,
        waUrl,
        waWebUrl,
        doc,
      });

      if (cleanPhone) {
        toast.success(`PDF Bill downloaded & WhatsApp chat opened for ${ownerName}!`, {
          id: toastId,
          duration: 4000,
        });
      } else {
        toast.dismiss(toastId);
        toast.error(`Phone number has only ${clean10.length} digits. Enter 10 digits in the box below to open WhatsApp.`, {
          duration: 6000,
        });
      }
    } catch (err) {
      if (waTab && !waTab.closed) {
        try { waTab.close(); } catch (_) {}
      }
      console.error('Failed to share PDF via WhatsApp:', err);
      toast.error(`Failed to share PDF: ${err.message || 'Error'}`, { id: toastId });
    } finally {
      setSharingPdfId(null);
    }
  };

  // ── PLANS WORKFLOW ACTIONS ──────────────────────────────────────────

  // Add plan to active owner
  const handleAddPlanToActiveOwner = async () => {
    if (!activeOwner) return;

    let finalPlanName = customPlanName.trim();
    let finalPlanNum = '';

    if (!finalPlanName && selectedCatalogPlanId) {
      const match = masterCatalog.find((p) => p.id === selectedCatalogPlanId);
      if (match) {
        finalPlanName = match.name;
        finalPlanNum = match.num || match.name.match(/^(\d+)/)?.[1] || '';
      }
    } else if (finalPlanName) {
      finalPlanName = extractMainPlanName(finalPlanName);
      finalPlanNum = finalPlanName.match(/^(\d+)/)?.[1] || '';
    }

    if (!finalPlanName) {
      return toast.error('Please select a plan from catalog or enter a custom name');
    }

    try {
      await addPlanToOwner(activeOwner.id, {
        num: finalPlanNum,
        name: finalPlanName,
        category: planCategory,
        status: 'not_started',
        notes: planNotes,
        fileUrl: planFileUrl,
      });

      toast.success(`Added "${finalPlanName}" to ${activeOwner.ownerName}`);
      setSelectedCatalogPlanId('');
      setCustomPlanName('');
      setPlanNotes('');
      setPlanFileUrl('');
      setAddPlanModalOpen(false);
    } catch (err) {
      console.error(err);
      toast.error('Failed to add plan');
    }
  };

  // Quick 1-click toggle status (Done vs Pending)
  const handleTogglePlanStatus = async (planId, currentStatus) => {
    if (!activeOwner) return;
    try {
      await togglePlanStatus(activeOwner.id, planId, currentStatus);
      const newStatus = currentStatus === 'completed' ? 'Pending' : 'Completed';
      toast.success(`Plan marked as ${newStatus}`);
    } catch (err) {
      console.error(err);
      toast.error('Failed to update plan status');
    }
  };

  // Change plan status directly
  const handleChangePlanStatus = async (planId, status) => {
    if (!activeOwner) return;
    try {
      await updatePlanInOwner(activeOwner.id, planId, { status });
      toast.success(`Status updated to ${PLAN_STATUS_CONFIG[status]?.label || status}`);
    } catch (err) {
      console.error(err);
      toast.error('Failed to update status');
    }
  };

  // Delete plan from active owner
  const handleDeletePlanFromActiveOwner = async (planId, planName) => {
    if (!activeOwner) return;
    if (!window.confirm(`Remove "${planName}" from ${activeOwner.ownerName}'s plans?`)) return;
    try {
      await deletePlanFromOwner(activeOwner.id, planId);
      toast.success(`Removed "${planName}"`);
    } catch (err) {
      console.error(err);
      toast.error('Failed to remove plan');
    }
  };


  // Replace / Sync with Exact 21 Plans (removes old and removes owner name from list)
  const handleSyncExact21Plans = async () => {
    if (!activeOwner) return;
    if (!window.confirm(`Update ${activeOwner.ownerName}'s plans to the EXACT 21 engineering drawings (01-FINAL PLAN to 21-Loan Estimate)?\n\nOld/duplicate plans will be cleaned up, and any completed plans will remain marked done.`)) return;

    const t = toast.loading('Syncing to exact 21 engineering plans...');
    try {
      await resetOwnerPlansToExact21(activeOwner.id);
      toast.dismiss(t);
      toast.success(`Updated ${activeOwner.ownerName} to the exact 21 plans!`);
    } catch (err) {
      console.error(err);
      toast.dismiss(t);
      toast.error('Failed to sync plans');
    }
  };

  // Backward-compatible alias
  const handleSyncExact16Plans = handleSyncExact21Plans;

  // Batch Add all 21 Engineer plans
  const handleAddAll21Plans = async () => {
    if (!activeOwner) return;
    const currentNames = (activeOwner.plansList || []).map((p) => p.name.toLowerCase());
    const toAdd = masterCatalog.filter((p) => !currentNames.includes(p.name.toLowerCase()));

    if (toAdd.length === 0) {
      return toast('All catalog plans are already added to this owner', { icon: 'ℹ️' });
    }

    const t = toast.loading(`Adding ${toAdd.length} plans to ${activeOwner.ownerName}...`);
    try {
      for (const item of toAdd) {
        await addPlanToOwner(activeOwner.id, {
          num: item.num,
          name: item.name,
          category: item.category || 'Architectural',
          status: 'not_started',
        });
      }
      toast.dismiss(t);
      toast.success(`Successfully added all ${toAdd.length} plans to ${activeOwner.ownerName}`);
    } catch (err) {
      console.error(err);
      toast.dismiss(t);
      toast.error('Failed to add plans');
    }
  };

  const handleAddAll16Plans = handleAddAll21Plans;
  const handleAddDefaultStandardPlans = handleAddAll21Plans;

  // ── SAVE WORKSPACE (Explicit save button with prominent foreground feedback) ──
  const handleSaveWorkspace = async () => {
    if (!activeOwner) return;
    setSavingWorkspace(true);

    try {
      const effectivePlans = activeOwner.plansList || [];
      const effectivePayments = activeOwner.payments || [];
      const totalPaid = effectivePayments.reduce((s, p) => s + (Number(p.amount) || 0), 0);
      const houseAmount = Number(activeOwner.houseAmount) || 0;
      const pendingBalance = Math.max(0, houseAmount - totalPaid);

      await updateHousePlan(activeOwner.id, {
        plansList: effectivePlans,
        payments: effectivePayments,
        totalPaid,
        pendingBalance,
        contractorId: activeOwner.contractorId || scopeId,
      });

      // Show prominent in-screen foreground banner only (no duplicate black toast popup)
      setSaveSuccessNotice(true);
      setTimeout(() => {
        setSaveSuccessNotice(false);
      }, 3500);
    } catch (err) {
      console.error('Failed to save workspace:', err);
      toast.error(`Failed to save workspace: ${err.message || 'Error'}`);
    } finally {
      setSavingWorkspace(false);
    }
  };

  // ── PAYMENTS WORKFLOW ACTIONS ────────────────────────────────────────

  // Add payment installment
  const handleAddPayment = async () => {
    if (!activeOwner) return;
    if (!paymentForm.amount || Number(paymentForm.amount) <= 0) {
      return toast.error('Please enter a valid payment amount');
    }

    try {
      await addPaymentToOwner(activeOwner.id, paymentForm);
      toast.success(`Payment of ${formatCurrency(paymentForm.amount)} recorded for ${activeOwner.ownerName}`);
      setPaymentForm({
        installmentName: 'Part 2 Payment',
        type: 'part',
        amount: '',
        date: new Date().toISOString().split('T')[0],
        mode: 'UPI',
        referenceNo: '',
        notes: '',
      });
      setAddPaymentModalOpen(false);
    } catch (err) {
      console.error(err);
      toast.error('Failed to record payment');
    }
  };

  // Delete payment
  const handleDeletePayment = async (paymentId, amount) => {
    if (!activeOwner) return;
    if (!window.confirm(`Delete this payment of ${formatCurrency(amount)}? Balance will be automatically recalculated.`)) return;
    try {
      await deletePaymentFromOwner(activeOwner.id, paymentId);
      toast.success('Payment deleted and balance recalculated');
    } catch (err) {
      console.error(err);
      toast.error('Failed to delete payment');
    }
  };

  // Open Add Payment Modal with smart defaults
  const handleOpenAddPayment = (presetType = null) => {
    if (!activeOwner) return;
    const currentPayments = activeOwner.payments || [];
    const currentCount = currentPayments.length;
    const pending = Number(activeOwner.pendingBalance) || 0;
    const totalFee = Number(activeOwner.houseAmount) || 0;
    const halfAmt = Math.round(totalFee / 2);

    let type = 'half_payment';
    let installmentName = 'Half Payment (50% Plan Fee)';
    let amount = halfAmt > 0 ? String(halfAmt) : '';

    if (presetType === 'advance') {
      type = 'advance';
      installmentName = '1st Advance Booking';
      amount = halfAmt > 0 ? String(halfAmt) : '';
    } else if (currentCount > 0) {
      type = 'final';
      installmentName = `Installment ${currentCount + 1} (Final Settlement)`;
      amount = pending > 0 ? String(pending) : '';
    }

    setPaymentForm({
      installmentName,
      type,
      amount,
      date: new Date().toISOString().split('T')[0],
      mode: 'UPI',
      referenceNo: '',
      notes: '',
    });
    setAddPaymentModalOpen(true);
  };

  // Quick 50% Half Payment Preset
  const handlePresetHalfPayment = () => {
    if (!activeOwner) return;
    const halfAmt = Math.round((Number(activeOwner.houseAmount) || 0) / 2);
    setPaymentForm({
      installmentName: 'Half Payment (50% Plan Fee)',
      type: 'half_payment',
      amount: String(halfAmt),
      date: new Date().toISOString().split('T')[0],
      mode: 'UPI',
      referenceNo: '',
      notes: '50% Half payment installment for engineering & 3D plan drawings',
    });
    setAddPaymentModalOpen(true);
  };

  // Request Payment from Client (WhatsApp reminder with bill details)
  const handleRequestPayment = () => {
    if (!activeOwner) return;
    const ownerName = activeOwner.ownerName || 'Client';
    const planNum = activeOwner.planNumber || '';
    const totalFee = formatCurrency(activeOwner.houseAmount);
    const paid = formatCurrency(activeOwner.totalPaid);
    const pending = formatCurrency(activeOwner.pendingBalance);
    const coName = branding?.companyName || 'YS Construction';

    const message = `Namaste ${ownerName} ji,\n\nThis is a payment request from *${coName}* regarding your House Planning project (*${planNum}*).\n\n• *Total Plan Fee:* ${totalFee}\n• *Amount Received:* ${paid}\n• *Pending Balance:* ${pending}\n\nKindly process the pending installment payment at your earliest convenience.\n\nThank you,\n*${coName}*`;

    const cleanPhone = normalizeWhatsAppNumber(activeOwner.ownerPhone);

    if (cleanPhone) {
      const url = `https://api.whatsapp.com/send?phone=${cleanPhone}&text=${encodeURIComponent(message)}`;
      window.open(url, '_blank');
      toast.success(`Opening WhatsApp payment request for ${ownerName}`);
    } else {
      navigator.clipboard.writeText(message);
      toast.error(`Invalid mobile number (${activeOwner.ownerPhone || 'Empty'}). Payment request text copied to clipboard!`);
    }
  };

  // ── MASTER CATALOG MANAGER ACTIONS ──────────────────────────────────

  const openCatalogManager = () => {
    // If masterCatalog has legacy obsolete items (like "Typical Floor"):
    const hasLegacy = masterCatalog.some(
      (item) =>
        item.id?.startsWith('default_') ||
        item.name?.includes('Typical Floor') ||
        item.name?.includes('Plinth Beam Layout') ||
        !item.num
    );

    if (hasLegacy || !Array.isArray(masterCatalog) || masterCatalog.length === 0) {
      setLocalCatalog([...DEFAULT_MASTER_PLANS]);
      if (scopeId) {
        saveMasterPlanCatalog(scopeId, DEFAULT_MASTER_PLANS).catch(console.error);
        try {
          localStorage.setItem(`trackify_master_catalog_${scopeId}`, JSON.stringify(DEFAULT_MASTER_PLANS));
        } catch (_) {}
      }
    } else {
      // Ensure standard defaults (including 22-Door Details) are merged in if missing
      const existingNames = new Set(masterCatalog.map((m) => (m.mainName || m.name || '').toLowerCase()));
      const missingDefaults = DEFAULT_MASTER_PLANS.filter(
        (def) => !existingNames.has((def.mainName || def.name || '').toLowerCase())
      );
      const merged = missingDefaults.length > 0 ? [...masterCatalog, ...missingDefaults] : [...masterCatalog];
      setLocalCatalog(merged);
    }
    setCatalogModalOpen(true);
  };

  const handleAddCatalogItem = () => {
    if (!newCatalogItemName.trim()) return toast.error('Plan name is required');
    const inputVal = newCatalogItemName.trim();
    const pure = extractPureMainName(inputVal);
    
    // Check if input had a specific number (e.g. "22" in "22-Door Details" or "22 - Door Details")
    const matchedNum = inputVal.match(/^(\d+)/)?.[1];
    const nextNum = matchedNum ? matchedNum.padStart(2, '0') : String(localCatalog.length + 1).padStart(2, '0');
    
    const formattedName = `${nextNum}-${pure}`;

    const newItem = {
      id: `custom_${Date.now()}_${nextNum}`,
      num: nextNum,
      name: formattedName,
      mainName: pure,
      category: newCatalogCategory,
      desc: 'Engineering drawing deliverable template',
    };
    const updated = [...localCatalog, newItem];
    setLocalCatalog(updated);
    setNewCatalogItemName('');
    toast.success(`Added "${formattedName}" to list. Click "Save Catalog Templates" to save to cloud.`);
  };

  const handleDeleteCatalogItem = (id) => {
    setLocalCatalog(localCatalog.filter((item) => item.id !== id));
  };

  const handleSaveCatalog = async () => {
    setSavingCatalog(true);
    try {
      await saveMasterPlanCatalog(scopeId, localCatalog);
      try {
        localStorage.setItem(`trackify_master_catalog_${scopeId}`, JSON.stringify(localCatalog));
      } catch (_) {}
      toast.success(`Master Plan Catalog (${localCatalog.length} templates) saved successfully!`);
      setCatalogModalOpen(false);
    } catch (err) {
      console.error(err);
      toast.error('Failed to save master catalog');
    } finally {
      setSavingCatalog(false);
    }
  };

  const handleResetCatalogToDefaults = async () => {
    if (window.confirm(`Reset catalog to the standard ${DEFAULT_MASTER_PLANS.length} engineering plan templates?`)) {
      setLocalCatalog([...DEFAULT_MASTER_PLANS]);
      if (scopeId) {
        try {
          await saveMasterPlanCatalog(scopeId, DEFAULT_MASTER_PLANS);
          try {
            localStorage.setItem(`trackify_master_catalog_${scopeId}`, JSON.stringify(DEFAULT_MASTER_PLANS));
          } catch (_) {}
          toast.success(`Reset and saved ${DEFAULT_MASTER_PLANS.length} standard engineering templates`);
        } catch {
          toast.success(`Reset to ${DEFAULT_MASTER_PLANS.length} standard engineering templates`);
        }
      } else {
        toast.success(`Reset to ${DEFAULT_MASTER_PLANS.length} standard engineering templates`);
      }
    }
  };

  // ── EXPORT EXCEL ─────────────────────────────────────────────────────
  const handleExportAll = () => {
    if (owners.length === 0) return toast.error('No house owner data to export');

    const rows = owners.map((o) => ({
      'Owner / Customer': o.ownerName,
      'Phone': o.ownerPhone,
      'Town / City': o.city || o.town,
      'Plan Number': o.planNumber,
      '3D Serial No': o.serialNumber3D,
      'Total Plan Fee (₹)': o.houseAmount || 0,
      'Plan Fee Received (₹)': o.totalPaid || 0,
      'Pending Plan Balance (₹)': o.pendingBalance || 0,
      'Total House Sq. Ft.': o.totalSqFt || 0,
      'Plan Rate / Sq. Ft': o.ratePerSqFt || 0,
      'Assigned Plans Count': (o.plansList || []).length,
      'Completed Plans': (o.plansList || []).filter((p) => p.status === 'completed').length,
      'Engineer (Er.)': o.engineerName || '-',
      'Floors': o.floors || '-',
      'Facing': o.facing || '-',
    }));

    const ws = XLSX.utils.json_to_sheet(rows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Plan Clients & Fees');
    XLSX.writeFile(wb, `Trackify_Plan_Fees_${new Date().toISOString().split('T')[0]}.xlsx`);
    toast.success('Exported to Excel');
  };

  // Helper copy
  const copyToClipboard = (e, text, label) => {
    e.stopPropagation();
    navigator.clipboard.writeText(text);
    toast.success(`${label} copied: ${text}`);
  };

  if (error) {
    return (
      <div className="p-6 bg-danger/10 border border-danger/20 rounded-xl text-danger space-y-2">
        <div className="flex items-center gap-2">
          <AlertCircle className="w-5 h-5" />
          <h3 className="font-bold">Error Loading House Plans</h3>
        </div>
        <p className="text-sm">{error.message || 'Check Firestore permissions.'}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* ── TOP STATS OVERVIEW ────────────────────────────────────────── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Total House Owners */}
        <div className="bg-bg-card border border-border rounded-xl p-5 shadow-sm hover:border-gold/30 transition-colors">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[12px] font-semibold text-text-muted uppercase tracking-wider">House Clients / Owners</span>
            <div className="p-2 bg-gold/10 text-gold rounded-lg">
              <Home className="w-5 h-5" />
            </div>
          </div>
          <h3 className="text-2xl font-bold text-text-primary">{overallStats.totalOwners}</h3>
          <p className="text-xs text-text-muted mt-1">
            Clients for 2D/3D Plan Design
          </p>
        </div>

        {/* Plans Completion Progress */}
        <div className="bg-bg-card border border-border rounded-xl p-5 shadow-sm hover:border-info/30 transition-colors">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[12px] font-semibold text-text-muted uppercase tracking-wider">Engineering Plans Status</span>
            <div className="p-2 bg-info/10 text-info rounded-lg">
              <Layers className="w-5 h-5" />
            </div>
          </div>
          <h3 className="text-2xl font-bold text-text-primary">
            {overallStats.completedPlansCount} <span className="text-sm font-normal text-text-muted">/ {overallStats.totalPlansCount} Done</span>
          </h3>
          <div className="w-full bg-bg-input h-1.5 rounded-full mt-2 overflow-hidden">
            <div
              className="bg-info h-full rounded-full transition-all duration-300"
              style={{ width: `${overallStats.planCompletionRate}%` }}
            />
          </div>
        </div>

        {/* Total Plan Fees Billing */}
        <div className="bg-bg-card border border-border rounded-xl p-5 shadow-sm hover:border-success/30 transition-colors">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[12px] font-semibold text-text-muted uppercase tracking-wider">Total Plan Fees Billing</span>
            <div className="p-2 bg-success/10 text-success rounded-lg">
              <IndianRupee className="w-5 h-5" />
            </div>
          </div>
          <h3 className="text-2xl font-bold text-text-primary">
            {formatCurrency(overallStats.totalValuation)}
          </h3>
          <p className="text-xs text-success mt-1 font-medium">
            Fees Collected: {formatCurrency(overallStats.totalPaid)}
          </p>
        </div>

        {/* Pending Plan Fees */}
        <div className="bg-bg-card border border-border rounded-xl p-5 shadow-sm hover:border-warning/30 transition-colors">
          <div className="flex items-center justify-between mb-2">
            <span className="text-[12px] font-semibold text-text-muted uppercase tracking-wider">Pending Plan Fees</span>
            <div className="p-2 bg-warning/10 text-warning rounded-lg">
              <Wallet className="w-5 h-5" />
            </div>
          </div>
          <h3 className="text-2xl font-bold text-warning">
            {formatCurrency(overallStats.totalPending)}
          </h3>
          <p className="text-xs text-text-muted mt-1">Outstanding plan balance across clients</p>
        </div>
      </div>

      {/* ── ACTION BAR & SEARCH ──────────────────────────────────────── */}
      <div className="flex flex-col md:flex-row gap-4 items-stretch md:items-center justify-between bg-bg-card border border-border p-4 rounded-xl">
        {/* Search */}
        <div className="relative flex-1 min-w-[260px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-muted" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by owner name, town/city, phone, 3D serial, plan no..."
            className="w-full pl-9 pr-4 py-2 bg-bg-input border border-border-strong rounded-lg text-sm text-text-primary placeholder-text-muted focus:outline-none focus:border-gold transition-colors"
          />
        </div>

        {/* Action Buttons */}
        <div className="flex flex-wrap items-center gap-2.5">
          {/* Master Catalog 21 Plans Button */}
          <button
            onClick={openCatalogManager}
            className="flex items-center gap-1.5 px-3 py-2 bg-bg-input border border-border-strong rounded-lg text-xs font-medium text-text-secondary hover:text-gold hover:border-gold transition-colors"
            title="Configure 21 Master Plan Templates"
          >
            <Settings2 className="w-4 h-4 text-gold" />
            <span>Master Catalog ({masterCatalog.length} Plans)</span>
          </button>

          {/* View Mode */}
          <div className="flex items-center bg-bg-input border border-border-strong rounded-lg p-0.5">
            <button
              onClick={() => setViewMode('grid')}
              className={`p-1.5 rounded ${viewMode === 'grid' ? 'bg-bg-elevated text-gold shadow-sm' : 'text-text-muted hover:text-text-secondary'}`}
              title="Card View"
            >
              <LayoutGrid className="w-4 h-4" />
            </button>
            <button
              onClick={() => setViewMode('table')}
              className={`p-1.5 rounded ${viewMode === 'table' ? 'bg-bg-elevated text-gold shadow-sm' : 'text-text-muted hover:text-text-secondary'}`}
              title="Table View"
            >
              <List className="w-4 h-4" />
            </button>
          </div>

          {/* Export */}
          <button
            onClick={handleExportAll}
            className="flex items-center gap-1.5 px-3 py-2 bg-bg-input border border-border-strong rounded-lg text-xs font-medium text-text-secondary hover:text-text-primary hover:border-gold transition-colors"
            title="Export to Excel"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Export</span>
          </button>

          {/* Add Owner Button */}
          <button
            onClick={openAddOwner}
            className="flex items-center gap-2 px-4 py-2 bg-gold text-bg-primary font-semibold text-xs rounded-lg shadow-[0_0_15px_rgba(245,166,35,0.25)] hover:scale-105 active:scale-95 transition-all"
          >
            <Plus className="w-4 h-4" />
            <span>Add New House Owner</span>
          </button>
        </div>
      </div>

      {/* ── OWNERS LIST (GRID OR TABLE) ──────────────────────────────── */}
      {isLoading ? (
        <div className="py-20 flex flex-col items-center justify-center bg-bg-card border border-border rounded-xl">
          <LoadingSpinner label="Loading House Owners, Plans & Ledgers..." />
        </div>
      ) : filteredOwners.length === 0 ? (
        <EmptyState
          icon={Home}
          title={search ? 'No matching house owners' : 'No house owners added yet'}
          description={
            search
              ? 'Try modifying your search keywords.'
              : 'Add your first customer/owner (e.g. Tanvir) with their contact details, house amount, and engineering plans.'
          }
          action={
            <Button onClick={openAddOwner} className="bg-gold text-bg-primary font-semibold">
              <Plus className="w-4 h-4 mr-2" /> Add First Owner
            </Button>
          }
        />
      ) : viewMode === 'grid' ? (
        /* ── GRID OF OWNERS ─────────────────────────────────────────── */
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filteredOwners.map((owner) => {
            const plans = owner.plansList || [];
            const completedCount = plans.filter((p) => p.status === 'completed').length;
            const progressPct = plans.length > 0 ? Math.round((completedCount / plans.length) * 100) : 0;
            const paymentBadge = getPaymentStatusBadge(owner.houseAmount, owner.totalPaid);

            return (
              <motion.div
                key={owner.id}
                layout
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 12 }}
                onClick={() => {
                  setActiveOwnerId(owner.id);
                  setOwnerTab('plans');
                }}
                className="group relative bg-gradient-to-b from-bg-card via-bg-card to-bg-elevated/40 border border-border/80 hover:border-gold/60 rounded-2xl p-5 shadow-[0_4px_24px_rgba(0,0,0,0.03)] hover:shadow-[0_16px_42px_rgba(245,166,35,0.12)] transition-all duration-300 cursor-pointer flex flex-col justify-between overflow-hidden"
              >
                {/* Luminous Top Gold Hover Accent */}
                <div className="absolute top-0 left-0 right-0 h-[2.5px] bg-gradient-to-r from-transparent via-gold to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />

                <div>
                  {/* Top Bar: Clean Plan No Badge (3D Serial Removed) & Payment Status */}
                  <div className="flex items-center justify-between gap-2 mb-4">
                    <span
                      onClick={(e) => copyToClipboard(e, owner.planNumber, 'Plan No')}
                      className="inline-flex items-center gap-1.5 px-3 py-1 bg-amber-500/10 hover:bg-amber-500/20 border border-amber-500/30 text-amber-600 dark:text-amber-400 font-mono text-xs font-bold rounded-lg shadow-sm transition-colors"
                      title="Click to copy Plan No"
                    >
                      <Compass className="w-3.5 h-3.5 text-gold" />
                      <span>{owner.planNumber || 'PLN'}</span>
                    </span>

                    <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[10px] font-bold tracking-wider border shadow-sm ${paymentBadge.bg}`}>
                      <span className={`w-1.5 h-1.5 rounded-full ${paymentBadge.dot || 'bg-current'} animate-pulse`} />
                      <span>{paymentBadge.label}</span>
                    </span>
                  </div>

                  {/* Owner Header Info */}
                  <div className="mb-3.5">
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <div className="p-2 bg-gradient-to-br from-gold/20 to-gold/5 text-gold border border-gold/25 rounded-xl shrink-0 shadow-sm group-hover:scale-105 transition-transform">
                        <Home className="w-4 h-4" />
                      </div>
                      <h3 className="text-lg font-extrabold text-text-primary group-hover:text-gold transition-colors tracking-tight truncate">
                        {owner.ownerName}
                      </h3>
                    </div>

                    <div className="flex flex-wrap items-center gap-2 text-xs text-text-muted pl-0.5">
                      {owner.ownerPhone && (
                        <span className="font-mono text-[11px] font-medium text-text-secondary bg-bg-input/60 border border-border/60 px-2 py-0.5 rounded-md flex items-center gap-1">
                          <Phone className="w-3 h-3 text-text-muted" />
                          <span>{owner.ownerPhone}</span>
                        </span>
                      )}
                      {(owner.city || owner.town) && (
                        <span className="text-[11px] font-medium text-sky-600 dark:text-sky-400 bg-sky-500/10 border border-sky-500/20 px-2 py-0.5 rounded-md flex items-center gap-1">
                          <MapPin className="w-3 h-3" />
                          <span>{owner.city || owner.town}</span>
                        </span>
                      )}
                      {owner.totalSqFt && (
                        <span className="text-[11px] text-text-muted font-medium bg-bg-input/40 px-2 py-0.5 rounded-md border border-border/40">
                          {Number(owner.totalSqFt).toLocaleString('en-IN')} sq.ft
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Engineering Drawing Scope Progress Box */}
                  <div className="bg-gradient-to-br from-bg-elevated/70 via-bg-input/40 to-bg-card border border-border/70 rounded-xl p-3.5 mb-3.5 shadow-sm">
                    <div className="flex items-center justify-between text-xs mb-2">
                      <span className="font-bold text-text-secondary flex items-center gap-1.5 text-xs">
                        <Layers className="w-3.5 h-3.5 text-amber-500" />
                        <span>Drawing Scope:</span>
                      </span>
                      <span className="font-mono text-[11px] font-bold text-text-primary bg-bg-card px-2.5 py-0.5 rounded-md border border-border/60 shadow-xs">
                        {completedCount} / {plans.length} Done ({progressPct}%)
                      </span>
                    </div>

                    <div className="w-full bg-border/40 h-2 rounded-full overflow-hidden p-0.5 mb-2.5">
                      <div
                        className="bg-gradient-to-r from-amber-500 via-amber-400 to-emerald-500 h-full rounded-full transition-all duration-500 shadow-[0_0_8px_rgba(245,166,35,0.4)]"
                        style={{ width: `${progressPct}%` }}
                      />
                    </div>

                    <div className="flex flex-wrap gap-1.5">
                      {plans.slice(0, 4).map((p) => (
                        <span
                          key={p.id}
                          className={`text-[10px] px-2 py-0.5 rounded-md font-medium border flex items-center gap-1 transition-colors ${
                            p.status === 'completed'
                              ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-600 dark:text-emerald-400 font-semibold'
                              : 'bg-bg-input/70 border-border/60 text-text-muted'
                          }`}
                        >
                          {p.status === 'completed' && <Check className="w-2.5 h-2.5 stroke-[3]" />}
                          <span>{p.name.length > 18 ? p.name.substring(0, 16) + '...' : p.name}</span>
                        </span>
                      ))}
                      {plans.length > 4 && (
                        <span className="text-[10px] font-mono px-2 py-0.5 text-text-muted bg-bg-elevated/80 border border-border/50 rounded-md">
                          +{plans.length - 4} more
                        </span>
                      )}
                      {plans.length === 0 && (
                        <span className="text-[11px] text-text-muted italic">
                          No plans attached yet — click to add
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Financials Strip */}
                  <div className="grid grid-cols-2 gap-3 bg-gradient-to-r from-bg-input/80 via-bg-elevated/40 to-bg-input/80 border border-border/70 rounded-xl p-3 text-xs mb-3 shadow-inner">
                    <div>
                      <span className="text-[10px] text-text-muted uppercase font-bold tracking-wider block mb-0.5">
                        Agreed Plan Fee
                      </span>
                      <span className="font-extrabold text-sm text-text-primary">
                        {formatCurrency(owner.houseAmount)}
                      </span>
                    </div>

                    <div>
                      <span className="text-[10px] text-text-muted uppercase font-bold tracking-wider block mb-0.5">
                        Remaining Balance
                      </span>
                      {Number(owner.pendingBalance) <= 0 && Number(owner.houseAmount) > 0 ? (
                        <span className="font-extrabold text-sm text-emerald-500 flex items-center gap-1">
                          <span>₹0</span>
                          <span className="text-[9px] font-bold px-1.5 py-0.5 bg-emerald-500/15 border border-emerald-500/30 rounded text-emerald-500">PAID</span>
                        </span>
                      ) : (
                        <span className="font-extrabold text-sm text-amber-500">
                          {formatCurrency(owner.pendingBalance)}
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Engineer Info */}
                  {owner.engineerName && (
                    <div className="flex items-center justify-between text-[11px] text-text-muted px-1 mb-3">
                      <span>Supervising Engineer:</span>
                      <span className="text-amber-500 font-semibold flex items-center gap-1 bg-amber-500/10 px-2 py-0.5 rounded-md border border-amber-500/20">
                        <HardHat className="w-3 h-3 text-gold" />
                        <span>{owner.engineerName}</span>
                      </span>
                    </div>
                  )}
                </div>

                {/* Footer Quick Actions */}
                <div className="pt-3.5 border-t border-border/80 mt-1 flex items-center justify-between gap-2" onClick={(e) => e.stopPropagation()}>
                  <button
                    onClick={() => {
                      setActiveOwnerId(owner.id);
                      setOwnerTab('plans');
                    }}
                    className="flex-1 flex items-center justify-center gap-1.5 py-2 px-3 bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-400 hover:to-amber-500 text-bg-primary font-bold rounded-xl text-xs shadow-[0_4px_14px_rgba(245,166,35,0.25)] hover:shadow-[0_6px_18px_rgba(245,166,35,0.4)] active:scale-95 transition-all"
                  >
                    <span>Manage Plans & Payments</span>
                    <ChevronRight className="w-3.5 h-3.5 stroke-[2.5]" />
                  </button>

                  <button
                    onClick={(e) => handleDownloadPdfBill(e, owner)}
                    disabled={downloadingPdfId === owner.id}
                    className="p-2 bg-bg-elevated hover:bg-amber-500/15 hover:border-amber-500/40 text-text-secondary hover:text-amber-500 border border-border/80 rounded-xl transition-all disabled:opacity-50 active:scale-90"
                    title="Download Branded PDF Bill"
                  >
                    <Printer className="w-3.5 h-3.5" />
                  </button>

                  <button
                    onClick={(e) => handleSharePdfToWhatsApp(owner, e)}
                    disabled={sharingPdfId === owner.id}
                    className="p-2 bg-bg-elevated hover:bg-emerald-500/15 hover:border-emerald-500/40 text-text-secondary hover:text-emerald-400 border border-border/80 rounded-xl transition-all disabled:opacity-50 active:scale-90"
                    title="Share PDF Bill with Thanks Message to Client on WhatsApp"
                  >
                    <Share2 className="w-3.5 h-3.5" />
                  </button>

                  <button
                    onClick={(e) => openEditOwner(e, owner)}
                    className="p-2 bg-bg-elevated hover:bg-sky-500/15 hover:border-sky-500/40 text-text-secondary hover:text-sky-400 border border-border/80 rounded-xl transition-all active:scale-90"
                    title="Edit Owner Info"
                  >
                    <Pencil className="w-3.5 h-3.5" />
                  </button>

                  <button
                    onClick={(e) => handleDeleteOwner(e, owner.id, owner.ownerName)}
                    className="p-2 bg-bg-elevated hover:bg-rose-500/15 hover:border-rose-500/40 text-text-muted hover:text-rose-400 border border-border/80 rounded-xl transition-all active:scale-90"
                    title="Delete Owner Project"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </motion.div>
            );
          })}
        </div>
      ) : (
        /* ── TABLE VIEW ─────────────────────────────────────────────── */
        <div className="bg-bg-card border border-border rounded-xl overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-text-secondary">
              <thead className="bg-bg-elevated/70 text-[11px] uppercase tracking-wider text-text-muted border-b border-border">
                <tr>
                  <th className="py-3 px-4">Plan No</th>
                  <th className="py-3 px-4">House Client / Owner</th>
                  <th className="py-3 px-4">Plans Progress</th>
                  <th className="py-3 px-4 text-right">Plan Fee</th>
                  <th className="py-3 px-4 text-right">Fee Received</th>
                  <th className="py-3 px-4 text-right">Pending Fee</th>
                  <th className="py-3 px-4">Payment Status</th>
                  <th className="py-3 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {filteredOwners.map((owner) => {
                  const plans = owner.plansList || [];
                  const completedCount = plans.filter((p) => p.status === 'completed').length;
                  const paymentBadge = getPaymentStatusBadge(owner.houseAmount, owner.totalPaid);

                  return (
                    <tr
                      key={owner.id}
                      onClick={() => {
                        setActiveOwnerId(owner.id);
                        setOwnerTab('plans');
                      }}
                      className="hover:bg-bg-elevated/40 cursor-pointer transition-colors"
                    >
                      <td className="py-3.5 px-4 font-mono font-medium">
                        <div className="text-gold font-semibold">{owner.planNumber || 'PLN'}</div>
                      </td>

                      <td className="py-3.5 px-4">
                        <div className="font-semibold text-text-primary text-sm">{owner.ownerName}</div>
                        <div className="text-[11px] text-text-muted">
                          {owner.ownerPhone} • {owner.city || owner.town || 'Site'}
                        </div>
                      </td>

                      <td className="py-3.5 px-4">
                        <div className="font-medium text-text-primary">
                          {completedCount} of {plans.length} Plans Completed
                        </div>
                        <div className="w-32 bg-bg-input h-1 rounded-full mt-1.5 overflow-hidden">
                          <div
                            className="bg-info h-full rounded-full"
                            style={{ width: `${plans.length > 0 ? (completedCount / plans.length) * 100 : 0}%` }}
                          />
                        </div>
                      </td>

                      <td className="py-3.5 px-4 text-right font-bold text-text-primary">
                        {formatCurrency(owner.houseAmount)}
                      </td>

                      <td className="py-3.5 px-4 text-right font-semibold text-success">
                        {formatCurrency(owner.totalPaid)}
                      </td>

                      <td className="py-3.5 px-4 text-right font-semibold text-warning">
                        {formatCurrency(owner.pendingBalance)}
                      </td>

                      <td className="py-3.5 px-4">
                        <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider border ${paymentBadge.bg}`}>
                          {paymentBadge.label}
                        </span>
                      </td>

                      <td className="py-3.5 px-4 text-right" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => {
                              setActiveOwnerId(owner.id);
                              setOwnerTab('plans');
                            }}
                            className="p-1.5 hover:bg-gold/10 hover:text-gold rounded text-text-muted transition-colors"
                            title="Open Owner Workspace"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          <button
                            onClick={(e) => handleDownloadPdfBill(e, owner)}
                            disabled={downloadingPdfId === owner.id}
                            className="p-1.5 hover:bg-gold/10 hover:text-gold rounded text-text-muted transition-colors disabled:opacity-50"
                            title="Download Branded PDF Bill"
                          >
                            <Printer className="w-4 h-4" />
                          </button>
                          <button
                            onClick={(e) => handleSharePdfToWhatsApp(owner, e)}
                            disabled={sharingPdfId === owner.id}
                            className="p-1.5 hover:bg-emerald-600/15 hover:text-emerald-400 rounded text-text-muted transition-colors disabled:opacity-50"
                            title="Share PDF Bill with Thanks Message on WhatsApp"
                          >
                            <Share2 className="w-4 h-4" />
                          </button>
                          <button
                            onClick={(e) => openEditOwner(e, owner)}
                            className="p-1.5 hover:bg-bg-input rounded text-text-muted hover:text-text-primary transition-colors"
                            title="Edit Owner"
                          >
                            <Pencil className="w-3.5 h-3.5" />
                          </button>
                          <button
                            onClick={(e) => handleDeleteOwner(e, owner.id, owner.ownerName)}
                            className="p-1.5 hover:bg-danger/10 rounded text-text-muted hover:text-danger transition-colors"
                            title="Delete Owner"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ═══════════════════════════════════════════════════════════════════ */}
      {/* ── DEDICATED OWNER WORKSPACE (Card Modal with Full-Size Backdrop Blur) ── */}
      {/* ═══════════════════════════════════════════════════════════════════ */}
      {mounted &&
        createPortal(
          <AnimatePresence>
            {activeOwner && (
              <div
                className="fixed inset-0 z-[50000] flex items-center justify-center p-3 sm:p-5 overflow-hidden"
                style={{ zIndex: 50000 }}
              >
                {/* 100% Full-Size Backdrop Blur covering the entire browser window */}
                <motion.div
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.2 }}
                  className="fixed inset-0 bg-black/60 backdrop-blur-md"
                  onClick={() => setActiveOwnerId(null)}
                />

                {/* Centered Modal Card ("Card is half old" with Upper Pending UI & 21 Plans) */}
                <motion.div
                  initial={{ opacity: 0, scale: 0.95, y: 15 }}
                  animate={{ opacity: 1, scale: 1, y: 0 }}
                  exit={{ opacity: 0, scale: 0.95, y: 15 }}
                  transition={{ type: 'spring', damping: 25, stiffness: 300 }}
                  className="relative w-full max-w-5xl bg-bg-card border border-border rounded-2xl shadow-[0_30px_90px_rgba(0,0,0,0.85)] overflow-hidden z-10 max-h-[92vh] flex flex-col"
                >
                  {/* Floating In-Card Success Banner (Guaranteed 100% in front of everything) */}
                  <AnimatePresence>
                    {saveSuccessNotice && (
                      <motion.div
                        initial={{ opacity: 0, y: -25, scale: 0.9 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        exit={{ opacity: 0, y: -20, scale: 0.95 }}
                        transition={{ type: 'spring', damping: 22, stiffness: 320 }}
                        className="absolute top-3 left-1/2 -translate-x-1/2 z-[200] bg-emerald-600 border border-emerald-400 text-white px-5 py-2.5 rounded-2xl shadow-[0_15px_40px_rgba(0,0,0,0.7)] flex items-center gap-3 font-bold text-xs pointer-events-none"
                      >
                        <div className="p-1 bg-white/20 rounded-full shrink-0">
                          <Check className="w-4 h-4 text-white stroke-[3]" />
                        </div>
                        <div className="text-left">
                          <div className="font-bold text-white text-xs">Workspace Saved Successfully!</div>
                          <div className="text-[10px] text-emerald-100 font-normal">All drawings, payments, and specs for {activeOwner.ownerName} are saved in cloud.</div>
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>

                  {/* Upper Header Bar with Full Pending & Fee UI */}
                  <div className="border-b border-border bg-bg-elevated/60 px-5 py-3.5 flex flex-wrap items-center justify-between gap-4 shrink-0 shadow-sm">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="p-2.5 bg-gold/15 text-gold border border-gold/30 rounded-xl shrink-0">
                        <Home className="w-5 h-5" />
                      </div>
                      <div className="min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          <h2 className="text-lg sm:text-xl font-bold text-text-primary truncate">
                            {activeOwner.ownerName}
                          </h2>
                          <span className="text-xs px-2.5 py-0.5 rounded font-mono font-semibold bg-bg-input border border-border-strong text-gold">
                            {activeOwner.planNumber}
                          </span>
                          {activeOwner.serialNumber3D && (
                            <span className="text-xs px-2.5 py-0.5 rounded font-mono font-semibold bg-cyan-950/50 border border-cyan-500/30 text-cyan-400 flex items-center gap-1">
                              <Sparkles className="w-3 h-3" />
                              {activeOwner.serialNumber3D}
                            </span>
                          )}
                        </div>
                        <div className="flex flex-wrap items-center gap-3 text-xs text-text-muted mt-1">
                          {activeOwner.ownerPhone && (
                            <span className="flex items-center gap-1">
                              <Phone className="w-3 h-3" />
                              {activeOwner.ownerPhone}
                            </span>
                          )}
                          {(activeOwner.city || activeOwner.town) && (
                            <span className="flex items-center gap-1">
                              <MapPin className="w-3 h-3" />
                              {activeOwner.city || activeOwner.town}
                            </span>
                          )}
                          {activeOwner.totalSqFt && (
                            <span className="text-text-secondary font-medium">
                              {Number(activeOwner.totalSqFt).toLocaleString('en-IN')} sq.ft
                            </span>
                          )}
                          {activeOwner.engineerName && (
                            <span className="text-gold font-medium flex items-center gap-1">
                              <HardHat className="w-3 h-3" />
                              {activeOwner.engineerName}
                            </span>
                          )}
                        </div>
                      </div>
                    </div>

                    {/* Upper Pending UI & Quick Actions */}
                    <div className="flex items-center gap-2.5 flex-wrap">
                      <div className="flex items-center gap-2 bg-bg-input/60 border border-border-strong rounded-xl p-1.5 px-3">
                        <div className="text-right">
                          <span className="text-[10px] text-text-muted uppercase font-semibold block leading-tight">Plan Fee</span>
                          <span className="text-xs font-bold text-text-primary">{formatCurrency(activeOwner.houseAmount)}</span>
                        </div>
                        <div className="h-6 w-[1px] bg-border-strong mx-1" />
                        <div className="text-right">
                          <span className="text-[10px] text-text-muted uppercase font-semibold block leading-tight">Paid</span>
                          <span className="text-xs font-bold text-success">{formatCurrency(activeOwner.totalPaid)}</span>
                        </div>
                        <div className="h-6 w-[1px] bg-border-strong mx-1" />
                        <div className="text-right">
                          <span className="text-[10px] text-warning uppercase font-bold block leading-tight">Pending</span>
                          <span className="text-xs font-extrabold text-warning">{formatCurrency(activeOwner.pendingBalance)}</span>
                        </div>
                      </div>

                      <button
                        onClick={(e) => handleDownloadPdfBill(activeOwner, e)}
                        disabled={downloadingPdfId === activeOwner.id}
                        className="flex items-center gap-1.5 px-3 py-2 bg-gold hover:bg-gold/90 text-bg-primary rounded-xl text-xs font-semibold shadow-sm hover:scale-105 active:scale-95 transition-all disabled:opacity-50"
                        title="Download Branded PDF Bill & Schedule of Deliverables"
                      >
                        <Printer className="w-3.5 h-3.5" />
                        <span>{downloadingPdfId === activeOwner.id ? 'Generating PDF...' : 'Download PDF Bill'}</span>
                      </button>

                      <button
                        onClick={(e) => handleSharePdfToWhatsApp(activeOwner, e)}
                        disabled={sharingPdfId === activeOwner.id}
                        className="flex items-center gap-1.5 px-3 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-semibold shadow-sm hover:scale-105 active:scale-95 transition-all disabled:opacity-50"
                        title="Share Branded PDF Bill & Thank-You Message to Client via WhatsApp"
                      >
                        <Share2 className="w-3.5 h-3.5" />
                        <span>{sharingPdfId === activeOwner.id ? 'Preparing...' : 'Share Bill on WhatsApp'}</span>
                      </button>

                      <button
                        onClick={(e) => openEditOwner(e, activeOwner)}
                        className="flex items-center gap-1.5 px-3 py-2 bg-bg-input border border-border-strong hover:border-gold text-text-secondary hover:text-gold rounded-xl text-xs font-semibold transition-colors shadow-sm hover:scale-105 active:scale-95"
                        title="Edit Plan Fee, House Area & Client Details"
                      >
                        <Pencil className="w-3.5 h-3.5" />
                        <span>Edit Fee & Details</span>
                      </button>

                      <button
                        onClick={() => setActiveOwnerId(null)}
                        className="p-2 hover:bg-bg-input border border-border-strong rounded-xl text-text-muted hover:text-text-primary transition-colors"
                        title="Close Workspace"
                      >
                        <X className="w-5 h-5" />
                      </button>
                    </div>
                  </div>

            {/* Sub-Navigation Tabs */}
            <div className="flex items-center border-b border-border bg-bg-card px-6 gap-2 shrink-0">
                <button
                  onClick={() => setOwnerTab('plans')}
                  className={`flex items-center gap-2 py-3 px-4 text-xs font-semibold border-b-2 transition-all ${
                    ownerTab === 'plans'
                      ? 'border-gold text-gold bg-bg-elevated/40'
                      : 'border-transparent text-text-muted hover:text-text-secondary'
                  }`}
                >
                  <Layers className="w-4 h-4" />
                  <span>Engineering Plans Checklist ({(activeOwner.plansList || []).length})</span>
                </button>

                <button
                  onClick={() => setOwnerTab('payments')}
                  className={`flex items-center gap-2 py-3 px-4 text-xs font-semibold border-b-2 transition-all ${
                    ownerTab === 'payments'
                      ? 'border-gold text-gold bg-bg-elevated/40'
                      : 'border-transparent text-text-muted hover:text-text-secondary'
                  }`}
                >
                  <CreditCard className="w-4 h-4" />
                  <span>Payments & Balance Ledger</span>
                </button>

                <button
                  onClick={() => setOwnerTab('info')}
                  className={`flex items-center gap-2 py-3 px-4 text-xs font-semibold border-b-2 transition-all ${
                    ownerTab === 'info'
                      ? 'border-gold text-gold bg-bg-elevated/40'
                      : 'border-transparent text-text-muted hover:text-text-secondary'
                  }`}
                >
                  <FileText className="w-4 h-4" />
                  <span>Project Specs & Notes</span>
                </button>
              </div>

              {/* Workspace Body */}
              <div className="p-5 sm:p-6 overflow-y-auto flex-1 space-y-5 max-w-7xl mx-auto w-full">
                {/* ════ TAB 1: PLANS WORKFLOW ════ */}
                {ownerTab === 'plans' && (
                  <div className="space-y-4">
                    {/* Controls Bar for Plans */}
                    <div className="flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-3 bg-bg-elevated/40 border border-border-strong rounded-xl p-3.5">
                      <div className="flex flex-wrap items-center gap-3">
                        <div className="text-xs">
                          <span className="text-text-muted">Plans Attached: </span>
                          <span className="font-bold text-text-primary text-sm">
                            {(activeOwner.plansList || []).filter((p) => p.status === 'completed').length} / {(activeOwner.plansList || []).length} Completed
                          </span>
                        </div>
                      </div>

                      <div className="flex flex-wrap items-center gap-2">
                        {/* Sync / Replace with Standard Master Plans Button */}
                        <button
                          onClick={handleSyncExact21Plans}
                          className="px-3 py-1.5 bg-gold text-bg-primary rounded-lg text-xs font-bold hover:scale-105 active:scale-95 transition-all shadow-sm flex items-center gap-1.5"
                          title={`Sync to the standard engineering drawings (including 22-Door Details), removing old/duplicate plans`}
                        >
                          <RotateCcw className="w-3.5 h-3.5" />
                          <span>Sync Standard Plans ({DEFAULT_MASTER_PLANS.length})</span>
                        </button>

                        <button
                          onClick={handleAddAll21Plans}
                          className="px-3 py-1.5 bg-bg-input border border-border-strong hover:border-gold rounded-lg text-xs font-medium text-text-secondary hover:text-gold transition-colors"
                          title="Add missing plans from the master catalog"
                        >
                          + Add All Catalog Plans
                        </button>

                        <button
                          onClick={() => {
                            setSelectedCatalogPlanId('');
                            setCustomPlanName('');
                            setAddPlanModalOpen(true);
                          }}
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-bg-input border border-border-strong hover:border-gold text-text-secondary hover:text-gold rounded-lg text-xs font-medium transition-all"
                        >
                          <Plus className="w-3.5 h-3.5" />
                          <span>Add Custom Plan</span>
                        </button>
                      </div>
                    </div>

                    {/* Plans List Cards */}
                    {(activeOwner.plansList || []).length === 0 ? (
                      <div className="text-center py-12 border border-dashed border-border-strong rounded-xl p-8 bg-bg-input/20">
                        <Compass className="w-10 h-10 text-gold mx-auto mb-3 opacity-60" />
                        <h4 className="text-base font-bold text-text-primary mb-1">
                          No plans added for {activeOwner.ownerName} yet
                        </h4>
                        <p className="text-xs text-text-muted max-w-md mx-auto mb-4">
                          Load the exact 21 engineering plans (01-FINAL PLAN, 02-CENTER LINE, 03-FOUNDATION PLAN DETAILS... up to 21-Loan Estimate).
                        </p>
                        <div className="flex flex-wrap justify-center gap-3">
                          <button
                            onClick={handleSyncExact21Plans}
                            className="px-4 py-2 bg-gold text-bg-primary text-xs font-bold rounded-lg shadow-sm hover:scale-105 flex items-center gap-1.5"
                          >
                            <RotateCcw className="w-3.5 h-3.5" />
                            <span>Load All Exact 21 Plans</span>
                          </button>
                          <button
                            onClick={handleAddAll21Plans}
                            className="px-4 py-2 bg-bg-input border border-border-strong text-text-secondary text-xs font-medium rounded-lg hover:border-gold"
                          >
                            + Add All 21 Plans
                          </button>
                          <button
                            onClick={() => setAddPlanModalOpen(true)}
                            className="px-4 py-2 bg-bg-input border border-border-strong text-text-secondary text-xs font-medium rounded-lg hover:border-gold"
                          >
                            Choose from Catalog
                          </button>
                        </div>
                      </div>
                    ) : (
                      <div className="space-y-2.5">
                        {activeOwner.plansList.map((plan, index) => {
                          const statusStyle = PLAN_STATUS_CONFIG[plan.status] || PLAN_STATUS_CONFIG.not_started;
                          const isDone = plan.status === 'completed';
                          const planBadgeNum = plan.num || plan.name?.match(/^(\d+)/)?.[1] || String(index + 1).padStart(2, '0');
                          const exactPlanName = `${planBadgeNum}-${extractPureMainName(plan.name)}`;

                          return (
                            <div
                              key={plan.id}
                              className={`p-3.5 rounded-xl border transition-all flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 ${
                                isDone
                                  ? 'bg-success/5 border-success/30'
                                  : 'bg-bg-elevated/40 border-border-strong hover:border-gold/40'
                              }`}
                            >
                              <div className="flex items-start sm:items-center gap-3 flex-1 min-w-0">
                                <div className="min-w-0 flex-1">
                                  <div className="flex items-center gap-2 flex-wrap">
                                    <h4 className={`text-sm font-bold ${isDone ? 'text-success' : 'text-text-primary'}`}>
                                      {exactPlanName}
                                    </h4>
                                    <span className="text-[10px] px-2 py-0.5 rounded bg-bg-input border border-border-strong text-text-muted">
                                      {plan.category || 'Architectural'}
                                    </span>
                                  </div>

                                  {plan.notes && (
                                    <p className="text-xs text-text-muted mt-0.5 truncate">
                                      {plan.notes}
                                    </p>
                                  )}
                                  {plan.completedDate && (
                                    <p className="text-[11px] text-success mt-0.5 flex items-center gap-1 font-mono">
                                      <CheckCircle2 className="w-3 h-3" /> Completed on {plan.completedDate}
                                    </p>
                                  )}
                                </div>
                              </div>

                              {/* Status Dropdown & Toggle Button */}
                              <div className="flex items-center gap-2 self-end sm:self-center">
                                {/* Status Selector */}
                                <select
                                  value={plan.status}
                                  onChange={(e) => handleChangePlanStatus(plan.id, e.target.value)}
                                  className={`px-2.5 py-1 rounded text-xs font-semibold uppercase tracking-wider border focus:outline-none ${statusStyle.bg}`}
                                >
                                  {Object.entries(PLAN_STATUS_CONFIG).map(([k, v]) => (
                                    <option key={k} value={k}>
                                      {v.label}
                                    </option>
                                  ))}
                                </select>

                                {/* Quick Mark Done Button */}
                                <button
                                  onClick={() => handleTogglePlanStatus(plan.id, plan.status)}
                                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                                    isDone
                                      ? 'bg-success/20 text-success border border-success/40 hover:bg-warning/20 hover:text-warning hover:border-warning/40'
                                      : 'bg-gold text-bg-primary hover:scale-105 active:scale-95 shadow-sm'
                                  }`}
                                  title={isDone ? 'Mark as Pending' : 'Mark as Done / Complete'}
                                >
                                  <Check className="w-3.5 h-3.5" />
                                  <span>{isDone ? 'Completed' : 'Mark Done'}</span>
                                </button>

                                {/* Delete Plan from Owner */}
                                <button
                                  onClick={() => handleDeletePlanFromActiveOwner(plan.id, plan.name)}
                                  className="p-1.5 hover:bg-danger/20 hover:text-danger rounded-lg text-text-muted border border-transparent hover:border-danger/30 transition-colors"
                                  title="Delete Plan from this owner"
                                >
                                  <Trash2 className="w-3.5 h-3.5" />
                                </button>
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>
                )}

                {/* ════ TAB 2: PAYMENTS & BALANCES (SELF-CONTAINED FOR THIS OWNER) ════ */}
                {ownerTab === 'payments' && (
                  <div className="space-y-5">
                    {/* Financial Summary Cards for this Owner */}
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                      <div className="bg-bg-elevated/70 border border-border-strong rounded-xl p-4">
                        <span className="text-[11px] font-bold uppercase tracking-wider text-text-muted block mb-1">
                          Total Plan / Drawings Fees
                        </span>
                        <div className="text-2xl font-bold text-text-primary">
                          {formatCurrency(activeOwner.houseAmount)}
                        </div>
                        <p className="text-[11px] text-text-muted mt-1">
                          Agreed 2D/3D planning & engineering fees
                        </p>
                      </div>

                      <div className="bg-bg-elevated/70 border border-success/30 rounded-xl p-4">
                        <span className="text-[11px] font-bold uppercase tracking-wider text-success block mb-1">
                          Plan Fees Received
                        </span>
                        <div className="text-2xl font-bold text-success">
                          {formatCurrency(activeOwner.totalPaid)}
                        </div>
                        <p className="text-[11px] text-text-muted mt-1">
                          {activeOwner.houseAmount > 0
                            ? `${Math.round(((activeOwner.totalPaid || 0) / activeOwner.houseAmount) * 100)}% of plan fees paid`
                            : 'No fee set'}
                        </p>
                      </div>

                      <div className="bg-bg-elevated/70 border border-warning/30 rounded-xl p-4">
                        <span className="text-[11px] font-bold uppercase tracking-wider text-warning block mb-1">
                          Remaining Pending Balance
                        </span>
                        <div className="text-2xl font-bold text-warning">
                          {formatCurrency(activeOwner.pendingBalance)}
                        </div>
                        <p className="text-[11px] text-text-muted mt-1">
                          Outstanding plan fee for {activeOwner.ownerName}
                        </p>
                      </div>
                    </div>

                    {/* Action Bar for Payments */}
                    <div className="flex flex-wrap items-center justify-between gap-3 bg-bg-elevated/40 border border-border-strong rounded-xl p-3.5">
                      <div className="text-xs text-text-muted">
                        Installments: <span className="font-bold text-text-primary">{(activeOwner.payments || []).length} recorded</span>
                      </div>

                      <div className="flex flex-wrap items-center gap-2">
                        {/* Download Branded PDF Bill */}
                        <button
                          onClick={(e) => handleDownloadPdfBill(e, activeOwner)}
                          disabled={downloadingPdfId === activeOwner.id}
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-bg-card border border-gold/40 hover:border-gold text-gold hover:bg-gold/10 rounded-lg text-xs font-semibold shadow-sm transition-all disabled:opacity-50"
                          title="Generate and download official PDF Bill / Invoice"
                        >
                          <Printer className="w-3.5 h-3.5" />
                          <span>{downloadingPdfId === activeOwner.id ? 'Generating...' : 'Download PDF Bill'}</span>
                        </button>

                        {/* Share PDF Bill to WhatsApp with Thanks Message */}
                        <button
                          onClick={(e) => handleSharePdfToWhatsApp(activeOwner, e)}
                          disabled={sharingPdfId === activeOwner.id}
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-600/15 border border-emerald-500/40 hover:border-emerald-500 text-emerald-400 hover:bg-emerald-600/25 rounded-lg text-xs font-semibold shadow-sm transition-all disabled:opacity-50"
                          title="Share official PDF Bill with Thank You message to client via WhatsApp"
                        >
                          <Share2 className="w-3.5 h-3.5" />
                          <span>{sharingPdfId === activeOwner.id ? 'Preparing...' : 'Share Bill on WhatsApp'}</span>
                        </button>

                        {/* Request Payment via WhatsApp / Message */}
                        <button
                          onClick={handleRequestPayment}
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-600/15 border border-emerald-500/30 hover:border-emerald-500 text-emerald-400 hover:bg-emerald-600/25 rounded-lg text-xs font-semibold shadow-sm transition-all"
                          title="Send or copy payment request reminder to client via WhatsApp"
                        >
                          <Send className="w-3.5 h-3.5" />
                          <span>Request Payment</span>
                        </button>

                        {/* Edit Plan Fee & Details Button */}
                        <button
                          onClick={(e) => openEditOwner(e, activeOwner)}
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-bg-input border border-border-strong hover:border-gold rounded-lg text-xs font-medium text-text-secondary hover:text-gold transition-colors"
                          title="Edit Total Agreed Plan Fee or Customer Details"
                        >
                          <Pencil className="w-3.5 h-3.5" />
                          <span>Edit Plan Fee</span>
                        </button>

                        {/* Primary Record Payment Button */}
                        <button
                          onClick={() => handleOpenAddPayment()}
                          className="flex items-center gap-1.5 px-3.5 py-1.5 bg-gold text-bg-primary rounded-lg text-xs font-bold shadow-sm hover:scale-105 active:scale-95 transition-all"
                          title="Record advance booking, half payment (50%), or milestone installment"
                        >
                          <Plus className="w-4 h-4" />
                          <span>Record Payment</span>
                        </button>
                      </div>
                    </div>

                    {/* Payments History Table */}
                    {(activeOwner.payments || []).length === 0 ? (
                      <div className="text-center py-10 border border-dashed border-border-strong rounded-xl p-8 bg-bg-input/20">
                        <Receipt className="w-10 h-10 text-gold mx-auto mb-2 opacity-60" />
                        <h4 className="text-base font-bold text-text-primary mb-1">
                          No payments recorded yet for {activeOwner.ownerName}
                        </h4>
                        <p className="text-xs text-text-muted max-w-sm mx-auto mb-4">
                          Record advance booking, 50% half payment, or milestone installment for this client.
                        </p>
                        <button
                          onClick={() => handleOpenAddPayment()}
                          className="inline-flex items-center gap-1.5 px-4 py-2 bg-gold text-bg-primary text-xs font-bold rounded-lg shadow-sm hover:scale-105 active:scale-95 transition-all"
                        >
                          <Plus className="w-4 h-4" />
                          <span>Record Payment</span>
                        </button>
                      </div>
                    ) : (
                      <div className="bg-bg-elevated/40 border border-border-strong rounded-xl overflow-hidden">
                        <table className="w-full text-left text-xs text-text-secondary">
                          <thead className="bg-bg-input/80 text-[11px] uppercase tracking-wider text-text-muted border-b border-border">
                            <tr>
                              <th className="py-3 px-4">Installment / Type</th>
                              <th className="py-3 px-4">Date</th>
                              <th className="py-3 px-4">Payment Mode</th>
                              <th className="py-3 px-4">Ref / Notes</th>
                              <th className="py-3 px-4 text-right">Amount Received</th>
                              <th className="py-3 px-4 text-right">Action</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-border">
                            {activeOwner.payments.map((p) => (
                              <tr key={p.id} className="hover:bg-bg-input/40 transition-colors">
                                <td className="py-3 px-4">
                                  <div className="font-semibold text-text-primary">{p.installmentName}</div>
                                  <div className="text-[10px] text-text-muted capitalize">{p.type?.replace('_', ' ')}</div>
                                </td>
                                <td className="py-3 px-4 font-mono text-text-secondary">{p.date}</td>
                                <td className="py-3 px-4">
                                  <span className="px-2 py-0.5 rounded text-[10px] font-medium bg-bg-input border border-border-strong text-text-primary">
                                    {p.mode}
                                  </span>
                                </td>
                                <td className="py-3 px-4">
                                  <div className="text-text-primary font-mono text-[11px]">{p.referenceNo || '-'}</div>
                                  {p.notes && <div className="text-[10px] text-text-muted truncate max-w-xs">{p.notes}</div>}
                                </td>
                                <td className="py-3 px-4 text-right font-bold text-success text-sm">
                                  {formatCurrency(p.amount)}
                                </td>
                                <td className="py-3 px-4 text-right">
                                  <button
                                    onClick={() => handleDeletePayment(p.id, p.amount)}
                                    className="p-1 hover:bg-danger/20 hover:text-danger rounded text-text-muted transition-colors"
                                    title="Delete Payment"
                                  >
                                    <Trash2 className="w-3.5 h-3.5" />
                                  </button>
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>
                )}

                {/* ════ TAB 3: PROJECT SPECS & DETAILS ════ */}
                {ownerTab === 'info' && (
                  <div className="space-y-4">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      {/* Owner Details Card */}
                      <div className="bg-bg-elevated/40 border border-border-strong rounded-xl p-4 space-y-2.5 text-xs">
                        <div className="flex items-center justify-between mb-2">
                          <h4 className="font-bold text-text-primary flex items-center gap-1.5 text-sm">
                            <Home className="w-4 h-4 text-gold" /> Owner & Site Address
                          </h4>
                          <button
                            onClick={(e) => openEditOwner(e, activeOwner)}
                            className="flex items-center gap-1 px-2.5 py-1 bg-gold/15 hover:bg-gold text-gold hover:text-bg-primary border border-gold/30 rounded-lg text-xs font-semibold transition-all"
                            title="Edit Client & Site Details"
                          >
                            <Pencil className="w-3 h-3" />
                            <span>Edit Details</span>
                          </button>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-text-muted">Customer Name:</span>
                          <span className="font-semibold text-text-primary">{activeOwner.ownerName}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-text-muted">Contact Phone:</span>
                          <span className="font-mono text-text-secondary">{activeOwner.ownerPhone || '-'}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-text-muted">Town / City:</span>
                          <span className="text-text-secondary">{activeOwner.city || activeOwner.town || '-'}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-text-muted">Site Location / Address:</span>
                          <span className="text-text-secondary text-right">{activeOwner.ownerAddress || '-'}</span>
                        </div>
                      </div>

                      {/* Structural & Plan Specifications */}
                      <div className="bg-bg-elevated/40 border border-border-strong rounded-xl p-4 space-y-2.5 text-xs">
                        <div className="flex items-center justify-between mb-2">
                          <h4 className="font-bold text-text-primary flex items-center gap-1.5 text-sm">
                            <Compass className="w-4 h-4 text-gold" /> House Architecture & Area
                          </h4>
                          <button
                            onClick={(e) => openEditOwner(e, activeOwner)}
                            className="flex items-center gap-1 px-2.5 py-1 bg-gold/15 hover:bg-gold text-gold hover:text-bg-primary border border-gold/30 rounded-lg text-xs font-semibold transition-all"
                            title="Edit Plan Fee & House Area"
                          >
                            <Pencil className="w-3 h-3" />
                            <span>Edit Fee & Specs</span>
                          </button>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-text-muted">Plan Number:</span>
                          <span className="font-mono text-gold font-semibold">{activeOwner.planNumber}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-text-muted">3D Serial Number:</span>
                          <span className="font-mono text-cyan-400 font-semibold">{activeOwner.serialNumber3D || '-'}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-text-muted">Total House Sq. Ft:</span>
                          <span className="font-semibold text-text-primary">
                            {Number(activeOwner.totalSqFt || 0).toLocaleString('en-IN')} sq.ft
                          </span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-text-muted">Estimated Rate:</span>
                          <span className="text-text-secondary font-mono">
                            {activeOwner.ratePerSqFt ? `₹${activeOwner.ratePerSqFt} / sq.ft` : '-'}
                          </span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-text-muted">Configuration & Facing:</span>
                          <span className="text-text-secondary">
                            {activeOwner.bhk} • {activeOwner.floors} • {activeOwner.facing} Facing
                          </span>
                        </div>
                      </div>
                    </div>

                    {/* Engineer & Technical Notes */}
                    {activeOwner.engineerNotes && (
                      <div className="bg-bg-elevated/40 border border-border-strong rounded-xl p-4 text-xs space-y-1.5">
                        <h4 className="font-bold text-text-primary flex items-center gap-1.5 text-sm">
                          <HardHat className="w-4 h-4 text-gold" /> Engineer's Technical Notes
                        </h4>
                        <p className="text-text-secondary whitespace-pre-wrap leading-relaxed">
                          {activeOwner.engineerNotes}
                        </p>
                      </div>
                    )}
                  </div>
                )}
              </div>

              {/* Workspace Footer */}
              <div className="border-t border-border px-5 py-3.5 bg-bg-elevated/60 flex items-center justify-between shrink-0">
                <span className="text-xs text-text-muted font-mono">
                  Owner ID: {activeOwner.id}
                </span>

                <div className="flex items-center gap-3">
                  <button
                    onClick={() => setActiveOwnerId(null)}
                    className="px-4 py-2 bg-bg-input border border-border-strong rounded-xl text-xs font-semibold text-text-secondary hover:text-text-primary transition-colors"
                  >
                    Close Workspace
                  </button>

                  <button
                    onClick={handleSaveWorkspace}
                    disabled={savingWorkspace}
                    className="flex items-center gap-2 px-5 py-2 bg-emerald-600 hover:bg-emerald-500 active:scale-95 text-white rounded-xl text-xs font-bold shadow-[0_4px_14px_rgba(16,185,129,0.35)] transition-all disabled:opacity-50"
                    title="Save all changes in this workspace to cloud"
                  >
                    <Check className="w-4 h-4" />
                    <span>{savingWorkspace ? 'Saving...' : 'Save Workspace'}</span>
                  </button>
                </div>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>,
      document.body
    )}

      {/* ═══════════════════════════════════════════════════════════════════ */}
      {/* ── ADD / EDIT HOUSE OWNER MODAL ─────────────────────────────────── */}
      {/* ═══════════════════════════════════════════════════════════════════ */}
      <Modal
        isOpen={ownerModalOpen}
        onClose={() => setOwnerModalOpen(false)}
        title={editingOwnerId ? 'Edit House Owner' : 'Add New House Owner (Customer)'}
        confirmText={savingOwner ? 'Saving...' : editingOwnerId ? 'Update Owner' : 'Save Owner'}
        onConfirm={handleSaveOwner}
        zIndex={100000}
        className="max-w-2xl max-h-[90vh] overflow-y-auto"
      >
        <div className="space-y-4 text-xs">
          {/* Section 1: Customer Details */}
          <div className="bg-bg-elevated/40 border border-border-strong rounded-xl p-3.5 space-y-3">
            <h4 className="font-bold uppercase tracking-wider text-gold flex items-center gap-1.5">
              <Home className="w-4 h-4" /> 1. Customer / Owner Information
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <Label className="text-xs">
                  Owner Name (e.g. Tanvir) <span className="text-danger">*</span>
                </Label>
                <Input
                  value={ownerForm.ownerName}
                  onChange={(e) => setOwnerForm({ ...ownerForm, ownerName: e.target.value })}
                  placeholder="e.g. Tanvir Patel"
                  className="mt-1"
                />
              </div>

              <div>
                <div className="flex items-center justify-between">
                  <Label className="text-xs">
                    Mobile Number <span className="text-danger">*</span>
                  </Label>
                  <span className={`text-[10px] font-mono font-bold ${
                    extract10DigitPhone(ownerForm.ownerPhone).length === 10 ? 'text-emerald-400' : 'text-text-muted'
                  }`}>
                    {extract10DigitPhone(ownerForm.ownerPhone).length}/10 digits
                    {extract10DigitPhone(ownerForm.ownerPhone).length === 10 ? ' ✓' : ''}
                  </span>
                </div>
                <div className="flex items-center mt-1">
                  <span className="px-2.5 py-2 bg-bg-elevated border border-r-0 border-border-strong rounded-l-lg text-xs font-semibold text-text-secondary select-none flex items-center gap-1 shrink-0">
                    <span>🇮🇳</span>
                    <span>+91</span>
                  </span>
                  <Input
                    type="tel"
                    value={extract10DigitPhone(ownerForm.ownerPhone)}
                    onChange={(e) => {
                      const raw = e.target.value.replace(/\D/g, '');
                      const cleaned = raw.startsWith('91') && raw.length === 12 ? raw.slice(2) : raw.slice(0, 10);
                      setOwnerForm({ ...ownerForm, ownerPhone: cleaned });
                    }}
                    maxLength={10}
                    placeholder="10-digit mobile (e.g. 9876543210)"
                    className="rounded-l-none font-mono text-xs tracking-wider"
                  />
                </div>
              </div>

              <div>
                <Label className="text-xs">Town / City</Label>
                <Input
                  value={ownerForm.city}
                  onChange={(e) => setOwnerForm({ ...ownerForm, city: e.target.value, town: e.target.value })}
                  placeholder="e.g. Ahmedabad, Surat"
                  className="mt-1"
                />
              </div>

              <div>
                <Label className="text-xs">Site / House Address</Label>
                <Input
                  value={ownerForm.ownerAddress}
                  onChange={(e) => setOwnerForm({ ...ownerForm, ownerAddress: e.target.value })}
                  placeholder="Plot No, Street, Landmark"
                  className="mt-1"
                />
              </div>
            </div>
          </div>

          {/* Section 2: Plan Identifiers & Fees */}
          <div className="bg-bg-elevated/40 border border-border-strong rounded-xl p-3.5 space-y-3">
            <h4 className="font-bold uppercase tracking-wider text-success flex items-center gap-1.5">
              <IndianRupee className="w-4 h-4" /> 2. Plan Fees, Sq. Ft & Serial Numbers
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <Label className="text-xs">
                  Total Plan Fee / Charges (₹) <span className="text-danger">*</span>
                </Label>
                <Input
                  type="number"
                  value={ownerForm.houseAmount}
                  onChange={(e) => handleOwnerAmountOrSqFtChange('houseAmount', e.target.value)}
                  placeholder="e.g. 20000 or 35000"
                  className="mt-1 font-semibold text-success"
                />
                <span className="text-[10px] text-text-muted mt-0.5 block">
                  Agreed 2D/3D design & drawing fee (e.g. ₹20,000 or ₹35,000)
                </span>
              </div>

              <div>
                <Label className="text-xs">
                  House Built-up Area (Sq. Ft.) <span className="text-danger">*</span>
                </Label>
                <Input
                  type="number"
                  value={ownerForm.totalSqFt}
                  onChange={(e) => handleOwnerAmountOrSqFtChange('totalSqFt', e.target.value)}
                  placeholder="e.g. 2000"
                  className="mt-1 font-semibold"
                />
              </div>

              <div>
                <Label className="text-xs">Plan Number</Label>
                <Input
                  value={ownerForm.planNumber}
                  onChange={(e) => setOwnerForm({ ...ownerForm, planNumber: e.target.value })}
                  placeholder="e.g. PLN-2026-001"
                  className="mt-1 font-mono text-gold"
                />
              </div>

              <div>
                <Label className="text-xs">3D Plan Serial Number</Label>
                <Input
                  value={ownerForm.serialNumber3D}
                  onChange={(e) => setOwnerForm({ ...ownerForm, serialNumber3D: e.target.value })}
                  placeholder="e.g. 3D-SER-9402"
                  className="mt-1 font-mono text-cyan-400"
                />
              </div>

              <div>
                <Label className="text-xs">Plot Area (Sq. Ft)</Label>
                <Input
                  type="number"
                  value={ownerForm.plotAreaSqFt}
                  onChange={(e) => setOwnerForm({ ...ownerForm, plotAreaSqFt: e.target.value })}
                  placeholder="e.g. 1800"
                  className="mt-1"
                />
              </div>

              <div>
                <Label className="text-xs">Rate per Sq. Ft. (₹)</Label>
                <Input
                  type="number"
                  value={ownerForm.ratePerSqFt}
                  onChange={(e) => setOwnerForm({ ...ownerForm, ratePerSqFt: e.target.value })}
                  placeholder="Auto calculated"
                  className="mt-1 font-mono"
                />
              </div>
            </div>
          </div>

          {/* Section 3: Advance Payment (Optional on Create) */}
          {!editingOwnerId && (
            <div className="bg-bg-elevated/40 border border-border-strong rounded-xl p-3.5 space-y-3">
              <h4 className="font-bold uppercase tracking-wider text-cyan-400 flex items-center gap-1.5">
                <Receipt className="w-4 h-4" /> 3. Initial Advance Payment (Optional)
              </h4>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <Label className="text-xs">Initial Advance Amount (₹)</Label>
                  <Input
                    type="number"
                    value={ownerForm.initialAdvanceAmount}
                    onChange={(e) => setOwnerForm({ ...ownerForm, initialAdvanceAmount: e.target.value })}
                    placeholder="e.g. 500000"
                    className="mt-1 text-success"
                  />
                </div>
                <div>
                  <Label className="text-xs">Payment Mode</Label>
                  <select
                    value={ownerForm.initialAdvanceMode}
                    onChange={(e) => setOwnerForm({ ...ownerForm, initialAdvanceMode: e.target.value })}
                    className="mt-1 w-full px-3 py-2 bg-bg-input border border-border-strong rounded-lg text-xs text-text-primary focus:outline-none focus:border-gold"
                  >
                    <option value="UPI">UPI / GPay / PhonePe</option>
                    <option value="Cash">Cash</option>
                    <option value="Cheque">Cheque</option>
                    <option value="Bank Transfer">Bank Transfer (NEFT/RTGS)</option>
                  </select>
                </div>
              </div>
            </div>
          )}

          {/* Section 4: Specifications */}
          <div className="bg-bg-elevated/40 border border-border-strong rounded-xl p-3.5 space-y-3">
            <h4 className="font-bold uppercase tracking-wider text-text-primary flex items-center gap-1.5">
              <HardHat className="w-4 h-4 text-gold" /> 4. Engineer & Structure Specifications
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div>
                <Label className="text-xs">Engineer Name (Er.)</Label>
                <Input
                  value={ownerForm.engineerName}
                  onChange={(e) => setOwnerForm({ ...ownerForm, engineerName: e.target.value })}
                  placeholder="e.g. Er. Vikram"
                  className="mt-1 text-gold"
                />
              </div>

              <div>
                <Label className="text-xs">Configuration</Label>
                <select
                  value={ownerForm.bhk}
                  onChange={(e) => setOwnerForm({ ...ownerForm, bhk: e.target.value })}
                  className="mt-1 w-full px-3 py-2 bg-bg-input border border-border-strong rounded-lg text-xs text-text-primary focus:outline-none focus:border-gold"
                >
                  <option value="1 BHK">1 BHK</option>
                  <option value="2 BHK">2 BHK</option>
                  <option value="3 BHK">3 BHK</option>
                  <option value="4 BHK">4 BHK</option>
                  <option value="5+ BHK">5+ BHK</option>
                  <option value="Villa">Villa / Duplex</option>
                </select>
              </div>

              <div>
                <Label className="text-xs">Floors</Label>
                <select
                  value={ownerForm.floors}
                  onChange={(e) => setOwnerForm({ ...ownerForm, floors: e.target.value })}
                  className="mt-1 w-full px-3 py-2 bg-bg-input border border-border-strong rounded-lg text-xs text-text-primary focus:outline-none focus:border-gold"
                >
                  <option value="Ground Only">Ground Only</option>
                  <option value="G+1">G+1</option>
                  <option value="G+2">G+2</option>
                  <option value="G+3">G+3</option>
                  <option value="Duplex">Duplex</option>
                </select>
              </div>

              <div className="sm:col-span-3">
                <Label className="text-xs">Technical Notes & Specifications</Label>
                <textarea
                  rows={2}
                  value={ownerForm.engineerNotes}
                  onChange={(e) => setOwnerForm({ ...ownerForm, engineerNotes: e.target.value })}
                  placeholder="Structural notes, vastu requirements, foundation details..."
                  className="mt-1 w-full px-3 py-2 bg-bg-input border border-border-strong rounded-lg text-xs text-text-primary focus:outline-none focus:border-gold"
                />
              </div>
            </div>
          </div>
        </div>
      </Modal>

      {/* ── WHATSAPP SHARE MODAL ── */}
      <Modal
        isOpen={!!whatsappShareData}
        onClose={() => setWhatsappShareData(null)}
        title="Share Bill & Thanks Message on WhatsApp"
        confirmText="Open in WhatsApp"
        cancelText="Close"
        onConfirm={() => {
          const clean10 = extract10DigitPhone(customSharePhone) || extract10DigitPhone(whatsappShareData?.cleanPhone);
          if (!clean10 || clean10.length !== 10) {
            toast.error(`Please enter exactly 10 digits for mobile number (currently ${clean10 ? clean10.length : 0} digits)`);
            return;
          }
          if (!/^[6-9]\d{9}$/.test(clean10)) {
            toast.error('Mobile number must be a valid 10-digit Indian number starting with 6, 7, 8, or 9');
            return;
          }
          if (whatsappShareData?.owner?.id) {
            updateHousePlan(whatsappShareData.owner.id, { ownerPhone: `+91 ${clean10}` }).catch(() => {});
          }
          const url = `https://api.whatsapp.com/send?phone=91${clean10}&text=${encodeURIComponent(whatsappShareData.thanksMessage)}`;
          window.open(url, '_blank');
        }}
        zIndex={100000}
        className="max-w-xl"
      >
        {whatsappShareData && (
          <div className="space-y-4">
            {/* Header Client Info Card */}
            <div className="flex items-center justify-between p-3.5 bg-emerald-950/30 border border-emerald-500/30 rounded-xl">
              <div className="flex items-center gap-3">
                <div className="p-2.5 bg-emerald-500 text-bg-primary rounded-xl font-bold shrink-0">
                  <Share2 className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="font-bold text-sm text-text-primary">
                    {whatsappShareData.ownerName}
                  </h4>
                  <p className="text-xs text-emerald-400 font-mono mt-0.5">
                    {whatsappShareData.ownerPhone || 'No phone number provided'}
                  </p>
                </div>
              </div>
              <span className="text-[11px] font-bold px-2.5 py-1 bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 rounded-md">
                PDF Generated
              </span>
            </div>

            {/* SEND TO NEW OR UNSAVED NUMBER SECTION */}
            <div className="bg-bg-input/60 border border-border-strong rounded-xl p-3.5 space-y-2">
              <div className="flex items-center justify-between">
                <label className="text-xs font-semibold text-text-muted uppercase">
                  WhatsApp Mobile Number (10 Digits)
                </label>
                <span className={`text-[11px] font-mono font-bold ${
                  extract10DigitPhone(customSharePhone).length === 10 ? 'text-emerald-400' : 'text-amber-400'
                }`}>
                  {extract10DigitPhone(customSharePhone).length}/10 digits
                  {extract10DigitPhone(customSharePhone).length === 10 ? ' ✓' : ''}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <div className="flex items-center flex-1">
                  <span className="px-2.5 py-2 bg-bg-elevated border border-r-0 border-border-strong rounded-l-lg text-xs font-semibold text-text-secondary select-none flex items-center gap-1 shrink-0">
                    <span>🇮🇳</span>
                    <span>+91</span>
                  </span>
                  <Input
                    type="tel"
                    value={extract10DigitPhone(customSharePhone)}
                    onChange={(e) => {
                      const raw = e.target.value.replace(/\D/g, '');
                      const cleaned = raw.startsWith('91') && raw.length === 12 ? raw.slice(2) : raw.slice(0, 10);
                      setCustomSharePhone(cleaned);
                    }}
                    maxLength={10}
                    placeholder="Enter 10-digit mobile (e.g. 9876543210)"
                    className="rounded-l-none font-mono text-sm tracking-wider"
                  />
                </div>
                <button
                  type="button"
                  onClick={() => {
                    const clean10 = extract10DigitPhone(customSharePhone);
                    if (!clean10 || clean10.length !== 10) {
                      toast.error(`Please enter exactly 10 digits (currently ${clean10 ? clean10.length : 0} digits)`);
                      return;
                    }
                    if (!/^[6-9]\d{9}$/.test(clean10)) {
                      toast.error('Mobile number must start with 6, 7, 8, or 9');
                      return;
                    }
                    if (whatsappShareData?.owner?.id) {
                      updateHousePlan(whatsappShareData.owner.id, { ownerPhone: `+91 ${clean10}` }).catch(() => {});
                    }
                    const url = `https://api.whatsapp.com/send?phone=91${clean10}&text=${encodeURIComponent(whatsappShareData.thanksMessage)}`;
                    window.open(url, '_blank');
                  }}
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg text-xs font-bold transition-all shadow-sm shrink-0 flex items-center gap-1.5"
                  title="Open direct chat with this phone number"
                >
                  <Send className="w-3.5 h-3.5" />
                  <span>Send</span>
                </button>
              </div>
              <div className="flex items-center gap-2 text-[11px] pt-0.5">
                <button
                  type="button"
                  onClick={() => {
                    const clean10 = extract10DigitPhone(customSharePhone) || extract10DigitPhone(whatsappShareData.cleanPhone);
                    if (!clean10 || clean10.length !== 10) {
                      toast.error('Please enter a valid 10-digit mobile number first');
                      return;
                    }
                    if (whatsappShareData?.owner?.id) {
                      updateHousePlan(whatsappShareData.owner.id, { ownerPhone: `+91 ${clean10}` }).catch(() => {});
                    }
                    const url = `https://web.whatsapp.com/send?phone=91${clean10}&text=${encodeURIComponent(whatsappShareData.thanksMessage)}`;
                    window.open(url, '_blank');
                  }}
                  className="text-emerald-400 hover:text-emerald-300 hover:underline flex items-center gap-1 font-medium"
                >
                  <ExternalLink className="w-3 h-3" />
                  <span>Open in WhatsApp Web directly</span>
                </button>
                <span className="text-text-muted">•</span>
                <span className="text-text-muted">Chat opens even if not saved in contacts</span>
              </div>
            </div>

            {/* Generated PDF File Badge */}
            <div className="flex items-center justify-between p-2.5 bg-bg-elevated/70 border border-border rounded-lg text-xs">
              <div className="flex items-center gap-2 truncate mr-2 font-mono text-[11px] text-gold">
                <FileText className="w-4 h-4 shrink-0" />
                <span className="truncate">{whatsappShareData.safeFilename}</span>
              </div>
              <button
                type="button"
                onClick={() => whatsappShareData.doc?.save(whatsappShareData.safeFilename)}
                className="text-xs text-gold hover:text-gold/80 hover:underline font-semibold shrink-0"
                title="Download another copy of the PDF"
              >
                Download Again
              </button>
            </div>

            {/* Message Preview Box */}
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="text-xs font-semibold text-text-muted uppercase">
                  Thank You & Bill Summary (WhatsApp Text)
                </label>
                <button
                  type="button"
                  onClick={() => {
                    navigator.clipboard.writeText(whatsappShareData.thanksMessage);
                    toast.success('Message copied to clipboard!');
                  }}
                  className="text-xs text-gold hover:underline flex items-center gap-1 font-medium"
                >
                  <Copy className="w-3 h-3" />
                  <span>Copy Message</span>
                </button>
              </div>
              <div className="bg-bg-input border border-border-strong rounded-xl p-3 text-xs text-text-secondary max-h-40 overflow-y-auto whitespace-pre-wrap font-sans leading-relaxed select-all">
                {whatsappShareData.thanksMessage}
              </div>
            </div>

            <p className="text-[11px] text-text-muted leading-tight">
              💡 <span className="font-semibold text-text-secondary">Instructions:</span> WhatsApp opens directly in chat with the pre-filled thank you message. Attach the downloaded PDF bill (<span className="text-gold font-mono">{whatsappShareData.safeFilename}</span>) before pressing send!
            </p>
          </div>
        )}
      </Modal>

      {/* ═══════════════════════════════════════════════════════════════════ */}
      {/* ── MASTER PLAN CATALOG MANAGER (21 STANDARD ENGINEERING TEMPLATES) ─ */}
      {/* ═══════════════════════════════════════════════════════════════════ */}
      <Modal
        isOpen={catalogModalOpen}
        onClose={() => setCatalogModalOpen(false)}
        title={`Master Plan Catalog (${localCatalog.length} Engineering Templates)`}
        confirmText={savingCatalog ? 'Saving...' : 'Save Catalog Templates'}
        onConfirm={handleSaveCatalog}
        zIndex={100000}
        className="max-w-2xl max-h-[90vh] overflow-y-auto"
      >
        <div className="space-y-4 text-xs">
          {/* Add New Plan Template to Catalog */}
          <div className="flex flex-col sm:flex-row gap-2 items-stretch sm:items-center bg-bg-elevated/50 p-3 rounded-xl border border-border-strong">
            <input
              type="text"
              value={newCatalogItemName}
              onChange={(e) => setNewCatalogItemName(e.target.value)}
              placeholder="e.g. 22 - BOUNDARY WALL DETAILS, Landscaping..."
              className="flex-1 px-3 py-2 bg-bg-input border border-border-strong rounded-lg text-xs text-text-primary focus:outline-none focus:border-gold"
            />
            <select
              value={newCatalogCategory}
              onChange={(e) => setNewCatalogCategory(e.target.value)}
              className="px-3 py-2 bg-bg-input border border-border-strong rounded-lg text-xs text-text-secondary focus:outline-none focus:border-gold"
            >
              <option value="Structural">Structural</option>
              <option value="Architectural">Architectural</option>
              <option value="3D & Design">3D & Design</option>
              <option value="Services">Services (Plumbing/Electric)</option>
              <option value="Municipal">Municipal / Approval</option>
            </select>
            <button
              type="button"
              onClick={handleAddCatalogItem}
              className="px-3 py-2 bg-gold text-bg-primary font-bold rounded-lg text-xs hover:scale-105 active:scale-95"
            >
              + Add Template
            </button>
          </div>

          {/* Templates List */}
          <div className="border border-border-strong rounded-xl divide-y divide-border overflow-hidden max-h-80 overflow-y-auto">
            {localCatalog.map((item, idx) => {
              const numDisplay = item.num || String(idx + 1).padStart(2, '0');
              const cleanDisplayName = item.mainName || extractPureMainName(item.name);

              return (
                <div key={item.id || idx} className="p-3 flex items-center justify-between gap-3 bg-bg-input/30 hover:bg-bg-input/60 transition-colors">
                  <div className="flex items-center gap-2.5 min-w-0">
                    <div className="min-w-0">
                      <span className="font-semibold text-text-primary text-xs">
                        {numDisplay}-{cleanDisplayName}
                      </span>
                      <span className="ml-2 text-[10px] px-2 py-0.5 rounded bg-bg-elevated border border-border-strong text-text-muted">
                        {item.category}
                      </span>
                    </div>
                  </div>

                  <button
                    type="button"
                    onClick={() => handleDeleteCatalogItem(item.id)}
                    className="p-1 hover:bg-danger/20 hover:text-danger rounded text-text-muted transition-colors"
                    title="Remove from Catalog"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              );
            })}
          </div>

          <div className="flex justify-between items-center pt-2">
            <span className="text-[11px] text-text-muted">
              Total {localCatalog.length} engineering drawing templates configured
            </span>
            <button
              type="button"
              onClick={handleResetCatalogToDefaults}
              className="text-[11px] text-text-muted hover:text-gold flex items-center gap-1 underline"
            >
              <RotateCcw className="w-3 h-3" /> Reset to standard {DEFAULT_MASTER_PLANS.length} templates
            </button>
          </div>
        </div>
      </Modal>

      {/* ═══════════════════════════════════════════════════════════════════ */}
      {/* ── ADD PLAN TO OWNER MODAL (FROM CATALOG OR CUSTOM) ─────────────── */}
      {/* ═══════════════════════════════════════════════════════════════════ */}
      <Modal
        isOpen={addPlanModalOpen}
        onClose={() => setAddPlanModalOpen(false)}
        title={`Add Plan to ${activeOwner?.ownerName || 'Owner'}`}
        confirmText="Add Plan"
        onConfirm={handleAddPlanToActiveOwner}
        zIndex={100000}
        className="max-w-lg"
      >
        <div className="space-y-4 text-xs">
          <div>
            <Label className="text-xs">
              Select from Master Catalog ({masterCatalog.length} Templates)
            </Label>
            <select
              value={selectedCatalogPlanId}
              onChange={(e) => {
                const val = e.target.value;
                setSelectedCatalogPlanId(val);
                if (val) {
                  const match = masterCatalog.find((p) => p.id === val);
                  if (match) {
                    setCustomPlanName(match.name);
                    setPlanCategory(match.category);
                  }
                }
              }}
              className="mt-1 w-full px-3 py-2.5 bg-bg-input border border-border-strong rounded-lg text-xs text-text-primary focus:outline-none focus:border-gold"
            >
              <option value="">-- Choose from Master Catalog ({masterCatalog.length} Plans) --</option>
              {masterCatalog.map((plan) => (
                <option key={plan.id} value={plan.id}>
                  {plan.num ? `${plan.num}-` : ''}{plan.mainName || extractPureMainName(plan.name)} ({plan.category})
                </option>
              ))}
            </select>
          </div>

          <div className="flex items-center gap-2 my-1">
            <div className="h-px bg-border flex-1" />
            <span className="text-[10px] text-text-muted uppercase">OR CUSTOM NAME</span>
            <div className="h-px bg-border flex-1" />
          </div>

          <div>
            <Label className="text-xs">Plan Name</Label>
            <Input
              value={customPlanName}
              onChange={(e) => setCustomPlanName(e.target.value)}
              placeholder="e.g. Typical-1, Typical-2, Center Line Plan..."
              className="mt-1"
            />
          </div>

          <div>
            <Label className="text-xs">Category</Label>
            <select
              value={planCategory}
              onChange={(e) => setPlanCategory(e.target.value)}
              className="mt-1 w-full px-3 py-2 bg-bg-input border border-border-strong rounded-lg text-xs text-text-primary focus:outline-none focus:border-gold"
            >
              <option value="Structural">Structural</option>
              <option value="Architectural">Architectural</option>
              <option value="3D & Design">3D & Design</option>
              <option value="Services">Services (Plumbing/Electrical)</option>
              <option value="Municipal">Municipal / Approval</option>
            </select>
          </div>

          <div>
            <Label className="text-xs">Specific Notes / Revision</Label>
            <Input
              value={planNotes}
              onChange={(e) => setPlanNotes(e.target.value)}
              placeholder="e.g. Column sizes updated as per site soil test"
              className="mt-1"
            />
          </div>

          <div>
            <Label className="text-xs">Drawing File / 3D Asset Link (Optional)</Label>
            <Input
              value={planFileUrl}
              onChange={(e) => setPlanFileUrl(e.target.value)}
              placeholder="https://... cloud drawing or PDF link"
              className="mt-1"
            />
          </div>
        </div>
      </Modal>

      {/* ═══════════════════════════════════════════════════════════════════ */}
      {/* ── ADD PAYMENT INSTALLMENT MODAL (DEDICATED TO THIS OWNER) ──────── */}
      {/* ═══════════════════════════════════════════════════════════════════ */}
      <Modal
        isOpen={addPaymentModalOpen}
        onClose={() => setAddPaymentModalOpen(false)}
        title={`Record Plan Fee Payment for ${activeOwner?.ownerName || 'Client'}`}
        confirmText="Record Payment"
        onConfirm={handleAddPayment}
        zIndex={100000}
        className="max-w-lg"
      >
        <div className="space-y-4 text-xs">
          {activeOwner && (
            <div className="p-3 bg-bg-input/60 border border-border-strong rounded-xl flex items-center justify-between">
              <div>
                <span className="text-[10px] text-text-muted uppercase">Pending Balance</span>
                <div className="text-base font-bold text-warning">
                  {formatCurrency(activeOwner.pendingBalance)}
                </div>
              </div>
              <div className="text-right">
                <span className="text-[10px] text-text-muted uppercase">Total Plan Fee</span>
                <div className="text-sm font-semibold text-text-primary">
                  {formatCurrency(activeOwner.houseAmount)}
                </div>
              </div>
            </div>
          )}

          {/* 1-Click Quick Amount Fillers */}
          {activeOwner && (
            <div className="space-y-1.5">
              <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider block">
                Quick 1-Click Amount Fill:
              </span>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => {
                    const half = Math.round((Number(activeOwner.houseAmount) || 0) / 2);
                    setPaymentForm({
                      ...paymentForm,
                      type: 'half_payment',
                      installmentName: 'Half Payment (50% Plan Fee)',
                      amount: String(half),
                    });
                  }}
                  className={`px-2.5 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                    paymentForm.type === 'half_payment'
                      ? 'bg-gold text-bg-primary border-gold shadow-sm'
                      : 'bg-bg-input border-border-strong hover:border-gold text-text-secondary hover:text-gold'
                  }`}
                >
                  ⚡ 50% Half ({formatCurrency(Math.round((Number(activeOwner.houseAmount) || 0) / 2))})
                </button>

                <button
                  type="button"
                  onClick={() => {
                    const pending = Number(activeOwner.pendingBalance) || 0;
                    setPaymentForm({
                      ...paymentForm,
                      type: 'final',
                      installmentName: (activeOwner.payments || []).length === 0 ? 'Full Payment (100% Cleared)' : 'Final Balance Settlement',
                      amount: String(pending),
                    });
                  }}
                  className={`px-2.5 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                    paymentForm.type === 'final'
                      ? 'bg-emerald-600 text-white border-emerald-500 shadow-sm'
                      : 'bg-bg-input border-border-strong hover:border-emerald-500 text-text-secondary hover:text-emerald-400'
                  }`}
                >
                  ✓ Full Remaining ({formatCurrency(activeOwner.pendingBalance)})
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setPaymentForm({
                      ...paymentForm,
                      type: 'advance',
                      installmentName: '1st Advance Booking',
                      amount: paymentForm.amount || '5000',
                    });
                  }}
                  className={`px-2.5 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                    paymentForm.type === 'advance'
                      ? 'bg-cyan-600 text-white border-cyan-500 shadow-sm'
                      : 'bg-bg-input border-border-strong hover:border-cyan-500 text-text-secondary hover:text-cyan-400'
                  }`}
                >
                  ★ Advance Booking
                </button>

                <button
                  type="button"
                  onClick={() => {
                    const nextNum = (activeOwner.payments || []).length + 1;
                    setPaymentForm({
                      ...paymentForm,
                      type: 'part',
                      installmentName: `Installment ${nextNum}`,
                    });
                  }}
                  className={`px-2.5 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                    paymentForm.type === 'part'
                      ? 'bg-bg-elevated text-gold border-gold'
                      : 'bg-bg-input border-border-strong hover:border-border text-text-secondary'
                  }`}
                >
                  ✎ Custom Part
                </button>
              </div>
            </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <Label className="text-xs">
                Installment Type <span className="text-danger">*</span>
              </Label>
              <select
                value={paymentForm.type}
                onChange={(e) => {
                  const type = e.target.value;
                  let installmentName = 'Part Payment';
                  let amount = paymentForm.amount;
                  if (type === 'half_payment') {
                    installmentName = 'Half Payment (50%)';
                    if (activeOwner) amount = String(Math.round((activeOwner.houseAmount || 0) / 2));
                  } else if (type === 'advance') {
                    installmentName = 'Advance Booking Payment';
                  } else if (type === 'final') {
                    installmentName = 'Final Settlement';
                    if (activeOwner) amount = String(activeOwner.pendingBalance || 0);
                  }
                  setPaymentForm({ ...paymentForm, type, installmentName, amount });
                }}
                className="mt-1 w-full px-3 py-2 bg-bg-input border border-border-strong rounded-lg text-xs text-text-primary focus:outline-none focus:border-gold"
              >
                <option value="half_payment">Half Payment (Part 1 - 50%)</option>
                <option value="advance">Advance Booking</option>
                <option value="part">Part 2 / Milestone Payment</option>
                <option value="final">Final Settlement</option>
                <option value="custom">Custom Installment</option>
              </select>
            </div>

            <div>
              <Label className="text-xs">Installment Title</Label>
              <Input
                value={paymentForm.installmentName}
                onChange={(e) => setPaymentForm({ ...paymentForm, installmentName: e.target.value })}
                placeholder="e.g. Half Payment on Footing Approval"
                className="mt-1"
              />
            </div>

            <div>
              <Label className="text-xs">
                Amount Received (₹) <span className="text-danger">*</span>
              </Label>
              <Input
                type="number"
                value={paymentForm.amount}
                onChange={(e) => setPaymentForm({ ...paymentForm, amount: e.target.value })}
                placeholder="e.g. 2500000"
                className="mt-1 font-bold text-success text-sm"
              />
            </div>

            <div>
              <Label className="text-xs">Payment Date</Label>
              <Input
                type="date"
                value={paymentForm.date}
                onChange={(e) => setPaymentForm({ ...paymentForm, date: e.target.value })}
                className="mt-1 font-mono"
              />
            </div>

            <div>
              <Label className="text-xs">Payment Mode</Label>
              <select
                value={paymentForm.mode}
                onChange={(e) => setPaymentForm({ ...paymentForm, mode: e.target.value })}
                className="mt-1 w-full px-3 py-2 bg-bg-input border border-border-strong rounded-lg text-xs text-text-primary focus:outline-none focus:border-gold"
              >
                <option value="UPI">UPI / GPay / PhonePe</option>
                <option value="Cash">Cash</option>
                <option value="Bank Transfer">Bank NEFT / RTGS</option>
                <option value="Cheque">Cheque</option>
              </select>
            </div>

            <div>
              <Label className="text-xs">Reference / Transaction ID</Label>
              <Input
                value={paymentForm.referenceNo}
                onChange={(e) => setPaymentForm({ ...paymentForm, referenceNo: e.target.value })}
                placeholder="UTR / Cheque No / Ref"
                className="mt-1 font-mono"
              />
            </div>

            <div className="sm:col-span-2">
              <Label className="text-xs">Notes / Milestone Description</Label>
              <Input
                value={paymentForm.notes}
                onChange={(e) => setPaymentForm({ ...paymentForm, notes: e.target.value })}
                placeholder="e.g. 50% paid on slab cast and Typical-1 approval"
                className="mt-1"
              />
            </div>
          </div>
        </div>
      </Modal>
    </div>
  );
}
