import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════
  // 🌌 MIDNIGHT AMETHYST — Premium Security Palette
  // ═══════════════════════════════════════════════════

  // Primary palette (Vivid Violet / Electric Purple)
  static const Color primary = Color(0xFFA855F7);       // ✨ Vivid Amethyst
  static const Color primaryLight = Color(0xFFC084FC);   // Soft Lavender
  static const Color secondary = Color(0xFF2DD4BF);      // Aurora Teal
  static const Color accent = Color(0xFF00F5D4);         // Neon Mint Glow

  // Backgrounds & Surfaces (Light Mode — Porcelain Mist)
  static const Color background = Color(0xFFF5F3FF);     // Ghostly Lavender
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEDE9FE); // Soft Violet Wash

  // Text Colors (Light Mode)
  static const Color textPrimary = Color(0xFF1E1B4B);    // Deep Indigo
  static const Color textSecondary = Color(0xFF4C1D95);  // Royal Purple
  static const Color textTertiary = Color(0xFF8B5CF6);   // Medium Violet

  // Backgrounds & Surfaces (Dark Mode — Deep Space Void)
  static const Color darkBackground = Color(0xFF030014);  // Cosmic Black-Violet
  static const Color darkSurface = Color(0xFF0A0620);     // Deep Nebula
  static const Color darkSurfaceVariant = Color(0xFF150D30); // Midnight Plum
  
  // Text Colors (Dark Mode)
  static const Color darkTextPrimary = Color(0xFFF5F3FF);   // Porcelain White
  static const Color darkTextSecondary = Color(0xFFC4B5FD); // Lavender Mist
  static const Color darkTextTertiary = Color(0xFF7C3AED);  // Dim Violet

  // Status Colors (Jewel-Tone)
  static const Color success = Color(0xFF34D399);  // Emerald Glow
  static const Color error = Color(0xFFFF6B8A);    // Rose Neon
  static const Color warning = Color(0xFFFBBF24);  // Gold Spark
  static const Color divider = Color(0xFF1E1B4B);

  // Category Colors (Gemstone Palette)
  static const Color photos = Color(0xFF38BDF8);   // Sapphire Sky
  static const Color videos = Color(0xFFA78BFA);   // Amethyst Glow
  static const Color documents = Color(0xFF2DD4BF); // Emerald Sea
  static const Color zip = Color(0xFFFBBF24);       // Gold Amber
  static const Color notes = Color(0xFFFB7185);     // Rose Quartz

  static Color categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'photos': return photos;
      case 'videos': return videos;
      case 'documents': return documents;
      case 'zip': return zip;
      case 'notes': return notes;
      default: return primary;
    }
  }
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get display => GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: -1.2,
      );

  static TextStyle get heading => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.6,
      );

  static TextStyle get subheading => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 0.1,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 0.4,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      dividerColor: AppColors.divider.withOpacity(0.1),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display,
        headlineLarge: AppTextStyles.heading,
        titleLarge: AppTextStyles.subheading,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.bodySmall,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.button,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.heading,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 6,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.primary,
      dividerColor: Colors.white.withOpacity(0.05),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkSurfaceVariant,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display.copyWith(color: AppColors.darkTextPrimary),
        headlineLarge: AppTextStyles.heading.copyWith(color: AppColors.darkTextPrimary),
        titleLarge: AppTextStyles.subheading.copyWith(color: AppColors.darkTextPrimary),
        bodyLarge: AppTextStyles.body.copyWith(color: AppColors.darkTextSecondary),
        bodyMedium: AppTextStyles.bodySmall.copyWith(color: AppColors.darkTextSecondary),
        bodySmall: AppTextStyles.caption.copyWith(color: AppColors.darkTextTertiary),
        labelLarge: AppTextStyles.button,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.heading.copyWith(color: AppColors.darkTextPrimary),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 8,
          shadowColor: AppColors.primary.withOpacity(0.6),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0, 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: AppTextStyles.caption.copyWith(color: AppColors.darkTextTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}

