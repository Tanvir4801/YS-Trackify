interface HazardStripeProps {
  className?: string;
}

export function HazardStripe({ className = '' }: HazardStripeProps) {
  return (
    <div
      className={`hazard-stripe hazard-stripe-thin w-full ${className}`}
      role="separator"
      aria-hidden="true"
    />
  );
}
