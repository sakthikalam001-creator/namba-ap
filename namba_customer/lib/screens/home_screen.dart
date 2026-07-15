import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
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
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    _startBannerTimer();
    _fetchLiveVendors();
    _initSocket();
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
            }
          });
        } else if (data['type'] == 'vendor_new_live') {
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
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveVendors() async {
    setState(() => _isLoadingStores = true);
    final vendors = await _apiService.getNearbyVendors(13.0827, 80.2707, radius: 20);
    final List<Store> mappedStores = [];
    for (final v in vendors) {
      final id = v['_id'] as String;
      final rawProducts = await _apiService.getVendorProducts(id);
      final products = rawProducts.map((p) => Product(
        id: p['_id'], name: p['name'], price: (p['price'] as num).toDouble(),
        unit: p['category'] ?? 'unit', imageUrl: p['image'], storeId: id,
      )).toList();

      mappedStores.add(Store(
        id: id, name: v['storeName'] ?? 'Store', category: v['category'] ?? 'Grocery',
        description: 'Quality Goods', ownerPhone: '9876543210', rating: 4.8, deliveryTime: 25,
        distanceKm: 2.0, photoUrls: ['https://images.unsplash.com/photo-1542838132-92c53300491e?w=800'],
        products: products, isOpen: v['isOpen'] ?? true, hasItemList: products.isNotEmpty,
      ));
    }
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
      body: Stack(
        children: [
          pages[_tab],
          Positioned(left: 0, right: 0, bottom: 0, child: _buildPremiumBottomNav(cart)),
        ],
      ),
    );
  }

  Widget _buildPremiumBottomNav(CartProvider cart) {
    const Color primary = Color(0xFF4F46E5);
    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10))],
        ),
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

    return RefreshIndicator(
      onRefresh: _fetchLiveVendors,
      color: const Color(0xFF4F46E5),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSuperHeader(auth, notif),
          SliverToBoxAdapter(child: _buildSuperPromos()),
          SliverToBoxAdapter(child: _buildBentoCategories()),
          if (orders.activeOrders.isNotEmpty) SliverToBoxAdapter(child: _buildLiveTrackingBar(orders)),
          if (orders.orders.any((o) => o.status == OrderStatus.delivered && (o.userRating == null || o.userRating == 0.0) && o.placedAt.isAfter(DateTime.now().subtract(const Duration(hours: 48))))) 
            SliverToBoxAdapter(child: _buildUnratedOrderBar(orders)),
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
      ),
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
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      expandedHeight: 160,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(20, 45, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DELIVERING TO', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                        Row(children: [
                          Text(auth.address.split(',').first, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1F2937))),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4F46E5)),
                        ]),
                      ],
                    ),
                  ),
                  _iconBtn(Iconsax.notification_copy, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())), hasBadge: notif.unreadCount > 0),
                  const SizedBox(width: 12),
                  _iconBtn(Iconsax.user_copy, () => setState(() => _tab = 3)),
                ],
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
          child: _buildSearchBar(),
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

  Widget _buildSuperPromos() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: PageView(
        controller: _bannerCtrl,
        onPageChanged: (i) => setState(() => _bannerIndex = i),
        children: [
          _promoCard('Fresh Grocery', 'UP TO 50% OFF', 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800'),
          _promoCard('Elite Bakery', 'MORNING FRESH', 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=800'),
          _promoCard('Quick Pharma', 'HEALTH CARE', 'https://images.unsplash.com/photo-1583421171928-847bbad1ec9b?w=800'),
        ],
      ),
    );
  }

  Widget _promoCard(String title, String tag, String img) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), image: DecorationImage(image: NetworkImage(img), fit: BoxFit.cover)),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)])),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tag, style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
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
              if (store.isOpen) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('LIVE', style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 4),
            Text(store.category.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1)),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
              const SizedBox(width: 4),
              Text('${store.rating}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(width: 16),
              const Icon(Iconsax.clock_copy, color: Colors.grey, size: 14),
              const SizedBox(width: 4),
              Text('${store.deliveryTime} min', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
            ]),
          ])),
        ]),
      ),
    );
  }
}
