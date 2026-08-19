import 'package:flutter/material.dart';

class AppColors {
  // Primary palette — clinical teal
  static const primary = Color(0xFF0A9396);
  static const primaryLight = Color(0xFF94D2BD);
  static const primaryDark = Color(0xFF005F73);

  // Accent — warm sky blue
  static const accent = Color(0xFF0077B6);
  static const accentLight = Color(0xFF90E0EF);

  // Surface & Background
  static const background = Color(0xFFF8FFFE);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F9F9);

  // Text
  static const textPrimary = Color(0xFF1A2E35);
  static const textSecondary = Color(0xFF5A7A85);
  static const textHint = Color(0xFFABC4C9);

  // Gradient stops
  static const gradientTop = Color(0xFFE8F8F7);
  static const gradientBottom = Color(0xFFD0F0EE);

  // Feedback
  static const error = Color(0xFFE63946);
  static const success = Color(0xFF2DC653);
  static const warning = Color(0xFFFFB703);

  // Divider & border
  static const border = Color(0xFFDDEEEE);
  static const divider = Color(0xFFE8F4F3);
}

class AppTextStyles {
  static const displayLarge = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const headlineMedium = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const titleLarge = TextStyle(
    fontFamily: 'sans-serif',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  static const bodyLarge = TextStyle(
    fontFamily: 'sans-serif',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const bodyMedium = TextStyle(
    fontFamily: 'sans-serif',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const labelLarge = TextStyle(
    fontFamily: 'sans-serif',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const caption = TextStyle(
    fontFamily: 'sans-serif',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
      primary: AppColors.primary,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'sans-serif',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
      labelStyle: AppTextStyles.bodyMedium,
      errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
      prefixIconColor: AppColors.textSecondary,
      suffixIconColor: AppColors.textSecondary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        textStyle: AppTextStyles.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTextStyles.labelLarge.copyWith(fontSize: 14),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: AppColors.border, width: 1.5),
    ),
  );
}
