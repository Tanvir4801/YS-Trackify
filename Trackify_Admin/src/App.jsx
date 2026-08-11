import React, { useEffect, Suspense, lazy } from 'react';
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
const Labours = lazy(() => import('./pages/Labours'));
const LabourProfile = lazy(() => import('./pages/LabourProfile'));
const Attendance = lazy(() => import('./pages/Attendance'));
const Payments = lazy(() => import('./pages/Payments'));
const Users = lazy(() => import('./pages/Users'));
const Reports = lazy(() => import('./pages/Reports'));
const Payroll = lazy(() => import('./pages/Payroll'));
const Supervisors = lazy(() => import('./pages/Supervisors'));
const Settings = lazy(() => import('./pages/Settings'));
const BrandingSettings = lazy(() => import('./pages/BrandingSettings'));
const SupportRequests = lazy(() => import('./pages/SupportRequests'));
const Sites = lazy(() => import('./pages/Sites'));
const Expenses = lazy(() => import('./pages/Expenses'));
const SiteCosts = lazy(() => import('./pages/SiteCosts'));
const TempLabours = lazy(() => import('./pages/TempLabours'));

// Client Ledger
const ClientList = lazy(() => import('./pages/clients/ClientList'));
const ClientProfile = lazy(() => import('./pages/clients/ClientProfile'));
const ProjectDetails = lazy(() => import('./pages/clients/ProjectDetails'));

// TrackOps Pages
const MissionDashboard = lazy(() => import('./pages/trackops/MissionDashboard'));
const LiveUsers = lazy(() => import('./pages/trackops/LiveUsers'));
const ErrorCenter = lazy(() => import('./pages/trackops/ErrorCenter'));
const UsageAnalytics = lazy(() => import('./pages/trackops/UsageAnalytics'));
const MissionLogs = lazy(() => import('./pages/trackops/MissionLogs'));
const ProductHealth = lazy(() => import('./pages/trackops/ProductHealth'));
const SupportCenter = lazy(() => import('./pages/trackops/SupportCenter'));
const RemoteActions = lazy(() => import('./pages/trackops/RemoteActions'));
const SecurityCenter = lazy(() => import('./pages/trackops/SecurityCenter'));
const Roadmap = lazy(() => import('./pages/trackops/Roadmap'));
const DeploymentCenter = lazy(() => import('./pages/trackops/DeploymentCenter'));

// Super Admin pages
const SADashboard = lazy(() => import('./pages/superadmin/SADashboard'));
const SARevenue = lazy(() => import('./pages/superadmin/SARevenue'));
const SACustomers = lazy(() => import('./pages/superadmin/SACustomers'));
const SACustomerProfile = lazy(() => import('./pages/superadmin/SACustomerProfile'));
const SASubscriptions = lazy(() => import('./pages/superadmin/SASubscriptions'));
const SAUsageAnalytics = lazy(() => import('./pages/superadmin/SAUsageAnalytics'));
const SAFeatureAnalytics = lazy(() => import('./pages/superadmin/SAFeatureAnalytics'));
const SASupport = lazy(() => import('./pages/superadmin/SASupport'));
const SAGrowth = lazy(() => import('./pages/superadmin/SAGrowth'));
const SAChurn = lazy(() => import('./pages/superadmin/SAChurn'));
const SAInsights = lazy(() => import('./pages/superadmin/SAInsights'));
const SAUserManagement = lazy(() => import('./pages/superadmin/SAUserManagement'));
// Labs Pages
const FeatureFlags = lazy(() => import('./pages/labs/FeatureFlags'));
const BetaTestCenter = lazy(() => import('./pages/labs/BetaTestCenter'));
const CostSimulator = lazy(() => import('./pages/labs/CostSimulator'));
const AILabs = lazy(() => import('./pages/labs/AILabs'));
const ABTesting = lazy(() => import('./pages/labs/ABTesting'));
const UILabs = lazy(() => import('./pages/labs/UILabs'));
const RoadmapLabs = lazy(() => import('./pages/labs/RoadmapLabs'));
const ExperimentalModules = lazy(() => import('./pages/labs/ExperimentalModules'));
const PerformanceLab = lazy(() => import('./pages/labs/PerformanceLab'));
const InternalNotes = lazy(() => import('./pages/labs/InternalNotes'));
const FeatureRequests = lazy(() => import('./pages/labs/FeatureRequests'));
const ReleaseCenter = lazy(() => import('./pages/labs/ReleaseCenter'));

function NavigateByRole() {
  const role = useAuthStore((s) => s.role);
  if (role === 'trackops') return <Navigate to="/trackops/dashboard" replace />;
  if (role === 'super_admin') return <Navigate to="/sa/dashboard" replace />;
  return <Navigate to="/dashboard" replace />;
}

const contractorRoles = ['contractor', 'supervisor'];


const SuspenseFallback = () => (
  <div className="flex h-screen w-full items-center justify-center bg-gray-50/10 dark:bg-gray-900/10">
    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
  </div>
);

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
      <Suspense fallback={<SuspenseFallback />}><Routes>
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
      </Routes></Suspense>
    </ErrorBoundary>
  );
}

