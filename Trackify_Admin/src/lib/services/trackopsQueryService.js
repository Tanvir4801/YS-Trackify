import { useQuery, useInfiniteQuery, useQueryClient } from '@tanstack/react-query';
import { useState, useEffect } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { useTrackOpsMonitoring } from '../../context/TrackOpsMonitoringContext';

// Hook to detect user inactivity (5 minutes)
export function useUserIdle() {
  const [isIdle, setIsIdle] = useState(false);

  useEffect(() => {
    let timeout;
    const resetTimer = () => {
      setIsIdle(false);
      clearTimeout(timeout);
      timeout = setTimeout(() => setIsIdle(true), 5 * 60 * 1000);
    };

    window.addEventListener('mousemove', resetTimer);
    window.addEventListener('keydown', resetTimer);
    window.addEventListener('scroll', resetTimer);
    window.addEventListener('click', resetTimer);

    resetTimer();

    return () => {
      clearTimeout(timeout);
      window.removeEventListener('mousemove', resetTimer);
      window.removeEventListener('keydown', resetTimer);
      window.removeEventListener('scroll', resetTimer);
      window.removeEventListener('click', resetTimer);
    };
  }, []);

  return isIdle;
}

// Define endpoints
const getAnalyticsFn = httpsCallable(functions, 'trackopsGetAnalytics');
const getBillingFn = httpsCallable(functions, 'trackopsGetBilling');
const getLogsFn = httpsCallable(functions, 'trackopsGetPaginatedLogs');

const vercelGetProjectFullFn = httpsCallable(functions, 'vercelGetProjectFull');
const vercelGetAnalyticsFn = httpsCallable(functions, 'vercelGetDeploymentAnalytics');
const vercelGetLogsFn = httpsCallable(functions, 'vercelGetDeploymentLogs');
const vercelGetFilesFn = httpsCallable(functions, 'vercelGetDeploymentFiles');
const getVercelProjectFn = httpsCallable(functions, 'vercelGetProjectFull');

const infralensGetOverviewFn = httpsCallable(functions, 'infralensGetOverview');
const infralensGetAlertsFn = httpsCallable(functions, 'infralensGetAlerts');
const infralensGetIncidentDetailsFn = httpsCallable(functions, 'infralensGetIncidentDetails');
const infralensGetHealthFn = httpsCallable(functions, 'infralensGetHealth');
const infralensGetKubernetesFn = httpsCallable(functions, 'infralensGetKubernetes');
const infralensGetContainersFn = httpsCallable(functions, 'infralensGetContainers');
const infralensGetForecastFn = httpsCallable(functions, 'infralensGetForecast');

// Default Intervals
const INTERVALS = {
  ANALYTICS: 5 * 60 * 1000,     // 5 minutes
  BILLING: 60 * 60 * 1000,      // 60 minutes
  VERCEL: 30 * 1000,            // 30 seconds
};

/**
 * useTrackOpsAnalytics
 */
export function useTrackOpsAnalytics() {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  
  return useQuery({
    queryKey: ['trackops', 'analytics'],
    queryFn: async () => {
      const res = await getAnalyticsFn({});
      return res.data;
    },
    // Pause polling if monitoring is off or user is inactive
    refetchInterval: isMonitoringActive ? INTERVALS.ANALYTICS : false,
    refetchOnWindowFocus: true,
    staleTime: INTERVALS.ANALYTICS,
    enabled: isMonitoringActive,
  });
}

/**
 * useTrackOpsBilling
 */
export function useTrackOpsBilling() {
  const { isMonitoringActive } = useTrackOpsMonitoring();

  return useQuery({
    queryKey: ['trackops', 'billing'],
    queryFn: async () => {
      const res = await getBillingFn({});
      return res.data;
    },
    refetchInterval: isMonitoringActive ? INTERVALS.BILLING : false,
    refetchOnWindowFocus: true,
    staleTime: INTERVALS.BILLING,
    enabled: isMonitoringActive,
  });
}

/**
 * useTrackOpsVercel
 */
export function useTrackOpsVercel(projectId = null) {
  const { isMonitoringActive } = useTrackOpsMonitoring();

  return useQuery({
    queryKey: ['trackops', 'vercel', projectId],
    queryFn: async () => {
      const res = await getVercelProjectFn({ projectId });
      return res.data;
    },
    refetchInterval: isMonitoringActive ? INTERVALS.VERCEL : false,
    refetchOnWindowFocus: true,
    staleTime: INTERVALS.VERCEL,
    enabled: isMonitoringActive,
  });
}

/**
 * useInfiniteTrackOpsLogs
 * For paginated historical logs with "Load More" functionality.
 */
export function useInfiniteTrackOpsLogs(collectionName) {
  return useInfiniteQuery({
    queryKey: ['trackops', 'logs', 'infinite', collectionName],
    queryFn: async ({ pageParam = null }) => {
      const res = await getLogsFn({ collectionName, lastVisibleId: pageParam, pageSize: 50 });
      return res.data; // { logs, lastVisibleId, hasMore }
    },
    getNextPageParam: (lastPage) => {
      return lastPage.hasMore ? lastPage.lastVisibleId : undefined;
    },
    initialPageParam: null,
    staleTime: 60 * 1000,
  });
}

/**
 * useTrackOpsVercelDashboard
 * Polled every 5s for Vercel deployment status
 */
export function useTrackOpsVercelDashboard() {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  const isIdle = useUserIdle();
  const active = isMonitoringActive && !isIdle;

  return useQuery({
    queryKey: ['trackops', 'vercel', 'dashboard'],
    queryFn: async () => {
      const res = await vercelGetProjectFullFn({});
      return res.data?.data || null;
    },
    refetchInterval: active ? 5000 : false,
    staleTime: 5000,
    enabled: active,
  });
}

/**
 * useTrackOpsVercelAnalytics
 * Polled every 30s
 */
export function useTrackOpsVercelAnalytics(projectId) {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  const isIdle = useUserIdle();
  const active = !!projectId && isMonitoringActive && !isIdle;

  return useQuery({
    queryKey: ['trackops', 'vercel', 'analytics', projectId],
    queryFn: async () => {
      const res = await vercelGetAnalyticsFn({ projectId });
      return res.data?.data || null;
    },
    refetchInterval: active ? 30000 : false,
    staleTime: 30000,
    enabled: active,
  });
}

/**
 * useTrackOpsVercelLogs
 * Polled every 5s
 */
export function useTrackOpsVercelLogs(deploymentId) {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  const isIdle = useUserIdle();
  const active = !!deploymentId && isMonitoringActive && !isIdle;

  return useQuery({
    queryKey: ['trackops', 'vercel', 'logs', deploymentId],
    queryFn: async () => {
      const res = await vercelGetLogsFn({ deploymentId });
      return res.data?.data || null;
    },
    refetchInterval: active ? 5000 : false,
    staleTime: 5000,
    enabled: active,
  });
}

/**
 * useTrackOpsVercelFiles
 * Polled every 60s
 */
export function useTrackOpsVercelFiles(deploymentId) {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  const isIdle = useUserIdle();
  const active = !!deploymentId && isMonitoringActive && !isIdle;

  return useQuery({
    queryKey: ['trackops', 'vercel', 'files', deploymentId],
    queryFn: async () => {
      const res = await vercelGetFilesFn({ deploymentId });
      return res.data?.data || null;
    },
    refetchInterval: active ? 60000 : false,
    staleTime: 60000,
    enabled: active,
  });
}

// ─── InfraLens Integration Hooks ──────────────────────────────────────────────

export function useInfraLensOverview() {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  const isIdle = useUserIdle();
  const active = isMonitoringActive && !isIdle;

  return useQuery({
    queryKey: ['trackops', 'infralens', 'overview'],
    queryFn: async () => {
      const res = await infralensGetOverviewFn({});
      if (res.data?.success === false) throw new Error(res.data.message || 'InfraLens request failed.');
      return res.data?.data?.data ? { ...res.data, data: res.data.data.data } : res.data;
    },
    refetchInterval: active ? 30000 : false, // Poll every 30s when active
    staleTime: 30000,
    enabled: active,
    retry: 2, // Retry network errors briefly
  });
}

export function useInfraLensAlerts() {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  const isIdle = useUserIdle();
  const active = isMonitoringActive && !isIdle;

  return useQuery({
    queryKey: ['trackops', 'infralens', 'alerts'],
    queryFn: async () => {
      const res = await infralensGetAlertsFn({});
      if (res.data?.success === false) throw new Error(res.data.message || 'InfraLens request failed.');
      return res.data?.data?.data ? { ...res.data, data: res.data.data.data } : res.data;
    },
    refetchInterval: active ? 30000 : false,
    staleTime: 30000,
    enabled: active,
    retry: 2,
  });
}

export function useInfraLensIncident(incidentId) {
  // On demand fetching for details
  return useQuery({
    queryKey: ['trackops', 'infralens', 'incident', incidentId],
    queryFn: async () => {
      const res = await infralensGetIncidentDetailsFn({ incidentId });
      if (res.data?.success === false) throw new Error(res.data.message || 'InfraLens request failed.');
      return res.data;
    },
    staleTime: 5 * 60 * 1000, // 5 min cache
    enabled: !!incidentId,
    retry: 1,
  });
}

export function useInfraLensHealth() {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  const isIdle = useUserIdle();
  const active = isMonitoringActive && !isIdle;

  return useQuery({
    queryKey: ['trackops', 'infralens', 'health'],
    queryFn: async () => {
      const res = await infralensGetHealthFn({});
      if (res.data?.success === false) throw new Error(res.data.message || 'InfraLens request failed.');
      return res.data?.data?.data ? { ...res.data, data: res.data.data.data } : res.data;
    },
    refetchInterval: active ? 60000 : false, // Every 60s
    staleTime: 60000,
    enabled: active,
    retry: 2,
  });
}

export function useInfraLensForecast() {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  const isIdle = useUserIdle();
  const active = isMonitoringActive && !isIdle;

  return useQuery({
    queryKey: ['trackops', 'infralens', 'forecast'],
    queryFn: async () => {
      const res = await infralensGetForecastFn({});
      if (res.data?.success === false) throw new Error(res.data.message || 'InfraLens request failed.');
      return res.data?.data?.data ? { ...res.data, data: res.data.data.data } : res.data;
    },
    refetchInterval: active ? 60000 : false,
    staleTime: 60000,
    enabled: active,
  });
}

export function useInfraLensKubernetes() {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  const isIdle = useUserIdle();
  const active = isMonitoringActive && !isIdle;

  return useQuery({
    queryKey: ['trackops', 'infralens', 'kubernetes'],
    queryFn: async () => {
      const res = await infralensGetKubernetesFn({});
      if (res.data?.success === false) throw new Error(res.data.message || 'InfraLens request failed.');
      return res.data?.data?.data ? { ...res.data, data: res.data.data.data } : res.data;
    },
    refetchInterval: active ? 30000 : false,
    staleTime: 30000,
    enabled: active,
  });
}

export function useInfraLensContainers() {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  const isIdle = useUserIdle();
  const active = isMonitoringActive && !isIdle;

  return useQuery({
    queryKey: ['trackops', 'infralens', 'containers'],
    queryFn: async () => {
      const res = await infralensGetContainersFn({});
      if (res.data?.success === false) throw new Error(res.data.message || 'InfraLens request failed.');
      return res.data?.data?.data ? { ...res.data, data: res.data.data.data } : res.data;
    },
    refetchInterval: active ? 30000 : false,
    staleTime: 30000,
    enabled: active,
  });
}
