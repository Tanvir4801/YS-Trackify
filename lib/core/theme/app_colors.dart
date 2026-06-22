import 'package:flutter/material.dart';

class AppColors {
  // ── Navy + Gold premium palette ──────────────────────────────────────────
  static const navy        = Color(0xFF10141C);
  static const navyLight   = Color(0xFF1A2438);
  static const gold        = Color(0xFFD4A437);
  static const goldLight   = Color(0xFFE8C468);
  static const goldDark    = Color(0xFFB8862A);

  static const cream       = Color(0xFFF8F7F3);
  static const surfaceMuted= Color(0xFF10141C); // Changed to navy

  // ── Semantic (kept for backward compat) ─────────────────────────────────
  static const primary        = Color(0xFFD4A437);   // gold
  static const primaryLight   = Color(0xFFE8C468);   // gold shimmer
  static const primaryDark    = Color(0xFFB8862A);
  static const primarySurface = Color(0xFF1A2438);   // navyLight

  static const secondary      = Color(0xFF1A2438);
  static const accent         = Color(0xFFD4A437);
  static const accentSurface  = Color(0xFF1A2438);

  // ── Attendance status ────────────────────────────────────────────────────
  static const present        = Color(0xFF22C55E);
  static const success        = present;
  static const presentSurface = Color(0xFF1A2438); // Dark surface
  static const absent         = Color(0xFFEF4444);
  static const danger         = absent;
  static const absentSurface  = Color(0xFF1A2438);
  static const halfDay        = Color(0xFFF59E0B);
  static const halfSurface    = Color(0xFF1A2438);

  // ── Legacy aliases kept to avoid breaking references ─────────────────────
  static const presentBg  = presentSurface;
  static const absentBg   = absentSurface;
  static const halfDayBg  = halfSurface;
  static const temp        = Color(0xFFA855F7);
  static const tempBg      = Color(0xFF1A2438);
  static const blue        = Color(0xFF3B82F6);
  static const blueBg      = Color(0xFF1A2438);

  // ── Surfaces & borders ───────────────────────────────────────────────────
  static const background      = navy;
  static const surface         = navyLight;
  static const surfaceElevated = Color(0xFF23304A);
  static const border          = Color(0xFF2A364F);
  static const borderLight     = Color(0xFF23304A);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const textPrimary       = Color(0xFFFFFFFF);
  static const textSecondary     = Color(0xFF94A3B8);
  static const textTertiary      = Color(0xFF64748B);
  static const textOnPrimary     = Color(0xFF10141C); // Dark text on Gold
  static const textOnDark        = Color(0xFFFFFFFF);
  static const textOnDarkMuted   = Color(0xFF94A3B8);

  // ── Legacy card colours (kept so existing widgets compile) ───────────────
  static const blueCard   = navyLight;
  static const greenCard  = navyLight;
  static const redCard    = navyLight;
  static const amberCard  = navyLight;
  static const purpleCard = navyLight;
  static const slateCard  = navyLight;
  static const skyCard    = navyLight;
  static const yellowCard = navyLight;

  static const gradientStart = navy;
  static const gradientEnd   = Color(0xFF172033);
}
