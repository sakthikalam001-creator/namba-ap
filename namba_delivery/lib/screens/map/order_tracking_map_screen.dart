import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../providers/delivery_provider.dart';
import '../../models/delivery_order.dart';

class OrderTrackingMapScreen extends StatefulWidget {
  final String orderId;
  final bool focusOnCustomer;

  const OrderTrackingMapScreen({
    super.key,
    required this.orderId,
    this.focusOnCustomer = false,
  });

  @override
  State<OrderTrackingMapScreen> createState() => _OrderTrackingMapScreenState();
}

class _OrderTrackingMapScreenState extends State<OrderTrackingMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  List<LatLng> _polylinePoints = [];
  bool _isFetchingRoute = false;
  String _statusMessage = 'Initializing navigation...';
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // Get current position
    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _fitInitialView();
    }

    // Subscribe to position updates
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  void _fitInitialView() {
    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final order = provider.activeOrders.firstWhere(
      (o) => o.id == widget.orderId,
      orElse: () => provider.activeOrders.first,
    );

    final storePoint = LatLng(order.storeLat ?? 11.0168, order.storeLng ?? 76.9558);
    final destPoint = LatLng(order.destLat ?? 11.0500, order.destLng ?? 76.9800);

    if (widget.focusOnCustomer) {
      _mapController.move(destPoint, 15.0);
    } else {
      _mapController.move(storePoint, 15.0);
    }
  }

  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    if (_isFetchingRoute) return;
    setState(() {
      _isFetchingRoute = true;
      _statusMessage = 'Calculating optimal route...';
    });

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        
        if (mounted) {
          setState(() {
            _polylinePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
            _isFetchingRoute = false;
            _statusMessage = 'Route Synced Successfully';
          });
          
          if (_polylinePoints.isNotEmpty) {
             _fitBounds();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _polylinePoints = [start, end];
          _isFetchingRoute = false;
          _statusMessage = 'Direct Path Calculated';
        });
      }
    }
  }

  void _fitBounds() {
    if (_polylinePoints.isEmpty) return;
    
    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (var p in _polylinePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 13.5);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final order = provider.activeOrders.firstWhere(
      (o) => o.id == widget.orderId,
      orElse: () => provider.activeOrders.first,
    );

    final storePoint = LatLng(order.storeLat ?? 11.0168, order.storeLng ?? 76.9558);
    final destPoint = LatLng(order.destLat ?? 11.0500, order.destLng ?? 76.9800);

    if (_polylinePoints.isEmpty && !_isFetchingRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRoadRoute(storePoint, destPoint));
    }

    return Scaffold(
      body: Stack(
        children: [
          // MAP LAYER
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.focusOnCustomer ? destPoint : storePoint,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.namba.delivery',
              ),
              if (_polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polylinePoints,
                      color: AppTheme.primaryOrange.withOpacity(0.2),
                      strokeWidth: 10,
                    ),
                    Polyline(
                      points: _polylinePoints,
                      color: AppTheme.primaryOrange,
                      strokeWidth: 4,
                      borderStrokeWidth: 1.5,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // STORE MARKER
                  Marker(
                    point: storePoint,
                    width: 70, height: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(width: 35, height: 35, decoration: BoxDecoration(color: AppTheme.primaryOrange.withOpacity(0.2), shape: BoxShape.circle)).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1,1), end: const Offset(2.5, 2.5), duration: 2000.ms).fadeOut(),
                        Container(
                          width: 35, height: 35,
                          decoration: BoxDecoration(color: AppTheme.primaryOrange, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)]),
                          child: const Icon(icons.Iconsax.shop_copy, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                  // DESTINATION MARKER
                  Marker(
                    point: destPoint,
                    width: 60, height: 60,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)]),
                      child: const Icon(icons.Iconsax.location_copy, color: Colors.white, size: 18),
                    ),
                  ),
                  // RIDER MARKER
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 80, height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.accentTeal.withOpacity(0.25), shape: BoxShape.circle)).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1,1), end: const Offset(2.2, 2.2), duration: 1500.ms).fadeOut(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppTheme.accentTeal, width: 2.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)]),
                            child: const Icon(Icons.motorcycle_rounded, color: AppTheme.accentTeal, size: 28),
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: 800.ms),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // HEADER OVERLAY
          Positioned(
            top: 50, left: 20, right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkText, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ORDER #${order.displayId.isNotEmpty ? order.displayId : order.id.substring(order.id.length - 6).toUpperCase()}',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.darkText),
                            ),
                            Row(
                              children: [
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms),
                                const SizedBox(width: 8),
                                Text(_statusMessage, style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.mediumText, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: -1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),

          // FOCUS ACTIONS
          Positioned(
            bottom: 40, right: 20,
            child: Column(
              children: [
                _buildMapAction(
                  icons.Iconsax.shop_copy,
                  AppTheme.primaryOrange,
                  () => _mapController.move(storePoint, 16.0),
                ),
                const SizedBox(height: 12),
                _buildMapAction(
                  icons.Iconsax.user_copy,
                  AppTheme.accentGreen,
                  () => _mapController.move(destPoint, 16.0),
                ),
                const SizedBox(height: 12),
                _buildMapAction(
                  icons.Iconsax.radar_2_copy,
                  AppTheme.accentTeal,
                  () => _fitBounds(),
                ),
              ],
            ),
          ).animate().slideX(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
        ],
      ),
    );
  }

  Widget _buildMapAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
