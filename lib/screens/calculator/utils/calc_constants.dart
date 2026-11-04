import 'package:flutter/material.dart';

class CalcColors {
  // Primary (Gold)
  static Color amber(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD4A437) : const Color(0xFFC98F00);
  static Color amberDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFB8862A) : const Color(0xFF9E7000);
  static Color amberLight(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE8C468) : const Color(0xFFFFD468);
  static Color amberText(BuildContext context) => const Color(0xFFFFFFFF);

  // Background (Navy in dark, Light grey in light)
  static Color pageBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF10141C) : const Color(0xFFF6F8FB);
  static Color surface(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A2438) : const Color(0xFFFFFFFF);
  static Color border(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0);
  static Color inputBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF10141C) : const Color(0xFFF8FAFC);
  static Color searchBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF23304A) : const Color(0xFFF1F5F9);

  // Text
  static Color textPrimary(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  static Color textSecondary(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color textMuted(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // Success (result safe)
  static Color green(BuildContext context) => const Color(0xFF22C55E);
  static Color greenDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF22C55E) : const Color(0xFF16A34A);
  static Color greenMid(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF22C55E) : const Color(0xFF15803D);
  static Color greenLight(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A2438) : const Color(0xFFDCFCE7);
  static Color greenBorder(BuildContext context) => const Color(0xFF22C55E);
  static Color greenDivider(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A364F) : const Color(0xFF86EFAC);
  static Color greenNote(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF166534);

  // Danger (result unsafe)
  static Color red(BuildContext context) => const Color(0xFFEF4444);
  static Color redDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
  static Color redMid(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFEF4444) : const Color(0xFFB91C1C);
  static Color redLight(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A2438) : const Color(0xFFFEE2E2);
  static Color redBorder(BuildContext context) => const Color(0xFFEF4444);

  // Warning card
  static Color warnBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A2438) : const Color(0xFFFFFBEB);
  static Color warnBorder(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD4A437) : const Color(0xFFF59E0B);
  static Color warnIcon(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD4A437) : const Color(0xFFD97706);
  static Color warnText(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFFFFF) : const Color(0xFF92400E);

  // Category colors
  static Color concrete(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD4A437) : const Color(0xFFF59E0B);
  static Color structural(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFEF4444) : const Color(0xFF0B3157); // Deep Navy
  static Color steel(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3B82F6) : const Color(0xFF1677E8);
  static Color areaWorks(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF22C55E) : const Color(0xFF00B686);
  static Color earthwork(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA855F7) : const Color(0xFF8B5CF6);
  static Color converter(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF14B8A6) : const Color(0xFF6483A3);

  // Category light backgrounds (Elevated Surface)
  static Color concreteBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF23304A) : const Color(0xFFFEF3C7);
  static Color structuralBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF23304A) : const Color(0xFFFEE2E2);
  static Color steelBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF23304A) : const Color(0xFFDBEAFE);
  static Color areaWorksBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF23304A) : const Color(0xFFDCFCE7);
  static Color earthworkBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF23304A) : const Color(0xFFF3E8FF);
  static Color converterBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF23304A) : const Color(0xFFCCFBF1);

  // IS badge
  static Color isBadgeBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF23304A) : const Color(0xFFFEF3C7);
  static Color isBadgeBorder(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A364F) : const Color(0xFFFDE68A);
  static Color isBadgeIcon(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD4A437) : const Color(0xFFD97706);
  static Color isBadgeText(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE8C468) : const Color(0xFF92400E);
}

class CalcTextStyles {
  static TextStyle screenTitle(BuildContext context) => TextStyle(
    fontSize: 22, fontWeight: FontWeight.w500,
    color: CalcColors.textPrimary(context),
  );
  static TextStyle screenSubtitle(BuildContext context) => TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: CalcColors.textSecondary(context),
  );
  static TextStyle sectionLabel(BuildContext context) => TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: CalcColors.textMuted(context),
    letterSpacing: 0.5,
  );
  static TextStyle cardTitle(BuildContext context) => TextStyle(
    fontSize: 15, fontWeight: FontWeight.w500,
    color: CalcColors.textPrimary(context),
  );
  static TextStyle cardDesc(BuildContext context) => TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: CalcColors.textSecondary(context),
  );
  static TextStyle inputLabel(BuildContext context) => TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: CalcColors.textSecondary(context),
    letterSpacing: 0.4,
  );
  static TextStyle inputText(BuildContext context) => TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400,
    color: CalcColors.textPrimary(context),
  );
  static TextStyle resultBig(BuildContext context) => TextStyle(
    fontSize: 28, fontWeight: FontWeight.w500,
    color: CalcColors.green(context),
  );
  static TextStyle resultBigDanger(BuildContext context) => TextStyle(
    fontSize: 28, fontWeight: FontWeight.w500,
    color: CalcColors.red(context),
  );
  static TextStyle resultLabel(BuildContext context) => TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: CalcColors.greenMid(context),
  );
  static TextStyle resultRowLabel(BuildContext context) => TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: CalcColors.greenMid(context),
  );
  static TextStyle resultRowValue(BuildContext context) => TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500,
    color: CalcColors.greenDark(context),
  );
  static TextStyle resultNote(BuildContext context) => TextStyle(
    fontSize: 11, fontStyle: FontStyle.italic,
    color: CalcColors.greenNote(context),
  );
  static TextStyle tileLabel(BuildContext context) => TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500,
    color: CalcColors.textPrimary(context),
  );
  static TextStyle tileDesc(BuildContext context) => TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    color: CalcColors.textSecondary(context), height: 1.4,
  );
}

class CalcDimens {
  static const double radiusSm  = 20.0; // pill chips
  static const double radiusMd  = 10.0; // inputs, buttons
  static const double radiusLg  = 16.0; // cards
  static const double radiusXl  = 24.0; // bottom sheets
  static const double radiusIcon = 12.0; // icon containers
  
  static const double inputHeight  = 44.0;
  static const double buttonHeight = 50.0;
  static const double chipHeight   = 34.0;
  static const double tileIconSize = 40.0;
  static const double cardIconSize = 36.0;
  static const double navIconSize  = 24.0;
  
  static const double pagePadding  = 16.0;
  static const double cardPadding  = 14.0;
  static const double fieldGap     = 10.0;
  static const double sectionGap   = 12.0;
}
