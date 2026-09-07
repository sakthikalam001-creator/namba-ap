import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('customer_dark_mode') ?? false;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (_) {}
  }

  void toggleTheme(bool isOn) async {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('customer_dark_mode', isOn);
    } catch (_) {}
  }

  // Dynamic Semantic Color System for All Pages
  Color get scaffoldBg => isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get cardBg => isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get cardBgSecondary => isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
  Color get textPrimary => isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get textSecondary => isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get borderCol => isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get inputBg => isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  Color get navBg => isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get modalBg => isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get mapBg => isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0);
  
  String get mapTileUrl => isDarkMode
      ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'
      : 'https://mt{s}.google.com/vt/lyrs=m&hl=en&gl=IN&x={x}&y={y}&z={z}';

  // Super-Premium Brand Colors
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color primarySlate = Color(0xFF0F172A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryIndigo,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryIndigo,
        primary: primaryIndigo,
        secondary: primarySlate,
        surface: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primarySlate,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(color: primarySlate, fontWeight: FontWeight.w800, fontSize: 18),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
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
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.dark(
        primary: primaryIndigo,
        secondary: Color(0xFFF8FAFC),
        surface: Color(0xFF1E293B),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(color: const Color(0xFFF8FAFC), fontWeight: FontWeight.w800, fontSize: 18),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: const Color(0xFFF8FAFC),
        displayColor: const Color(0xFFF8FAFC),
      ),
    );
  }
}
