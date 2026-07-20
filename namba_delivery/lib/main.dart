import 'package:flutter/material.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'services/voice_dispatch_service.dart';
import 'providers/delivery_provider.dart';
import 'services/delivery_auth_service.dart';
import 'screens/auth/delivery_login_screen.dart';
import 'screens/auth/delivery_pending_approval_screen.dart';
import 'screens/dashboard/delivery_dashboard_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {

  debugPrint('🚀 BOOT: Initializing App...');
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ BOOT: Env Loaded');
  } catch (e) {
    debugPrint('❌ BOOT: Env Load Failed: $e');
  }

  debugPrint('🚀 BOOT: Flutter Binding Initialized');
  
  await Hive.initFlutter();
  debugPrint('🚀 BOOT: Hive Initialized');
  
  await VoiceDispatchService.init();
  debugPrint('🚀 BOOT: Voice Dispatch Initialized');

  // Check auth state before rendering
  debugPrint('🚀 BOOT: Checking Login State...');
  final isLoggedIn = await DeliveryAuthService.isLoggedIn();
  debugPrint('🚀 BOOT: Is Logged In: $isLoggedIn');
  
  final approvalStatus = isLoggedIn ? await DeliveryAuthService.getApprovalStatus() : 'none';
  debugPrint('🚀 BOOT: Approval Status: $approvalStatus');
  
  final driverName = isLoggedIn ? await DeliveryAuthService.getDriverName() : '';
  final driverId = isLoggedIn ? await DeliveryAuthService.getDriverId() : '';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
      ],
      child: NambaDeliveryApp(
        isLoggedIn: isLoggedIn,
        approvalStatus: approvalStatus,
        driverName: driverName,
        driverId: driverId,
      ),
    ),
  );
}

class NambaDeliveryApp extends StatelessWidget {
  final bool isLoggedIn;
  final String approvalStatus;
  final String driverName;
  final String driverId;

  const NambaDeliveryApp({
    super.key,
    required this.isLoggedIn,
    required this.approvalStatus,
    required this.driverName,
    required this.driverId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final isAuthed = provider.isAuthenticated;

    Widget home;
    if (!isAuthed) {
      home = const DeliveryLoginScreen();
    } else if (provider.approvalStatus == 'approved') {
      home = const DeliveryDashboardScreen();
    } else {
      home = DeliveryPendingApprovalScreen(
        driverName: driverName,
        driverId: driverId,
      );
    }

    return MaterialApp(
      title: 'Namba Delivery Partner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: InitialCheckScreen(nextScreen: home),
    );
  }
}

class InitialCheckScreen extends StatefulWidget {
  final Widget nextScreen;
  const InitialCheckScreen({super.key, required this.nextScreen});

  @override
  State<InitialCheckScreen> createState() => _InitialCheckScreenState();
}

class _InitialCheckScreenState extends State<InitialCheckScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
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
    
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {}

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.nextScreen),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
