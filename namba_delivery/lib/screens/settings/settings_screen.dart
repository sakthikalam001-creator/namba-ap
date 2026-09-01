import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';
import '../rider_permissions_wizard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  String _language = 'English';
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
    final savedLang = prefs.getString('app_language') ?? 'English';
    final savedVehicle = prefs.getString('driver_vehicle_type') ?? 'Bike';
    final savedVehNum = prefs.getString('driver_vehicle_number') ?? 'TN 01 AB 1234';
    final savedUpi = prefs.getString('driver_upi_id') ?? 'partner@okaxis';

    if (mounted) {
      setState(() {
        _notifications = savedNotifs;
        _language = savedLang;
        _driverName = name;
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

  Future<void> _setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
    setState(() => _language = lang);
    HapticFeedback.mediumImpact();

    if (mounted) {
      String msg = 'Language updated to $lang';
      if (lang == 'Tamil') msg = 'மொழி தமிழாக மாற்றப்பட்டது (Tamil)';
      if (lang == 'Tanglish') msg = 'App language Tanglish-ku maathiyachu!';

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
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text(
          'APP CONFIGURATION',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5, color: AppTheme.darkText),
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
            _buildSettingsSection('COMMUNICATION', [
              _toggleItem(
                icons.Iconsax.notification_copy,
                'Order Notifications',
                _notifications,
                _updateNotifications,
              ),
              _languageItem(
                icons.Iconsax.translate_copy,
                'App Language',
                _language,
                () => _showLanguagePicker(),
              ),
            ]),
            const SizedBox(height: 28),
            _buildSettingsSection('ACCOUNT & SECURITY', [
              _menuItem(
                icons.Iconsax.shield_tick_copy,
                'Rider Setup & Permissions',
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
                icons.Iconsax.user_edit_copy,
                'Edit Profile',
                () => _showEditProfileModal(),
                color: AppTheme.primaryOrange,
              ),
              _menuItem(
                icons.Iconsax.key_copy,
                'Privacy Center',
                () => _showPrivacyCenterModal(),
                color: const Color(0xFF3B82F6),
              ),
              _menuItem(
                icons.Iconsax.security_safe_copy,
                'Terms of Service',
                () => _showTermsModal(),
                color: const Color(0xFF8B5CF6),
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
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECT APP LANGUAGE',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 1.2),
                    ),
                    Text(
                      'Choose your preferred display language',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkText),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _langTile(
              'ENGLISH',
              'English (Global / Standard)',
              'Default system interface & English voice dispatch',
              _language == 'English',
              () {
                Navigator.pop(ctx);
                _setLanguage('English');
              },
            ),
            const SizedBox(height: 12),
            _langTile(
              'TAMIL (தமிழ்)',
              'தமிழ்நாடு (தூய தமிழ்)',
              'ஆர்டர்கள், சம்பள விவரங்கள் மற்றும் ஆப் அறிவிப்புகள்',
              _language == 'Tamil',
              () {
                Navigator.pop(ctx);
                _setLanguage('Tamil');
              },
            ),
            const SizedBox(height: 12),
            _langTile(
              'TANGLISH (தங்கிலீஷ்)',
              'Tanglish (Tamil in English text)',
              'Easy Tanglish interface: "Orders check pannunga, Payout status"',
              _language == 'Tanglish',
              () {
                Navigator.pop(ctx);
                _setLanguage('Tanglish');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _langTile(String label, String region, String subtitle, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: selected ? const Color(0xFF4F46E5) : AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• $region',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: selected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF4F46E5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  // ── EDIT PROFILE MODAL ───────────────────────────────────────────────────
  void _showEditProfileModal() {
    final nameCtrl = TextEditingController(text: _driverName);
    final phoneCtrl = TextEditingController(text: _driverPhone);
    final vehNumCtrl = TextEditingController(text: _vehicleNumber);
    final upiCtrl = TextEditingController(text: _upiId);
    String selectedVeh = _vehicleType;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(icons.Iconsax.user_edit_copy, color: AppTheme.primaryOrange, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EDIT RIDER PROFILE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 1.2)),
                        Text('Update personal & vehicle info', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkText)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Full Name
                _buildTextField('Full Name (பெயர்)', nameCtrl, Icons.person_outline_rounded),
                const SizedBox(height: 16),

                // Mobile Phone
                _buildTextField('Registered Mobile Number', phoneCtrl, Icons.phone_outlined, readOnly: true),
                const SizedBox(height: 16),

                // Vehicle Type selector
                Text('Vehicle Type', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
                const SizedBox(height: 8),
                Row(
                  children: ['Bike', 'Scooter', 'EV Bike'].map((type) {
                    final isSel = selectedVeh == type;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedVeh = type),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            type,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                              fontSize: 12.5,
                              color: isSel ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Vehicle Number
                _buildTextField('Vehicle Number Plate (e.g. TN 01 AB 1234)', vehNumCtrl, Icons.two_wheeler_rounded),
                const SizedBox(height: 16),

                // UPI ID
                _buildTextField('Payout UPI ID (e.g. 9876543210@upi)', upiCtrl, Icons.account_balance_wallet_outlined),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () async {
                    final newName = nameCtrl.text.trim();
                    final newVehNum = vehNumCtrl.text.trim();
                    final newUpi = upiCtrl.text.trim();

                    final prefs = await SharedPreferences.getInstance();
                    if (newName.isNotEmpty) {
                      await prefs.setString('driver_name', newName);
                    }
                    await prefs.setString('driver_vehicle_type', selectedVeh);
                    if (newVehNum.isNotEmpty) {
                      await prefs.setString('driver_vehicle_number', newVehNum);
                    }
                    if (newUpi.isNotEmpty) {
                      await prefs.setString('driver_upi_id', newUpi);
                    }

                    if (mounted) {
                      setState(() {
                        if (newName.isNotEmpty) _driverName = newName;
                        _vehicleType = selectedVeh;
                        if (newVehNum.isNotEmpty) _vehicleNumber = newVehNum;
                        if (newUpi.isNotEmpty) _upiId = newUpi;
                      });
                    }

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    HapticFeedback.mediumImpact();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text('Profile details updated successfully!', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text('SAVE PROFILE CHANGES', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: ctrl,
            readOnly: readOnly,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: readOnly ? const Color(0xFF94A3B8) : AppTheme.darkText),
            decoration: InputDecoration(
              icon: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ── PRIVACY CENTER MODAL ─────────────────────────────────────────────────
  void _showPrivacyCenterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(icons.Iconsax.key_copy, color: Color(0xFF3B82F6), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PRIVACY & DATA PROTECTION', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 1.2)),
                      Text('Security & Permissions Center', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkText)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _privacyTile(
                Icons.location_on_rounded,
                'Real-Time GPS Tracking',
                'Your location is collected in real-time only when your status is ONLINE to calculate accurate trip distance (₹7/KM) and assign nearby store orders.',
                const Color(0xFF10B981),
              ),
              const SizedBox(height: 12),
              _privacyTile(
                Icons.mic_rounded,
                'Voice Dispatch & Mic',
                'Microphone is used strictly on-demand for Voice Dispatch, Hands-Free navigation and emergency SOS recording. No background audio is saved.',
                const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 12),
              _privacyTile(
                Icons.lock_rounded,
                'TLS 1.3 End-to-End Encryption',
                'All document uploads (Aadhar, License, Bank Details) are securely encrypted and stored with restricted Admin access only.',
                const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await openAppSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                label: Text('OPEN SYSTEM APP PERMISSIONS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.5)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('App cache and temporary session tokens cleared.', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFF334155),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('CLEAR TEMPORARY CACHE', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _privacyTile(IconData icon, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.darkText)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.35, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TERMS OF SERVICE MODAL ──────────────────────────────────────────────
  void _showTermsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(icons.Iconsax.security_safe_copy, color: Color(0xFF8B5CF6), size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NAMBA FLEET AGREEMENT', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 1.2)),
                    Text('Terms of Service & Policies', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkText)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _termItem('1. Payout & Settlements', 'Weekly earnings are automatically settled every Tuesday by 8:00 PM to the registered bank account/UPI ID. Distance pay is based on base rate ₹7/KM.'),
                    _termItem('2. Delivery Partner Code of Conduct', 'Partners must handle food and package parcels with utmost care, maintain hygiene, wear helmets while driving, and follow traffic laws.'),
                    _termItem('3. Order Fulfillment & Cancellations', 'Once an assignment is accepted, partner is expected to complete pickup and drop-off in a timely manner. Repeated cancellations without valid reasons may affect tier rankings.'),
                    _termItem('4. Customer Privacy & Cash On Delivery', 'Customer phone numbers and addresses are strictly for active deliveries. Cash On Delivery (COD) collected must be reconciled seamlessly.'),
                    _termItem('5. 24/7 Super Admin & SOS Support', 'For roadside breakdowns, customer issues, or emergencies, partners can connect instantly via Live Admin Chat or SOS emergency helpline.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('I UNDERSTAND & AGREE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _termItem(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
          const SizedBox(height: 6),
          Text(content, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B), height: 1.4, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
