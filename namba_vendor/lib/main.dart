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
import 'screens/splash_screen.dart';
import 'services/navigation_provider.dart';
import 'models/vendor_order_model.dart';

import 'screens/profile/store_profile_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ BOOT: Env Loaded');
  } catch (e) {
    debugPrint('❌ BOOT: Env Load Failed: $e');
  }
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
      title: 'Namba Delivery Vendor',
      debugShowCheckedModeBanner: false,
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

  @override
  void initState() {
    super.initState();
    _initNotifications(); // Add this call
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupOrderListener();
    });
  }

  Future<void> _initNotifications() async {
    // 🔔 Request permission up front so new order pushes work
    await VendorNotificationService().initialize();
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

      if (relevantOrders.isNotEmpty && orderProvider.isInitialSyncComplete) {
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

          alertService.playNewOrderAlert(order.id.substring(order.id.length > 4 ? order.id.length - 4 : 0));

          // Capture the order in a local variable for the closure
          final capturedOrder = order;
          final isAssigned = capturedOrder.status == VendorOrderStatus.accepted;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VendorOrderDetailScreen(orderId: capturedOrder.id),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(isAssigned ? Iconsax.routing : Iconsax.box, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isAssigned ? 'Driver Assigned to Order!' : 'Pudhiya Order VandhuLLadhu!',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            Text(
                              'Order #${capturedOrder.id.substring(capturedOrder.id.length > 6 ? capturedOrder.id.length - 6 : 0)} from ${capturedOrder.customerName}',
                              style: GoogleFonts.outfit(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              backgroundColor: isAssigned ? AppTheme.accentBlue : AppTheme.primaryOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 15),
            ),
          );

          break; // Show one notification at a time
        }
      }
    });
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

