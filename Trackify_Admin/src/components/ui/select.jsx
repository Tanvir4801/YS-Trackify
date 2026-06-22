import React, { createContext, useContext, useMemo } from 'react';
import clsx from 'clsx';

const SelectContext = createContext(null);

const SELECT_ITEM_MARKER = Symbol('SelectItem');
const SELECT_VALUE_MARKER = Symbol('SelectValue');

function collectElements(node, matcher, found = []) {
  React.Children.forEach(node, (child) => {
    if (!React.isValidElement(child)) return;

    if (matcher(child)) {
      found.push(child.props);
    }

    if (child.props?.children) {
      collectElements(child.props.children, matcher, found);
    }
  });

  return found;
}

export function Select({ value, onValueChange, children, className }) {
  const items = useMemo(() => collectElements(children, (child) => child.type?.__selectItem), [children]);
  const valueNode = useMemo(
    () => collectElements(children, (child) => child.type?.__selectValue)[0],
    [children],
  );

  return (
    <SelectContext.Provider value={{ value, onValueChange, items, placeholder: valueNode?.placeholder }}>
      <div className={clsx('inline-flex flex-col', className)}>{children}</div>
    </SelectContext.Provider>
  );
}

export function SelectTrigger({ className, children }) {
  const context = useContext(SelectContext);

  return (
    <select
      value={context?.value ?? ''}
      onChange={(event) => context?.onValueChange?.(event.target.value)}
      className={clsx(
        'h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20',
        className,
      )}
    >
      {context?.placeholder ? <option value="">{context.placeholder}</option> : null}
      {context?.items?.map((item) => (
        <option key={item.value} value={item.value}>
          {item.children}
        </option>
      ))}
    </select>
  );
}

export function SelectContent({ children }) {
  return null;
}

export function SelectItem({ value, children }) {
  return null;
}

SelectItem.__selectItem = SELECT_ITEM_MARKER;

export function SelectValue({ placeholder }) {
  return null;
}

SelectValue.__selectValue = SELECT_VALUE_MARKER;
