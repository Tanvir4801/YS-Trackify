import React from 'react';

export function Table({ ...props }) {
  return <table className="w-full caption-bottom text-sm" {...props} />;
}

export function TableHeader({ ...props }) {
  return <thead className="border-b border-border" {...props} />;
}

export function TableBody({ ...props }) {
  return <tbody {...props} />;
}

export function TableFooter({ ...props }) {
  return <tfoot className="border-t border-border bg-bg-elevated font-medium" {...props} />;
}

export function TableRow({ className = '', ...props }) {
  return <tr className={className} {...props} />;
}

export function TableHead({ className = '', ...props }) {
  return <th className={`px-6 py-4 text-left text-[10px] font-medium uppercase tracking-widest text-text-muted ${className}`} {...props} />;
}

export function TableCell({ className = '', ...props }) {
  return <td className={`px-6 py-4 text-[13px] text-text-primary ${className}`} {...props} />;
}
