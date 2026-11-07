import { useState, useEffect, useRef } from 'react';

export function useCountUp(
  end: number,
  duration = 2000,
  startOnView = true
): { value: number; ref: React.RefObject<HTMLElement | null> } {
  const [value, setValue] = useState(0);
  const ref = useRef<HTMLElement | null>(null);
  const hasStarted = useRef(false);

  useEffect(() => {
    if (!startOnView) {
      animateCount();
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !hasStarted.current) {
          hasStarted.current = true;
          animateCount();
        }
      },
      { threshold: 0.3 }
    );

    if (ref.current) observer.observe(ref.current);
    return () => observer.disconnect();

    function animateCount() {
      const startTime = performance.now();
      const step = (currentTime: number) => {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3);
        setValue(Math.round(eased * end));
        if (progress < 1) requestAnimationFrame(step);
      };
      requestAnimationFrame(step);
    }
  }, [end, duration, startOnView]);

  return { value, ref };
}

