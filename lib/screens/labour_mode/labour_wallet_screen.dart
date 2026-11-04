import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/attendance_model.dart';
import '../../models/labour_model.dart';
import '../../models/payment_model.dart';
import '../../services/labour_mode/labour_firestore_service.dart';

class LabourWalletScreen extends StatelessWidget {
  const LabourWalletScreen({
    super.key,
    required this.labour,
    required this.firestoreService,
  });

  final Labour labour;
  final LabourFirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundColor(context),
      child: StreamBuilder<List<Attendance>>(
        stream: firestoreService.streamAttendance(labour.id),
        builder: (context, attSnapshot) {
          if (!attSnapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryColor(context)));
          }

          return StreamBuilder<List<Payment>>(
            stream: firestoreService.streamPayments(labour.id),
            builder: (context, paySnapshot) {
              if (!paySnapshot.hasData) {
                return Center(child: CircularProgressIndicator(color: AppColors.primaryColor(context)));
              }

              final records = attSnapshot.data!;
              final payments = paySnapshot.data!;
              
              final summary = firestoreService.buildDashboardSummary(labour, records, payments);
              final netPay = summary.finalPay;
              final grossSalary = summary.totalEarned;

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel(label: 'CURRENT BALANCE'),
                      const SizedBox(height: 12),
                      _WalletBalanceCard(
                        totalSalary: grossSalary,
                        advanceTaken: summary.advanceTaken,
                        netPayable: netPay,
                        paidSalary: 0, // Since paid salary is usually recorded when settled
                      ),
                      const SizedBox(height: 24),
                      const _SectionLabel(label: 'RECENT TRANSACTIONS'),
                      const SizedBox(height: 12),
                      if (payments.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.cardColor(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderColor(context)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.history_rounded, color: AppColors.textTertiaryColor(context), size: 40),
                              const SizedBox(height: 12),
                              Text('No Transactions Yet', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Advances and salary payments will appear here.', style: TextStyle(color: AppColors.textTertiaryColor(context), fontSize: 12), textAlign: TextAlign.center),
                            ],
                          ),
                        )
                      else
                        ...payments.map((payment) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TransactionCard(payment: payment),
                        )),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryColor(context),
        letterSpacing: 1.2,
      ),
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({
    required this.totalSalary,
    required this.advanceTaken,
    required this.netPayable,
    required this.paidSalary,
  });

  final double totalSalary;
  final double advanceTaken;
  final double netPayable;
  final double paidSalary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderColor(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimaryColor(context).withValues(alpha: 0.04),
            blurRadius: 15,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NET PAYABLE', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryColor(context), size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${netPayable.toStringAsFixed(0)}',
            style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 36, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Divider(color: AppColors.borderColor(context)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(context, 'Gross Salary', '₹${totalSalary.toStringAsFixed(0)}', AppColors.textPrimaryColor(context)),
              _buildMiniStat(context, 'Advances', '-₹${advanceTaken.toStringAsFixed(0)}', AppColors.errorColor(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textTertiaryColor(context), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final isAdvance = payment.type == PaymentType.advance;
    final iconColor = isAdvance ? AppColors.errorColor(context) : AppColors.successColor(context);
    final bgColor = iconColor.withValues(alpha: 0.1);
    final sign = isAdvance ? '-' : '+';
    
    String title = isAdvance ? 'Advance Taken' : 'Salary Settlement';
    if (payment.notes.isNotEmpty) {
      title += ' - ${payment.notes}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAdvance ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(payment.date),
                  style: TextStyle(color: AppColors.textTertiaryColor(context), fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '$sign₹${payment.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: iconColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
