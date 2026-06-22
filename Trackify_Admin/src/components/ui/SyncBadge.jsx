import React from 'react';
import clsx from 'clsx';

const SyncBadge = ({ isSynced, className, onClick }) => {
  return (
    <span
      onClick={onClick}
      className={clsx(
        'inline-flex items-center rounded-full px-2 py-1 text-sm font-medium text-white',
        isSynced ? 'bg-green-500' : 'bg-orange-500',
        className,
      )}
    >
      {isSynced ? 'Synced' : 'Pending'}
    </span>
  );
};

export default SyncBadge;