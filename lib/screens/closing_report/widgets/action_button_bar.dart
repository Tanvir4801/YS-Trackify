import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Bottom action buttons bar for the closing report screen.
class ActionButtonBar extends StatelessWidget {
  const ActionButtonBar({
    super.key,
    required this.onWhatsApp,
    required this.onDownloadPdf,
    required this.onCopy,
    required this.onSave,
    this.isSaving = false,
  });

  final VoidCallback onWhatsApp;
  final VoidCallback onDownloadPdf;
  final VoidCallback onCopy;
  final VoidCallback onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                color: AppColors.success,
                onTap: onWhatsApp,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF',
                color: AppColors.danger,
                onTap: onDownloadPdf,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.copy_rounded,
                label: 'Copy',
                color: AppColors.blue,
                onTap: onCopy,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: isSaving
                    ? Icons.hourglass_top_rounded
                    : Icons.bookmark_rounded,
                label: isSaving ? 'Saving...' : 'Save',
                color: AppColors.gold,
                onTap: isSaving ? () {} : onSave,
                isPrimary: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary
              ? color.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? color.withValues(alpha: 0.4)
                : color.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
