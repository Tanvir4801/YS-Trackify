interface SurveyMarkerProps {
  className?: string;
}

export function SurveyMarker({ className = '' }: SurveyMarkerProps) {
  return (
    <div
      className={`flex items-center justify-center w-full py-8 ${className}`}
      aria-hidden="true"
    >
      {/* Left line */}
      <div className="flex-1 h-px bg-trackify-cardBorder/40" />

      {/* Center marker */}
      <span className="mx-4 font-mono text-xs text-trackify-textMuted/40 select-none">
        +
      </span>

      {/* Right line */}
      <div className="flex-1 h-px bg-trackify-cardBorder/40" />
    </div>
  );
}

export default SurveyMarker;
