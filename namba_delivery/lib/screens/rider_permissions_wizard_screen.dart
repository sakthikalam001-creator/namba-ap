import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiderPermissionsWizardScreen extends StatefulWidget {
  final Widget nextScreen;

  const RiderPermissionsWizardScreen({super.key, required this.nextScreen});

  static Future<bool> shouldShowWizard() async {
    try {
      final notif = await _checkNotificationStatus();
      final locGranted = await _checkLocationStatus();
      final sysBattery = await _checkBatteryStatus();

      // If any essential permission is missing, wizard is shown
      return !notif || !locGranted || !sysBattery;
    } catch (_) {
      return false;
    }
  }

  static const MethodChannel _settingsChannel = MethodChannel('com.example.namaba_delivery/settings');

  static Future<bool> _checkNotificationStatus() async {
    try {
      if (Platform.isAndroid) {
        final bool? nativeVal = await _settingsChannel.invokeMethod<bool>('areNotificationsEnabled');
        if (nativeVal != null) return nativeVal;
      }
      return await Permission.notification.isGranted;
    } catch (_) {
      return await Permission.notification.isGranted;
    }
  }

  static Future<bool> _checkBatteryStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('user_allowed_battery') == true) return true;

      if (Platform.isAndroid) {
        final bool? nativeVal = await _settingsChannel.invokeMethod<bool>('isBatteryOptimizationsIgnored');
        if (nativeVal == true) return true;
      }
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('user_allowed_battery') ?? false;
    }
  }

  static Future<bool> _checkLocationStatus() async {
    try {
      final locStatus = await Geolocator.checkPermission();
      return (locStatus == LocationPermission.always || locStatus == LocationPermission.whileInUse);
    } catch (_) {
      return false;
    }
  }

  @override
  State<RiderPermissionsWizardScreen> createState() => _RiderPermissionsWizardScreenState();
}

class _RiderPermissionsWizardScreenState extends State<RiderPermissionsWizardScreen> with WidgetsBindingObserver {
  bool _notifGranted = false;
  bool _locGranted = false;
  bool _batteryGranted = false;

  static const MethodChannel _settingsChannel = MethodChannel('com.example.namaba_delivery/settings');

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
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    try {
      final notif = await RiderPermissionsWizardScreen._checkNotificationStatus();
      final loc = await RiderPermissionsWizardScreen._checkLocationStatus();
      final battery = await RiderPermissionsWizardScreen._checkBatteryStatus();

      if (mounted) {
        setState(() {
          _notifGranted = notif;
          _locGranted = loc;
          _batteryGranted = battery;
        });
      }
    } catch (e) {
      debugPrint('[Wizard] Check permissions error: $e');
    }
  }

  bool get _allEssentialGranted => _notifGranted && _locGranted && _batteryGranted;

  Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      if (!status.isGranted && Platform.isAndroid) {
        await _settingsChannel.invokeMethod('openNotificationSettings');
      }
    } catch (_) {
      await openAppSettings();
    }
    await _checkAllPermissions();
  }

  Future<void> _requestLocationPermission() async {
    try {
      var status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied || status == LocationPermission.unableToDetermine) {
        status = await Geolocator.requestPermission();
      }
      
      // If granted (or when user allows it), check if device GPS is turned on
      // If GPS is OFF, automatically redirect rider to turn ON GPS Location Services!
      final bool isGpsEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isGpsEnabled) {
        await Geolocator.openLocationSettings();
      } else if (status == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
    } catch (_) {
      await Geolocator.openLocationSettings();
    }
    await _checkAllPermissions();
  }

  Future<void> _requestBatteryPermission() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('user_allowed_battery', true);

    try {
      if (Platform.isAndroid) {
        final bool? opened = await _settingsChannel.invokeMethod<bool>('openBatterySettings');
        if (opened != true) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      } else {
        await openAppSettings();
      }
    } catch (_) {
      await Permission.ignoreBatteryOptimizations.request();
    }
    await _checkAllPermissions();
  }

  Future<void> _handleBottomButtonTap() async {
    if (_allEssentialGranted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('wizard_completed', true);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => widget.nextScreen),
        );
      }
      return;
    }

    // Step-by-step trigger for ungranted permissions
    if (!_notifGranted) {
      await _requestNotificationPermission();
      return;
    }
    if (!_locGranted) {
      await _requestLocationPermission();
      return;
    }
    if (!_batteryGranted) {
      await _requestBatteryPermission();
      return;
    }

    await _checkAllPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
        ),
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER ROW
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.security_rounded,
                                color: Color(0xFF4F46E5),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Setup Order Alerts',
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF1E293B),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Required for ringing on lockscreen',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // EXPLANATION TEXT
                        Text(
                          'To ensure order ringtones play loudly even when your phone screen is LOCKED, please allow the following permissions:',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF475569),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ITEM 1: NOTIFICATIONS
                        _buildPermissionCard(
                          icon: Icons.notifications_active_rounded,
                          title: '1. Order Notifications',
                          desc: 'Play loud ringtones for new incoming orders',
                          isGranted: _notifGranted,
                          onTap: _requestNotificationPermission,
                        ),

                        const SizedBox(height: 14),

                        // ITEM 2: LOCATION
                        _buildPermissionCard(
                          icon: Icons.location_on_rounded,
                          title: '2. Live GPS Location',
                          desc: 'Accurate order assignment & delivery tracking',
                          isGranted: _locGranted,
                          onTap: _requestLocationPermission,
                        ),

                        const SizedBox(height: 14),

                        // ITEM 3: BATTERY
                        _buildPermissionCard(
                          icon: Icons.battery_charging_full_rounded,
                          title: '3. Allow Background Usage',
                          desc: 'Keep rider app active in background & receive orders when locked',
                          isGranted: _batteryGranted,
                          onTap: _requestBatteryPermission,
                        ),

                        const SizedBox(height: 20),

                        // BOTTOM ACTION BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _handleBottomButtonTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _allEssentialGranted
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _allEssentialGranted
                                      ? Icons.check_circle_rounded
                                      : Icons.settings_suggest_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _allEssentialGranted
                                          ? 'CONTINUE TO APP'
                                          : 'ALLOW ALL PERMISSIONS',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String desc,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isGranted ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: isGranted ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // ICON BADGE
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFFD1FAE5)
                  : const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? const Color(0xFF059669) : const Color(0xFF4F46E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // TITLE & SUBTITLE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isGranted ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: isGranted ? const Color(0xFF047857) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ACTION BUTTON OR STATUS BADGE
          if (!isGranted)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ALLOW',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4F46E5),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF059669),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ON',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF065F46),
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
