import 'package:flutter/material.dart';

/// Centralized theme tokens and styles adhering to ourPlace design aesthetics
class AppTheme {
  // Brand Palette
  static const Color background = Colors.black;
  static const Color surfaceCharcoal = Color(0xFF383838);
  static const Color chipBackground = Color(0xFF222222);
  static const Color chipBorder = Color(0xFF333333);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted = Colors.white54;
  static const Color accentBlue = Color(0xFF64B5F6);

  /// Application dark theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        surface: surfaceCharcoal,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
      ),
    );
  }
}
