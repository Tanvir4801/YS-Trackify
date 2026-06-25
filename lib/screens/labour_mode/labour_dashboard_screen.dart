import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_colors.dart';
import '../../models/labour.dart';
import '../../services/labour_mode/labour_service.dart';

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
    final netPay = summary.finalPay;
    final isPositive = netPay >= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroEarningsCard(
            labour: labour,
            summary: summary,
            netPay: netPay,
            isPositive: isPositive,
          ),
          const SizedBox(height: 20),
          _SectionLabel(label: AppText.quickStats),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _QuickStatChip(
              icon: Icons.calendar_today_rounded,
              label: 'Days Worked',
              value: summary.totalDaysWorked.toStringAsFixed(1),
              color: AppColors.navy,
            )),
            const SizedBox(width: 10),
            Expanded(child: _QuickStatChip(
              icon: Icons.bolt_rounded,
              label: 'OT Hours',
              value: '${summary.extraHours.toStringAsFixed(1)}h',
              color: AppColors.goldDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _QuickStatChip(
              icon: Icons.currency_rupee_rounded,
              label: 'Daily Rate',
              value: '₹${summary.dailyWage.toStringAsFixed(0)}',
              color: AppColors.present,
            )),
          ]),
          const SizedBox(height: 20),
          _SectionLabel(label: AppText.earningsBreakdown),
          const SizedBox(height: 10),
          _EarningsBreakdownCard(summary: summary),
          const SizedBox(height: 20),
          if (summary.extraHours > 0) ...[
            _SectionLabel(label: 'Overtime'),
            const SizedBox(height: 10),
            _OvertimeCard(
              hours: summary.extraHours,
              rate: labour.overtimeRate,
              earned: summary.overtimePay,
            ),
            const SizedBox(height: 20),
          ],
          if (summary.advanceTaken > 0) ...[
            _SectionLabel(label: 'Advance Taken'),
            const SizedBox(height: 10),
            _AdvanceCard(amount: summary.advanceTaken),
          ],
        ],
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
      style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: AppColors.textTertiary, letterSpacing: 1.0),
    );
  }
}

// ── Hero Card ────────────────────────────────────────────────────────────────
class _HeroEarningsCard extends StatelessWidget {
  const _HeroEarningsCard({
    required this.labour, required this.summary,
    required this.netPay, required this.isPositive,
  });

  final Labour labour;
  final dynamic summary;
  final double netPay;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF1A2438), Color(0xFF202C44)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(color: AppColors.navy.withValues(alpha: 0.45),
            blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(children: [
        Positioned(top: -30, right: -20,
          child: Container(width: 140, height: 140,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.05)))),
        Positioned(bottom: -40, right: 40,
          child: Container(width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.04)))),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    labour.name.isNotEmpty ? labour.name[0].toUpperCase() : 'L',
                    style: const TextStyle(color: AppColors.gold,
                      fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(labour.name,
                    style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 18),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    labour.role.isNotEmpty ? labour.role : 'Construction Worker',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, color: AppColors.gold, size: 7),
                  SizedBox(width: 5),
                  Text('Active', style: TextStyle(
                    color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: 22),
            Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _HeroStatItem(
                label: 'Net Payable',
                value: '₹${netPay.abs().toStringAsFixed(0)}',
                valueColor: isPositive ? AppColors.gold : AppColors.absent,
                isLarge: true,
              )),
              Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.12)),
              Expanded(child: _HeroStatItem(
                label: 'Base Earned',
                value: '₹${summary.basePay.toStringAsFixed(0)}',
                valueColor: Colors.white,
              )),
              Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.12)),
              Expanded(child: _HeroStatItem(
                label: 'Overtime',
                value: '₹${summary.overtimePay.toStringAsFixed(0)}',
                valueColor: AppColors.goldLight,
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _HeroStatItem extends StatelessWidget {
  const _HeroStatItem({
    required this.label, required this.value, required this.valueColor,
    this.isLarge = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
        style: TextStyle(color: valueColor, fontWeight: FontWeight.w900,
          fontSize: isLarge ? 22 : 16)),
      const SizedBox(height: 4),
      Text(label,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.55),
          fontSize: 10, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center),
    ]);
  }
}

// ── Quick Stat Chip ──────────────────────────────────────────────────────────
class _QuickStatChip extends StatelessWidget {
  const _QuickStatChip({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(
          color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(
          color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Earnings Breakdown Card ──────────────────────────────────────────────────
class _EarningsBreakdownCard extends StatelessWidget {
  const _EarningsBreakdownCard({required this.summary});
  final dynamic summary;

  @override
  Widget build(BuildContext context) {
    final netPayable = summary.basePay + summary.overtimePay - summary.advanceTaken;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        _buildRow(label: 'Base Salary', amount: summary.basePay,
          color: AppColors.navy, icon: Icons.work_outline_rounded),
        Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
        _buildRow(label: 'Overtime Earnings', amount: summary.overtimePay,
          color: AppColors.goldDark, icon: Icons.bolt_rounded),
        Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
        _buildRow(label: 'Advance Deducted', amount: -summary.advanceTaken,
          color: AppColors.absent, icon: Icons.remove_circle_outline_rounded),
        Divider(height: 1, color: AppColors.border),
        // Net highlight
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, Color(0xFF1F2B40)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Net Payable',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
            Text('₹${netPayable.abs().toStringAsFixed(0)}',
              style: const TextStyle(color: AppColors.gold,
                fontWeight: FontWeight.w900, fontSize: 22)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildRow({required String label, required double amount,
    required Color color, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600,
            fontSize: 14, color: AppColors.textPrimary))),
        Text(
          '${amount >= 0 ? '+' : ''}₹${amount.abs().toStringAsFixed(0)}',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
      ]),
    );
  }
}

// ── Overtime Card ────────────────────────────────────────────────────────────
class _OvertimeCard extends StatelessWidget {
  const _OvertimeCard({required this.hours, required this.rate, required this.earned});
  final double hours;
  final double rate;
  final double earned;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.halfDayBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.halfDay.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: AppColors.halfDay.withValues(alpha: 0.1),
          blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: AppColors.halfDay.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.bolt_rounded, color: AppColors.halfDay, size: 28)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Overtime Module',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
              color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Row(children: [
            _OTChip(label: '${hours.toStringAsFixed(1)} hrs'),
            const SizedBox(width: 6),
            _OTChip(label: '₹${rate.toStringAsFixed(0)}/hr'),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('Earned',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary,
              fontWeight: FontWeight.w600)),
          Text('₹${earned.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w900,
              fontSize: 20, color: AppColors.halfDay)),
        ]),
      ]),
    );
  }
}

class _OTChip extends StatelessWidget {
  const _OTChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.halfDay.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.halfDay)),
    );
  }
}

// ── Advance Card ─────────────────────────────────────────────────────────────
class _AdvanceCard extends StatelessWidget {
  const _AdvanceCard({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.absentBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.absent.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: AppColors.absent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.account_balance_wallet_outlined,
            color: AppColors.absent, size: 24)),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Advance Taken',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
              color: AppColors.textPrimary)),
          SizedBox(height: 2),
          Text('Deducted from salary',
            style: TextStyle(fontSize: 11, color: AppColors.absent)),
        ])),
        Text('-₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w900,
            fontSize: 18, color: AppColors.absent)),
      ]),
    );
  }
}
