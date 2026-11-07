import React from 'react';
import { useAuthStore } from '../store/authStore';
import toast from 'react-hot-toast';

/**
 * Central hook for Demo Mode permissions.
 *
 * In Demo Mode:
 * - canRead: true (can view all tables, charts, profiles, filters)
 * - canWrite: false (cannot add/update/delete any document)
 * - canDelete: false
 * - canManageSettings: false
 */
export function useDemoPermissions() {
  const role = useAuthStore((s) => s.role);
  const isDemoStore = Boolean(useAuthStore((s) => s.isDemo));
  const isDemoStorage =
    typeof window !== 'undefined' && sessionStorage.getItem('trackify_demo_mode') === 'true';
  const isDemo = role === 'demo' || isDemoStore || isDemoStorage;

  const canRead = true;
  const canWrite = !isDemo;
  const canDelete = !isDemo;
  const canManageSettings = !isDemo;

  /**
   * Guards any user mutation attempt. If in demo mode, blocks execution
   * and displays a professional informative toast notification.
   */
  const guardAction = (callback, actionDescription = 'This operation') => {
    if (isDemo) {
      toast(
        (t) => (
          <div className="flex flex-col gap-1 text-left">
            <span className="font-semibold text-amber-400 text-sm flex items-center gap-1.5">
              <span>🔒</span> Action Disabled in Demo Mode
            </span>
            <span className="text-xs text-slate-300 leading-relaxed">
              {actionDescription} is restricted in demo mode. Contact our team to activate full company operations.
            </span>
          </div>
        ),
        {
          duration: 4000,
          position: 'top-right',
          style: {
            background: '#0F1A2E',
            color: '#F8FAFC',
            border: '1px solid rgba(245, 158, 11, 0.4)',
            boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.5)',
          },
        }
      );
      return false;
    }

    return callback ? callback() : true;
  };

  return {
    isDemo,
    canRead,
    canWrite,
    canDelete,
    canManageSettings,
    guardAction,
  };
}
