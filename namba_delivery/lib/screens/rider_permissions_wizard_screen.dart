import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class RiderPermissionsWizardScreen extends StatefulWidget {
  final Widget nextScreen;

  const RiderPermissionsWizardScreen({super.key, required this.nextScreen});

  static Future<bool> shouldShowWizard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wizardCompleted = prefs.getBool('wizard_completed') ?? false;

      final notif = await Permission.notification.isGranted;
      final overlay = await Permission.systemAlertWindow.isGranted;
      final sysBattery = await Permission.ignoreBatteryOptimizations.isGranted;
      final loc = await Geolocator.checkPermission();

      final locGranted = (loc == LocationPermission.always || loc == LocationPermission.whileInUse);

      // Return true if wizard hasn't been completed on first install OR any essential permission is missing
      return !wizardCompleted || !notif || !overlay || !sysBattery || !locGranted;
    } catch (_) {
      return true;
    }
  }

  @override
  State<RiderPermissionsWizardScreen> createState() => _RiderPermissionsWizardScreenState();
}

class _RiderPermissionsWizardScreenState extends State<RiderPermissionsWizardScreen> with WidgetsBindingObserver {
  bool _notifGranted = false;
  bool _locGranted = false;
  bool _overlayGranted = false;
  bool _batteryGranted = false;
  bool _autoStartDone = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions(); // Automatically re-check when returning from Settings screen
    }
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _isChecking = true);

    try {
      // 1. Notification
      final notif = await Permission.notification.isGranted;

      // 2. Location
      final locStatus = await Geolocator.checkPermission();
      final loc = (locStatus == LocationPermission.always || locStatus == LocationPermission.whileInUse);

      // 3. Overlay (Display over other apps)
      bool overlay = await Permission.systemAlertWindow.isGranted;

      // 4. Battery Optimization
      bool sysBattery = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      final prefs = await SharedPreferences.getInstance();
      final userAllowedBattery = prefs.getBool('user_allowed_battery') ?? false;
      final battery = sysBattery || userAllowedBattery;

      // 5. AutoStart / Background Settings
      final autoStartDone = prefs.getBool('user_configured_autostart') ?? false;

      if (mounted) {
        setState(() {
          _notifGranted = notif;
          _locGranted = loc;
          _overlayGranted = overlay;
          _batteryGranted = battery;
          _autoStartDone = autoStartDone;
          _isChecking = false;
        });
      }
    } catch (e) {
      debugPrint('[Wizard] Check permissions error: $e');
      if (mounted) setState(() => _isChecking = false);
    }
  }

  bool get _allEssentialGranted => _notifGranted && _locGranted && _overlayGranted && _batteryGranted;

  static const _settingsChannel = MethodChannel('com.example.namaba_delivery/settings');

  Future<void> _openDirectOverlaySettings() async {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Display Over Other Apps அமைப்புகளுக்குச் செல்கிறது...',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          backgroundColor: AppTheme.primaryOrange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    try {
      if (Platform.isAndroid) {
        await _settingsChannel.invokeMethod('openOverlaySettings');
      } else {
        await openAppSettings();
      }
    } catch (_) {
      await openAppSettings();
    }
  }

  Future<void> _openDirectNotificationSettings() async {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notifications அமைப்புகளுக்குச் செல்கிறது...',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          backgroundColor: AppTheme.primaryOrange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    try {
      if (Platform.isAndroid) {
        await _settingsChannel.invokeMethod('openNotificationSettings');
      } else {
        await openAppSettings();
      }
    } catch (_) {
      await openAppSettings();
    }
  }

  Future<void> _openDirectBatterySettings() async {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Battery Optimization அமைப்புகளுக்குச் செல்கிறது...',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          backgroundColor: AppTheme.primaryOrange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    try {
      if (Platform.isAndroid) {
        await _settingsChannel.invokeMethod('openBatterySettings');
      } else {
        await openAppSettings();
      }
    } catch (_) {
      await openAppSettings();
    }
  }

  Future<void> _openRideAppSettings(String settingName) async {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ride App ($settingName) அமைப்புகளுக்குச் செல்கிறது...',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          backgroundColor: AppTheme.primaryOrange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    await openAppSettings();
  }

  void _proceedToApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wizard_completed', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.nextScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = AppTheme.primaryOrange;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Sleek dark theme
      body: SafeArea(
        child: Column(
          children: [
            // TOP HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.security_rounded, color: themeColor, size: 32),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ரைடர் ஆப் மொபைல் அமைப்புகள்',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rider App Setup & Permission Wizard',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      'மொபைல் லாக் அல்லது ஸ்கிரீன் ஆப்-ல் இருக்கும் போது ஆர்டர் நோட்டிபிகேஷன்கள் உடனுக்குடன் வர கீழே உள்ள அமைப்புகளை ஆன் செய்யவும்.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        height: 1.35,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // STEP BY STEP PERMISSIONS LIST
            Expanded(
              child: _isChecking
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // STEP 1: NOTIFICATIONS
                        _buildStepCard(
                          stepNum: '1',
                          title: 'Notifications & Order Sound Alert',
                          subtitle: 'அறிவிப்புகள் மற்றும் அலாரம் சவுண்ட் பெற அனுமதிக்கவும்.',
                          icon: Icons.notifications_active_rounded,
                          isGranted: _notifGranted,
                          buttonLabel: 'OPEN SETTINGS',
                          onTap: () async {
                            final status = await Permission.notification.request();
                            if (!status.isGranted) {
                              await _openDirectNotificationSettings();
                            }
                            _checkAllPermissions();
                          },
                        ),
                        const SizedBox(height: 12),

                        // STEP 2: LOCATION
                        _buildStepCard(
                          stepNum: '2',
                          title: 'Location (Always In Background)',
                          subtitle: 'ரைடர் இருப்பிடத்தை துல்லியமாக கண்காணிக்க அனுமதிக்கவும்.',
                          icon: Icons.location_on_rounded,
                          isGranted: _locGranted,
                          buttonLabel: 'OPEN SETTINGS',
                          onTap: () async {
                            final status = await Permission.locationAlways.request();
                            if (!status.isGranted) {
                              await _openRideAppSettings('Location / இருப்பிடம்');
                            }
                            _checkAllPermissions();
                          },
                        ),
                        const SizedBox(height: 12),

                        // STEP 3: DISPLAY OVER OTHER APPS (SYSTEM ALERT WINDOW)
                        _buildStepCard(
                          stepNum: '3',
                          title: 'Display Over Other Apps (Overlay)',
                          subtitle: 'திரையின் மேல் தோன்றும் அனுமதி (Lock screen-ல் Popup வர).',
                          icon: Icons.layers_rounded,
                          isGranted: _overlayGranted,
                          buttonLabel: 'OPEN SETTINGS',
                          onTap: () async {
                            await _openDirectOverlaySettings();
                            _checkAllPermissions();
                          },
                        ),
                        const SizedBox(height: 12),

                        // STEP 4: IGNORE BATTERY OPTIMIZATION
                        _buildStepCard(
                          stepNum: '4',
                          title: 'Battery Optimization (Dont Kill App)',
                          subtitle: 'பேட்டரி சேமிப்பால் ஆப் பின்னணியில் மூடாமல் இருக்க ஆன் செய்யவும்.',
                          icon: Icons.battery_charging_full_rounded,
                          isGranted: _batteryGranted,
                          buttonLabel: 'OPEN SETTINGS',
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('user_allowed_battery', true);
                            await _openDirectBatterySettings();
                          },
                        ),
                        const SizedBox(height: 12),

                        // STEP 5: AUTO START / BACKGROUND APP MANAGEMENT (ALL MOBILE BRANDS)
                        _buildStepCard(
                          stepNum: '5',
                          title: 'Auto-Start & Background Execution',
                          subtitle: 'மொபைல் ரீஸ்டார்ட் ஆனாலும் ஆப் தானாகவே இயங்க அனுமதி (POCO / Xiaomi / Vivo / Samsung).',
                          icon: Icons.autorenew_rounded,
                          isGranted: _autoStartDone,
                          buttonLabel: 'OPEN SETTINGS',
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('user_configured_autostart', true);
                            try {
                              final isAvailable = await isAutoStartAvailable ?? false;
                              if (isAvailable) {
                                await getAutoStartPermission();
                              } else {
                                await _openRideAppSettings('Auto Start / பின்னணி இயக்கம்');
                              }
                            } catch (_) {
                              await _openRideAppSettings('Auto Start / பின்னணி இயக்கம்');
                            }
                            _checkAllPermissions();
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
            ),

            // BOTTOM ACTION BUTTON
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _proceedToApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allEssentialGranted ? themeColor : const Color(0xFF334155),
                    elevation: _allEssentialGranted ? 4 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _allEssentialGranted
                              ? 'அனைத்தும் ஆன் செய்யப்பட்டது • CONTINUE TO APP'
                              : 'தொடர்ந்து செல்லவும் • PROCEED TO APP',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNum,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    final statusColor = isGranted ? const Color(0xFF00C853) : const Color(0xFFFF9800);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? const Color(0xFF00C853).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
          width: isGranted ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // STEP BADGE / STATUS ICON
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isGranted ? Icons.check_circle_rounded : icon,
                color: statusColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // TITLE & SUBTITLE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP $stepNum: $title',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isGranted ? const Color(0xFF00C853) : Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    color: Colors.grey.shade400,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ACTION BUTTON OR DONE BADGE
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isGranted ? const Color(0xFF00C853).withValues(alpha: 0.2) : const Color(0xFF00C853),
                foregroundColor: isGranted ? const Color(0xFF00C853) : Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: isGranted ? 0 : 2,
              ),
              child: Text(
                isGranted ? '✓ DONE' : buttonLabel,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
