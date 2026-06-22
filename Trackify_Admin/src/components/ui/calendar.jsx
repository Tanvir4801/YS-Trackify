import React from 'react';
import clsx from 'clsx';

const formatDate = (date) => {
  if (!date) return '';
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

export function Calendar({ selected, onSelect, className }) {
  return (
    <input
      type="date"
      value={selected ? formatDate(selected) : ''}
      onChange={(event) => onSelect?.(event.target.value ? new Date(`${event.target.value}T00:00:00`) : undefined)}
      className={clsx('h-10 rounded-md border border-slate-300 px-3 text-sm text-slate-900', className)}
    />
  );
}
