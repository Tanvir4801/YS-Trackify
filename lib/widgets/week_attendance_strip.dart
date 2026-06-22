import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeekAttendanceStrip extends StatelessWidget {
  const WeekAttendanceStrip({
    super.key,
    required this.attendanceByDate,
  });

  final Map<String, Map<String, int>> attendanceByDate;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Row(
      children: days.map((day) {
        final key = DateFormat('yyyy-MM-dd').format(day);
        final data = attendanceByDate[key];
        final present = data?['present'] ?? 0;
        final absent = data?['absent'] ?? 0;
        final half = data?['half'] ?? 0;
        final total = present + absent + half;

        final isToday = key == DateFormat('yyyy-MM-dd').format(today);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('E').format(day).substring(0, 2),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isToday
                        ? const Color(0xFF1B8B6E)
                        : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFF1B8B6E).withValues(alpha: 0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday
                        ? Border.all(
                            color: const Color(0xFF1B8B6E).withValues(alpha: 0.4))
                        : null,
                  ),
                  child: total == 0
                      ? Center(
                          child: Icon(
                            Icons.remove,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (present > 0)
                              _MiniBar(
                                value: present / total,
                                color: const Color(0xFF059669),
                              ),
                            if (half > 0)
                              _MiniBar(
                                value: half / total,
                                color: const Color(0xFFF59E0B),
                              ),
                            if (absent > 0)
                              _MiniBar(
                                value: absent / total,
                                color: const Color(0xFFEF4444),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday
                        ? const Color(0xFF1B8B6E)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            height: 6,
            width: constraints.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        },
      ),
    );
  }
}
