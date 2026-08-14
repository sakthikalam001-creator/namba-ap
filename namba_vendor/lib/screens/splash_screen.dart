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

    // Request Android Permissions on First Launch (Notifications, Unrestricted Battery, Auto-Start)
    await _checkAndroidPermissionsOnFirstLaunch();

    // Proceed
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
    final userAllowed = prefs.getBool('user_allowed_battery') ?? false;
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
  bool _batteryGranted = false;
  bool _overlayGranted = false;

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
      _checkPermissions();
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

    bool overlay = await Permission.systemAlertWindow.isGranted;
    if (!overlay) {
      try {
        const platform = MethodChannel('com.namba.vendor/app');
        final bool nativeOverlay = await platform.invokeMethod('canDrawOverlays');
        if (nativeOverlay) overlay = true;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _notifGranted = notif;
        _batteryGranted = battery;
        _overlayGranted = overlay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _notifGranted && _batteryGranted && _overlayGranted;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.security_rounded, color: Color(0xFF4F46E5), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Setup Order Alerts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Required for ringing on lockscreen',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'To ensure order ringtones play loudly even when your phone screen is LOCKED, please allow the following permissions:',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 20),

              // 1. Order Notifications
              _buildDialogPermissionItem(
                icon: Icons.notifications_active_rounded,
                title: '1. Order Notifications',
                desc: 'Play loud ringtones for new incoming orders',
                isGranted: _notifGranted,
                onTap: () async {
                  await Permission.notification.request();
                  _checkPermissions();
                },
              ),
              const SizedBox(height: 12),

              // 2. Unrestricted Battery
              _buildDialogPermissionItem(
                icon: Icons.battery_charging_full_rounded,
                title: '2. Unrestricted Battery',
                desc: 'Keep store active in background when locked',
                isGranted: _batteryGranted,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('user_allowed_battery', true);
                  await prefs.setBool('setup_order_alerts_completed', true);
                  try {
                    const platform = MethodChannel('com.namba.vendor/app');
                    await platform.invokeMethod('openBatterySettings');
                  } catch (_) {
                    await Permission.ignoreBatteryOptimizations.request();
                  }
                  _checkPermissions();
                },
              ),
              const SizedBox(height: 12),

              // 3. Display Over Other Apps
              _buildDialogPermissionItem(
                icon: Icons.layers_rounded,
                title: '3. Display Over Other Apps',
                desc: 'Show incoming order call alerts over other apps',
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
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('setup_order_alerts_completed', true);
                    await prefs.setBool('user_allowed_battery', true);
                    if (allGranted) {
                      if (mounted) Navigator.pop(context);
                    } else {
                      if (!_notifGranted) await Permission.notification.request();
                      if (!_batteryGranted) {
                        try {
                          const platform = MethodChannel('com.namba.vendor/app');
                          await platform.invokeMethod('openBatterySettings');
                        } catch (_) {
                          await Permission.ignoreBatteryOptimizations.request();
                        }
                      }
                      if (!_overlayGranted) {
                        try {
                          const platform = MethodChannel('com.namba.vendor/app');
                          await platform.invokeMethod('openOverlaySettings');
                        } catch (_) {
                          await Permission.systemAlertWindow.request();
                        }
                      }
                      await _checkPermissions();
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  child: Text(
                    allGranted ? 'CONTINUE TO DASHBOARD' : 'ALLOW PERMISSIONS NOW',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isGranted ? const Color(0xFFECFDF5) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? const Color(0xFF10B981) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGranted ? const Color(0xFFD1FAE5) : const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? const Color(0xFF059669) : const Color(0xFF4F46E5),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isGranted ? const Color(0xFF065F46) : const Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isGranted ? const Color(0xFF047857) : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isGranted)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'ALLOW',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
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

