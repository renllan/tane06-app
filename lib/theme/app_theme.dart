import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFFF4F7FA);
  static const Color surfaceDark = Color(0xFFEFE6DA);
  static const Color surfaceMedium = Color(0xFFF9F2E7);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFF2E6D5D);
  static const Color secondary = Color(0xFFB26063);

  static const Color heartRate = Color(0xFFE96B6B);
  static const Color heartRateGlow = Color(0x40E96B6B);
  static const Color bloodPressure = Color(0xFF6C7FEA);
  static const Color bloodPressureGlow = Color(0x406C7FEA);
  static const Color sleep = Color(0xFF4CBF87);
  static const Color sleepGlow = Color(0x404CBF87);
  static const Color hrv = Color(0xFFFFA24D);
  static const Color hrvGlow = Color(0x40FFA24D);
  static const Color steps = Color(0xFF4BA3C7);
  static const Color stepsGlow = Color(0x404BA3C7);

  static const Color textPrimary = Color(0xFF20313D);
  static const Color textSecondary = Color(0xFF6B7885);
  static const Color textTertiary = Color(0xFF97A0A9);

  static const LinearGradient heartRateGradient = LinearGradient(
    colors: [Color(0xFFE96B6B), Color(0xFFFF9D7A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient bloodPressureGradient = LinearGradient(
    colors: [Color(0xFF6C7FEA), Color(0xFF8E9FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient sleepGradient = LinearGradient(
    colors: [Color(0xFF4CBF87), Color(0xFF7DE0A5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient hrvGradient = LinearGradient(
    colors: [Color(0xFFFFA24D), Color(0xFFFFC97A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient stepsGradient = LinearGradient(
    colors: [Color(0xFF4BA3C7), Color(0xFF8FD2F2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get wellnessTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.background,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
      ),
    );
    final bodyTextTheme = GoogleFonts.interTextTheme(baseTheme.textTheme);

    return baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      cardTheme: const CardTheme(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      textTheme: bodyTextTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.surfaceDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }
}
