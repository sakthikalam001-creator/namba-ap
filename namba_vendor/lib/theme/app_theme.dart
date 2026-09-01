import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryOrange = Color(0xFF2563EB); // Azure Blue
  static const Color primaryDeepOrange = Color(0xFF1D4ED8); // Deep Azure
  static const Color primaryRed = Color(0xFFEF4444);
  static const Color accentGreen = Color(0xFF22C55E);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentTeal = Color(0xFF14B8A6);

  // Light Mode Colors
  static const Color darkText = Color(0xFF1A1D2E);
  static const Color lightText = Color(0xFF9CA3AF);
  static const Color mediumText = Color(0xFF6B7280);
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);

  // Dark Mode Colors
  static const Color darkBg = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF131B2E);
  static const Color darkCard = Color(0xFF192238);
  static const Color darkBorder = Color(0xFF273552);
  static const Color darkTextMain = Color(0xFFF8FAFC);
  static const Color darkTextSub = Color(0xFF94A3B8);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> buttonShadow = [
    BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4)),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.outfit().fontFamily,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: lightBg,
      cardColor: lightSurface,
      dividerColor: const Color(0xFFE2E8F0),
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        secondary: accentGreen,
        surface: lightSurface,
        onSurface: darkText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.outfit(
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: darkText),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.outfit().fontFamily,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: darkBg,
      cardColor: darkSurface,
      dividerColor: darkBorder,
      colorScheme: const ColorScheme.dark(
        primary: primaryOrange,
        secondary: accentGreen,
        surface: darkSurface,
        onSurface: darkTextMain,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.outfit(
          color: darkTextMain,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: darkTextMain),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
