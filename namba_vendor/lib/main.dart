import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'theme/app_theme.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'services/vendor_order_provider.dart';
import 'services/vendor_inventory_provider.dart';
import 'services/language_provider.dart';
import 'services/alert_service.dart';
import 'screens/dashboard/vendor_dashboard_screen.dart';
import 'screens/orders/vendor_orders_screen.dart';
import 'screens/orders/vendor_order_detail_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'services/vendor_notification_service.dart';
import 'services/vendor_background_service.dart';
import 'screens/splash_screen.dart';
import 'services/navigation_provider.dart';
import 'models/vendor_order_model.dart';
import 'widgets/permissions_wizard_sheet.dart';

import 'screens/profile/store_profile_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ BOOT: Env Loaded');
  } catch (e) {
    debugPrint('❌ BOOT: Env Load Failed: $e');
  }

  // Initialize background foreground task service
  await VendorBackgroundService.init();
  debugPrint('✅ BOOT: Background Service Initialized');

  // Register Firebase Messaging Background Handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text('UI Render Exception', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(details.exceptionAsString(), textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  };
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AlertService()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => VendorOrderProvider()),
        ChangeNotifierProvider(create: (_) => VendorInventoryProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const NambaVendorApp(),
    ),
  );
}

class NambaVendorApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  const NambaVendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Namba Vendor',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: globalMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.outfit().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF7C3AED),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      ),
      home: const SplashScreen(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  // Track ALL orders we've already shown a notification for (not just the last one)
  final Set<String> _shownNotificationIds = {};

  final List<Widget> _screens = [
    const VendorDashboardScreen(),
    const VendorOrdersScreen(),
    const InventoryScreen(),
    const StoreProfileScreen(),
  ];

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isNoInternetDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _setupOrderListener();
      // 🌟 Wait 1.5 seconds after screen is rendered to ensure Android allows settings redirects
      await Future.delayed(const Duration(milliseconds: 1500));
      await _initNotifications();
      await _showPermissionsWizardIfNeeded();

      // 🌟 Route to pending notification order if any!
      if (VendorNotificationService.pendingOrderId != null) {
        final orderId = VendorNotificationService.pendingOrderId!;
        VendorNotificationService.pendingOrderId = null; // Clear it
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VendorOrderDetailScreen(orderId: orderId),
            ),
          );
        }
      }
    });
  }

  Future<void> _initNotifications() async {
    // 🔔 Request permission up front so new order pushes work
    await VendorNotificationService().initialize();

    if (Platform.isAndroid) {
      // Small delay to ensure UI is ready before system dialogs pop up
      await Future.delayed(const Duration(seconds: 2));

      try {
        // 1. Request Notification Permission explicitly
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }

        // 2. Request System Alert Window (Display over other apps / Overlay)
        // This directly opens the settings screen shown in the user's screenshot!
        final isOverlayGranted = await Permission.systemAlertWindow.isGranted;
        if (!isOverlayGranted) {
          await Permission.systemAlertWindow.request();
        }

        // 3. Verify if Notification Permission is granted, show dialog if denied
        final isGranted = await Permission.notification.isGranted;
        if (!isGranted) {
          AlertService().showAlert(
            title: '⚠️ Notification Permission Required',
            message: 'ஆர்டர்கள் வரும்போது அலர்ட் பெற நோட்டிபிகேஷன் பர்மிஷன் தேவை. தயவுசெய்து உங்கள் போன் Settings-ல் Namba Vendor ஆப்பிற்கு Notifications-ஐ ஆன் செய்யவும்.',
          );
        }
      } catch (e) {
        debugPrint('Permission error: $e');
      }
    }
  }

  Future<void> _showPermissionsWizardIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool completed = prefs.getBool('setup_order_alerts_completed') ?? false;
    if (completed) return;

    final notif = await Permission.notification.isGranted;
    
    bool sysBattery = await Permission.ignoreBatteryOptimizations.isGranted;
    if (!sysBattery) {
      try {
        const platform = MethodChannel('com.namba.vendor/app');
        final bool nativeIgnored = await platform.invokeMethod('isBatteryOptimizationsIgnored');
        if (nativeIgnored) sysBattery = true;
      } catch (_) {}
    }
    final userAllowed = prefs.getBool('user_allowed_battery') ?? false;
    final battery = sysBattery || userAllowed;
    final overlay = await Permission.systemAlertWindow.isGranted;

    if (!notif || !battery || !overlay) {
      if (mounted) {
        await PermissionsWizardSheet.show(context);
        await prefs.setBool('setup_order_alerts_completed', true);
      }
    } else {
      await prefs.setBool('setup_order_alerts_completed', true);
    }
  }

  void _setupOrderListener() {
    final orderProvider = Provider.of<VendorOrderProvider>(context, listen: false);
    final alertService = Provider.of<AlertService>(context, listen: false);
    final inventoryProvider = Provider.of<VendorInventoryProvider>(context, listen: false);

    orderProvider.addListener(() {
      // Sync vendor ID to inventory provider once profile is loaded
      if (orderProvider.profile != null) {
        inventoryProvider.linkVendor(orderProvider.profile!.id);
      }
      
      // Get all relevant orders for notification (Pending or newly Accepted/Assigned)
      final relevantOrders = orderProvider.allOrders.where((o) => 
        (o.status == VendorOrderStatus.pending || o.status == VendorOrderStatus.accepted) && 
        !o.isNotified
      ).toList();

      if (relevantOrders.isNotEmpty) {
        for (final order in relevantOrders) {
          // Only show notification ONCE per order per session (redundancy check)
          if (_shownNotificationIds.contains(order.id)) {
            orderProvider.markAsNotified(order.id);
            continue;
          }
          
          // If the order is older than 5 minutes, don't show a notification on app start
          final age = DateTime.now().difference(order.timestamp);
          if (age.inMinutes > 5) {
            _shownNotificationIds.add(order.id);
            orderProvider.markAsNotified(order.id);
            continue;
          }

          _shownNotificationIds.add(order.id);
          orderProvider.markAsNotified(order.id); // Mark as notified in provider too

          // ✅ FIX: Pass the full order ID and parameters. This fixes action buttons and prevents duplicate notifications.
          final orderTypeStr = order.orderType == VendorOrderType.text
              ? 'Text'
              : (order.orderType == VendorOrderType.photo ? 'Photo' : 'Cart');
              
          alertService.playNewOrderAlert(
            order.id,
            orderType: orderTypeStr,
            customerName: order.customerName,
            amount: order.totalAmount,
          );

          break; // Process one new order notification at a time
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final bool hasNoInternet = results.isEmpty ||
        (results.length == 1 && results.first == ConnectivityResult.none);

    if (hasNoInternet) {
      if (!_isNoInternetDialogShowing) {
        _isNoInternetDialogShowing = true;
        _showNoInternetDialog();
      }
    } else {
      if (_isNoInternetDialogShowing) {
        _isNoInternetDialogShowing = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Column(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48),
              SizedBox(height: 12),
              Text(
                'No Internet Connection',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Namba Vendor needs an active internet connection to receive new orders. Please turn on Wi-Fi or Mobile Data.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              SizedBox(height: 12),
              Text(
                'புதிய ஆர்டர்களைப் பெற இணைய இணைப்பு தேவை. வைஃபை அல்லது மொபைல் டேட்டாவை ஆன் செய்யவும்.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 16),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final nav = Provider.of<NavigationProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBody: true,
      body: _screens[nav.selectedIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8), // Frosted White Glass
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 40,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(context, 0, Iconsax.grid_1, lang.translate('dashboard')),
                  _buildNavItem(context, 1, Iconsax.receipt_2, lang.translate('orders')),
                  _buildNavItem(context, 2, Iconsax.box, lang.translate('inventory')),
                  _buildNavItem(context, 3, Iconsax.profile_circle, lang.translate('profile')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final nav = Provider.of<NavigationProvider>(context, listen: false);
    final isSelected = nav.selectedIndex == index;
    return GestureDetector(
      onTap: () {
        nav.setIndex(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade600,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF2563EB),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

