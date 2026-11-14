import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF1A1F2B);
  static const navy50 = Color(0xFFF4F5F7);
  static const navy100 = Color(0xFFE5E7EB);
  static const navy200 = Color(0xFFC8CCD4);
  static const navy300 = Color(0xFF9AA1B0);
  static const navy400 = Color(0xFF6B7385);
  static const navy500 = Color(0xFF454B5A);
  static const navy600 = Color(0xFF2F3442);
  static const navy700 = Color(0xFF242936);
  static const navy800 = Color(0xFF1A1F2B);
  static const navy900 = Color(0xFF12151E);
  static const brand = Color(0xFFFF6B00);
  static const brand50 = Color(0xFFFFF4EB);
  static const brand100 = Color(0xFFFFE4CC);
  static const brand600 = Color(0xFFE05A00);
  static const brand700 = Color(0xFFB84700);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brand,
        onPrimary: Colors.white,
        secondary: AppColors.navy800,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.navy800,
        error: AppColors.danger,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy800,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.navy800,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerColor: AppColors.navy100,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.navy400, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.navy700, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navy200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navy200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy800,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.navy800,
        displayColor: AppColors.navy800,
      ),
    );
  }
}

int gridCount(double width) {
  if (width >= 1200) return 4;
  if (width >= 840) return 3;
  if (width >= 360) return 2;
  return 1;
}

double pagePadding(double width) {
  if (width >= 1200) return 32;
  if (width >= 700) return 24;
  return 16;
}
