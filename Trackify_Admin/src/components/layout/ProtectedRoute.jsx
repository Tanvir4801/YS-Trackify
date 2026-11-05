import React, { useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import LoadingSpinner from '../shared/LoadingSpinner';

export default function ProtectedRoute({ children }) {
  const uid = useAuthStore((s) => s.uid);
  const isLoading = useAuthStore((s) => s.isLoading);
  const setLoading = useAuthStore((s) => s.setLoading);
  const [timedOut, setTimedOut] = useState(false);

  useEffect(() => {
    if (!isLoading) return;
    // Failsafe: if auth state takes longer than 2.5s, unblock loading state
    const timer = setTimeout(() => {
      setTimedOut(true);
      setLoading(false);
    }, 2500);
    return () => clearTimeout(timer);
  }, [isLoading, setLoading]);

  if (isLoading && !timedOut) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoadingSpinner label="Loading…" />
      </div>
    );
  }

  if (!uid) return <Navigate to="/login" replace />;

  return children;
}
