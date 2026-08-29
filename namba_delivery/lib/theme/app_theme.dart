import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Official Namba Brand Color System ──────────────────────────────────
  static const Color primaryOrange = Color(0xFF4F46E5); // Modern Vibrant Indigo
  static const Color primaryDeepOrange = Color(0xFF4338CA); // Deep Indigo
  static const Color accentGreen = Color(0xFF10B981); // Emerald Green
  static const Color accentTeal = Color(0xFF0D9488);
  
  static const Color lightBg = Color(0xFFF8FAFC); // Clean Slate-50 Background
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF0F172A); // Rich Slate-900
  static const Color mediumText = Color(0xFF475569); // Slate-600
  static const Color lightText = Color(0xFF94A3B8); // Slate-400
  static const Color borderLight = Color(0xFFF1F5F9); // Slate-100 Border
  
  static const Color voltageOrange = primaryOrange;
  static const Color primeGreen = accentGreen;
  static const Color primeOrange = primaryOrange;
  static const Color signalRed = Color(0xFFEF4444);
  
  static const Color glassWhite = Color(0xCCFFFFFF);
  static const Color surfacedBlack = Color(0xFF0F172A);
  static const Color deepSpace = Color(0xFF020617);

  // Modern Layered Diffused Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 24, offset: Offset(0, 8), spreadRadius: 0),
    BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 2), spreadRadius: 0),
  ];

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x060F172A), blurRadius: 16, offset: Offset(0, 4), spreadRadius: 0),
    BoxShadow(color: Color(0x020F172A), blurRadius: 4, offset: Offset(0, 1), spreadRadius: 0),
  ];

  static const List<BoxShadow> accentShadow = [
    BoxShadow(color: Color(0x254F46E5), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> greenShadow = [
    BoxShadow(color: Color(0x2510B981), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static ThemeData get primeTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        secondary: accentGreen,
        surface: lightSurface,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: darkText, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        displayMedium: GoogleFonts.outfit(color: darkText, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        bodyLarge: GoogleFonts.outfit(color: darkText, fontWeight: FontWeight.w600),
        bodyMedium: GoogleFonts.outfit(color: mediumText, fontWeight: FontWeight.w500),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkText),
        titleTextStyle: GoogleFonts.outfit(color: darkText, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
    );
  }

  // Aliases for backward compatibility
  static ThemeData get liteTheme => primeTheme;
  static ThemeData get eliteTheme => primeTheme;
  static ThemeData get lightTheme => primeTheme;
}
