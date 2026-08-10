import 'package:flutter/material.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'services/voice_dispatch_service.dart';
import 'providers/delivery_provider.dart';
import 'services/delivery_auth_service.dart';
import 'services/delivery_background_service.dart';
import 'screens/auth/delivery_login_screen.dart';
import 'screens/auth/delivery_pending_approval_screen.dart';
import 'screens/dashboard/delivery_dashboard_screen.dart';
import 'screens/rider_permissions_wizard_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui';

final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

void safeShowSnackBar(SnackBar snackBar) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    globalMessengerKey.currentState?.hideCurrentSnackBar();
    globalMessengerKey.currentState?.showSnackBar(snackBar);
  });
}

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

  await DeliveryBackgroundService.init();
  debugPrint('🚀 BOOT: Delivery Background Service Initialized');

  // Check auth state before rendering
  debugPrint('🚀 BOOT: Checking Login State...');
  final isLoggedIn = await DeliveryAuthService.isLoggedIn();
  debugPrint('🚀 BOOT: Is Logged In: $isLoggedIn');
  
  final approvalStatus = isLoggedIn ? await DeliveryAuthService.getApprovalStatus() : 'none';
  debugPrint('🚀 BOOT: Approval Status: $approvalStatus');
  
  final driverName = isLoggedIn ? await DeliveryAuthService.getDriverName() : '';
  final driverId = isLoggedIn ? await DeliveryAuthService.getDriverId() : '';

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    globalMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Error: ${details.exception}', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Error: $error');
    globalMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Error: $error', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('⚠️ UI RENDER ERROR: ${details.exception}');
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text('UI Render Exception', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(details.exceptionAsString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  };

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
      scaffoldMessengerKey: globalMessengerKey,
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
    // 1. Check Internet (with 3s timeout and fallback)
    bool isConnected = false;
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        isConnected = true;
      }
    } catch (_) {
      // Fallback: Assume connected so app startup does not hang on DNS lookup delays
      isConnected = true;
    }

    if (!isConnected) {
      _showErrorDialog('No Internet Connection', 'Please turn on your internet connection to continue.');
      return;
    }

    // 2. Check Location Service (with 3s timeout)
    bool isLocationOn = true;
    try {
      isLocationOn = await Geolocator.isLocationServiceEnabled().timeout(const Duration(seconds: 3));
    } catch (_) {}

    if (!isLocationOn) {
      _showErrorDialog('Location Disabled', 'Please turn on your GPS location to continue.');
      return;
    }
    
    try {
      var permission = await Geolocator.checkPermission().timeout(const Duration(seconds: 3));
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission().timeout(const Duration(seconds: 5));
      }
    } catch (_) {}

    try {
      await DeliveryBackgroundService.requestPermissions();
    } catch (_) {}

    if (mounted) {
      final shouldShowWizard = await RiderPermissionsWizardScreen.shouldShowWizard();
      if (shouldShowWizard) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RiderPermissionsWizardScreen(nextScreen: widget.nextScreen)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => widget.nextScreen),
        );
      }
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
