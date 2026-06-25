import 'package:flutter/material.dart';

class AppColors {
  // ── Navy + Gold premium palette ──────────────────────────────────────────
  static const navy        = Color(0xFF10141C);
  static const navyLight   = Color(0xFF1A2030);
  static const gold        = Color(0xFFD4A437);
  static const goldLight   = Color(0xFFE8C468);
  static const goldDark    = Color(0xFFB8862A);

  static const cream       = Color(0xFFF8F7F3);
  static const surfaceMuted= Color(0xFFF1F0EC);

  // ── Semantic (kept for backward compat) ─────────────────────────────────
  static const primary        = Color(0xFF10141C);   // navy — main brand dark
  static const primaryLight   = Color(0xFFD4A437);   // gold shimmer
  static const primaryDark    = Color(0xFF0A0E14);
  static const primarySurface = Color(0xFFF1F0EC);   // cream tint

  static const secondary      = Color(0xFFD4A437);
  static const accent         = Color(0xFFD4A437);
  static const accentSurface  = Color(0xFFFEF9EC);

  // ── Attendance status ────────────────────────────────────────────────────
  static const present        = Color(0xFF22C55E);
  static const presentSurface = Color(0xFFEAFBF0);
  static const absent         = Color(0xFFEF4444);
  static const absentSurface  = Color(0xFFFEECEC);
  static const halfDay        = Color(0xFFF59E0B);
  static const halfSurface    = Color(0xFFFEF3E0);

  // ── Legacy aliases kept to avoid breaking references ─────────────────────
  static const presentBg  = presentSurface;
  static const absentBg   = absentSurface;
  static const halfDayBg  = halfSurface;
  static const temp        = Color(0xFFA855F7);
  static const tempBg      = Color(0xFFF6EEFE);
  static const blue        = Color(0xFF3B82F6);
  static const blueBg      = Color(0xFFEAF2FE);

  // ── Surfaces & borders ───────────────────────────────────────────────────
  static const background      = cream;
  static const surface         = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFF1F0EC);
  static const border          = Color(0xFFE7E5DE);
  static const borderLight     = Color(0xFFF1F0EC);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const textPrimary       = Color(0xFF12151B);
  static const textSecondary     = Color(0xFF6B7280);
  static const textTertiary      = Color(0xFFA0A3A8);
  static const textOnPrimary     = Color(0xFFFFFFFF);
  static const textOnDark        = Color(0xFFFFFFFF);
  static const textOnDarkMuted   = Color(0xFFB8BCC4);

  // ── Legacy card colours (kept so existing widgets compile) ───────────────
  static const blueCard   = Color(0xFFEFF6FF);
  static const greenCard  = Color(0xFFF0FDF4);
  static const redCard    = Color(0xFFFEF2F2);
  static const amberCard  = Color(0xFFFFFBEB);
  static const purpleCard = Color(0xFFF5F3FF);
  static const slateCard  = Color(0xFFF8FAFC);
  static const skyCard    = Color(0xFFE0F2FE);
  static const yellowCard = Color(0xFFFEFCE8);

  static const gradientStart = navy;
  static const gradientEnd   = gold;
}
