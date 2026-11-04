import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AttentionItem extends StatelessWidget {
  const AttentionItem({
    super.key,
    required this.icon,
    required this.message,
    this.isWarning = true,
  });

  final IconData icon;
  final String message;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppColors.warningColor(context) : AppColors.successColor(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
