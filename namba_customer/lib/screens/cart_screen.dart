import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';
import 'payment_screen.dart';
import '../models/models.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    const Color primary = Color(0xFF4F46E5);
    const Color secondary = Color(0xFF1F2937);
    final fmt = (double v) => '₹${v.toStringAsFixed(0)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: secondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('MY CART', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1, color: secondary)),
        centerTitle: true,
      ),
      body: cart.isEmpty ? _buildEmptyCart() : _buildCartContent(context, cart, primary, secondary, fmt),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(40), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)]), child: const Icon(Iconsax.shopping_cart_copy, size: 80, color: Color(0xFFE5E7EB))),
        const SizedBox(height: 24),
        Text('Your cart is empty', style: GoogleFonts.outfit(color: const Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Add some items to start a journey!', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildCartContent(BuildContext context, CartProvider cart, Color primary, Color secondary, Function fmt) {
    return Column(children: [
      Expanded(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (cart.storeName != null)
              Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: primary.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: primary.withOpacity(0.1))), child: Row(children: [Icon(Iconsax.shop_copy, size: 18, color: primary), const SizedBox(width: 12), Text('Ordering from ${cart.storeName}', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: primary, fontSize: 13))])),
            
            Text('ITEMS ADDED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            ...cart.items.map((item) => _cartItem(context, item, primary, secondary, fmt)),
            
            const SizedBox(height: 24),
            Text('BILLING DETAILS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            _billCard(cart, primary, secondary, fmt),
          ],
        ),
      ),
      _checkoutBar(context, cart, primary, fmt),
    ]);
  }

  Widget _cartItem(BuildContext context, CartItem item, Color primary, Color secondary, Function fmt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14)), child: const Icon(Iconsax.box_copy, color: Color(0xFF9CA3AF), size: 22)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.product.name, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: secondary)),
          Text('${fmt(item.product.price)} / ${item.product.unit}', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
        ])),
        Row(children: [
          _qtyBtn(Icons.remove, () => context.read<CartProvider>().removeItem(item.product), primary),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${item.quantity}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16))),
          _qtyBtn(Icons.add, () => context.read<CartProvider>().addItem(item.product), primary),
        ]),
        const SizedBox(width: 16),
        Text(fmt(item.total), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: secondary)),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, Color primary) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: primary)));
  }

  Widget _billCard(CartProvider cart, Color primary, Color secondary, Function fmt) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)]),
      child: Column(children: [
        _billRow('Subtotal', fmt(cart.subtotal), secondary),
        const SizedBox(height: 12),
        _billRow('Delivery Fee', fmt(cart.deliveryFee), secondary),
        const SizedBox(height: 12),
        _billRow('Platform Fee', fmt(cart.platformFee), secondary),
        const Divider(height: 32, color: Color(0xFFF3F4F6)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Grand Total', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: secondary)),
          Text(fmt(cart.total), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: primary)),
        ]),
      ]),
    );
  }

  Widget _billRow(String label, String val, Color secondary) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      Text(val, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: secondary)),
    ]);
  }

  Widget _checkoutBar(BuildContext context, CartProvider cart, Color primary, Function fmt) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: () => _placeOrder(context, cart),
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('CHECKOUT', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(width: 12),
              Container(width: 1, height: 20, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 12),
              Text(fmt(cart.total), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      ),
    );
  }

  void _placeOrder(BuildContext context, CartProvider cart) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    // 1. Check if location services (GPS) are enabled
    final isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isGpsEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enable GPS/Location services on your device to place an order.', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 2. Check location permissions
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permission is required to place an order.', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permission is permanently denied. Please enable it in device settings.', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 3. Erode Delivery Distance Radius Enforcement
    final custLat = auth.selectedAddress.lat ?? 0.0;
    final custLng = auth.selectedAddress.lng ?? 0.0;
    if (custLat != 0.0 && custLng != 0.0) {
      final distanceInMeters = Geolocator.distanceBetween(11.3410, 77.7172, custLat, custLng);
      final distanceInKm = distanceInMeters / 1000.0;
      
      // Maximum delivery radius threshold (Default 10 KM)
      const double maxRadiusKm = 10.0; 
      if (distanceInKm > maxRadiusKm) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.location_off_rounded, color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Text('Out of Delivery Range', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                ],
              ),
              content: Text(
                'We currently deliver only within ${maxRadiusKm.toInt()} KM of Erode. Your current location is ${distanceInKm.toStringAsFixed(1)} KM away.',
                style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF1F2937)),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    // Show loading dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final order = await orderProvider.placeOrder(
        storeId: cart.storeId ?? '',
        storeName: cart.storeName ?? '',
        storeCategory: '',
        items: cart.items,
        total: cart.total,
        address: auth.address,
        lat: auth.selectedAddress.lat,
        lng: auth.selectedAddress.lng,
      );

      cart.clear();
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => PaymentScreen(order: order)),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
