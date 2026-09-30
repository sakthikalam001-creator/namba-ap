import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';

class PermissionsWizardSheet extends StatefulWidget {
  const PermissionsWizardSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PermissionsWizardSheet(),
    );
  }

  @override
  State<PermissionsWizardSheet> createState() => _PermissionsWizardSheetState();
}

class _PermissionsWizardSheetState extends State<PermissionsWizardSheet> with WidgetsBindingObserver {
  bool _notifGranted = false;
  bool _batteryGranted = false;
  bool _overlayGranted = false;
  bool _autoStartAvailable = false;
  bool _exactAlarmGranted = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (mounted) _checkPermissions();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions(); // Re-check status when user returns to app
    }
  }

  Future<void> _checkPermissions() async {
    bool notif = await Permission.notification.isGranted;
    try {
      const platform = MethodChannel('com.namba.vendor/app');
      final bool? nativeNotif = await platform.invokeMethod<bool>('areNotificationsEnabled');
      if (nativeNotif != null) notif = nativeNotif;
    } catch (_) {}

    bool battery = false;
    try {
      const platform = MethodChannel('com.namba.vendor/app');
      final bool? nativeBattery = await platform.invokeMethod<bool>('isBatteryOptimizationsIgnored');
      if (nativeBattery != null) {
        battery = nativeBattery;
      } else {
        battery = await Permission.ignoreBatteryOptimizations.isGranted;
      }
    } catch (_) {
      battery = await Permission.ignoreBatteryOptimizations.isGranted;
    }

    bool overlay = false;
    try {
      const platform = MethodChannel('com.namba.vendor/app');
      final bool? nativeOverlay = await platform.invokeMethod<bool>('canDrawOverlays');
      if (nativeOverlay != null) overlay = nativeOverlay;
    } catch (_) {
      overlay = await Permission.systemAlertWindow.isGranted;
    }
    final exactAlarm = await Permission.scheduleExactAlarm.isGranted;
    final autoStart = await isAutoStartAvailable ?? false;

    if (mounted) {
      setState(() {
        _notifGranted = notif;
        _batteryGranted = battery;
        _overlayGranted = overlay;
        _exactAlarmGranted = exactAlarm;
        _autoStartAvailable = autoStart;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final double sheetHeight = MediaQuery.of(context).size.height * 0.85;
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: isDark ? Border.all(color: const Color(0xFF1E293B), width: 1.5) : null,
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Drag handle
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Text(
            lang.text(en: 'System Settings Setup', ta: 'கணினி அமைப்புகள்', tanglish: 'System Settings Setup'),
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang.text(
              en: 'Enable the settings below for order sound alerts to work properly:',
              ta: 'ஆர்டர் ஒலி அலர்ட் சரியாக வேலை செய்ய கீழே உள்ள அமைப்புகளை ஆன் செய்யவும்:',
              tanglish: 'Order sound alert crt-aa work aaga keezha ulla settings-a on pannunga:',
            ),
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // Permissions List
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildPermissionCard(
                  icon: Icons.notifications_active_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  title: lang.text(en: 'Notification Alerts', ta: 'அறிவிப்பு அலர்ட்', tanglish: 'Notification Alerts'),
                  desc: lang.text(
                    en: 'To play ringtones & show order popups on screen.',
                    ta: 'புதிய ஆர்டர்கள் வரும்போது அலர்ட் ஒலி எழுப்ப.',
                    tanglish: 'New orders varum bothu sound ring aaga.',
                  ),
                  isGranted: _notifGranted,
                  isDark: isDark,
                  onTap: () async {
                    await Permission.notification.request();
                    _checkPermissions();
                  },
                ),
                _buildPermissionCard(
                  icon: Icons.battery_charging_full_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: lang.text(
                    en: 'Background Run (Ignore Battery Optimization)',
                    ta: 'பின்னணி இயக்க அனுமதி',
                    tanglish: 'Background Run Permission',
                  ),
                  desc: lang.text(
                    en: 'Prevents the phone from killing the app in the background.',
                    ta: 'ஆப் மூடப்பட்டிருக்கும்போதும் புதிய ஆர்டர்களைப் பெற.',
                    tanglish: 'App close aana kooda background-la run aagurathukku.',
                  ),
                  isGranted: _batteryGranted,
                  isDark: isDark,
                  onTap: () async {
                    try {
                      const platform = MethodChannel('com.namba.vendor/app');
                      await platform.invokeMethod('openBatterySettings');
                    } catch (e) {
                      await Permission.ignoreBatteryOptimizations.request();
                    }
                    _checkPermissions();
                  },
                ),
                _buildPermissionCard(
                  icon: Icons.picture_in_picture_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: lang.text(
                    en: 'Display Over Other Apps',
                    ta: 'திரையின் மேல் காட்டும் அனுமதி',
                    tanglish: 'Display Over Other Apps',
                  ),
                  desc: lang.text(
                    en: 'Allows displaying incoming order screen on top of other apps.',
                    ta: 'போன் லாக் செய்யப்பட்டிருக்கும்போதும் திரையை ஆன் செய்ய.',
                    tanglish: 'Phone lock-la irundhalum order screen varathukku.',
                  ),
                  isGranted: _overlayGranted,
                  isDark: isDark,
                  onTap: () async {
                    try {
                      const platform = MethodChannel('com.namba.vendor/app');
                      await platform.invokeMethod('openOverlaySettings');
                    } catch (e) {
                      await Permission.systemAlertWindow.request();
                    }
                    _checkPermissions();
                  },
                ),
                if (!_overlayGranted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lang.text(
                                  en: 'Switch not turning on? (Restricted Setting)',
                                  ta: 'சுவிட்ச் ஆன் ஆகவில்லையா?',
                                  tanglish: 'Switch on aagalaiya? (Restricted Setting)',
                                ),
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lang.text(
                            en: 'On Android 13 / 14 / 15 phones, if it says "App was denied access":\n'
                                '1. Tap "Unlock Restricted Settings" below.\n'
                                '2. Tap 3 dots (⋮) in the top-right corner.\n'
                                '3. Tap "Allow restricted settings", then return here and enable.',
                            ta: 'ஆண்ட்ராய்டு 13 / 14 / 15 போன்களில் "App was denied access" என்று வந்தால்:\n'
                                '1. கீழே உள்ள "அனுமதியைத் திறக்க" பட்டனை அழுத்தவும்.\n'
                                '2. மேல் வலது மூலையில் உள்ள 3 புள்ளிகளை (⋮) தட்டவும்.\n'
                                '3. "Allow restricted settings" கொடுத்துவிட்டு மீண்டும் இங்கு வந்து ஆன் செய்யவும்.',
                            tanglish: 'Android 13 / 14 / 15 phones-la "App was denied access" nu vandha:\n'
                                '1. Keezha ulla "Unlock Restricted Settings" click pannunga.\n'
                                '2. Top right 3 dots (⋮) click pannunga.\n'
                                '3. "Allow restricted settings" kuduthutu marubadiyum inga vandhu on pannunga.',
                          ),
                          style: GoogleFonts.outfit(fontSize: 12, height: 1.4, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF78350F)),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                const platform = MethodChannel('com.namba.vendor/app');
                                await platform.invokeMethod('openAppDetailsSettings');
                              } catch (_) {
                                await openAppSettings();
                              }
                            },
                            icon: const Icon(Icons.lock_open_rounded, size: 16, color: Colors.white),
                            label: Text(
                              lang.text(
                                en: 'Unlock Restricted Settings (3-Dots Menu)',
                                ta: 'அனுமதியைத் திறக்கவும் (3 புள்ளி மெனு)',
                                tanglish: 'Unlock Restricted Settings (3-Dots Menu)',
                              ),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (Platform.isAndroid && _autoStartAvailable)
                  _buildPermissionCard(
                    icon: Icons.power_settings_new_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: lang.text(en: 'Auto-Start Manager', ta: 'ஆட்டோ-ஸ்டார்ட் அனுமதி', tanglish: 'Auto-Start Manager'),
                    desc: lang.text(
                      en: 'Launches order receiver automatically when phone reboots.',
                      ta: 'போன் ரீஸ்டார்ட் ஆகும் போது ஆப் தானாகவே வேலை செய்ய துவங்க.',
                      tanglish: 'Phone reboot aagum bothu app thaana run aaga.',
                    ),
                    isGranted: false,
                    isDark: isDark,
                    buttonText: lang.text(en: 'CONFIGURE', ta: 'அமைக்கவும்', tanglish: 'CONFIGURE'),
                    onTap: () async {
                      await getAutoStartPermission();
                    },
                  ),
                _buildPermissionCard(
                  icon: Icons.alarm_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: lang.text(en: 'Exact Alarm Triggers', ta: 'அலாரம் அலர்ட் அனுமதி', tanglish: 'Exact Alarm Triggers'),
                  desc: lang.text(
                    en: 'Ensures notifications are shown at exact time without delay.',
                    ta: 'ஆர்டர்கள் தாமதமின்றி உடனுக்குடன் வந்து சேர.',
                    tanglish: 'Orders delay illama crt time-kku vara.',
                  ),
                  isGranted: _exactAlarmGranted,
                  isDark: isDark,
                  onTap: () async {
                    await Permission.scheduleExactAlarm.request();
                    _checkPermissions();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Action Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('setup_order_alerts_completed', true);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                lang.text(en: 'CLOSE', ta: 'பிறகு செய்கிறேன்', tanglish: 'LATER'),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required bool isGranted,
    required bool isDark,
    required VoidCallback onTap,
    String? buttonText,
  }) {
    Color cardBg;
    Color borderColor;
    if (isGranted) {
      cardBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5);
      borderColor = const Color(0xFF10B981);
    } else {
      cardBg = isDark ? const Color(0xFF1E293B) : Colors.grey.shade50;
      borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: isGranted ? 1.8 : 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted ? const Color(0xFF10B981).withValues(alpha: 0.2) : iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? const Color(0xFF10B981) : iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isGranted 
                        ? const Color(0xFF34D399) 
                        : (isDark ? Colors.white : const Color(0xFF1E1B4B)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: isGranted 
                        ? const Color(0xFFA7F3D0) 
                        : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action Button / Status Icon
          if (!isGranted)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: iconColor.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                buttonText ?? 'ENABLE',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 4),
                  Text(
                    'ALLOWED ✓',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
