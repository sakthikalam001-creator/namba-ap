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

  // ── Extended Color Tokens ──────────────────────────────────────────
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);

  static const Color indigo50 = Color(0xFFEEF2FF);
  static const Color indigo100 = Color(0xFFE0E7FF);
  static const Color indigo600 = Color(0xFF4F46E5);
  static const Color indigo700 = Color(0xFF4338CA);

  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber600 = Color(0xFFD97706);

  static const Color rose50 = Color(0xFFFFF1F2);
  static const Color rose100 = Color(0xFFFFE4E6);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color rose600 = Color(0xFFE11D48);

  // ── Unified Typography Scale ──────────────────────────────────────
  static TextStyle get h1 => GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: darkText,
    letterSpacing: -0.5,
  );

  static TextStyle get h2 => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: darkText,
    letterSpacing: -0.3,
  );

  static TextStyle get h3 => GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: darkText,
  );

  static TextStyle get body => GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: mediumText,
  );

  static TextStyle get bodyBold => GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: darkText,
  );

  static TextStyle get bodySmall => GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: mediumText,
  );

  static TextStyle get caption => GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: lightText,
  );

  static TextStyle get captionBold => GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: darkText,
  );

  static TextStyle get badgeText => GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );

  static TextStyle get currencyText => GoogleFonts.outfit(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: darkText,
    letterSpacing: -0.5,
  );

  // ── Clean & Spacious Box Decorations ──────────────────────────────
  static BoxDecoration cardBoxDecoration({
    Color color = Colors.white,
    double radius = 20,
    Color borderColor = slate200,
    double borderWidth = 1.0,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: shadows ?? cardShadow,
    );
  }

  static BoxDecoration pillDecoration({
    required Color bg,
    required Color border,
    double radius = 24,
  }) {
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: 1.0),
    );
  }

  static ThemeData get primeTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: lightBg,
      fontFamily: GoogleFonts.outfit().fontFamily,
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        secondary: accentGreen,
        surface: lightSurface,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
        fontFamily: GoogleFonts.outfit().fontFamily,
      ).copyWith(
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
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: slate200, width: 1),
        ),
      ),
    );
  }

  // Aliases for backward compatibility
  static ThemeData get liteTheme => primeTheme;
  static ThemeData get eliteTheme => primeTheme;
  static ThemeData get lightTheme => primeTheme;
}
