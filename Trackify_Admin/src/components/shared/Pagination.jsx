import React from 'react';
import { ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight } from 'lucide-react';
import { Button } from '../ui/button';

export function usePagination(data, pageSize = 25) {
  const [page, setPage] = React.useState(0);
  const pageCount = Math.max(1, Math.ceil(data.length / pageSize));
  const safePage = Math.min(page, pageCount - 1);
  const paginated = data.slice(safePage * pageSize, safePage * pageSize + pageSize);

  React.useEffect(() => {
    setPage(0);
  }, [data.length, pageSize]);

  return {
    page: safePage,
    pageCount,
    paginated,
    setPage,
    canPrev: safePage > 0,
    canNext: safePage < pageCount - 1,
    total: data.length,
  };
}

const PAGE_SIZE_OPTIONS = [10, 25, 50, 100];

export default function Pagination({ page, pageCount, setPage, total, pageSize, onPageSizeChange }) {
  if (pageCount <= 1 && total <= (pageSize || 25)) return null;

  const windowPages = [];
  const start = Math.max(0, page - 2);
  const end = Math.min(pageCount - 1, page + 2);
  for (let i = start; i <= end; i++) windowPages.push(i);

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 px-4 py-3 text-sm text-slate-600">
      <div className="flex items-center gap-2">
        <span>Rows per page:</span>
        <select
          value={pageSize || 25}
          onChange={(e) => onPageSizeChange?.(Number(e.target.value))}
          className="h-8 rounded-md border border-slate-300 bg-white px-2 text-xs shadow-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
        >
          {PAGE_SIZE_OPTIONS.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>
        <span className="text-slate-400">
          {page * pageSize + 1}–{Math.min((page + 1) * pageSize, total)} of {total}
        </span>
      </div>
      <div className="flex items-center gap-1">
        <Button variant="outline" size="sm" onClick={() => setPage(0)} disabled={page === 0} className="h-8 w-8 p-0">
          <ChevronsLeft className="h-3.5 w-3.5" />
        </Button>
        <Button variant="outline" size="sm" onClick={() => setPage(page - 1)} disabled={page === 0} className="h-8 w-8 p-0">
          <ChevronLeft className="h-3.5 w-3.5" />
        </Button>
        {start > 0 && <span className="px-1">…</span>}
        {windowPages.map((p) => (
          <Button
            key={p}
            variant={p === page ? 'default' : 'outline'}
            size="sm"
            onClick={() => setPage(p)}
            className={`h-8 w-8 p-0 text-xs ${p === page ? 'bg-blue-600 text-white hover:bg-blue-700' : ''}`}
          >
            {p + 1}
          </Button>
        ))}
        {end < pageCount - 1 && <span className="px-1">…</span>}
        <Button variant="outline" size="sm" onClick={() => setPage(page + 1)} disabled={page >= pageCount - 1} className="h-8 w-8 p-0">
          <ChevronRight className="h-3.5 w-3.5" />
        </Button>
        <Button variant="outline" size="sm" onClick={() => setPage(pageCount - 1)} disabled={page >= pageCount - 1} className="h-8 w-8 p-0">
          <ChevronsRight className="h-3.5 w-3.5" />
        </Button>
      </div>
    </div>
  );
}
