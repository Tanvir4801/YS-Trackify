import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/labour_model.dart';
import 'labour_heatmap.dart';
import 'labour_quick_sheet.dart';
import 'quick_advance_dialog.dart';

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

    // 'pending' is treated as not-yet-marked — no status dot shown
    final statusColor = todayStatus == 'present'
        ? AppColors.present
        : todayStatus == 'half'
            ? AppColors.halfDay
            : todayStatus == 'absent'
                ? AppColors.absent
                : null; // null for pending/unknown → no dot rendered

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
                GestureDetector(
                  onTap: () => LabourQuickSheet.show(context, labour),
                  child: Stack(
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labour.name, style: AppTextStyles.headingMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${labour.type == LabourType.regular ? "Regular" : "Temporary"}'
                        ' • ₹${labour.dailyWage.toStringAsFixed(0)}/day',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      LabourHeatmap(
                        labourId: labour.id, 
                        contractorId: labour.contractorId ?? '',
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
                GestureDetector(
                  onTap: () async {
                    if (labour.phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No phone number added for ${labour.name}')),
                      );
                      return;
                    }
                    final uri = Uri(scheme: 'tel', path: labour.phone);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: labour.phone.isNotEmpty 
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.phone_rounded,
                      size: 20,
                      color: labour.phone.isNotEmpty
                          ? const Color(0xFF10B981)
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  labour.phone.isNotEmpty ? labour.phone : 'No phone',
                  style: AppTextStyles.bodyMedium,
                ),
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
                  onTap: () => showAdvanceDialog(context, labour),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 12, color: AppColors.primary),
                        SizedBox(width: 3),
                        Text(
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
