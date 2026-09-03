import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'services/vendor_order_provider.dart';
import 'services/vendor_inventory_provider.dart';
import 'services/language_provider.dart';
import 'services/alert_service.dart';
import 'screens/dashboard/vendor_dashboard_screen.dart';
import 'screens/orders/vendor_orders_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'services/vendor_notification_service.dart';
import 'services/vendor_background_service.dart';
import 'screens/splash_screen.dart';
import 'services/navigation_provider.dart';
import 'models/vendor_order_model.dart';
import 'screens/profile/store_profile_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/theme_provider.dart';
import 'theme/app_theme.dart';

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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Namba Vendor',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: globalMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    VendorNotificationService.isMainShellActive = true;
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        VendorNotificationService().stopAlarmSound();
      } catch (_) {}
      _setupOrderListener();

      // ⚡ IMMEDIATELY route to pending notification order if any!
      await _checkPendingNotificationOrder();

      await _initNotifications();
    });
  }

  Future<void> _initNotifications() async {
    // 🔔 Request permission so new order pushes work
    await VendorNotificationService().initialize();

    if (Platform.isAndroid) {
      try {
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
      } catch (e) {
        debugPrint('Notification init error: $e');
      }
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
      
      // Get all relevant orders for notification (Pending or newly Accepted/Assigned and not yet notified)
      final relevantOrders = orderProvider.allOrders.where((o) => 
        (o.status == VendorOrderStatus.pending || o.status == VendorOrderStatus.accepted) &&
        !o.isNotified
      ).toList();

      if (relevantOrders.isNotEmpty) {
        for (final order in relevantOrders) {
          // If the order is older than 5 minutes, don't show a notification on app start
          final age = DateTime.now().difference(order.timestamp);
          if (age.inMinutes > 5) {
            orderProvider.markAsNotified(order.id);
            SharedPreferences.getInstance().then((prefs) {
              final list = prefs.getStringList('shown_notification_order_ids') ?? [];
              if (!list.contains(order.id)) {
                list.add(order.id);
                prefs.setStringList('shown_notification_order_ids', list);
              }
            }).catchError((e) {
              debugPrint('Error saving shown notification ID in background: $e');
            });
            continue;
          }

          // Mark as notified in the provider synchronously first!
          orderProvider.markAsNotified(order.id);

          // Save to SharedPreferences asynchronously in the background
          SharedPreferences.getInstance().then((prefs) {
            final list = prefs.getStringList('shown_notification_order_ids') ?? [];
            if (!list.contains(order.id)) {
              list.add(order.id);
              prefs.setStringList('shown_notification_order_ids', list);
            }
          }).catchError((e) {
            debugPrint('Error saving shown notification ID in background: $e');
          });

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

  Future<void> _checkPendingNotificationOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderId = prefs.getString('pending_notification_order_id');
      if (orderId != null && orderId.isNotEmpty) {
        // Clear it immediately to prevent duplicate runs
        await prefs.remove('pending_notification_order_id');
        final actionId = prefs.getString('pending_notification_action_id');
        if (actionId != null) {
          await prefs.remove('pending_notification_action_id');
        }

        if (mounted) {
          if (actionId == 'decline') {
            final provider = Provider.of<VendorOrderProvider>(context, listen: false);
            provider.refreshOrders();
          } else {
            VendorNotificationService.navigateToOrderDetails(orderId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking pending notification order: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        VendorNotificationService().stopAlarmSound();
      } catch (_) {}
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _checkPendingNotificationOrder();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VendorNotificationService.isMainShellActive = false;
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
      // ⚡ Reconnected to internet: trigger instant sync & socket reconnect!
      try {
        final orderProvider = Provider.of<VendorOrderProvider>(context, listen: false);
        orderProvider.reconnectAndSync();
      } catch (e) {
        debugPrint('Error on connectivity reconnect: $e');
      }
    }
  }

  void _showNoInternetDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: isDark ? const BorderSide(color: Color(0xFF273552), width: 1.5) : BorderSide.none,
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'No Internet Connection',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Namba Vendor needs an active internet connection to receive new orders. Please turn on Wi-Fi or Mobile Data.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'புதிய ஆர்டர்களைப் பெற இணைய இணைப்பு தேவை. வைஃபை அல்லது மொபைல் டேட்டாவை ஆன் செய்யவும்.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final nav = Provider.of<NavigationProvider>(context);
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Step 1: If on Profile/Orders/Inventory (not Dashboard Tab 0), step back to Dashboard Tab 0
        if (nav.selectedIndex != 0) {
          nav.setIndex(0);
          return;
        }

        // Step 2: On Dashboard Tab 0 -> Double Tap Back to exit logic
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Press back again to exit / வெளியேற மீண்டும் அழுத்தவும்',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          return;
        }

        // Confirmed double press within 2s -> exit app
        const platform = MethodChannel('com.namba.vendor/app');
        try {
          await platform.invokeMethod('moveTaskToBack');
        } catch (_) {
          SystemNavigator.pop();
        }
      },
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            extendBody: true,
            body: _screens[nav.selectedIndex],
            bottomNavigationBar: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131B2E).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(
                          color: isDark ? const Color(0xFF273552) : Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
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
            ),
          );
        },
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

