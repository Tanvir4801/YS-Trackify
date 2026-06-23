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
        final recordDate = AppDateUtils.fromDateKey(record.dateKey);
        return recordDate.year == _selectedMonth.year &&
            recordDate.month == _selectedMonth.month;
      } catch (_) {
        return false;
      }
    }).toList();

    final monthSelector = _PremiumMonthSelector(
      selectedMonth: _selectedMonth,
      onMonthChanged: (m) => setState(() => _selectedMonth = m),
    );

    if (filteredRecords.isEmpty) {
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: monthSelector,
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          size: 40, color: Color(0xFF0F766E)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Attendance Records',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Records for this month will appear here.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final presentCount =
        filteredRecords.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount =
        filteredRecords.where((r) => r.status == AttendanceStatus.absent).length;
    final halfDayCount =
        filteredRecords.where((r) => r.status == AttendanceStatus.halfDay).length;
    final totalOT = filteredRecords.fold<double>(
        0, (sum, r) => sum + r.overtimeHours);
    final totalDays = filteredRecords.length;
    final attendancePct = totalDays > 0
        ? ((presentCount + halfDayCount * 0.5) / totalDays * 100).round()
        : 0;

    // Sort descending
    final sorted = [...filteredRecords]
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            monthSelector,
            const SizedBox(height: 16),
            // ── Summary Card ─────────────────────────────────────
            _PremiumSummaryCard(
              presentCount: presentCount,
              absentCount: absentCount,
              halfDayCount: halfDayCount,
              totalOT: totalOT,
              attendancePct: attendancePct,
            ),
            const SizedBox(height: 20),
            const Text(
              'TIMELINE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            // ── Timeline ─────────────────────────────────────────
            ...sorted.map((record) {
              final recordDate = AppDateUtils.fromDateKey(record.dateKey);
              final today = DateTime.now();
              final isToday = recordDate.year == today.year &&
                  recordDate.month == today.month &&
                  recordDate.day == today.day;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TimelineCard(
                  record: record,
                  recordDate: recordDate,
                  isToday: isToday,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Month Selector
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumMonthSelector extends StatelessWidget {
  const _PremiumMonthSelector({
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  final DateTime selectedMonth;
  final Function(DateTime) onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final monthYear = DateFormat('MMMM yyyy').format(selectedMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      child: Row(
        children: [
          _NavBtn(
            icon: Icons.chevron_left_rounded,
            onPressed: () => onMonthChanged(
              DateTime(selectedMonth.year, selectedMonth.month - 1),
            ),
          ),
          Expanded(
            child: Text(
              monthYear,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          _NavBtn(
            icon: Icons.chevron_right_rounded,
            onPressed: () => onMonthChanged(
              DateTime(selectedMonth.year, selectedMonth.month + 1),
            ),
          ),
        ],
      ),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF0F766E).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF0F766E), size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Summary Card
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumSummaryCard extends StatelessWidget {
  const _PremiumSummaryCard({
    required this.presentCount,
    required this.absentCount,
    required this.halfDayCount,
    required this.totalOT,
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
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Attendance Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$attendancePct% rate',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _SummaryStatItem(
                  label: 'Present',
                  count: '$presentCount',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF86EFAC),
                )),
                Expanded(child: _SummaryStatItem(
                  label: 'Absent',
                  count: '$absentCount',
                  icon: Icons.cancel_rounded,
                  color: const Color(0xFFFCA5A5),
                )),
                Expanded(child: _SummaryStatItem(
                  label: 'Half Day',
                  count: '$halfDayCount',
                  icon: Icons.schedule_rounded,
                  color: const Color(0xFFFDE68A),
                )),
                Expanded(child: _SummaryStatItem(
                  label: 'OT Hrs',
                  count: totalOT.toStringAsFixed(1),
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF7DD3FC),
                )),
              ],
            ),
            const SizedBox(height: 14),
            // Attendance progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Attendance Rate', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                    Text('$attendancePct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: attendancePct / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStatItem extends StatelessWidget {
  const _SummaryStatItem({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final String count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          count,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline Card
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.record,
    required this.recordDate,
    required this.isToday,
  });

  final AttendanceRecord record;
  final DateTime recordDate;
  final bool isToday;

  Color get _statusColor {
    switch (record.status) {
      case AttendanceStatus.present:  return const Color(0xFF16A34A);
      case AttendanceStatus.absent:   return const Color(0xFFEF4444);
      case AttendanceStatus.halfDay:  return const Color(0xFFF59E0B);
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(color: _statusColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            // Date block
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    dayNum,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      height: 1,
                    ),
                  ),
                  Text(
                    month,
                    style: TextStyle(
                      color: _statusColor.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'TODAY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (record.overtimeHours > 0) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          'OT ${record.overtimeHours.toStringAsFixed(1)}h',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon, size: 14, color: _statusColor),
                  const SizedBox(width: 5),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
