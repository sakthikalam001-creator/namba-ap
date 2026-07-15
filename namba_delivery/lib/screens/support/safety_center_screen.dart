import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('SAFETY & SECURITY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            _buildSOSSection(),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SAFETY GUIDELINES', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.lightText, letterSpacing: 1)),
                const Icon(icons.Iconsax.security_safe_copy, color: AppTheme.accentGreen, size: 16),
              ],
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 16),
            _buildSafetyGuidelines(),
            const SizedBox(height: 48),
            _buildEmergencyContacts(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: AppTheme.signalRed.withValues(alpha: 0.1), blurRadius: 40, offset: const Offset(0, 10))],
        border: Border.all(color: AppTheme.signalRed.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(color: AppTheme.signalRed.withValues(alpha: 0.1), shape: BoxShape.circle),
              ).animate(onPlay: (c) => c.repeat()).scale(duration: 1500.ms, begin: const Offset(1,1), end: const Offset(1.6,1.6)).fade(begin: 0.3, end: 0),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: const BoxDecoration(color: AppTheme.signalRed, shape: BoxShape.circle),
                child: const Icon(icons.Iconsax.danger_copy, color: Colors.white, size: 40),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'SIGNAL SOS',
            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.signalRed, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'IMMEDIATE EMERGENCY ASSISTANCE.\nOUR TEAM IS STANDING BY 24/7.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.lightText, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildSafetyGuidelines() {
    return Column(
      children: [
        _guidelineItem('WEAR HELMET', 'Ensure your helmet is securely fastened for every ride.', icons.Iconsax.shield_tick_copy),
        _guidelineItem('SAFE SPEED', 'Stick to safe speed limits. Do not rush for deliveries.', icons.Iconsax.timer_1_copy),
        _guidelineItem('SAFE HANDOVER', 'Follow no-contact protocols whenever possible.', icons.Iconsax.mask_copy),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _guidelineItem(String title, String desc, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.accentGreen, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.darkText)),
                const SizedBox(height: 2),
                Text(desc, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.lightText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EMERGENCY CONTACTS', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.lightText, letterSpacing: 1.5)),
        const SizedBox(height: 20),
        _contactItem('POLICE', '100', Colors.blueAccent),
        _contactItem('AMBULANCE', '108', AppTheme.signalRed),
        _contactItem('NAMBA SUPPORT', '1800-NAMBA', AppTheme.primaryOrange),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _contactItem(String label, String contact, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(contact, style: GoogleFonts.outfit(color: color, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.call_rounded, color: color, size: 20),
          ),
        ],
      ),
    );
  }
}
