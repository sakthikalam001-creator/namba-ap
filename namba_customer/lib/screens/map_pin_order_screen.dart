import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../models/models.dart';
import 'order_details_screen.dart';

class MapPinOrderScreen extends StatefulWidget {
  const MapPinOrderScreen({super.key});

  @override
  State<MapPinOrderScreen> createState() => _MapPinOrderScreenState();
}

class _MapPinOrderScreenState extends State<MapPinOrderScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _itemsController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();

  LatLng _pinnedLocation = const LatLng(11.3410, 77.7172); // Default center
  String _pinnedAddress = "Fetching location address...";
  bool _isResolvingAddress = false;
  bool _isSubmitting = false;

  double _calculatedDistanceKm = 0.0;
  double _calculatedDeliveryFee = 25.0; // Base fee

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userLat = auth.selectedAddress.lat ?? 11.3410;
      final userLng = auth.selectedAddress.lng ?? 77.7172;
      setState(() {
        _pinnedLocation = LatLng(userLat + 0.005, userLng + 0.005); // Offset slightly from home
      });
      _mapController.move(_pinnedLocation, 16.0);
      _reverseGeocodeLocation(_pinnedLocation);
    });
  }

  @override
  void dispose() {
    _itemsController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocodeLocation(LatLng location) async {
    setState(() => _isResolvingAddress = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${location.latitude}&lon=${location.longitude}&format=json');
      final res = await http.get(url, headers: {'User-Agent': 'NambaCustomerApp/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final addr = data['display_name'] ?? 'Pinned Location (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})';
        if (mounted) {
          setState(() {
            _pinnedAddress = addr;
            _isResolvingAddress = false;
          });
          _recalculateLogisticsFee();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pinnedAddress = 'Pinned Location (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})';
          _isResolvingAddress = false;
        });
        _recalculateLogisticsFee();
      }
    }
  }

  void _recalculateLogisticsFee() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userLat = auth.selectedAddress.lat ?? 11.3410;
    final userLng = auth.selectedAddress.lng ?? 77.7172;

    final Distance distanceCalculator = const Distance();
    final double meterDist = distanceCalculator.as(
      LengthUnit.Meter,
      _pinnedLocation,
      LatLng(userLat, userLng),
    );

    // Apply road factor (1.15)
    final double km = (meterDist * 1.15) / 1000.0;
    _calculatedDistanceKm = double.parse(km.toStringAsFixed(2));

    // Admin Logistics Rule: Base ₹25 for first 2 KM + ₹10 per extra KM
    if (_calculatedDistanceKm <= 2.0) {
      _calculatedDeliveryFee = 25.0;
    } else {
      _calculatedDeliveryFee = 25.0 + ((_calculatedDistanceKm - 2.0) * 10.0).roundToDouble();
    }
  }

  Future<void> _submitMapPinOrder() async {
    final itemsText = _itemsController.text.trim();
    if (itemsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter what items/things you want us to buy/pick up.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orders = Provider.of<OrderProvider>(context, listen: false);

    final storeNameInput = _shopNameController.text.trim();
    final finalStoreName = storeNameInput.isNotEmpty
        ? '📍 Map Pin: $storeNameInput'
        : '📍 Map Pin Custom Pickup';

    setState(() => _isSubmitting = true);

    try {
      final newOrder = await orders.placeCustomOrder(
        customStoreName: finalStoreName,
        customStoreAddress: _pinnedAddress,
        textContent: itemsText,
        type: OrderType.mapPin,
        pinnedLat: _pinnedLocation.latitude,
        pinnedLng: _pinnedLocation.longitude,
        deliveryFee: _calculatedDeliveryFee,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (newOrder != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Map Pin Order placed! Admin will assign a rider to pick up your products.'),
              backgroundColor: Color(0xFF059669),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: newOrder.id)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to place Map Pin order. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '📍 Pick Items via Map Pin',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF1E1B4B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1E1B4B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── MAP PIN SELECTION CONTAINER ───────────────────────────────────
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pinnedLocation,
                    initialZoom: 16.0,
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture && position.center != null) {
                        setState(() {
                          _pinnedLocation = position.center!;
                        });
                      }
                    },
                    onMapEvent: (event) {
                      if (event is MapEventMoveEnd) {
                        _reverseGeocodeLocation(_pinnedLocation);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}',
                      subdomains: const ['0', '1', '2', '3'],
                    ),
                  ],
                ),

                // Center Fixed Bouncing Location Pin
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Text(
                            'MOVE MAP TO PIN PICKUP PLACE',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Icon(Icons.location_on_rounded, size: 48, color: Color(0xFF4F46E5)),
                      ],
                    ),
                  ),
                ),

                // Top Instruction Badge
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.pin_drop_rounded, color: Color(0xFF4F46E5), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isResolvingAddress ? 'Resolving pinned place...' : _pinnedAddress,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF1E1B4B)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── ORDER DETAILS INPUT SHEET ─────────────────────────────────────
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5)),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shop / Location Name Optional Input
                    Text('STORE / PLACE NAME (OPTIONAL)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _shopNameController,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'e.g. Lakshmi Super Market / Local Vegetable Vendor',
                        hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Items List Input
                    Text('THINGS / ITEMS TO BUY (REQUIRED)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _itemsController,
                      maxLines: 3,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Write items list here (e.g. 1kg Tomatoes, 2L Milk, Fresh Curry leaves)...',
                        hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Logistics Rule Distance & Delivery Fee Calculation
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF4F46E5), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LOGISTICS DISTANCE & DELIVERY FEE',
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5), letterSpacing: 1),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Distance: $_calculatedDistanceKm KM  •  Fee: ₹${_calculatedDeliveryFee.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Order Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _submitMapPinOrder,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PLACE MAP PIN ORDER',
                                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
