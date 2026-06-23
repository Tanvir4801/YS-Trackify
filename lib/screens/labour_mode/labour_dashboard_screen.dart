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
          // ── Premium Hero Card ───────────────────────────────────────
          _HeroEarningsCard(
            labour: labour,
            summary: summary,
            netPay: netPay,
            isPositive: isPositive,
          ),
          const SizedBox(height: 20),

          // ── Quick Stats Row ─────────────────────────────────────────
          _SectionLabel(label: 'Quick Stats'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _QuickStatChip(
                icon: Icons.calendar_today_rounded,
                label: 'Days Worked',
                value: summary.totalDaysWorked.toStringAsFixed(1),
                color: const Color(0xFF0F766E),
              )),
              const SizedBox(width: 10),
              Expanded(child: _QuickStatChip(
                icon: Icons.bolt_rounded,
                label: 'OT Hours',
                value: '${summary.extraHours.toStringAsFixed(1)}h',
                color: const Color(0xFFF59E0B),
              )),
              const SizedBox(width: 10),
              Expanded(child: _QuickStatChip(
                icon: Icons.currency_rupee_rounded,
                label: 'Daily Rate',
                value: '₹${summary.dailyWage.toStringAsFixed(0)}',
                color: const Color(0xFF2563EB),
              )),
            ],
          ),
          const SizedBox(height: 20),

          // ── Earnings Breakdown ──────────────────────────────────────
          _SectionLabel(label: 'Earnings Breakdown'),
          const SizedBox(height: 10),
          _EarningsBreakdownCard(summary: summary),
          const SizedBox(height: 20),

          // ── Overtime Card ───────────────────────────────────────────
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

          // ── Advance Card ────────────────────────────────────────────
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
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.6,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Card
// ─────────────────────────────────────────────────────────────────────────────
class _HeroEarningsCard extends StatelessWidget {
  const _HeroEarningsCard({
    required this.labour,
    required this.summary,
    required this.netPay,
    required this.isPositive,
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decoration circles
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: 40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      child: Text(
                        labour.name.isNotEmpty ? labour.name[0].toUpperCase() : 'L',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labour.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            labour.role.isNotEmpty
                                ? labour.role
                                : 'Construction Worker',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Today's status pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Color(0xFF86EFAC), size: 8),
                          SizedBox(width: 5),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10, thickness: 1),
                const SizedBox(height: 18),
                // Earnings row
                Row(
                  children: [
                    Expanded(
                      child: _HeroStatItem(
                        label: 'Net Payable',
                        value: '₹${netPay.abs().toStringAsFixed(0)}',
                        valueColor: isPositive
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCA5A5),
                        isLarge: true,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    Expanded(
                      child: _HeroStatItem(
                        label: 'Base Earned',
                        value: '₹${summary.basePay.toStringAsFixed(0)}',
                        valueColor: Colors.white,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    Expanded(
                      child: _HeroStatItem(
                        label: 'Overtime',
                        value: '₹${summary.overtimePay.toStringAsFixed(0)}',
                        valueColor: const Color(0xFFFDE68A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatItem extends StatelessWidget {
  const _HeroStatItem({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isLarge = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w900,
            fontSize: isLarge ? 22 : 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Stat Chip
// ─────────────────────────────────────────────────────────────────────────────
class _QuickStatChip extends StatelessWidget {
  const _QuickStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Earnings Breakdown Card
// ─────────────────────────────────────────────────────────────────────────────
class _EarningsBreakdownCard extends StatelessWidget {
  const _EarningsBreakdownCard({required this.summary});
  final dynamic summary;

  @override
  Widget build(BuildContext context) {
    final netPayable = summary.basePay + summary.overtimePay - summary.advanceTaken;

    final rows = [
      _EarningRow(label: 'Base Salary',       amount: summary.basePay,      color: const Color(0xFF0F766E), icon: Icons.work_outline_rounded),
      _EarningRow(label: 'Overtime Earnings', amount: summary.overtimePay,  color: const Color(0xFFF59E0B), icon: Icons.bolt_rounded),
      _EarningRow(label: 'Advance Deducted',  amount: -summary.advanceTaken, color: const Color(0xFFEF4444), icon: Icons.remove_circle_outline_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: row.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(row.icon, color: row.color, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    row.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                Text(
                  '${row.amount >= 0 ? '+' : ''}₹${row.amount.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: row.color,
                  ),
                ),
              ],
            ),
          )),
          const Divider(height: 1, indent: 18, endIndent: 18),
          // Net Payable highlight
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Net Payable',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '₹${netPayable.abs().toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningRow {
  const _EarningRow({required this.label, required this.amount, required this.color, required this.icon});
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
}

// ─────────────────────────────────────────────────────────────────────────────
// Overtime Card
// ─────────────────────────────────────────────────────────────────────────────
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
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overtime Module',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _OTChip(label: '${hours.toStringAsFixed(1)} hrs'),
                    const SizedBox(width: 6),
                    _OTChip(label: '₹${rate.toStringAsFixed(0)}/hr'),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Earned', style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
              Text(
                '₹${earned.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ],
      ),
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
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFB45309),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Advance Card
// ─────────────────────────────────────────────────────────────────────────────
class _AdvanceCard extends StatelessWidget {
  const _AdvanceCard({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: Color(0xFFEF4444), size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Advance Taken', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF7F1D1D))),
                SizedBox(height: 2),
                Text('Deducted from salary', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
              ],
            ),
          ),
          Text(
            '-₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}
