import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/notification_provider.dart';
import 'store_listing_screen.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'order_details_screen.dart';
import 'profile_screen.dart';
import 'payment_screen.dart';
import 'notifications_screen.dart';
import 'store_detail_screen.dart';
import 'map_pin_order_screen.dart';
import 'order_tracking_screen.dart';
import 'offers_screen.dart';
import 'package:latlong2/latlong.dart';
import 'map_location_picker_screen.dart';
import '../services/location_accuracy_service.dart';
import '../services/notification_service.dart';
import '../widgets/order_rating_sheet.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';
import '../services/delivery_hub_service.dart';

class HomeScreen extends StatefulWidget {
  final bool autoOpenLocationSheet;
  const HomeScreen({super.key, this.autoOpenLocationSheet = false});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  int _bannerIndex = 0;
  DateTime? _lastPressedAt;
  final PageController _bannerCtrl = PageController();
  Timer? _bannerTimer;
  final CustomerApiService _apiService = CustomerApiService();
  List<Map<String, dynamic>> _activeAds = [];
  List<Store> _liveStores = [];
  bool _isLoadingStores = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  double _adminCustomOrderRadiusKm = 10.0;
  String _matchedHubName = 'Erode Central Hub';
  bool _isUserOutOfHubRange = false;
  double _distanceToMatchedHubKm = 0.0;
  String? _lastTrackedAddressId;
  bool _notificationsEnabled = true;
  bool _isNotificationBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startBannerTimer();
    _fetchLiveVendors();
    _fetchAds();
    _fetchAdminSettings();
    _initSocket();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().checkAndPromptNotificationPermission(context);
      _checkNotifications();
      _updateHubForCurrentLocation();
    });
  }

  Future<void> _checkNotifications() async {
    final enabled = await NotificationService().areNotificationsEnabled();
    if (mounted) {
      setState(() => _notificationsEnabled = enabled);
    }
  }

  void _updateHubForCurrentLocation() {
    if (!mounted) return;
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final double lat = (LocationAccuracyService.lastKnownAccuratePosition != null &&
              LocationAccuracyService.lastKnownAccuratePosition!.latitude != 0.0)
          ? LocationAccuracyService.lastKnownAccuratePosition!.latitude
          : (auth.selectedAddress.lat != null && auth.selectedAddress.lat != 0.0
              ? auth.selectedAddress.lat!
              : 11.3410);
      final double lng = (LocationAccuracyService.lastKnownAccuratePosition != null &&
              LocationAccuracyService.lastKnownAccuratePosition!.longitude != 0.0)
          ? LocationAccuracyService.lastKnownAccuratePosition!.longitude
          : (auth.selectedAddress.lng != null && auth.selectedAddress.lng != 0.0
              ? auth.selectedAddress.lng!
              : 77.7172);

      final match = DeliveryHubService.matchLocation(lat, lng);
      if (mounted) {
        setState(() {
          _adminCustomOrderRadiusKm = match.hub.radiusKm;
          _matchedHubName = match.hub.name;
          _isUserOutOfHubRange = !match.isInRange;
          _distanceToMatchedHubKm = match.distanceKm;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchAdminSettings() async {
    try {
      await DeliveryHubService.fetchHubs(forceRefresh: true);
      _updateHubForCurrentLocation();
    } catch (_) {}
  }

  Future<void> _fetchAds() async {
    try {
      final rawAds = await _apiService.getAds();
      if (mounted) {
        setState(() {
          _activeAds = List<Map<String, dynamic>>.from(rawAds);
        });
      }
    } catch (e) {
      print('Fetch Ads Error in HomeScreen: $e');
    }
  }

  void _initSocket() {
    _apiService.initSocket((data) {
      if (mounted) {
        if (data['type'] == 'vendor_status') {
          final vid = data['vendorId'];
          final isOpen = data['isOpen'];
          setState(() {
            final idx = _liveStores.indexWhere((s) => s.id == vid);
            if (idx != -1) {
              _liveStores[idx] = _liveStores[idx].copyWith(isOpen: isOpen);
              _liveStores.sort((a, b) {
                if (a.isOpen && !b.isOpen) return -1;
                if (!a.isOpen && b.isOpen) return 1;
                return 0;
              });
            }
          });
        } else if (data['type'] == 'vendor_new_live' || data['type'] == 'vendor_updated' || data['type'] == 'inventory_update') {
          _fetchLiveVendors();
        }
      }
    });
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_bannerCtrl.hasClients) {
        int nextPage = _bannerIndex + 1;
        if (nextPage >= 3) nextPage = 0;
        _bannerCtrl.animateToPage(nextPage, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotifications();
      _fetchLiveVendors();
    }
  }

  Future<void> _fetchLiveVendors() async {
    setState(() => _isLoadingStores = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final double lat = auth.selectedAddress.lat ?? 11.3410;
    final double lng = auth.selectedAddress.lng ?? 77.7172;
    final int searchRadius = _adminCustomOrderRadiusKm > 0 ? _adminCustomOrderRadiusKm.toInt() : 15;
    final vendors = await _apiService.getNearbyVendors(lat, lng, radius: searchRadius);
    final List<Store> mappedStores = [];
    for (final v in vendors) {
      final id = v['_id'] as String;

      mappedStores.add(Store(
        id: id, name: v['storeName'] ?? 'Store', category: v['category'] ?? 'Grocery',
        description: 'Quality Goods', ownerPhone: '9876543210', rating: 4.8, deliveryTime: 25,
        distanceKm: 2.0, photoUrls: ['https://images.unsplash.com/photo-1542838132-92c53300491e?w=800'],
        products: [], isOpen: v['isOpen'] ?? true, hasItemList: false,
      ));
    }
    mappedStores.sort((a, b) {
      if (a.isOpen && !b.isOpen) return -1;
      if (!a.isOpen && b.isOpen) return 1;
      return 0;
    });
    setState(() { _liveStores = mappedStores; _isLoadingStores = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final cart = Provider.of<CartProvider>(context);
    final orders = Provider.of<OrderProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<CustomerLanguageProvider>(context);

    final String currentAddrKey = '${auth.selectedAddress.id}_${auth.selectedAddress.lat}_${auth.selectedAddress.lng}';
    if (_lastTrackedAddressId != currentAddrKey) {
      _lastTrackedAddressId = currentAddrKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateHubForCurrentLocation();
      });
    }

    final pages = [
      _buildHome(auth, cart, orders),
      const OffersScreen(),
      const OrderHistoryScreen(),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_tab != 0) {
          setState(() {
            _tab = 0;
          });
          return;
        }
        final now = DateTime.now();
        if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Provider.of<CustomerLanguageProvider>(context, listen: false).isTamil ? 'வெளியேற மீண்டும் அழுத்தவும்' : Provider.of<CustomerLanguageProvider>(context, listen: false).isTanglish ? 'Veliyeera meendum press seiyavum' : 'Press back again to exit',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1F2937),
            ),
          );
          return;
        }
        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBg,
        body: pages[_tab],
        bottomNavigationBar: _buildPremiumBottomNav(cart, theme, lang),
      ),
    );
  }

  Widget _buildPremiumBottomNav(CartProvider cart, ThemeProvider theme, CustomerLanguageProvider lang) {
    const Color primary = Color(0xFF4F46E5);
    final isDark = theme.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: theme.navBg,
        border: Border(top: BorderSide(color: theme.borderCol)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navBtn(0, Iconsax.home_1_copy, lang.translate('home'), primary, theme),
              _navBtn(1, Iconsax.discount_shape_copy, lang.translate('offers'), primary, theme),
              _cartBtn(cart, primary),
              _navBtn(2, Iconsax.receipt_2_copy, lang.translate('orders'), primary, theme),
              _navBtn(3, Iconsax.user_copy, lang.translate('profile'), primary, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(int idx, IconData icon, String label, Color primary, ThemeProvider theme) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? primary.withOpacity(theme.isDarkMode ? 0.2 : 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: active ? primary : (theme.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400), size: 24),
      ),
    );
  }

  Widget _cartBtn(CartProvider cart, Color primary) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Iconsax.shopping_cart_copy, color: Colors.grey.shade400, size: 24),
          if (cart.itemCount > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHome(AuthProvider auth, CartProvider cart, OrderProvider orders) {
    final notif = Provider.of<NotificationProvider>(context);
    
    final filteredStores = _liveStores.where((s) {
      final name = s.name.toLowerCase();
      final cat = s.category.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || cat.contains(query);
    }).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
          _buildSuperHeader(auth, notif),
          SliverToBoxAdapter(child: _buildSuperPromos()),
          SliverToBoxAdapter(child: _buildBentoCategories()),
          SliverToBoxAdapter(child: _buildQuoteBannerCard(orders)),
          SliverToBoxAdapter(child: _buildSectionHeader(_searchQuery.isEmpty ? Provider.of<CustomerLanguageProvider>(context).translate('explore_nearby') : Provider.of<CustomerLanguageProvider>(context).translate('search_results'))),
          if (_isLoadingStores) 
            SliverPadding(padding: const EdgeInsets.all(20), sliver: SliverList(delegate: SliverChildBuilderDelegate((_, __) => const ShimmerStoreTile(), childCount: 3)))
          else if (filteredStores.isEmpty && _searchQuery.isNotEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.search_status_copy, size: 60, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('No stores found for "$_searchQuery"', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
                if (i == filteredStores.length) return const SizedBox(height: 120);
                return _buildSuperStoreCard(filteredStores[i]);
              }, childCount: filteredStores.length + 1)),
            ),
        ],
      );
  }

  Widget _buildQuoteBannerCard(OrderProvider orders) {
    // Find active order waiting for customer payment.
    // Standard cart orders: payment pending from start (totalAmount > 0 && !isPaymentDone)
    // Custom / Map Pin orders: show ONLY when rider/vendor has quoted the items bill!
    final pendingQuoteOrder = orders.orders.cast<DeliveryOrder?>().firstWhere(
      (o) {
        if (o == null) return false;
        if (o.isPaymentDone || o.status == OrderStatus.delivered || o.status == OrderStatus.rejected) {
          return false;
        }

        final bool isCustom = o.orderType != OrderType.standard || o.isCustomStore;
        if (isCustom) {
          // For custom / map-pin orders, DO NOT show banner card until rider quotes the items bill
          final double itemsCost = o.items.fold(0.0, (sum, i) => sum + i.total) > 0 
              ? o.items.fold(0.0, (sum, i) => sum + i.total) 
              : o.subTotal;
          final bool hasQuote = itemsCost > 0 || (o.billPhotoPath != null && o.billPhotoPath!.isNotEmpty);
          return hasQuote && o.totalAmount > 0;
        } else {
          // For standard store cart orders
          return o.totalAmount > 0;
        }
      },
      orElse: () => null,
    );

    if (pendingQuoteOrder == null) return const SizedBox.shrink();
    final o = pendingQuoteOrder;

    final bool isQuoteOrder = o.orderType != OrderType.standard || o.isCustomStore;
    final String displayName = o.customStoreName?.isNotEmpty == true 
        ? o.customStoreName! 
        : (o.storeName.isNotEmpty ? o.storeName : "Pinned Shop Location");

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: o.id))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Iconsax.receipt_2_copy, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isQuoteOrder ? 'QUOTE RECEIVED' : 'PAYMENT PENDING',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('ID: ${o.displayId}', style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isQuoteOrder ? '$displayName sent a bill quote' : 'Complete payment for $displayName',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL BILL AMOUNT', style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      Text(
                        '₹${o.totalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Text('PAY NOW', style: GoogleFonts.outfit(color: const Color(0xFF4F46E5), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, color: Color(0xFF4F46E5), size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnratedOrderBar(OrderProvider orders) {
    final o = orders.orders.firstWhere((o) => o.status == OrderStatus.delivered && (o.userRating == null || o.userRating == 0.0) && o.placedAt.isAfter(DateTime.now().subtract(const Duration(hours: 48))));
    
    return GestureDetector(
      onTap: () => OrderRatingSheet.show(context, o),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]), 
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.35), blurRadius: 15, offset: const Offset(0, 8))]
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DELIVERED • HOW WAS YOUR FOOD & RIDER?', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.85), fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text('Rate your order from ${o.storeName}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              'Tap to submit real rating, compliments & tip rider ★',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11.5, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(padding: const EdgeInsets.all(20), child: Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: theme.textPrimary)));
  }

  Widget _buildSuperHeader(AuthProvider auth, NotificationProvider notif) {
    final theme = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<CustomerLanguageProvider>(context);
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 10),
        color: theme.scaffoldBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _showLocationSelectorSheet(context, auth);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.translate('delivering_to'), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: theme.textSecondary, letterSpacing: 1.5)),
                        Row(children: [
                          Flexible(
                            child: Text(
                              _getDisplayAddress(auth.address), 
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: theme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4F46E5)),
                        ]),
                      ],
                    ),
                  ),
                ),
                _iconBtn(Icons.translate_rounded, () => CustomerLanguageProvider.showLanguageModal(context)),
                const SizedBox(width: 8),
                _iconBtn(Iconsax.notification_copy, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())), hasBadge: notif.unreadCount > 0),
                const SizedBox(width: 8),
                _iconBtn(Iconsax.user_copy, () => setState(() => _tab = 3)),
              ],
            ),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildMapPinOrderQuickBanner(),
            _buildNotificationEnableBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationEnableBar() {
    if (_notificationsEnabled || _isNotificationBannerDismissed) {
      return const SizedBox.shrink();
    }
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3B1219) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Turn ON notifications for live store bill quotes & order tracking! / நோட்டிஃபிகேஷன் ஆன் செய்க 🔔',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF991B1B),
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final granted = await NotificationService().requestNotificationPermission();
              if (!granted) {
                await NotificationService().openNotificationSettings();
              }
              await _checkNotifications();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ON', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => _isNotificationBannerDismissed = true),
            child: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPinOrderQuickBanner() {
    final lang = Provider.of<CustomerLanguageProvider>(context);
    final int radiusKm = _adminCustomOrderRadiusKm.toInt();
    final String hubDisplay = _matchedHubName.toUpperCase();

    final String promiseMsg = lang.isTamil
        ? (_isUserOutOfHubRange
            ? 'தற்போது $_matchedHubName எல்லைக்குள் ($radiusKm km) மட்டுமே சேவை வழங்கப்படுகிறது.'
            : '$radiusKm km-க்குள் நீங்கள் கேட்கும் எந்த பொருளையும் எந்த கடையிலிருந்தும் வாங்கி வந்து தருகிறோம்!')
        : lang.isTanglish
            ? (_isUserOutOfHubRange
                ? 'Tharpothu $_matchedHubName ellaikulla ($radiusKm km) mattumae service kedaikkum.'
                : '$radiusKm km kulla neenga kekura entha porulayum entha kadayila irundhum vangi vandhu tharom!')
            : (_isUserOutOfHubRange
                ? 'Currently service is available within $radiusKm km of $_matchedHubName.'
                : 'We buy and deliver any item you request from any shop within $radiusKm km!');

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MapPinOrderScreen()),
      ),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF090D1A), Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: _isUserOutOfHubRange
                ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                : const Color(0xFF10B981).withValues(alpha: 0.35),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isUserOutOfHubRange ? const Color(0xFFEF4444) : const Color(0xFF4F46E5))
                  .withValues(alpha: 0.24),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background ambient pattern elements
            Positioned(
              right: -20,
              top: -25,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -15,
              bottom: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withValues(alpha: 0.09),
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Tags Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dynamic Range Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isUserOutOfHubRange
                                ? const [Color(0xFFDC2626), Color(0xFFEF4444)]
                                : const [Color(0xFF059669), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: (_isUserOutOfHubRange
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF10B981))
                                  .withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isUserOutOfHubRange ? Icons.warning_amber_rounded : Icons.bolt_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isUserOutOfHubRange
                                  ? 'OUT OF RANGE'
                                  : '$radiusKm KM SERVICE RANGE',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Location Hub Tag Pill
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, color: Color(0xFF34D399), size: 13),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  hubDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFE2E8F0),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Main Title Row
                  Row(
                    children: [
                      // Icon with Glow
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                        ),
                        child: const Center(
                          child: Icon(Icons.location_searching_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Text Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📍 MAP PIN PICKUP ORDER',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Pick any shop or location on live map',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),

                  // Prominent Promise Message Box (Admin Range Verified)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: _isUserOutOfHubRange ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          width: 3.5,
                        ),
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        right: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1.5),
                          child: Icon(
                            _isUserOutOfHubRange ? Icons.info_outline_rounded : Icons.verified_rounded,
                            color: _isUserOutOfHubRange ? const Color(0xFFFCA5A5) : const Color(0xFF34D399),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            promiseMsg,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFF1F5F9),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bottom Action Button Row
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.touch_app_rounded, color: Color(0xFF34D399), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'PIN ANY LOCATION ON MAP',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'ORDER NOW',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF34D399),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, color: Color(0xFF34D399), size: 14),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {bool hasBadge = false}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.borderCol),
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Icon(icon, size: 20, color: theme.textPrimary),
          if (hasBadge) Positioned(right: -2, top: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle))),
        ]),
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<CustomerLanguageProvider>(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.inputBg, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: theme.borderCol),
      ),
      child: Row(
        children: [
          Icon(Iconsax.search_normal_copy, color: theme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.outfit(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: lang.translate('search_hint'),
                hintStyle: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
            ),
          const SizedBox(width: 8),
          const Icon(Iconsax.setting_4_copy, color: Color(0xFF4F46E5), size: 18),
        ],
      ),
    );
  }

  String _getDisplayAddress(String fullAddress) {
    if (fullAddress.isEmpty || fullAddress.toLowerCase().contains('fetching')) return 'Detecting location...';
    final parts = fullAddress.split(',');
    if (parts.first.length <= 3 && parts.length > 1) {
      return '${parts[0]}, ${parts[1]}'.trim();
    }
    return parts.first.trim();
  }

  Widget _buildSuperPromos() {
    final hasRealAds = _activeAds.isNotEmpty;
    final bannerCount = hasRealAds ? _activeAds.length : 3;

    return Column(
      children: [
        Container(
          height: 160,
          margin: const EdgeInsets.only(top: 10, bottom: 12),
          child: PageView.builder(
            controller: _bannerCtrl,
            itemCount: bannerCount,
            onPageChanged: (i) => setState(() => _bannerIndex = i),
            itemBuilder: (context, index) {
              if (hasRealAds) {
                final ad = _activeAds[index];
                final adId = (ad['_id'] ?? ad['id'] ?? '').toString();
                final title = (ad['title'] ?? 'Featured Offer').toString();
                final subtitle = (ad['subtitle'] ?? '').toString();
                final offerTag = (ad['offerTag'] ?? '🔥 SPECIAL OFFER').toString();
                final img = (ad['imageUrl'] ?? '').toString();
                final gradient = ad['gradient'];
                final ctaText = (ad['ctaText'] ?? 'ORDER NOW').toString();
                final fontFamily = (ad['fontFamily'] ?? 'Outfit').toString();
                final fontSize = (ad['fontSize'] as num?)?.toDouble() ?? 18.0;
                final alignmentStr = (ad['alignment'] ?? 'left').toString();

                String storeName = '';
                final vendorObj = ad['vendor'];
                if (vendorObj != null && vendorObj is Map<String, dynamic>) {
                  storeName = (vendorObj['storeName'] ?? vendorObj['name'] ?? '').toString();
                }

                return GestureDetector(
                  onTap: () {
                    if (adId.isNotEmpty) {
                      _apiService.trackAdClick(adId);
                    }
                    if (vendorObj != null && vendorObj is Map<String, dynamic>) {
                      final storeObj = Store.fromMap(vendorObj);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StoreDetailScreen(store: storeObj)),
                      );
                    }
                  },
                  child: _promoCard(
                    title: title,
                    subtitle: subtitle,
                    offerTag: offerTag,
                    img: img,
                    storeName: storeName,
                    gradient: gradient,
                    ctaText: ctaText,
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    alignmentStr: alignmentStr,
                  ),
                );
              } else {
                if (index == 0) return _promoCard(title: 'Fresh Grocery', offerTag: 'UP TO 50% OFF', subtitle: 'Farm fresh veggies & fruits at best price', img: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800');
                if (index == 1) return _promoCard(title: 'Elite Bakery', offerTag: 'MORNING FRESH', subtitle: 'Hot bakes, cakes & puffs daily', img: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=800');
                return _promoCard(title: 'Quick Pharma', offerTag: 'HEALTH CARE', subtitle: 'Medicines & wellness essentials delivered fast', img: 'https://images.unsplash.com/photo-1583421171928-847bbad1ec9b?w=800');
              }
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(bannerCount, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _bannerIndex == i ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _bannerIndex == i ? const Color(0xFF4F46E5) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          )),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  TextStyle _getBannerTextStyle({
    required String fontFamily,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
  }) {
    switch (fontFamily) {
      case 'Poppins':
        return GoogleFonts.poppins(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);
      case 'Montserrat':
        return GoogleFonts.montserrat(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);
      case 'Inter':
        return GoogleFonts.inter(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);
      case 'Playfair':
        return GoogleFonts.playfairDisplay(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);
      case 'Outfit':
      default:
        return GoogleFonts.outfit(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);
    }
  }

  Widget _promoCard({
    required String title,
    required String offerTag,
    required String img,
    String subtitle = '',
    String storeName = '',
    dynamic gradient,
    String ctaText = 'ORDER NOW',
    String fontFamily = 'Outfit',
    double fontSize = 18.0,
    String alignmentStr = 'left',
  }) {
    List<Color> gradientColors = [const Color(0xFF1E1B4B), const Color(0xFF4338CA)];
    if (gradient is List && gradient.isNotEmpty) {
      try {
        gradientColors = gradient.map((c) {
          if (c is String) {
            final hex = c.replaceAll('#', '');
            return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
          }
          return const Color(0xFF4F46E5);
        }).toList();
      } catch (_) {}
    }

    final alignment = alignmentStr == 'center' ? TextAlign.center : (alignmentStr == 'right' ? TextAlign.right : TextAlign.left);
    final crossAlign = alignmentStr == 'center' ? CrossAxisAlignment.center : (alignmentStr == 'right' ? CrossAxisAlignment.end : CrossAxisAlignment.start);

    String resolvedImgUrl = img;
    if (resolvedImgUrl.isNotEmpty && !resolvedImgUrl.startsWith('http')) {
      final serverRoot = 'http://54.204.9.126:5000';
      if (!resolvedImgUrl.startsWith('/')) resolvedImgUrl = '/$resolvedImgUrl';
      resolvedImgUrl = '$serverRoot$resolvedImgUrl';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (resolvedImgUrl.isNotEmpty && resolvedImgUrl.startsWith('http'))
              Image.network(
                resolvedImgUrl,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(color: gradientColors.first),
              )
            else
              Container(color: gradientColors.first),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    gradientColors.first.withValues(alpha: img.isNotEmpty ? 0.35 : 0.95),
                    gradientColors.length > 1
                        ? gradientColors[1].withValues(alpha: img.isNotEmpty ? 0.78 : 0.95)
                        : Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: crossAlign,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (storeName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, color: Colors.white, size: 11),
                              const SizedBox(width: 4),
                              Text(
                                storeName,
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          offerTag,
                          style: GoogleFonts.outfit(color: const Color(0xFFFDE047), fontWeight: FontWeight.w900, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: crossAlign,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        textAlign: alignment,
                        overflow: TextOverflow.ellipsis,
                        style: _getBannerTextStyle(
                          fontFamily: fontFamily,
                          fontSize: fontSize.clamp(14.0, 19.0),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          textAlign: alignment,
                          overflow: TextOverflow.ellipsis,
                          style: _getBannerTextStyle(
                            fontFamily: fontFamily,
                            fontSize: (fontSize * 0.62).clamp(10.5, 12.5),
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoCategories() {
    final cats = [
      {'l': 'Grocery', 'i': Iconsax.shop_copy, 'c': const Color(0xFF6366F1)},
      {'l': 'Bakery', 'i': Iconsax.cake_copy, 'c': const Color(0xFFEC4899)},
      {'l': 'Pharma', 'i': Iconsax.health_copy, 'c': const Color(0xFF10B981)},
      {'l': 'Food', 'i': Iconsax.ranking_copy, 'c': const Color(0xFFF59E0B)},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: cats.map((e) => _catItem(e['l'] as String, e['i'] as IconData, e['c'] as Color)).toList()),
    );
  }

  Widget _catItem(String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreListingScreen(category: label))),
      child: Column(children: [
        Container(width: 68, height: 68, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.1))), child: Icon(icon, color: color, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: Provider.of<ThemeProvider>(context, listen: false).textPrimary)),
      ]),
    );
  }

  Widget _buildLiveTrackingBar(OrderProvider orders) {
    final o = orders.activeOrders.first;
    final bool isActionRequired = o.orderType != OrderType.standard && o.totalAmount > 0 && !o.isPaymentDone;

    final List<Color> bgColors = isActionRequired 
        ? [const Color(0xFF6366F1), const Color(0xFF818CF8)]
        : [const Color(0xFF4F46E5), const Color(0xFF818CF8)];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => isActionRequired ? OrderDetailsScreen(orderId: o.id) : OrderTrackingScreen(order: o))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bgColors), 
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [BoxShadow(color: bgColors.first.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
        ),
        child: Row(children: [
          Icon(isActionRequired ? Iconsax.notification_copy : Iconsax.routing_copy, color: Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isActionRequired ? 'ACTION REQUIRED' : 'ACTIVE DELIVERY', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text(isActionRequired ? 'Accept Quote & Pay for ${o.storeName}' : o.storeName, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              o.textContent ?? o.items.map((i) => '${i.quantity}x ${i.product.name}').join(', '),
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
        ]),
      ),
    );
  }

  Widget _buildSuperStoreCard(Store store) {
    Widget cardContent = Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Provider.of<ThemeProvider>(context, listen: false).cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Provider.of<ThemeProvider>(context, listen: false).borderCol),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(Provider.of<ThemeProvider>(context, listen: false).isDarkMode ? 0.25 : 0.03), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Hero(
          tag: 'store_${store.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: (store.photoUrls.isNotEmpty && store.photoUrls.first.startsWith('http')) 
              ? Image.network(
                  store.photoUrls.first, 
                  width: 80, 
                  height: 80, 
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(width: 80, height: 80, color: Colors.grey.shade100, child: const Icon(Icons.store, color: Colors.grey)),
                )
              : Container(width: 80, height: 80, color: Colors.grey.shade100, child: const Icon(Icons.store, color: Colors.grey)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(store.isOpen ? store.name : '${store.name} (CLOSED)', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: store.isOpen ? Provider.of<ThemeProvider>(context, listen: false).textPrimary : Colors.grey.shade500))),
            if (store.isOpen) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('OPEN', style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w900)))
            else Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('CLOSED', style: GoogleFonts.outfit(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 4),
          Text(store.category.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
            const SizedBox(width: 4),
            Text('${store.rating}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(width: 16),
          ]),
        ])),
      ]),
    );

    if (!store.isOpen) {
      cardContent = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: Opacity(
          opacity: 0.65,
          child: cardContent,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (!store.isOpen) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${store.name} is currently CLOSED!'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 1500),
            ),
          );
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(store: store)));
      },
      child: cardContent,
    );
  }

  void _showLocationSelectorSheet(BuildContext context, AuthProvider auth, {int initialStep = 0}) async {
    int step = initialStep;
    Position? gpsPos;
    bool isFetchingGps = false;
    String selectedLabel = 'Home';
    final doorNoCtrl = TextEditingController();
    final streetCtrl = TextEditingController();

    if (initialStep == 1) {
      isFetchingGps = true;
      try {
        gpsPos = await LocationAccuracyService.getBestPosition(
          targetAccuracyMeters: 20,
          maxUsableAccuracyMeters: 100,
          quickFixTimeout: const Duration(seconds: 3),
          refineTimeout: const Duration(seconds: 5),
        );
      } catch (_) {}
      isFetchingGps = false;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (step == 1 && gpsPos == null && !isFetchingGps) {
            isFetchingGps = true;
            LocationAccuracyService.getBestPosition(
              targetAccuracyMeters: 20,
              maxUsableAccuracyMeters: 100,
              quickFixTimeout: const Duration(seconds: 3),
              refineTimeout: const Duration(seconds: 5),
            ).then((pos) {
              setSheetState(() {
                gpsPos = pos;
                isFetchingGps = false;
              });
            }).catchError((_) {
              setSheetState(() {
                isFetchingGps = false;
              });
            });
          }

          final sheetTheme = Provider.of<ThemeProvider>(context, listen: false);
          final isSheetDark = sheetTheme.isDarkMode;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: sheetTheme.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(top: BorderSide(color: sheetTheme.borderCol)),
              ),
              child: SingleChildScrollView(
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: step == 0 ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: isSheetDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Select Delivery Location', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: sheetTheme.textPrimary)),
                    const SizedBox(height: 16),
                    
                    // Live GPS Current Location Option (Opens Map Picker directly)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        final lastPos = LocationAccuracyService.lastKnownAccuratePosition;
                        final initialLoc = (lastPos != null && lastPos.latitude != 0.0)
                            ? LatLng(lastPos.latitude, lastPos.longitude)
                            : (auth.selectedAddress.lat != null && auth.selectedAddress.lat != 0.0
                                ? LatLng(auth.selectedAddress.lat!, auth.selectedAddress.lng!)
                                : null);
                        final initialAddr = (LocationAccuracyService.lastKnownAddress != null && LocationAccuracyService.lastKnownAddress!.isNotEmpty)
                            ? LocationAccuracyService.lastKnownAddress!
                            : (auth.address.isNotEmpty ? auth.address : null);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapLocationPickerScreen(
                              initialLocation: initialLoc,
                              initialAddress: initialAddr,
                            ),
                          ),
                        ).then((_) {
                          if (mounted) _fetchLiveVendors();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
                              child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Use Current Location', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
                                  const SizedBox(height: 2),
                                  Text('Pin your exact GPS location on map & enter address', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF4F46E5)),
                          ],
                        ),
                      ),
                    ),

                    if (auth.addresses.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Saved Addresses', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
                      const SizedBox(height: 12),

                      // List of saved addresses
                      ...auth.addresses.map((addr) {
                        final isSelected = auth.selectedAddress.id == addr.id;
                        return GestureDetector(
                          onTap: () {
                            auth.selectAddress(addr.id);
                            _fetchLiveVendors();
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.12) : (isSheetDark ? sheetTheme.inputBg : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : sheetTheme.borderCol),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  addr.label == 'Home' ? Icons.home_rounded :
                                  addr.label == 'Work' ? Icons.work_rounded : Icons.location_on_rounded,
                                  color: isSelected ? const Color(0xFF4F46E5) : Colors.grey,
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(addr.label, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: sheetTheme.textPrimary)),
                                      Text(addr.address, style: GoogleFonts.outfit(fontSize: 12, color: sheetTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5), size: 20),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),

                // STEP 1: Complete Delivery Address Form
                secondChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setSheetState(() => step = 0),
                          icon: Icon(Icons.arrow_back_rounded, color: sheetTheme.textPrimary),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        Text('Complete Delivery Address', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: sheetTheme.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (gpsPos != null)
                      Row(
                        children: [
                          const Icon(Icons.gps_fixed_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text('Live GPS Position Locked',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Label Selector
                    Text('Save Address As *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: sheetTheme.textSecondary)),
                    const SizedBox(height: 10),
                    Row(
                      children: ['Home', 'Work', 'Other'].map((lbl) {
                        final isSel = selectedLabel == lbl;
                        final icon = lbl == 'Home' ? Icons.home_rounded : lbl == 'Work' ? Icons.work_rounded : Icons.location_on_rounded;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedLabel = lbl),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF4F46E5) : (isSheetDark ? sheetTheme.inputBg : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isSel ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 8)] : [],
                            ),
                            child: Row(
                              children: [
                                Icon(icon, size: 16, color: isSel ? Colors.white : (isSheetDark ? sheetTheme.textSecondary : Colors.grey.shade600)),
                                const SizedBox(width: 6),
                                Text(lbl, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: isSel ? Colors.white : (isSheetDark ? sheetTheme.textSecondary : Colors.grey.shade700))),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Door No Field
                    Text('House / Flat / Door No. & Building Name *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: sheetTheme.textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: doorNoCtrl,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: sheetTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Door No 14, Lotus Apartments',
                        hintStyle: GoogleFonts.outfit(color: sheetTheme.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.home_work_rounded, color: Color(0xFF4F46E5), size: 20),
                        filled: true,
                        fillColor: sheetTheme.inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: sheetTheme.borderCol)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: sheetTheme.borderCol)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Street Field
                    Text('Street Name, Area or Landmark *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: sheetTheme.textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: streetCtrl,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: sheetTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Near Swastik Roundabout, Erode',
                        hintStyle: GoogleFonts.outfit(color: sheetTheme.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF4F46E5), size: 20),
                        filled: true,
                        fillColor: sheetTheme.inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: sheetTheme.borderCol)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: sheetTheme.borderCol)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Submit CTA
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final dNo = doorNoCtrl.text.trim();
                          final st = streetCtrl.text.trim();
                          if (dNo.isEmpty || st.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter your House/Door No. and Street address details.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          final fullAddress = "$dNo, $st";
                          final newAddr = UserAddress(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            label: selectedLabel,
                            address: fullAddress,
                            lat: gpsPos?.latitude ?? 11.3410,
                            lng: gpsPos?.longitude ?? 77.7172,
                          );

                          auth.addAddress(newAddr);
                          auth.selectAddress(newAddr.id);
                          Navigator.pop(ctx);
                          _fetchLiveVendors();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$selectedLabel Address Saved & Selected 📍'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        label: Text('Save Address & Start Ordering', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
}
