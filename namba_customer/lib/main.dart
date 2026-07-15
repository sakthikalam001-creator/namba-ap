import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/notification_provider.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

import 'providers/theme_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

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
  } catch (e, stack) {
    print('❌ CRITICAL STARTUP ERROR: $e');
    print('📜 STACK TRACE: $stack');
  }

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
          navigatorKey: navigatorKey,
          title: 'Namba Customer',
          debugShowCheckedModeBanner: false,
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: theme.themeMode,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
