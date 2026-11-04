import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/site_model.dart';

class AttendanceSiteRow extends StatelessWidget {
  const AttendanceSiteRow({
    super.key,
    required this.site,
    required this.markedCount,
    required this.onTap,
  });

  final SiteModel site;
  final int markedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompleted = markedCount > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isDark ? null : const LinearGradient(
            colors: [Color(0xFFF5F9FD), Color(0xFFEAF2F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          color: isDark ? AppColors.navyLight : null,
          borderRadius: BorderRadius.circular(isDark ? 16 : 20),
          border: Border.all(color: isDark ? AppColors.border : const Color(0xFFD4E1EE), width: 1),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06), 
              blurRadius: isDark ? 8 : 14, 
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status Indicator Circle
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF00A878) : const Color(0xFFF2A900),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isCompleted ? const Color(0xFF00A878) : const Color(0xFFF2A900)).withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Site Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    site.name.toUpperCase(),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF132B4F),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surface : (isCompleted ? const Color(0xFFE7F8F2) : const Color(0xFFFFF4D9)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCompleted ? 'COMPLETED' : 'PENDING',
                          style: TextStyle(
                            color: isCompleted ? const Color(0xFF00A878) : (isDark ? AppColors.textTertiary : const Color(0xFFC88A00)),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        markedCount > 0 ? '$markedCount Marked' : 'No Labours Marked',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : const Color(0xFF64809E),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDark ? AppColors.textTertiary : const Color(0xFF64809E),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
