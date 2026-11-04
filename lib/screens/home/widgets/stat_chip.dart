import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../widgets/glass_card.dart';

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.bgColor,
    this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final Color? bgColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        useBlur: true,
        borderRadius: 12.0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        baseColorTint: Theme.of(context).brightness == Brightness.dark && bgColor != null ? bgColor! : color,
        glowColor: color,
        tintOpacityLight: 0.08,
        tintOpacityDark: 1.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (_, val, __) => Text(
                      val == val.toInt() ? val.toInt().toString() : val.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textPrimaryColor(context),
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 0.5,
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
