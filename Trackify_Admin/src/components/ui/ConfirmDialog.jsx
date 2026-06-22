import React from 'react';
import Modal from './Modal';

const ConfirmDialog = ({
  isOpen,
  title = 'Confirm action',
  message,
  onClose,
  onConfirm,
  confirmText = 'Confirm',
  cancelText = 'Cancel',
}) => {
  return (
    <Modal
      isOpen={isOpen}
      title={title}
      onClose={onClose}
      onConfirm={onConfirm}
      confirmText={confirmText}
      cancelText={cancelText}
    >
      <p>{message}</p>
    </Modal>
  );
};

export default ConfirmDialog;