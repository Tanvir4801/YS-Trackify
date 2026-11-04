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
              
              int presentCount = 0;
              int threeQuarterCount = 0;
              int halfDayCount = 0;
              int quarterCount = 0;
              int absentCount = 0;
              double currentMonthDaysWorked = 0.0;
              
              final now = DateTime.now();
              final thisMonthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
              
              for (final r in records) {
                if (r.date.startsWith(thisMonthPrefix)) {
                  currentMonthDaysWorked += r.status.wageFactor;
                  if (r.status == AttendanceStatus.present) {
                    presentCount++;
                  } else if (r.status == AttendanceStatus.threeQuarter) {
                    threeQuarterCount++;
                  } else if (r.status == AttendanceStatus.half) {
                    halfDayCount++;
                  } else if (r.status == AttendanceStatus.quarter) {
                    quarterCount++;
                  } else if (r.status == AttendanceStatus.absent) {
                    absentCount++;
                  }
                }
              }
              
              final totalMarked = presentCount + threeQuarterCount + halfDayCount + quarterCount + absentCount;
              final totalDaysInMonth = totalMarked == 0 ? 1 : totalMarked;
              final double attendanceRate = (currentMonthDaysWorked / totalDaysInMonth).clamp(0.0, 1.0);
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
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 8,
                      runSpacing: 16,
                      children: [
                        _StatusCard(
                          icon: Icons.check_circle_rounded,
                          color: AppColors.successColor(context),
                          count: presentCount.toString(),
                          label: 'Present',
                        ),
                        if (threeQuarterCount > 0)
                          _StatusCard(
                            icon: Icons.star_half_rounded,
                            color: Colors.teal,
                            count: threeQuarterCount.toString(),
                            label: '3/4 Day',
                          ),
                        _StatusCard(
                          icon: Icons.schedule_rounded,
                          color: AppColors.warningColor(context),
                          count: halfDayCount.toString(),
                          label: 'Half Day',
                        ),
                        if (quarterCount > 0)
                          _StatusCard(
                            icon: Icons.timelapse_rounded,
                            color: Colors.orangeAccent,
                            count: quarterCount.toString(),
                            label: '1/4 Day',
                          ),
                        _StatusCard(
                          icon: Icons.cancel_rounded,
                          color: AppColors.errorColor(context),
                          count: absentCount.toString(),
                          label: 'Absent',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _AttendanceRateCard(rate: attendanceRate, daysWorked: currentMonthDaysWorked),
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
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryColor(context),
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
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimaryColor(context).withValues(alpha: 0.04),
            blurRadius: 15,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NET PAYABLE', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryColor(context).withValues(alpha: 0.8), size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${netPay.toStringAsFixed(0)}',
            style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 36, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(context, 'Gross Earned', '₹${summary.totalEarned.toStringAsFixed(0)}', AppColors.textPrimaryColor(context)),
              _buildMiniStat(context, 'Advances', '₹${summary.advanceTaken.toStringAsFixed(0)}', AppColors.errorColor(context)),
              _buildMiniStat(context, 'OT Pay', '₹${summary.overtimePay.toStringAsFixed(0)}', AppColors.primaryColor(context)),
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
        Text(label, style: TextStyle(color: AppColors.textTertiaryColor(context), fontSize: 10, fontWeight: FontWeight.w600)),
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
    final todayStr = AppDateUtils.toDateKey(DateTime.now());
    final todayRecord = records.where((r) => r.date == todayStr).firstOrNull;

    final bool isMarked = todayRecord != null && todayRecord.status != AttendanceStatus.pending;
    final String statusText = isMarked ? todayRecord.status.firestoreValue.toUpperCase() : 'NOT MARKED';
    final Color statusColor = _getStatusColor(context, todayRecord?.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(isMarked ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Attendance", style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12)),
                const SizedBox(height: 4),
                Text(statusText, style: TextStyle(color: statusColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (!isMarked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Mark Now',
                style: TextStyle(color: AppColors.primaryColor(context), fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context, AttendanceStatus? status) {
    if (status == null || status == AttendanceStatus.pending) return AppColors.textTertiaryColor(context);
    if (status == AttendanceStatus.present) return AppColors.successColor(context);
    if (status == AttendanceStatus.threeQuarter) return Colors.teal;
    if (status == AttendanceStatus.half) return AppColors.warningColor(context);
    if (status == AttendanceStatus.quarter) return Colors.orangeAccent;
    return AppColors.errorColor(context);
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
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(count, style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: AppColors.textTertiaryColor(context), fontSize: 10)),
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
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attendance Rate', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12)),
              const SizedBox(height: 4),
              Text('${(rate * 100).toStringAsFixed(0)}%', style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60, height: 60,
                child: CircularProgressIndicator(
                  value: rate,
                  backgroundColor: AppColors.primaryColor(context).withValues(alpha: 0.1),
                  color: AppColors.primaryColor(context),
                  strokeWidth: 6,
                ),
              ),
              Icon(Icons.star_rounded, color: AppColors.primaryColor(context), size: 24),
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
                  color: AppColors.softGold(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryColor(context).withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.campaign_rounded, color: AppColors.primaryColor(context), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        n.message,
                        style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 14, fontWeight: FontWeight.bold),
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
