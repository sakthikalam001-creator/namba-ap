import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/models.dart';
import '../providers/order_provider.dart';

class OrderTrackingScreen extends StatefulWidget {
  final DeliveryOrder order;
  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with TickerProviderStateMixin {
  bool _dialogShown = false;
  IO.Socket? _socket;
  bool _isConnected = false;
  
  // Coordinates
  LatLng? _riderLocation;
  LatLng? _animatedRiderLocation;
  LatLng? _prevRiderLocation;
  LatLng? _storeLocation;
  LatLng? _customerLocation;

  final MapController _mapController = MapController();
  List<LatLng> _polylinePoints = [];
  bool _isFetchingRoute = false;
  Timer? _smoothTimer;
  
  // Map Layer
  String _mapTileUrl = 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}';
  bool _isSatellite = false;

  // Realtime calculated values
  double _calculatedDistanceKm = 0.0;
  int _estimatedMins = 15;
  String _liveStatusMsg = 'Rider is on the way';

  @override
  void initState() {
    super.initState();
    _setupInitialCoordinates();
    _initSocket();
    _fetchRoadRoute();
  }

  @override
  void dispose() {
    _smoothTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  void _setupInitialCoordinates() {
    final o = widget.order;

    // 1. Customer Location (Default: Erode center if unspecified)
    if (o.customerLat != null && o.customerLng != null) {
      _customerLocation = LatLng(o.customerLat!, o.customerLng!);
    } else {
      _customerLocation = const LatLng(11.3410, 77.7172);
    }

    // 2. Store Location
    if (o.vendorLat != null && o.vendorLng != null) {
      _storeLocation = LatLng(o.vendorLat!, o.vendorLng!);
    } else {
      // Slightly offset from customer for visualization if not set
      _storeLocation = LatLng(_customerLocation!.latitude + 0.015, _customerLocation!.longitude - 0.015);
    }

    // 3. Driver Location
    if (o.driverLat != null && o.driverLng != null) {
      _riderLocation = LatLng(o.driverLat!, o.driverLng!);
    } else {
      _riderLocation = LatLng(_storeLocation!.latitude + 0.005, _storeLocation!.longitude + 0.005);
    }

    _animatedRiderLocation = _riderLocation;
    _recalculateDistanceAndEta();
  }

  void _initSocket() {
    String serverUrl = dotenv.env['API_URL'] ?? 'http://100.53.131.76:5000';
    if (serverUrl.endsWith('/api')) {
      serverUrl = serverUrl.replaceAll('/api', '');
    }

    try {
      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setReconnectionAttempts(10)
            .build(),
      );

      _socket!.onConnect((_) {
        if (mounted) setState(() => _isConnected = true);
        _socket!.emit('join_room', 'order_${widget.order.id}');
      });

      _socket!.on('rider_location_updated', (data) {
        if (mounted && data != null) {
          final double? lat = (data['lat'] as num?)?.toDouble();
          final double? lng = (data['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            final newLoc = LatLng(lat, lng);
            _smoothMoveTo(newLoc);
            if (data['status'] != null) {
              setState(() {
                _liveStatusMsg = data['status'].toString();
              });
            }
          }
        }
      });

      _socket!.onDisconnect((_) {
        if (mounted) setState(() => _isConnected = false);
      });
    } catch (e) {
      debugPrint('[Socket Error] $e');
    }
  }

  void _smoothMoveTo(LatLng target) {
    _smoothTimer?.cancel();
    _prevRiderLocation = _animatedRiderLocation ?? _riderLocation;
    if (mounted) setState(() => _riderLocation = target);

    const steps = 10;
    int step = 0;
    _smoothTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || step >= steps) {
        timer.cancel();
        return;
      }
      step++;
      final t = step / steps;
      final prev = _prevRiderLocation;
      if (prev == null) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          _animatedRiderLocation = LatLng(
            prev.latitude + (target.latitude - prev.latitude) * t,
            prev.longitude + (target.longitude - prev.longitude) * t,
          );
          _recalculateDistanceAndEta();
        });
      }
    });
  }

  void _recalculateDistanceAndEta() {
    if (_animatedRiderLocation == null || _customerLocation == null) return;
    const distanceCalc = Distance();
    final meters = distanceCalc(_animatedRiderLocation!, _customerLocation!);
    _calculatedDistanceKm = double.parse((meters / 1000.0).toStringAsFixed(1));
    // Average speed ~ 25 km/h in city traffic => 1 km takes ~2.4 mins + 5 min padding
    _estimatedMins = ((_calculatedDistanceKm * 2.5) + 4).round();
    if (_estimatedMins < 3) _estimatedMins = 3;
  }

  Future<void> _fetchRoadRoute() async {
    if (_isFetchingRoute) return;
    final start = _riderLocation ?? _storeLocation;
    final end = _customerLocation;

    if (start == null || end == null) return;

    if (mounted) setState(() => _isFetchingRoute = true);

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        if (mounted) {
          setState(() {
            _polylinePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
            _isFetchingRoute = false;
          });
        }
      } else {
        throw Exception('OSRM Failed');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _polylinePoints = [start, end];
          _isFetchingRoute = false;
        });
      }
    }
  }

  void _recenterMap() {
    if (_animatedRiderLocation != null) {
      _mapController.move(_animatedRiderLocation!, 15.5);
    } else if (_customerLocation != null) {
      _mapController.move(_customerLocation!, 15.0);
    }
  }

  void _toggleSatellite() {
    setState(() {
      _isSatellite = !_isSatellite;
      _mapTileUrl = _isSatellite
          ? 'https://mt{s}.google.com/vt/lyrs=y,traffic&x={x}&y={y}&z={z}'
          : 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}';
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showRatingDialog(BuildContext context, DeliveryOrder order, OrderProvider provider) {
    double selectedRating = 5.0;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.star_1_copy, color: Color(0xFF6366F1), size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Rate Your Experience',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How was the delivery for your order from ${order.storeName}?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  final isSelected = starIndex <= selectedRating;
                  return GestureDetector(
                    onTap: () {
                      setStateDialog(() {
                        selectedRating = starIndex.toDouble();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isSelected ? Colors.amber : Colors.grey.shade300,
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: commentCtrl,
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your comments (optional)...',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 13),
                  fillColor: const Color(0xFFF9FAFB),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'CANCEL',
                        style: GoogleFonts.outfit(color: Colors.grey.shade500, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        provider.submitRating(order.id, selectedRating, commentCtrl.text);
                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Thank you for your rating!',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );

                        const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.namba.customer';
                        await _launchUrl(playStoreUrl);
                      },
                      child: Text(
                        'SUBMIT & RATE',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final order = orderProvider.orders.firstWhere((o) => o.id == widget.order.id, orElse: () => widget.order);

    if (order.status == OrderStatus.delivered && (order.userRating == null || order.userRating == 0.0) && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRatingDialog(context, order, orderProvider);
      });
    }

    final steps = [
      {'title': 'Order Placed', 'subtitle': 'We have received your order.', 'status': OrderStatus.placed, 'icon': Iconsax.shopping_bag_copy},
      {'title': 'Order Confirmed', 'subtitle': 'Store has confirmed your order.', 'status': OrderStatus.accepted, 'icon': Iconsax.tick_circle_copy},
      {'title': 'Order in Preparation', 'subtitle': 'Preparing your items with care.', 'status': OrderStatus.preparing, 'icon': Iconsax.status_up_copy},
      {'title': 'Rider Assigned', 'subtitle': order.deliveryPartner?.name ?? 'Assigning best rider...', 'status': OrderStatus.assigned, 'icon': Iconsax.user_tag_copy},
      {'title': 'Rider Reached Shop', 'subtitle': 'Rider is collecting your order.', 'status': OrderStatus.ready, 'icon': Iconsax.shop_copy},
      {'title': 'Rider On the Way', 'subtitle': 'Rider is moving towards you.', 'status': OrderStatus.pickedUp, 'icon': Iconsax.routing_copy},
      {'title': 'Order Arrived', 'subtitle': 'Rider is at your location!', 'status': OrderStatus.outForDelivery, 'icon': Iconsax.location_copy},
      {'title': 'Order Delivered', 'subtitle': 'Delivered. Enjoy your meal!', 'status': OrderStatus.delivered, 'icon': Iconsax.cup_copy},
    ];

    int currentIdx = 0;
    switch (order.status) {
      case OrderStatus.placed: currentIdx = 0; break;
      case OrderStatus.accepted: currentIdx = 1; break;
      case OrderStatus.preparing: currentIdx = 2; break;
      case OrderStatus.assigned: currentIdx = 3; break;
      case OrderStatus.ready: currentIdx = 4; break;
      case OrderStatus.pickedUp: currentIdx = 5; break;
      case OrderStatus.outForDelivery: 
      case OrderStatus.arrived: currentIdx = 6; break;
      case OrderStatus.delivered: currentIdx = 7; break;
      case OrderStatus.rejected: currentIdx = -1; break;
    }

    const Color primaryColor = Color(0xFF6366F1); 
    const Color secondaryColor = Color(0xFF1F2937);

    final initialCenter = _animatedRiderLocation ?? _customerLocation ?? const LatLng(11.3410, 77.7172);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Google Map Section (Top 50% screen height)
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.48,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 15.0,
                    minZoom: 4.0,
                    maxZoom: 19.0,
                  ),
                  children: [
                    // Google Map HD Traffic Layer
                    TileLayer(
                      urlTemplate: _mapTileUrl,
                      subdomains: const ['0', '1', '2', '3'],
                      userAgentPackageName: 'com.namba.customer',
                    ),
                    
                    // Route Polyline Layer
                    if (_polylinePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _polylinePoints,
                            strokeWidth: 5.5,
                            color: primaryColor,
                            borderStrokeWidth: 2.0,
                            borderColor: Colors.white,
                          ),
                        ],
                      ),

                    // Map Markers (Store, Customer, Rider)
                    MarkerLayer(
                      markers: [
                        // Store Marker
                        if (_storeLocation != null)
                          Marker(
                            point: _storeLocation!,
                            width: 50, height: 50,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)],
                                  ),
                                  child: const Icon(Iconsax.shop_copy, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                          ),

                        // Customer Marker
                        if (_customerLocation != null)
                          Marker(
                            point: _customerLocation!,
                            width: 55, height: 55,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 10, spreadRadius: 3)],
                                  ),
                                  child: const Icon(Iconsax.home_2_copy, color: Colors.white, size: 22),
                                ),
                              ],
                            ),
                          ),

                        // Animated Rider Marker
                        if (_animatedRiderLocation != null)
                          Marker(
                            point: _animatedRiderLocation!,
                            width: 60, height: 60,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.5), blurRadius: 12, spreadRadius: 4)],
                                  ),
                                  child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 24),
                                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                                 .scaleXY(begin: 1.0, end: 1.08, duration: 800.ms),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Map Overlay Gradient
                Positioned(
                  top: 0, left: 0, right: 0, height: 90,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                      ),
                    ),
                  ),
                ),

                // Map Floating Action Buttons (Satellite Toggle, Recenter)
                Positioned(
                  right: 16, bottom: 40,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'sat_btn',
                        backgroundColor: Colors.white,
                        onPressed: _toggleSatellite,
                        child: Icon(_isSatellite ? Icons.map_outlined : Icons.satellite_alt_rounded, color: secondaryColor),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'center_btn',
                        backgroundColor: primaryColor,
                        onPressed: _recenterMap,
                        child: const Icon(Icons.my_location_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Socket Live Badge Top Bar
                Positioned(
                  top: 50, right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isConnected ? const Color(0xFF10B981) : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.3, end: 1.0),
                        const SizedBox(width: 6),
                        Text(
                          _isConnected ? 'LIVE GPS' : 'SYNCING',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Scrollable Content Card (Bottom Section)
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: secondaryColor, size: 18),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Iconsax.call_copy, color: primaryColor, size: 18),
                    ),
                    onPressed: () => _launchUrl('tel:${order.deliveryPartner?.phone ?? "919840212345"}'),
                  ),
                  const SizedBox(width: 16),
                ],
              ),

              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).size.height * 0.38)),

              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 44, height: 5,
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ETA & Status Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ARRIVING IN', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                              const SizedBox(height: 2),
                              Text(
                                order.status == OrderStatus.delivered ? 'DELIVERED' : '$_estimatedMins MINS',
                                style: GoogleFonts.outfit(color: secondaryColor, fontSize: 28, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: order.status == OrderStatus.delivered ? const Color(0xFF10B981).withOpacity(0.12) : primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              order.status == OrderStatus.delivered ? 'COMPLETED' : '$_calculatedDistanceKm KM AWAY', 
                              style: GoogleFonts.outfit(
                                color: order.status == OrderStatus.delivered ? const Color(0xFF10B981) : primaryColor, 
                                fontWeight: FontWeight.w900, 
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Live Status Banner Message
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Iconsax.routing_copy, color: primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _liveStatusMsg,
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: secondaryColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Delivery OTP Box (If available or generated)
                      if (order.deliveryOtp != null || (order.status != OrderStatus.delivered && order.status != OrderStatus.placed)) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('DELIVERY OTP', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                                  Text(
                                    order.deliveryOtp ?? (order.id.length >= 4 ? order.id.substring(order.id.length - 4) : '4821'),
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4.0),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                  'Share with rider',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Rider Card Section
                      if (order.deliveryPartner != null) ...[
                        Text('YOUR DELIVERY PARTNER', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 54, height: 54,
                                decoration: BoxDecoration(color: primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.two_wheeler_rounded, color: primaryColor, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(order.deliveryPartner!.name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: secondaryColor)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Text('${order.deliveryPartner!.rating}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: secondaryColor)),
                                        const SizedBox(width: 8),
                                        Text('• ${order.deliveryPartner!.vehicleNumber}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.12), shape: BoxShape.circle),
                                  child: const Icon(Iconsax.message_2_copy, color: Color(0xFF25D366), size: 20),
                                ),
                                onPressed: () => _launchUrl('https://wa.me/${order.deliveryPartner!.phone}'),
                              ),
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.12), shape: BoxShape.circle),
                                  child: const Icon(Iconsax.call_copy, color: primaryColor, size: 20),
                                ),
                                onPressed: () => _launchUrl('tel:${order.deliveryPartner!.phone}'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Store Info Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Iconsax.shop_copy, color: Color(0xFFF59E0B), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(order.storeName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: secondaryColor)),
                                  Text(order.storeCategory, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Status Timeline
                      Text('ORDER PROGRESS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                      const SizedBox(height: 20),
                      Column(
                        children: List.generate(steps.length, (index) {
                          final step = steps[index];
                          final bool isDone = index <= currentIdx;
                          final bool isActive = index == currentIdx;
                          final bool isLast = index == steps.length - 1;

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 26, height: 26,
                                      decoration: BoxDecoration(
                                        color: isDone ? primaryColor : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: isDone ? primaryColor : Colors.grey.shade300, width: isActive ? 4 : 2),
                                        boxShadow: isActive ? [BoxShadow(color: primaryColor.withOpacity(0.35), blurRadius: 10, spreadRadius: 3)] : [],
                                      ),
                                      child: isDone ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                                    ),
                                    if (!isLast)
                                      Expanded(
                                        child: Container(width: 2, color: isDone ? primaryColor : Colors.grey.shade200),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 28),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step['title'] as String, 
                                          style: GoogleFonts.outfit(
                                            fontSize: 15, 
                                            fontWeight: isActive ? FontWeight.w900 : (isDone ? FontWeight.w700 : FontWeight.w600), 
                                            color: isDone ? secondaryColor : Colors.grey.shade400,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          step['subtitle'] as String, 
                                          style: GoogleFonts.outfit(
                                            fontSize: 12, 
                                            color: isDone ? Colors.grey.shade600 : Colors.grey.shade400, 
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isDone)
                                  Text(
                                    DateFormat('hh:mm a').format(order.statusTimestamps[step['status']] ?? order.placedAt),
                                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w700),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),

                      // Order Items List
                      if (order.items.isNotEmpty) ...[
                        Text('ORDERED ITEMS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text('${item.quantity}x', style: GoogleFonts.outfit(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 13)),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(item.product.name, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: secondaryColor)),
                                ],
                              ),
                              Text('₹${(item.product.price * item.quantity).toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: secondaryColor)),
                            ],
                          ),
                        )),
                        const SizedBox(height: 28),
                      ],

                      // Bill Details Breakdown
                      if (order.totalAmount > 0) ...[
                        Text('BILL SUMMARY', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Subtotal', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                  Text('₹${(order.subTotal > 0 ? order.subTotal : order.totalAmount).toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 13, color: secondaryColor, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Delivery Fee', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                  Text('₹${order.deliveryFee.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 13, color: secondaryColor, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Platform Fee', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                  Text('₹${order.platformFee.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 13, color: secondaryColor, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              if (order.discount > 0) ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Vendor Discount', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF10B981), fontWeight: FontWeight.w700)),
                                    Text('-₹${order.discount.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF10B981), fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ],
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Divider(height: 1),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Amount', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: secondaryColor)),
                                  Text('₹${order.totalAmount.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: order.isPaymentDone ? const Color(0xFF10B981).withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    order.isPaymentDone ? 'PAID ONLINE (SUCCESS)' : 'CASH ON DELIVERY (COD)',
                                    style: GoogleFonts.outfit(
                                      color: order.isPaymentDone ? const Color(0xFF10B981) : Colors.orange.shade800,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
