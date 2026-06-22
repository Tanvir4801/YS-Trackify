import React from 'react';
import clsx from 'clsx';

const statusColors = {
  present: 'bg-green-500',
  absent: 'bg-red-500',
  half: 'bg-yellow-500',
  supervisor: 'bg-blue-500',
  labour: 'bg-purple-500',
  active: 'bg-green-500',
  inactive: 'bg-gray-500',
  salary: 'bg-sky-500',
  advance: 'bg-amber-500',
  overtime: 'bg-indigo-500',
};

const StatusBadge = ({ status, className, onClick }) => {
  return (
    <span
      onClick={onClick}
      className={clsx(
        'inline-flex items-center rounded-full px-2 py-1 text-sm font-medium text-white',
        statusColors[status] || 'bg-slate-500',
        className,
      )}
    >
      {status}
    </span>
  );
};

export default StatusBadge;