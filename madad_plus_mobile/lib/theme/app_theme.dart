import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color blue = Color(0xFF17365D);
  static const Color red = Color(0xFFB4232C);
  static const Color green = Color(0xFF176B5E);
  static const Color orange = Color(0xFF8A4B00);
  static const Color ink = Color(0xFF17212F);
  static const Color muted = Color(0xFF52606D);
  static const Color line = Color(0xFFC8D1DC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color page = Color(0xFFEDF1F6);
  static const Color soft = Color(0xFFF7F9FC);
  static const Color focus = Color(0xFF005FCC);
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

class AppSpacing {
  AppSpacing._();

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;
}

class AppTextTheme {
  AppTextTheme._();

  static const TextTheme textTheme = TextTheme(
    headlineLarge: TextStyle(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      height: 1.5,
      fontWeight: FontWeight.w800,
      color: AppColors.muted,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    ),
  );
}

class AppTheme {
  AppTheme._();

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.page,
    dividerColor: AppColors.line,
    focusColor: AppColors.focus,
    colorScheme: const ColorScheme.light(
      primary: AppColors.blue,
      onPrimary: AppColors.surface,
      secondary: AppColors.green,
      onSecondary: AppColors.surface,
      tertiary: AppColors.orange,
      onTertiary: AppColors.surface,
      error: AppColors.red,
      onError: AppColors.surface,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    ),
    textTheme: AppTextTheme.textTheme,
  );
}
