import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/labour.dart';
import '../../models/payment.dart';
import '../../services/hive_service.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({
    super.key,
    required this.labour,
    required this.hiveService,
  });

  final Labour labour;
  final HiveService hiveService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BoxEvent>(
      stream: Hive.box<Payment>(HiveService.paymentBoxName).watch(),
      builder: (context, _) {
        final paymentBox = Hive.box<Payment>(HiveService.paymentBoxName);
        final payments = paymentBox.values
            .where((item) => item.labourId == labour.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final now = DateTime.now();
        final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
        final thisMonthTotal = payments.where((payment) {
          try {
            final date = DateTime.parse(payment.date);
            return date.year == now.year && date.month == now.month;
          } catch (_) {
            return false;
          }
        }).fold<double>(0, (sum, p) => sum + p.amount);

        final remainingAmount = (labour.advanceAmount - totalPaid)
            .clamp(0, double.infinity)
            .toDouble();

        if (payments.isEmpty) {
          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 82,
                      width: 82,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        size: 42,
                        color: AppColors.primary.withValues(alpha: 0.58),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No payments yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color:
                                AppColors.textPrimary.withValues(alpha: 0.82),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Payment entries will show up here once added.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                AppColors.textPrimary.withValues(alpha: 0.50),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Paid',
                        value: '₹${totalPaid.toStringAsFixed(0)}',
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        title: 'This Month',
                        value: '₹${thisMonthTotal.toStringAsFixed(0)}',
                        icon: Icons.calendar_month_outlined,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SummaryCard(
                  title: 'Remaining Amount',
                  value: '₹${remainingAmount.toStringAsFixed(0)}',
                  icon: Icons.hourglass_bottom_outlined,
                  color: const Color(0xFFAD1457),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.history_edu_outlined,
                      size: 21,
                      color: AppColors.textPrimary.withValues(alpha: 0.80),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Payment History',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...payments.map((payment) {
                  DateTime? date;
                  try {
                    date = DateTime.parse(payment.date);
                  } catch (_) {
                    date = null;
                  }

                  final fullDate = date != null
                      ? DateFormat('dd MMM yyyy').format(date)
                      : payment.date;

                  final paymentType =
                      payment.amount >= labour.dailyWage ? 'Salary' : 'Advance';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PaymentTile(
                      fullDate: fullDate,
                      amount: payment.amount,
                      paymentType: paymentType,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary.withValues(alpha: 0.74),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.fullDate,
    required this.amount,
    required this.paymentType,
  });

  final String fullDate;
  final double amount;
  final String paymentType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 18,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Received',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  fullDate,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withValues(alpha: 0.58),
                      ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    paymentType,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1976D2),
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                ),
          ),
        ],
      ),
    );
  }
}
