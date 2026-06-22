import React, { useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { LifeBuoy, MessageCircle, CheckCircle, XCircle } from 'lucide-react';
import toast from 'react-hot-toast';
import { useSupportRequests, updateSupportRequestStatus } from '../hooks/useSupportRequests';
import { useLabours } from '../hooks/useLabours';
import { toDateKeySafe } from '../lib/utils';
import LoadingSpinner from '../components/shared/LoadingSpinner';
import EmptyState from '../components/shared/EmptyState';
import Pagination, { usePagination } from '../components/shared/Pagination';
import { Button } from '../components/ui/button';

const STATUS_BADGE = {
  Pending: 'bg-warning-bg border border-warning/30 text-warning',
  Resolved: 'bg-success-bg border border-success/30 text-success',
  Rejected: 'bg-danger-bg border border-danger/30 text-danger',
};

export default function SupportRequests() {
  const queryClient = useQueryClient();
  const { data: requests = [], isLoading } = useSupportRequests();
  const { data: labours = [] } = useLabours();
  const [pageSize, setPageSize] = useState(25);
  const [updating, setUpdating] = useState(null);

  const labourMap = useMemo(() => {
    const map = new Map();
    labours.forEach((l) => map.set(l.id, l));
    return map;
  }, [labours]);

  const { page, pageCount, paginated, setPage, total } = usePagination(requests, pageSize);

  const handleStatusChange = async (requestId, newStatus) => {
    setUpdating(requestId);
    try {
      await updateSupportRequestStatus(requestId, newStatus);
      toast.success(`Request marked as ${newStatus}`);
      queryClient.invalidateQueries({ queryKey: ['support_requests'] });
    } catch (err) {
      console.error(err);
      toast.error('Failed to update status');
    } finally {
      setUpdating(null);
    }
  };

  const handleWhatsApp = (labourId, labourName, description) => {
    const labour = labourMap.get(labourId);
    if (!labour || !labour.phone) {
      return toast.error('No phone number found for this labourer');
    }
    
    let phone = labour.phone.replace(/[^\d+]/g, '');
    if (!phone.startsWith('+')) phone = '+91' + phone;

    const message = `Hello ${labourName}, regarding your support request: "${description}" - `;
    const url = `https://wa.me/${phone}?text=${encodeURIComponent(message)}`;
    window.open(url, '_blank');
  };

  return (
    <div className="space-y-6">
      <div className="rounded-2xl border border-border bg-bg-card p-4 shadow-sm flex flex-wrap items-center justify-between gap-3">
        <div className="text-[13px] text-text-secondary">
          <span className="font-mono font-bold text-text-primary">{requests.length}</span> request{requests.length === 1 ? '' : 's'} total
        </div>
      </div>

      <div className="rounded-2xl border border-border bg-bg-card shadow-sm overflow-hidden">
        {isLoading ? (
          <LoadingSpinner label="Loading requests…" />
        ) : requests.length === 0 ? (
          <EmptyState icon={LifeBuoy} title="No support requests" description="You're all caught up!" />
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full text-[13px]">
                <thead className="sticky top-0 border-b border-border bg-bg-elevated text-left text-[10px] uppercase tracking-widest text-text-muted">
                  <tr>
                    <th className="px-6 py-4 font-medium">Date</th>
                    <th className="px-6 py-4 font-medium">Labour</th>
                    <th className="px-6 py-4 font-medium">Site</th>
                    <th className="px-6 py-4 font-medium">Issue Type</th>
                    <th className="px-6 py-4 font-medium">Description</th>
                    <th className="px-6 py-4 font-medium">Status</th>
                    <th className="px-6 py-4 font-medium text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {paginated.map((r) => {
                    const isUpdating = updating === r.id;
                    return (
                      <tr key={r.id} className={`border-b border-border last:border-b-0 hover:bg-bg-card-hover transition-colors ${isUpdating ? 'opacity-50' : ''}`}>
                        <td className="px-6 py-4 font-mono text-text-secondary">
                          {r.createdAt ? new Date(r.createdAt.seconds * 1000).toLocaleDateString() : r.date}
                        </td>
                        <td className="px-6 py-4 font-medium text-text-primary text-[14px]">
                          {r.labourName || r.labourId}
                        </td>
                        <td className="px-6 py-4 text-text-secondary">{r.siteName || '—'}</td>
                        <td className="px-6 py-4 text-text-secondary font-medium">{r.issueType}</td>
                        <td className="px-6 py-4 text-text-muted max-w-[200px] truncate" title={r.description}>
                          {r.description}
                        </td>
                        <td className="px-6 py-4">
                          <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-[11px] tracking-wider uppercase font-bold ${STATUS_BADGE[r.status] || STATUS_BADGE.Pending}`}>
                            {r.status || 'Pending'}
                          </span>
                        </td>
                        <td className="px-6 py-4">
                          <div className="flex items-center justify-end gap-2">
                            <button
                              onClick={() => handleWhatsApp(r.labourId, r.labourName, r.description)}
                              className="p-2 rounded-lg text-[#25D366] hover:bg-[#25D366]/10 transition-colors"
                              title="Message on WhatsApp"
                            >
                              <MessageCircle className="h-4 w-4" />
                            </button>
                            
                            {r.status !== 'Resolved' && (
                              <button
                                onClick={() => handleStatusChange(r.id, 'Resolved')}
                                disabled={isUpdating}
                                className="p-2 rounded-lg text-success hover:bg-success/10 transition-colors"
                                title="Mark as Resolved"
                              >
                                <CheckCircle className="h-4 w-4" />
                              </button>
                            )}
                            
                            {r.status !== 'Rejected' && (
                              <button
                                onClick={() => handleStatusChange(r.id, 'Rejected')}
                                disabled={isUpdating}
                                className="p-2 rounded-lg text-danger hover:bg-danger/10 transition-colors"
                                title="Reject Request"
                              >
                                <XCircle className="h-4 w-4" />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <Pagination page={page} pageCount={pageCount} setPage={setPage} total={total} pageSize={pageSize} onPageSizeChange={setPageSize} />
          </>
        )}
      </div>
    </div>
  );
}
