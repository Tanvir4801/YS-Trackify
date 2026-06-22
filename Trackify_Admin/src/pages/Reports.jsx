import { motion, AnimatePresence } from 'framer-motion';
import React, { useMemo, useState } from 'react';
import {
  Calendar, Download, FileText, ClipboardList, TrendingUp, Wallet, Activity,
  Building2, Users, BarChart3, ChevronDown, ChevronUp,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { useSubscriptionStore } from '../store/subscriptionStore';
import { useLabours } from '../hooks/useLabours';
import { useSupervisors } from '../hooks/useSupervisors';
import { useSites } from '../hooks/useSites';
import { useSiteCosts } from '../hooks/useSiteCosts';
import { getAttendanceRange } from '../lib/services/attendance.service';
import { getPayments } from '../lib/services/payments.service';
import { getTempLaboursByDateRange } from '../lib/services/tempLabours.service';
import { exportExcel, formatCurrency, monthBounds } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import StatusBadge from '../components/shared/StatusBadge';
import { useBranding } from '../context/BrandingContext';
import { generatePDF } from '../lib/pdfGenerator';

const MONTHS = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December',
];

const TABS = [
  { id: 'monthly',      label: 'Monthly Salary',   icon: Calendar },
  { id: 'attendance',   label: 'Attendance',       icon: ClipboardList },
  { id: 'overtime',     label: 'Overtime',         icon: TrendingUp },
  { id: 'payment',      label: 'Payments',         icon: Wallet },
  { id: 'productivity', label: 'Productivity',     icon: Activity },
  { id: 'sitewise',     label: 'Site-wise',        icon: Building2 },
  { id: 'sitecosts',    label: 'Site Costs',       icon: Wallet },
  { id: 'labourwise',   label: 'Labour-wise',      icon: Users },
  { id: 'overall',      label: 'Overall',          icon: BarChart3 },
];



function dateRangeBounds(from, to) { return { start: from, end: to }; }

function getPresentDays(recs) {
  return recs.reduce((s, r) => {
    if (r.status === 'absent' || r.status === 'pending') return s;
    const factor = r.shiftFactor !== undefined ? Number(r.shiftFactor) : (r.status === 'present' ? 1.0 : (r.status === 'half' ? 0.5 : 0.0));
    return s + factor;
  }, 0);
}


export default function Reports() {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const isSupervisor = role === 'supervisor';
  const scopeId = useScopeId();
  const { featureFlags } = useSubscriptionStore();
  const { branding } = useBranding();
  const { data: labours = [] } = useLabours({ activeOnly: false });
  const { data: supervisors = [] } = useSupervisors();
  const { data: sites = [] } = useSites(true);
  const { materials, expenses } = useSiteCosts();

  const resolveSiteName = (id) => {
    if (!id || id === '—' || id === 'Unknown') return id;
    const site = sites.find((s) => s.id === id);
    if (site) return site.name;
    const sup = supervisors.find((s) => s.id === id);
    if (sup) return `Supervisor: ${sup.name}`;
    return id;
  };

  const now = new Date();
  const [activeTab, setActiveTab] = useState('monthly');
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [year, setYear] = useState(now.getFullYear());
  const [fromDate, setFromDate] = useState(`${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`);
  const [toDate, setToDate] = useState(`${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()).padStart(2, '0')}`);
  const [labourFilter, setLabourFilter] = useState('all');

  const [report, setReport] = useState([]);
  const [loaded, setLoaded] = useState(false);
  const [running, setRunning] = useState(false);
  const [expandedSite, setExpandedSite] = useState(null);

  const years = Array.from({ length: 5 }, (_, i) => now.getFullYear() - i);

  const labourMap = useMemo(() => {
    const m = new Map();
    labours.forEach((l) => m.set(l.id, l));
    return m;
  }, [labours]);

  const targetLabours = useMemo(
    () => labourFilter === 'all' ? labours : labours.filter((l) => l.id === labourFilter),
    [labours, labourFilter],
  );

  const handleGenerate = async () => {
    setRunning(true);
    try {
      const usesMonthPicker = ['monthly', 'overtime', 'productivity', 'sitewise', 'overall'].includes(activeTab);
      const usesLabourFilter = activeTab === 'labourwise';
      const bounds = usesMonthPicker ? monthBounds(month, year) : dateRangeBounds(fromDate, toDate);

      const labourIdForQuery = usesLabourFilter && labourFilter !== 'all' ? labourFilter : null;

      const [attendance, payments, tempLabours] = await Promise.all([
        getAttendanceRange(scopeId, bounds.start, bounds.end, labourIdForQuery, isSupervisor, isSupervisor ? uid : null),
        activeTab !== 'labourwise' && activeTab !== 'sitewise'
          ? getPayments(scopeId, { startDate: bounds.start, endDate: bounds.end })
          : Promise.resolve([]),
        getTempLaboursByDateRange(scopeId, bounds.start, bounds.end),
      ]);

      const advByLabour = new Map();
      payments.filter((p) => p.type === 'advance').forEach((p) =>
        advByLabour.set(p.labourId, (advByLabour.get(p.labourId) || 0) + (p.amount || 0)),
      );

      if (activeTab === 'monthly') {
        const rows = targetLabours.map((l) => {
          const recs = attendance.filter((r) => r.labourId === l.id);
          const present = getPresentDays(recs);
          const half    = 0; // Deprecated
          const absent  = recs.filter((r) => r.status === 'absent').length;
          const pending = recs.filter((r) => r.status === 'pending').length;
          const otHours = recs.reduce((s, r) => s + (Number(r.overtimeHours) || 0), 0);
          // pending earns ₹0 — excluded from totalDays calculation (same as absent)
          const totalDays = present;

          const avgWageAtTime = recs.length > 0
            ? recs.reduce((s, r) => s + (Number(r.wageAtTime) || Number(l.dailyWage) || 0), 0) / recs.length
            : Number(l.dailyWage) || 0;

          const earnedWage = recs.reduce((s, r) => {
            const factor = r.shiftFactor !== undefined ? Number(r.shiftFactor) : (r.status === 'present' ? 1.0 : (r.status === 'half' ? 0.5 : 0.0));
            const wage = Number(r.wageAtTime) || Number(l.dailyWage) || 0;
            return s + (wage * factor);
          }, 0);

          const gross = earnedWage + otHours * (Number(l.overtimeWagePerHour) || 0);
          const advances = advByLabour.get(l.id) || 0;
          return {
            labourId: l.id, name: l.name, phone: l.phone,
            dailyWage: l.dailyWage, wageAtTime: avgWageAtTime, otRate: l.overtimeWagePerHour,
            present, half, absent, pending, otHours, totalDays, gross, advances, net: gross - advances,
          };
        });
        setReport(rows.sort((a, b) => String(a.name).localeCompare(String(b.name))));

      } else if (activeTab === 'attendance') {
        const totalDaysInRange = Math.round((new Date(bounds.end) - new Date(bounds.start)) / 86400000) + 1;
        const rows = targetLabours.map((l) => {
          const recs = attendance.filter((r) => r.labourId === l.id);
          const present = getPresentDays(recs);
          const half    = 0; // Deprecated
          const absent  = recs.filter((r) => r.status === 'absent').length;
          const pending = recs.filter((r) => r.status === 'pending').length;
          const rate    = totalDaysInRange > 0 ? Math.round((present / totalDaysInRange) * 100) : 0;
          return { labourId: l.id, name: l.name, present, half, absent, pending, rate };
        });
        setReport(rows.sort((a, b) => b.rate - a.rate));

      } else if (activeTab === 'overtime') {
        const rows = targetLabours
          .map((l) => {
            const recs = attendance.filter((r) => r.labourId === l.id);
            const otHours = recs.reduce((s, r) => s + (Number(r.overtimeHours) || 0), 0);
            const otCost  = otHours * (Number(l.overtimeWagePerHour) || 0);
            return { labourId: l.id, name: l.name, otRate: l.overtimeWagePerHour, otHours, otCost };
          })
          .filter((r) => r.otHours > 0)
          .sort((a, b) => b.otHours - a.otHours);
        setReport(rows);

      } else if (activeTab === 'payment') {
        setReport(payments.sort((a, b) => {
          const da = a.date instanceof Date ? a.date : a.date?.toDate?.() || new Date(0);
          const db2 = b.date instanceof Date ? b.date : b.date?.toDate?.() || new Date(0);
          return db2 - da;
        }));

      } else if (activeTab === 'productivity') {
        const totalDays = Math.round((new Date(bounds.end) - new Date(bounds.start)) / 86400000) + 1;
        const rows = targetLabours.map((l) => {
          const recs = attendance.filter((r) => r.labourId === l.id);
          const present = getPresentDays(recs);
          const half    = 0; // Deprecated
          const absent  = recs.filter((r) => r.status === 'absent').length;
          const pending = recs.filter((r) => r.status === 'pending').length;
          const rate    = totalDays > 0 ? Math.round((present / totalDays) * 100) : 0;
          return { labourId: l.id, name: l.name, present, half, absent, pending, rate, totalDays };
        });
        setReport(rows.sort((a, b) => b.rate - a.rate));

      } else if (activeTab === 'sitewise') {
        const bySite = new Map();
        attendance.forEach((r) => {
          const site = r.siteId || r.supervisorId || 'Unknown';
          if (!bySite.has(site)) bySite.set(site, []);
          bySite.get(site).push(r);
        });
        tempLabours.forEach((t) => {
          const site = t.siteId || t.supervisorId || 'Unknown';
          if (!bySite.has(site)) bySite.set(site, []);
          // Push a mock attendance record for aggregation
          bySite.get(site).push({
            status: 'present',
            wageAtTime: t.wage,
            shiftFactor: t.attendanceUnit,
            overtimeHours: 0,
            allowances: {},
            advance: t.paidAmount || 0,
            labourId: t.id
          });
        });
        const rows = Array.from(bySite.entries()).map(([site, recs]) => {
          const present = getPresentDays(recs);
          const half    = 0; // Deprecated
          const absent  = recs.filter((r) => r.status === 'absent').length;
          const pending = recs.filter((r) => r.status === 'pending').length;
          const totalWage = recs.reduce((s, r) => {
            const wage = Number(r.wageAtTime) || Number(labourMap.get(r.labourId)?.dailyWage) || 0;
            const factor = r.shiftFactor !== undefined ? Number(r.shiftFactor) : (r.status === 'present' ? 1.0 : (r.status === 'half' ? 0.5 : 0.0));
            return s + (wage * factor);
            // absent and pending → ₹0 multiplier
            return s;
          }, 0);
          const otHours = recs.reduce((s, r) => s + (Number(r.overtimeHours) || 0), 0);
          const totalAllowance = recs.reduce((s, r) => {
            const al = r.allowances || {};
            return s + (Number(al.petrol) || 0) + (Number(al.lunch) || 0) + (Number(al.breakfast) || 0) + (Number(al.tea) || 0);
          }, 0);
          const totalAdvance = recs.reduce((s, r) => s + (Number(r.advance) || 0), 0);
          const uniqueLabours = [...new Set(recs.map((r) => r.labourId))];
          return {
            siteId: site,
            siteName: resolveSiteName(site),
            present, half, absent, pending,
            totalRecords: recs.length, uniqueLabours: uniqueLabours.length,
            totalWage, otHours, totalAllowance, totalAdvance,
            grandTotal: totalWage + totalAllowance - totalAdvance,
            records: recs,
          };
        });
        setReport(rows.sort((a, b) => b.totalWage - a.totalWage));

      } else if (activeTab === 'sitecosts') {
        const bySite = new Map();
        
        materials.forEach(m => {
          if (m.purchaseDate >= bounds.start && m.purchaseDate <= bounds.end) {
            const site = m.siteId || 'Unknown';
            if (!bySite.has(site)) bySite.set(site, { materials: 0, expenses: 0, tempLabourCost: 0, tempLabourPaid: 0, tempLabourLiability: 0 });
            bySite.get(site).materials += (Number(m.totalAmount) || 0);
          }
        });

        expenses.forEach(e => {
          if (e.date >= bounds.start && e.date <= bounds.end) {
            const site = e.siteId || 'Unknown';
            if (!bySite.has(site)) bySite.set(site, { materials: 0, expenses: 0, tempLabourCost: 0, tempLabourPaid: 0, tempLabourLiability: 0 });
            bySite.get(site).expenses += (Number(e.amount) || 0);
          }
        });

        tempLabours.forEach(t => {
          if (t.date >= bounds.start && t.date <= bounds.end) {
            const site = t.siteId || t.supervisorId || 'Unknown';
            if (!bySite.has(site)) bySite.set(site, { materials: 0, expenses: 0, tempLabourCost: 0, tempLabourPaid: 0, tempLabourLiability: 0 });
            bySite.get(site).tempLabourCost += (Number(t.totalWage) || 0);
            bySite.get(site).tempLabourPaid += (Number(t.paidAmount) || 0);
            bySite.get(site).tempLabourLiability += (Number(t.remainingAmount) || 0);
          }
        });

        const rows = Array.from(bySite.entries()).map(([site, totals]) => ({
          siteId: site,
          siteName: resolveSiteName(site),
          materials: totals.materials,
          expenses: totals.expenses,
          tempLabourCost: totals.tempLabourCost,
          tempLabourPaid: totals.tempLabourPaid,
          tempLabourLiability: totals.tempLabourLiability,
          grandTotal: totals.materials + totals.expenses + totals.tempLabourCost
        })).sort((a,b) => b.grandTotal - a.grandTotal);
        
        setReport(rows);

      } else if (activeTab === 'labourwise') {
        const filteredRecs = labourFilter === 'all' ? attendance : attendance.filter((r) => r.labourId === labourFilter);
        const rows = filteredRecs
          .map((r) => {
            const labour = labourMap.get(r.labourId);
            const wageAtTime = Number(r.wageAtTime) || Number(labour?.dailyWage) || 0;
            // pending earns ₹0 (same as absent) — excluded from wage sum
            const factor = r.shiftFactor !== undefined ? Number(r.shiftFactor) : (r.status === 'present' ? 1.0 : (r.status === 'half' ? 0.5 : 0.0));
            const earned = wageAtTime * factor;
            const al = r.allowances || {};
            const totalAllowance = (Number(al.petrol) || 0) + (Number(al.lunch) || 0) + (Number(al.breakfast) || 0) + (Number(al.tea) || 0);
            const advance = Number(r.advance) || 0;
            return {
              date: r.date,
              labourId: r.labourId,
              labourName: labour?.name || r.labourId,
              status: r.status,
              overtimeHours: Number(r.overtimeHours) || 0,
              remark: r.remark || r.notes || '',
              wageAtTime,
              siteId: r.siteId || r.supervisorId || '—',
              siteName: resolveSiteName(r.siteId || r.supervisorId || '—'),
              earned,
              allowances: al,
              totalAllowance,
              advance,
              grandTotal: earned + totalAllowance - advance,
            };
          })
          .sort((a, b) => b.date.localeCompare(a.date));
        setReport(rows);

      } else if (activeTab === 'overall') {
        const [tempAttendance, overallTempLabours] = await Promise.all([
          getAttendanceRange(scopeId, bounds.start, bounds.end, null, isSupervisor, isSupervisor ? uid : null),
          getTempLaboursByDateRange(scopeId, bounds.start, bounds.end),
        ]);

        const regularRows = labours.filter((l) => l.type !== 'temporary').map((l) => {
          const recs = tempAttendance.filter((r) => r.labourId === l.id);
          const present = getPresentDays(recs);
          const half    = 0; // Deprecated
          const otHours = recs.reduce((s, r) => s + (Number(r.overtimeHours) || 0), 0);
          const earnedWage = recs.reduce((s, r) => {
            const factor = r.shiftFactor !== undefined ? Number(r.shiftFactor) : (r.status === 'present' ? 1.0 : (r.status === 'half' ? 0.5 : 0.0));
            const wage = Number(r.wageAtTime) || Number(l.dailyWage) || 0;
            return s + (wage * factor);
          }, 0);
          const gross = earnedWage + otHours * (Number(l.overtimeWagePerHour) || 0);
          const advances = advByLabour.get(l.id) || 0;
          return { labourId: l.id, name: l.name, type: 'regular', present, half, otHours, gross, advances, net: gross - advances };
        });

        // Consolidate overallTempLabours by name to show summary
        const tempSummaryMap = new Map();
        overallTempLabours.forEach(t => {
          if (!tempSummaryMap.has(t.name)) {
            tempSummaryMap.set(t.name, { labourId: t.id, name: t.name, type: 'temporary', present: 0, half: 0, otHours: 0, gross: 0, advances: 0, net: 0 });
          }
          const row = tempSummaryMap.get(t.name);
          row.present += (t.attendanceUnit || 0);
          const earnings = t.totalWage || (t.wage * t.attendanceUnit);
          const paid = t.paidAmount || 0;
          row.gross += earnings;
          row.advances += paid; // map paid amount to advances column for consistency
          row.net += (earnings - paid);
        });
        const tempRows = Array.from(tempSummaryMap.values());

        const allRows = [...regularRows, ...tempRows].filter((r) => r.present > 0);
        setReport(allRows.sort((a, b) => b.gross - a.gross));
      }

      setLoaded(true);
      toast.success(`Report ready — ${attendance.length} records`);
    } catch (err) {
      console.error(err);
      toast.error('Failed to generate report: ' + err.message);
    } finally {
      setRunning(false);
    }
  };

  const switchTab = (tab) => { setActiveTab(tab); setReport([]); setLoaded(false); setExpandedSite(null); };

  const totals = useMemo(() => {
    if (activeTab === 'monthly') return report.reduce((acc, r) => ({ gross: acc.gross + r.gross, adv: acc.adv + r.advances, net: acc.net + r.net, ot: acc.ot + r.otHours }), { gross: 0, adv: 0, net: 0, ot: 0 });
    if (activeTab === 'overtime') return report.reduce((acc, r) => ({ ot: acc.ot + r.otHours, cost: acc.cost + r.otCost }), { ot: 0, cost: 0 });
    if (activeTab === 'payment') return report.reduce((acc, p) => ({ total: acc.total + (p.amount || 0) }), { total: 0 });
    if (activeTab === 'sitewise') return report.reduce((acc, r) => ({ wage: acc.wage + r.totalWage, ot: acc.ot + r.otHours, records: acc.records + r.totalRecords, totalAllowance: acc.totalAllowance + (r.totalAllowance || 0), grandTotal: acc.grandTotal + (r.grandTotal || 0) }), { wage: 0, ot: 0, records: 0, totalAllowance: 0, grandTotal: 0 });
    if (activeTab === 'sitecosts') return report.reduce((acc, r) => ({ materials: acc.materials + r.materials, expenses: acc.expenses + r.expenses, grandTotal: acc.grandTotal + r.grandTotal }), { materials: 0, expenses: 0, grandTotal: 0 });
    if (activeTab === 'overall') return report.reduce((acc, r) => ({ gross: acc.gross + r.gross, adv: acc.adv + r.advances, net: acc.net + r.net }), { gross: 0, adv: 0, net: 0 });
    if (activeTab === 'labourwise') return report.reduce((acc, r) => ({ earned: acc.earned + r.earned, ot: acc.ot + r.overtimeHours, totalAllowance: acc.totalAllowance + (r.totalAllowance || 0), grandTotal: acc.grandTotal + (r.grandTotal || 0) }), { earned: 0, ot: 0, totalAllowance: 0, grandTotal: 0 });
    return {};
  }, [report, activeTab]);

  const handleExport = () => {
    if (report.length === 0) return toast.error('Generate report first');
    const monthName = MONTHS[month - 1];
    let filename = `report-${activeTab}`;
    let rows = [];

    if (activeTab === 'monthly') {
      filename = `Salary_${monthName}_${year}.csv`;
      rows = report.map((r) => ({ Name: r.name, Phone: r.phone, 'Daily Wage': r.dailyWage, 'Wage At Time': r.wageAtTime?.toFixed(2), 'OT Rate': r.otRate, 'Days Present': r.present, Absent: r.absent, 'OT Hours': r.otHours, Gross: Math.round(r.gross), Advances: Math.round(r.advances), Net: Math.round(r.net) }));
    } else if (activeTab === 'attendance') {
      filename = `Attendance_${fromDate}_to_${toDate}.csv`;
      rows = report.map((r) => ({ Name: r.name, 'Days Present': r.present, Absent: r.absent, 'Attendance %': `${r.rate}%` }));
    } else if (activeTab === 'overtime') {
      filename = `Overtime_${monthName}_${year}.csv`;
      rows = report.map((r) => ({ Name: r.name, 'OT Rate/hr': r.otRate, 'Total OT Hours': r.otHours, 'OT Cost': Math.round(r.otCost) }));
    } else if (activeTab === 'payment') {
      filename = `Payments_${fromDate}_to_${toDate}.csv`;
      rows = report.map((p) => ({ Date: p.date instanceof Date ? p.date.toLocaleDateString('en-IN') : '', Labour: labourMap.get(p.labourId)?.name || p.labourId, Type: p.type, Method: p.paymentMethod || 'cash', Amount: p.amount, Notes: p.notes }));
    } else if (activeTab === 'productivity') {
      filename = `Productivity_${monthName}_${year}.csv`;
      rows = report.map((r) => ({ Name: r.name, 'Days Present': r.present, Absent: r.absent, 'Attendance %': `${r.rate}%`, 'Total Days': r.totalDays }));
    } else if (activeTab === 'sitewise') {
      filename = `SiteWise_${monthName}_${year}.csv`;
      rows = report.map((r) => ({ Site: r.siteName, 'Days Present': r.present, Absent: r.absent, 'Unique Labours': r.uniqueLabours, 'Total Wage': Math.round(r.totalWage), 'OT Hours': r.otHours, 'Total Allowance': Math.round(r.totalAllowance || 0), 'Total Advance': Math.round(r.totalAdvance || 0), 'Grand Total': Math.round(r.grandTotal || 0) }));
    } else if (activeTab === 'sitecosts') {
      filename = `SiteCosts_${monthName}_${year}.csv`;
      rows = report.map((r) => ({ Site: r.siteName, 'Material Costs': Math.round(r.materials), 'Other Expenses': Math.round(r.expenses), 'Total Cost': Math.round(r.grandTotal) }));
    } else if (activeTab === 'labourwise') {
      filename = `LabourWise_${fromDate}_to_${toDate}.csv`;
      rows = report.map((r) => ({ Date: r.date, Labour: r.labourName, Status: r.status, 'OT Hours': r.overtimeHours, Remark: r.remark, 'Wage At Time': r.wageAtTime, Site: r.siteName, Earned: Math.round(r.earned), 'Petrol': Math.round(r.allowances?.petrol || 0), 'Lunch': Math.round(r.allowances?.lunch || 0), 'Breakfast': Math.round(r.allowances?.breakfast || 0), 'Tea': Math.round(r.allowances?.tea || 0), 'Total Allowance': Math.round(r.totalAllowance || 0), 'Advance': Math.round(r.advance || 0), 'Grand Total': Math.round(r.grandTotal || 0) }));
    } else if (activeTab === 'overall') {
      filename = `Overall_${monthName}_${year}.csv`;
      rows = report.map((r) => ({ Name: r.name, Type: r.type, 'Days Present': r.present, 'OT Hours': r.otHours, Gross: Math.round(r.gross), Advances: Math.round(r.advances), Net: Math.round(r.net) }));
    }
    exportExcel(filename, rows);
    toast.success('Excel downloaded');
  };

  const handleExportPDF = async () => {
    if (report.length === 0) return toast.error('Generate report first');
    const monthName = MONTHS[month - 1];
    let title = '';
    let subtitle = usesMonthPicker ? `For ${monthName} ${year}` : `From ${fromDate} to ${toDate}`;
    let filename = `report-${activeTab}.pdf`;
    let columns = [];
    let pdfRows = [];
    let pdfTotals = null;

    if (activeTab === 'monthly') {
      title = 'Monthly Salary Report';
      filename = `Salary_${monthName}_${year}.pdf`;
      columns = ['Name', 'Phone', 'Daily Wage', 'Days', 'Absent', 'OT Hrs', 'Gross', 'Advances', 'Net'];
      pdfRows = report.map((r) => [r.name, r.phone, formatCurrency(r.dailyWage), r.present, r.absent, r.otHours, formatCurrency(r.gross), formatCurrency(r.advances), formatCurrency(r.net)]);
      pdfTotals = { 'Total Gross': formatCurrency(totals.gross), 'Total Advances': formatCurrency(totals.adv), 'Net Payable': formatCurrency(totals.net) };
    } else if (activeTab === 'attendance') {
      title = 'Attendance Report';
      filename = `Attendance_${fromDate}_to_${toDate}.pdf`;
      columns = ['Name', 'Days', 'Absent', 'Attendance %'];
      pdfRows = report.map((r) => [r.name, r.present, r.absent, `${r.rate}%`]);
    } else if (activeTab === 'overtime') {
      title = 'Overtime Report';
      filename = `Overtime_${monthName}_${year}.pdf`;
      columns = ['Name', 'OT Rate/hr', 'Total OT Hours', 'OT Cost'];
      pdfRows = report.map((r) => [r.name, r.otRate ? formatCurrency(r.otRate) : '-', r.otHours, formatCurrency(r.otCost)]);
      pdfTotals = { 'Total OT Hours': totals.ot, 'Total OT Cost': formatCurrency(totals.cost) };
    } else if (activeTab === 'payment') {
      title = 'Payments Report';
      filename = `Payments_${fromDate}_to_${toDate}.pdf`;
      columns = ['Date', 'Labour', 'Type', 'Method', 'Amount'];
      pdfRows = report.map((p) => [p.date instanceof Date ? p.date.toLocaleDateString('en-IN') : '', labourMap.get(p.labourId)?.name || p.labourId, p.type, p.paymentMethod || 'cash', formatCurrency(p.amount)]);
      pdfTotals = { 'Total Paid': formatCurrency(totals.total) };
    } else if (activeTab === 'productivity') {
      title = 'Productivity Report';
      filename = `Productivity_${monthName}_${year}.pdf`;
      columns = ['Name', 'Days', 'Absent', 'Attendance %'];
      pdfRows = report.map((r) => [r.name, r.present, r.absent, `${r.rate}%`]);
    } else if (activeTab === 'sitewise') {
      title = 'Site-wise Report';
      filename = `SiteWise_${monthName}_${year}.pdf`;
      columns = ['Site', 'Days', 'Absent', 'Unique Labours', 'OT Hrs', 'Grand Total'];
      pdfRows = report.map((r) => [r.siteName, r.present, r.absent, r.uniqueLabours, r.otHours, formatCurrency(r.grandTotal || 0)]);
      pdfTotals = { 'Total Wage': formatCurrency(totals.wage), 'Grand Total': formatCurrency(totals.grandTotal) };
    } else if (activeTab === 'sitecosts') {
      title = 'Site Costs Report';
      filename = `SiteCosts_${monthName}_${year}.pdf`;
      columns = ['Site', 'Material Costs', 'Other Expenses', 'Total Cost'];
      pdfRows = report.map((r) => [r.siteName, formatCurrency(r.materials), formatCurrency(r.expenses), formatCurrency(r.grandTotal)]);
      pdfTotals = { 'Total Materials': formatCurrency(totals.materials), 'Total Expenses': formatCurrency(totals.expenses), 'Grand Total': formatCurrency(totals.grandTotal) };
    } else if (activeTab === 'labourwise') {
      title = 'Labour-wise Report';
      filename = `LabourWise_${fromDate}_to_${toDate}.pdf`;
      columns = ['Date', 'Labour', 'Status', 'Site', 'Earned', 'Grand Total'];
      pdfRows = report.map((r) => [r.date, r.labourName, r.status, r.siteName, formatCurrency(r.earned), formatCurrency(r.grandTotal || 0)]);
      pdfTotals = { 'Total Earned': formatCurrency(totals.earned), 'Grand Total': formatCurrency(totals.grandTotal) };
    } else if (activeTab === 'overall') {
      title = 'Overall Report';
      filename = `Overall_${monthName}_${year}.pdf`;
      columns = ['Name', 'Type', 'Days', 'OT Hrs', 'Gross', 'Net'];
      pdfRows = report.map((r) => [r.name, r.type, r.present, r.otHours, formatCurrency(r.gross), formatCurrency(r.net)]);
      pdfTotals = { 'Total Gross': formatCurrency(totals.gross), 'Net Payable': formatCurrency(totals.net) };
    }

    try {
      toast.loading('Generating PDF...', { id: 'pdf-gen' });
      await generatePDF({
        title,
        subtitle,
        filename,
        columns,
        rows: pdfRows,
        totals: pdfTotals,
        branding,
      });
      toast.success('PDF downloaded', { id: 'pdf-gen' });
    } catch (e) {
      toast.error('Failed to generate PDF', { id: 'pdf-gen' });
    }
  };

  const usesMonthPicker = ['monthly', 'overtime', 'productivity', 'sitewise', 'overall'].includes(activeTab);
  const usesDateRange   = ['attendance', 'payment', 'labourwise'].includes(activeTab);

  return (
    <div className="space-y-6">

      <div className="flex flex-wrap gap-2 rounded-xl border border-border bg-bg-card p-1 shadow-sm overflow-x-auto">
        {TABS.map((t) => (
          <button
            key={t.id}
            onClick={() => switchTab(t.id)}
            className={`flex items-center gap-2 rounded-lg px-4 py-2.5 text-[12px] font-semibold uppercase tracking-widest transition-colors whitespace-nowrap ${
              activeTab === t.id ? 'bg-bg-elevated text-gold shadow' : 'text-text-muted hover:bg-bg-input hover:text-text-primary'
            }`}
          >
            <t.icon className="h-4 w-4" />
            {t.label}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap items-end gap-4 rounded-xl border border-border bg-bg-card px-6 py-5 shadow-sm">
        {usesMonthPicker ? (
          <>
            <div className="space-y-1.5 flex flex-col">
              <Label>Month</Label>
              <select value={month} onChange={(e) => setMonth(Number(e.target.value))} className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary shadow-sm outline-none focus:border-gold focus:ring-1 focus:ring-gold">
                {MONTHS.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
              </select>
            </div>
            <div className="space-y-1.5 flex flex-col">
              <Label>Year</Label>
              <select value={year} onChange={(e) => setYear(Number(e.target.value))} className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary shadow-sm outline-none focus:border-gold focus:ring-1 focus:ring-gold">
                {years.map((y) => <option key={y} value={y}>{y}</option>)}
              </select>
            </div>
          </>
        ) : (
          <>
            <div className="space-y-1.5 flex flex-col">
              <Label>From</Label>
              <Input type="date" value={fromDate} onChange={(e) => setFromDate(e.target.value)} className="h-9 w-40" />
            </div>
            <div className="space-y-1.5 flex flex-col">
              <Label>To</Label>
              <Input type="date" value={toDate} onChange={(e) => setToDate(e.target.value)} className="h-9 w-40" />
            </div>
          </>
        )}
        <div className="space-y-1.5 flex flex-col">
          <Label>Labour</Label>
          <select value={labourFilter} onChange={(e) => setLabourFilter(e.target.value)} className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary shadow-sm outline-none focus:border-gold focus:ring-1 focus:ring-gold">
            <option value="all">All labours</option>
            {labours.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
          </select>
        </div>
        <button onClick={handleGenerate} disabled={running} className="flex h-9 items-center gap-2 rounded-lg bg-info px-5 text-[13px] font-semibold text-white shadow-[0_0_15px_rgba(37,99,235,0.2)] hover:scale-105 transition-all disabled:opacity-50 disabled:hover:scale-100">
          <FileText className="h-4 w-4" /> {running ? 'Generating…' : 'Generate'}
        </button>
        <button onClick={() => featureFlags?.excel_reports === false ? toast.error('Excel Export is not available on Free plan') : handleExport()} disabled={report.length === 0 || featureFlags?.excel_reports === false} className="flex h-9 items-center gap-2 rounded-lg border border-border-strong bg-bg-elevated px-4 text-[13px] font-medium text-text-secondary hover:text-text-primary hover:border-gold transition-colors disabled:opacity-50 disabled:pointer-events-none">
          <Download className="h-4 w-4" /> CSV
        </button>
        <button onClick={() => featureFlags?.pdf_reports === false ? toast.error('PDF Export is not available on Free plan') : handleExportPDF()} disabled={report.length === 0 || featureFlags?.pdf_reports === false} className="flex h-9 items-center gap-2 rounded-lg border border-border-strong bg-bg-elevated px-4 text-[13px] font-medium text-text-secondary hover:text-text-primary hover:border-gold transition-colors disabled:opacity-50 disabled:pointer-events-none">
          <FileText className="h-4 w-4" /> PDF
        </button>
      </div>

      {loaded && activeTab === 'monthly' && (
        <div className="grid gap-4 sm:grid-cols-4">
          {[{ label: 'Gross', value: formatCurrency(totals.gross), color: 'text-text-primary' }, { label: 'Advances', value: formatCurrency(totals.adv), color: 'text-danger' }, { label: 'Net Payable', value: formatCurrency(totals.net), color: 'text-gold' }, { label: 'OT Hours', value: totals.ot, color: 'text-info' }].map((s) => (
            <div key={s.label} className="rounded-xl border border-border bg-bg-card p-5 shadow-sm">
              <p className="text-[11px] font-semibold uppercase tracking-widest text-text-muted">{s.label}</p>
              <p className={`mt-2 text-[20px] font-mono font-bold tracking-tight ${s.color}`}>{s.value}</p>
            </div>
          ))}
        </div>
      )}

      {loaded && activeTab === 'overtime' && (
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="rounded-xl border border-border bg-bg-card p-5 shadow-sm">
            <p className="text-[11px] font-semibold uppercase tracking-widest text-text-muted">Total OT Hours</p>
            <p className="mt-2 text-[20px] font-mono font-bold tracking-tight text-info">{totals.ot}</p>
          </div>
          <div className="rounded-xl border border-border bg-bg-card p-5 shadow-sm">
            <p className="text-[11px] font-semibold uppercase tracking-widest text-text-muted">Total OT Cost</p>
            <p className="mt-2 text-[20px] font-mono font-bold tracking-tight text-gold">{formatCurrency(totals.cost)}</p>
          </div>
        </div>
      )}

      {loaded && activeTab === 'payment' && (
        <div className="rounded-xl border border-border bg-bg-card p-5 shadow-sm">
          <p className="text-[11px] font-semibold uppercase tracking-widest text-text-muted">Total Payments</p>
          <p className="mt-2 text-[20px] font-mono font-bold tracking-tight text-success">{formatCurrency(totals.total)}</p>
        </div>
      )}

      {loaded && activeTab === 'sitewise' && (
        <div className="grid gap-4 sm:grid-cols-3">
          {[{ label: 'Total Wage', value: formatCurrency(totals.wage), color: 'text-gold' }, { label: 'OT Hours', value: totals.ot, color: 'text-info' }, { label: 'Total Records', value: totals.records, color: 'text-text-primary' }].map((s) => (
            <div key={s.label} className="rounded-xl border border-border bg-bg-card p-5 shadow-sm">
              <p className="text-[11px] font-semibold uppercase tracking-widest text-text-muted">{s.label}</p>
              <p className={`mt-2 text-[20px] font-mono font-bold tracking-tight ${s.color}`}>{s.value}</p>
            </div>
          ))}
        </div>
      )}

      {loaded && activeTab === 'overall' && (
        <div className="grid gap-4 sm:grid-cols-3">
          {[{ label: 'Grand Total Gross', value: formatCurrency(totals.gross), color: 'text-text-primary' }, { label: 'Total Advances', value: formatCurrency(totals.adv), color: 'text-danger' }, { label: 'Net Payable', value: formatCurrency(totals.net), color: 'text-gold' }].map((s) => (
            <div key={s.label} className="rounded-xl border border-border bg-bg-card p-5 shadow-sm">
              <p className="text-[11px] font-semibold uppercase tracking-widest text-text-muted">{s.label}</p>
              <p className={`mt-2 text-[20px] font-mono font-bold tracking-tight ${s.color}`}>{s.value}</p>
            </div>
          ))}
        </div>
      )}

      {loaded && activeTab === 'labourwise' && (
        <div className="grid gap-4 sm:grid-cols-2">
          {[{ label: 'Total Earned', value: formatCurrency(totals.earned), color: 'text-gold' }, { label: 'Total OT Hours', value: totals.ot, color: 'text-info' }].map((s) => (
            <div key={s.label} className="rounded-xl border border-border bg-bg-card p-5 shadow-sm">
              <p className="text-[11px] font-semibold uppercase tracking-widest text-text-muted">{s.label}</p>
              <p className={`mt-2 text-[20px] font-mono font-bold tracking-tight ${s.color}`}>{s.value}</p>
            </div>
          ))}
        </div>
      )}

      <div className="rounded-xl border border-border bg-bg-card shadow-sm overflow-hidden">
        {running ? (
          <LoadingSpinner label="Generating report…" />
        ) : !loaded ? (
          <EmptyState icon={FileText} title="No report yet" description="Select filters and click Generate." />
        ) : report.length === 0 ? (
          <EmptyState icon={FileText} title="No data for this period" description="Try different filters." />
        ) : (
          <div className="overflow-x-auto">
            {activeTab === 'monthly' && (
              <table className="w-full text-[13px]">
                <thead className="border-b border-border text-left text-[10px] uppercase tracking-widest text-text-muted">
                  <tr>
                    <th className="px-6 py-4 font-medium">Labour</th>
                    <th className="px-6 py-4 font-medium text-right">Daily Wage</th>
                    <th className="px-6 py-4 font-medium text-right" title="Wage at time of marking">Wage @Mark</th>
                    <th className="px-6 py-4 font-medium text-right">OT Rate</th>
                    <th className="px-6 py-4 font-medium text-right text-success" title="Total Days Present">Days</th>
                    <th className="px-6 py-4 font-medium text-right text-danger">A</th>
                    <th className="px-6 py-4 font-medium text-right text-info">OT Hrs</th>
                    <th className="px-6 py-4 font-medium text-right text-text-primary">Gross</th>
                    <th className="px-6 py-4 font-medium text-right text-danger">Advances</th>
                    <th className="px-6 py-4 font-medium text-right text-gold">Net</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r) => (
                    <tr key={r.labourId} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                      <td className="px-6 py-4 font-medium text-text-primary text-[14px]">{r.name}</td>
                      <td className="px-6 py-4 text-right font-mono text-text-secondary">{formatCurrency(r.dailyWage)}</td>
                      <td className="px-6 py-4 text-right font-mono font-medium text-info">{formatCurrency(r.wageAtTime)}</td>
                      <td className="px-6 py-4 text-right font-mono text-text-secondary">{r.otRate ? formatCurrency(r.otRate) : <span className="text-text-muted/50">—</span>}</td>
                      <td className="px-6 py-4 text-right font-mono text-success">{r.present}</td>
                      <td className="px-6 py-4 text-right font-mono text-danger">{r.absent}</td>
                      <td className="px-6 py-4 text-right font-mono text-info">{r.otHours}</td>
                      <td className="px-6 py-4 text-right font-mono font-medium text-text-primary">{formatCurrency(r.gross)}</td>
                      <td className="px-6 py-4 text-right font-mono text-danger">{formatCurrency(r.advances)}</td>
                      <td className={`px-6 py-4 text-right font-mono font-bold ${r.net < 0 ? 'text-danger' : 'text-gold'}`}>{formatCurrency(r.net)}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot className="border-t-2 border-border-strong bg-bg-elevated/50 text-[12px] font-semibold">
                  <tr>
                    <td className="px-6 py-4 uppercase tracking-widest text-text-muted" colSpan={8}>Totals</td>
                    <td className="px-6 py-4 text-right font-mono text-text-primary">{formatCurrency(totals.gross)}</td>
                    <td className="px-6 py-4 text-right font-mono text-danger">{formatCurrency(totals.adv)}</td>
                    <td className="px-6 py-4 text-right font-mono font-bold text-gold text-[14px]">{formatCurrency(totals.net)}</td>
                  </tr>
                </tfoot>
              </table>
            )}

            {activeTab === 'attendance' && (
              <table className="w-full text-[13px]">
                <thead className="border-b border-border text-left text-[10px] uppercase tracking-widest text-text-muted">
                  <tr>
                    <th className="px-6 py-4 font-medium">Labour</th>
                    <th className="px-6 py-4 font-medium text-right text-success">Days Present</th>
                    <th className="px-6 py-4 font-medium text-right text-danger">Absent</th>
                    <th className="px-6 py-4 font-medium text-right">Pending</th>
                    <th className="px-6 py-4 font-medium">Attendance Rate</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r) => (
                    <tr key={r.labourId} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                      <td className="px-6 py-4 font-medium text-text-primary text-[14px]">{r.name}</td>
                      <td className="px-6 py-4 text-right font-mono font-medium text-success">{r.present}</td>
                      <td className="px-6 py-4 text-right font-mono font-medium text-danger">{r.absent}</td>
                      <td className="px-6 py-4 text-right font-mono text-text-muted">{r.pending || 0}</td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="h-2 w-24 overflow-hidden rounded-full bg-bg-input">
                            <div className="h-full rounded-full bg-gold" style={{ width: `${r.rate}%` }} />
                          </div>
                          <span className={`text-[12px] font-mono font-bold ${r.rate >= 75 ? 'text-success' : r.rate >= 50 ? 'text-warning' : 'text-danger'}`}>{r.rate}%</span>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {activeTab === 'overtime' && (
              <table className="w-full text-[13px]">
                <thead className="border-b border-border text-left text-[10px] uppercase tracking-widest text-text-muted">
                  <tr>
                    <th className="px-6 py-4 font-medium">Labour</th>
                    <th className="px-6 py-4 font-medium text-right">OT Rate/hr</th>
                    <th className="px-6 py-4 font-medium text-right text-info">Total OT Hours</th>
                    <th className="px-6 py-4 font-medium text-right text-gold">OT Cost</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r) => (
                    <tr key={r.labourId} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                      <td className="px-6 py-4 font-medium text-text-primary text-[14px]">{r.name}</td>
                      <td className="px-6 py-4 text-right font-mono text-text-secondary">{r.otRate ? formatCurrency(r.otRate) : <span className="text-text-muted/50">—</span>}</td>
                      <td className="px-6 py-4 text-right font-mono font-medium text-info">{r.otHours}</td>
                      <td className="px-6 py-4 text-right font-mono font-bold text-gold">{formatCurrency(r.otCost)}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot className="border-t-2 border-border-strong bg-bg-elevated/50 text-[12px] font-semibold">
                  <tr>
                    <td className="px-6 py-4 uppercase tracking-widest text-text-muted" colSpan={2}>Totals</td>
                    <td className="px-6 py-4 text-right font-mono font-bold text-info">{totals.ot}</td>
                    <td className="px-6 py-4 text-right font-mono font-bold text-gold text-[14px]">{formatCurrency(totals.cost)}</td>
                  </tr>
                </tfoot>
              </table>
            )}

            {activeTab === 'payment' && (
              <table className="w-full text-[13px]">
                <thead className="border-b border-border text-left text-[10px] uppercase tracking-widest text-text-muted">
                  <tr>
                    <th className="px-6 py-4 font-medium">Date</th>
                    <th className="px-6 py-4 font-medium">Labour</th>
                    <th className="px-6 py-4 font-medium">Type</th>
                    <th className="px-6 py-4 font-medium">Method</th>
                    <th className="px-6 py-4 font-medium text-right">Amount</th>
                    <th className="px-6 py-4 font-medium">Notes</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((p) => (
                    <tr key={p.id} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                      <td className="px-6 py-4 text-text-secondary tracking-wide">{p.date instanceof Date ? p.date.toLocaleDateString('en-IN') : p.date?.toDate?.()?.toLocaleDateString?.('en-IN') || '—'}</td>
                      <td className="px-6 py-4 font-medium text-text-primary text-[14px]">{labourMap.get(p.labourId)?.name || p.labourId}</td>
                      <td className="px-6 py-4"><StatusBadge status={p.type || 'salary'} /></td>
                      <td className="px-6 py-4 capitalize text-text-secondary">{p.paymentMethod || 'cash'}</td>
                      <td className="px-6 py-4 text-right font-mono font-medium text-success">{formatCurrency(p.amount)}</td>
                      <td className="px-6 py-4 text-text-muted italic">{p.notes || <span className="text-text-muted/50">—</span>}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot className="border-t-2 border-border-strong bg-bg-elevated/50 text-[12px] font-semibold text-text-secondary">
                  <tr>
                    <td className="px-6 py-4 uppercase tracking-widest text-text-muted" colSpan={4}>Total Paid</td>
                    <td className="px-6 py-4 text-right font-mono font-bold text-success text-[14px]">{formatCurrency(totals.total)}</td>
                    <td className="px-6 py-4"></td>
                  </tr>
                </tfoot>
              </table>
            )}

            {activeTab === 'productivity' && (
              <table className="w-full text-[13px]">
                <thead className="border-b border-border text-left text-[10px] uppercase tracking-widest text-text-muted">
                  <tr>
                    <th className="px-6 py-4 font-medium">Rank</th>
                    <th className="px-6 py-4 font-medium">Labour</th>
                    <th className="px-6 py-4 font-medium text-right text-success">Days Present</th>
                    <th className="px-6 py-4 font-medium text-right text-danger">Absent</th>
                    <th className="px-6 py-4 font-medium text-right">Pending</th>
                    <th className="px-6 py-4 font-medium">Attendance Rate</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r, i) => (
                    <tr key={r.labourId} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                      <td className="px-6 py-4 text-text-muted font-mono">#{i + 1}</td>
                      <td className="px-6 py-4 font-medium text-text-primary text-[14px]">{r.name}</td>
                      <td className="px-6 py-4 text-right font-mono font-medium text-success">{r.present}</td>
                      <td className="px-6 py-4 text-right font-mono font-medium text-danger">{r.absent}</td>
                      <td className="px-6 py-4 text-right font-mono text-text-muted">{r.pending || 0}</td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="h-2 w-24 overflow-hidden rounded-full bg-bg-input">
                            <div className="h-full rounded-full bg-gold" style={{ width: `${r.rate}%` }} />
                          </div>
                          <span className={`text-[12px] font-mono font-bold ${r.rate >= 75 ? 'text-success' : r.rate >= 50 ? 'text-warning' : 'text-danger'}`}>{r.rate}%</span>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {activeTab === 'sitewise' && (
              <table className="w-full text-[13px]">
                <thead className="border-b border-border text-left text-[10px] uppercase tracking-widest text-text-muted">
                  <tr>
                    <th className="px-6 py-4 font-medium">Site</th>
                    <th className="px-6 py-4 font-medium text-right">Labours</th>
                    <th className="px-6 py-4 font-medium text-right text-success">Days Present</th>
                    <th className="px-6 py-4 font-medium text-right text-danger">Absent</th>
                    <th className="px-6 py-4 font-medium text-right">Pending</th>
                    <th className="px-6 py-4 font-medium text-right text-info">OT Hrs</th>
                    <th className="px-6 py-4 font-medium text-right">Total Wage</th>
                    <th className="px-6 py-4 font-medium text-right text-warning">Allowances</th>
                    <th className="px-6 py-4 font-medium text-right text-gold">Grand Total</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r) => (
                    <React.Fragment key={r.siteId}>
                      <tr
                        className="border-b border-border hover:bg-bg-card-hover cursor-pointer transition-colors"
                        onClick={() => setExpandedSite(expandedSite === r.siteId ? null : r.siteId)}
                      >
                        <td className="px-6 py-4 font-medium text-text-primary text-[14px] flex items-center gap-3">
                          <Building2 className="h-4 w-4 text-info" />
                          {r.siteName.length > 20 ? r.siteName.slice(0, 16) + '…' : r.siteName}
                          {expandedSite === r.siteId ? <ChevronUp className="h-4 w-4 text-text-muted" /> : <ChevronDown className="h-4 w-4 text-text-muted" />}
                        </td>
                        <td className="px-6 py-4 text-right font-mono text-text-secondary">{r.uniqueLabours}</td>
                        <td className="px-6 py-4 text-right font-mono text-success">{r.present}</td>
                        <td className="px-6 py-4 text-right font-mono text-danger">{r.absent}</td>
                        <td className="px-6 py-4 text-right font-mono text-text-muted">{r.pending || 0}</td>
                        <td className="px-6 py-4 text-right font-mono text-info">{r.otHours}</td>
                        <td className="px-6 py-4 text-right font-mono font-medium text-text-primary">{formatCurrency(r.totalWage)}</td>
                        <td className="px-6 py-4 text-right font-mono font-medium text-warning">{r.totalAllowance > 0 ? formatCurrency(r.totalAllowance) : <span className="text-text-muted/50">—</span>}</td>
                        <td className="px-6 py-4 text-right font-mono font-bold text-gold">{formatCurrency(r.grandTotal || r.totalWage)}</td>
                      </tr>
                      {expandedSite === r.siteId && (
                        <tr>
                          <td colSpan={10} className="bg-bg-elevated px-6 py-4">
                            <table className="w-full text-[12px]">
                              <thead>
                                <tr className="text-text-muted text-[10px] uppercase tracking-widest border-b border-border-strong">
                                  <th className="py-2 text-left font-medium">Labour</th>
                                  <th className="py-2 text-right font-medium">Date</th>
                                  <th className="py-2 text-right font-medium">Status</th>
                                  <th className="py-2 text-right font-medium">Wage @Mark</th>
                                  <th className="py-2 text-right font-medium text-warning">Allowances</th>
                                  <th className="py-2 text-right font-medium text-danger">Advance</th>
                                  <th className="py-2 text-right font-medium">Remark</th>
                                </tr>
                              </thead>
                              <tbody>
                                {r.records.slice(0, 20).map((rec, idx) => {
                                  const al = rec.allowances || {};
                                  const recAllowance = (Number(al.petrol)||0)+(Number(al.lunch)||0)+(Number(al.breakfast)||0)+(Number(al.tea)||0);
                                  return (
                                    <tr key={idx} className="border-b border-border-strong last:border-b-0 hover:bg-bg-card-hover/50">
                                      <td className="py-3 text-text-primary font-medium">{labourMap.get(rec.labourId)?.name || rec.labourId}</td>
                                      <td className="py-3 text-right text-text-secondary tracking-wide">{rec.date}</td>
                                      <td className="py-3 text-right"><StatusBadge status={rec.status} /></td>
                                      <td className="py-3 text-right font-mono text-info">{formatCurrency(rec.wageAtTime || 0)}</td>
                                      <td className="py-3 text-right font-mono text-warning">{recAllowance > 0 ? formatCurrency(recAllowance) : <span className="text-text-muted/50">—</span>}</td>
                                      <td className="py-3 text-right font-mono text-danger">{rec.advance > 0 ? `-${formatCurrency(rec.advance)}` : <span className="text-text-muted/50">—</span>}</td>
                                      <td className="py-3 text-right text-text-muted italic">{rec.remark || <span className="text-text-muted/50">—</span>}</td>
                                    </tr>
                                  );
                                })}
                                {r.records.length > 20 && (
                                  <tr><td colSpan={7} className="py-3 text-center text-text-muted text-[11px] uppercase tracking-widest">+{r.records.length - 20} more records</td></tr>
                                )}
                              </tbody>
                            </table>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  ))}
                </tbody>
                <tfoot className="border-t-2 border-border-strong bg-bg-elevated/50 text-[12px] font-semibold text-text-secondary">
                  <tr>
                    <td className="px-6 py-4 uppercase tracking-widest text-text-muted" colSpan={6}>Totals</td>
                    <td className="px-6 py-4 text-right font-mono text-info">{totals.ot}</td>
                    <td className="px-6 py-4 text-right font-mono text-text-primary">{formatCurrency(totals.wage)}</td>
                    <td className="px-6 py-4 text-right font-mono text-warning">{formatCurrency(totals.totalAllowance || 0)}</td>
                    <td className="px-6 py-4 text-right font-mono font-bold text-gold text-[14px]">{formatCurrency(totals.grandTotal || totals.wage)}</td>
                  </tr>
                </tfoot>
              </table>
            )}

            {activeTab === 'sitecosts' && (
                <table className="w-full text-left text-[13px]">
                  <thead>
                    <tr className="border-b border-border-strong text-[11px] font-bold uppercase tracking-widest text-text-muted">
                      <th className="px-6 py-4 font-medium">Site</th>
                      <th className="px-6 py-4 font-medium text-right text-info">Material Expenses</th>
                      <th className="px-6 py-4 font-medium text-right text-warning">Other Expenses</th>
                      <th className="px-6 py-4 font-medium text-right text-purple-400">Temp Labour Cost</th>
                      <th className="px-6 py-4 font-medium text-right text-gold">Total Site Cost</th>
                    </tr>
                  </thead>
                  <tbody>
                    {report.map((r) => (
                      <tr key={r.siteId} className="border-b border-border hover:bg-bg-card-hover transition-colors">
                        <td className="px-6 py-4 font-medium text-text-primary text-[14px] flex items-center gap-3">
                          <Building2 className="h-4 w-4 text-info" />
                          {r.siteName}
                        </td>
                        <td className="px-6 py-4 text-right font-mono font-medium text-info">
                          {r.materials > 0 ? formatCurrency(r.materials) : <span className="text-text-muted/50">—</span>}
                        </td>
                        <td className="px-6 py-4 text-right font-mono font-medium text-warning">
                          {r.expenses > 0 ? formatCurrency(r.expenses) : <span className="text-text-muted/50">—</span>}
                        </td>
                        <td className="px-6 py-4 text-right font-mono font-medium text-purple-400">
                          {r.tempLabourCost > 0 ? formatCurrency(r.tempLabourCost) : <span className="text-text-muted/50">—</span>}
                        </td>
                        <td className="px-6 py-4 text-right font-mono font-bold text-gold">
                          {formatCurrency(r.grandTotal)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}

            {activeTab === 'labourwise' && (
              <table className="w-full text-[13px]">
                <thead className="border-b border-border text-left text-[10px] uppercase tracking-widest text-text-muted">
                  <tr>
                    <th className="px-6 py-4 font-medium">Date</th>
                    <th className="px-6 py-4 font-medium">Labour</th>
                    <th className="px-6 py-4 font-medium">Status</th>
                    <th className="px-6 py-4 font-medium text-right text-info">OT Hrs</th>
                    <th className="px-6 py-4 font-medium text-right">Wage @Mark</th>
                    <th className="px-6 py-4 font-medium">Site</th>
                    <th className="px-6 py-4 font-medium text-right">Earned</th>
                    <th className="px-6 py-4 font-medium text-right text-warning">Allowances</th>
                    <th className="px-6 py-4 font-medium text-right text-danger">Advance</th>
                    <th className="px-6 py-4 font-medium text-right text-gold">Grand Total</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r, i) => (
                    <tr key={i} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
                      <td className="px-6 py-4 text-text-secondary tracking-wide">{r.date}</td>
                      <td className="px-6 py-4 font-medium text-text-primary text-[14px]">{r.labourName}</td>
                      <td className="px-6 py-4"><StatusBadge status={r.status} /></td>
                      <td className="px-6 py-4 text-right font-mono text-info">{r.overtimeHours || <span className="text-text-muted/50">—</span>}</td>
                      <td className="px-6 py-4 text-right font-mono font-medium text-info">{formatCurrency(r.wageAtTime)}</td>
                      <td className="px-6 py-4 text-[12px] font-mono text-text-secondary">{r.siteName?.slice(0, 10) || <span className="text-text-muted/50">—</span>}</td>
                      <td className="px-6 py-4 text-right font-mono font-medium text-text-primary">{formatCurrency(r.earned)}</td>
                      <td className="px-6 py-4 text-right font-mono text-warning">
                        {r.totalAllowance > 0 ? (
                          <span title={`Petrol: ₹${r.allowances?.petrol||0} · Lunch: ₹${r.allowances?.lunch||0} · Breakfast: ₹${r.allowances?.breakfast||0} · Tea: ₹${r.allowances?.tea||0}`}>
                            +{formatCurrency(r.totalAllowance)}
                          </span>
                        ) : <span className="text-text-muted/50">—</span>}
                      </td>
                      <td className="px-6 py-4 text-right font-mono text-danger">{r.advance > 0 ? `-${formatCurrency(r.advance)}` : <span className="text-text-muted/50">—</span>}</td>
                      <td className="px-6 py-4 text-right font-mono font-bold text-gold">{r.totalAllowance > 0 || r.advance > 0 ? formatCurrency(r.grandTotal) : <span className="text-text-muted/50">—</span>}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot className="border-t-2 border-border-strong bg-bg-elevated/50 text-[12px] font-semibold text-text-secondary">
                  <tr>
                    <td className="px-6 py-4 uppercase tracking-widest text-text-muted" colSpan={3}>Totals</td>
                    <td className="px-6 py-4 text-right font-mono text-info">{totals.ot} OT hrs</td>
                    <td className="px-6 py-4"></td>
                    <td className="px-6 py-4"></td>
                    <td className="px-6 py-4 text-right font-mono text-success">{formatCurrency(totals.earned)}</td>
                    <td className="px-6 py-4 text-right font-mono text-warning">{formatCurrency(totals.totalAllowance || 0)}</td>
                    <td className="px-6 py-4" />
                    <td className="px-6 py-4 text-right font-mono font-bold text-gold text-[14px]">{formatCurrency(totals.grandTotal || totals.earned)}</td>
                  </tr>
                </tfoot>
              </table>
            )}

            {activeTab === 'overall' && (
              <table className="w-full text-[13px]">
                <thead className="border-b border-border text-left text-[10px] uppercase tracking-widest text-text-muted">
                  <tr>
                    <th className="px-6 py-4 font-medium">Labour</th>
                    <th className="px-6 py-4 font-medium">Type</th>
                    <th className="px-6 py-4 font-medium text-right text-success">Days Present</th>
                    <th className="px-6 py-4 font-medium text-right text-info">OT Hrs</th>
                    <th className="px-6 py-4 font-medium text-right text-text-primary">Gross</th>
                    <th className="px-6 py-4 font-medium text-right text-danger">Advances</th>
                    <th className="px-6 py-4 font-medium text-right text-gold">Net</th>
                  </tr>
                </thead>
                <tbody>
                  {report.map((r) => (
                    <tr key={r.labourId} className={`border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors ${r.type === 'temporary' ? 'bg-bg-elevated/50' : ''}`}>
                      <td className="px-6 py-4 font-medium text-text-primary text-[14px]">
                        {r.name}
                        {r.type === 'temporary' && (
                          <span className="ml-3 text-[10px] font-semibold text-info bg-info/10 border border-info/30 px-1.5 py-0.5 rounded tracking-widest">TEMP</span>
                        )}
                      </td>
                      <td className="px-6 py-4"><StatusBadge status={r.type} /></td>
                      <td className="px-6 py-4 text-right font-mono text-success">{r.present}</td>
                      <td className="px-6 py-4 text-right font-mono text-info">{r.otHours}</td>
                      <td className="px-6 py-4 text-right font-mono font-medium text-text-primary">{formatCurrency(r.gross)}</td>
                      <td className="px-6 py-4 text-right font-mono text-danger">{formatCurrency(r.advances)}</td>
                      <td className={`px-6 py-4 text-right font-mono font-bold ${r.net < 0 ? 'text-danger' : 'text-gold'}`}>{formatCurrency(r.net)}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot className="border-t-2 border-border-strong bg-bg-elevated/50 text-[12px] font-semibold text-text-secondary">
                  <tr>
                    <td className="px-6 py-4 uppercase tracking-widest text-text-muted" colSpan={5}>Grand Total</td>
                    <td className="px-6 py-4 text-right font-mono text-text-primary">{formatCurrency(totals.gross)}</td>
                    <td className="px-6 py-4 text-right font-mono text-danger">{formatCurrency(totals.adv)}</td>
                    <td className="px-6 py-4 text-right font-mono font-bold text-gold text-[14px]">{formatCurrency(totals.net)}</td>
                  </tr>
                </tfoot>
              </table>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
