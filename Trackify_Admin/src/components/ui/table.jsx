import React from 'react';

export function Table({ ...props }) {
  return <table className="w-full caption-bottom text-sm" {...props} />;
}

export function TableHeader({ ...props }) {
  return <thead className="border-b border-slate-200" {...props} />;
}

export function TableBody({ ...props }) {
  return <tbody {...props} />;
}

export function TableFooter({ ...props }) {
  return <tfoot className="border-t border-slate-200 bg-slate-50 font-medium" {...props} />;
}

export function TableRow({ className = '', ...props }) {
  return <tr className={className} {...props} />;
}

export function TableHead({ className = '', ...props }) {
  return <th className={`px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-600 ${className}`} {...props} />;
}

export function TableCell({ className = '', ...props }) {
  return <td className={`px-4 py-3 text-sm text-slate-700 ${className}`} {...props} />;
}
