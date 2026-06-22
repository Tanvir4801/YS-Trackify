import 'package:flutter/material.dart';

class CalcColors {
  // Primary (Gold)
  static const amber        = Color(0xFFD4A437);
  static const amberDark    = Color(0xFFB8862A);
  static const amberLight   = Color(0xFFE8C468);
  static const amberText    = Color(0xFFFFFFFF);

  // Background (Navy)
  static const pageBg       = Color(0xFF10141C);
  static const surface      = Color(0xFF1A2438);
  static const border       = Color(0xFF2A364F);
  static const inputBg      = Color(0xFF10141C);
  static const searchBg     = Color(0xFF23304A);

  // Text
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted     = Color(0xFF64748B);

  // Success (result safe)
  static const green         = Color(0xFF22C55E);
  static const greenDark     = Color(0xFF22C55E);
  static const greenMid      = Color(0xFF22C55E);
  static const greenLight    = Color(0xFF1A2438);
  static const greenBorder   = Color(0xFF22C55E);
  static const greenDivider  = Color(0xFF2A364F);
  static const greenNote     = Color(0xFF94A3B8);

  // Danger (result unsafe)
  static const red           = Color(0xFFEF4444);
  static const redDark       = Color(0xFFEF4444);
  static const redMid        = Color(0xFFEF4444);
  static const redLight      = Color(0xFF1A2438);
  static const redBorder     = Color(0xFFEF4444);

  // Warning card
  static const warnBg        = Color(0xFF1A2438);
  static const warnBorder    = Color(0xFFD4A437);
  static const warnIcon      = Color(0xFFD4A437);
  static const warnText      = Color(0xFFFFFFFF);

  // Category colors
  static const concrete      = Color(0xFFD4A437); // Gold
  static const structural    = Color(0xFFEF4444); // Red
  static const steel         = Color(0xFF3B82F6); // Blue
  static const areaWorks     = Color(0xFF22C55E); // Green
  static const earthwork     = Color(0xFFA855F7); // Purple
  static const converter     = Color(0xFF14B8A6); // Teal

  // Category light backgrounds (Elevated Surface)
  static const concreteBg    = Color(0xFF23304A);
  static const structuralBg  = Color(0xFF23304A);
  static const steelBg       = Color(0xFF23304A);
  static const areaWorksBg   = Color(0xFF23304A);
  static const earthworkBg   = Color(0xFF23304A);
  static const converterBg   = Color(0xFF23304A);

  // IS badge
  static const isBadgeBg     = Color(0xFF23304A);
  static const isBadgeBorder = Color(0xFF2A364F);
  static const isBadgeIcon   = Color(0xFFD4A437);
  static const isBadgeText   = Color(0xFFE8C468);
}

class CalcTextStyles {
  static const screenTitle = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w500,
    color: CalcColors.textPrimary,
  );
  static const screenSubtitle = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: CalcColors.textSecondary,
  );
  static const sectionLabel = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: CalcColors.textMuted,
    letterSpacing: 0.5,
  );
  static const cardTitle = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w500,
    color: CalcColors.textPrimary,
  );
  static const cardDesc = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: CalcColors.textSecondary,
  );
  static const inputLabel = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: CalcColors.textSecondary,
    letterSpacing: 0.4,
  );
  static const inputText = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400,
    color: CalcColors.textPrimary,
  );
  static const resultBig = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w500,
    color: CalcColors.green,
  );
  static const resultBigDanger = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w500,
    color: CalcColors.red,
  );
  static const resultLabel = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: CalcColors.greenMid,
  );
  static const resultRowLabel = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: CalcColors.greenMid,
  );
  static const resultRowValue = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500,
    color: CalcColors.greenDark,
  );
  static const resultNote = TextStyle(
    fontSize: 11, fontStyle: FontStyle.italic,
    color: CalcColors.greenNote,
  );
  static const tileLabel = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500,
    color: CalcColors.textPrimary,
  );
  static const tileDesc = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    color: CalcColors.textSecondary, height: 1.4,
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
