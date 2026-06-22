import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';

export default function RoleRoute({ allowedRoles, children }) {
  const role = useAuthStore((s) => s.role);
  if (!role) return null;
  if (!allowedRoles.includes(role)) {
    if (role === 'trackops') return <Navigate to="/trackops/dashboard" replace />;
    if (role === 'super_admin') return <Navigate to="/sa/dashboard" replace />;
    if (role === 'contractor' || role === 'supervisor') return <Navigate to="/dashboard" replace />;
    
    // Safety fallback for completely unknown/invalid roles to prevent infinite loops
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-900 text-white font-mono p-4">
        <div>
          <h1 className="text-2xl text-red-500 mb-2">ACCESS DENIED</h1>
          <p>Invalid or unrecognized role: <strong>{role}</strong></p>
          <p className="mt-4 text-gray-500 text-sm">Please contact support or sign out.</p>
        </div>
      </div>
    );
  }
  return children;
}
