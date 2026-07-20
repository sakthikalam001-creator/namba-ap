import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/notification_provider.dart';
import 'store_listing_screen.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'order_details_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'store_detail_screen.dart';
import 'order_tracking_screen.dart';
import 'offers_screen.dart';
import 'map_location_picker_screen.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';

class HomeScreen extends StatefulWidget {
  final bool autoOpenLocationSheet;
  const HomeScreen({super.key, this.autoOpenLocationSheet = false});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  int _bannerIndex = 0;
  final PageController _bannerCtrl = PageController();
  Timer? _bannerTimer;
  final CustomerApiService _apiService = CustomerApiService();
  List<Store> _liveStores = [];
  bool _isLoadingStores = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startBannerTimer();
    _fetchLiveVendors();
    _initSocket();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (widget.autoOpenLocationSheet || !auth.hasSetLocation) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MapLocationPickerScreen(isInitialSetup: true))).then((_) => _fetchLiveVendors());
      }
    });
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
      _fetchLiveVendors();
    }
  }

  Future<void> _fetchLiveVendors() async {
    setState(() => _isLoadingStores = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final double lat = auth.selectedAddress.lat ?? 11.3410;
    final double lng = auth.selectedAddress.lng ?? 77.7172;
    final vendors = await _apiService.getNearbyVendors(lat, lng, radius: 20);
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

    final pages = [
      _buildHome(auth, cart, orders),
      const OffersScreen(),
      const OrderHistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: pages[_tab],
      bottomNavigationBar: _buildPremiumBottomNav(cart),
    );
  }

  Widget _buildPremiumBottomNav(CartProvider cart) {
    const Color primary = Color(0xFF4F46E5);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navBtn(0, Iconsax.home_1_copy, 'Home', primary),
              _navBtn(1, Iconsax.discount_shape_copy, 'Offers', primary),
              _cartBtn(cart, primary),
              _navBtn(2, Iconsax.receipt_2_copy, 'Orders', primary),
              _navBtn(3, Iconsax.user_copy, 'Profile', primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(int idx, IconData icon, String label, Color primary) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: active ? primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: active ? primary : Colors.grey.shade400, size: 24),
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
          SliverToBoxAdapter(child: _buildSectionHeader(_searchQuery.isEmpty ? 'Explore Nearby' : 'Search Results')),
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

  Widget _buildUnratedOrderBar(OrderProvider orders) {
    final o = orders.orders.firstWhere((o) => o.status == OrderStatus.delivered && (o.userRating == null || o.userRating == 0.0) && o.placedAt.isAfter(DateTime.now().subtract(const Duration(hours: 48))));
    
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: o))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)]), 
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
        ),
        child: Row(children: [
          const Icon(Iconsax.star_1_copy, color: Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DELIVERED - PLEASE RATE', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text('Rate your order from ${o.storeName}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              'Tap to rate your experience',
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

  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.all(20), child: Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1F2937))));
  }

  Widget _buildSuperHeader(AuthProvider auth, NotificationProvider notif) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 10),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapLocationPickerScreen())).then((_) => _fetchLiveVendors()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DELIVERING TO', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                        Row(children: [
                          Flexible(
                            child: Text(
                              _getDisplayAddress(auth.address), 
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1F2937)),
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
                _iconBtn(Iconsax.notification_copy, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())), hasBadge: notif.unreadCount > 0),
                const SizedBox(width: 12),
                _iconBtn(Iconsax.user_copy, () => setState(() => _tab = 3)),
              ],
            ),
            const SizedBox(height: 20),
            _buildSearchBar(),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {bool hasBadge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade100)),
        child: Stack(clipBehavior: Clip.none, children: [
          Icon(icon, size: 22, color: const Color(0xFF1F2937)),
          if (hasBadge) Positioned(right: -2, top: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle))),
        ]),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.search_normal_copy, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search stores, items...',
                hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500),
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
    if (fullAddress.isEmpty) return 'Select Address';
    final parts = fullAddress.split(',');
    if (parts.first.length <= 3 && parts.length > 1) {
      return '${parts[0]}, ${parts[1]}'.trim();
    }
    return parts.first.trim();
  }

  Widget _buildSuperPromos() {
    return Column(
      children: [
        Container(
          height: 160,
          margin: const EdgeInsets.only(top: 10, bottom: 12),
          child: PageView(
            controller: _bannerCtrl,
            onPageChanged: (i) => setState(() => _bannerIndex = i),
            children: [
              _promoCard('Fresh Grocery', 'UP TO 50% OFF', 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800'),
              _promoCard('Elite Bakery', 'MORNING FRESH', 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=800'),
              _promoCard('Quick Pharma', 'HEALTH CARE', 'https://images.unsplash.com/photo-1583421171928-847bbad1ec9b?w=800'),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) => AnimatedContainer(
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

  Widget _promoCard(String title, String tag, String img) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), image: DecorationImage(image: NetworkImage(img), fit: BoxFit.cover)),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.85)])),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tag, style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 2),
          Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
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
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937))),
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
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(store: store))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.grey.shade50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Row(children: [
          Hero(tag: 'store_${store.id}', child: Container(width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), image: DecorationImage(image: NetworkImage(store.photoUrls.first), fit: BoxFit.cover)))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(store.name, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF1F2937)))),
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
      ),
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
        gpsPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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
            Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((pos) {
              setSheetState(() {
                gpsPos = pos;
                isFetchingGps = false;
              });
            }).catchError((_) {
              setSheetState(() => isFetchingGps = false);
            });
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Select Delivery Location', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1F2937))),
                    const SizedBox(height: 16),
                    
                    // Live GPS Current Location Option
                    GestureDetector(
                      onTap: () async {
                        setSheetState(() => isFetchingGps = true);
                        try {
                          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                          setSheetState(() {
                            gpsPos = pos;
                            isFetchingGps = false;
                            step = 1;
                          });
                        } catch (e) {
                          setSheetState(() => isFetchingGps = false);
                          final success = await auth.useCurrentGpsLocation();
                          if (success && mounted) {
                            _fetchLiveVendors();
                            Navigator.pop(ctx);
                          }
                        }
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
                              child: isFetchingGps
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Use Current Location', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
                                  const SizedBox(height: 2),
                                  Text('Order from where you are right now (GPS)', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF4F46E5)),
                          ],
                        ),
                      ),
                    ),

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
                            color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.05) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade200),
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
                                    Text(addr.label, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1F2937))),
                                    Text(addr.address, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5), size: 20),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 12),

                    // Pick on Map CTA
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MapLocationPickerScreen())).then((_) => _fetchLiveVendors());
                        },
                        icon: const Icon(Icons.map_rounded, color: Color(0xFF4F46E5)),
                        label: Text('Set Location on Map', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        Text('Complete Delivery Address', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1F2937))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (gpsPos != null)
                      Row(
                        children: [
                          const Icon(Icons.gps_fixed_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text('GPS Location: ${gpsPos!.latitude.toStringAsFixed(4)}, ${gpsPos!.longitude.toStringAsFixed(4)}',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Label Selector
                    Text('Save Address As *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
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
                              color: isSel ? const Color(0xFF4F46E5) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isSel ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 8)] : [],
                            ),
                            child: Row(
                              children: [
                                Icon(icon, size: 16, color: isSel ? Colors.white : Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(lbl, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: isSel ? Colors.white : Colors.grey.shade700)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Door No Field
                    Text('House / Flat / Door No. & Building Name *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: doorNoCtrl,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Door No 14, Lotus Apartments',
                        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.home_work_rounded, color: Color(0xFF4F46E5), size: 20),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Street Field
                    Text('Street Name, Area or Landmark *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: streetCtrl,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Near Swastik Roundabout, Erode',
                        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF4F46E5), size: 20),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
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
