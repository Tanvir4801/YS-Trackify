import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/attendance_model.dart';
import '../../models/labour_model.dart';
import '../../models/payment_model.dart';
import '../../models/notice_model.dart';
import '../../services/labour_mode/labour_firestore_service.dart';

class LabourDashboardScreen extends StatelessWidget {
  const LabourDashboardScreen({
    super.key,
    required this.labour,
    required this.firestoreService,
  });

  final Labour labour;
  final LabourFirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: StreamBuilder<List<Attendance>>(
        stream: firestoreService.streamAttendance(labour.id),
        builder: (context, attSnapshot) {
          if (!attSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }

          return StreamBuilder<List<Payment>>(
            stream: firestoreService.streamPayments(labour.id),
            builder: (context, paySnapshot) {
              if (!paySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppColors.gold));
              }

              final records = attSnapshot.data!;
              final payments = paySnapshot.data!;
              
              final summary = firestoreService.buildDashboardSummary(labour, records, payments);
              
              int presentCount = 0;
              int halfDayCount = 0;
              int absentCount = 0;
              
              for (final r in records) {
                if (r.status == AttendanceStatus.present) {
                  presentCount++;
                } else if (r.status == AttendanceStatus.half) halfDayCount++;
                else if (r.status == AttendanceStatus.absent) absentCount++;
              }
              
              final totalDaysInMonth = (presentCount + halfDayCount + absentCount) == 0 
                  ? 1 : (presentCount + halfDayCount + absentCount);
              final double attendanceRate = (summary.totalDaysWorked / totalDaysInMonth).clamp(0.0, 1.0);
              final netPay = summary.finalPay;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NoticeBoardSection(labour: labour, firestoreService: firestoreService),
                    _HeroEarningsCard(summary: summary, netPay: netPay),
                    const SizedBox(height: 24),
                    const _SectionLabel(label: "TODAY'S STATUS"),
                    const SizedBox(height: 12),
                    _TodayStatusCard(records: records),
                    const SizedBox(height: 24),
                    const _SectionLabel(label: 'THIS MONTH'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatusCard(
                            icon: Icons.check_circle_rounded,
                            color: AppColors.present,
                            count: presentCount.toString(),
                            label: 'Present',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatusCard(
                            icon: Icons.schedule_rounded,
                            color: AppColors.halfDay,
                            count: halfDayCount.toString(),
                            label: 'Half Day',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatusCard(
                            icon: Icons.cancel_rounded,
                            color: AppColors.absent,
                            count: absentCount.toString(),
                            label: 'Absent',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    _AttendanceRateCard(rate: attendanceRate, daysWorked: summary.totalDaysWorked),
                  ],
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
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.gold,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _HeroEarningsCard extends StatelessWidget {
  const _HeroEarningsCard({required this.summary, required this.netPay});
  final LabourDashboardSummary summary;
  final double netPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyLight, AppColors.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('NET PAYABLE', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold.withValues(alpha: 0.8), size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${netPay.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Gross Earned', '₹${summary.totalEarned.toStringAsFixed(0)}', Colors.white),
              _buildMiniStat('Advances', '₹${summary.advanceTaken.toStringAsFixed(0)}', AppColors.absent),
              _buildMiniStat('OT Pay', '₹${summary.overtimePay.toStringAsFixed(0)}', AppColors.gold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TodayStatusCard extends StatelessWidget {
  const _TodayStatusCard({required this.records});
  final List<Attendance> records;

  @override
  Widget build(BuildContext context) {
    // Find today's record
    final todayStr = AppDateUtils.toDateKey(DateTime.now());
    final todayRecord = records.where((r) => r.date == todayStr).firstOrNull;

    final String statusText = todayRecord?.status.firestoreValue.toUpperCase() ?? 'NOT MARKED';
    final Color statusColor = _getStatusColor(todayRecord?.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_today_rounded, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Attendance", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(statusText, style: TextStyle(color: statusColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus? status) {
    if (status == null || status == AttendanceStatus.pending) return AppColors.textTertiary;
    if (status == AttendanceStatus.present) return AppColors.present;
    if (status == AttendanceStatus.half) return AppColors.halfDay;
    return AppColors.absent;
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon, required this.color,
    required this.count, required this.label,
  });

  final IconData icon;
  final Color color;
  final String count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(count, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _AttendanceRateCard extends StatelessWidget {
  const _AttendanceRateCard({required this.rate, required this.daysWorked});
  final double rate;
  final double daysWorked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Attendance Rate', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${(rate * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60, height: 60,
                child: CircularProgressIndicator(
                  value: rate,
                  backgroundColor: AppColors.navyLight,
                  color: AppColors.gold,
                  strokeWidth: 6,
                ),
              ),
              const Icon(Icons.star_rounded, color: AppColors.gold, size: 24),
            ]
          )
        ],
      ),
    );
  }
}

class _NoticeBoardSection extends StatelessWidget {
  const _NoticeBoardSection({required this.labour, required this.firestoreService});
  final Labour labour;
  final LabourFirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Notice>>(
      stream: firestoreService.streamNotices(labour.supervisorId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
        final notices = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(label: 'NOTICE BOARD'),
              const SizedBox(height: 12),
              ...notices.map((n) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.campaign_rounded, color: AppColors.gold, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        n.message,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}
