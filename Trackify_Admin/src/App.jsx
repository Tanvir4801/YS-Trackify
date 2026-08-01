import React, { useEffect } from 'react';
import { Routes, Route, Navigate, useNavigate } from 'react-router-dom';
import { onAuthStateChanged } from 'firebase/auth';
import { collection, doc, getDoc, getDocs, query, where, setDoc, deleteDoc } from 'firebase/firestore';
import toast from 'react-hot-toast';

import { auth, db } from './lib/firebase';
import { useAuthStore } from './store/authStore';

import ProtectedRoute from './components/layout/ProtectedRoute';
import AppLayout from './components/layout/AppLayout';
import TrackOpsLayout from './components/layout/TrackOpsLayout';
import { TrackOpsMonitoringProvider } from './context/TrackOpsMonitoringContext';
import LabsLayout from './components/layout/LabsLayout';
import RoleRoute from './components/shared/RoleRoute';
import ErrorBoundary from './components/shared/ErrorBoundary';
import TelemetryTracker from './components/shared/TelemetryTracker';

// Contractor pages
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
import BrandingSettings from './pages/BrandingSettings';
import SupportRequests from './pages/SupportRequests';
import Sites from './pages/Sites';
import Expenses from './pages/Expenses';
import SiteCosts from './pages/SiteCosts';
import TempLabours from './pages/TempLabours';

// Client Ledger
import ClientList from './pages/clients/ClientList';
import ClientProfile from './pages/clients/ClientProfile';
import ProjectDetails from './pages/clients/ProjectDetails';

// TrackOps Pages
import MissionDashboard from './pages/trackops/MissionDashboard';
import LiveUsers from './pages/trackops/LiveUsers';
import ErrorCenter from './pages/trackops/ErrorCenter';
import UsageAnalytics from './pages/trackops/UsageAnalytics';
import MissionLogs from './pages/trackops/MissionLogs';
import ProductHealth from './pages/trackops/ProductHealth';
import SupportCenter from './pages/trackops/SupportCenter';
import RemoteActions from './pages/trackops/RemoteActions';
import SecurityCenter from './pages/trackops/SecurityCenter';
import Roadmap from './pages/trackops/Roadmap';
import DeploymentCenter from './pages/trackops/DeploymentCenter';

// Super Admin pages
import SADashboard      from './pages/superadmin/SADashboard';
import SARevenue        from './pages/superadmin/SARevenue';
import SACustomers      from './pages/superadmin/SACustomers';
import SACustomerProfile from './pages/superadmin/SACustomerProfile';
import SASubscriptions  from './pages/superadmin/SASubscriptions';
import SAUsageAnalytics from './pages/superadmin/SAUsageAnalytics';
import SAFeatureAnalytics from './pages/superadmin/SAFeatureAnalytics';
import SASupport        from './pages/superadmin/SASupport';
import SAGrowth         from './pages/superadmin/SAGrowth';
import SAChurn          from './pages/superadmin/SAChurn';
import SAInsights       from './pages/superadmin/SAInsights';
import SAUserManagement from './pages/superadmin/SAUserManagement';
// Labs Pages
import FeatureFlags from './pages/labs/FeatureFlags';
import BetaTestCenter from './pages/labs/BetaTestCenter';
import CostSimulator from './pages/labs/CostSimulator';
import AILabs from './pages/labs/AILabs';
import ABTesting from './pages/labs/ABTesting';
import UILabs from './pages/labs/UILabs';
import RoadmapLabs from './pages/labs/RoadmapLabs';
import ExperimentalModules from './pages/labs/ExperimentalModules';
import PerformanceLab from './pages/labs/PerformanceLab';
import InternalNotes from './pages/labs/InternalNotes';
import FeatureRequests from './pages/labs/FeatureRequests';
import ReleaseCenter from './pages/labs/ReleaseCenter';

function NavigateByRole() {
  const role = useAuthStore((s) => s.role);
  if (role === 'trackops') return <Navigate to="/trackops/dashboard" replace />;
  if (role === 'super_admin') return <Navigate to="/sa/dashboard" replace />;
  return <Navigate to="/dashboard" replace />;
}

const contractorRoles = ['contractor', 'supervisor'];

export default function App() {
  const navigate = useNavigate();

  const setUser            = useAuthStore((s) => s.setUser);
  const clearUser          = useAuthStore((s) => s.clearUser);
  const switchContractor   = useAuthStore((s) => s.switchContractor);
  const setContractorsList = useAuthStore((s) => s.setContractorsList);
  const setLoading         = useAuthStore((s) => s.setLoading);

  useEffect(() => {
    setLoading(true);
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (!firebaseUser) {
        clearUser();
        if (window.location.pathname !== '/login') navigate('/login', { replace: true });
        return;
      }

      try {
        let userSnap = await getDoc(doc(db, 'users', firebaseUser.uid));
        
        // Auto-link pre-created users (e.g. created from SA User Management UI)
        if (!userSnap.exists()) {
          const emailQuery = query(collection(db, 'users'), where('email', '==', firebaseUser.email));
          const emailSnap = await getDocs(emailQuery);
          
          if (!emailSnap.empty) {
            // Found a pre-created document, migrate it to the correct UID
            const preCreatedDoc = emailSnap.docs[0];
            const preCreatedData = preCreatedDoc.data();
            
            await setDoc(doc(db, 'users', firebaseUser.uid), {
              ...preCreatedData,
              updatedAt: new Date()
            });
            
            // Delete the old random-ID document safely
            try {
              await deleteDoc(preCreatedDoc.ref);
            } catch (delErr) {
              console.warn('Could not delete pre-created doc (likely permissions), continuing anyway', delErr);
            }
            
            // Re-fetch the newly created snap
            userSnap = await getDoc(doc(db, 'users', firebaseUser.uid));
          } else {
            toast.error('Your user profile is missing. Contact your admin.');
            await auth.signOut();
            clearUser();
            navigate('/login', { replace: true });
            return;
          }
        }

        const userData = userSnap.data();

        const lockoutUntil = userData.lockoutUntil?.toDate?.();
        if (lockoutUntil && lockoutUntil > new Date()) {
          toast.error('Account locked due to multiple failed attempts.');
          await auth.signOut();
          clearUser();
          navigate('/login', { replace: true });
          return;
        }

        if (userData.isCompromised) {
          toast.error('Security Alert: Your account is compromised. Password reset required.');
          await auth.signOut();
          clearUser();
          navigate('/login', { replace: true });
          return;
        }

        if (userData.requiresPasswordReset) {
          toast.error('Security lock: Password reset required.');
          await auth.signOut();
          clearUser();
          navigate('/login', { replace: true });
          return;
        }

        if (userData.isActive === false) {
          toast.error('Your account is deactivated.');
          await auth.signOut();
          clearUser();
          navigate('/login', { replace: true });
          return;
        }

        const effectiveRole = userData.role === 'supervisor' ? 'contractor' : userData.role;

        setUser({
          uid:          firebaseUser.uid,
          role:         effectiveRole,
          name:         userData.name,
          email:        firebaseUser.email,
          contractorId: userData.contractorId ?? '',
        });

        if (effectiveRole === 'super_admin') {
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
          if (contractorSnap.exists()) {
            const cData = contractorSnap.data();
            if (cData.isSuspended) {
              toast.error(`Company Suspended: ${cData.suspensionReason || 'Please contact support'}`);
              await auth.signOut();
              clearUser();
              navigate('/login', { replace: true });
              return;
            }
            switchContractor(userData.contractorId, cData.name);
          }
        }

        const currentPath = window.location.pathname;
        if (currentPath === '/login' || currentPath === '/') {
          if (effectiveRole === 'trackops') {
            navigate('/trackops/dashboard', { replace: true });
          } else if (effectiveRole === 'super_admin') {
            navigate('/sa/dashboard', { replace: true });
          } else {
            navigate('/dashboard', { replace: true });
          }
        }
      } catch (err) {
        console.error('Auth bootstrap failed', err);
        toast.error('Failed to load profile: ' + (err.message || 'Unknown error'));
        clearUser();
      }
    });
    return () => unsubscribe();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <ErrorBoundary>
      <TelemetryTracker />
      <Routes>
        <Route path="/login" element={<Login />} />

        {/* ── TrackOps Routes (/trackops/*) ────────────────────── */}
        <Route element={<ProtectedRoute><TrackOpsMonitoringProvider><TrackOpsLayout /></TrackOpsMonitoringProvider></ProtectedRoute>}>
          <Route path="/trackops/dashboard" element={<RoleRoute allowedRoles={['trackops', 'super_admin']} fallback="/dashboard"><MissionDashboard /></RoleRoute>} />
          <Route path="/trackops/live-users" element={<RoleRoute allowedRoles={['trackops', 'super_admin']} fallback="/dashboard"><LiveUsers /></RoleRoute>} />
          <Route path="/trackops/errors" element={<RoleRoute allowedRoles={['trackops', 'super_admin']} fallback="/dashboard"><ErrorCenter /></RoleRoute>} />
          <Route path="/trackops/mission-logs" element={<RoleRoute allowedRoles={['trackops', 'super_admin']} fallback="/dashboard"><MissionLogs /></RoleRoute>} />
          <Route path="/trackops/health" element={<RoleRoute allowedRoles={['trackops', 'super_admin']} fallback="/dashboard"><ProductHealth /></RoleRoute>} />
          <Route path="/trackops/analytics" element={<RoleRoute allowedRoles={['trackops', 'super_admin']} fallback="/dashboard"><UsageAnalytics /></RoleRoute>} />
          <Route path="/trackops/support" element={<RoleRoute allowedRoles={['trackops', 'super_admin']} fallback="/dashboard"><SupportCenter /></RoleRoute>} />
          <Route path="/trackops/remote-actions" element={<RoleRoute allowedRoles={['trackops', 'super_admin']} fallback="/dashboard"><RemoteActions /></RoleRoute>} />
          <Route path="/trackops/security" element={<RoleRoute allowedRoles={['trackops', 'super_admin']} fallback="/dashboard"><SecurityCenter /></RoleRoute>} />
          <Route path="/trackops/roadmap" element={<RoleRoute allowedRoles={['trackops', 'super_admin']} fallback="/dashboard"><Roadmap /></RoleRoute>} />
          <Route path="/trackops/deployment" element={<RoleRoute allowedRoles={['trackops', 'super_admin']} fallback="/dashboard"><DeploymentCenter /></RoleRoute>} />
        </Route>

        <Route element={<ProtectedRoute><LabsLayout /></ProtectedRoute>}>
          <Route path="/labs" element={<Navigate to="/labs/feature-flags" replace />} />
          <Route path="/labs/feature-flags" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><FeatureFlags /></RoleRoute>} />
          <Route path="/labs/beta" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><BetaTestCenter /></RoleRoute>} />
          <Route path="/labs/cost-simulator" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><CostSimulator /></RoleRoute>} />
          <Route path="/labs/ai" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><AILabs /></RoleRoute>} />
          <Route path="/labs/ab-testing" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><ABTesting /></RoleRoute>} />
          <Route path="/labs/ui" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><UILabs /></RoleRoute>} />
          <Route path="/labs/roadmap" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><RoadmapLabs /></RoleRoute>} />
          <Route path="/labs/experimental" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><ExperimentalModules /></RoleRoute>} />
          <Route path="/labs/performance" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><PerformanceLab /></RoleRoute>} />
          <Route path="/labs/notes" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><InternalNotes /></RoleRoute>} />
          <Route path="/labs/requests" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><FeatureRequests /></RoleRoute>} />
          <Route path="/labs/release" element={<RoleRoute allowedRoles={['super_admin', 'trackops']} fallback="/dashboard"><ReleaseCenter /></RoleRoute>} />
        </Route>

        <Route element={<ProtectedRoute><AppLayout /></ProtectedRoute>}>

          {/* ── Super Admin Routes (/sa/*) ─────────────────────── */}
          <Route path="/sa/dashboard"    element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SADashboard /></RoleRoute>} />
          <Route path="/sa/revenue"      element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SARevenue /></RoleRoute>} />
          <Route path="/sa/customers"    element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SACustomers /></RoleRoute>} />
          <Route path="/sa/customers/:id" element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SACustomerProfile /></RoleRoute>} />
          <Route path="/sa/subscriptions" element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SASubscriptions /></RoleRoute>} />
          <Route path="/sa/usage"        element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SAUsageAnalytics /></RoleRoute>} />
          <Route path="/sa/features"     element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SAFeatureAnalytics /></RoleRoute>} />
          <Route path="/sa/support"      element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SASupport /></RoleRoute>} />
          <Route path="/sa/growth"       element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SAGrowth /></RoleRoute>} />
          <Route path="/sa/churn"        element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SAChurn /></RoleRoute>} />
          <Route path="/sa/insights"     element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SAInsights /></RoleRoute>} />
          <Route path="/sa/users"        element={<RoleRoute allowedRoles={['super_admin']} fallback="/dashboard"><SAUserManagement /></RoleRoute>} />

          {/* ── Contractor / Supervisor Routes ─────────────────── */}
          <Route path="/dashboard"   element={<RoleRoute allowedRoles={contractorRoles} fallback="/sa/dashboard"><Dashboard /></RoleRoute>} />
          <Route path="/labours"     element={<RoleRoute allowedRoles={contractorRoles} fallback="/sa/dashboard"><Labours /></RoleRoute>} />
          <Route path="/labours/:id" element={<RoleRoute allowedRoles={contractorRoles} fallback="/sa/dashboard"><LabourProfile /></RoleRoute>} />
          <Route path="/attendance"  element={<RoleRoute allowedRoles={contractorRoles} fallback="/sa/dashboard"><Attendance /></RoleRoute>} />
          <Route path="/payroll"     element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><Payroll /></RoleRoute>} />
          <Route path="/payments"    element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><Payments /></RoleRoute>} />
          <Route path="/temp-labours" element={<RoleRoute allowedRoles={contractorRoles} fallback="/sa/dashboard"><TempLabours /></RoleRoute>} />
          <Route path="/reports"     element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><Reports /></RoleRoute>} />
          <Route path="/supervisors" element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><Supervisors /></RoleRoute>} />
          <Route path="/users"       element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><Users /></RoleRoute>} />
          <Route path="/settings"    element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><Settings /></RoleRoute>} />
          <Route path="/branding"    element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><BrandingSettings /></RoleRoute>} />
          <Route path="/support-requests" element={<RoleRoute allowedRoles={contractorRoles} fallback="/sa/dashboard"><SupportRequests /></RoleRoute>} />
          <Route path="/sites"       element={<RoleRoute allowedRoles={contractorRoles} fallback="/sa/dashboard"><Sites /></RoleRoute>} />
          <Route path="/expenses"    element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><Expenses /></RoleRoute>} />
          <Route path="/site-costs"  element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><SiteCosts /></RoleRoute>} />
          
          <Route path="/clients"     element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><ClientList /></RoleRoute>} />
          <Route path="/clients/:id" element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><ClientProfile /></RoleRoute>} />
          <Route path="/clients/:clientId/projects/:projectId" element={<RoleRoute allowedRoles={['contractor']}  fallback="/attendance"><ProjectDetails /></RoleRoute>} />

          <Route index element={<NavigateByRole />} />
          <Route path="*" element={<NavigateByRole />} />
        </Route>
      </Routes>
    </ErrorBoundary>
  );
}

