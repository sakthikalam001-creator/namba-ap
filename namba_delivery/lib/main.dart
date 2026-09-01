import 'package:flutter/material.dart';
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
    debugPrint('Flutter Error: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Error: $error');
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
        ChangeNotifierProvider(
          create: (_) => DeliveryProvider(
            initialIsLoggedIn: isLoggedIn,
            initialApprovalStatus: approvalStatus,
          ),
        ),
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
    final status = provider.approvalStatus.isNotEmpty ? provider.approvalStatus : approvalStatus;

    Widget home;
    if (!isAuthed) {
      home = const DeliveryLoginScreen();
    } else if (status == 'approved' || provider.pendingAssignment != null) {
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
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkPrerequisites();
    });
  }

  Future<void> _checkPrerequisites() async {
    if (_isChecking) return;
    _isChecking = true;

    // 0. Check if Rider Setup & Permission Wizard should open first on initial boot
    try {
      final shouldShowWizard = await RiderPermissionsWizardScreen.shouldShowWizard();
      if (shouldShowWizard && mounted) {
        _isChecking = false;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RiderPermissionsWizardScreen(nextScreen: widget.nextScreen)),
        );
        return;
      }
    } catch (e) {
      debugPrint('[InitialCheck] Check wizard error: $e');
    }

    // 1. Fast navigation to main app screen if wizard is already completed
    if (mounted) {
      _isChecking = false;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.nextScreen),
      );
    }
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
