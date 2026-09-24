import 'package:flutter/material.dart';

/// Centralized theme tokens and styles adhering to Nest design aesthetics
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

  // High-Visibility Notification & Upper-Screen Banner Tokens
  static const Color notificationSurface = Color(0xFF1E1E26);
  static const Color notificationBorder = Color(0xFF4D4D62);
  static const Color notificationTextPrimary = Colors.white;
  static const Color notificationTextSecondary = Color(0xFFE2E2EC);
  static const Color notificationDiscreetGold = Color(0xFFFFB300);
  static const Color notificationLovePink = Color(0xFFFF4081);
  static const Color notificationChatBlue = Color(0xFF00E5FF);
  static const Color notificationSuccessGreen = Color(0xFF00E676);
  static const Color notificationBadgeBackground = Color(0xFF2A2A38);

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
