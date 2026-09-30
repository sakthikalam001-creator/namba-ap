import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';
import '../../services/delivery_language_provider.dart';
import '../rider_permissions_wizard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  String _driverName = 'Partner';
  String _driverPhone = '';
  String _vehicleType = 'Bike';
  String _vehicleNumber = '';
  String _upiId = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final name = await DeliveryAuthService.getDriverName();
    final phone = await DeliveryAuthService.getDriverPhone();
    final savedNotifs = prefs.getBool('order_notifications_enabled') ?? true;
    final savedVehicle = prefs.getString('driver_vehicle_type') ?? 'Bike';
    final savedVehNum = prefs.getString('driver_vehicle_number') ?? 'TN 01 AB 1234';
    final savedUpi = prefs.getString('driver_upi_id') ?? 'partner@okaxis';

    if (mounted) {
      setState(() {
        _notifications = savedNotifs;
        _driverName = name.isNotEmpty ? name : 'Partner';
        _driverPhone = phone;
        _vehicleType = savedVehicle;
        _vehicleNumber = savedVehNum;
        _upiId = savedUpi;
      });
    }
  }

  Future<void> _updateNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('order_notifications_enabled', value);
    setState(() => _notifications = value);
    HapticFeedback.lightImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(value ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                value ? 'Order notification alerts enabled' : 'Order notification alerts muted',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          backgroundColor: value ? const Color(0xFF10B981) : const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _setLanguage(AppLanguage lang) async {
    final langProv = context.read<DeliveryLanguageProvider>();
    await langProv.setLanguage(lang);
    HapticFeedback.mediumImpact();

    if (mounted) {
      String msg = 'Language updated to ${langProv.languageCodeName}';
      if (lang == AppLanguage.tamil) msg = 'மொழி தமிழாக மாற்றப்பட்டது!';
      if (lang == AppLanguage.tanglish) msg = 'App language Tanglish-ku maathiyachu!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.translate_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4F46E5),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProv = context.watch<DeliveryLanguageProvider>();
    final activeLangName = langProv.languageCodeName;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text(
          context.tr('app_configuration'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: AppTheme.darkText),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.borderLight, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            _buildSettingsSection(context.tr('communication'), [
              _toggleItem(
                icons.Iconsax.notification_copy,
                context.tr('order_notifications'),
                _notifications,
                _updateNotifications,
              ),
              _languageItem(
                icons.Iconsax.translate_copy,
                context.tr('app_language'),
                activeLangName,
                () => _showLanguagePicker(),
              ),
            ]),
            const SizedBox(height: 28),
            _buildSettingsSection(context.tr('account_security'), [
              _menuItem(
                icons.Iconsax.shield_tick_copy,
                context.tr('rider_setup_permissions'),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RiderPermissionsWizardScreen(nextScreen: SettingsScreen()),
                    ),
                  );
                },
                color: AppTheme.accentGreen,
              ),
              _menuItem(
                icons.Iconsax.user_square_copy,
                context.tr('verified_profile_details'),
                () => _showVerifiedProfileModal(),
                color: AppTheme.primaryOrange,
                isLast: true,
              ),
            ]),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'BUILD v2.4.0-PRIME • FLEET CLIENT',
                style: GoogleFonts.outfit(
                  color: AppTheme.lightText,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 20),
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
          padding: const EdgeInsets.only(left: 6, bottom: 10),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.softShadow,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(children: children),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _toggleItem(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.lightBg))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.accentGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.darkText),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.accentGreen,
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
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.darkText),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                current.toUpperCase(),
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5)),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
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
              decoration: BoxDecoration(color: activeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: activeColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.darkText),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  // ── LANGUAGE PICKER MODAL (English, Tamil, Tanglish) ──────────────────────
  void _showLanguagePicker() {
    final langProv = context.read<DeliveryLanguageProvider>();
    final current = langProv.currentLanguage;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.translate_rounded, color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('select_app_language'),
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('choose_display_lang'),
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.darkText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _langTile(
              flag: '🇬🇧',
              title: context.tr('lang_english_title'),
              subtitle: context.tr('lang_english_desc'),
              selected: current == AppLanguage.english,
              onTap: () {
                Navigator.pop(ctx);
                _setLanguage(AppLanguage.english);
              },
            ),
            const SizedBox(height: 12),
            _langTile(
              flag: '🇮🇳',
              title: context.tr('lang_tamil_title'),
              subtitle: context.tr('lang_tamil_desc'),
              selected: current == AppLanguage.tamil,
              onTap: () {
                Navigator.pop(ctx);
                _setLanguage(AppLanguage.tamil);
              },
            ),
            const SizedBox(height: 12),
            _langTile(
              flag: '🇮🇳',
              title: context.tr('lang_tanglish_title'),
              subtitle: context.tr('lang_tanglish_desc'),
              selected: current == AppLanguage.tanglish,
              onTap: () {
                Navigator.pop(ctx);
                _setLanguage(AppLanguage.tanglish);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _langTile({
    required String flag,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5).withValues(alpha: 0.07) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF4F46E5).withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(flag, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: selected ? const Color(0xFF4F46E5) : AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: selected ? const Color(0xFF4338CA) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF4F46E5) : Colors.transparent,
                border: Border.all(
                  color: selected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── VERIFIED & ADMIN LOCKED PROFILE DETAILS MODAL ─────────────────────────
  void _showVerifiedProfileModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(icons.Iconsax.security_safe_copy, color: Color(0xFF0F172A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('profile_admin_locked'),
                          style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: const Color(0xFF059669), letterSpacing: 1.2),
                        ),
                        Text(
                          context.tr('verified_profile_details'),
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.darkText),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF166534)),
                        const SizedBox(width: 4),
                        Text(
                          'LOCKED',
                          style: GoogleFonts.outfit(color: const Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Admin Notice Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF3B82F6), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('profile_locked_desc'),
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: const Color(0xFF475569),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Read-only Details
              _readOnlyField(context.tr('full_name'), _driverName, Icons.person_rounded),
              const SizedBox(height: 12),
              _readOnlyField(context.tr('mobile_number'), _driverPhone.isNotEmpty ? _driverPhone : 'Registered Phone', Icons.phone_rounded),
              const SizedBox(height: 12),
              _readOnlyField(context.tr('vehicle_type'), _vehicleType, Icons.delivery_dining_rounded),
              const SizedBox(height: 12),
              _readOnlyField(context.tr('vehicle_number'), _vehicleNumber, Icons.two_wheeler_rounded),
              const SizedBox(height: 12),
              _readOnlyField(context.tr('upi_id'), _upiId, Icons.account_balance_wallet_rounded),
              const SizedBox(height: 24),

              // Close Button
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  context.tr('close').toUpperCase(),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF64748B), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkText,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 16),
        ],
      ),
    );
  }
}
