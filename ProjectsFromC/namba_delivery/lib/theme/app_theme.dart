import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Prime Light Color Palette
  static const Color primaryOrange = Color(0xFFFF5C00); // Vibrant Namba Orange
  static const Color primaryDeepOrange = Color(0xFFE85400);
  static const Color accentGreen = Color(0xFF00B686); // Namba Verified Green
  static const Color accentTeal = Color(0xFF14B8A6);
  
  static const Color lightBg = Color(0xFFF8F9FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF1A1D2E);
  static const Color mediumText = Color(0xFF6B7280);
  static const Color lightText = Color(0xFF9CA3AF);
  
  static const Color voltageOrange = primaryOrange;
  static const Color primeGreen = accentGreen;
  static const Color primeOrange = primaryOrange;
  static const Color signalRed = Color(0xFFEF4444);
  
  static const Color glassWhite = Color(0xCCFFFFFF);
  static const Color surfacedBlack = Color(0xFF161622); // Keep for occasional dark elements if needed
  static const Color deepSpace = Color(0xFF050505);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 8), spreadRadius: -4),
  ];

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x05000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> accentShadow = [
    BoxShadow(color: Color(0x33FF5C00), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static ThemeData get primeTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        secondary: accentGreen,
        surface: lightSurface,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: darkText),
        displayMedium: GoogleFonts.outfit(color: darkText),
        bodyLarge: GoogleFonts.outfit(color: darkText),
        bodyMedium: GoogleFonts.outfit(color: darkText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkText),
        titleTextStyle: TextStyle(color: darkText, fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }

  // Alias for backward compatibility
  static ThemeData get liteTheme => primeTheme;
  static ThemeData get eliteTheme => primeTheme; // Overriding elite with prime to shift the whole app
  static ThemeData get lightTheme => primeTheme;
}
