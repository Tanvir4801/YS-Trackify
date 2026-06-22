import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  static const displayLarge = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: -0.5,
    height: 1.2,
  );
  static const displayMedium = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.3,
  );
  static const headingLarge = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const headingMedium = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const bodyLarge = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary, height: 1.5,
  );
  static const bodyMedium = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static const caption = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: AppColors.textTertiary, letterSpacing: 0.3,
  );
  static const labelLarge = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const moneyLarge = TextStyle(
    fontSize: 26, fontWeight: FontWeight.w800,
    color: AppColors.primary, letterSpacing: -0.5,
  );
  static const moneyMedium = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );
}
