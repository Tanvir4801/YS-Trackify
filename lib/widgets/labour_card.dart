import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/labour.dart';

class LabourCard extends StatelessWidget {
  const LabourCard({
    super.key,
    required this.labour,
    required this.advanceAmount,
    this.todayStatus,
    this.onTap,
    this.onAdvanceTap,
    this.onMenuTap,
  });

  final Labour labour;
  final double advanceAmount;
  final String? todayStatus;
  final VoidCallback? onTap;
  final VoidCallback? onAdvanceTap;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final initial = labour.name.isNotEmpty
        ? labour.name[0].toUpperCase()
        : '?';

    final statusColor = todayStatus == 'present'
        ? AppColors.present
        : todayStatus == 'half'
            ? AppColors.halfDay
            : todayStatus == 'absent'
                ? AppColors.absent
                : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (statusColor != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labour.name, style: AppTextStyles.headingMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${labour.role.isNotEmpty ? labour.role : "Worker"}'
                        ' • ₹${labour.dailyWage.toStringAsFixed(0)}/day',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onMenuTap,
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.textTertiary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone_outlined,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(labour.phoneNumber, style: AppTextStyles.bodyMedium),
                const Spacer(),
                if (advanceAmount > 0) ...[
                  GestureDetector(
                    onTap: onAdvanceTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.amberCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.halfDay.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.currency_rupee,
                              size: 12, color: AppColors.halfDay),
                          Text(
                            'Adv ₹${advanceAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.halfDay,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: onAdvanceTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 12, color: AppColors.primary),
                        const SizedBox(width: 3),
                        const Text(
                          'Advance',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
