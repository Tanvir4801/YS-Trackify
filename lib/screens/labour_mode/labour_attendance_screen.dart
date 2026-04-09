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

    // Filter records for selected month
    final filteredRecords = allRecords.where((record) {
      try {
        final recordDate = AppDateUtils.fromDateKey(record.dateKey);
        return recordDate.year == _selectedMonth.year &&
            recordDate.month == _selectedMonth.month;
      } catch (_) {
        return false;
      }
    }).toList();

    if (filteredRecords.isEmpty) {
      return SafeArea(
        child: Column(
          children: [
            _MonthSelector(
              selectedMonth: _selectedMonth,
              onMonthChanged: (newMonth) {
                setState(() {
                  _selectedMonth = newMonth;
                });
              },
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 48,
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No attendance data',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final today = DateTime.now();
    final presentCount = filteredRecords
        .where((r) => r.status == AttendanceStatus.present)
        .length;
    final absentCount = filteredRecords
        .where((r) => r.status == AttendanceStatus.absent)
        .length;
    final halfDayCount = filteredRecords
        .where((r) => r.status == AttendanceStatus.halfDay)
        .length;

    final groupedByMonth = _groupByMonth(filteredRecords);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MonthSelector(
              selectedMonth: _selectedMonth,
              onMonthChanged: (newMonth) {
                setState(() {
                  _selectedMonth = newMonth;
                });
              },
            ),
            const SizedBox(height: 14),
            _SummaryCard(
              presentCount: presentCount,
              absentCount: absentCount,
              halfDayCount: halfDayCount,
            ),
            const SizedBox(height: 20),
            ...groupedByMonth.entries.map((entry) {
              final monthKey = entry.key;
              final monthRecords = entry.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthKey,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...monthRecords.map((record) {
                    final recordDate = AppDateUtils.fromDateKey(record.dateKey);
                    final isToday = recordDate.year == today.year &&
                        recordDate.month == today.month &&
                        recordDate.day == today.day;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AttendanceCard(
                        record: record,
                        recordDate: recordDate,
                        isToday: isToday,
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Map<String, List<AttendanceRecord>> _groupByMonth(List<AttendanceRecord> records) {
    final grouped = <String, List<AttendanceRecord>>{};

    for (final record in records) {
      try {
        final date = AppDateUtils.fromDateKey(record.dateKey);
        final monthKey = DateFormat('MMMM yyyy').format(date);
        grouped.putIfAbsent(monthKey, () => []);
        grouped[monthKey]!.add(record);
      } catch (_) {
        // Skip records with invalid date format
      }
    }

    // Sort months in descending order (latest first)
    final sorted = <String, List<AttendanceRecord>>{};
    grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a))
      ..forEach((key) => sorted[key] = grouped[key]!);

    return sorted;
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  final DateTime selectedMonth;
  final Function(DateTime) onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final monthYear = DateFormat('MMMM yyyy').format(selectedMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final previousMonth = DateTime(
                selectedMonth.year,
                selectedMonth.month - 1,
              );
              onMonthChanged(previousMonth);
            },
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(
            child: Text(
              monthYear,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final nextMonth = DateTime(
                selectedMonth.year,
                selectedMonth.month + 1,
              );
              onMonthChanged(nextMonth);
            },
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.presentCount,
    required this.absentCount,
    required this.halfDayCount,
  });

  final int presentCount;
  final int absentCount;
  final int halfDayCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
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
          Text(
            'Attendance Summary',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.check_circle_outline,
                  label: 'Present',
                  count: presentCount,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.close_outlined,
                  label: 'Absent',
                  count: absentCount,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.schedule_outlined,
                  label: 'Half-Day',
                  count: halfDayCount,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.record,
    required this.recordDate,
    required this.isToday,
  });

  final AttendanceRecord record;
  final DateTime recordDate;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEE').format(recordDate);
    final dateStr = DateFormat('dd MMM yyyy').format(recordDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFFFF9E6) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? const Color(0xFFFFD700).withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.1),
          width: isToday ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dayName, $dateStr',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              if (isToday)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Today',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          _StatusIcon(status: record.status),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case AttendanceStatus.present:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_circle_outlined,
            color: Colors.green,
            size: 22,
          ),
        );
      case AttendanceStatus.absent:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.close_outlined,
            color: Colors.red,
            size: 22,
          ),
        );
      case AttendanceStatus.halfDay:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.schedule_outlined,
            color: Colors.orange,
            size: 22,
          ),
        );
    }
  }
}
