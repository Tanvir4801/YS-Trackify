import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../models/labour.dart';
import '../../services/labour_mode/labour_service.dart';
import '../../widgets/labour_mode/labour_stat_card.dart';

class LabourDashboardScreen extends StatelessWidget {
  const LabourDashboardScreen({
    super.key,
    required this.labour,
    required this.labourService,
  });

  final Labour labour;
  final LabourService labourService;

  @override
  Widget build(BuildContext context) {
    final summary = labourService.buildDashboardSummary(labour);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              labour.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              labour.role,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 22),
            Text(
              'Today Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: LabourStatCard(
                title: context.tr('finalPay'),
                value: 'Rs ${summary.finalPay.toStringAsFixed(0)}',
                backgroundColor: summary.finalPay >= 0
                    ? const Color(0xFFD4F5E8)
                    : AppColors.redCard,
                valueColor: summary.finalPay >= 0
                    ? AppColors.present
                    : AppColors.absent,
                gradient: summary.finalPay >= 0
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.present.withValues(alpha: 0.12),
                          const Color(0xFFE6F9EC),
                        ],
                      )
                    : null,
                icon: Icons.verified_outlined,
                isHighlighted: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: LabourStatCard(
                title: context.tr('totalEarned'),
                value: 'Rs ${(summary.basePay + summary.overtimePay).toStringAsFixed(0)}',
                backgroundColor: AppColors.yellowCard,
                valueColor: AppColors.textPrimary,
                subtitle: '${context.tr('basePay')} + ${context.tr('overtimePay')}',
                icon: Icons.calculate_outlined,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: LabourStatCard(
                    title: context.tr('basePay'),
                    value: 'Rs ${summary.basePay.toStringAsFixed(0)}',
                    backgroundColor: AppColors.greenCard,
                    valueColor: AppColors.present,
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LabourStatCard(
                    title: context.tr('advanceTaken'),
                    value: 'Rs ${summary.advanceTaken.toStringAsFixed(0)}',
                    backgroundColor: AppColors.redCard,
                    valueColor: AppColors.absent,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LabourStatCard(
                    title: context.tr('totalDaysWorked'),
                    value: summary.totalDaysWorked.toStringAsFixed(1),
                    backgroundColor: AppColors.blueCard,
                    valueColor: AppColors.primary,
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LabourStatCard(
                    title: context.tr('dailyWage'),
                    value: 'Rs ${summary.dailyWage.toStringAsFixed(0)}',
                    backgroundColor: AppColors.blueCard,
                    valueColor: AppColors.secondary,
                    icon: Icons.currency_rupee,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.08),
                    AppColors.secondary.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('overtimePay'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${context.tr('extraHours')}: ${summary.extraHours.toStringAsFixed(1)} hrs',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Rs ${summary.overtimePay.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
