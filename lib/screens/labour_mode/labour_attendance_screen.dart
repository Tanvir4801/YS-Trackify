import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/attendance_record.dart';
import '../../models/labour.dart';
import '../../services/labour_mode/labour_service.dart';

class LabourAttendanceScreen extends StatefulWidget {
  const LabourAttendanceScreen({
    super.key,
    required this.labour,
    required this.labourService,
  });

  final Labour labour;
  final LabourService labourService;

  @override
  State<LabourAttendanceScreen> createState() => _LabourAttendanceScreenState();
}

class _LabourAttendanceScreenState extends State<LabourAttendanceScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final allRecords = widget.labourService.getAttendanceForLabour(widget.labour.id);
    final filteredRecords = allRecords.where((record) {
      try {
        final d = AppDateUtils.fromDateKey(record.dateKey);
        return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
      } catch (_) { return false; }
    }).toList();

    final monthSelector = _MonthSelector(
      selectedMonth: _selectedMonth,
      onMonthChanged: (m) => setState(() => _selectedMonth = m),
    );

    if (filteredRecords.isEmpty) {
      return SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: monthSelector),
          Expanded(child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.calendar_month_rounded,
                  size: 40, color: AppColors.navy)),
              const SizedBox(height: 16),
              const Text('No Attendance Records',
                style: TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 17, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Records for this month will appear here.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
          )),
        ]),
      );
    }

    final presentCount = filteredRecords.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount  = filteredRecords.where((r) => r.status == AttendanceStatus.absent).length;
    final halfDayCount = filteredRecords.where((r) => r.status == AttendanceStatus.halfDay).length;
    final totalOT      = filteredRecords.fold<double>(0, (s, r) => s + r.overtimeHours);
    final totalDays    = filteredRecords.length;
    final attendancePct = totalDays > 0
        ? ((presentCount + halfDayCount * 0.5) / totalDays * 100).round()
        : 0;

    final sorted = [...filteredRecords]..sort((a, b) => b.dateKey.compareTo(a.dateKey));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          monthSelector,
          const SizedBox(height: 16),
          _SummaryCard(
            presentCount: presentCount, absentCount: absentCount,
            halfDayCount: halfDayCount, totalOT: totalOT,
            attendancePct: attendancePct),
          const SizedBox(height: 20),
          const Text('TIMELINE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: AppColors.textTertiary, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          ...sorted.map((record) {
            final recordDate = AppDateUtils.fromDateKey(record.dateKey);
            final today      = DateTime.now();
            final isToday    = recordDate.year == today.year &&
                recordDate.month == today.month &&
                recordDate.day == today.day;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TimelineCard(
                record: record, recordDate: recordDate, isToday: isToday));
          }),
        ]),
      ),
    );
  }
}

// ── Month Selector ───────────────────────────────────────────────────────────
class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.selectedMonth, required this.onMonthChanged});

  final DateTime selectedMonth;
  final Function(DateTime) onMonthChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border)),
      child: Row(children: [
        _NavBtn(icon: Icons.chevron_left_rounded,
          onPressed: () => onMonthChanged(
            DateTime(selectedMonth.year, selectedMonth.month - 1))),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(selectedMonth),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800,
              fontSize: 15, color: AppColors.textPrimary))),
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
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.navy, size: 22)),
    );
  }
}

// ── Summary Card ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.presentCount, required this.absentCount,
    required this.halfDayCount, required this.totalOT,
    required this.attendancePct,
  });

  final int presentCount;
  final int absentCount;
  final int halfDayCount;
  final double totalOT;
  final int attendancePct;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, Color(0xFF1A2438)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.35),
          blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Attendance Summary',
              style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 16)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Text('$attendancePct% rate',
                style: const TextStyle(color: AppColors.gold,
                  fontWeight: FontWeight.w700, fontSize: 12))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _StatItem(label: 'Present', count: '$presentCount',
              icon: Icons.check_circle_rounded, color: AppColors.gold)),
            Expanded(child: _StatItem(label: 'Absent', count: '$absentCount',
              icon: Icons.cancel_rounded, color: AppColors.absent)),
            Expanded(child: _StatItem(label: 'Half Day', count: '$halfDayCount',
              icon: Icons.schedule_rounded, color: AppColors.halfDay)),
            Expanded(child: _StatItem(label: 'OT Hrs',
              count: totalOT.toStringAsFixed(1),
              icon: Icons.bolt_rounded, color: AppColors.goldLight)),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Attendance Rate',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            Text('$attendancePct%',
              style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: attendancePct / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            )),
        ]),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.count,
    required this.icon, required this.color});

  final String label;
  final String count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 5),
      Text(count, style: TextStyle(color: color,
        fontWeight: FontWeight.w900, fontSize: 20)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(
        color: Colors.white.withValues(alpha: 0.65),
        fontSize: 10, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── Timeline Card ────────────────────────────────────────────────────────────
class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.record, required this.recordDate, required this.isToday});

  final AttendanceRecord record;
  final DateTime recordDate;
  final bool isToday;

  Color get _statusColor {
    switch (record.status) {
      case AttendanceStatus.present:  return AppColors.present;
      case AttendanceStatus.absent:   return AppColors.absent;
      case AttendanceStatus.halfDay:  return AppColors.halfDay;
    }
  }

  String get _statusLabel {
    switch (record.status) {
      case AttendanceStatus.present:  return 'Present';
      case AttendanceStatus.absent:   return 'Absent';
      case AttendanceStatus.halfDay:  return 'Half Day';
    }
  }

  IconData get _statusIcon {
    switch (record.status) {
      case AttendanceStatus.present:  return Icons.check_circle_rounded;
      case AttendanceStatus.absent:   return Icons.cancel_rounded;
      case AttendanceStatus.halfDay:  return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEE').format(recordDate);
    final dayNum  = DateFormat('dd').format(recordDate);
    final month   = DateFormat('MMM').format(recordDate);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: _statusColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          // Date block
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(dayNum, style: TextStyle(color: _statusColor,
                fontWeight: FontWeight.w900, fontSize: 18, height: 1)),
              Text(month, style: TextStyle(color: _statusColor.withValues(alpha: 0.8),
                fontSize: 10, fontWeight: FontWeight.w700)),
            ])),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(dayName, style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.halfDayBg, borderRadius: BorderRadius.circular(6)),
                  child: const Text('TODAY', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: AppColors.halfDay, letterSpacing: 0.5))),
              ],
            ]),
            if (record.overtimeHours > 0) ...[
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.bolt_rounded, size: 12, color: AppColors.halfDay),
                const SizedBox(width: 3),
                Text('OT ${record.overtimeHours.toStringAsFixed(1)}h',
                  style: const TextStyle(fontSize: 11,
                    color: AppColors.halfDay, fontWeight: FontWeight.w700)),
              ]),
            ],
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_statusIcon, size: 14, color: _statusColor),
              const SizedBox(width: 5),
              Text(_statusLabel, style: TextStyle(
                color: _statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
            ])),
        ]),
      ),
    );
  }
}
