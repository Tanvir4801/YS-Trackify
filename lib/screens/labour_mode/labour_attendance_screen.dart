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
      color: AppColors.backgroundColor(context),
      child: StreamBuilder<List<Attendance>>(
        stream: widget.firestoreService.streamAttendance(widget.labour.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryColor(context)));
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
                        color: AppColors.cardColor(context),
                        borderRadius: BorderRadius.circular(24)),
                      child: Icon(Icons.calendar_month_rounded,
                        size: 40, color: AppColors.primaryColor(context))),
                    const SizedBox(height: 16),
                    Text('No Attendance Records',
                      style: TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 17, color: AppColors.textPrimaryColor(context))),
                    const SizedBox(height: 6),
                    Text('Records for this month will appear here.',
                      style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13)),
                  ]),
                )),
              ]),
            );
          }

          final presentCount = filteredRecords.where((r) => r.status == AttendanceStatus.present).length;
          final absentCount  = filteredRecords.where((r) => r.status == AttendanceStatus.absent).length;
          final halfDayCount = filteredRecords.where((r) => r.status == AttendanceStatus.half).length;
          final threeQuarterCount = filteredRecords.where((r) => r.status == AttendanceStatus.threeQuarter).length;
          final quarterCount = filteredRecords.where((r) => r.status == AttendanceStatus.quarter).length;
          
          final totalOT      = filteredRecords.fold<double>(0, (s, r) => s + r.overtimeHours);
          final totalMarkedDays = presentCount + absentCount + halfDayCount + threeQuarterCount + quarterCount;
          
          final attendancePct = totalMarkedDays > 0
              ? ((presentCount + threeQuarterCount * 0.75 + halfDayCount * 0.5 + quarterCount * 0.25) / totalMarkedDays * 100).round()
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
                  halfDayCount: halfDayCount, threeQuarterCount: threeQuarterCount,
                  quarterCount: quarterCount, totalOT: totalOT,
                  attendancePct: attendancePct),
                const SizedBox(height: 20),
                Text('TIMELINE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.textTertiaryColor(context), letterSpacing: 1.2)),
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
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Row(children: [
        _NavBtn(icon: Icons.chevron_left_rounded,
          onPressed: () => onMonthChanged(
            DateTime(selectedMonth.year, selectedMonth.month - 1))),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(selectedMonth),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800,
              fontSize: 15, color: AppColors.textPrimaryColor(context)))),
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
          color: AppColors.softGold(context),
          borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.primaryColor(context), size: 22)),
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
    
    final recordMap = <int, List<AttendanceStatus>>{};
    for (var r in records) {
      final day = AppDateUtils.fromDateKey(r.date).day;
      recordMap.putIfAbsent(day, () => []).add(r.status);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) => 
              SizedBox(
                width: 32,
                child: Text(day, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondaryColor(context), fontWeight: FontWeight.w700, fontSize: 13)),
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
              final dayStatuses = recordMap[dayNumber] ?? [];
              
              Color textColor = AppColors.textPrimaryColor(context);

              Color getIndicatorColor(AttendanceStatus status) {
                if (status == AttendanceStatus.present) return AppColors.successColor(context);
                if (status == AttendanceStatus.absent) return AppColors.errorColor(context);
                if (status == AttendanceStatus.half) return AppColors.warningColor(context);
                if (status == AttendanceStatus.threeQuarter) return Colors.teal;
                if (status == AttendanceStatus.quarter) return Colors.orangeAccent;
                return Colors.transparent;
              }

              final now = DateTime.now();
              final isToday = selectedMonth.year == now.year && selectedMonth.month == now.month && dayNumber == now.day;

              if (isToday) textColor = AppColors.primaryColor(context);

              return Container(
                decoration: BoxDecoration(
                  color: isToday ? AppColors.softGold(context) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday ? Border.all(color: AppColors.primaryColor(context).withValues(alpha: 0.3)) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$dayNumber', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    if (dayStatuses.isEmpty)
                      const SizedBox(height: 6)
                    else if (dayStatuses.length == 1)
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: getIndicatorColor(dayStatuses.first),
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 2,
                        runSpacing: 2,
                        alignment: WrapAlignment.center,
                        children: dayStatuses.map((s) => Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(
                            color: getIndicatorColor(s),
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        )).toList(),
                      ),
                  ],
                ),
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
    required this.halfDayCount, required this.threeQuarterCount,
    required this.quarterCount, required this.totalOT,
    required this.attendancePct,
  });

  final int presentCount, absentCount, halfDayCount, threeQuarterCount, quarterCount, attendancePct;
  final double totalOT;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ATTENDANCE SUMMARY', style: TextStyle(color: AppColors.primaryColor(context), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('$attendancePct%', style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Attendance Rate', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 11)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt, color: AppColors.primaryColor(context), size: 16),
                  const SizedBox(width: 4),
                  Text('${totalOT.toStringAsFixed(1)} OT Hrs', style: TextStyle(color: AppColors.primaryColor(context), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 8,
          runSpacing: 16,
          children: [
            _SummaryStat(label: 'Present', count: presentCount, color: AppColors.successColor(context)),
            if (threeQuarterCount > 0) _SummaryStat(label: '3/4 Day', count: threeQuarterCount, color: Colors.teal),
            _SummaryStat(label: 'Half Day', count: halfDayCount, color: AppColors.warningColor(context)),
            if (quarterCount > 0) _SummaryStat(label: '1/4 Day', count: quarterCount, color: Colors.orangeAccent),
            _SummaryStat(label: 'Absent', count: absentCount, color: AppColors.errorColor(context)),
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
    return Column(
      children: [
        Text('$count', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: AppColors.textTertiaryColor(context), fontSize: 11)),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.record, required this.recordDate, required this.isToday});
  final Attendance record;
  final DateTime recordDate;
  final bool isToday;

  Color _getStatusColor(BuildContext context, AttendanceStatus? status) {
    if (status == AttendanceStatus.present) return AppColors.successColor(context);
    if (status == AttendanceStatus.threeQuarter) return Colors.teal;
    if (status == AttendanceStatus.half) return AppColors.warningColor(context);
    if (status == AttendanceStatus.quarter) return Colors.orangeAccent;
    if (status == AttendanceStatus.absent) return AppColors.errorColor(context);
    return Colors.transparent;
  }

  IconData _getStatusIcon(AttendanceStatus? status) {
    if (status == AttendanceStatus.present) return Icons.check_circle_rounded;
    if (status == AttendanceStatus.threeQuarter) return Icons.star_half_rounded;
    if (status == AttendanceStatus.half) return Icons.schedule_rounded;
    if (status == AttendanceStatus.quarter) return Icons.timelapse_rounded;
    if (status == AttendanceStatus.absent) return Icons.cancel_rounded;
    return Icons.help_outline;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context, record.status);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(Icons.circle, color: statusColor, size: 12),
              Container(width: 2, height: 40, color: AppColors.borderColor(context)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMM').format(recordDate),
                  style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(record.status.firestoreValue.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700)),
                    if (record.siteName != null && record.siteName!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.location_on, size: 12, color: AppColors.textTertiaryColor(context)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          record.siteName!, 
                          style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (record.overtimeHours > 0)
            Text('+${record.overtimeHours} OT Hrs', style: TextStyle(color: AppColors.primaryColor(context), fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
