import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiderPermissionsWizardScreen extends StatefulWidget {
  final Widget nextScreen;

  const RiderPermissionsWizardScreen({super.key, required this.nextScreen});

  static Future<bool> shouldShowWizard() async {
    try {
      final notif = await Permission.notification.isGranted;
      final overlay = await Permission.systemAlertWindow.isGranted;
      final sysBattery = await Permission.ignoreBatteryOptimizations.isGranted;
      final loc = await Geolocator.checkPermission();

      final locGranted = (loc == LocationPermission.always || loc == LocationPermission.whileInUse);

      // Return true if any essential permission is missing
      return !notif || !overlay || !sysBattery || !locGranted;
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
  bool _autoStartAvailable = false;
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
      if (!sysBattery) {
        sysBattery = await Permission.ignoreBatteryOptimizations.isGranted;
      }
      final prefs = await SharedPreferences.getInstance();
      final userAllowedBattery = prefs.getBool('user_allowed_battery') ?? false;
      final battery = sysBattery || userAllowedBattery;

      // 5. AutoStart (Xiaomi / POCO / Vivo / Oppo)
      bool autoStartAvailable = false;
      try {
        autoStartAvailable = await isAutoStartAvailable ?? false;
      } catch (_) {}
      final autoStartDone = prefs.getBool('user_configured_autostart') ?? false;

      if (mounted) {
        setState(() {
          _notifGranted = notif;
          _locGranted = loc;
          _overlayGranted = overlay;
          _batteryGranted = battery;
          _autoStartAvailable = autoStartAvailable;
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

  void _proceedToApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF00C853);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Sleek dark theme
      body: SafeArea(
        child: Column(
          children: [
            // TOP HEADER
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.security_rounded, color: themeColor, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ரைடர் ஆப் மொபைல் அமைப்புகள்',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rider App Setup & Permission Wizard',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      'மொபைல் லாக் அல்லது ஸ்கிரீன் ஆப்-ல் இருக்கும் போது ஆர்டர் நோட்டிபிகேஷன்கள் உடனுக்குடன் வர கீழே உள்ள அமைப்புகளை ஆன் செய்யவும்.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        height: 1.4,
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // STEP 1: NOTIFICATIONS
                        _buildStepCard(
                          stepNum: '1',
                          title: 'Notifications & Order Sound Alert',
                          subtitle: 'அறிவிப்புகள் மற்றும் அலாரம் சவுண்ட் பெற அனுமதிக்கவும்.',
                          icon: Icons.notifications_active_rounded,
                          isGranted: _notifGranted,
                          buttonLabel: 'ALLOW SOUND',
                          onTap: () async {
                            await Permission.notification.request();
                            _checkAllPermissions();
                          },
                        ),
                        const SizedBox(height: 14),

                        // STEP 2: LOCATION
                        _buildStepCard(
                          stepNum: '2',
                          title: 'Location (Always In Background)',
                          subtitle: 'ரைடர் இருப்பிடத்தை துல்லியமாக கண்காணிக்க அனுமதிக்கவும்.',
                          icon: Icons.location_on_rounded,
                          isGranted: _locGranted,
                          buttonLabel: 'ALLOW LOCATION',
                          onTap: () async {
                            await Geolocator.requestPermission();
                            await Permission.locationAlways.request();
                            _checkAllPermissions();
                          },
                        ),
                        const SizedBox(height: 14),

                        // STEP 3: DISPLAY OVER OTHER APPS (SYSTEM ALERT WINDOW)
                        _buildStepCard(
                          stepNum: '3',
                          title: 'Display Over Other Apps (Overlay)',
                          subtitle: 'திரையின் மேல் தோன்றும் அனுமதி (Lock screen-ல் Popup வர).',
                          icon: Icons.layers_rounded,
                          isGranted: _overlayGranted,
                          buttonLabel: 'TURN ON SETTING',
                          onTap: () async {
                            await Permission.systemAlertWindow.request();
                            _checkAllPermissions();
                          },
                        ),
                        const SizedBox(height: 14),

                        // STEP 4: IGNORE BATTERY OPTIMIZATION
                        _buildStepCard(
                          stepNum: '4',
                          title: 'Battery Optimization (Dont Kill App)',
                          subtitle: 'பேட்டரி சேமிப்பால் ஆப் பின்னணியில் மூடாமல் இருக்க ஆன் செய்யவும்.',
                          icon: Icons.battery_charging_full_rounded,
                          isGranted: _batteryGranted,
                          buttonLabel: 'ALLOW BACKGROUND',
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('user_allowed_battery', true);
                            await FlutterForegroundTask.requestIgnoreBatteryOptimization();
                            _checkAllPermissions();
                          },
                        ),
                        const SizedBox(height: 14),

                        // STEP 5: AUTO START PERMISSION (IF AVAILABLE ON VIVO/POCO/XIAOMI/OPPO)
                        if (_autoStartAvailable) ...[
                          _buildStepCard(
                            stepNum: '5',
                            title: 'Auto-Start Permission (Xiaomi/POCO/Vivo)',
                            subtitle: 'மொபைல் ரீஸ்டார்ட் ஆனாலும் ஆப் தானாகவே இயங்க அனுமதி.',
                            icon: Icons.autorenew_rounded,
                            isGranted: _autoStartDone,
                            buttonLabel: 'OPEN AUTO START',
                            onTap: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('user_configured_autostart', true);
                              try {
                                await getAutoStartPermission();
                              } catch (_) {}
                              _checkAllPermissions();
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
            ),

            // BOTTOM ACTION BUTTON
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _proceedToApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allEssentialGranted ? themeColor : const Color(0xFF334155),
                    elevation: _allEssentialGranted ? 4 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _allEssentialGranted
                            ? 'அனைத்தும் ஆன் செய்யப்பட்டது • CONTINUE TO APP'
                            : 'தொடர்ந்து செல்லவும் • PROCEED TO APP',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _allEssentialGranted ? Colors.black : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: _allEssentialGranted ? Colors.black : Colors.white70,
                        size: 20,
                      ),
                    ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted ? const Color(0xFF1E293B) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGranted ? const Color(0xFF00C853).withOpacity(0.5) : Colors.white.withOpacity(0.1),
          width: isGranted ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // STEP BADGE / STATUS ICON
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isGranted ? Icons.check_circle_rounded : icon,
                color: statusColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // TITLE & SUBTITLE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'STEP $stepNum: ',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: 1,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ACTION BUTTON OR DONE BADGE
          if (isGranted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '✓ DONE',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF00C853),
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                buttonLabel,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
