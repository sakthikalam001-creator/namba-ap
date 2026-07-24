import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';
import 'cart_screen.dart';
import 'map_location_picker_screen.dart';

class StoreDetailScreen extends StatefulWidget {
  final Store store;
  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  late Store _currentStore;
  bool _isLoading = false;
  final CustomerApiService _apiService = CustomerApiService();

  @override
  void initState() {
    super.initState();
    _currentStore = widget.store;
    _fetchStoreDetails();
    _apiService.initSocket((data) {
      if (mounted && data['type'] == 'inventory_update' && data['vendorId'] == widget.store.id) {
        _fetchStoreDetails();
      }
    });
  }

  Future<void> _fetchStoreDetails() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final rawProducts = await _apiService.getVendorProducts(widget.store.id);
      final products = rawProducts.map((p) => Product.fromMap(p)).toList();
      if (mounted) {
        setState(() {
          _currentStore = _currentStore.copyWith(products: products, hasItemList: products.isNotEmpty);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Store get store => _currentStore;
  static const Color primary = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF1F2937);

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              _buildStoreInfo(),
              _buildQuickOrderSection(),
              if (store.hasItemList) _buildMenuList(cart),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          if (cart.itemCount > 0) Positioned(left: 20, right: 20, bottom: 0, child: SafeArea(top: false, minimum: const EdgeInsets.only(bottom: 30), child: _buildFloatingCart(cart))),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.arrow_back_ios_new_rounded, color: secondary, size: 18)),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            store.photoUrls.isNotEmpty ? Image.network(store.photoUrls[0], fit: BoxFit.cover) : Container(color: primary.withOpacity(0.1)),
            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.6)]))),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfo() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(store.name, style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: secondary))),
              _statusBadge(),
            ]),
            const SizedBox(height: 8),
            Text(store.description, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade500, height: 1.5)),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _infoTile(Icons.star_rounded, '${store.rating}', 'Rating', const Color(0xFFF59E0B)),
              _infoTile(Iconsax.clock_copy, '${store.deliveryTime} min', 'Delivery', primary),
              _infoTile(Iconsax.routing_copy, '${store.distanceKm} km', 'Distance', const Color(0xFF0EA5E9)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: store.isOpen ? const Color(0xFF10B981).withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(store.isOpen ? 'OPEN' : 'CLOSED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: store.isOpen ? const Color(0xFF10B981) : Colors.red)),
    );
  }

  Widget _infoTile(IconData icon, String val, String label, Color color) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(height: 8),
      Text(val, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: secondary)),
      Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
    ]);
  }

  Widget _buildQuickOrderSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('QUICK ORDER', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(
            'நீங்கள் தேடும் பொருட்கள் கீழே உள்ள பட்டியலில் இல்லை எனில், Chat அல்லது Photo மூலம் ஆர்டர் செய்யலாம்.',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade800, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _quickBtn(Iconsax.message_text_copy, 'Order via Chat', primary, _showTextOrderSheet)),
            const SizedBox(width: 12),
            Expanded(child: _quickBtn(Iconsax.camera_copy, 'Order via Photo', const Color(0xFF8B5CF6), _showPhotoOrderSheet)),
          ]),
        ]),
      ),
    );
  }

  void _showTextOrderSheet() {
    final List<Map<String, String>> items = [];
    final itemCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24, right: 24, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Iconsax.document_text, color: primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Shopping List', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
                  Text('டைப் செய்து வரிசையாகச் சேர்க்கவும்', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
                ])),
              ]),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: TextField(
                        controller: itemCtrl,
                        onChanged: (val) => setS(() {}),
                        decoration: InputDecoration(hintText: 'Item Name (e.g. Milk)', border: InputBorder.none, hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey)),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: TextField(
                        controller: qtyCtrl,
                        decoration: InputDecoration(hintText: 'Qty', border: InputBorder.none, hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey)),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      if (itemCtrl.text.trim().isNotEmpty) {
                        setS(() {
                          items.add({
                            'name': itemCtrl.text.trim().toUpperCase(),
                            'qty': qtyCtrl.text.trim().isEmpty ? '1' : qtyCtrl.text.trim().toUpperCase(),
                          });
                          itemCtrl.clear();
                          qtyCtrl.clear();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (items.isNotEmpty) ...[
                Text('Items Added', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.3),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
                      child: Row(children: [
                        Text('${i+1}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: primary)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(items[i]['name']!, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14))),
                        Text(items[i]['qty']!, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: primary)),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => setS(() => items.removeAt(i)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  hintText: 'Additional notes (optional)',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Iconsax.edit, size: 20),
                ),
                style: GoogleFonts.outfit(fontSize: 13),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: items.isEmpty ? null : () => _confirmOrder(OrderType.text, items, notesCtrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Confirm Order List', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoOrderSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Photo Order', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            _photoOptionBtn(Iconsax.camera, 'Camera-ல் Photo எடு', primary, () async {
              Navigator.pop(ctx);
              final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (img != null) _showPhotoPreview(img);
            }),
            const SizedBox(height: 12),
            _photoOptionBtn(Iconsax.gallery, 'Gallery-ல் இருந்து எடு', const Color(0xFF10B981), () async {
              Navigator.pop(ctx);
              final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (img != null) _showPhotoPreview(img);
            }),
          ]),
        ),
      ),
    );
  }

  void _showPhotoPreview(XFile img) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Photo Preview', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(img.path), height: 250, width: double.infinity, fit: BoxFit.cover)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _confirmOrder(OrderType.photo, [], '', photoPath: img.path),
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text('Send Photo Order', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ]),
      ),
    );
  }

  Widget _photoOptionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.1))),
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const Spacer(),
          Icon(Iconsax.arrow_right_3, color: color.withOpacity(0.3), size: 18),
        ]),
      ),
    );
  }

  void _confirmOrder(OrderType type, List<Map<String, String>> items, String notes, {String? photoPath}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.hasValidPinnedLocation) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please pin your location on the map before placing an order.', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MapLocationPickerScreen()),
      );
      return;
    }

    // Pop the bottom sheet first
    Navigator.pop(context);

    // Show confirm dialog with fee info
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Confirm Order?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 22, color: secondary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('உங்கள் ஆர்டரை உறுதி செய்யவா?', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Text('Free to Place Order', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF065F46))),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Vendor quote பண்ணிய பிறகு விலை காட்டப்படும். Accept பண்ணினாலே Pay பண்ணுற option வரும், அத வச்சி நீங்க ஈஸியா Pay பண்ணிக்கலாம்.',
                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF065F46), height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Confirm Order', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: primary)),
    );

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      String content = '';
      if (type == OrderType.text) {
        content = "Items requested:\n";
        for (int i=0; i < items.length; i++) {
          content += "${i + 1}. ${items[i]['name']} (Qty: ${items[i]['qty']})\n";
        }
        if (notes.isNotEmpty) content += "\nNote: $notes";
      } else {
        content = "Check photo for details";
      }

      await orderProvider.placeSpecialOrder(
        store: widget.store,
        address: auth.address,
        lat: auth.selectedAddress.lat,
        lng: auth.selectedAddress.lng,
        type: type,
        content: content,
        photoPath: photoPath,
      );

      if (mounted) {
        Navigator.pop(context); // Pop loading
        _showSuccess();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order failed: $e')));
      }
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 64),
          const SizedBox(height: 16),
          Text('Order Sent!', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 8),
          Text('உங்கள் ஆர்டர் கடைக்கு அனுப்பப்பட்டது. அவர்கள் விலையை உறுதி செய்த பின் உங்களுக்குத் தெரிவிக்கப்படும்.', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600)),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('GREAT!'),
            ),
          )
        ],
      ),
    );
  }

  Widget _quickBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.1)), boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: secondary)),
        ]),
      ),
    );
  }

  Widget _buildMenuList(CartProvider cart) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
        final p = store.products[i];
        return _productCard(p, cart);
      }, childCount: store.products.length)),
    );
  }

  Widget _productCard(Product p, CartProvider cart) {
    final inCart = cart.getQuantity(p.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Row(children: [
        Container(width: 70, height: 70, decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16), image: p.imageUrl != null ? DecorationImage(image: NetworkImage(p.imageUrl!), fit: BoxFit.cover) : null), child: p.imageUrl == null ? const Icon(Iconsax.box_copy, color: Colors.grey) : null),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: secondary)),
          Text(p.unit, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('₹${p.price.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: primary)),
        ])),
        if (inCart == 0)
          ElevatedButton(onPressed: () => cart.addItem(p), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16)), child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)))
        else
          Row(children: [
            _qtyBtn(Icons.remove, () => cart.removeItem(p), primary),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$inCart', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16))),
            _qtyBtn(Icons.add, () => cart.addItem(p), primary),
          ]),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)));
  }

  Widget _buildFloatingCart(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${cart.itemCount} ITEMS', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text('₹${cart.total.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
        const Spacer(),
        GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())), child: Row(children: [Text('VIEW CART', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(width: 8), const Icon(Iconsax.arrow_right_1_copy, color: Colors.white, size: 18)])),
      ]),
    );
  }
}
