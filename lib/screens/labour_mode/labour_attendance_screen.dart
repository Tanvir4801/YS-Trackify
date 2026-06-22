import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/attendance_model.dart';
import '../../models/labour_model.dart';
import '../../services/labour_mode/labour_firestore_service.dart';

class LabourAttendanceScreen extends StatefulWidget {
  const LabourAttendanceScreen({
    super.key,
    required this.labour,
    required this.firestoreService,
  });

  final Labour labour;
  final LabourFirestoreService firestoreService;

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
    return Container(
      color: AppColors.background,
      child: StreamBuilder<List<Attendance>>(
        stream: widget.firestoreService.streamAttendance(widget.labour.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }

          final allRecords = snapshot.data!;
          final filteredRecords = allRecords.where((record) {
            try {
              final d = AppDateUtils.fromDateKey(record.date);
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
                        color: AppColors.navyLight,
                        borderRadius: BorderRadius.circular(24)),
                      child: const Icon(Icons.calendar_month_rounded,
                        size: 40, color: AppColors.navy)),
                    const SizedBox(height: 16),
                    const Text('No Attendance Records',
                      style: TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 17, color: Colors.white)),
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
          final halfDayCount = filteredRecords.where((r) => r.status == AttendanceStatus.half).length;
          final totalOT      = filteredRecords.fold<double>(0, (s, r) => s + r.overtimeHours);
          final totalMarkedDays = presentCount + absentCount + halfDayCount;
          final attendancePct = totalMarkedDays > 0
              ? ((presentCount + halfDayCount * 0.5) / totalMarkedDays * 100).round()
              : 0;

          final sorted = [...filteredRecords]..sort((a, b) => b.date.compareTo(a.date));

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                monthSelector,
                const SizedBox(height: 16),
                _CalendarGrid(selectedMonth: _selectedMonth, records: filteredRecords),
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
                  final recordDate = AppDateUtils.fromDateKey(record.date);
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
        },
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
              fontSize: 15, color: Colors.white))),
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

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.selectedMonth, required this.records});
  final DateTime selectedMonth;
  final List<Attendance> records;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(selectedMonth.year, selectedMonth.month);
    final firstDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday - 1; 
    
    final recordMap = {
      for (var r in records) AppDateUtils.fromDateKey(r.date).day: r.status
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) => 
              SizedBox(
                width: 32,
                child: Text(day, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 13)),
              )
            ).toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, childAspectRatio: 1,
              mainAxisSpacing: 8, crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final dayIndex = index - firstWeekday;
              if (dayIndex < 0 || dayIndex >= daysInMonth) {
                return const SizedBox.shrink();
              }
              final dayNumber = dayIndex + 1;
              final status = recordMap[dayNumber];
              
              Color bgColor = AppColors.navyLight;
              Color textColor = Colors.white54;
              Color? borderColor;

              if (status == AttendanceStatus.present) {
                bgColor = AppColors.present.withValues(alpha: 0.2);
                textColor = AppColors.present;
                borderColor = AppColors.present.withValues(alpha: 0.5);
              } else if (status == AttendanceStatus.absent) {
                bgColor = AppColors.absent.withValues(alpha: 0.2);
                textColor = AppColors.absent;
                borderColor = AppColors.absent.withValues(alpha: 0.5);
              } else if (status == AttendanceStatus.half) {
                bgColor = AppColors.halfDay.withValues(alpha: 0.2);
                textColor = AppColors.halfDay;
                borderColor = AppColors.halfDay.withValues(alpha: 0.5);
              }

              return Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
                ),
                alignment: Alignment.center,
                child: Text('$dayNumber', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.presentCount, required this.absentCount,
    required this.halfDayCount, required this.totalOT,
    required this.attendancePct,
  });

  final int presentCount, absentCount, halfDayCount, attendancePct;
  final double totalOT;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monthly Rate', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text('$attendancePct%', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.gold, size: 16),
                  const SizedBox(width: 4),
                  Text('${totalOT.toStringAsFixed(1)} OT Hrs', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _SummaryStat(label: 'Present', count: presentCount, color: AppColors.present),
            _SummaryStat(label: 'Half Day', count: halfDayCount, color: AppColors.halfDay),
            _SummaryStat(label: 'Absent', count: absentCount, color: AppColors.absent),
          ],
        ),
      ]),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.record, required this.recordDate, required this.isToday});
  final Attendance record;
  final DateTime recordDate;
  final bool isToday;

  Color _getStatusColor(AttendanceStatus? status) {
    if (status == AttendanceStatus.present) return AppColors.present;
    if (status == AttendanceStatus.absent) return AppColors.absent;
    if (status == AttendanceStatus.half) return AppColors.halfDay;
    return Colors.transparent;
  }

  IconData _getStatusIcon(AttendanceStatus? status) {
    if (status == AttendanceStatus.present) return Icons.check_circle_rounded;
    if (status == AttendanceStatus.absent) return Icons.cancel_rounded;
    if (status == AttendanceStatus.half) return Icons.schedule_rounded;
    return Icons.help_outline;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(record.status);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isToday ? AppColors.gold.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getStatusIcon(record.status), color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMM').format(recordDate),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(record.status.firestoreValue.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (record.overtimeHours > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.navyLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.gold, size: 14),
                  const SizedBox(width: 4),
                  Text('${record.overtimeHours}h', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
