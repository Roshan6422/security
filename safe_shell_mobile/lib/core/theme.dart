import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF4DA3FF); // Light blue
  static const Color accent = Color(0xFF0A2A4F); // Dark blue
  static const Color background = Color(0xFF0B0F14); // Near-black
  static const Color surface = Color(0xFF1A1F26); // Slightly lighter background
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFEAF2FF);
  static const Color error = Color(0xFFCF6679);

  // Category Colors
  static const Color photos = Color(0xFF4DA3FF);
  static const Color videos = Color(0xFF8B5CF6);
  static const Color documents = Color(0xFF10B981);
  static const Color zip = Color(0xFFF59E0B);
  static const Color notes = Color(0xFFF43F5E); // Added missing color
}

class AppTextStyles {
  static TextStyle get display => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        letterSpacing: -0.02,
      );

  static TextStyle get heading => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.02,
      );

  static TextStyle get subheading => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary.withOpacity(0.7),
      );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display,
        headlineLarge: AppTextStyles.heading,
        titleLarge: AppTextStyles.subheading,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.body,
        labelSmall: AppTextStyles.caption,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.heading,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
    );
  }
}

