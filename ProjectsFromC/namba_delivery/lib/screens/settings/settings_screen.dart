import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  String _language = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('APP CONFIGURATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
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
            _buildSettingsSection('COMMUNICATION', [
              _toggleItem(icons.Iconsax.notification_copy, 'Order Notifications', _notifications, (v) => setState(() => _notifications = v)),
              _languageItem(icons.Iconsax.translate_copy, 'App Language', _language, () => _showLanguagePicker()),
            ]),
            const SizedBox(height: 32),
            _buildSettingsSection('ACCOUNT & SECURITY', [
              _menuItem(icons.Iconsax.user_edit_copy, 'Edit Profile', () {}, color: AppTheme.primaryOrange),
              _menuItem(icons.Iconsax.key_copy, 'Privacy Center', () {}, color: AppTheme.accentGreen),
              _menuItem(icons.Iconsax.security_safe_copy, 'Terms of Service', () {}, isLast: true),
            ]),
            const SizedBox(height: 48),
            Text('BUILD v2.4.0-PRIME', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.lightText, letterSpacing: 1)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(children: children),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _toggleItem(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.lightBg))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppTheme.accentGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkText)),
          const Spacer(),
          Switch.adaptive(
            value: value, 
            onChanged: onChanged, 
            activeColor: AppTheme.accentGreen,
          ),
        ],
      ),
    );
  }

  Widget _languageItem(IconData icon, String title, String current, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppTheme.primaryOrange, size: 20),
            ),
            const SizedBox(width: 16),
            Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkText)),
            const Spacer(),
            Text(current.toUpperCase(), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primaryOrange)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.lightBg),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap, {Color? color, bool isLast = false}) {
    final activeColor = color ?? AppTheme.lightText;
    return InkWell(
      onTap: onTap,
      borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(24)) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: AppTheme.lightBg))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: activeColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: activeColor, size: 20),
            ),
            const SizedBox(width: 16),
            Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkText)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.lightBg),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CHOOSE LANGUAGE', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.lightText, letterSpacing: 1.5)),
            const SizedBox(height: 32),
            _langTile('ENGLISH', 'United States', _language == 'English', () => setState(() { _language = 'English'; Navigator.pop(ctx); })),
            const SizedBox(height: 12),
            _langTile('TAMIL', 'தமிழ்நாடு', _language == 'Tamil', () => setState(() { _language = 'Tamil'; Navigator.pop(ctx); })),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _langTile(String label, String region, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentGreen.withValues(alpha: 0.05) : AppTheme.lightBg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.accentGreen : Colors.transparent),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: selected ? AppTheme.accentGreen : AppTheme.darkText)),
                Text(region, style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.lightText, fontWeight: FontWeight.w700)),
              ],
            ),
            const Spacer(),
            if (selected) const Icon(icons.Iconsax.tick_circle_copy, color: AppTheme.accentGreen, size: 24),
          ],
        ),
      ),
    );
  }
}
