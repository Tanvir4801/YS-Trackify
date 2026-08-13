import { motion, AnimatePresence } from 'framer-motion';
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Calendar, Save, CheckCheck, ClipboardList, Download, ChevronLeft, ChevronRight, Search, X, Plus, Shield, ChevronDown, ChevronUp, MessageSquare, MapPin, Building2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuthStore, useScopeId } from '../store/authStore';
import { useLabours } from '../hooks/useLabours';
import { useAttendanceByDate } from '../hooks/useAttendance';
import { bulkMarkAttendance, markAsPending, getAttendanceRange, updateAttendanceRemark, updateAttendanceAllowances } from '../lib/services/attendance.service';
import { subscribeSites } from '../lib/services/sites.service';
import { subscribeSessionsForDate, forceEndSession } from '../lib/services/sessions.service';
import { getTempLaboursByDate, addTempLabourEntry, deleteTempLabourEntry } from '../lib/services/tempLabours.service';
import { todayKey, toDateKey, initials, exportExcel, formatCurrency } from '../lib/utils';
import MarkedViaBadge from '../components/shared/MarkedViaBadge';

import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import StatusBadge from '../components/shared/StatusBadge';

const STATUS_CYCLE = ['present', 'three_quarter', 'half', 'quarter', 'absent'];
// 'pending' is intentionally excluded from the cycle — it is a reset action,
// not a normal status to cycle through. It is reachable via the "Reset to Pending"
// button below, which requires an explicit confirm step.
const STATUS_OPTIONS = [
  { value: 'present', label: 'Present' },
  { value: 'three_quarter', label: '3/4 Day' },
  { value: 'half', label: 'Half day' },
  { value: 'quarter', label: '1/4 Day' },
  { value: 'absent', label: 'Absent' },
  { value: 'pending', label: 'Pending (reset)' },
];

function cycleStatus(current) {
  const idx = STATUS_CYCLE.indexOf(current);
  return STATUS_CYCLE[(idx + 1) % STATUS_CYCLE.length];
}

function shiftDate(dateStr, days) {
  const d = new Date(dateStr + 'T00:00:00');
  d.setDate(d.getDate() + days);
  return toDateKey(d);
}

function defaultRow(labour) {
  return {
    labourId: labour.id,
    // IMPORTANT: missing/no Firestore attendance record must be treated as "available" (pending)
    // and must NOT be auto-saved as "present".
    status: 'pending',
    overtimeHours: Number(labour.defaultOvertimeHours) || 0,
    remark: '',
    wageAtTime: Number(labour.dailyWage) || 0,
    siteId: '',
  };
}



export default function Attendance() {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeFromStore = useScopeId();
  const isSupervisor = role === 'supervisor';
  const writeScope = isSupervisor ? uid : scopeFromStore;

  const [date, setDate] = useState(todayKey());
  const [rows, setRows] = useState({});
  // Tracks explicit user changes in this session.
  // Save must ONLY write for labours present in this map.
  const [localChanges, setLocalChanges] = useState({});
  const localChangesRef = React.useRef(localChanges);
  useEffect(() => {
    localChangesRef.current = localChanges;
  }, [localChanges]);

  const [saving, setSaving] = useState(false);
  const [safetyNetOpen, setSafetyNetOpen] = useState(false);
  const [forceClosingSession, setForceClosingSession] = useState(false);


  const [showTempDialog, setShowTempDialog] = useState(false);
  const [tempName, setTempName] = useState('');
  const [tempWage, setTempWage] = useState('');
  const [tempUnit, setTempUnit] = useState('1.0');
  const [tempRemarks, setTempRemarks] = useState('');
  const [tempPaidAmount, setTempPaidAmount] = useState('');
  const [tempPaymentRemark, setTempPaymentRemark] = useState('');
  const [addingTemp, setAddingTemp] = useState(false);
  const [tempLabours, setTempLabours] = useState([]);

  const [supervisorFilter, setSupervisorFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [editingOT, setEditingOT] = useState(null);
  const [editingRemark, setEditingRemark] = useState(null);
  const [editingAllowances, setEditingAllowances] = useState(null);
  const [allowanceForm, setAllowanceForm] = useState({ petrol: 0, lunch: 0, breakfast: 0, tea: 0, advance: 0 });
  const [savingAllowance, setSavingAllowance] = useState(false);
  const [sites, setSites] = useState([]);
  const [selectedSite, setSelectedSite] = useState(null); // null = all sites
  const [sessions, setSessions] = useState([]);

  const contractorId = isSupervisor ? scopeFromStore : writeScope;


  const { data: labours, isLoading: loadingLabours } = useLabours();
  const { records, isLoading: loadingRecords } = useAttendanceByDate(date);

  useEffect(() => {
    const contractorId = isSupervisor ? scopeFromStore : writeScope;
    if (!contractorId) return;
    const unsub = subscribeSites(contractorId, setSites);
    return unsub;
  }, [writeScope, scopeFromStore, isSupervisor]);

  useEffect(() => {
    const contractorId = isSupervisor ? scopeFromStore : writeScope;
    if (!contractorId) return;
    const unsub = subscribeSessionsForDate(contractorId, date, setSessions);
    return unsub;
  }, [writeScope, scopeFromStore, isSupervisor, date]);

  useEffect(() => {
    const fetchTempLabours = async () => {
      const contractorId = isSupervisor ? scopeFromStore : writeScope;
      if (!contractorId) return;
      try {
        const data = await getTempLaboursByDate(contractorId, date);
        setTempLabours(data);
      } catch (e) {
        console.error('Failed to fetch temp labours:', e);
      }
    };
    fetchTempLabours();
  }, [writeScope, scopeFromStore, isSupervisor, date]);

  const sessionMap = useMemo(() => {
    const m = {};
    sessions.forEach((s) => { m[s.siteId] = s; });
    return m;
  }, [sessions]);

  useEffect(() => {
    const next = {};
    labours.forEach((l) => {
      const matchingRecords = records.filter((r) => r.labourId === l.id);
      
      if (matchingRecords.length > 0) {
        matchingRecords.forEach((existing) => {
          // Fallback to labourId if siteId is missing (legacy records)
          const recordKey = existing.siteId ? `${l.id}_${existing.siteId}` : l.id;
          const localChange = localChangesRef.current[recordKey];
          
          if (localChange !== undefined) {
            next[recordKey] = {
              labourId: l.id,
              status: existing.status || 'pending',
              overtimeHours: Number(existing.overtimeHours) || 0,
              remark: existing.remark || existing.notes || '',
              wageAtTime: Number(existing.wageAtTime) || Number(l.dailyWage) || 0,
              shiftFactor: existing.shiftFactor,
              siteId: existing.siteId || '',
              recordId: existing.id,
              petrol: Number(existing.petrol) || 0,
              lunch: Number(existing.lunch) || 0,
              breakfast: Number(existing.breakfast) || 0,
              tea: Number(existing.tea) || 0,
              advance: Number(existing.advance) || 0,
              markedVia: existing.markedVia || '',
              ...localChange,
            };
          } else {
            next[recordKey] = {
              labourId: l.id,
              status: existing.status || 'pending',
              overtimeHours: Number(existing.overtimeHours) || 0,
              remark: existing.remark || existing.notes || '',
              wageAtTime: Number(existing.wageAtTime) || Number(l.dailyWage) || 0,
              shiftFactor: existing.shiftFactor,
              siteId: existing.siteId || '',
              recordId: existing.id,
              petrol: Number(existing.petrol) || 0,
              lunch: Number(existing.lunch) || 0,
              breakfast: Number(existing.breakfast) || 0,
              tea: Number(existing.tea) || 0,
              advance: Number(existing.advance) || 0,
              markedVia: existing.markedVia || '',
            };
          }
        });
      } else {
        const localRow = rows[l.id]; // default key for pending
        if (localRow) {
          next[l.id] = localRow;
        } else {
          next[l.id] = defaultRow(l);
        }
      }
    });
    setRows(next);
  }, [labours, records]);

  const updateRow = (rowKey, patch) => {
    setRows((prev) => ({ ...prev, [rowKey]: { ...prev[rowKey], ...patch } }));

    // Track explicit changes for Save.
    // Save must NOT write untouched/default rows.
    // Therefore, localChanges is only for explicit Present/Absent/Half statuses.
    const currentRow = rows[rowKey];
    const nextRow = { ...(currentRow || {}), ...patch };
    const status = patch.status ?? nextRow.status;

    const shouldTrack = status === 'present' || status === 'three_quarter' || status === 'half' || status === 'quarter' || status === 'absent';

    if (patch.status) {
      setLocalChanges((prev) => {
        const copy = { ...prev };
        if (shouldTrack) copy[rowKey] = { ...copy[rowKey], ...patch };
        else delete copy[rowKey];
        return copy;
      });
      return;
    }

    // Non-status fields (OT/remark/siteId) should only be saved if status is currently tracked.
    if (shouldTrack) {
      setLocalChanges((prev) => ({
        ...prev,
        [rowKey]: {
          ...(prev[rowKey] || {}),
          ...patch,
        },
      }));
    }
  };

  const clickStatus = (labourId) => {
    const current = rows[labourId]?.status || 'pending';
    const nextStatus = cycleStatus(current);
    const targetSiteId = selectedSite ?? rows[labourId]?.siteId ?? '';
    updateRow(labourId, { status: nextStatus, siteId: targetSiteId });
  };

  const markAll = (status) => {
    const next = { ...rows };
    const changes = { ...localChanges };

    Object.keys(next).forEach((rowKey) => {
      const curr = next[rowKey];
      const l = labours.find(lab => lab.id === curr.labourId);
      if (!l) return;
      if (supervisorFilter !== 'all' && l.supervisorId !== supervisorFilter) return;
      if (selectedSite && curr.siteId && curr.siteId !== selectedSite) return;
      
      next[rowKey] = { ...curr, status };
      if (status === 'present' || status === 'three_quarter' || status === 'half' || status === 'quarter' || status === 'absent') {
        changes[rowKey] = { status };
      }
    });

    setRows(next);
    setLocalChanges(changes);
    toast.success(`All filtered rows marked ${status}`);
  };

  const copyYesterday = useCallback(async () => {
    const yesterday = shiftDate(date, -1);
    const t = toast.loading("Loading yesterday's attendance…");
    try {
      const contractorId = isSupervisor ? scopeFromStore : writeScope;
      const recs = await getAttendanceRange(contractorId, yesterday, yesterday, null, isSupervisor, isSupervisor ? uid : null);
      if (recs.length === 0) { toast.dismiss(t); toast.error('No attendance found for yesterday'); return; }
      const next = { ...rows };
      recs.forEach((r) => {
        if (next[r.labourId]) {
          next[r.labourId] = { ...next[r.labourId], status: r.status, overtimeHours: Number(r.overtimeHours) || 0, remark: r.remark || '' };
        }
      });
      setRows(next);
      toast.dismiss(t);
      toast.success('Copied yesterday\'s attendance');
    } catch (e) {
      toast.dismiss(t);
      toast.error('Failed to load yesterday');
    }
  }, [date, rows, writeScope, scopeFromStore, isSupervisor, uid]);

  const handleSave = async () => {
    if (!writeScope) { toast.error('Pick a contractor in the header before saving'); return; }
    if (labours.length === 0) { toast.error('No labours to mark'); return; }

    const changedIds = Object.keys(localChanges);
    if (changedIds.length === 0) {
      toast.error('No changes to save');
      return;
    }

    // Only save labours that have explicit status chosen in this session.
    const dataToSave = changedIds
      .map((rowKey) => {
        const currentRow = rows[rowKey];
        if (!currentRow) return null;
        const labour = labours.find((l) => l.id === currentRow.labourId);
        if (!labour) return null;

        const change = localChanges[rowKey] || {};
        const st = change.status ?? currentRow.status;

        if (!(st === 'present' || st === 'three_quarter' || st === 'half' || st === 'quarter' || st === 'absent')) return null;

        // Keep latest from UI row
        return {
          labourId: currentRow.labourId,
          status: st,
          overtimeHours: Number(currentRow.overtimeHours) || 0,
          remark: currentRow.remark || '',
          wageAtTime: Number(labour.dailyWage) || 0,
          // IMPORTANT: when viewing a specific site, we store siteId in the local change via the dropdown handler.
          siteId: change.siteId ?? currentRow.siteId ?? '',
          recordId: currentRow.recordId,
        };
      })
      .filter(Boolean);

    if (dataToSave.length === 0) {
      toast.error('No explicit Present/Absent/Half changes to save');
      return;
    }

    setSaving(true);
    const t = toast.loading('Saving attendance…');
    try {
      const contractorId = isSupervisor ? scopeFromStore : writeScope;
      await bulkMarkAttendance(contractorId, date, dataToSave, isSupervisor, isSupervisor ? uid : null);
      setLocalChanges({});
      toast.dismiss(t);
      toast.success('Attendance saved');
    } catch (err) {
      console.error('Save error:', err);
      toast.dismiss(t);
      toast.error('Failed to save: ' + (err.message || 'Unknown error'));
    } finally {
      setSaving(false);
    }
  };

  const handleRemarkSave = async (labourId) => {
    const row = rows[labourId];
    if (!row?.recordId) return;
    const contractorId = isSupervisor ? scopeFromStore : writeScope;
    try {
      await updateAttendanceRemark(row.recordId, row.remark || '', contractorId, date, labourId);
    } catch (e) {
      console.error('Failed to save remark:', e);
    }
    setEditingRemark(null);
  };

  const openAllowanceEdit = (labourId) => {
    const row = rows[labourId];
    if (!row?.recordId) { toast.error('Save attendance first before editing allowances'); return; }
    setAllowanceForm({
      petrol: row.petrol || 0,
      lunch: row.lunch || 0,
      breakfast: row.breakfast || 0,
      tea: row.tea || 0,
      advance: row.advance || 0,
    });
    setEditingAllowances(labourId);
  };

  const handleAllowanceSave = async () => {
    const row = rows[editingAllowances];
    if (!row?.recordId) return;
    setSavingAllowance(true);
    const contractorId = isSupervisor ? scopeFromStore : writeScope;
    try {
      await updateAttendanceAllowances(row.recordId, {
        ...allowanceForm,
        wageAtTime: row.wageAtTime,
        contractorId,
        date,
        labourId: editingAllowances,
      });
      updateRow(editingAllowances, { ...allowanceForm });
      toast.success('Allowances saved');
      setEditingAllowances(null);
    } catch (e) {
      toast.error('Failed to save allowances');
    } finally {
      setSavingAllowance(false);
    }
  };

  const handleAddTempLabour = async () => {
    if (!tempName.trim()) { toast.error('Enter a name'); return; }
    const wage = parseFloat(tempWage);
    if (!wage || wage <= 0) { toast.error('Enter a valid daily wage'); return; }
    if (!writeScope) { toast.error('Select a contractor first'); return; }
    
    setAddingTemp(true);
    try {
      const contractorId = isSupervisor ? scopeFromStore : writeScope;
      const newEntry = await addTempLabourEntry({
        contractorId,
        supervisorId: uid || writeScope,
        siteId: selectedSite || '',
        date,
        name: tempName.trim(),
        wage,
        attendanceUnit: parseFloat(tempUnit),
        remarks: tempRemarks.trim(),
        paidAmount: parseFloat(tempPaidAmount) || 0,
        paymentRemark: tempPaymentRemark.trim(),
      });
      
      setTempLabours(prev => [...prev, newEntry]);
      toast.success(`${tempName.trim()} added`);
      setTempName('');
      setTempWage('');
      setTempRemarks('');
      setTempUnit('1.0');
      setTempPaidAmount('');
      setTempPaymentRemark('');
      setShowTempDialog(false);
    } catch (err) {
      toast.error('Failed to add temp worker: ' + err.message);
    } finally {
      setAddingTemp(false);
    }
  };

  const handleDeleteTempLabour = async (id) => {
    if (!window.confirm('Are you sure you want to delete this temporary worker entry?')) return;
    try {
      await deleteTempLabourEntry(id);
      setTempLabours(prev => prev.filter(l => l.id !== id));
      toast.success('Deleted successfully');
    } catch (e) {
      toast.error('Failed to delete');
    }
  };

  const handleForceCloseSession = async (siteCard) => {
    const confirmed = window.confirm(
      `Force close session for ${siteCard.siteName}?\n\n` +
      `This will end the active mobile session.\n` +
      `Supervisor: ${siteCard.supervisorName || 'Unknown'}\n\n` +
      `After force-close, you can edit attendance manually from web.`
    );

    if (!confirmed) return;
    if (!contractorId) { toast.error('Missing contractor scope'); return; }

    try {
      setForceClosingSession(true);
      const sid = siteCard.sessionId;
      if (!sid) { toast.error('Missing session id'); setForceClosingSession(false); return; }
      await forceEndSession(contractorId, sid);
      toast.success(`Session closed for ${siteCard.siteName}. You can now edit attendance.`);
    } catch (err) {
      console.error('Force close error:', err);
      toast.error('Failed to close session: ' + (err.message || 'Unknown error'));
    } finally {
      setForceClosingSession(false);
    }
  };

  const handleMarkAsPending = async (labourId) => {

    const row = rows[labourId];
    const labour = labours.find((l) => l.id === labourId);
    if (!row?.recordId) {
      toast.error('No saved record to reset — save attendance first');
      return;
    }
    const confirmed = window.confirm(
      `Reset ${labour?.name || labourId} to Pending?\n\nThis removes their wage credit for today and marks them as needing to be re-marked. Use this to correct a mis-marked record (e.g., marked at the wrong site).`
    );
    if (!confirmed) return;
    const contractorId = isSupervisor ? scopeFromStore : writeScope;
    try {
      await markAsPending(contractorId, labourId, date, {
        siteId: row.siteId || null,
        pendingReason: 'admin_reset',
      });
      toast.success(`${labour?.name || labourId} reset to Pending`);
    } catch (e) {
      console.error('markAsPending error:', e);
      toast.error('Failed to reset: ' + (e.message || 'Unknown error'));
    }
  };

  const handleExport = () => {
    const rows2 = labours.map((l) => {
      const r = rows[l.id] || defaultRow(l);
      // Map status values to human-readable labels for CSV export
      const statusLabels = { present: 'Present', absent: 'Absent', half: 'Half day', pending: 'Pending' };
      return {
        Date: date,
        Labour: l.name,
        Phone: l.phone || '',
        Status: statusLabels[r.status] || r.status,
        'OT Hours': r.overtimeHours,
        Remark: r.remark || '',
        'Wage At Time': r.wageAtTime || l.dailyWage,
      };
    });
    exportExcel(`attendance-${date}.csv`, rows2);
    toast.success('Excel downloaded');
  };

  const supervisorIds = useMemo(() => {
    const ids = [...new Set(labours.map((l) => l.supervisorId).filter(Boolean))];
    return ids;
  }, [labours]);

  const takenLabourIds = useMemo(() => {
    const taken = new Set(
      records
        .filter((r) => r.status === 'present' || r.status === 'three_quarter' || r.status === 'half' || r.status === 'quarter' || r.status === 'absent')
        .map((r) => r.labourId)
    );
    return taken;
  }, [records]);

  const displayRows = useMemo(() => {
    return Object.entries(rows).map(([rowKey, row]) => {
      const l = labours.find(lab => lab.id === row.labourId);
      return { rowKey, row, l };
    }).filter(({ row, l }) => {
      if (!l) return false;
      if (search && !l.name?.toLowerCase().includes(search.toLowerCase()) && !l.phone?.includes(search)) return false;
      if (supervisorFilter !== 'all' && l.supervisorId !== supervisorFilter) return false;
      if (statusFilter !== 'all' && row.status !== statusFilter) return false;
      // Filter by selected site if specified
      if (selectedSite) {
         // If a site is selected, only show records matching that site, OR pending workers
         if (row.siteId && row.siteId !== selectedSite) return false;
         // If they have a siteId from another record, but this is the pending row... wait
         // If we are filtering by site, we probably only want to see them if they are pending or have this site
      }
      return true;
    }).sort(({ l: a }, { l: b }) => (a.name || '').localeCompare(b.name || ''));
  }, [rows, labours, search, supervisorFilter, statusFilter, selectedSite]);

  const summaryCounts = useMemo(() => {
    const presentIds = new Set();
    const absentIds = new Set();
    const threeQuarterIds = new Set();
    const halfIds = new Set();
    const quarterIds = new Set();
    const pendingIds = new Set();

    // Count UNIQUE labour IDs across ALL records (flat + nested merged by labourId).
    records.forEach((r) => {
      if (!r?.labourId) return;
      if (r.status === 'present') presentIds.add(r.labourId);
      else if (r.status === 'absent') absentIds.add(r.labourId);
      else if (r.status === 'three_quarter') threeQuarterIds.add(r.labourId);
      else if (r.status === 'half') halfIds.add(r.labourId);
      else if (r.status === 'quarter') quarterIds.add(r.labourId);
      else if (r.status === 'pending') pendingIds.add(r.labourId);
    });

    const allRecordedIds = new Set([
      ...presentIds,
      ...absentIds,
      ...threeQuarterIds,
      ...halfIds,
      ...quarterIds,
      ...pendingIds,
    ]);

    const unmarkedCount = labours.filter((l) => !allRecordedIds.has(l.id)).length;
    const markedCount = presentIds.size + absentIds.size + threeQuarterIds.size + halfIds.size + quarterIds.size;

    return {
      present: presentIds.size,
      absent: absentIds.size,
      three_quarter: threeQuarterIds.size,
      half: halfIds.size,
      quarter: quarterIds.size,
      pending: pendingIds.size,
      totalMarked: markedCount,
      unmarked: unmarkedCount,
    };
  }, [records, labours]);

  // Site view must show:
  // - marked at selected site (present/absent/half)
  // - all pending (any old site)
  // - all unmarked (no record today)
  const { pendingLabours, alreadyMarked } = useMemo(() => {
    const selected = selectedSite;
    const pending = [];
    const marked = [];

    // displayRows is the list of { rowKey, row, l } we injected earlier
    displayRows.forEach(({ rowKey, row, l }) => {
      // row.status is the source of truth for if it's marked or pending
      if (row.status === 'pending') {
         // if it's pending, we show it in pending
         pending.push({ rowKey, row, l });
      } else {
         marked.push({ rowKey, row, l });
      }
    });

    return {
      pendingLabours: pending,
      alreadyMarked: marked,
    };
  }, [displayRows]);

  // NOTE: selectedSite is intentionally not used for record grouping on web because
  // Firestore attendance records currently DO NOT contain siteId.



  const summary = useMemo(() => {
    const s = { present: 0, three_quarter: 0, half: 0, quarter: 0, absent: 0, pending: 0, totalOT: 0 };
    Object.values(rows).forEach((r) => {
      if (r.status === 'present') s.present++;
      else if (r.status === 'absent') s.absent++;
      else if (r.status === 'three_quarter') s.three_quarter++;
      else if (r.status === 'half') s.half++;
      else if (r.status === 'quarter') s.quarter++;
      else if (r.status === 'pending') s.pending++;
      s.totalOT += Number(r.overtimeHours) || 0;
    });
    return s;
  }, [rows]);

  const wageLiability = useMemo(() => {
    let total = 0;
    records.forEach((r) => {
      if (r.status === 'pending' || r.status === 'absent') return;
      const l = labours.find(lab => lab.id === r.labourId);
      if (!l) return;
      
      const wage = Number(r.wageAtTime) || Number(l.dailyWage) || 0;
      const otRate = Number(l.overtimeWagePerHour) || 0;
      
      const factor = r.shiftFactor !== undefined ? Number(r.shiftFactor) : (r.status === 'present' ? 1.0 : r.status === 'half' ? 0.5 : r.status === 'three_quarter' ? 0.75 : r.status === 'quarter' ? 0.25 : 0.0);
      
      total += (wage * factor) + ((Number(r.overtimeHours) || 0) * otRate);
    });
    return total;
  }, [records, labours]);

  const dayName = useMemo(() => {
    try { return new Date(date + 'T00:00:00').toLocaleDateString('en-IN', { weekday: 'long' }); }
    catch { return ''; }
  }, [date]);

  const tableRows = (list) => list.map(({ rowKey, row, l }) => {
    
    const dailyWage = Number(l.dailyWage) || 0;
    const otRate = Number(l.overtimeWagePerHour) || 0;
    const otHours = Number(row.overtimeHours) || 0;
    // Calculate total factor and OT across all records for this labour
    let totalFactor = 0;
    let totalOT = 0;
    const labourRecords = records.filter(r => r.labourId === l.id && r.status !== 'pending');
    
    if (selectedSite) {
      // If a site is selected, only show earnings for the specific row (which is the selected site's record)
      const factor = row.shiftFactor !== undefined ? Number(row.shiftFactor) : (row.status === 'present' ? 1.0 : row.status === 'three_quarter' ? 0.75 : row.status === 'half' ? 0.5 : row.status === 'quarter' ? 0.25 : 0.0);
      totalFactor = factor;
      totalOT = otHours;
    } else {
      // All sites view: sum up all records
      if (labourRecords.length > 0) {
        labourRecords.forEach(r => {
          const factor = r.shiftFactor !== undefined ? Number(r.shiftFactor) : (r.status === 'present' ? 1.0 : r.status === 'three_quarter' ? 0.75 : r.status === 'half' ? 0.5 : r.status === 'quarter' ? 0.25 : 0.0);
          totalFactor += factor;
          totalOT += Number(r.overtimeHours) || 0;
        });
      } else {
        const factor = row.shiftFactor !== undefined ? Number(row.shiftFactor) : (row.status === 'present' ? 1.0 : row.status === 'three_quarter' ? 0.75 : row.status === 'half' ? 0.5 : row.status === 'quarter' ? 0.25 : 0.0);
        totalFactor = factor;
        totalOT = otHours;
      }
    }

    let dayEarnings = 0;
    if (totalFactor > 0 || totalOT > 0) {
      dayEarnings = (dailyWage * totalFactor) + (totalOT * otRate);
    }

    return (
      <tr key={rowKey} className="border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors">
        <td className="px-6 py-4">
          <div className="flex items-center gap-3">
            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-bg-elevated border border-border-strong text-[12px] font-mono font-medium text-text-secondary">
              {initials(l.name)}
            </div>
            <div>
              <div className="font-medium text-text-primary text-[14px]">{l.name}</div>
              {l.skill && <div className="text-[11px] text-text-muted tracking-wider uppercase">{l.skill}</div>}
              {records.filter((r) => r.labourId === l.id && r.siteId !== (selectedSite || row.siteId) && r.status !== 'pending').map((or) => {
                const sName = sites.find((s) => s.id === or.siteId)?.name || or.siteId;
                const statusLabel = or.status === 'present' ? 'Present' : or.status === 'three_quarter' ? '3/4 Day' : or.status === 'half' ? 'Half Day' : or.status === 'quarter' ? '1/4 Day' : or.status;
                return (
                  <div key={or.siteId || Math.random()} className="inline-flex mt-1 mr-1 items-center rounded bg-warning-bg border border-warning/30 px-1.5 py-0.5 text-[10px] text-warning font-semibold tracking-wide uppercase">
                    {statusLabel} at {sName}
                  </div>
                );
              })}
            </div>
          </div>
        </td>
        <td className="px-6 py-4 font-mono text-text-secondary">{formatCurrency(dailyWage)}</td>
        <td className="px-6 py-4">
          <div className="flex flex-wrap items-center gap-2">
            <button onClick={() => clickStatus(rowKey)} title="Click to cycle status (present → absent → half)" className="inline-block cursor-pointer transition-transform hover:scale-105 active:scale-95">
              <StatusBadge status={row.status} />
            </button>
            <select
              value={row.status}
              onChange={(e) => {
                const newStatus = e.target.value;
                const targetSiteId = selectedSite ?? row.siteId ?? '';
                updateRow(rowKey, {
                  status: newStatus,
                  siteId: targetSiteId,
                });
              }}
              className="h-8 rounded-lg border border-border-strong bg-bg-input px-2 text-[12px] text-text-primary outline-none focus:border-gold"
            >
              {STATUS_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
            {row.recordId && row.status !== 'pending' && (
              <button
                onClick={() => handleMarkAsPending(rowKey)}
                title="Reset to Pending (clears wage credit, marks for re-marking)"
                className="flex h-8 w-8 items-center justify-center rounded-lg border border-border-strong bg-bg-elevated text-text-muted hover:border-warning hover:text-warning transition-colors"
              >
                ↺
              </button>
            )}
          </div>
        </td>
        <td className="px-6 py-4 text-right">
          {editingOT === rowKey ? (
            <Input
              type="number" min="0" step="0.5"
              value={row.overtimeHours}
              onChange={(e) => updateRow(rowKey, { overtimeHours: e.target.value })}
              onBlur={() => setEditingOT(null)}
              autoFocus
              className="h-8 w-20 text-right bg-bg-input text-[13px]"
            />
          ) : (
            <button onClick={() => setEditingOT(rowKey)} className="font-mono text-info underline-offset-4 hover:underline">
              {row.overtimeHours}
            </button>
          )}
        </td>
        <td className="px-6 py-4">
          {editingRemark === rowKey ? (
            <Input
              type="text"
              value={row.remark || ''}
              onChange={(e) => updateRow(rowKey, { remark: e.target.value })}
              onBlur={() => handleRemarkSave(rowKey)}
              autoFocus
              placeholder="Add remark…"
              className="h-8 w-40 text-[12px] bg-bg-input"
            />
          ) : (
            <button
              onClick={() => setEditingRemark(rowKey)}
              className="flex items-center gap-1.5 text-[12px] text-text-muted hover:text-text-primary transition-colors"
              title="Click to add remark"
            >
              <MessageSquare className="h-[14px] w-[14px]" />
              <span className="max-w-[120px] truncate">{row.remark || '—'}</span>
            </button>
          )}
        </td>
        <td className="px-6 py-4 text-right font-mono font-medium text-text-primary">{formatCurrency(dayEarnings)}</td>
        <td className="px-6 py-4 text-center">
          <button
            onClick={() => openAllowanceEdit(rowKey)}
            title="Edit allowances"
            className="text-[12px] text-info hover:text-gold hover:underline transition-colors"
          >
            {(row.petrol || row.lunch || row.breakfast || row.tea || row.advance)
              ? <span className="font-mono font-bold text-warning">₹{((row.petrol||0)+(row.lunch||0)+(row.breakfast||0)+(row.tea||0)).toFixed(0)}</span>
              : <span className="text-text-muted/50">+ add</span>}
          </button>
        </td>
        <td className="px-6 py-4 text-center">
          {(row.recordId && row.status !== 'pending') ? <span className="text-[14px] font-bold text-success">✓</span> : <span className="text-text-muted/30">—</span>}
        </td>
      </tr>
    );
  });

  return (
    <div className="space-y-6">
      {/* Date picker + context bar */}
      <div className="rounded-xl border border-border bg-bg-card px-6 py-5 mb-3 flex flex-wrap items-center justify-between gap-4">
        <div className="text-[13px] text-text-secondary uppercase tracking-widest font-medium">
          <span className="font-semibold text-text-primary mr-3">{dayName}</span>
          <span className="text-text-muted">
            {displayRows.length} labours · {summaryCounts.totalMarked} marked ·{' '}
            <span className={summaryCounts.pending > 0 ? 'text-warning font-semibold' : 'text-success font-semibold'}>
              {summaryCounts.pending} pending
            </span>
          </span>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <button onClick={() => setDate(shiftDate(date, -1))} className="flex h-9 w-9 items-center justify-center rounded-lg border border-border-strong bg-bg-elevated hover:bg-bg-card-hover transition-colors">
            <ChevronLeft className="h-4 w-4 text-text-muted" />
          </button>
          <div className="flex h-9 items-center gap-2 rounded-lg border border-border-strong bg-bg-elevated px-3 transition-colors focus-within:border-gold">
            <Calendar className="h-4 w-4 text-gold" />
            <input 
              type="date" 
              value={date} 
              onChange={(e) => setDate(e.target.value)} 
              className="bg-transparent text-[13px] font-mono font-medium text-text-primary outline-none [&::-webkit-calendar-picker-indicator]:invert-[0.8]" 
            />
          </div>
          <button onClick={() => setDate(shiftDate(date, 1))} className="flex h-9 w-9 items-center justify-center rounded-lg border border-border-strong bg-bg-elevated hover:bg-bg-card-hover transition-colors">
            <ChevronRight className="h-4 w-4 text-text-muted" />
          </button>
          {date !== todayKey() && (
            <button onClick={() => setDate(todayKey())} className="h-9 px-4 rounded-lg bg-gold-bg border border-gold text-gold text-[12px] font-semibold transition-colors hover:bg-gold hover:text-bg-primary">
              Today
            </button>
          )}
        </div>
      </div>

      <div className="flex flex-wrap items-end gap-3 rounded-xl border border-border bg-bg-card px-5 py-3.5 mb-3">
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
          <input 
            value={search} 
            onChange={(e) => setSearch(e.target.value)} 
            placeholder="Search name or phone…" 
            className="h-9 w-48 rounded-lg border border-border-strong bg-bg-input pl-9 pr-3 text-[13px] text-text-primary placeholder:text-text-muted outline-none focus:border-gold focus:ring-1 focus:ring-gold" 
          />
        </div>
        <div className="space-y-1.5 flex flex-col">
          <label className="text-[10px] uppercase tracking-widest text-text-muted font-medium ml-1">Status</label>
          <select 
            value={statusFilter} 
            onChange={(e) => setStatusFilter(e.target.value)} 
            className="h-9 rounded-lg border border-border-strong bg-bg-input px-3 text-[13px] text-text-primary outline-none focus:border-gold focus:ring-1 focus:ring-gold"
          >
            <option value="all">All statuses</option>
            {STATUS_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
        </div>
        <div className="flex flex-wrap gap-2 ml-auto">
          <button onClick={() => markAll('present')} className="flex h-9 items-center gap-1.5 rounded-lg border border-success/30 bg-success-bg px-3 text-[12px] font-medium text-success hover:bg-success hover:text-bg-primary transition-colors"><CheckCheck className="h-4 w-4" /> All present</button>
          <button onClick={() => markAll('absent')} className="flex h-9 items-center gap-1.5 rounded-lg border border-danger/30 bg-danger-bg px-3 text-[12px] font-medium text-danger hover:bg-danger hover:text-white transition-colors"><X className="h-4 w-4" /> All absent</button>
          <button onClick={copyYesterday} className="flex h-9 items-center gap-1.5 rounded-lg border border-border-strong bg-bg-elevated px-3 text-[12px] font-medium text-text-secondary hover:border-gold hover:text-gold transition-colors"><Calendar className="h-4 w-4" /> Copy yesterday</button>
          <button onClick={handleExport} className="flex h-9 items-center gap-1.5 rounded-lg border border-border-strong bg-bg-elevated px-3 text-[12px] font-medium text-text-secondary hover:text-text-primary transition-colors"><Download className="h-4 w-4" /> CSV</button>
          <button
            onClick={handleSave}
            disabled={saving || labours.length === 0 || Object.keys(localChanges).length === 0}
            className={`flex h-9 items-center gap-2 rounded-lg px-4 text-[13px] font-medium transition-all ${
              Object.keys(localChanges).length > 0 && !saving 
                ? 'bg-gold text-bg-primary shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-105' 
                : 'bg-bg-elevated text-text-muted border border-border-strong cursor-not-allowed'
            }`}
          >
            <Save className="h-4 w-4" />
            {saving
              ? 'Saving…'
              : Object.keys(localChanges).length > 0
              ? `Save (${Object.keys(localChanges).length})`
              : 'Save'}
          </button>
        </div>
      </div>

      {/* ── ALLOWANCES EDIT MODAL ───────────────────────────── */}
      {editingAllowances && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
          <div className="w-full max-w-sm rounded-2xl bg-bg-card border border-border p-6 shadow-2xl">
            <div className="flex items-center gap-2 mb-1 border-b border-border pb-3">
              <span className="text-lg">💰</span>
              <h3 className="text-base font-semibold text-text-primary">Daily Allowances</h3>
            </div>
            <p className="my-3 text-xs text-text-muted">Labour: <span className="text-text-primary font-medium">{labours.find((l) => l.id === editingAllowances)?.name}</span></p>
            <div className="space-y-3">
              {[
                { key: 'petrol', emoji: '🚗', label: 'Petrol' },
                { key: 'lunch', emoji: '🍽', label: 'Lunch' },
                { key: 'breakfast', emoji: '🍳', label: 'Breakfast' },
                { key: 'tea', emoji: '☕', label: 'Tea' },
              ].map(({ key, emoji, label }) => (
                <div key={key} className="flex items-center gap-3">
                  <span className="text-base w-5">{emoji}</span>
                  <Label className="w-20 text-xs text-text-secondary">{label}</Label>
                  <Input
                    type="number"
                    min="0"
                    value={allowanceForm[key]}
                    onChange={(e) => setAllowanceForm((f) => ({ ...f, [key]: Number(e.target.value) || 0 }))}
                    className="h-8 flex-1 text-right text-sm bg-bg-input text-text-primary border-border-strong"
                    placeholder="0"
                  />
                  <span className="text-xs text-text-muted">₹</span>
                </div>
              ))}
              <div className="border-t border-border pt-3">
                <div className="flex items-center gap-3">
                  <span className="text-base w-5">💸</span>
                  <Label className="w-20 text-xs text-danger font-medium">Advance</Label>
                  <Input
                    type="number"
                    min="0"
                    value={allowanceForm.advance}
                    onChange={(e) => setAllowanceForm((f) => ({ ...f, advance: Number(e.target.value) || 0 }))}
                    className="h-8 flex-1 text-right text-sm bg-bg-input text-text-primary border-danger/30 focus:border-danger"
                    placeholder="0"
                  />
                  <span className="text-xs text-text-muted">₹</span>
                </div>
              </div>
              <div className="rounded-lg bg-info-bg border border-info/20 p-3 text-xs text-info">
                <span className="font-semibold">Total allowances: </span>
                ₹{(allowanceForm.petrol + allowanceForm.lunch + allowanceForm.breakfast + allowanceForm.tea).toFixed(0)}
                {allowanceForm.advance > 0 && <span className="ml-2 text-danger font-semibold">· Advance: ₹{allowanceForm.advance.toFixed(0)}</span>}
              </div>
            </div>
            <div className="mt-5 flex gap-2 border-t border-border pt-4">
              <Button variant="outline" onClick={() => setEditingAllowances(null)} className="flex-1 border-border-strong text-text-secondary hover:text-text-primary hover:bg-bg-elevated">Cancel</Button>
              <Button onClick={handleAllowanceSave} disabled={savingAllowance} className="flex-1 bg-gold text-bg-primary hover:bg-gold-light hover:scale-102 transition-transform">
                {savingAllowance ? 'Saving…' : 'Save Allowances'}
              </Button>
            </div>
          </div>
        </div>
      )}



      {isSupervisor && (
        <div className="rounded-xl border border-border bg-bg-elevated px-4 py-3 text-[13px] text-text-secondary mb-4">
          Showing your assigned labours only.
        </div>
      )}

      <div className="rounded-xl border border-border bg-bg-elevated px-5 py-4 mb-4">
        <div className="flex flex-wrap gap-x-6 gap-y-3 text-[13px]">
          <span className="text-text-muted">Total: <strong className="text-text-primary font-mono ml-1">{displayRows.length}</strong></span>
          <span className="text-text-muted">Present: <strong className="text-success font-mono ml-1">{summary.present}</strong></span>
          <span className="text-text-muted">Absent: <strong className="text-danger font-mono ml-1">{summary.absent}</strong></span>
          <span className="text-text-muted">Half: <strong className="text-warning font-mono ml-1">{summary.half}</strong></span>
          {summary.pending > 0 && (
            <span className="text-text-muted">Pending: <strong className="text-warning font-mono ml-1">{summary.pending}</strong></span>
          )}
          <span className="text-text-muted">OT Hours: <strong className="text-info font-mono ml-1">{summary.totalOT}</strong></span>
          <span className="text-text-muted">Wage liability: <strong className="text-gold font-mono ml-1">{formatCurrency(wageLiability)}</strong></span>
          <span className="text-text-muted">Unmarked: <strong className="text-text-primary font-mono ml-1">{summaryCounts.unmarked}</strong></span>
        </div>
      </div>

      {/* ── SITE CARDS ──────────────────────────────────────────────────── */}
      {/* Sites are standalone — siteId is on the attendance record, not the labour */}
      {sites.length > 0 && (
        <div className="flex gap-3 overflow-x-auto pb-2 mb-4 scrollbar-thin">
          {/* All card */}
          <button
            onClick={() => setSelectedSite(null)}
            className={`flex shrink-0 flex-col items-center gap-1.5 rounded-xl border px-6 py-4 text-center transition-all min-w-[120px] ${
              selectedSite === null
                ? 'border-gold bg-gold-bg shadow-[0_0_15px_rgba(245,166,35,0.1)] text-gold'
                : 'border-border bg-bg-card text-text-secondary hover:border-border-strong hover:bg-bg-elevated'
            }`}
          >
            <Building2 className={`h-5 w-5 ${selectedSite === null ? 'text-gold' : 'text-text-muted'}`} />
            <span className="text-[13px] font-medium mt-1">All Sites</span>
            <span className={`text-[11px] ${selectedSite === null ? 'text-gold/80' : 'text-text-muted'}`}>
              {displayRows.length} labours
            </span>
            {pendingLabours.length > 0 && (
              <span className={`mt-1 rounded px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider ${selectedSite === null ? 'bg-gold/20 text-gold' : 'bg-warning-bg border border-warning/30 text-warning'}`}>
                {pendingLabours.length} pending
              </span>
            )}
            {displayRows.length > 0 && pendingLabours.length === 0 && (
              <span className={`text-[11px] font-semibold mt-1 ${selectedSite === null ? 'text-gold' : 'text-success'}`}>All ✓</span>
            )}
          </button>
          {/* Per-site cards — show session status + how many labours were marked today */}
          {sites.map((s) => {
            const markedHere = records.filter(r => r.siteId === s.id && r.status !== 'pending').length;
            const siteSession = sessionMap[s.id];
            const isActive = selectedSite === s.id;

            const sessionStatus = siteSession?.status;
            const sessionBadge = !siteSession
              ? { label: 'PENDING', cls: 'bg-warning-bg border border-warning/30 text-warning', dot: null }
              : sessionStatus === 'active'
              ? { label: 'IN PROGRESS', cls: 'bg-info-bg border border-info/30 text-info', dot: 'bg-info' }
              : { label: 'COMPLETE', cls: 'bg-success-bg border border-success/30 text-success', dot: null };
            return (
              <button
                key={s.id}
                onClick={() => setSelectedSite(s.id)}
                className={`flex shrink-0 flex-col items-center gap-1.5 rounded-xl border px-6 py-4 text-center transition-all min-w-[130px] ${
                  isActive
                    ? 'border-gold bg-gold-bg shadow-[0_0_15px_rgba(245,166,35,0.1)] text-gold'
                    : 'border-border bg-bg-card text-text-secondary hover:border-border-strong hover:bg-bg-elevated'
                }`}
              >
                <MapPin className={`h-5 w-5 ${isActive ? 'text-gold' : 'text-info'}`} />
                <span className="text-[13px] font-medium leading-tight mt-1">{s.name}</span>
                <span className={`text-[11px] ${isActive ? 'text-gold/80' : 'text-text-muted'}`}>
                  {markedHere} marked today
                </span>
                {/* Session status badge */}
                <span className={`mt-1 inline-flex items-center gap-1.5 rounded px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider ${isActive ? 'bg-gold/20 text-gold' : sessionBadge.cls}`}>
                  {sessionBadge.dot && (
                    <span className={`inline-block h-1.5 w-1.5 rounded-full live-dot ${isActive ? 'bg-gold' : sessionBadge.dot}`} />
                  )}
                  {sessionBadge.label}
                </span>
                {siteSession?.markedCount > 0 && (
                  <span className={`text-[11px] font-semibold mt-1 ${isActive ? 'text-gold' : 'text-success'}`}>
                    {siteSession.markedCount} scanned
                  </span>
                )}

                {/* Force close session (admin) */}
                {sessionStatus === 'active' && (
                  <div className="mt-2">
                    <button
                      onClick={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        handleForceCloseSession({
                          siteName: s.name,
                          supervisorName: s.supervisorName,
                          sessionId: siteSession?.id,
                        });
                      }}
                      disabled={forceClosingSession}
                      className="mt-1 px-3 py-1 text-[11px] font-semibold bg-warning-bg border border-warning text-warning rounded hover:bg-warning hover:text-white transition-colors"
                      title="Force close active mobile session"
                    >
                      {forceClosingSession ? 'Closing…' : '⚠ Force Close'}
                    </button>
                  </div>
                )}
              </button>
            );
          })}
        </div>
      )}

      {/* ── ATTENDANCE TABLE ─────────────────────────────────────────────── */}
      <div className="rounded-xl border border-border bg-bg-card overflow-hidden">
        {loadingLabours || loadingRecords ? (
          <LoadingSpinner label="Loading attendance…" />
        ) : labours.length === 0 ? (
          <EmptyState icon={ClipboardList} title="No labours to mark" description={isSupervisor ? 'No labours assigned to you.' : 'Add labours from the Labours page first.'} />
        ) : (
          <>
            {pendingLabours.length > 0 && (
              <>
                <div className="px-5 pt-5 pb-3 flex items-center gap-3">
                  <span className="text-[11px] font-bold uppercase tracking-[1.5px] text-text-muted">
                    Pending — {pendingLabours.length}
                  </span>
                  <div className="h-[1px] flex-1 bg-border-strong" />
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-[13px] whitespace-nowrap">
                    <thead className="sticky top-0 border-y border-border bg-bg-elevated text-left text-[10px] uppercase tracking-widest text-text-muted">
                      <tr>
                        <th className="px-5 py-3 font-medium">Labour</th>
                        <th className="px-5 py-3 font-medium">Daily Wage</th>
                        <th className="px-5 py-3 font-medium">Status</th>
                        <th className="px-5 py-3 font-medium text-right">OT Hours</th>
                        <th className="px-5 py-3 font-medium">Remark</th>
                        <th className="px-5 py-3 font-medium text-right">Day Earnings</th>
                        <th className="px-5 py-3 font-medium text-center">Allowances</th>
                        <th className="px-5 py-3 font-medium text-center">Saved</th>
                      </tr>
                    </thead>
                    <tbody>{tableRows(pendingLabours)}</tbody>
                  </table>
                </div>
              </>
            )}

            {alreadyMarked.length > 0 && (
              <div className="border-t border-border-strong bg-warning-bg">
                <button
                  onClick={() => setSafetyNetOpen((o) => !o)}
                  className="flex w-full items-center gap-3 px-5 py-4 text-left hover:bg-warning/5 transition-colors"
                >
                  <Shield className="h-[18px] w-[18px] text-warning" />
                  <div className="flex-1">
                    <span className="text-[13px] font-medium text-warning">
                      Already Marked Today — {alreadyMarked.length}
                    </span>
                    <span className="ml-3 text-[12px] text-warning/80">Review &amp; fix before day locks</span>
                  </div>
                  {safetyNetOpen ? <ChevronUp className="h-4 w-4 text-warning" /> : <ChevronDown className="h-4 w-4 text-warning" />}
                </button>

                {safetyNetOpen && (
                  <div className="overflow-x-auto border-t border-warning/20">
                    <table className="w-full text-[13px] whitespace-nowrap">
                      <thead className="border-b border-warning/20 text-left text-[10px] uppercase tracking-widest text-warning/80 bg-warning/10">
                        <tr>
                          <th className="px-6 py-4 font-medium">Labour</th>
                          <th className="px-6 py-4 font-medium">Daily Wage</th>
                          <th className="px-6 py-4 font-medium">Status</th>
                          <th className="px-6 py-4 font-medium text-right">OT Hours</th>
                          <th className="px-6 py-4 font-medium">Remark</th>
                          <th className="px-6 py-4 font-medium text-right">Day Earnings</th>
                          <th className="px-6 py-4 font-medium">Site</th>
                          <th className="px-6 py-4 font-medium">Via</th>
                        </tr>
                      </thead>
                      <tbody>
                        {alreadyMarked.map(({ rowKey, row, l }) => {
                          
                          const dailyWage = Number(l.dailyWage) || 0;
                          const otRate = Number(l.overtimeWagePerHour) || 0;
                          const otHours = Number(row.overtimeHours) || 0;
                          let dayEarnings = 0;
                          const factor = row.shiftFactor !== undefined ? Number(row.shiftFactor) : (row.status === 'present' ? 1.0 : (row.status === 'half' ? 0.5 : 0.0));
                          if (factor > 0) {
                            dayEarnings = (dailyWage * factor) + (otHours * otRate);
                          }
                          const siteLabel = row.siteId ? (sites.find((s) => s.id === row.siteId)?.name || row.siteId.slice(0, 6) + '…') : '—';

                          return (
                            <tr key={rowKey} className="border-b border-warning/10 last:border-b-0 hover:bg-warning/10 transition-colors">
                              <td className="px-6 py-4">
                                <div className="flex items-center gap-3">
                                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-warning/20 border border-warning/30 text-[12px] font-mono font-medium text-warning">{initials(l.name)}</div>
                                  <div>
                                    <div className="font-medium text-text-primary text-[14px]">{l.name}</div>
                                    {selectedSite && records.filter((r) => r.labourId === l.id && r.siteId !== selectedSite && r.status !== 'pending').map((or) => {
                                      const sName = sites.find((s) => s.id === or.siteId)?.name || or.siteId;
                                      const statusLabel = or.status === 'present' ? 'Present' : or.status === 'half' ? 'Half Day' : or.status;
                                      return (
                                        <div key={or.siteId} className="inline-flex mt-1 items-center rounded bg-warning-bg border border-warning/30 px-1.5 py-0.5 text-[10px] text-warning font-semibold tracking-wide uppercase">
                                          {statusLabel} at {sName}
                                        </div>
                                      );
                                    })}
                                  </div>
                                </div>
                              </td>
                              <td className="px-6 py-4 font-mono text-text-secondary">{formatCurrency(dailyWage)}</td>
                              <td className="px-6 py-4">
                                <div className="flex items-center gap-2">
                                  <button onClick={() => clickStatus(rowKey)} className="inline-block cursor-pointer hover:scale-105 transition-transform">
                                    <StatusBadge status={row.status} />
                                  </button>
                                  <select
                                    value={row.status}
                                    onChange={(e) => {
                                      const targetSiteId = selectedSite ?? row.siteId ?? '';
                                      updateRow(rowKey, { status: e.target.value, siteId: targetSiteId });
                                    }}
                                    className="h-8 rounded-lg border border-warning/30 bg-bg-input px-2 text-[12px] text-text-primary outline-none focus:border-warning transition-colors"
                                  >
                                    {STATUS_OPTIONS.map((o) => (
                                      <option key={o.value} value={o.value} className="bg-bg-input text-text-primary">
                                        {o.label}
                                      </option>
                                    ))}
                                  </select>
                                </div>
                              </td>
                              <td className="px-6 py-4 text-right">
                                {editingOT === rowKey ? (
                                  <Input type="number" min="0" step="0.5" value={row.overtimeHours} onChange={(e) => updateRow(rowKey, { overtimeHours: e.target.value })} onBlur={() => setEditingOT(null)} autoFocus className="h-8 w-20 text-right bg-bg-input border-warning/30 text-[13px]" />
                                ) : (
                                  <button onClick={() => setEditingOT(rowKey)} className="font-mono text-text-secondary hover:text-text-primary hover:underline">{row.overtimeHours}</button>
                                )}
                              </td>
                              <td className="px-6 py-4">
                                {editingRemark === rowKey ? (
                                  <Input type="text" value={row.remark || ''} onChange={(e) => updateRow(rowKey, { remark: e.target.value })} onBlur={() => handleRemarkSave(rowKey)} autoFocus className="h-8 w-40 text-[12px] bg-bg-input border-warning/30" />
                                ) : (
                                  <button onClick={() => setEditingRemark(rowKey)} className="text-[12px] text-text-muted hover:text-text-primary flex items-center gap-1.5 transition-colors">
                                    <MessageSquare className="h-[14px] w-[14px]" />
                                    <span className="max-w-[120px] truncate">{row.remark || '—'}</span>
                                  </button>
                                )}
                              </td>
                              <td className="px-6 py-4 text-right font-mono font-medium text-text-primary">{formatCurrency(dayEarnings)}</td>
                              <td className="px-6 py-4 text-[12px] font-mono text-text-muted">{siteLabel}</td>
                              <td className="px-6 py-4"><MarkedViaBadge via={row.markedVia} /></td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )}

            {displayRows.length === 0 && (
              <p className="py-10 text-center text-[13px] text-text-muted">No labours match the current filters.</p>
            )}
          </>
        )}
      </div>

      {/* ── DAILY WORK ENTRIES (TEMP) ─────────────────────────────────────────────── */}
      {tempLabours.length > 0 && (
        <div className="rounded-xl border border-border bg-bg-card overflow-hidden">
          <div className="px-5 pt-5 pb-3 flex items-center gap-3 bg-purple-500/5">
            <span className="text-[11px] font-bold uppercase tracking-[1.5px] text-purple-400">
              Daily Work Entries — {tempLabours.length}
            </span>
            <div className="h-[1px] flex-1 bg-purple-500/20" />
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-[13px] whitespace-nowrap">
              <thead className="border-y border-border bg-bg-elevated text-left text-[10px] uppercase tracking-widest text-text-muted">
                <tr>
                  <th className="px-5 py-3 font-medium">Worker</th>
                  <th className="px-5 py-3 font-medium">Shift</th>
                  <th className="px-5 py-3 font-medium text-right">Wage</th>
                  <th className="px-5 py-3 font-medium">Site</th>
                  <th className="px-5 py-3 font-medium text-center">Status</th>
                  <th className="px-5 py-3 font-medium">Remarks</th>
                  <th className="px-5 py-3 font-medium"></th>
                </tr>
              </thead>
              <tbody>
                {tempLabours.map((t) => (
                  <tr key={t.id} className="border-b border-border/50 hover:bg-bg-elevated transition-colors">
                    <td className="px-5 py-4 font-medium text-text-primary flex items-center gap-2">
                      <span className="inline-block px-1.5 py-0.5 rounded text-[9px] font-bold bg-purple-500/20 text-purple-400 uppercase">TEMP</span>
                      {t.name}
                    </td>
                    <td className="px-5 py-4">{t.attendanceUnit} Day</td>
                    <td className="px-5 py-4 text-right font-mono font-medium">{formatCurrency(t.totalWage || (t.wage * t.attendanceUnit))}</td>
                    <td className="px-5 py-4 text-text-secondary">{t.siteId ? (sites.find((s) => s.id === t.siteId)?.name || '...') : '—'}</td>
                    <td className="px-5 py-4 text-center">
                      <div className="flex flex-col items-center gap-1">
                        <span className={`inline-block px-2 py-0.5 rounded text-[10px] font-bold ${t.paymentStatus === 'paid' ? 'bg-success/20 text-success' : t.paymentStatus === 'partial_paid' ? 'bg-orange-500/20 text-orange-400' : 'bg-danger/20 text-danger'}`}>
                          {t.paymentStatus?.replace('_', ' ').toUpperCase() || 'UNPAID'}
                        </span>
                        {t.paidAmount > 0 && <span className="text-[10px] text-text-muted font-mono">{formatCurrency(t.paidAmount)}</span>}
                      </div>
                    </td>
                    <td className="px-5 py-4 text-text-muted italic text-[11px]">{t.remarks || '—'}</td>
                    <td className="px-5 py-4 text-right">
                      <button onClick={() => handleDeleteTempLabour(t.id)} className="text-danger hover:text-red-400 p-1">
                        <X className="h-4 w-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

    </div>
  );
}
