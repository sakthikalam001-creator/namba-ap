import 'package:flutter/material.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _checkPrerequisites();
    });
  }

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
      _showErrorDialog('No Internet Connection', 'Please turn on your internet connection to continue.');
      return;
    }

    // 2. Check Location Service
    bool isLocationOn = await Geolocator.isLocationServiceEnabled();
    if (!isLocationOn) {
      _showErrorDialog('Location Disabled', 'Please turn on your GPS location to continue.');
      return;
    }

    // 3. Request Permission
    await _requestLocationPermissionOnStartup();

    // 4. Proceed
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => auth.isLoggedIn ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              if (title == 'Location Disabled') {
                await Geolocator.openLocationSettings();
              }
              _checkPrerequisites(); // Check again
            },
            child: const Text('Retry', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
