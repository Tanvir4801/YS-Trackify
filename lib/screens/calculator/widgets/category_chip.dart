import 'package:flutter/material.dart';
import '../utils/calc_constants.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? activeColor;

  const CategoryChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? CalcColors.amber;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? color : CalcColors.surface,
          borderRadius: BorderRadius.circular(
            CalcDimens.radiusSm),
          border: Border.all(
            color: isActive ? color : CalcColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive
                ? Colors.white
                : CalcColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
