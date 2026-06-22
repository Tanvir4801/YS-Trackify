import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// A styled insight chip/pill for displaying smart insights.
class InsightChip extends StatelessWidget {
  const InsightChip({
    super.key,
    required this.text,
    this.index = 0,
  });

  final String text;
  final int index;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;

    if (text.contains('\u{26A0}') || text.contains('\u{1F4C9}') || text.contains('\u{1F4B8}')) {
      bgColor = AppColors.absentSurface;
      borderColor = AppColors.absent.withValues(alpha: 0.25);
    } else if (text.contains('\u{2705}') || text.contains('\u{1F4C8}') || text.contains('\u{1F4B0}')) {
      bgColor = AppColors.presentSurface;
      borderColor = AppColors.present.withValues(alpha: 0.25);
    } else if (text.contains('\u{1F327}') || text.contains('\u{1F550}')) {
      bgColor = AppColors.halfSurface;
      borderColor = AppColors.halfDay.withValues(alpha: 0.25);
    } else {
      bgColor = AppColors.blueBg;
      borderColor = AppColors.blue.withValues(alpha: 0.25);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
