import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark Mode Semantic Palette
  static const _darkBackground = Color(0xFF0B1018);
  static const _darkSurface = Color(0xFF111827);
  static const _darkCard = Color(0xFF172033);
  static const _darkElevated = Color(0xFF1E2A42);
  static const _darkBorder = Color(0xFF293650);
  static const _darkPrimary = Color(0xFFF2B400);

  // Light Mode Semantic Palette (Premium Slate/Cool Tint)
  static const _lightBackground = Color(0xFFF3F6F9);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightElevated = Color(0xFFFFFFFF);
  static const _lightBorder = Color(0xFFE2E8F0);
  static const _lightPrimary = Color(0xFFD97706); // Deep gold

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBackground,
      primaryColor: _darkPrimary,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        surface: _darkSurface,
        onSurface: Color(0xFFF5F7FA), // Primary text
        onPrimary: Color(0xFF000000), // Dark text on gold
      ),
      cardTheme: const CardThemeData(
        color: _darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFFF5F7FA)),
        titleTextStyle: TextStyle(
          color: Color(0xFFF5F7FA),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
        space: 1,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyLarge: const TextStyle(color: Color(0xFFF5F7FA)),
        bodyMedium: const TextStyle(color: Color(0xFF94A3B8)), // Secondary text
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: const Color(0xFF000000),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: _darkPrimary,
        unselectedItemColor: Color(0xFF64748B),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBackground,
      primaryColor: _lightPrimary,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        surface: _lightSurface,
        onSurface: Color(0xFF0F172A), // Slate 900
        onPrimary: Color(0xFFFFFFFF),
      ),
      cardTheme: CardThemeData(
        color: _lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: const Color(0xFF0F172A).withValues(alpha: 0.08), width: 1), // Subtle border definition
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _lightBorder,
        thickness: 1,
        space: 1,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        bodyLarge: const TextStyle(color: Color(0xFF0F172A)),
        bodyMedium: const TextStyle(color: Color(0xFF475569)), // Slate 600
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: const Color(0xFFFFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _lightSurface,
        selectedItemColor: _lightPrimary,
        unselectedItemColor: Color(0xFF94A3B8), // Slate 400
      ),
    );
  }
}
