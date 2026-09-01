import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import 'auth/vendor_login_screen.dart';
import '../models/vendor_profile_model.dart';
import '../services/vendor_order_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _autoCheckTimer;
  bool _isDialogShowing = false;
  int _dialogGeneration = 0; // Unique ID per dialog — prevents .then() race condition
  String _statusText = 'Checking internet...';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _checkPrerequisites();
    });
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  Future<bool> _hasInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.isEmpty || (connectivityResult.length == 1 && connectivityResult.first == ConnectivityResult.none)) {
        return false;
      }
      return true;
    } catch (_) {}
    return true;
  }


  Future<void> _checkPrerequisites() async {
    _setStatus('Checking internet...');

    // 1. Check Internet
    final bool isConnected = await _hasInternet();

    if (!isConnected) {
      _setStatus('No internet connection');
      _showModernErrorDialog(
        title: 'No Internet Connection',
        message: 'Please turn on your Wi-Fi or Mobile Data to continue using Namba.',
        icon: Icons.wifi_off_rounded,
        isLocation: false,
      );
      return;
    }

    _setStatus('Checking location...');

    // 2. Check Location Service
    final bool isLocationOn = await Geolocator.isLocationServiceEnabled();
    if (!isLocationOn) {
      _setStatus('Location is disabled');
      _showModernErrorDialog(
        title: 'Location Disabled',
        message: 'We need your GPS location to manage your store and deliveries.',
        icon: Icons.location_off_rounded,
        isLocation: true,
      );
      return;
    }

    _setStatus('Loading...');

    // Request location permission if needed
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {}

    // Request Android Permissions on First Launch (Notifications, Overlay, Battery)
    await _checkAndroidPermissionsOnFirstLaunch();

    // Proceed straight to home
    if (mounted) _navigateToHome();
  }

  Future<void> _checkAndroidPermissionsOnFirstLaunch() async {
    if (!Platform.isAndroid) return;
    
    final prefs = await SharedPreferences.getInstance();
    final bool completed = prefs.getBool('setup_order_alerts_completed') ?? false;
    final bool userAllowed = prefs.getBool('user_allowed_battery') ?? false;
    if (completed || userAllowed) return; // Never show permission dialog again if already granted!

    // Check if all permissions are already granted
    final notif = await Permission.notification.isGranted;
    
    bool sysBattery = await Permission.ignoreBatteryOptimizations.isGranted;
    if (!sysBattery) {
      try {
        const platform = MethodChannel('com.namba.vendor/app');
        final bool nativeIgnored = await platform.invokeMethod('isBatteryOptimizationsIgnored');
        if (nativeIgnored) sysBattery = true;
      } catch (_) {}
    }
    final battery = sysBattery || userAllowed;
    final overlay = await Permission.systemAlertWindow.isGranted;
    
    if (notif && battery && overlay) {
      await prefs.setBool('setup_order_alerts_completed', true);
      return;
    }

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PermissionEnforcerDialog(),
      );
      await prefs.setBool('setup_order_alerts_completed', true);
    }
  }

  void _showModernErrorDialog({
    required String title,
    required String message,
    required IconData icon,
    required bool isLocation,
  }) {
    if (!mounted || _isDialogShowing) return;
    _isDialogShowing = true;

    // ✅ Unique generation ID — so .then() doesn't interfere with a future dialog
    _dialogGeneration++;
    final int myGeneration = _dialogGeneration;

    _autoCheckTimer?.cancel();
    _autoCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final bool connected = await _hasInternet();
      final bool locationOn = await Geolocator.isLocationServiceEnabled();
      final bool isResolved = isLocation ? locationOn : connected;

      if (isResolved) {
        timer.cancel();
        // Only act if this callback belongs to the currently showing dialog
        if (mounted && _isDialogShowing && _dialogGeneration == myGeneration) {
          _isDialogShowing = false;
          Navigator.pop(context);
          await Future.delayed(const Duration(milliseconds: 50));
          if (mounted) _checkPrerequisites();
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 50, color: const Color(0xFF4F46E5)),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              if (isLocation)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      await Geolocator.openLocationSettings();
                    },
                    child: Text(
                      'Open Settings',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                Center(
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Waiting for connection...',
                        style: GoogleFonts.outfit(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // ✅ Only reset flag if this .then() belongs to the SAME dialog generation
      // This prevents overwriting a newer dialog's state
      if (_dialogGeneration == myGeneration) {
        _isDialogShowing = false;
        _autoCheckTimer?.cancel();
      }
    });
  }


  Future<void> _navigateToHome() async {
    if (!mounted) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isVendorLoggedIn') ?? false;
      final phone = prefs.getString('vendorPhone');
      final cachedJsonStr = prefs.getString('vendorProfileJson');
      
      if (isLoggedIn && (phone != null || cachedJsonStr != null)) {
        Map<String, dynamic>? vendorMap;

        // Try online status fetch first
        if (phone != null && phone.isNotEmpty) {
          try {
            String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://54.204.9.126:5000/api/v1';
            final encodedPhone = Uri.encodeComponent(phone.trim());
            final statusResponse = await http.get(Uri.parse('$baseUrl/admin/vendors/status-by-phone/$encodedPhone')).timeout(const Duration(seconds: 5));
            if (statusResponse.statusCode == 200) {
              final statusData = jsonDecode(statusResponse.body);
              if (statusData['success'] == true && statusData['data'] != null) {
                vendorMap = statusData['data'];
                await prefs.setString('vendorProfileJson', jsonEncode(vendorMap));
              }
            }
          } catch (netErr) {
            debugPrint('⚠️ Online vendor check timed out/failed, trying offline cache: $netErr');
          }
        }

        // Offline / Cache fallback if network failed but cache exists
        if (vendorMap == null && cachedJsonStr != null && cachedJsonStr.isNotEmpty) {
          try {
            vendorMap = jsonDecode(cachedJsonStr);
            debugPrint('⚡ Auto-login using cached vendor profile!');
          } catch (jsonErr) {
            debugPrint('❌ Cached vendor profile JSON parse error: $jsonErr');
          }
        }

        if (vendorMap != null && vendorMap['approvalStatus'] == 'approved') {
          if (!mounted) return;
          final orderProvider = Provider.of<VendorOrderProvider>(context, listen: false);
          orderProvider.setProfile(VendorProfileModel.fromJson(vendorMap));
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigationShell()));
          return;
        } else {
          // Add alert to see WHY it failed
          debugPrint('Auto-login rejected: vendorMap=$vendorMap');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Auto-login failed: Profile not found or not approved.\nMap: $vendorMap')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Auto-login check failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-login error: $e')),
        );
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const VendorLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Iconsax.shop,
                size: 60,
                color: Color(0xFF4F46E5),
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).rotate(delay: 600.ms),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'NAMBA DELIVERY',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5, end: 0),
            Text(
              'VENDOR',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
                letterSpacing: 2,
              ),
            ).animate().fadeIn(delay: 800.ms),
            const SizedBox(height: 48),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ).animate().fadeIn(delay: 900.ms),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _statusText,
                key: ValueKey(_statusText),
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.65),
                  letterSpacing: 0.5,
                ),
              ),
            ).animate().fadeIn(delay: 1000.ms),
          ],
        ),
      ),
    );
  }
}

class PermissionEnforcerDialog extends StatefulWidget {
  const PermissionEnforcerDialog({super.key});

  @override
  State<PermissionEnforcerDialog> createState() => _PermissionEnforcerDialogState();
}

class _PermissionEnforcerDialogState extends State<PermissionEnforcerDialog> with WidgetsBindingObserver {
  bool _notifGranted = false;
  bool _overlayGranted = false;
  bool _batteryGranted = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    // Fast 400ms periodic timer so settings turn green the instant user flips switches!
    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
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
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    // 1. Strictly Check Notification permission (only true if user toggled on in OS)
    bool notif = await Permission.notification.isGranted;
    try {
      const platform = MethodChannel('com.namba.vendor/app');
      final bool? nativeNotif = await platform.invokeMethod<bool>('areNotificationsEnabled');
      if (nativeNotif != null) notif = nativeNotif;
    } catch (_) {}

    // 2. Strictly Check Display Overlay permission (only true if switch is ON in OS)
    bool overlay = false;
    try {
      const platform = MethodChannel('com.namba.vendor/app');
      final bool? nativeOverlay = await platform.invokeMethod<bool>('canDrawOverlays');
      if (nativeOverlay != null) overlay = nativeOverlay;
    } catch (_) {
      overlay = await Permission.systemAlertWindow.isGranted;
    }

    // 3. Strictly Check Unrestricted Battery (only true if whitelist/unrestricted is ON in OS)
    bool battery = false;
    try {
      const platform = MethodChannel('com.namba.vendor/app');
      final bool? nativeBattery = await platform.invokeMethod<bool>('isBatteryOptimizationsIgnored');
      if (nativeBattery != null) battery = nativeBattery;
    } catch (_) {
      battery = await Permission.ignoreBatteryOptimizations.isGranted;
    }

    if (mounted) {
      setState(() {
        _notifGranted = notif;
        _overlayGranted = overlay;
        _batteryGranted = battery;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _notifGranted && _overlayGranted && _batteryGranted;
    final mediaQuery = MediaQuery.of(context);

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
        ),
      ),
      child: PopScope(
        canPop: false,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.security_rounded, color: Color(0xFF4F46E5), size: 28),
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

                  // 1. Order Notifications
                  _buildDialogPermissionItem(
                    icon: Icons.notifications_active_rounded,
                    title: '1. Order Notifications',
                    desc: 'Play loud ringtones for new incoming orders',
                    isGranted: _notifGranted,
                    onTap: () async {
                      try {
                        const platform = MethodChannel('com.namba.vendor/app');
                        await platform.invokeMethod('openNotificationSettings');
                      } catch (_) {
                        await Permission.notification.request();
                      }
                      _checkPermissions();
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2. Display Over Other Apps
                  _buildDialogPermissionItem(
                    icon: Icons.layers_rounded,
                    title: '2. Display Over Other Apps',
                    desc: 'Show full screen incoming order screen when locked',
                    isGranted: _overlayGranted,
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
                  const SizedBox(height: 12),

                  // 3. Unrestricted Battery
                  _buildDialogPermissionItem(
                    icon: Icons.battery_charging_full_rounded,
                    title: '3. Unrestricted Battery',
                    desc: 'Keep store active in background when locked',
                    isGranted: _batteryGranted,
                    onTap: () async {
                      try {
                        const platform = MethodChannel('com.namba.vendor/app');
                        await platform.invokeMethod('openBatterySettings');
                      } catch (_) {
                        await Permission.ignoreBatteryOptimizations.request();
                      }
                      _checkPermissions();
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: allGranted ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (allGranted) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('setup_order_alerts_completed', true);
                          if (mounted) Navigator.of(this.context).pop();
                        } else {
                          // Prompt missing permissions in sequence
                          if (!_notifGranted) {
                            try {
                              const platform = MethodChannel('com.namba.vendor/app');
                              await platform.invokeMethod('openNotificationSettings');
                            } catch (_) {
                              await Permission.notification.request();
                            }
                          } else if (!_overlayGranted) {
                            try {
                              const platform = MethodChannel('com.namba.vendor/app');
                              await platform.invokeMethod('openOverlaySettings');
                            } catch (_) {
                              await Permission.systemAlertWindow.request();
                            }
                          } else if (!_batteryGranted) {
                            try {
                              const platform = MethodChannel('com.namba.vendor/app');
                              await platform.invokeMethod('openBatterySettings');
                            } catch (_) {
                              await Permission.ignoreBatteryOptimizations.request();
                            }
                          }
                          await _checkPermissions();
                          if (allGranted && mounted) Navigator.of(this.context).pop();
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            allGranted ? Icons.check_circle_rounded : Icons.security_update_good_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                allGranted ? 'ALL PERMISSIONS ENABLED ✓' : 'ALLOW ALL PERMISSIONS',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
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
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('setup_order_alerts_completed', true);
                        if (mounted) Navigator.of(this.context).pop();
                      },
                      child: Text(
                        allGranted ? 'Tap above to continue' : 'Skip for now / பிறகு அமைக்கவும்',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogPermissionItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isGranted ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: isGranted ? 2.0 : 1.0,
        ),
        boxShadow: isGranted
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isGranted ? const Color(0xFF10B981) : const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isGranted ? Icons.check_rounded : icon,
              color: isGranted ? Colors.white : const Color(0xFF4F46E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
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
                      fontSize: 13.5,
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
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: isGranted ? const Color(0xFF047857) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isGranted)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'ALLOW',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 5),
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

