import { useEffect, useState } from 'react';
import { useScopeId, useAuthStore } from '../store/authStore';
import { subscribeProjects, subscribeMilestones, subscribeClientPayments, subscribeProjectDocuments } from '../lib/services/clients.service';

export function useProjects(clientId = null) {
  const role = useAuthStore((s) => s.role);
  const uid = useAuthStore((s) => s.uid);
  const scopeId = useScopeId(); 

  const [data, setData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!scopeId) {
      setData([]);
      setIsLoading(false);
      return undefined;
    }
    setIsLoading(true);
    setError(null);
    const unsub = subscribeProjects(
      scopeId,
      clientId,
      (list) => {
        setData(list);
        setIsLoading(false);
      },
      (err) => {
        setError(err);
        setIsLoading(false);
      }
    );
    return () => unsub();
  }, [scopeId, clientId, role, uid]);

  return { data, isLoading, error };
}

export function useMilestones(projectId) {
  const [data, setData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!projectId) {
      setData([]);
      setIsLoading(false);
      return undefined;
    }
    setIsLoading(true);
    const unsub = subscribeMilestones(projectId, (list) => {
      setData(list);
      setIsLoading(false);
    });
    return () => unsub();
  }, [projectId]);

  return { data, isLoading };
}

export function useClientPayments(projectId) {
  const [data, setData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!projectId) {
      setData([]);
      setIsLoading(false);
      return undefined;
    }
    setIsLoading(true);
    const unsub = subscribeClientPayments(projectId, (list) => {
      setData(list);
      setIsLoading(false);
    });
    return () => unsub();
  }, [projectId]);

  return { data, isLoading };
}

export function useProjectDocuments(projectId) {
  const [data, setData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!projectId) {
      setData([]);
      setIsLoading(false);
      return undefined;
    }
    setIsLoading(true);
    const unsub = subscribeProjectDocuments(projectId, (list) => {
      setData(list);
      setIsLoading(false);
    });
    return () => unsub();
  }, [projectId]);

  return { data, isLoading };
}
