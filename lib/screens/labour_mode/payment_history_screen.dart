import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/attendance_model.dart';
import '../../models/labour_model.dart';
import '../../models/payment_model.dart';
import '../../services/labour_mode/labour_firestore_service.dart';

class LabourReportScreen extends StatefulWidget {
  const LabourReportScreen({
    super.key,
    required this.labour,
    required this.firestoreService,
  });

  final Labour labour;
  final LabourFirestoreService firestoreService;

  @override
  State<LabourReportScreen> createState() => _LabourReportScreenState();
}

class _LabourReportScreenState extends State<LabourReportScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: StreamBuilder<List<Attendance>>(
        stream: widget.firestoreService.streamAttendance(widget.labour.id),
        builder: (context, attSnapshot) {
          if (!attSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }

          return StreamBuilder<List<Payment>>(
            stream: widget.firestoreService.streamPayments(widget.labour.id),
            builder: (context, paySnapshot) {
              if (!paySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppColors.gold));
              }

              final records = attSnapshot.data!;
              final payments = paySnapshot.data!;
              
              final summary = widget.firestoreService.buildDashboardSummary(widget.labour, records, payments);
              
              // We compute simple stats based on the entire record length
              final double lifetimeEarnings = summary.totalEarned;
              final double lifetimeDays = summary.totalDaysWorked;

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _MonthSelector(
                      selectedMonth: _selectedMonth,
                      onMonthChanged: (m) => setState(() => _selectedMonth = m),
                    ),
                    const SizedBox(height: 24),
                    const _SectionLabel(label: 'WORK HISTORY'),
                    const SizedBox(height: 12),
                    _WorkHistoryCard(lifetimeEarnings: lifetimeEarnings, lifetimeDays: lifetimeDays),
                    const SizedBox(height: 24),
                    const _SectionLabel(label: 'DOWNLOAD CENTER'),
                    const SizedBox(height: 12),
                    const _DownloadCenterCard(),
                  ]),
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

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.selectedMonth, required this.onMonthChanged});
  final DateTime selectedMonth;
  final Function(DateTime) onMonthChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        _NavBtn(icon: Icons.chevron_left_rounded,
          onPressed: () => onMonthChanged(
            DateTime(selectedMonth.year, selectedMonth.month - 1))),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(selectedMonth),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800,
              fontSize: 16, color: Colors.white))),
        _NavBtn(icon: Icons.chevron_right_rounded,
          onPressed: () => onMonthChanged(
            DateTime(selectedMonth.year, selectedMonth.month + 1))),
      ]),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white70, size: 22)),
    );
  }
}

class _WorkHistoryCard extends StatelessWidget {
  const _WorkHistoryCard({required this.lifetimeEarnings, required this.lifetimeDays});
  final double lifetimeEarnings;
  final double lifetimeDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            icon: Icons.payments_rounded,
            label: 'Total Earnings',
            value: '₹${lifetimeEarnings.toStringAsFixed(0)}',
            color: AppColors.gold,
          ),
          Container(height: 50, width: 1, color: AppColors.border),
          _Stat(
            icon: Icons.calendar_month_rounded,
            label: 'Total Days',
            value: lifetimeDays.toStringAsFixed(1),
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
      ],
    );
  }
}

class _DownloadCenterCard extends StatelessWidget {
  const _DownloadCenterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _DownloadTile(
            title: 'Salary Slip',
            subtitle: 'Download monthly payslip',
            icon: Icons.receipt_long_rounded,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading Salary Slip...')),
              );
            },
          ),
          const Divider(color: AppColors.border, height: 32),
          _DownloadTile(
            title: 'Attendance Report',
            subtitle: 'Detailed attendance log',
            icon: Icons.calendar_view_month_rounded,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading Attendance Report...')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.title, required this.subtitle,
    required this.icon, required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navyLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.gold, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.download_rounded, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
