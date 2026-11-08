import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const night = Color(0xFF14101A);
  static const nightElevated = Color(0xFF1D1726);
  static const plum = Color(0xFF3A1F3D);
  static const coral = Color(0xFFE88A7A);
  static const sage = Color(0xFF9BAE9A);
  static const cream = Color(0xFFF7F1E8);
  static const textPrimary = Color(0xFFF7F1E8);
  static const textSecondary = Color(0xFFB8AEB9);
  static const textMuted = Color(0xFF6E6570);
  static const outline = Color(0xFF2E2634);
}

class T {
  T._();
  static const display = TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.2);
  static const headline = TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3);
  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.35);
  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.55);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);
  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.night,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.coral,
      onPrimary: AppColors.night,
      secondary: AppColors.sage,
      onSecondary: AppColors.night,
      surface: AppColors.nightElevated,
      onSurface: AppColors.textPrimary,
      outline: AppColors.outline,
    ),
    textTheme: TextTheme(
      displayMedium: T.display.copyWith(color: AppColors.textPrimary),
      headlineMedium: T.headline.copyWith(color: AppColors.textPrimary),
      titleMedium: T.title.copyWith(color: AppColors.textPrimary),
      bodyMedium: T.body.copyWith(color: AppColors.textSecondary),
      bodySmall: T.caption.copyWith(color: AppColors.textMuted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.textPrimary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.coral,
        foregroundColor: AppColors.night,
        textStyle: T.button,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        textStyle: T.button,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.coral,
      thumbColor: AppColors.coral,
      inactiveTrackColor: AppColors.outline,
    ),
  );
}