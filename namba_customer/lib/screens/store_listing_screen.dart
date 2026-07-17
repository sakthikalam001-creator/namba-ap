import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../data/mock_data.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';
import 'store_detail_screen.dart';
import '../services/api_service.dart';

class StoreListingScreen extends StatefulWidget {
  final String category;
  final Store? initialStore;
  const StoreListingScreen({super.key, required this.category, this.initialStore});
  @override
  State<StoreListingScreen> createState() => _StoreListingScreenState();
}

class _StoreListingScreenState extends State<StoreListingScreen> with WidgetsBindingObserver {
  Store? _selectedStore;
  final CustomerApiService _apiService = CustomerApiService();
  List<Store> _stores = [];
  bool _isLoading = true;

  Color get _catColor {
    switch (widget.category) {
      case 'Grocery': return const Color(0xFF059669);
      case 'Bakery': return const Color(0xFFDB2777);
      case 'Medicine': return const Color(0xFF2563EB);
      case 'Food': return const Color(0xFFD97706);
      default: return const Color(0xFF4F46E5);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedStore = widget.initialStore;
    _initSocket();
    _fetchStores();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchStores();
    }
  }

  void _initSocket() {
    _apiService.initSocket((data) {
      if (mounted) {
        if (data['type'] == 'vendor_status' || data['type'] == 'vendor_new_live' || data['type'] == 'vendor_updated' || data['type'] == 'inventory_update') {
          _fetchStores();
        }
      }
    });
  }

  Future<void> _fetchStores() async {
    setState(() => _isLoading = true);
    final vendors = await _apiService.getNearbyVendors(13.0827, 80.2707, radius: 20);
    
    final mappedStores = vendors.where((v) => v['category'] == widget.category).map((v) {
      final name = v['storeName'] ?? 'Store';
      final id = v['_id'];
      final distanceRaw = v['distance'] != null ? (v['distance'] / 1000).toDouble() : 2.0;

      return Store(
        id: id,
        name: name,
        category: widget.category,
        description: 'Quality ${widget.category} Items',
        ownerPhone: '9876543210',
        rating: 4.8,
        deliveryTime: 25,
        distanceKm: distanceRaw,
        photoUrls: ['https://images.unsplash.com/photo-1542838132-92c53300491e?w=800'],
        products: [],
        isOpen: v['isOpen'] ?? true,
      );
    }).toList();

    setState(() {
      _stores = mappedStores;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedStore != null) {
      // Small delay to prevent build errors during navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_selectedStore != null) {
          final store = _selectedStore!;
          setState(() => _selectedStore = null);
          Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(store: store)));
        }
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _catColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.category, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _stores.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No $widget.category stores found', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _stores.length,
              itemBuilder: (ctx, i) => _buildStoreCard(_stores[i]),
            ),
    );
  }

  Widget _buildStoreCard(Store store) {
    return GestureDetector(
      onTap: () => setState(() => _selectedStore = store),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: store.photoUrls.isNotEmpty
                ? Image.network(store.photoUrls[0], height: 160, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 160, color: _catColor.withOpacity(0.1),
                      child: Icon(_catIcon, size: 60, color: _catColor)))
                : Container(height: 160, color: _catColor.withOpacity(0.1), child: Icon(_catIcon, size: 60, color: _catColor)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(store.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: store.isOpen ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(store.isOpen ? '● Open' : '● Closed',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: store.isOpen ? Colors.green.shade700 : Colors.grey)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(store.description, style: TextStyle(color: Colors.grey.shade500, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 3),
                Text('${store.rating}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 14),
                Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text('${store.deliveryTime} min', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(width: 14),
                Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 2),
                Text('${store.distanceKm} km', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildStoreDetail(Store store) {
    final cart = Provider.of<CartProvider>(context);
    final fmt = (double v) => '₹${v.toStringAsFixed(0)}';
    final pageCtrl = PageController();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: _catColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _selectedStore = null),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: store.photoUrls.isNotEmpty
                ? Image.network(store.photoUrls[0], fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: _catColor.withOpacity(0.3)))
                : Container(color: _catColor.withOpacity(0.3)),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(store.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: store.isOpen ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(store.isOpen ? '● Open' : '● Closed',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: store.isOpen ? Colors.green.shade700 : Colors.grey)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(store.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5)),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 4),
                  Text('${store.rating}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time_rounded, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('${store.deliveryTime} min', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on_rounded, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 2),
                  Text('${store.distanceKm} km', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 20),
                // Contact buttons
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:${store.ownerPhone}')),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('https://wa.me/${store.ownerPhone.replaceAll('+', '')}?text=Hi, I want to order from ${store.name}')),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text('Menu / Items', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final p = store.products[i];
                final qty = cart.getQuantity(p.id);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    if (p.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(p.imageUrl!, width: 60, height: 60, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: _catColor.withOpacity(0.1),
                            child: Icon(_catIcon, color: _catColor, size: 28))),
                      )
                    else
                      Container(width: 60, height: 60, decoration: BoxDecoration(color: _catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(_catIcon, color: _catColor, size: 28)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text('per ${p.unit}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text(fmt(p.price), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _catColor)),
                    ])),
                    qty == 0
                      ? GestureDetector(
                          onTap: store.isOpen ? () => context.read<CartProvider>().addItem(p, storeName: store.name) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: store.isOpen ? _catColor : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Add', style: TextStyle(color: store.isOpen ? Colors.white : Colors.grey, fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                        )
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          _qtyBtn(Icons.remove_rounded, () => context.read<CartProvider>().removeItem(p), _catColor),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('$qty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _catColor)),
                          ),
                          _qtyBtn(Icons.add_rounded, () => context.read<CartProvider>().addItem(p, storeName: store.name), _catColor),
                        ]),
                  ]),
                );
              },
              childCount: store.products.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: cart.itemCount > 0 ? Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))]),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 16),
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: _catColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('${cart.itemCount} items', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const Text('View Cart →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              Text('₹${cart.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
          ),
        ),
      ) : null,
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  IconData get _catIcon {
    switch (widget.category) {
      case StoreCategory.grocery: return Icons.shopping_basket_rounded;
      case StoreCategory.bakery: return Icons.cake_rounded;
      case StoreCategory.medicine: return Icons.local_pharmacy_rounded;
      case StoreCategory.food: return Icons.restaurant_rounded;
      default: return Icons.store_rounded;
    }
  }
}
