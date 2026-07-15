import 'package:flutter/material.dart';
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

  Widget get _home {
    if (!isLoggedIn) return const DeliveryLoginScreen();
    if (approvalStatus == 'approved') return const DeliveryDashboardScreen();
    return DeliveryPendingApprovalScreen(
      driverName: driverName,
      driverId: driverId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Namba Delivery Partner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _home,
    );
  }
}
