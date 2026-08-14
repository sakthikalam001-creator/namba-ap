import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
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
  final ImagePicker _picker = ImagePicker();

  LatLng _pinnedLocation = const LatLng(11.3498, 77.7189); // Default center (Erode)
  String _pinnedAddress = "Fetching location address...";
  bool _isResolvingAddress = false;
  bool _isSubmitting = false;

  // Mode: 0 = Text, 1 = Photo
  int _selectedMode = 0;
  File? _selectedPhoto;

  // Admin Logistics Rules Settings
  double _maxServiceRadiusKm = 15.0; // Admin Range Limit (e.g. 5KM, 10KM, 15KM...)
  LatLng _serviceCenter = const LatLng(11.3498, 77.7189);
  bool _isLoadingSettings = true;

  // Distance & Fee Calculations
  double _distanceFromCenterKm = 0.0;
  double _calculatedDistanceKm = 0.0;
  double _calculatedDeliveryFee = 25.0;
  bool _isOutOfRange = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAdminLogisticsSettings();
    });
  }

  @override
  void dispose() {
    _itemsController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdminLogisticsSettings() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userLat = auth.selectedAddress.lat ?? 11.3498;
    final userLng = auth.selectedAddress.lng ?? 77.7189;

    setState(() {
      _pinnedLocation = LatLng(userLat, userLng);
    });
    _mapController.move(_pinnedLocation, 16.0);

    try {
      final url = Uri.parse('${CustomerApiService.baseUrl}/admin/settings/public');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (data != null) {
          final double maxRadius = (data['maxServiceRadiusKm'] ?? 15.0).toDouble();
          final double centerLat = (data['serviceCenterLat'] ?? 11.3498).toDouble();
          final double centerLng = (data['serviceCenterLng'] ?? 77.7189).toDouble();

          setState(() {
            _maxServiceRadiusKm = maxRadius > 0 ? maxRadius : 15.0;
            _serviceCenter = LatLng(centerLat, centerLng);
            _isLoadingSettings = false;
          });
        }
      }
    } catch (_) {
      setState(() => _isLoadingSettings = false);
    }

    _reverseGeocodeLocation(_pinnedLocation);
  }

  Future<void> _reverseGeocodeLocation(LatLng location) async {
    setState(() => _isResolvingAddress = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${location.latitude}&lon=${location.longitude}&format=json');
      final res = await http.get(url, headers: {'User-Agent': 'NambaCustomerApp/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final addr = data['display_name'] ??
            'Pinned Location (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})';
        if (mounted) {
          setState(() {
            _pinnedAddress = addr;
            _isResolvingAddress = false;
          });
          _recalculateLogisticsAndRange();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pinnedAddress =
              'Pinned Location (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})';
          _isResolvingAddress = false;
        });
        _recalculateLogisticsAndRange();
      }
    }
  }

  void _recalculateLogisticsAndRange() {
    final Distance distanceCalculator = const Distance();

    // 1. Distance from Admin Hub Service Center to Pinned Location
    final double meterDistCenter = distanceCalculator.as(
      LengthUnit.Meter,
      _pinnedLocation,
      _serviceCenter,
    );
    _distanceFromCenterKm = double.parse(((meterDistCenter * 1.15) / 1000.0).toStringAsFixed(2));

    // 2. Check if Pinned Location exceeds Admin Delivery Radius Limit (e.g. 5KM, 10KM, 15KM)
    _isOutOfRange = _distanceFromCenterKm > _maxServiceRadiusKm;

    // 3. Distance from Pinned Location to Customer Delivery Address for delivery fee calculation
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userLat = auth.selectedAddress.lat ?? 11.3498;
    final userLng = auth.selectedAddress.lng ?? 77.7189;

    final double meterDistDel = distanceCalculator.as(
      LengthUnit.Meter,
      _pinnedLocation,
      LatLng(userLat, userLng),
    );
    final double kmDel = (meterDistDel * 1.15) / 1000.0;
    _calculatedDistanceKm = double.parse(kmDel.toStringAsFixed(2));

    // Admin Logistics Fee Rule: Base ₹25 for first 2 KM + ₹10 per extra KM
    if (_calculatedDistanceKm <= 2.0) {
      _calculatedDeliveryFee = 25.0;
    } else {
      _calculatedDeliveryFee = 25.0 + ((_calculatedDistanceKm - 2.0) * 10.0).roundToDouble();
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() {
          _selectedPhoto = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick photo: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _submitMapPinOrder() async {
    if (_isOutOfRange) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '❌ Out of Service Area! Pinned location is ${_distanceFromCenterKm} KM away (Max allowed: ${_maxServiceRadiusKm.toStringAsFixed(0)} KM).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final itemsText = _itemsController.text.trim();
    if (_selectedMode == 0 && itemsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter what items/things you want us to buy/pick up.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedMode == 1 && _selectedPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload or capture a photo of your shopping list.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

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
        textContent: _selectedMode == 0 ? itemsText : (itemsText.isNotEmpty ? itemsText : 'Photo Order Attached'),
        photoPath: _selectedMode == 1 ? _selectedPhoto?.path : null,
        type: _selectedMode == 1 ? OrderType.photo : OrderType.mapPin,
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
          // ── MAP PIN SELECTION VIEW ───────────────────────────────────────
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
                            color: _isOutOfRange ? Colors.redAccent : const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Text(
                            _isOutOfRange ? 'OUT OF SERVICE RADIUS' : 'MOVE MAP TO PIN PICKUP PLACE',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Icon(Icons.location_on_rounded, size: 48, color: _isOutOfRange ? Colors.redAccent : const Color(0xFF4F46E5)),
                      ],
                    ),
                  ),
                ),

                // Top Address Badge
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
                            color: (_isOutOfRange ? Colors.redAccent : const Color(0xFF4F46E5)).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isOutOfRange ? Icons.warning_amber_rounded : Icons.pin_drop_rounded,
                            color: _isOutOfRange ? Colors.redAccent : const Color(0xFF4F46E5),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isResolvingAddress ? 'Resolving pinned place...' : _pinnedAddress,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF1E1B4B)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                    // ── LOGISTICS RANGE CONTROL ALERT BANNER (ADMIN RULE) ──
                    if (_isOutOfRange)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'OUT OF SERVICE RADIUS (${_maxServiceRadiusKm.toStringAsFixed(0)} KM LIMIT)',
                                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.redAccent, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pinned location is ${_distanceFromCenterKm} KM away. Please move map pin inside our ${_maxServiceRadiusKm.toStringAsFixed(0)} KM service area.',
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF991B1B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'IN SERVICE AREA (${_distanceFromCenterKm} KM / Max ${_maxServiceRadiusKm.toStringAsFixed(0)} KM)',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF065F46)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── TEXT vs PHOTO MODE SWITCHER TABS ───────────────────
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedMode = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedMode == 0 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _selectedMode == 0
                                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                                      : [],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.edit_note_rounded, size: 18, color: _selectedMode == 0 ? const Color(0xFF4F46E5) : Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('TEXT LIST', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: _selectedMode == 0 ? const Color(0xFF4F46E5) : Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedMode = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedMode == 1 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _selectedMode == 1
                                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                                      : [],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_rounded, size: 18, color: _selectedMode == 1 ? const Color(0xFF4F46E5) : Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('PHOTO UPLOAD', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: _selectedMode == 1 ? const Color(0xFF4F46E5) : Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Shop Name Input
                    Text('STORE / PLACE NAME (OPTIONAL)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _shopNameController,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'e.g. Lakshmi Super Market / Krishnaveni Mess',
                        hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── TEXT INPUT MODE ──
                    if (_selectedMode == 0) ...[
                      Text('THINGS / ITEMS TO BUY (REQUIRED)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _itemsController,
                        maxLines: 3,
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Write items list here (e.g. 1kg Idly Batter, 2L Milk)...',
                          hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],

                    // ── PHOTO UPLOAD MODE ──
                    if (_selectedMode == 1) ...[
                      Text('SHOPPING LIST / ITEM PHOTO (REQUIRED)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      if (_selectedPhoto != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(_selectedPhoto!, height: 140, width: double.infinity, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedPhoto = null),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  foregroundColor: const Color(0xFF1E1B4B),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4F46E5)),
                                label: Text('TAKE PHOTO', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                                onPressed: () => _pickPhoto(ImageSource.camera),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  foregroundColor: const Color(0xFF1E1B4B),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF4F46E5)),
                                label: Text('GALLERY', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                                onPressed: () => _pickPhoto(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),
                    ],
                    const SizedBox(height: 16),

                    // Logistics Fee Box
                    Container(
                      padding: const EdgeInsets.all(14),
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
                                  'DELIVERY DISTANCE & LOGISTICS FEE',
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5), letterSpacing: 1),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Distance: $_calculatedDistanceKm KM  •  Delivery Fee: ₹${_calculatedDeliveryFee.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B)),
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
                          backgroundColor: _isOutOfRange ? Colors.grey.shade400 : const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: (_isSubmitting || _isOutOfRange) ? null : _submitMapPinOrder,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isOutOfRange ? 'OUT OF SERVICE AREA' : 'PLACE MAP PIN ORDER',
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
