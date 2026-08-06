import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
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
    final notif = await Permission.notification.isGranted;
    
    bool sysBattery = await Permission.ignoreBatteryOptimizations.isGranted;
    if (!sysBattery) {
      try {
        const platform = MethodChannel('com.namba.vendor/app');
        final bool nativeIgnored = await platform.invokeMethod('isBatteryOptimizationsIgnored');
        if (nativeIgnored) sysBattery = true;
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final userAllowedBattery = prefs.getBool('user_allowed_battery') ?? false;
    final battery = sysBattery || userAllowedBattery;

    final sysOverlay = await Permission.systemAlertWindow.isGranted;
    final userAllowedOverlay = prefs.getBool('user_allowed_overlay') ?? false;
    final overlay = sysOverlay || userAllowedOverlay;
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
    final double sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Text(
            'System Settings Setup',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E1B4B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ஆர்டர் சவுண்ட் அலர்ட் சரியாக வேலை செய்ய கீழே உள்ள செட்டிங்ஸ்களை ஆன் செய்யவும்:',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
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
                  title: 'Notification Alerts',
                  titleTa: 'நோட்டிபிகேஷன் அலர்ட்',
                  desc: 'To play ringtones & show order popups on screen.',
                  descTa: 'புதிய ஆர்டர்கள் வரும்போது அலர்ட் ஒலி எழுப்ப.',
                  isGranted: _notifGranted,
                  onTap: () async {
                    await Permission.notification.request();
                    _checkPermissions();
                  },
                ),
                _buildPermissionCard(
                  icon: Icons.battery_charging_full_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Background Run (Ignore Battery Optimization)',
                  titleTa: 'பேக்கிரவுண்ட் ரன் பர்மிஷன்',
                  desc: 'Prevents the phone from killing the app in the background.',
                  descTa: 'ஆப் மூடப்பட்டிருக்கும்போதும் புதிய ஆர்டர்களைப் பெற.',
                  isGranted: _batteryGranted,
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('user_allowed_battery', true);
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
                  title: 'Draw Over Other Apps (Overlay Permission)',
                  titleTa: 'டிஸ்ப்ளே ஓவர் அதர் ஆப்ஸ்',
                  desc: 'Allows displaying incoming order screen on top of other apps.',
                  descTa: 'போன் லாக் செய்யப்பட்டிருக்கும்போதும் ஸ்கிரீனை ஆன் செய்ய.',
                  isGranted: _overlayGranted,
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('user_allowed_overlay', true);
                    try {
                      const platform = MethodChannel('com.namba.vendor/app');
                      await platform.invokeMethod('openOverlaySettings');
                    } catch (e) {
                      await Permission.systemAlertWindow.request();
                    }
                    _checkPermissions();
                  },
                ),
                if (Platform.isAndroid && _autoStartAvailable)
                  _buildPermissionCard(
                    icon: Icons.power_settings_new_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Auto-Start manager',
                    titleTa: 'ஆட்டோ-ஸ்டார்ட் பர்மிஷன்',
                    desc: 'Launches order receiver automatically when phone reboots.',
                    descTa: 'போன் ஆஃப் ஆகி ஆன் ஆகும்போது ஆப் தானாகவே வேலை செய்ய துவங்க.',
                    isGranted: false, // Auto-start is third party, we cannot verify programmatically
                    buttonText: 'CONFIGURE',
                    onTap: () async {
                      await getAutoStartPermission();
                    },
                  ),
                _buildPermissionCard(
                  icon: Icons.alarm_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Exact Alarm triggers',
                  titleTa: 'அலாரம் அலர்ட் பர்மிஷன்',
                  desc: 'Ensures notifications are shown at exact time without delay.',
                  descTa: 'ஆர்டர்கள் தாமதமின்றி உடனுக்குடன் வந்து சேர.',
                  isGranted: _exactAlarmGranted,
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
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                'CLOSE / LATER (பிறகு செய்கிறேன்)',
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
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String titleTa,
    required String desc,
    required String descTa,
    required bool isGranted,
    required VoidCallback onTap,
    String? buttonText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGranted ? Colors.green.shade100 : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted ? Colors.green.shade50 : iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? Colors.green : iconColor,
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
                    color: isGranted ? Colors.green.shade800 : const Color(0xFF1E1B4B),
                  ),
                ),
                Text(
                  titleTa,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  descTa,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
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
                backgroundColor: iconColor.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 28,
            ),
        ],
      ),
    );
  }
}
