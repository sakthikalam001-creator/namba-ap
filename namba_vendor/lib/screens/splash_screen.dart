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

  Future<void> _checkPrerequisites() async {
    _setStatus('Checking internet...');

    // 1. Check Internet
    bool isConnected = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        isConnected = true;
      }
    } catch (_) {}

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
    bool isLocationOn = await Geolocator.isLocationServiceEnabled();
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

    // Request permission if needed
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {}

    // 4. Proceed
    if (mounted) _navigateToHome();
  }

  void _showModernErrorDialog({
    required String title,
    required String message,
    required IconData icon,
    required bool isLocation,
  }) {
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
          Navigator.pop(context);
          _isDialogShowing = false;
          _checkPrerequisites();
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
      _isDialogShowing = false;
      _autoCheckTimer?.cancel();
    });
  }

  Future<void> _navigateToHome() async {
    
    if (!mounted) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isVendorLoggedIn') ?? false;
      final phone = prefs.getString('vendorPhone');
      
      if (isLoggedIn && phone != null) {
        String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://100.53.131.76:5000/api/v1';
        
        final statusResponse = await http.get(Uri.parse('$baseUrl/admin/vendors/status-by-phone/$phone'));
        if (statusResponse.statusCode == 200) {
          final statusData = jsonDecode(statusResponse.body);
          if (statusData['success'] == true) {
            final vendor = statusData['data'];
            if (vendor['approvalStatus'] == 'approved') {
              if (!mounted) return;
              final orderProvider = Provider.of<VendorOrderProvider>(context, listen: false);
              orderProvider.setProfile(VendorProfileModel.fromJson(vendor));
              if (!mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigationShell()));
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Auto-login failed: $e');
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
            Text(
              'NAMBA DELIVERY',
              style: GoogleFonts.outfit(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
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

