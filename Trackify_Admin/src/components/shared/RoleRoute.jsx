import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';

export default function RoleRoute({ allowedRoles, fallback = '/attendance', children }) {
  const role = useAuthStore((s) => s.role);
  if (!role) return null;
  if (!allowedRoles.includes(role)) {
    return <Navigate to={fallback} replace />;
  }
  return children;
}
