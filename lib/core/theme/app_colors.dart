import 'package:flutter/material.dart';

class AppColors {
  // ── NEW THEME-AWARE SEMANTIC TOKENS ──
  
  static Color backgroundColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF080F1C) : const Color(0xFFF3F6F9); // Premium soft tint

  static LinearGradient backgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [const Color(0xFF040810), const Color(0xFF03070E), const Color(0xFF020409)]
          : [const Color(0xFFF5F7FA), const Color(0xFFF3F6F9), const Color(0xFFEBF0F5)],
    );
  }

  // ── GLASS SURFACES ──
  static Color glassSurfaceColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF16243A).withValues(alpha: 0.72) 
      : const Color(0xFFFFFFFF).withValues(alpha: 0.85);

  static Color glassSurfaceSecondaryColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF142238).withValues(alpha: 0.72) 
      : const Color(0xFFFFFFFF).withValues(alpha: 0.90);

  static Color glassBorderColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF78A0C8).withValues(alpha: 0.18) 
      : const Color(0xFF0F172A).withValues(alpha: 0.08); // Subtle slate border

  static Color glassHighlightBorderColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFFFFFFFF).withValues(alpha: 0.08) 
      : const Color(0xFFFFFFFF).withValues(alpha: 0.60);

  // ── FLAT SURFACES (Non-glass fallbacks) ──
  static Color surfaceColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF13243A) : const Color(0xFFFFFFFF);

  static Color surfaceSecondaryColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF162840) : const Color(0xFFFFFFFF);

  static Color cardColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF13243A) : const Color(0xFFFFFFFF);

  static Color surfaceElevatedColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF14263C) : const Color(0xFFFFFFFF);

  static Color borderColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF91AAC8).withValues(alpha: 0.14) : const Color(0xFF0F172A).withValues(alpha: 0.08);

  static Color subtleBorderColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF91AAC8).withValues(alpha: 0.14) : const Color(0xFF0F172A).withValues(alpha: 0.05);
  
  // ── TYPOGRAPHY ──
  static Color textPrimaryColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFFF4F7FB) : const Color(0xFF0F172A); // High contrast slate/black

  static Color textSecondaryColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF91A7BE) : const Color(0xFF475569);

  static Color textTertiaryColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF7189A4) : const Color(0xFF64748B);

  static Color mutedTextColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF7189A4) : const Color(0xFF94A3B8);

  static Color textOnPrimaryColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);

  // ── SEMANTIC COLORS ──
  static Color primaryColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFFF2A900) : const Color(0xFFF2A900); // Trackify Gold

  static Color softGold(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF2A2114) : const Color(0xFFFFF4D6);

  static Color successColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF00C896) : const Color(0xFF00B686);

  static Color warningColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFFF2A900) : const Color(0xFFE09A00);

  static Color errorColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFFFF4D73) : const Color(0xFFE83D63);

  static Color infoColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF3182F6) : const Color(0xFF3B82F6);

  static Color violetColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF9B6CFF) : const Color(0xFF7C3AED);

  // ── MODULE TINTS (For Action Cards) ──
  static Color get qrTint => const Color(0xFF00C896);
  static Color get manualTint => const Color(0xFF3B82F6);
  static Color get reportsTint => const Color(0xFF9B6CFF);
  static Color get closingTint => const Color(0xFFF2A900);
  static Color get materialsTint => const Color(0xFFFF6446);
  static Color get calculatorTint => const Color(0xFF3B82F6);

  // ── ORIGINAL LEGACY CONSTANTS (DO NOT REMOVE OR RENAME) ──
  static const navy = Color(0xFF10141C);
  static const navyLight = Color(0xFF1A2438);
  static const gold = Color(0xFFD4A437);
  static const goldLight = Color(0xFFE8C468);
  static const goldDark = Color(0xFFB8862A);
  
  static const cream = Color(0xFFF8F7F3);
  static const surfaceMuted = Color(0xFF10141C);
  
  static const secondary = Color(0xFF1A2438);
  static const secondaryDark = Color(0xFF10141C);

  static const primary = Color(0xFFD4A437);
  static const primaryLight = Color(0xFFE8C468);
  static const primaryDark = Color(0xFFB8862A);
  static const primarySurface = Color(0xFF1A2438);

  static const present = Color(0xFF22C55E);
  static const absent = Color(0xFFEF4444);
  static const halfDay = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  
  static const presentSurface = Color(0xFF1A2438);
  static const absentSurface = Color(0xFF1A2438);
  static const halfSurface = Color(0xFF1A2438);
  static const temp = Color(0xFFA855F7);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFFA855F7);
  static const orange = Color(0xFFF97316);
  
  // Legacy text colors
  static const textPrimary = Color(0xFFF5F7FA);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF64748B);

  // Other legacy fallbacks found in errors
  static const background = Color(0xFF10141C); // Navy
  static const surface = Color(0xFF1A2438); // Navy Light
  static const surfaceElevated = Color(0xFF1E2A42);
  static const border = Color(0xFF293650);
  static const borderLight = Color(0xFF293650);
}
