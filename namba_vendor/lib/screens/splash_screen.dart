import 'package:flutter/material.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../theme/app_theme.dart';
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
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
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
            child: const Text('Retry', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  _navigateToHome() async {
    
    if (!mounted) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isVendorLoggedIn') ?? false;
      final phone = prefs.getString('vendorPhone');
      
      if (isLoggedIn && phone != null) {
        String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000/api/v1';
        
        final statusResponse = await http.get(Uri.parse('$baseUrl/admin/vendors/status-by-phone/$phone'));
        if (statusResponse.statusCode == 200) {
          final statusData = jsonDecode(statusResponse.body);
          if (statusData['success'] == true) {
            final vendor = statusData['data'];
            if (vendor['approvalStatus'] == 'approved') {
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
          ],
        ),
      ),
    );
  }
}

