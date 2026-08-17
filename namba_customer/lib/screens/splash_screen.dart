import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart';
import 'home_screen.dart';
import 'map_location_picker_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.forward();
    
    Future.delayed(const Duration(milliseconds: 400), () {
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

    // 4. Minimum 2.8 seconds display duration so user can see and enjoy the splash emblem
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!).inMilliseconds;
      if (elapsed < 2800) {
        await Future.delayed(Duration(milliseconds: 2800 - elapsed));
      }
    }

    // 5. Proceed with smooth fade transition
    if (!mounted) return;
    final Widget targetScreen = !auth.isLoggedIn
        ? const OnboardingScreen()
        : !auth.hasSetLocation
            ? const MapLocationPickerScreen(isInitialSetup: true)
            : const HomeScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
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
    final size = MediaQuery.of(context).size;
    final logoSize = size.width * 0.72;

    return Scaffold(
      backgroundColor: const Color(0xFF091E29),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  Color(0xFF0F2B3A),
                  Color(0xFF051219),
                  Color(0xFF02090D),
                ],
              ),
            ),
          ),

          // Center Logo & Branding
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: logoSize > 320 ? 320 : logoSize,
                      height: logoSize > 320 ? 320 : logoSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.15),
                            blurRadius: 50,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/splash_logo.png',
                          width: logoSize > 320 ? 320 : logoSize,
                          height: logoSize > 320 ? 320 : logoSize,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF00E5FF).withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Footer Tagline
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fade,
              child: Text(
                'YOUR EVERYTHING SUPER APP',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
