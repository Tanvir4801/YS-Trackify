import { useQuery, useInfiniteQuery, useQueryClient } from '@tanstack/react-query';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';
import { useTrackOpsMonitoring } from '../../context/TrackOpsMonitoringContext';

// Define endpoints
const getAnalyticsFn = httpsCallable(functions, 'trackopsGetAnalytics');
const getBillingFn = httpsCallable(functions, 'trackopsGetBilling');
const getLogsFn = httpsCallable(functions, 'trackopsGetPaginatedLogs');

const vercelGetProjectFullFn = httpsCallable(functions, 'vercelGetProjectFull');
const vercelGetAnalyticsFn = httpsCallable(functions, 'vercelGetDeploymentAnalytics');
const vercelGetLogsFn = httpsCallable(functions, 'vercelGetDeploymentLogs');
const vercelGetFilesFn = httpsCallable(functions, 'vercelGetDeploymentFiles');
const getVercelProjectFn = httpsCallable(functions, 'vercelGetProjectFull');

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
  return useQuery({
    queryKey: ['trackops', 'vercel', 'dashboard'],
    queryFn: async () => {
      const res = await vercelGetProjectFullFn({});
      return res.data?.data || null;
    },
    refetchInterval: isMonitoringActive ? 5000 : false,
    staleTime: 5000,
    enabled: isMonitoringActive,
  });
}

/**
 * useTrackOpsVercelAnalytics
 * Polled every 30s
 */
export function useTrackOpsVercelAnalytics(projectId) {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  return useQuery({
    queryKey: ['trackops', 'vercel', 'analytics', projectId],
    queryFn: async () => {
      const res = await vercelGetAnalyticsFn({ projectId });
      return res.data?.data || null;
    },
    refetchInterval: !isMonitoringActive || !projectId ? false : 30000,
    staleTime: 30000,
    enabled: !!projectId && isMonitoringActive,
  });
}

/**
 * useTrackOpsVercelLogs
 * Polled every 5s
 */
export function useTrackOpsVercelLogs(deploymentId) {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  return useQuery({
    queryKey: ['trackops', 'vercel', 'logs', deploymentId],
    queryFn: async () => {
      const res = await vercelGetLogsFn({ deploymentId });
      return res.data?.data || null;
    },
    refetchInterval: !isMonitoringActive || !deploymentId ? false : 5000,
    staleTime: 5000,
    enabled: !!deploymentId && isMonitoringActive,
  });
}

/**
 * useTrackOpsVercelFiles
 * Polled every 60s
 */
export function useTrackOpsVercelFiles(deploymentId) {
  const { isMonitoringActive } = useTrackOpsMonitoring();
  return useQuery({
    queryKey: ['trackops', 'vercel', 'files', deploymentId],
    queryFn: async () => {
      const res = await vercelGetFilesFn({ deploymentId });
      return res.data?.data || null;
    },
    refetchInterval: !isMonitoringActive || !deploymentId ? false : 60000,
    staleTime: 60000,
    enabled: !!deploymentId && isMonitoringActive,
  });
}
