import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final Color color;
    final Color bg;
    final String label;
    final IconData icon;

    if (s == 'present') {
      color = AppColors.present;
      bg = AppColors.presentSurface;
      label = 'Present';
      icon = Icons.check_circle_outline;
    } else if (s == 'absent') {
      color = AppColors.absent;
      bg = AppColors.absentSurface;
      label = 'Absent';
      icon = Icons.cancel_outlined;
    } else if (s == 'half' || s == 'half_day') {
      color = AppColors.halfDay;
      bg = AppColors.halfSurface;
      label = 'Half Day';
      icon = Icons.timelapse_outlined;
    } else {
      color = AppColors.textTertiary;
      bg = AppColors.surfaceElevated;
      label = status;
      icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
