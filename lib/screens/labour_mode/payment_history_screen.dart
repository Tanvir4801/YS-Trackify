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
            .where((p) => p.labourId == labour.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final now = DateTime.now();
        final totalPaid    = payments.fold<double>(0, (s, p) => s + p.amount);
        final thisMonth    = payments.where((p) {
          try {
            final d = DateTime.parse(p.date);
            return d.year == now.year && d.month == now.month;
          } catch (_) { return false; }
        }).fold<double>(0, (s, p) => s + p.amount);
        final salaryTotal  = payments.where((p) => p.amount >= labour.dailyWage)
            .fold<double>(0, (s, p) => s + p.amount);
        final advanceTotal = payments.where((p) => p.amount < labour.dailyWage)
            .fold<double>(0, (s, p) => s + p.amount);

        if (payments.isEmpty) {
          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.navy, AppColors.navyLight],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                        size: 42, color: AppColors.gold)),
                    const SizedBox(height: 20),
                    const Text('No Payments Yet',
                      style: TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 20, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    const Text(
                      'Your salary and advance payments will appear here once processed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary,
                        fontSize: 14, height: 1.5)),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Hero summary
              _HeroSummaryCard(
                totalPaid: totalPaid,
                thisMonthTotal: thisMonth,
                salaryTotal: salaryTotal,
                advanceTotal: advanceTotal,
              ),
              const SizedBox(height: 20),
              const Row(children: [
                Icon(Icons.history_rounded, size: 16, color: AppColors.textTertiary),
                SizedBox(width: 8),
                Text('TRANSACTION HISTORY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary, letterSpacing: 1.2)),
              ]),
              const SizedBox(height: 12),
              ...payments.asMap().entries.map((entry) {
                final idx = entry.key;
                final payment = entry.value;
                DateTime? date;
                try { date = DateTime.parse(payment.date); } catch (_) {}
                final fullDate = date != null
                    ? DateFormat('dd MMM yyyy').format(date)
                    : payment.date;
                final isSalary = payment.amount >= labour.dailyWage;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PaymentTile(
                    fullDate: fullDate,
                    amount: payment.amount,
                    isSalary: isSalary,
                    index: idx,
                    total: payments.length,
                  ),
                );
              }),
            ]),
          ),
        );
      },
    );
  }
}

// ── Hero Summary Card ────────────────────────────────────────────────────────
class _HeroSummaryCard extends StatelessWidget {
  const _HeroSummaryCard({
    required this.totalPaid, required this.thisMonthTotal,
    required this.salaryTotal, required this.advanceTotal,
  });

  final double totalPaid;
  final double thisMonthTotal;
  final double salaryTotal;
  final double advanceTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, Color(0xFF1A2438), Color(0xFF202C44)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.4),
          blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet_rounded,
              color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Text('Payment Overview',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          const SizedBox(height: 14),
          Text('₹${totalPaid.toStringAsFixed(0)}',
            style: const TextStyle(color: AppColors.gold,
              fontWeight: FontWeight.w900, fontSize: 36, height: 1)),
          const SizedBox(height: 4),
          Text('Total Received',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _HeroStat(
              label: 'This Month', value: '₹${thisMonthTotal.toStringAsFixed(0)}',
              icon: Icons.calendar_today_rounded, color: AppColors.goldLight)),
            const SizedBox(width: 16),
            Expanded(child: _HeroStat(
              label: 'Salary', value: '₹${salaryTotal.toStringAsFixed(0)}',
              icon: Icons.payments_rounded, color: AppColors.present)),
            const SizedBox(width: 16),
            Expanded(child: _HeroStat(
              label: 'Advances', value: '₹${advanceTotal.toStringAsFixed(0)}',
              icon: Icons.arrow_upward_rounded, color: AppColors.halfDay)),
          ]),
        ]),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label, required this.value,
    required this.icon, required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color,
        fontWeight: FontWeight.w800, fontSize: 14)),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55),
        fontSize: 10, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── Payment Tile ─────────────────────────────────────────────────────────────
class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.fullDate, required this.amount,
    required this.isSalary, required this.index, required this.total,
  });

  final String fullDate;
  final double amount;
  final bool isSalary;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final typeColor = isSalary ? AppColors.navy : AppColors.goldDark;
    final typeBg    = isSalary ? AppColors.primarySurface : AppColors.halfDayBg;
    final typeLabel = isSalary ? 'Salary' : 'Advance';
    final typeIcon  = isSalary ? Icons.payments_rounded : Icons.trending_up_rounded;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: typeColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14)),
            child: Icon(typeIcon, color: typeColor, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Payment Received',
              style: TextStyle(fontWeight: FontWeight.w800,
                fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(fullDate,
              style: const TextStyle(fontSize: 12,
                color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: typeBg,
                borderRadius: BorderRadius.circular(8)),
              child: Text(typeLabel,
                style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700, color: typeColor))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('+₹${amount.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.w900,
                fontSize: 18, color: typeColor)),
            const SizedBox(height: 2),
            Text('#${(total - index).toString().padLeft(3, '0')}',
              style: const TextStyle(fontSize: 10,
                color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}
