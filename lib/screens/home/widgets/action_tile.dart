import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../widgets/glass_card.dart';

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.bgColor,
    this.iconBgColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color? bgColor;
  final Color? iconBgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        useBlur: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        baseColorTint: Theme.of(context).brightness == Brightness.dark && bgColor != null ? bgColor! : color,
        glowColor: color,
        tintOpacityLight: 0.05,
        tintOpacityDark: 1.0,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF91A7BE) : AppColors.textSecondaryColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
