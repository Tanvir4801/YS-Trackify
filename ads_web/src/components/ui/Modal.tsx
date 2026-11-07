'use client';

import { useEffect, useRef, useCallback, type ReactNode } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X } from 'lucide-react';
import { useReducedMotion } from '@/hooks/useReducedMotion';

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: ReactNode;
}

export function Modal({ isOpen, onClose, title, children }: ModalProps) {
  const contentRef = useRef<HTMLDivElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);
  const prefersReduced = useReducedMotion();
  const titleId = title ? 'modal-title' : undefined;

  // Close on Escape key
  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    },
    [onClose],
  );

  // Focus trap & restore
  useEffect(() => {
    if (isOpen) {
      previousFocusRef.current = document.activeElement as HTMLElement;
      document.addEventListener('keydown', handleKeyDown);
      document.body.style.overflow = 'hidden';

      // Focus the close button or content after mount
      requestAnimationFrame(() => {
        const focusable = contentRef.current?.querySelector<HTMLElement>(
          'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
        );
        focusable?.focus();
      });
    }

    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      document.body.style.overflow = '';
      previousFocusRef.current?.focus();
    };
  }, [isOpen, handleKeyDown]);

  // Close on backdrop click
  const handleBackdropClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (e.target === e.currentTarget) onClose();
  };

  const motionProps = prefersReduced
    ? {}
    : {
        initial: { opacity: 0 },
        animate: { opacity: 1 },
        exit: { opacity: 0 },
        transition: { duration: 0.2 },
      };

  const panelMotion = prefersReduced
    ? {}
    : {
        initial: { opacity: 0, scale: 0.95, y: 16 },
        animate: { opacity: 1, scale: 1, y: 0 },
        exit: { opacity: 0, scale: 0.95, y: 16 },
        transition: { duration: 0.25, ease: [0.22, 1, 0.36, 1] },
      };

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4"
          onClick={handleBackdropClick}
          aria-hidden={!isOpen}
          {...motionProps}
        >
          <motion.div
            ref={contentRef}
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            className="glass-card relative w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-xl p-4 sm:p-6 shadow-2xl"
            {...panelMotion}
          >
            {/* Close button */}
            <button
              onClick={onClose}
              className="absolute top-4 right-4 p-1.5 rounded-lg text-trackify-textMuted hover:text-trackify-textMain hover:bg-white/5 transition-colors focus:outline-none focus:ring-2 focus:ring-trackify-amber/50 cursor-pointer"
              aria-label="Close dialog"
            >
              <X className="w-5 h-5" />
            </button>

            {/* Title */}
            {title && (
              <h2
                id={titleId}
                className="font-heading text-xl font-semibold text-trackify-textMain mb-4 pr-8"
              >
                {title}
              </h2>
            )}

            {/* Content */}
            <div>{children}</div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
