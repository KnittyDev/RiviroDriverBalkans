import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Brand Color (#99cfcf)
  static const Color primary = Color(0xFF99CFCF); // Direct #99cfcf hex
  static const Color primaryActiveBg = Color(0x2899CFCF); // Soft 16% opacity #99cfcf for pill
  static const Color primarySubtle = Color(0xFFEBF7F7);
  // Neutral & Surface (Pure White theme)
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color card = Colors.white;
  // Typography
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textInactive = Color(0xFF94A3B8);
  // Borders & Shadows
  static const Color border = Color(0xFFF1F5F5);
  static const Color shadowColor = Color(0x0C0F172A);
}

class AppTheme {
  static ThemeData get lightTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textDark),
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme),
    );
  }
}
