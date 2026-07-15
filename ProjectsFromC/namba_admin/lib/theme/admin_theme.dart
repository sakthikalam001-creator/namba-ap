import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminColors {
  // Professional Palette: Carbon & Indigo
  static const Color sidebarBg = Color(0xFF0F172A); // Carbon Obsidian
  static const Color sidebarHover = Color(0xFF1E293B);
  static const Color primaryIndigo = Color(0xFF4F46E5); // Royal Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  
  static const Color background = Color(0xFFF8FAFC); // Ice Slate
  static const Color cardBg = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  
  static const Color textHeading = Color(0xFF0F172A);
  static const Color textSub = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  
  static const Color success = Color(0xFF059669); // Emerald
  static const Color warning = Color(0xFFD97706); // Amber
  static const Color danger = Color(0xFFDC2626); // Rose
  static const Color info = Color(0xFF0EA5E9); // Sky Blue
  
  static const List<Color> primaryGradient = [Color(0xFF4F46E5), Color(0xFF6366F1)];
  static const List<Color> emeraldGradient = [Color(0xFF059669), Color(0xFF10B981)];
}

class AdminStyles {
  static final headerStyle = GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: AdminColors.textHeading,
    letterSpacing: -0.5,
  );

  static final subHeaderStyle = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AdminColors.textSub,
    letterSpacing: 1.0,
  );

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 15,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
  ];
}
