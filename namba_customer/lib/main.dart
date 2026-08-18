import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/notification_provider.dart';
import 'services/notification_service.dart';
import 'services/location_accuracy_service.dart';
import 'screens/splash_screen.dart';

import 'providers/theme_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';

final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🚀 Loading Environment Variables...');
    await dotenv.load(fileName: ".env");
    print('✅ Env Loaded: ${dotenv.env['API_BASE_URL']}');

    print('🚀 Skipping Firebase for now (Mock Mode Enabled)');
    /*
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      await Firebase.initializeApp(
...
    } else {
      await Firebase.initializeApp();
    }
    */
    print('✅ App Initialized in Mock Mode');

    print('🚀 Initializing Hive...');
    await Hive.initFlutter();
    print('✅ Hive Initialized');

    print('🚀 Initializing Notifications...');
    await NotificationService().initialize();
    print('✅ Notifications Initialized');

    print('🚀 Initializing Location Cache...');
    await LocationAccuracyService.initCache();
    print('✅ Location Cache Initialized');
  } catch (e, stack) {
    print('❌ CRITICAL STARTUP ERROR: $e');
    print('📜 STACK TRACE: $stack');
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: \${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Error: \$error');
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

  runApp(const NambaApp());
}

class NambaApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  const NambaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProxyProvider2<NotificationProvider, AuthProvider, OrderProvider>(
          create: (_) => OrderProvider(),
          update: (_, notif, auth, order) {
            order!.setProviders(notif, auth);
            return order;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          navigatorKey: NambaApp.navigatorKey,
          scaffoldMessengerKey: globalMessengerKey,
          title: 'Namba Customer',
          debugShowCheckedModeBanner: false,
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: theme.themeMode,
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
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
