import React, { createContext, useContext, useMemo, useState } from 'react';
import clsx from 'clsx';

const PopoverContext = createContext(null);

export function Popover({ children }) {
  const [open, setOpen] = useState(false);
  const value = useMemo(() => ({ open, setOpen }), [open]);

  return (
    <PopoverContext.Provider value={value}>
      <div className="relative inline-block">{children}</div>
    </PopoverContext.Provider>
  );
}

export function PopoverTrigger({ asChild = false, children }) {
  const context = useContext(PopoverContext);
  if (!context) return children;

  const triggerProps = {
    onClick: () => context.setOpen((current) => !current),
  };

  if (asChild && React.isValidElement(children)) {
    return React.cloneElement(children, triggerProps);
  }

  return <button type="button" {...triggerProps}>{children}</button>;
}

export function PopoverContent({ className, align = 'center', children }) {
  const context = useContext(PopoverContext);
  if (!context?.open) return null;

  const alignClasses = {
    start: 'left-0',
    center: 'left-1/2 -translate-x-1/2',
    end: 'right-0',
  };

  return (
    <div
      className={clsx(
        'absolute z-50 mt-2 rounded-md border border-slate-200 bg-white p-2 shadow-lg',
        alignClasses[align] || alignClasses.center,
        className,
      )}
    >
      {children}
    </div>
  );
}
