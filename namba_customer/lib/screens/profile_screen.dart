import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../models/models.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'saved_addresses_screen.dart';
import 'order_history_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import 'customer_support_screen.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final orders = Provider.of<OrderProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<CustomerLanguageProvider>(context);
    final isDark = theme.isDarkMode;

    final deliveredCount = orders.orders.where((o) => o.status == OrderStatus.delivered).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 1. Ultra-Premium Hero Header ──
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)]
                      : const [Color(0xFF1E1B4B), Color(0xFF3730A3), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(isDark ? 0.2 : 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
              child: Column(
                children: [
                  // User Avatar with glowing border and edit badge
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.4), width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: (auth.profileImage.isNotEmpty && auth.profileImage.startsWith('http'))
                              ? Image.network(
                                  auth.profileImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _fallbackAvatar(auth.name),
                                )
                              : _fallbackAvatar(auth.name),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6),
                            ],
                          ),
                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // User Name + Verified Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          auth.name.isNotEmpty ? auth.name : 'Customer',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Phone / Email subtitle
                  Text(
                    auth.email.isNotEmpty ? auth.email : (auth.phone.isNotEmpty ? '+91 ${auth.phone}' : 'Active User'),
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Sleek Metric Badges (Orders, Delivered, Status)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isDark ? 0.08 : 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem('${orders.orders.length}', 'Total Orders'),
                        Container(width: 1, height: 30, color: Colors.white.withOpacity(0.25)),
                        _statItem('$deliveredCount', 'Delivered'),
                        Container(width: 1, height: 30, color: Colors.white.withOpacity(0.25)),
                        _statItem('Active', 'Membership'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 2. Clean Modern Menu Options (NO WALLET) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: ACCOUNT & ORDERS
                  _sectionHeader('ACCOUNT & ORDERS', theme),
                  const SizedBox(height: 10),
                  _buildMenuItem(
                    context,
                    icon: Iconsax.location_copy,
                    iconColor: const Color(0xFF4F46E5),
                    title: lang.translate('saved_address'),
                    subtitle: auth.address.isNotEmpty ? auth.address : 'Manage delivery addresses',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen())),
                    theme: theme,
                  ),
                  const SizedBox(height: 10),
                  _buildMenuItem(
                    context,
                    icon: Iconsax.receipt_item_copy,
                    iconColor: const Color(0xFF0EA5E9),
                    title: lang.translate('order_history'),
                    subtitle: lang.translate('view_past_orders'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
                    theme: theme,
                  ),

                  const SizedBox(height: 24),

                  // Section: APP SETTINGS
                  _sectionHeader('PREFERENCES', theme),
                  const SizedBox(height: 10),

                  // Dark Mode Switch Tile
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.borderCol),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.amber : const Color(0xFF4F46E5)).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            theme.isDarkMode ? Iconsax.moon_copy : Iconsax.sun_1_copy,
                            color: isDark ? Colors.amber : const Color(0xFF4F46E5),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.translate('dark_mode'),
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: theme.textPrimary,
                                ),
                              ),
                              Text(
                                isDark ? 'Dark theme active' : 'Light theme active',
                                style: GoogleFonts.outfit(fontSize: 12, color: theme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: theme.isDarkMode,
                          onChanged: (val) => theme.toggleTheme(val),
                          activeColor: const Color(0xFF4F46E5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Notification Preferences & Controls Tile
                  _NotificationPreferenceCard(theme: theme, lang: lang),

                  const SizedBox(height: 10),

                  // Language Tile
                  _buildMenuItem(
                    context,
                    icon: Iconsax.global_copy,
                    iconColor: const Color(0xFF10B981),
                    title: lang.translate('language'),
                    subtitle: lang.languageName,
                    onTap: () => CustomerLanguageProvider.showLanguageModal(context),
                    theme: theme,
                  ),

                  const SizedBox(height: 24),

                  // Section: SUPPORT & ASSISTANCE
                  _sectionHeader('SUPPORT & HELP', theme),
                  const SizedBox(height: 10),
                  _buildMenuItem(
                    context,
                    icon: Iconsax.message_question_copy,
                    iconColor: const Color(0xFFF59E0B),
                    title: lang.translate('help_support'),
                    subtitle: lang.translate('help_desc'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerSupportScreen())),
                    theme: theme,
                  ),

                  const SizedBox(height: 24),

                  // Logout Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3B1219).withOpacity(0.6) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFFEF4444).withOpacity(0.3) : const Color(0xFFFEE2E2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Iconsax.logout_copy, color: Colors.redAccent, size: 22),
                      ),
                      title: Text(
                        lang.translate('logout'),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: Colors.redAccent,
                        ),
                      ),
                      subtitle: Text(
                        lang.translate('logout_desc'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.redAccent.withOpacity(0.8),
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.redAccent),
                      onTap: () => _confirmLogout(context, auth),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    return Container(
      color: const Color(0xFF312E81),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.outfit(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: theme.textSecondary.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeProvider theme,
  }) {
    final isDark = theme.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            color: theme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(fontSize: 12, color: theme.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.textSecondary.withOpacity(0.6)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Confirm Logout?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: theme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to sign out from your account?',
          style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: theme.textSecondary, fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              auth.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationPreferenceCard extends StatefulWidget {
  final ThemeProvider theme;
  final CustomerLanguageProvider lang;

  const _NotificationPreferenceCard({required this.theme, required this.lang});

  @override
  State<_NotificationPreferenceCard> createState() => _NotificationPreferenceCardState();
}

class _NotificationPreferenceCardState extends State<_NotificationPreferenceCard> with WidgetsBindingObserver {
  bool _notificationsEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final enabled = await NotificationService().areNotificationsEnabled();
    if (mounted) {
      setState(() => _notificationsEnabled = enabled);
    }
  }

  Future<void> _toggle(bool val) async {
    setState(() => _isLoading = true);
    if (val) {
      final granted = await NotificationService().requestNotificationPermission();
      if (!granted) {
        await NotificationService().openNotificationSettings();
      }
    } else {
      await NotificationService().openNotificationSettings();
    }
    await _checkStatus();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.theme.isDarkMode;
    final theme = widget.theme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _notificationsEnabled 
              ? theme.borderCol 
              : const Color(0xFFEF4444).withValues(alpha: 0.4),
          width: _notificationsEnabled ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _notificationsEnabled
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (_notificationsEnabled ? const Color(0xFF10B981) : const Color(0xFFDC2626)).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  _notificationsEnabled ? Iconsax.notification_copy : Icons.notifications_off_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order & Bill Alerts (அறிவிப்புகள்)',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _notificationsEnabled
                          ? '🟢 Active & Allowed / இயங்குகிறது'
                          : '🔴 Blocked / தட்டினால் ஆன் செய்யலாம்',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _notificationsEnabled ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _notificationsEnabled,
                onChanged: _isLoading ? null : _toggle,
                activeColor: const Color(0xFF10B981),
              ),
            ],
          ),
          if (!_notificationsEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3B1219) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ நோட்டிஃபிகேஷன் முடக்கப்பட்டுள்ளது! கடை அனுப்பும் பில் விலைப் பட்டியல் மற்றும் டெலிவரி தகவல்களை உடனுக்குடன் பெற அறிவிப்பை ஆன் செய்யவும்.',
                    style: GoogleFonts.outfit(fontSize: 11.5, color: isDark ? Colors.white : const Color(0xFF991B1B), height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _toggle(true),
                      icon: const Icon(Icons.notifications_active_rounded, size: 16),
                      label: Text(
                        'TURN ON NOTIFICATIONS / ஆன் செய்க 🔔',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
