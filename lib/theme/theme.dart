import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFEC8036);
  static const Color error = Color(0xFFED493D);
  static const Color background = Color(0xFFFAFAFA);
  static const Color teriary = Color(0xFF23CE7F);
  static const Color secondary = Color(0xFFCC592D);
  static const Color onPrimary = Color(0xFFFFFFFF); // white text on primary
  static const Color text = Color.fromARGB(255, 22, 22, 22); // black text
}

ThemeData getAppTheme() {
  return ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 4,
    ),
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.background,
      onSurface: AppColors.text,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.teriary,
      foregroundColor: AppColors.onPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.teriary,
        foregroundColor: AppColors.onPrimary,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
    ),
    iconTheme: IconThemeData(color: AppColors.secondary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.secondary),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.text),
      bodyMedium: TextStyle(color: AppColors.text),
      titleLarge: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
    ),
  );
}
