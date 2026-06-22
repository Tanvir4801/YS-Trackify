import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import LoadingSpinner from '../shared/LoadingSpinner';

export default function ProtectedRoute({ children }) {
  const uid = useAuthStore((s) => s.uid);
  const isLoading = useAuthStore((s) => s.isLoading);

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoadingSpinner label="Loading…" />
      </div>
    );
  }

  if (!uid) return <Navigate to="/login" replace />;

  return children;
}
