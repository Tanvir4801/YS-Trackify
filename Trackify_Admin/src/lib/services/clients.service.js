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
  deleteDoc,
} from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL, deleteObject } from 'firebase/storage';
import { db, storage } from '../firebase';

// Helper to safely extract date
const safeDate = (timestamp) => timestamp?.toDate?.() || null;

// ==========================================
// CLIENTS
// ==========================================

export async function addClient(data) {
  if (!data.contractorId) throw new Error('contractorId is required');

  const payload = {
    ...data,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    status: data.status || 'active',
  };

  const docRef = await addDoc(collection(db, 'clients'), payload);
  await updateDoc(docRef, { id: docRef.id });
  return docRef.id;
}

export async function updateClient(clientId, updates) {
  const payload = { ...updates, updatedAt: serverTimestamp() };
  await updateDoc(doc(db, 'clients', clientId), payload);
}

export async function deleteClient(clientId) {
  await deleteDoc(doc(db, 'clients', clientId));
}

export function subscribeClients(contractorId, callback, onError) {
  if (!contractorId) {
    callback([]);
    return () => {};
  }
  const q = query(
    collection(db, 'clients'),
    where('contractorId', '==', contractorId)
  );

  return onSnapshot(q, (snap) => {
    const clients = snap.docs.map((d) => ({
      id: d.id,
      ...d.data(),
      createdAt: safeDate(d.data().createdAt),
      updatedAt: safeDate(d.data().updatedAt),
    }));
    callback(clients.sort((a, b) => (a.name || '').localeCompare(b.name || '')));
  }, (err) => {
    console.error('subscribeClients error:', err);
    if (onError) onError(err);
  });
}

// ==========================================
// PROJECTS
// ==========================================

export async function addProject(data) {
  if (!data.contractorId) throw new Error('contractorId is required');
  if (!data.clientId) throw new Error('clientId is required');

  const payload = {
    ...data,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    status: data.status || 'active',
    completionPercent: data.completionPercent || 0,
  };

  const docRef = await addDoc(collection(db, 'projects'), payload);
  await updateDoc(docRef, { id: docRef.id });
  return docRef.id;
}

export async function updateProject(projectId, updates) {
  const payload = { ...updates, updatedAt: serverTimestamp() };
  await updateDoc(doc(db, 'projects', projectId), payload);
}

export async function deleteProject(projectId) {
  await deleteDoc(doc(db, 'projects', projectId));
}

export function subscribeProjects(contractorId, clientId = null, callback, onError) {
  if (!contractorId) {
    callback([]);
    return () => {};
  }
  
  const constraints = [where('contractorId', '==', contractorId)];
  if (clientId) {
    constraints.push(where('clientId', '==', clientId));
  }

  const q = query(collection(db, 'projects'), ...constraints);

  return onSnapshot(q, (snap) => {
    const projects = snap.docs.map((d) => ({
      id: d.id,
      ...d.data(),
      startDate: safeDate(d.data().startDate),
      endDate: safeDate(d.data().endDate),
      createdAt: safeDate(d.data().createdAt),
      updatedAt: safeDate(d.data().updatedAt),
    }));
    callback(projects.sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0)));
  }, (err) => {
    console.error('subscribeProjects error:', err);
    if (onError) onError(err);
  });
}

// ==========================================
// MILESTONES
// ==========================================

export async function addMilestone(data) {
  if (!data.projectId || !data.contractorId) throw new Error('Missing requirements');

  const payload = {
    ...data,
    status: data.status || 'pending',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const docRef = await addDoc(collection(db, 'payment_milestones'), payload);
  await updateDoc(docRef, { id: docRef.id });
  return docRef.id;
}

export async function updateMilestone(milestoneId, updates) {
  const payload = { ...updates, updatedAt: serverTimestamp() };
  await updateDoc(doc(db, 'payment_milestones', milestoneId), payload);
}

export function subscribeMilestones(projectId, callback) {
  if (!projectId) {
    callback([]);
    return () => {};
  }
  const q = query(collection(db, 'payment_milestones'), where('projectId', '==', projectId));

  return onSnapshot(q, (snap) => {
    const milestones = snap.docs.map((d) => ({
      id: d.id,
      ...d.data(),
      dueDate: safeDate(d.data().dueDate),
      paidDate: safeDate(d.data().paidDate),
      createdAt: safeDate(d.data().createdAt),
      updatedAt: safeDate(d.data().updatedAt),
    }));
    callback(milestones.sort((a, b) => (a.createdAt || 0) - (b.createdAt || 0)));
  }, (err) => {
    console.error('subscribeMilestones error:', err);
  });
}

export async function deleteMilestone(milestoneId) {
  await deleteDoc(doc(db, 'payment_milestones', milestoneId));
}

// ==========================================
// PAYMENTS
// ==========================================

export async function addClientPayment(data) {
  const payload = {
    ...data,
    createdAt: serverTimestamp(),
  };

  const docRef = await addDoc(collection(db, 'client_payments'), payload);
  await updateDoc(docRef, { id: docRef.id });
  
  // If tied to milestone, update milestone
  if (data.milestoneId) {
    await updateMilestone(data.milestoneId, {
      status: 'paid',
      paidDate: data.date,
      paidAmount: data.amount
    });
  }
  
  return docRef.id;
}

export function subscribeClientPayments(projectId, callback) {
  if (!projectId) {
    callback([]);
    return () => {};
  }
  const q = query(collection(db, 'client_payments'), where('projectId', '==', projectId));

  return onSnapshot(q, (snap) => {
    const payments = snap.docs.map((d) => ({
      id: d.id,
      ...d.data(),
      date: safeDate(d.data().date),
      createdAt: safeDate(d.data().createdAt),
    }));
    callback(payments.sort((a, b) => (b.date || 0) - (a.date || 0)));
  }, (err) => {
    console.error('subscribeClientPayments error:', err);
  });
}

export async function deleteClientPayment(paymentId) {
  await deleteDoc(doc(db, 'client_payments', paymentId));
}

// ==========================================
// DOCUMENTS
// ==========================================

export async function uploadProjectDocument(file, meta) {
  const { contractorId, clientId, projectId, type } = meta;
  if (!contractorId || !clientId || !projectId || !file) throw new Error('Missing file or meta');

  const ext = file.name.split('.').pop();
  const fileName = `${Date.now()}_${Math.random().toString(36).substring(7)}.${ext}`;
  const filePath = `clients/${contractorId}/${clientId}/${type}/${fileName}`;
  const storageRef = ref(storage, filePath);

  await uploadBytes(storageRef, file);
  const fileUrl = await getDownloadURL(storageRef);

  const payload = {
    contractorId,
    clientId,
    projectId,
    type,
    fileUrl,
    fileName: file.name,
    storagePath: filePath,
    uploadedAt: serverTimestamp(),
  };

  const docRef = await addDoc(collection(db, 'project_documents'), payload);
  await updateDoc(docRef, { id: docRef.id });
  return docRef.id;
}

export function subscribeProjectDocuments(projectId, callback) {
  if (!projectId) {
    callback([]);
    return () => {};
  }
  const q = query(collection(db, 'project_documents'), where('projectId', '==', projectId));

  return onSnapshot(q, (snap) => {
    const docs = snap.docs.map((d) => ({
      id: d.id,
      ...d.data(),
      uploadedAt: safeDate(d.data().uploadedAt),
    }));
    callback(docs.sort((a, b) => (b.uploadedAt || 0) - (a.uploadedAt || 0)));
  }, (err) => {
    console.error('subscribeProjectDocuments error:', err);
  });
}

export async function deleteProjectDocument(docId, storagePath) {
  if (storagePath) {
    try {
      const fileRef = ref(storage, storagePath);
      await deleteObject(fileRef);
    } catch (e) {
      console.warn("Storage file not found, deleting doc anyway.", e);
    }
  }
  await deleteDoc(doc(db, 'project_documents', docId));
}
