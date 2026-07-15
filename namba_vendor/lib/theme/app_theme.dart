import 'package:flutter/material.dart';

class AppTheme {
  // Switched to Premium Azure Blue per user request, keeping variable names intact for stability
  static const Color primaryOrange = Color(0xFF2563EB); // Azure Blue
  static const Color primaryDeepOrange = Color(0xFF1D4ED8); // Deep Azure
  static const Color primaryRed = Color(0xFFEF4444);
  static const Color accentGreen = Color(0xFF22C55E);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color darkText = Color(0xFF1A1D2E);
  static const Color lightText = Color(0xFF9CA3AF);
  static const Color mediumText = Color(0xFF6B7280);
  static const Color lightBg = Color(0xFFF5F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> buttonShadow = [
    BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4)),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: lightBg,
      colorScheme: ColorScheme.light(
        primary: primaryOrange,
        secondary: accentGreen,
      ),
    );
  }
}

