import 'package:flutter/material.dart';

/// Tokens de color de Jota Parasite. Mantener aquí los colores de marca.
abstract final class AppColors {
  static const background = Color(0xFF161124);
  static const heroStart = Color(0xFF2B1B42);
  static const heroEnd = Color(0xFF382356);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF8F6FC);
  static const border = Color(0xFFEADEF7);
  static const lime = Color(0xFFA3FF2E);
  static const limeStrong = Color(0xFF94F024);
  static const action = Color(0xFF6C3EB8);
  static const actionLight = Color(0xFF7C43BD);
  static const chip = Color(0xFFEADAFF);
  static const alert = Color(0xFFFEE2E2);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA79BB7);
  static const textOnSurface = Color(0xFF1E152A);
}

abstract final class AppRadii {
  static const card = 24.0;
  static const control = 16.0;
  static const pill = 999.0;
}

abstract final class AppTheme {
  static BoxDecoration get heroCardDecoration => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroStart, AppColors.heroEnd],
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: const Color(0x26EADAFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44090016),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      );

  static BoxDecoration get surfaceCardDecoration => BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      );

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.actionLight,
        onPrimary: AppColors.textPrimary,
        secondary: AppColors.lime,
        onSecondary: AppColors.textOnSurface,
        surface: AppColors.heroStart,
        onSurface: AppColors.textPrimary,
        error: Color(0xFFFF7373),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 32,
          height: 1.12,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        headlineMedium: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 25,
          height: 1.18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
        titleLarge: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          height: 1.45,
        ),
        bodyMedium: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.35,
        ),
        labelLarge: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x33EADAFF),
        thickness: 1,
      ),
    );
  }
}
