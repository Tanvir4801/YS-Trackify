import {
  collection,
  doc,
  getDoc,
  getDocs,
  addDoc,
  updateDoc,
  query,
  where,
  onSnapshot,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from '../firebase';

function snapToDoc(snap) {
  const data = snap.data() || {};
  return {
    id: snap.id,
    ...data,
    overtimeWagePerHour: Number(data.overtimeWagePerHour) || 0,
    defaultOvertimeHours: Number(data.defaultOvertimeHours) || 0,
    dailyWage: Number(data.dailyWage) || Number(data.dailyRate) || 0,
    dailyRate: Number(data.dailyRate) || Number(data.dailyWage) || 0,
    joiningDate: data.joiningDate?.toDate?.() || null,
    syncedAt: data.syncedAt?.toDate?.() || null,
    createdAt: data.createdAt?.toDate?.() || null,
    updatedAt: data.updatedAt?.toDate?.() || null,
    type: data.type || 'regular',
    isTemporary: data.type === 'temporary',
    supervisorRefPath:
      typeof data.supervisorRef === 'string'
        ? data.supervisorRef
        : data.supervisorRef?.path || null,
  };
}

function buildQueries(contractorId, options = {}) {
  const activeOnly = options.activeOnly !== false;
  const activeConstraint = activeOnly ? [where('isActive', '==', true)] : [];

  if (!contractorId) {
    return [query(collection(db, 'labours'), ...activeConstraint)];
  }

  return [
    query(collection(db, 'labours'), ...activeConstraint, where('contractorId', '==', contractorId)),
    query(collection(db, 'labours'), ...activeConstraint, where('supervisorId', '==', contractorId)),
  ];
}

export async function getLabours(contractorId, options = {}) {
  const queries = buildQueries(contractorId, options);
  const snaps = await Promise.all(queries.map((q) => getDocs(q)));
  const map = new Map();
  snaps.forEach((snap) => snap.docs.forEach((d) => { if (!map.has(d.id)) map.set(d.id, snapToDoc(d)); }));
  let results = Array.from(map.values());
  if (options.supervisorId) {
    results = results.filter((l) => l.supervisorId === options.supervisorId || l.supervisorRefPath === `users/${options.supervisorId}`);
  }
  if (!options.includeTemporary) {
    results = results.filter((l) => l.type !== 'temporary');
  }
  return results.sort((a, b) => String(a.name || '').localeCompare(String(b.name || '')));
}

export async function getLabour(labourId) {
  const snap = await getDoc(doc(db, 'labours', labourId));
  if (!snap.exists()) return null;
  return snapToDoc(snap);
}

export async function getTemporaryLabours(contractorId, supervisorId = null) {
  const constraints = [where('type', '==', 'temporary'), where('contractorId', '==', contractorId)];
  if (supervisorId) constraints.push(where('supervisorId', '==', supervisorId));
  const snap = await getDocs(query(collection(db, 'labours'), ...constraints));
  return snap.docs.map((d) => snapToDoc(d));
}

export async function addLabour(data) {
  if (!data.supervisorId) throw new Error('supervisorId is required');
  if (!data.contractorId) throw new Error('contractorId is required');

  const supervisorId = data.supervisorId;
  const contractorId = data.contractorId;

  const payload = {
    name: data.name,
    phone: data.phone ?? null,
    phoneNumber: data.phone ?? null,
    skill: data.skill ?? null,
    role: data.skill ?? null,
    dailyWage: Number(data.dailyWage) || 0,
    dailyRate: Number(data.dailyWage) || 0,
    overtimeWagePerHour: Number(data.overtimeWagePerHour) || 0,
    defaultOvertimeHours: Number(data.defaultOvertimeHours) || 0,
    supervisorId,
    supervisorRef: doc(db, 'users', supervisorId),
    contractorId,
    siteId: data.siteId || null,
    isActive: data.isActive ?? true,
    type: data.type || 'regular',
    isSynced: true,
    syncedAt: serverTimestamp(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const ref = await addDoc(collection(db, 'labours'), payload);
  await updateDoc(ref, { id: ref.id });
  console.log('✅ Labour added:', ref.id, 'type:', payload.type);
  return ref.id;
}

export async function addTemporaryLabour(contractorId, supervisorId, name, dailyWage) {
  if (!contractorId || !supervisorId) throw new Error('contractorId and supervisorId are required');
  const payload = {
    name,
    phone: null,
    phoneNumber: null,
    skill: 'Temporary',
    role: 'Temporary',
    dailyWage: Number(dailyWage) || 0,
    dailyRate: Number(dailyWage) || 0,
    overtimeWagePerHour: 0,
    defaultOvertimeHours: 0,
    supervisorId,
    supervisorRef: doc(db, 'users', supervisorId),
    contractorId,
    isActive: true,
    type: 'temporary',
    isSynced: true,
    syncedAt: serverTimestamp(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
  const ref = await addDoc(collection(db, 'labours'), payload);
  await updateDoc(ref, { id: ref.id });
  console.log('✅ Temp labour added:', ref.id, name);
  return { id: ref.id, ...payload };
}

export async function updateLabour(labourId, updates) {
  const payload = { ...updates, updatedAt: serverTimestamp() };
  if (payload.dailyWage !== undefined) {
    payload.dailyWage = Number(payload.dailyWage) || 0;
    payload.dailyRate = payload.dailyWage;
  }
  if (payload.overtimeWagePerHour !== undefined) payload.overtimeWagePerHour = Number(payload.overtimeWagePerHour) || 0;
  if (payload.defaultOvertimeHours !== undefined) payload.defaultOvertimeHours = Number(payload.defaultOvertimeHours) || 0;
  if (payload.supervisorId) {
    payload.supervisorRef = doc(db, 'users', payload.supervisorId);
    if (!payload.contractorId) payload.contractorId = payload.contractorId || payload.supervisorId;
  }
  if (payload.skill !== undefined) payload.role = payload.skill;
  if (payload.role !== undefined && payload.skill === undefined) payload.skill = payload.role;
  if (payload.phone !== undefined) payload.phoneNumber = payload.phone;
  await updateDoc(doc(db, 'labours', labourId), payload);
  console.log('✅ Labour updated:', labourId);
}

export async function deactivateLabour(labourId) {
  await updateDoc(doc(db, 'labours', labourId), { isActive: false, updatedAt: serverTimestamp() });
}

export async function activateLabour(labourId) {
  await updateDoc(doc(db, 'labours', labourId), { isActive: true, updatedAt: serverTimestamp() });
}

export function subscribeLabours(contractorId, callback, options = {}) {
  const queries = buildQueries(contractorId, options);
  const buckets = queries.map(() => new Map());

  const emit = () => {
    const merged = new Map();
    buckets.forEach((b) => b.forEach((v, k) => merged.set(k, v)));
    let results = Array.from(merged.values());
    if (options.supervisorId) {
      results = results.filter((l) => l.supervisorId === options.supervisorId || l.supervisorRefPath === `users/${options.supervisorId}`);
    }
    if (!options.includeTemporary) {
      results = results.filter((l) => l.type !== 'temporary');
    }
    callback(results.sort((a, b) => String(a.name || '').localeCompare(String(b.name || ''))));
  };

  const unsubs = queries.map((q, i) =>
    onSnapshot(q, (snap) => {
      const next = new Map();
      snap.docs.forEach((d) => next.set(d.id, snapToDoc(d)));
      buckets[i] = next;
      emit();
    }, (err) => { console.error('❌ subscribeLabours error:', err); }),
  );
  return () => unsubs.forEach((u) => u());
}

export function subscribeTemporaryLabours(contractorId, callback) {
  if (!contractorId) { callback([]); return () => {}; }
  const q = query(collection(db, 'labours'), where('contractorId', '==', contractorId), where('type', '==', 'temporary'), where('isActive', '==', true));
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map((d) => snapToDoc(d)));
  }, (err) => { console.error('subscribeTemporaryLabours error:', err); });
}
