import React from 'react';
import { useMemo, useState } from 'react';
import clsx from 'clsx';

const DataTable = ({
  columns = [],
  data = [],
  loading = false,
  searchValue = '',
  searchKeys = [],
  emptyMessage = 'No records found.',
}) => {
  const [sortKey, setSortKey] = useState(null);
  const [sortDirection, setSortDirection] = useState('asc');

  if (loading) {
    return (
      <div className="animate-pulse">
        <div className="mb-4 h-10 rounded bg-gray-300"></div>
        <div className="mb-4 h-10 rounded bg-gray-300"></div>
        <div className="h-10 rounded bg-gray-300"></div>
      </div>
    );
  }

  const filteredData = useMemo(() => {
    if (!searchValue || searchKeys.length === 0) {
      return data;
    }

    const search = searchValue.toLowerCase();
    return data.filter((row) =>
      searchKeys.some((key) => String(row[key] ?? '').toLowerCase().includes(search))
    );
  }, [data, searchKeys, searchValue]);

  const sortedData = useMemo(() => {
    if (!sortKey) {
      return filteredData;
    }

    const column = columns.find((item) => item.key === sortKey);
    if (!column?.sortable) {
      return filteredData;
    }

    return [...filteredData].sort((left, right) => {
      const leftValue = left[sortKey];
      const rightValue = right[sortKey];

      if (leftValue === rightValue) return 0;

      const result = leftValue > rightValue ? 1 : -1;
      return sortDirection === 'asc' ? result : -result;
    });
  }, [columns, filteredData, sortDirection, sortKey]);

  return (
    <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">
      <table className="min-w-full divide-y divide-slate-200">
        <thead>
          <tr className="bg-slate-50">
            {columns.map((column) => (
              <th
                key={column.key}
                onClick={() => {
                  if (!column.sortable) return;
                  if (sortKey === column.key) {
                    setSortDirection((current) => (current === 'asc' ? 'desc' : 'asc'));
                  } else {
                    setSortKey(column.key);
                    setSortDirection('asc');
                  }
                }}
                className={clsx(
                  'px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-600',
                  column.sortable && 'cursor-pointer select-none hover:text-slate-900',
                )}
              >
                {column.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-200 bg-white">
          {sortedData.length > 0 ? (
            sortedData.map((row) => (
              <tr key={row.id} className="hover:bg-slate-50/60">
                {columns.map((column) => (
                  <td key={column.key} className="px-4 py-3 text-sm text-slate-700">
                    {column.render ? column.render(row[column.key], row) : row[column.key]}
                  </td>
                ))}
              </tr>
            ))
          ) : (
            <tr>
              <td className="px-4 py-8 text-center text-sm text-slate-500" colSpan={columns.length || 1}>
                {emptyMessage}
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
};

export default DataTable;