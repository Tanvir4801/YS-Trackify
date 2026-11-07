/**
 * Format a number as Indian Rupee currency with proper grouping.
 * e.g. 150000 → "₹1,50,000"
 */
export function formatINR(amount: number): string {
  const formatted = amount.toLocaleString('en-IN', {
    maximumFractionDigits: 0,
  });
  return `₹${formatted}`;
}

/**
 * Format a number with Indian grouping (no currency symbol).
 * e.g. 150000 → "1,50,000"
 */
export function formatIndianNumber(num: number): string {
  return num.toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

