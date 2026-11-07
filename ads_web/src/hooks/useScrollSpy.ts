import { useState, useEffect, useRef, useCallback } from 'react';

const NAVBAR_OFFSET = 75; // 65px navbar + 3px hazard line + 7px breathing room

export function useScrollSpy(sectionIds: string[]) {
  const [activeId, setActiveId] = useState<string>('');
  const lockTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const isLockedRef = useRef(false);

  const scrollToSection = useCallback((id: string) => {
    const element = document.getElementById(id);
    if (!element) return;

    // Immediately lock active state to clicked section
    setActiveId(id);
    isLockedRef.current = true;

    if (lockTimerRef.current) {
      clearTimeout(lockTimerRef.current);
    }

    // Exact scroll calculation accounting for sticky navbar
    const elementPosition = element.getBoundingClientRect().top + window.scrollY;
    const offsetPosition = Math.max(0, elementPosition - NAVBAR_OFFSET);

    window.scrollTo({
      top: offsetPosition,
      behavior: 'smooth',
    });

    // Update URL hash smoothly without jump
    if (window.history.pushState) {
      window.history.pushState(null, '', `#${id}`);
    }

    // Release lock once smooth scrolling has concluded
    lockTimerRef.current = setTimeout(() => {
      isLockedRef.current = false;
    }, 900);
  }, []);

  useEffect(() => {
    const handleScroll = () => {
      // Do not override if user clicked a nav link and scroll is animating
      if (isLockedRef.current) return;

      const scrollPosition = window.scrollY + NAVBAR_OFFSET + 30;
      const windowHeight = window.innerHeight;
      const documentHeight = document.documentElement.scrollHeight;

      // If at the very bottom of page, activate last section
      if (window.scrollY + windowHeight >= documentHeight - 60) {
        const lastId = sectionIds[sectionIds.length - 1];
        if (lastId) setActiveId(lastId);
        return;
      }

      // If at the very top (above first section)
      if (window.scrollY < 120) {
        setActiveId('');
        return;
      }

      // Find section currently in view
      let currentSection = '';
      for (const id of sectionIds) {
        const el = document.getElementById(id);
        if (!el) continue;

        const top = el.offsetTop;
        const height = el.offsetHeight;

        if (scrollPosition >= top && scrollPosition < top + height) {
          currentSection = id;
          break;
        }
      }

      if (currentSection) {
        setActiveId(currentSection);
      }
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    // Run once on mount
    handleScroll();

    return () => {
      window.removeEventListener('scroll', handleScroll);
      if (lockTimerRef.current) clearTimeout(lockTimerRef.current);
    };
  }, [sectionIds]);

  return { activeId, setActiveId, scrollToSection };
}

export default useScrollSpy;
