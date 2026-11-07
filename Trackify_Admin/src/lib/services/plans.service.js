import {
  collection,
  doc,
  getDoc,
  getDocs,
  addDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  onSnapshot,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from '../firebase';

// Helper to safely extract Date or string
export const safeDate = (timestamp) => {
  if (!timestamp) return null;
  if (typeof timestamp.toDate === 'function') return timestamp.toDate();
  if (timestamp instanceof Date) return timestamp;
  return new Date(timestamp);
};

/**
 * Extracts only the main important plan name, stripping out any customer/first names.
 * e.g. "01-SHAILESHBHAI KATSWEL-FINAL PLAN" -> "01-FINAL PLAN"
 * e.g. "01-TANVIR-FINAL PLAN" -> "01-FINAL PLAN"
 * e.g. "02-TANVIR-CENTER LINE" -> "02-CENTER LINE"
 */
export function extractMainPlanName(rawName) {
  if (!rawName) return '';
  const parts = rawName.split('-').map((s) => s.trim());
  if (parts.length >= 3) {
    const num = parts[0].padStart(2, '0');
    // Strip client/first name in parts[1], take the main plan from parts[2..]
    const mainPlan = parts.slice(2).join('-');
    return `${num}-${mainPlan}`;
  } else if (parts.length === 2 && /^\d+$/.test(parts[0])) {
    return `${parts[0].padStart(2, '0')}-${parts[1]}`;
  }
  return rawName.replace(/\s*-\s*/g, '-');
}

/**
 * Returns strictly the main plan name without numbers or customer name (e.g. "FINAL PLAN", "CENTER LINE").
 */
export function extractPureMainName(rawName) {
  if (!rawName) return '';
  const parts = rawName.split('-').map((s) => s.trim());
  if (parts.length >= 3) {
    return parts.slice(2).join('-');
  } else if (parts.length === 2) {
    if (/^\d+$/.test(parts[0])) return parts[1];
    return parts[1];
  }
  return rawName.replace(/^\d+[\s._-]+/, '').trim();
}

/**
 * Returns formatted Windows file name for the client (e.g. "01-TANVIR-FINAL PLAN")
 */
export function formatWindowsFileName(rawName, ownerName, numPrefix) {
  const main = extractPureMainName(rawName);
  const cleanOwner = (ownerName || 'CLIENT').trim().toUpperCase().replace(/[^A-Z0-9\s]/g, '');
  const num = (numPrefix || rawName.match(/^\d+/)?.[0] || '01').padStart(2, '0');
  return `${num}-${cleanOwner}-${main}`;
}

// ==========================================
// DEFAULT 21 MASTER PLANS CATALOG (FROM ER DIRECTORY + EXTENDED)
// Exact format: 01-FINAL PLAN, 02-CENTER LINE, etc. (No customer name in list)
// ==========================================
export const DEFAULT_MASTER_PLANS = [
  { id: '01_final_plan', num: '01', name: '01-FINAL PLAN', mainName: 'FINAL PLAN', category: 'Architectural', desc: 'Final approved architectural plan' },
  { id: '02_center_line', num: '02', name: '02-CENTER LINE', mainName: 'CENTER LINE', category: 'Structural', desc: 'Column center line marking layout' },
  { id: '03_foundation_plan_details', num: '03', name: '03-FOUNDATION PLAN DETAILS', mainName: 'FOUNDATION PLAN DETAILS', category: 'Structural', desc: 'Foundation excavation & rebar plan' },
  { id: '04_footing_typical_2', num: '04', name: '04-FOOTING TYPICAL (2)', mainName: 'FOOTING TYPICAL (2)', category: 'Structural', desc: 'Secondary footing section & schedule' },
  { id: '05_footing_typical', num: '05', name: '05-FOOTING TYPICAL', mainName: 'FOOTING TYPICAL', category: 'Structural', desc: 'Typical footing section & rebar schedule' },
  { id: '06_ground_beams_details', num: '06', name: '06-GROUND BEAMS DETAILS', mainName: 'GROUND BEAMS DETAILS', category: 'Structural', desc: 'Ground tie beams reinforcement layout' },
  { id: '07_plinth_beams_details', num: '07', name: '07-PLINTH BEAMS DETAILS', mainName: 'PLINTH BEAMS DETAILS', category: 'Structural', desc: 'Plinth level beam rebar & casting drawings' },
  { id: '08_front_side_elevation', num: '08', name: '08-FRONT SIDE ELEVATION', mainName: 'FRONT SIDE ELEVATION', category: '3D & Design', desc: 'Front architectural elevation & exterior design' },
  { id: '09_right_side_elevation', num: '09', name: '09-RIGHT SIDE ELEVATION', mainName: 'RIGHT SIDE ELEVATION', category: '3D & Design', desc: 'Right elevation drawing & exterior details' },
  { id: '10_left_side_elevation', num: '10', name: '10-LEFT SIDE ELEVATION', mainName: 'LEFT SIDE ELEVATION', category: '3D & Design', desc: 'Left elevation drawing & exterior details' },
  { id: '11_gf_working', num: '11', name: '11-GF WORKING', mainName: 'GF WORKING', category: 'Architectural', desc: 'Ground floor architectural working layout' },
  { id: '12_gf_slab_beams_details', num: '12', name: '12-GROUND FLOOR SLAB AND BEAMS DETAILS', mainName: 'GROUND FLOOR SLAB AND BEAMS DETAILS', category: 'Structural', desc: 'Ground floor roof slab casting & beam schedule' },
  { id: '13_gf_electric', num: '13', name: '13-GF ELECTRIC', mainName: 'GF ELECTRIC', category: 'Services', desc: 'Ground floor conduits, switches & electrical layout' },
  { id: '14_ff_working', num: '14', name: '14-FF WORKING', mainName: 'FF WORKING', category: 'Architectural', desc: 'First floor architectural working layout' },
  { id: '15_ff_slab_beams_details', num: '15', name: '15-FIRST FLOOR SLAB AND BEAMS DETAILS', mainName: 'FIRST FLOOR SLAB AND BEAMS DETAILS', category: 'Structural', desc: 'First floor roof slab casting & beam schedule' },
  { id: '16_ff_electric', num: '16', name: '16-FF ELECTRIC', mainName: 'FF ELECTRIC', category: 'Services', desc: 'First floor conduits, switches & electrical layout' },
  { id: '17_plumbing_details', num: '17', name: '17-PLUMBING DETAILS', mainName: 'PLUMBING DETAILS', category: 'Services', desc: 'Plumbing, drainage & sanitary line layout' },
  { id: '18_gf_lintel_details', num: '18', name: '18-GF Lintel Details', mainName: 'GF Lintel Details', category: 'Structural', desc: 'Ground floor lintel beam rebar details' },
  { id: '19_ff_lintel_details', num: '19', name: '19-FF Lintel Details', mainName: 'FF Lintel Details', category: 'Structural', desc: 'First floor lintel beam rebar details' },
  { id: '20_passing_plan', num: '20', name: '20-Passing Plan', mainName: 'Passing Plan', category: 'Municipal', desc: 'Authority / Municipal passing sanction plan' },
  { id: '21_loan_estimate', num: '21', name: '21-Loan Estimate', mainName: 'Loan Estimate', category: 'Services', desc: 'Bank loan valuation & estimate sheet' },
  { id: '22_door_details', num: '22', name: '22-Door Details', mainName: 'Door Details', category: 'Architectural', desc: 'Door and window schedule & joinery details' },
];

// ==========================================
// HOUSE PLANS SERVICE
// ==========================================

/**
 * Real-time listener for house plans belonging to a contractor
 */
export function subscribeHousePlans(contractorId, callback, onError) {
  if (!contractorId) {
    callback([]);
    return () => {};
  }

  const q = query(
    collection(db, 'house_plans'),
    where('contractorId', '==', contractorId)
  );

  return onSnapshot(
    q,
    (snapshot) => {
      const plans = [];
      snapshot.docs.forEach((docSnap) => {
        // Skip master catalog configuration doc
        if (docSnap.id.startsWith('_catalog_') || docSnap.data().isCatalogDoc) {
          return;
        }

        const data = docSnap.data();
        const payments = Array.isArray(data.payments) ? data.payments : [];
        const siteVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];
        const rawPlans = Array.isArray(data.plansList) ? data.plansList : [];

        // Auto-clean plan names to remove any client names (e.g. "01-TANVIR-FINAL PLAN" -> "01-FINAL PLAN")
        const plansList = rawPlans.map((p) => ({
          ...p,
          name: extractMainPlanName(p.name) || p.name,
        }));

        // Compute total paid, site visits, and pending balance (resilient to empty payments array)
        const paymentsSum = payments.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
        const totalPaid = paymentsSum > 0 ? paymentsSum : (Number(data.totalPaid) || 0);
        const houseAmount = Number(data.houseAmount) || 0;
        const totalVisitsAmount = siteVisits.reduce((sum, v) => sum + (Number(v.amount) || 0), 0);
        const totalBillableAmount = houseAmount + totalVisitsAmount;
        const pendingBalance = Math.max(0, totalBillableAmount - totalPaid);

        // Auto-synthesize a payment item if totalPaid > 0 but payments array is empty
        const effectivePayments = payments.length > 0
          ? payments
          : (totalPaid > 0
              ? [{
                  id: `pay_record_${docSnap.id}`,
                  installmentName: totalPaid >= houseAmount ? 'Full Plan Fee (100% Cleared)' : 'Advance Booking Payment',
                  type: totalPaid >= houseAmount ? 'final' : 'advance',
                  amount: totalPaid,
                  date: safeDate(data.updatedAt)?.toISOString().split('T')[0] || safeDate(data.createdAt)?.toISOString().split('T')[0] || new Date().toISOString().split('T')[0],
                  mode: 'UPI',
                  notes: 'Recorded plan payment',
                  recordedAt: new Date().toISOString(),
                }]
              : []);

        // Compute completed plans count
        const completedPlansCount = plansList.filter((p) => p.status === 'completed').length;

        plans.push({
          id: docSnap.id,
          ...data,
          payments: effectivePayments,
          siteVisits,
          plansList,
          houseAmount,
          totalPaid,
          totalVisitsAmount,
          totalBillableAmount,
          pendingBalance,
          completedPlansCount,
          createdAt: safeDate(data.createdAt),
          updatedAt: safeDate(data.updatedAt),
        });
      });

      // Sort newest first
      plans.sort((a, b) => {
        const timeA = a.createdAt ? a.createdAt.getTime() : 0;
        const timeB = b.createdAt ? b.createdAt.getTime() : 0;
        return timeB - timeA;
      });

      callback(plans);
    },
    (err) => {
      console.error('Error subscribing to house plans:', err);
      if (onError) onError(err);
    }
  );
}

/**
 * Fetch a single house plan by ID
 */
export async function getHousePlan(planId) {
  if (!planId) return null;
  const snap = await getDoc(doc(db, 'house_plans', planId));
  if (!snap.exists()) return null;
  const data = snap.data();
  const payments = Array.isArray(data.payments) ? data.payments : [];
  const siteVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];
  const rawPlans = Array.isArray(data.plansList) ? data.plansList : [];
  const plansList = rawPlans.map((p) => ({
    ...p,
    name: extractMainPlanName(p.name) || p.name,
  }));
  const paymentsSum = payments.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
  const totalPaid = paymentsSum > 0 ? paymentsSum : (Number(data.totalPaid) || 0);
  const houseAmount = Number(data.houseAmount) || 0;
  const totalVisitsAmount = siteVisits.reduce((sum, v) => sum + (Number(v.amount) || 0), 0);
  const totalBillableAmount = houseAmount + totalVisitsAmount;
  const pendingBalance = Math.max(0, totalBillableAmount - totalPaid);
  const effectivePayments = payments.length > 0
    ? payments
    : (totalPaid > 0
        ? [{
            id: `pay_record_${snap.id}`,
            installmentName: totalPaid >= houseAmount ? 'Full Plan Fee (100% Cleared)' : 'Advance Booking Payment',
            type: totalPaid >= houseAmount ? 'final' : 'advance',
            amount: totalPaid,
            date: safeDate(data.updatedAt)?.toISOString().split('T')[0] || new Date().toISOString().split('T')[0],
            mode: 'UPI',
            notes: 'Recorded plan payment',
            recordedAt: new Date().toISOString(),
          }]
        : []);

  return {
    id: snap.id,
    ...data,
    payments: effectivePayments,
    siteVisits,
    plansList,
    houseAmount,
    totalPaid,
    totalVisitsAmount,
    totalBillableAmount,
    pendingBalance,
    completedPlansCount: plansList.filter((p) => p.status === 'completed').length,
    createdAt: safeDate(data.createdAt),
    updatedAt: safeDate(data.updatedAt),
  };
}

/**
 * Create a new house plan owner record
 */
export async function addHousePlan(planData) {
  if (!planData.contractorId) {
    throw new Error('contractorId is required to save a house plan');
  }

  const initialPlans = Array.isArray(planData.plansList) ? planData.plansList : [];
  const initialPayments = Array.isArray(planData.payments) ? planData.payments : [];
  const initialVisits = Array.isArray(planData.siteVisits) ? planData.siteVisits : [];

  const houseAmount = Number(planData.houseAmount) || 0;
  const totalVisitsAmount = initialVisits.reduce((sum, v) => sum + (Number(v.amount) || 0), 0);
  const totalBillableAmount = houseAmount + totalVisitsAmount;
  const totalPaid = initialPayments.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);

  const payload = {
    contractorId: planData.contractorId,
    // Owner Details
    ownerName: planData.ownerName?.trim() || '',
    ownerPhone: planData.ownerPhone?.trim() || '',
    ownerEmail: planData.ownerEmail?.trim() || '',
    ownerAddress: planData.ownerAddress?.trim() || '',
    city: planData.city?.trim() || planData.town?.trim() || '',
    town: planData.town?.trim() || planData.city?.trim() || '',

    // Plan & 3D Identifiers
    planNumber: planData.planNumber?.trim() || '',
    serialNumber3D: planData.serialNumber3D?.trim() || '',
    title: planData.title?.trim() || '',

    // Area & Valuation
    totalSqFt: Number(planData.totalSqFt) || 0,
    plotAreaSqFt: Number(planData.plotAreaSqFt) || 0,
    houseAmount,
    ratePerSqFt: Number(planData.ratePerSqFt) || 0,
    totalVisitsAmount,
    totalBillableAmount,
    totalPaid,
    pendingBalance: Math.max(0, totalBillableAmount - totalPaid),

    // Structural & Architectural Specs
    floors: planData.floors || 'G+1',
    facing: planData.facing || 'East',
    bhk: planData.bhk || '3 BHK',
    planType: planData.planType || '3D Elevation Plan',
    status: planData.status || 'in_progress',

    // Engineer ("Er.") Details
    engineerName: planData.engineerName?.trim() || '',
    engineerPhone: planData.engineerPhone?.trim() || '',
    engineerNotes: planData.engineerNotes?.trim() || '',

    // Dynamic Plans Checklist for this owner
    plansList: initialPlans,

    // Self-contained Payments for this owner
    payments: initialPayments,

    // Site / House Visits Ledger for this owner
    siteVisits: initialVisits,

    // Optional 3D Model / Drawing link or file URL
    fileUrl: planData.fileUrl?.trim() || '',

    // System audit fields
    createdBy: planData.createdBy || '',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const docRef = await addDoc(collection(db, 'house_plans'), payload);
  await updateDoc(docRef, { id: docRef.id });
  return docRef.id;
}

/**
 * Update an existing house plan record
 */
export async function updateHousePlan(planId, updates) {
  if (!planId) throw new Error('planId is required for update');

  const cleanUpdates = { ...updates };
  delete cleanUpdates.id;
  delete cleanUpdates.createdAt;

  if (cleanUpdates.totalSqFt !== undefined) {
    cleanUpdates.totalSqFt = Number(cleanUpdates.totalSqFt) || 0;
  }
  if (cleanUpdates.plotAreaSqFt !== undefined) {
    cleanUpdates.plotAreaSqFt = Number(cleanUpdates.plotAreaSqFt) || 0;
  }
  if (cleanUpdates.houseAmount !== undefined) {
    cleanUpdates.houseAmount = Number(cleanUpdates.houseAmount) || 0;
  }
  if (cleanUpdates.ratePerSqFt !== undefined) {
    cleanUpdates.ratePerSqFt = Number(cleanUpdates.ratePerSqFt) || 0;
  }

  // Recalculate financial balance if houseAmount, siteVisits, or payments are being updated
  if (cleanUpdates.houseAmount !== undefined || cleanUpdates.payments !== undefined || cleanUpdates.siteVisits !== undefined) {
    const currentSnap = await getDoc(doc(db, 'house_plans', planId));
    const currentData = currentSnap.data() || {};
    const effectiveAmount = cleanUpdates.houseAmount !== undefined ? cleanUpdates.houseAmount : Number(currentData.houseAmount || 0);
    const effectiveVisits = cleanUpdates.siteVisits !== undefined ? cleanUpdates.siteVisits : (currentData.siteVisits || []);
    const effectivePayments = cleanUpdates.payments !== undefined ? cleanUpdates.payments : (currentData.payments || []);

    const totalVisitsAmount = effectiveVisits.reduce((s, v) => s + (Number(v.amount) || 0), 0);
    const totalBillableAmount = effectiveAmount + totalVisitsAmount;
    const paymentsSum = effectivePayments.reduce((s, p) => s + (Number(p.amount) || 0), 0);
    const totalPaid = paymentsSum > 0 ? paymentsSum : (cleanUpdates.totalPaid !== undefined ? Number(cleanUpdates.totalPaid) : (Number(currentData.totalPaid) || 0));

    cleanUpdates.totalVisitsAmount = totalVisitsAmount;
    cleanUpdates.totalBillableAmount = totalBillableAmount;
    cleanUpdates.totalPaid = totalPaid;
    cleanUpdates.pendingBalance = Math.max(0, totalBillableAmount - totalPaid);

    if (totalPaid >= totalBillableAmount && totalBillableAmount > 0) {
      cleanUpdates.paymentStatus = 'completed';
    } else if (totalPaid >= totalBillableAmount * 0.5 && totalBillableAmount > 0) {
      cleanUpdates.paymentStatus = 'half_paid';
    } else if (totalPaid > 0) {
      cleanUpdates.paymentStatus = 'advance_received';
    } else {
      cleanUpdates.paymentStatus = 'pending';
    }
  }

  const payload = {
    ...cleanUpdates,
    updatedAt: serverTimestamp(),
  };

  await updateDoc(doc(db, 'house_plans', planId), payload);
}

/**
 * Delete a house plan record
 */
export async function deleteHousePlan(planId) {
  if (!planId) throw new Error('planId is required for deletion');
  await deleteDoc(doc(db, 'house_plans', planId));
}

// ==========================================
// OWNER-SPECIFIC PLANS WORKFLOW (ADD/UPDATE/DELETE/STATUS)
// ==========================================

/**
 * Add a new plan to this specific owner
 */
export async function addPlanToOwner(ownerId, planItem) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPlans = Array.isArray(data.plansList) ? data.plansList : [];

  const cleanName = extractMainPlanName(planItem.name?.trim()) || 'New Plan';
  let numMatch = planItem.num || cleanName.match(/^(\d+)/)?.[1] || '';
  if (!numMatch) {
    numMatch = String(currentPlans.length + 1).padStart(2, '0');
  }
  const newPlan = {
    id: `plan_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
    num: numMatch,
    name: cleanName.match(/^\d+/) ? cleanName : `${numMatch}-${cleanName}`,
    category: planItem.category || 'Architectural',
    status: planItem.status || 'not_started', // 'not_started' | 'pending' | 'in_progress' | 'completed'
    notes: planItem.notes?.trim() || '',
    fileUrl: planItem.fileUrl?.trim() || '',
    createdAt: new Date().toISOString(),
    completedDate: planItem.status === 'completed' ? new Date().toISOString().split('T')[0] : null,
  };

  const updatedPlans = [...currentPlans, newPlan];

  await updateDoc(doc(db, 'house_plans', ownerId), {
    plansList: updatedPlans,
    updatedAt: serverTimestamp(),
  });

  return newPlan;
}

/**
 * Add multiple plans to an owner in a single atomic update.
 * Useful for selectively adding 1, 2, or multiple missing drawings from the catalog.
 */
export async function addMultiplePlansToOwner(ownerId, planItems) {
  if (!ownerId) throw new Error('ownerId is required');
  if (!Array.isArray(planItems) || planItems.length === 0) return [];

  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPlans = Array.isArray(data.plansList) ? data.plansList : [];

  const newPlans = planItems.map((planItem, idx) => {
    const cleanName = extractMainPlanName(planItem.name?.trim()) || 'New Plan';
    let numMatch = planItem.num || cleanName.match(/^(\d+)/)?.[1] || '';
    if (!numMatch) {
      numMatch = String(currentPlans.length + idx + 1).padStart(2, '0');
    }
    return {
      id: `plan_${Date.now()}_${idx}_${Math.random().toString(36).substring(2, 7)}`,
      num: numMatch,
      name: cleanName.match(/^\d+/) ? cleanName : `${numMatch}-${cleanName}`,
      category: planItem.category || 'Architectural',
      status: planItem.status || 'not_started',
      notes: planItem.notes?.trim() || '',
      fileUrl: planItem.fileUrl?.trim() || '',
      createdAt: new Date().toISOString(),
      completedDate: planItem.status === 'completed' ? new Date().toISOString().split('T')[0] : null,
    };
  });

  const updatedPlans = [...currentPlans, ...newPlans];

  await updateDoc(doc(db, 'house_plans', ownerId), {
    plansList: updatedPlans,
    updatedAt: serverTimestamp(),
  });

  return newPlans;
}

/**
 * Renumbers all drawings of an owner sequentially (01, 02, ... N)
 * and repairs any duplicate '01' or missing numbers in Firestore.
 */
export async function renumberOwnerPlans(ownerId) {
  if (!ownerId) throw new Error('ownerId is required');
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPlans = Array.isArray(data.plansList) ? data.plansList : [];
  if (currentPlans.length === 0) return [];

  const updatedPlans = currentPlans.map((plan, idx) => {
    const seqNum = String(idx + 1).padStart(2, '0');
    const cleanMain = extractPureMainName(plan.name) || plan.name;
    return {
      ...plan,
      num: seqNum,
      name: `${seqNum}-${cleanMain}`,
      mainName: cleanMain,
    };
  });

  await updateDoc(doc(db, 'house_plans', ownerId), {
    plansList: updatedPlans,
    updatedAt: serverTimestamp(),
  });

  return updatedPlans;
}

/**
 * Resets / Syncs an owner's checklist to the EXACT 21 engineering plans,
 * removing any old/duplicate plans and removing any client names.
 */
export async function resetOwnerPlansToExact21(ownerId) {
  if (!ownerId) throw new Error('ownerId is required');
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const currentPlans = Array.isArray(snap.data().plansList) ? snap.data().plansList : [];
  const completedNums = new Set(
    currentPlans
      .filter((p) => p.status === 'completed')
      .map((p) => p.num || p.name.match(/^(\d+)/)?.[1])
      .filter(Boolean)
  );

  const exact21List = DEFAULT_MASTER_PLANS.map((template) => ({
    id: `plan_${Date.now()}_${template.num}`,
    num: template.num,
    name: template.name, // e.g. "01-FINAL PLAN"
    category: template.category,
    status: completedNums.has(template.num) ? 'completed' : 'not_started',
    createdAt: new Date().toISOString(),
    completedDate: completedNums.has(template.num) ? new Date().toISOString().split('T')[0] : null,
  }));

  await updateDoc(doc(db, 'house_plans', ownerId), {
    plansList: exact21List,
    updatedAt: serverTimestamp(),
  });

  return exact21List;
}

// Backward-compatible alias
export const resetOwnerPlansToExact16 = resetOwnerPlansToExact21;

/**
 * Update an existing plan inside this specific owner
 */
export async function updatePlanInOwner(ownerId, planItemId, updates) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPlans = Array.isArray(data.plansList) ? data.plansList : [];

  const updatedPlans = currentPlans.map((p) => {
    if (p.id === planItemId) {
      const isNowCompleted = updates.status === 'completed';
      return {
        ...p,
        ...updates,
        completedDate: isNowCompleted ? (p.completedDate || new Date().toISOString().split('T')[0]) : (updates.status ? null : p.completedDate),
      };
    }
    return p;
  });

  await updateDoc(doc(db, 'house_plans', ownerId), {
    plansList: updatedPlans,
    updatedAt: serverTimestamp(),
  });
}

/**
 * Admin Two-Factor Verification: Approve a specific plan modified by a supervisor
 */
export async function verifyPlanInOwner(ownerId, planItemId, adminUser) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPlans = Array.isArray(data.plansList) ? data.plansList : [];
  const currentVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];
  const nowIso = new Date().toISOString();

  const updatedPlans = currentPlans.map((p) => {
    if (p.id === planItemId) {
      return {
        ...p,
        verificationStatus: 'verified',
        verifiedBy: adminUser?.name || 'Admin',
        verifiedByUid: adminUser?.uid || '',
        verifiedAt: nowIso,
      };
    }
    return p;
  });

  const stillHasPendingPlans = updatedPlans.some((p) => p.verificationStatus === 'pending_admin_verification');
  const stillHasPendingVisits = currentVisits.some((v) => v.verificationStatus === 'pending_admin_verification');
  const hasPending = stillHasPendingPlans || stillHasPendingVisits;

  await updateDoc(doc(db, 'house_plans', ownerId), {
    plansList: updatedPlans,
    hasPendingSupervisorChanges: hasPending,
    ...(!hasPending ? { lastSupervisorAction: null } : {}),
    updatedAt: serverTimestamp(),
  });
}

/**
 * Admin Two-Factor Verification: Revert a drawing status change made by supervisor
 */
export async function revertPlanInOwner(ownerId, planItemId, adminUser) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPlans = Array.isArray(data.plansList) ? data.plansList : [];
  const currentVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];
  const nowIso = new Date().toISOString();

  const updatedPlans = currentPlans.map((p) => {
    if (p.id === planItemId) {
      const revertedStatus = p.status === 'completed' ? 'in_progress' : 'in_progress';
      return {
        ...p,
        status: revertedStatus,
        completedDate: null,
        verificationStatus: 'verified',
        verifiedBy: adminUser?.name || 'Admin',
        verifiedByUid: adminUser?.uid || '',
        verifiedAt: nowIso,
        revertedAt: nowIso,
      };
    }
    return p;
  });

  const stillHasPendingPlans = updatedPlans.some((p) => p.verificationStatus === 'pending_admin_verification');
  const stillHasPendingVisits = currentVisits.some((v) => v.verificationStatus === 'pending_admin_verification');
  const hasPending = stillHasPendingPlans || stillHasPendingVisits;

  await updateDoc(doc(db, 'house_plans', ownerId), {
    plansList: updatedPlans,
    hasPendingSupervisorChanges: hasPending,
    ...(!hasPending ? { lastSupervisorAction: null } : {}),
    updatedAt: serverTimestamp(),
  });
}

/**
 * Admin Two-Factor Verification: Approve a site visit logged by a supervisor
 */
export async function verifySiteVisitInOwner(ownerId, visitId, adminUser) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPlans = Array.isArray(data.plansList) ? data.plansList : [];
  const currentVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];
  const nowIso = new Date().toISOString();

  const updatedVisits = currentVisits.map((v) => {
    if (v.id === visitId) {
      return {
        ...v,
        verificationStatus: 'verified',
        verifiedBy: adminUser?.name || 'Admin',
        verifiedByUid: adminUser?.uid || '',
        verifiedAt: nowIso,
      };
    }
    return v;
  });

  const stillHasPendingPlans = currentPlans.some((p) => p.verificationStatus === 'pending_admin_verification');
  const stillHasPendingVisits = updatedVisits.some((v) => v.verificationStatus === 'pending_admin_verification');
  const hasPending = stillHasPendingPlans || stillHasPendingVisits;

  await updateDoc(doc(db, 'house_plans', ownerId), {
    siteVisits: updatedVisits,
    hasPendingSupervisorChanges: hasPending,
    ...(!hasPending ? { lastSupervisorAction: null } : {}),
    updatedAt: serverTimestamp(),
  });
}

/**
 * Admin Two-Factor Verification: Approve ALL pending changes (plans + visits) for an owner
 */
export async function verifyAllPendingInOwner(ownerId, adminUser) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPlans = Array.isArray(data.plansList) ? data.plansList : [];
  const currentVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];
  const nowIso = new Date().toISOString();

  const updatedPlans = currentPlans.map((p) => {
    if (p.verificationStatus === 'pending_admin_verification') {
      return {
        ...p,
        verificationStatus: 'verified',
        verifiedBy: adminUser?.name || 'Admin',
        verifiedByUid: adminUser?.uid || '',
        verifiedAt: nowIso,
      };
    }
    return p;
  });

  const updatedVisits = currentVisits.map((v) => {
    if (v.verificationStatus === 'pending_admin_verification') {
      return {
        ...v,
        verificationStatus: 'verified',
        verifiedBy: adminUser?.name || 'Admin',
        verifiedByUid: adminUser?.uid || '',
        verifiedAt: nowIso,
      };
    }
    return v;
  });

  await updateDoc(doc(db, 'house_plans', ownerId), {
    plansList: updatedPlans,
    siteVisits: updatedVisits,
    hasPendingSupervisorChanges: false,
    lastSupervisorAction: null,
    lastAdminVerifiedAt: serverTimestamp(),
    lastAdminVerifiedBy: adminUser?.name || 'Admin',
    updatedAt: serverTimestamp(),
  });
}

/**
 * Toggle plan status (e.g. Quick Mark Complete / Pending)
 */
export async function togglePlanStatus(ownerId, planItemId, currentStatus) {
  const nextStatus = currentStatus === 'completed' ? 'pending' : 'completed';
  await updatePlanInOwner(ownerId, planItemId, { status: nextStatus });
}

/**
 * Delete a plan from this specific owner
 */
export async function deletePlanFromOwner(ownerId, planItemId) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPlans = Array.isArray(data.plansList) ? data.plansList : [];
  const updatedPlans = currentPlans.filter((p) => p.id !== planItemId);

  await updateDoc(doc(db, 'house_plans', ownerId), {
    plansList: updatedPlans,
    updatedAt: serverTimestamp(),
  });
}

// ==========================================
// OWNER-SPECIFIC PAYMENTS (NO MIXING WITH OTHER CLIENTS)
// ==========================================

/**
 * Add a payment installment to this specific owner
 */
export async function addPaymentToOwner(ownerId, paymentItem) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPayments = Array.isArray(data.payments) ? data.payments : [];
  const siteVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];

  const newPayment = {
    id: `pay_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
    installmentName: paymentItem.installmentName?.trim() || 'Part Payment',
    type: paymentItem.type || 'part', // 'advance' | 'half_payment' | 'part' | 'final'
    amount: Number(paymentItem.amount) || 0,
    date: paymentItem.date || new Date().toISOString().split('T')[0],
    mode: paymentItem.mode || 'UPI', // 'Cash' | 'UPI' | 'Cheque' | 'Bank Transfer'
    referenceNo: paymentItem.referenceNo?.trim() || '',
    notes: paymentItem.notes?.trim() || '',
    recordedAt: new Date().toISOString(),
  };

  const updatedPayments = [...currentPayments, newPayment];
  const totalPaid = updatedPayments.reduce((s, p) => s + (Number(p.amount) || 0), 0);
  const houseAmount = Number(data.houseAmount) || 0;
  const totalVisitsAmount = siteVisits.reduce((s, v) => s + (Number(v.amount) || 0), 0);
  const totalBillableAmount = houseAmount + totalVisitsAmount;
  const pendingBalance = Math.max(0, totalBillableAmount - totalPaid);

  // Derive payment status
  let paymentStatus = 'pending';
  if (totalPaid >= totalBillableAmount && totalBillableAmount > 0) {
    paymentStatus = 'completed';
  } else if (totalPaid >= totalBillableAmount * 0.5 && totalBillableAmount > 0) {
    paymentStatus = 'half_paid';
  } else if (totalPaid > 0) {
    paymentStatus = 'advance_received';
  }

  await updateDoc(doc(db, 'house_plans', ownerId), {
    payments: updatedPayments,
    totalPaid,
    totalVisitsAmount,
    totalBillableAmount,
    pendingBalance,
    paymentStatus,
    updatedAt: serverTimestamp(),
  });

  return newPayment;
}

/**
 * Update an existing payment inside this specific owner
 */
export async function updatePaymentInOwner(ownerId, paymentId, updates) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPayments = Array.isArray(data.payments) ? data.payments : [];
  const siteVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];

  const updatedPayments = currentPayments.map((p) => {
    if (p.id === paymentId) {
      return {
        ...p,
        ...updates,
        amount: updates.amount !== undefined ? Number(updates.amount) : p.amount,
      };
    }
    return p;
  });

  const totalPaid = updatedPayments.reduce((s, p) => s + (Number(p.amount) || 0), 0);
  const houseAmount = Number(data.houseAmount) || 0;
  const totalVisitsAmount = siteVisits.reduce((s, v) => s + (Number(v.amount) || 0), 0);
  const totalBillableAmount = houseAmount + totalVisitsAmount;
  const pendingBalance = Math.max(0, totalBillableAmount - totalPaid);

  let paymentStatus = 'pending';
  if (totalPaid >= totalBillableAmount && totalBillableAmount > 0) {
    paymentStatus = 'completed';
  } else if (totalPaid >= totalBillableAmount * 0.5 && totalBillableAmount > 0) {
    paymentStatus = 'half_paid';
  } else if (totalPaid > 0) {
    paymentStatus = 'advance_received';
  }

  await updateDoc(doc(db, 'house_plans', ownerId), {
    payments: updatedPayments,
    totalPaid,
    totalVisitsAmount,
    totalBillableAmount,
    pendingBalance,
    paymentStatus,
    updatedAt: serverTimestamp(),
  });
}

/**
 * Delete a payment from this specific owner
 */
export async function deletePaymentFromOwner(ownerId, paymentId) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentPayments = Array.isArray(data.payments) ? data.payments : [];
  const siteVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];
  const updatedPayments = currentPayments.filter((p) => p.id !== paymentId);

  const totalPaid = updatedPayments.reduce((s, p) => s + (Number(p.amount) || 0), 0);
  const houseAmount = Number(data.houseAmount) || 0;
  const totalVisitsAmount = siteVisits.reduce((s, v) => s + (Number(v.amount) || 0), 0);
  const totalBillableAmount = houseAmount + totalVisitsAmount;
  const pendingBalance = Math.max(0, totalBillableAmount - totalPaid);

  let paymentStatus = 'pending';
  if (totalPaid >= totalBillableAmount && totalBillableAmount > 0) {
    paymentStatus = 'completed';
  } else if (totalPaid >= totalBillableAmount * 0.5 && totalBillableAmount > 0) {
    paymentStatus = 'half_paid';
  } else if (totalPaid > 0) {
    paymentStatus = 'advance_received';
  }

  await updateDoc(doc(db, 'house_plans', ownerId), {
    payments: updatedPayments,
    totalPaid,
    totalVisitsAmount,
    totalBillableAmount,
    pendingBalance,
    paymentStatus,
    updatedAt: serverTimestamp(),
  });
}

// ==========================================
// OWNER-SPECIFIC SITE / HOUSE VISITS LEDGER (ER SITE VISITS)
// ==========================================

/**
 * Common standard presets for site visits by the engineer
 */
export const DEFAULT_SITE_VISIT_PRESETS = [
  { label: 'Site Boundary & Center Line Marking', charge: 1500, desc: 'Initial site visit for boundary verification & column marking' },
  { label: 'Footing & Excavation Inspection', charge: 1500, desc: 'Foundation pit depth, soil check & footing rebar placement' },
  { label: 'Plinth Beam Level Verification', charge: 1500, desc: 'Plinth level beam rebar checking, cover blocks & shuttering' },
  { label: 'Ground Floor Slab Casting Supervision', charge: 1500, desc: 'GF roof slab steel distribution, electrical pipes & concrete pouring' },
  { label: 'First Floor Slab Casting Supervision', charge: 1500, desc: 'FF roof slab reinforcement check & live casting supervision' },
  { label: 'Lintel & Masonry Brickwork Verification', charge: 1500, desc: 'Door-window opening levels, lintel bands & brick masonry quality' },
  { label: 'Plumbing & Drainage Line Verification', charge: 1500, desc: 'Underground sanitary slope, drain pipe routing & septic tank check' },
  { label: 'Custom Engineer Site Visit', charge: 1500, desc: 'On-demand site consultation & architectural inspection' },
];

/**
 * Add a site inspection / supervision visit to this specific owner
 */
export async function addSiteVisitToOwner(ownerId, visitItem) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];
  const payments = Array.isArray(data.payments) ? data.payments : [];

  const newVisit = {
    id: `visit_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
    date: visitItem.date || new Date().toISOString().split('T')[0],
    purpose: visitItem.purpose?.trim() || 'Site Inspection',
    amount: Number(visitItem.amount !== undefined ? visitItem.amount : 1500) || 0,
    visitedBy: visitItem.visitedBy?.trim() || data.engineerName || 'Er. Engineer',
    notes: visitItem.notes?.trim() || '',
    createdAt: new Date().toISOString(),
  };

  const updatedVisits = [...currentVisits, newVisit];
  const totalVisitsAmount = updatedVisits.reduce((s, v) => s + (Number(v.amount) || 0), 0);
  const houseAmount = Number(data.houseAmount) || 0;
  const totalBillableAmount = houseAmount + totalVisitsAmount;
  const paymentsSum = payments.reduce((s, p) => s + (Number(p.amount) || 0), 0);
  const totalPaid = paymentsSum > 0 ? paymentsSum : (Number(data.totalPaid) || 0);
  const pendingBalance = Math.max(0, totalBillableAmount - totalPaid);

  const effectivePayments = payments.length > 0
    ? payments
    : (totalPaid > 0
        ? [{
            id: `pay_record_${ownerId}`,
            installmentName: totalPaid >= houseAmount ? 'Full Plan Fee (100% Cleared)' : 'Advance Booking Payment',
            type: totalPaid >= houseAmount ? 'final' : 'advance',
            amount: totalPaid,
            date: safeDate(data.updatedAt)?.toISOString().split('T')[0] || safeDate(data.createdAt)?.toISOString().split('T')[0] || new Date().toISOString().split('T')[0],
            mode: 'UPI',
            notes: 'Recorded plan payment',
            recordedAt: new Date().toISOString(),
          }]
        : []);

  let paymentStatus = 'pending';
  if (totalPaid >= totalBillableAmount && totalBillableAmount > 0) {
    paymentStatus = 'completed';
  } else if (totalPaid >= totalBillableAmount * 0.5 && totalBillableAmount > 0) {
    paymentStatus = 'half_paid';
  } else if (totalPaid > 0) {
    paymentStatus = 'advance_received';
  }

  await updateDoc(doc(db, 'house_plans', ownerId), {
    siteVisits: updatedVisits,
    payments: effectivePayments,
    totalPaid,
    totalVisitsAmount,
    totalBillableAmount,
    pendingBalance,
    paymentStatus,
    updatedAt: serverTimestamp(),
  });

  return newVisit;
}

/**
 * Update an existing site visit inside this specific owner
 */
export async function updateSiteVisitInOwner(ownerId, visitId, updates) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];
  const payments = Array.isArray(data.payments) ? data.payments : [];

  const updatedVisits = currentVisits.map((v) => {
    if (v.id === visitId) {
      return {
        ...v,
        ...updates,
        amount: updates.amount !== undefined ? Number(updates.amount) : v.amount,
      };
    }
    return v;
  });

  const totalVisitsAmount = updatedVisits.reduce((s, v) => s + (Number(v.amount) || 0), 0);
  const houseAmount = Number(data.houseAmount) || 0;
  const totalBillableAmount = houseAmount + totalVisitsAmount;
  const paymentsSum = payments.reduce((s, p) => s + (Number(p.amount) || 0), 0);
  const totalPaid = paymentsSum > 0 ? paymentsSum : (Number(data.totalPaid) || 0);
  const pendingBalance = Math.max(0, totalBillableAmount - totalPaid);

  const effectivePayments = payments.length > 0
    ? payments
    : (totalPaid > 0
        ? [{
            id: `pay_record_${ownerId}`,
            installmentName: totalPaid >= houseAmount ? 'Full Plan Fee (100% Cleared)' : 'Advance Booking Payment',
            type: totalPaid >= houseAmount ? 'final' : 'advance',
            amount: totalPaid,
            date: safeDate(data.updatedAt)?.toISOString().split('T')[0] || safeDate(data.createdAt)?.toISOString().split('T')[0] || new Date().toISOString().split('T')[0],
            mode: 'UPI',
            notes: 'Recorded plan payment',
            recordedAt: new Date().toISOString(),
          }]
        : []);

  let paymentStatus = 'pending';
  if (totalPaid >= totalBillableAmount && totalBillableAmount > 0) {
    paymentStatus = 'completed';
  } else if (totalPaid >= totalBillableAmount * 0.5 && totalBillableAmount > 0) {
    paymentStatus = 'half_paid';
  } else if (totalPaid > 0) {
    paymentStatus = 'advance_received';
  }

  await updateDoc(doc(db, 'house_plans', ownerId), {
    siteVisits: updatedVisits,
    payments: effectivePayments,
    totalPaid,
    totalVisitsAmount,
    totalBillableAmount,
    pendingBalance,
    paymentStatus,
    updatedAt: serverTimestamp(),
  });
}

/**
 * Delete a site visit from this specific owner
 */
export async function deleteSiteVisitFromOwner(ownerId, visitId) {
  const snap = await getDoc(doc(db, 'house_plans', ownerId));
  if (!snap.exists()) throw new Error('House Plan project not found');

  const data = snap.data();
  const currentVisits = Array.isArray(data.siteVisits) ? data.siteVisits : [];
  const payments = Array.isArray(data.payments) ? data.payments : [];
  const updatedVisits = currentVisits.filter((v) => v.id !== visitId);

  const totalVisitsAmount = updatedVisits.reduce((s, v) => s + (Number(v.amount) || 0), 0);
  const houseAmount = Number(data.houseAmount) || 0;
  const totalBillableAmount = houseAmount + totalVisitsAmount;
  const paymentsSum = payments.reduce((s, p) => s + (Number(p.amount) || 0), 0);
  const totalPaid = paymentsSum > 0 ? paymentsSum : (Number(data.totalPaid) || 0);
  const pendingBalance = Math.max(0, totalBillableAmount - totalPaid);

  const effectivePayments = payments.length > 0
    ? payments
    : (totalPaid > 0
        ? [{
            id: `pay_record_${ownerId}`,
            installmentName: totalPaid >= houseAmount ? 'Full Plan Fee (100% Cleared)' : 'Advance Booking Payment',
            type: totalPaid >= houseAmount ? 'final' : 'advance',
            amount: totalPaid,
            date: safeDate(data.updatedAt)?.toISOString().split('T')[0] || safeDate(data.createdAt)?.toISOString().split('T')[0] || new Date().toISOString().split('T')[0],
            mode: 'UPI',
            notes: 'Recorded plan payment',
            recordedAt: new Date().toISOString(),
          }]
        : []);

  let paymentStatus = 'pending';
  if (totalPaid >= totalBillableAmount && totalBillableAmount > 0) {
    paymentStatus = 'completed';
  } else if (totalPaid >= totalBillableAmount * 0.5 && totalBillableAmount > 0) {
    paymentStatus = 'half_paid';
  } else if (totalPaid > 0) {
    paymentStatus = 'advance_received';
  }

  await updateDoc(doc(db, 'house_plans', ownerId), {
    siteVisits: updatedVisits,
    payments: effectivePayments,
    totalPaid,
    totalVisitsAmount,
    totalBillableAmount,
    pendingBalance,
    paymentStatus,
    updatedAt: serverTimestamp(),
  });
}

// ==========================================
// MASTER PLAN CATALOG (15+ CUSTOMIZABLE TEMPLATES)
// ==========================================

/**
 * Subscribe to the contractor's customizable master plan catalog
 */
export function subscribeMasterPlanCatalog(contractorId, callback) {
  if (!contractorId) {
    callback(DEFAULT_MASTER_PLANS);
    return () => {};
  }

  const catalogDocRef = doc(db, 'house_plans', `_catalog_${contractorId}`);

  return onSnapshot(
    catalogDocRef,
    (snap) => {
      if (snap.exists() && Array.isArray(snap.data()?.catalog) && snap.data().catalog.length > 0) {
        callback(snap.data().catalog);
      } else {
        callback(DEFAULT_MASTER_PLANS);
      }
    },
    (err) => {
      console.warn('Could not load custom catalog, using defaults:', err);
      callback(DEFAULT_MASTER_PLANS);
    }
  );
}

/**
 * Save / Update customizable master plan catalog
 */
export async function saveMasterPlanCatalog(contractorId, catalogList) {
  if (!contractorId) throw new Error('contractorId is required to save master catalog');

  const catalogDocRef = doc(db, 'house_plans', `_catalog_${contractorId}`);
  await setDoc(
    catalogDocRef,
    {
      contractorId,
      isCatalogDoc: true,
      catalog: catalogList,
      updatedAt: serverTimestamp(),
    },
    { merge: true }
  );
}
