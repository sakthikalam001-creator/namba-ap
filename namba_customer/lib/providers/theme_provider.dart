import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // Super-Premium Design System
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color primarySlate = Color(0xFF1F2937);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryIndigo,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryIndigo,
        primary: primaryIndigo,
        secondary: primarySlate,
        surface: Colors.white,
        background: const Color(0xFFF9FAFB),
      ),
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primarySlate,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(color: primarySlate, fontWeight: FontWeight.w900, fontSize: 18),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: Colors.grey.withOpacity(0.05), width: 1),
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme(),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryIndigo,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryIndigo,
        brightness: Brightness.dark,
        primary: primaryIndigo,
        secondary: const Color(0xFFF3F4F6),
        surface: const Color(0xFF111827),
        background: const Color(0xFF030712),
      ),
      scaffoldBackgroundColor: const Color(0xFF030712),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF030712),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111827),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(bodyColor: Colors.white, displayColor: Colors.white),
    );
  }
}
