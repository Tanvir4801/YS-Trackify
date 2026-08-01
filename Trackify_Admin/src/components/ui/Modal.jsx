import React, { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import clsx from 'clsx';
import { AnimatePresence, motion } from 'framer-motion';

const Modal = ({
  isOpen,
  title,
  children,
  onClose,
  onConfirm,
  confirmText = 'Confirm',
  cancelText = 'Cancel',
  className,
}) => {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    return () => setMounted(false);
  }, []);

  if (!mounted) return null;

  return createPortal(
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-[9999] flex items-center justify-center p-4">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="absolute inset-0 bg-bg-primary/80 backdrop-blur-sm"
            onClick={onClose}
          />
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 10 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 10 }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
            className={clsx('relative w-full max-w-lg rounded-xl border border-border bg-bg-card shadow-[0_25px_60px_rgba(0,0,0,0.6)]', className)}
          >
            <div className="border-b border-border p-5">
              <h2 className="text-[16px] font-semibold tracking-wide text-text-primary uppercase">{title}</h2>
            </div>
            <div className="p-5 text-text-secondary">{children}</div>
            <div className="flex justify-end gap-3 border-t border-border p-5 bg-bg-elevated/50 rounded-b-xl">
              <button
                onClick={onClose}
                className="flex h-9 items-center gap-2 rounded-lg border border-border-strong bg-bg-elevated px-4 text-[13px] font-medium text-text-secondary hover:text-text-primary transition-colors"
              >
                {cancelText}
              </button>
              <button
                onClick={onConfirm}
                className="flex h-9 items-center gap-2 rounded-lg bg-gold px-5 text-[13px] font-semibold text-bg-primary shadow-[0_0_15px_rgba(245,166,35,0.2)] hover:scale-105 transition-all"
              >
                {confirmText}
              </button>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>,
    document.body
  );
};

export default Modal;