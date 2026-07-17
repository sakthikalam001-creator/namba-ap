import 'package:flutter/material.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _checkPrerequisites();
    });
  }

  Timer? _autoCheckTimer;
  bool _isDialogShowing = false;

  Future<void> _checkPrerequisites() async {
    // 1. Check Internet
    bool isConnected = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        isConnected = true;
      }
    } catch (_) {}

    if (!isConnected) {
      _showModernErrorDialog(
        title: 'No Internet Connection', 
        message: 'Please turn on your Wi-Fi or Mobile Data to continue using Namba.',
        icon: Icons.wifi_off_rounded,
        isLocation: false,
      );
      return;
    }

    // 2. Check Location Service
    bool isLocationOn = await Geolocator.isLocationServiceEnabled();
    if (!isLocationOn) {
      _showModernErrorDialog(
        title: 'Location Disabled', 
        message: 'We need your GPS location to find the best food and delivery partners near you.',
        icon: Icons.location_off_rounded,
        isLocation: true,
      );
      return;
    }

    // 3. Request Permission
    await _requestLocationPermissionOnStartup();

    // Wait for AuthProvider to finish loading SharedPreferences
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.initFuture != null) {
      await auth.initFuture;
    }

    // 4. Proceed
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => auth.isLoggedIn ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }

  void _showModernErrorDialog({required String title, required String message, required IconData icon, required bool isLocation}) {
    if (!mounted || _isDialogShowing) return;
    _isDialogShowing = true;

    // Auto-check in background so dialog dismisses automatically
    _autoCheckTimer?.cancel();
    _autoCheckTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      bool connected = false;
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) connected = true;
      } catch (_) {}
      bool locationOn = await Geolocator.isLocationServiceEnabled();

      bool isResolved = isLocation ? locationOn : connected;

      if (isResolved) {
        timer.cancel();
        if (mounted && _isDialogShowing) {
          Navigator.pop(context); // Close dialog
          _isDialogShowing = false;
          _checkPrerequisites(); // Continue to next screen
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
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
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 50, color: const Color(0xFF4F46E5)),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      await Geolocator.openLocationSettings();
                    },
                    child: const Text(
                      'Open Settings', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                )
              else
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF4F46E5))),
                      const SizedBox(height: 12),
                      Text('Waiting for connection...', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]
                  )
                ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _isDialogShowing = false;
      _autoCheckTimer?.cancel();
    });
  }

  Future<void> _requestLocationPermissionOnStartup() async {
    try {
      print('🚀 Checking Location Permissions on Startup...');
      var permission = await Geolocator.checkPermission();
      print('ℹ️ Current Permission: $permission');
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        print('🚀 Requesting Location Permission...');
        permission = await Geolocator.requestPermission();
        print('ℹ️ New Permission State: $permission');
      }
    } catch (e) {
      print('❌ Startup Location Permission Error: $e');
    }
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFDB2777)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, size: 65, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Namba', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                  const SizedBox(height: 6),
                  Text('Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.8), letterSpacing: 4)),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
