'use client';

import { useScrollProgress } from '@/hooks/useScrollProgress';

export function ScrollProgress() {
  const progress = useScrollProgress();

  return (
    <div
      className="fixed top-0 left-0 z-50 h-[2px] bg-trackify-amber transition-[width] duration-100 ease-out"
      style={{
        width: `${progress}%`,
        boxShadow: '0 0 10px rgba(245,158,11,0.5)',
      }}
      role="progressbar"
      aria-valuenow={Math.round(progress)}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-label="Page scroll progress"
    />
  );
}

export default ScrollProgress;
