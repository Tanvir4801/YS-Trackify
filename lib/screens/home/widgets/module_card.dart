import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../widgets/glass_card.dart';

class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.bgColor,
    this.iconBgColor,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color? bgColor;
  final Color? iconBgColor;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      useBlur: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      baseColorTint: Theme.of(context).brightness == Brightness.dark && bgColor != null ? bgColor! : color,
      glowColor: color,
      tintOpacityLight: 0.05,
      tintOpacityDark: 1.0,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor ?? color.withValues(alpha: Theme.of(context).brightness == Brightness.light ? 0.1 : 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? color.withValues(alpha: 0.15)
                      : color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textPrimaryColor(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeText != null && badgeText!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? const Color(0xFFF59E0B)).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (badgeColor ?? const Color(0xFFF59E0B)).withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          badgeText!,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: badgeColor ?? const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF91A7BE) : AppColors.textSecondaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textTertiaryColor(context), size: 18),
        ],
      ),
    );
  }
}
