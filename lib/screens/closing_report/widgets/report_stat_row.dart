import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// A label-value row with optional color accent and divider.
class ReportStatRow extends StatelessWidget {
  const ReportStatRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
    this.isLarge = false,
    this.icon,
    this.iconColor,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  final bool isLarge;
  final IconData? icon;
  final Color? iconColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: iconColor ?? AppColors.textTertiary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isLarge ? 14 : 13,
                    fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                    color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: isLarge ? 16 : 13,
                  fontWeight: isBold || isLarge ? FontWeight.w700 : FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary,
                  letterSpacing: isLarge ? -0.3 : 0,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: AppColors.borderLight),
      ],
    );
  }
}
