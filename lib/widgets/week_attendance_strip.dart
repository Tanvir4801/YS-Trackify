import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class WeekAttendanceStrip extends StatelessWidget {
  const WeekAttendanceStrip({
    super.key,
    required this.attendanceByDate,
  });

  final Map<String, Map<String, int>> attendanceByDate;

  @override
  Widget build(BuildContext context) {
    // Per your request: remove the “weekly 7 day strip” visualization.
    // Show a compact 2-line present vs absent ratio across the data we have.
    int present = 0;
    int absent = 0;

    for (final entry in attendanceByDate.entries) {
      final data = entry.value;
      present += data['present'] ?? 0;
      absent += data['absent'] ?? 0;
    }

    final total = present + absent;
    final presentPct = total == 0 ? 0.0 : present / total;
    final absentPct = total == 0 ? 0.0 : absent / total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Summary',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _TwoLineRatio(
            greenLabel: 'Present',
            redLabel: 'Absent',
            greenCount: present,
            redCount: absent,
            greenPct: presentPct,
            redPct: absentPct,
          ),
        ],
      ),
    );
  }
}

class _TwoLineRatio extends StatelessWidget {
  const _TwoLineRatio({
    required this.greenLabel,
    required this.redLabel,
    required this.greenCount,
    required this.redCount,
    required this.greenPct,
    required this.redPct,
  });

  final String greenLabel;
  final String redLabel;
  final int greenCount;
  final int redCount;
  final double greenPct;
  final double redPct;

  @override
  Widget build(BuildContext context) {
    // Two flexible rows: no fixed widths -> avoids overflow issues.
    return Column(
      children: [
        _ratioRow(
          label: greenLabel,
          count: greenCount,
          pct: greenPct,
          color: const Color(0xFF059669),
        ),
        const SizedBox(height: 6),
        _ratioRow(
          label: redLabel,
          count: redCount,
          pct: redPct,
          color: AppColors.danger,
        ),
      ],
    );
  }

  Widget _ratioRow({
    required String label,
    required int count,
    required double pct,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 8,
                color: color.withValues(alpha: 0.12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(pct * 100).round()}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

