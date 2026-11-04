import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SiteRow extends StatelessWidget {
  const SiteRow({
    super.key,
    required this.name,
    required this.labourCount,
    required this.status,
    required this.onTap,
  });

  final String name;
  final int labourCount;
  final String status; // 'Pending', 'In Progress', 'Completed'
  final VoidCallback onTap;

  Color _statusColor(BuildContext context) {
    switch (status) {
      case 'Completed':
        return AppColors.successColor(context);
      case 'In Progress':
        return AppColors.infoColor(context);
      default:
        return AppColors.primaryColor(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Tint based on status
    Color bgColor = isDark ? Colors.transparent : AppColors.cardColor(context);
    Color borderColor = isDark ? const Color(0xFF91AAC8).withValues(alpha: 0.12) : AppColors.borderColor(context);
    
    if (status == 'Completed' || status == 'Pending') {
      bgColor = statusColor.withValues(alpha: 0.05);
      borderColor = statusColor.withValues(alpha: isDark ? 0.2 : 0.2);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            gradient: isDark && bgColor == Colors.transparent
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0F1A2A), Color(0xFF0A1322)],
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              if (isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3182F6).withValues(alpha: 0.1) : AppColors.primaryColor(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.location_on_rounded, color: isDark ? const Color(0xFF3182F6) : AppColors.primaryColor(context), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimaryColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$labourCount Labour',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF7189A4) : AppColors.textTertiaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? statusColor.withValues(alpha: 0.1) : statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? statusColor.withValues(alpha: 0.2) : statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
