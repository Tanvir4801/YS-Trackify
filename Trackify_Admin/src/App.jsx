import React, { useEffect } from 'react';
import { Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom';
import { onAuthStateChanged } from 'firebase/auth';
import { collection, doc, getDoc, getDocs } from 'firebase/firestore';
import toast from 'react-hot-toast';

import { auth, db } from './lib/firebase';
import { useAuthStore } from './store/authStore';

import ProtectedRoute from './components/layout/ProtectedRoute';
import AppLayout from './components/layout/AppLayout';
import RoleRoute from './components/shared/RoleRoute';

import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Labours from './pages/Labours';
import LabourProfile from './pages/LabourProfile';
import Attendance from './pages/Attendance';
import Payments from './pages/Payments';
import Users from './pages/Users';
import Reports from './pages/Reports';
import Payroll from './pages/Payroll';
import Supervisors from './pages/Supervisors';
import Settings from './pages/Settings';
import Sites from './pages/Sites';
import Expenses from './pages/Expenses';

function NavigateByRole() {
  const role = useAuthStore((s) => s.role);
  if (role === 'supervisor') return <Navigate to="/attendance" replace />;
  return <Navigate to="/dashboard" replace />;
}

export default function App() {
  const navigate = useNavigate();
  const location = useLocation();

  const setUser = useAuthStore((s) => s.setUser);
  const clearUser = useAuthStore((s) => s.clearUser);
  const switchContractor = useAuthStore((s) => s.switchContractor);
  const setContractorsList = useAuthStore((s) => s.setContractorsList);
  const setLoading = useAuthStore((s) => s.setLoading);

  useEffect(() => {
    setLoading(true);
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (!firebaseUser) {
        clearUser();
        if (location.pathname !== '/login') navigate('/login', { replace: true });
        return;
      }

      try {
        const userSnap = await getDoc(doc(db, 'users', firebaseUser.uid));
        if (!userSnap.exists()) {
          toast.error('Your user profile is missing. Contact your admin.');
          await auth.signOut();
          clearUser();
          navigate('/login', { replace: true });
          return;
        }

        const userData = userSnap.data();

        if (userData.isActive === false) {
          toast.error('Your account is deactivated.');
          await auth.signOut();
          clearUser();
          navigate('/login', { replace: true });
          return;
        }

        setUser({
          uid: firebaseUser.uid,
          role: userData.role,
          name: userData.name,
          email: firebaseUser.email,
          contractorId: userData.contractorId ?? '',
        });

        if (userData.role === 'super_admin') {
          const snap = await getDocs(collection(db, 'contractors'));
          const list = snap.docs
            .map((d) => ({ id: d.id, ...d.data() }))
            .filter((c) => c.isActive !== false)
            .map((c) => ({ id: c.id, name: c.name || '(unnamed)' }))
            .sort((a, b) => String(a.name).localeCompare(String(b.name)));
          setContractorsList(list);
          switchContractor(null, null);
        } else if (userData.contractorId) {
          const contractorSnap = await getDoc(doc(db, 'contractors', userData.contractorId));
          const cName = contractorSnap.exists() ? contractorSnap.data().name : '';
          switchContractor(userData.contractorId, cName);
        }

        const target = userData.role === 'supervisor' ? '/attendance' : '/dashboard';
        if (location.pathname === '/login' || location.pathname === '/') {
          navigate(target, { replace: true });
        }
      } catch (err) {
        console.error('Auth bootstrap failed', err);
        toast.error('Failed to load your profile.');
        clearUser();
      }
    });
    return () => unsubscribe();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const adminRoles = ['super_admin', 'contractor'];

  return (
    <Routes>
      <Route path="/login" element={<Login />} />

      <Route
        element={
          <ProtectedRoute>
            <AppLayout />
          </ProtectedRoute>
        }
      >
        <Route
          path="/dashboard"
          element={
            <RoleRoute allowedRoles={adminRoles} fallback="/attendance">
              <Dashboard />
            </RoleRoute>
          }
        />

        <Route path="/labours" element={<Labours />} />
        <Route path="/labours/:id" element={<LabourProfile />} />

        <Route path="/attendance" element={<Attendance />} />

        <Route
          path="/payroll"
          element={
            <RoleRoute allowedRoles={adminRoles} fallback="/attendance">
              <Payroll />
            </RoleRoute>
          }
        />

        <Route
          path="/payments"
          element={
            <RoleRoute allowedRoles={adminRoles} fallback="/attendance">
              <Payments />
            </RoleRoute>
          }
        />

        <Route
          path="/reports"
          element={
            <RoleRoute allowedRoles={adminRoles} fallback="/attendance">
              <Reports />
            </RoleRoute>
          }
        />

        <Route
          path="/supervisors"
          element={
            <RoleRoute allowedRoles={adminRoles} fallback="/attendance">
              <Supervisors />
            </RoleRoute>
          }
        />

        <Route
          path="/users"
          element={
            <RoleRoute allowedRoles={adminRoles} fallback="/attendance">
              <Users />
            </RoleRoute>
          }
        />

        <Route
          path="/settings"
          element={
            <RoleRoute allowedRoles={adminRoles} fallback="/attendance">
              <Settings />
            </RoleRoute>
          }
        />

        <Route
          path="/sites"
          element={
            <RoleRoute allowedRoles={adminRoles} fallback="/attendance">
              <Sites />
            </RoleRoute>
          }
        />

        <Route
          path="/expenses"
          element={
            <RoleRoute allowedRoles={adminRoles} fallback="/attendance">
              <Expenses />
            </RoleRoute>
          }
        />

        <Route index element={<NavigateByRole />} />
        <Route path="*" element={<NavigateByRole />} />
      </Route>
    </Routes>
  );
}
