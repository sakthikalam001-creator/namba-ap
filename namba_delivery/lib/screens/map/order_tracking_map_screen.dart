import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
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

class _OrderTrackingMapScreenState extends State<OrderTrackingMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _animatedPosition; // for smooth glide animation
  List<LatLng> _polylinePoints = [];
  bool _isFetchingRoute = false;
  DeliveryStatus? _lastRoutedStatus;
  bool _hasRoutedFromRiderPos = false;
  String _currentMapStyleUrl = 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
  String _statusMessage = 'Initializing navigation...';
  StreamSubscription<Position>? _positionSubscription;

  // Smooth marker animation
  late AnimationController _markerMoveController;
  late Animation<double> _markerMoveAnim;
  LatLng? _previousPosition;

  // Pulsing animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _markerMoveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _markerMoveAnim = CurvedAnimation(
      parent: _markerMoveController,
      curve: Curves.easeInOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

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

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _animatedPosition = _currentPosition;
      });
      _fitInitialView();
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen((Position position) {
      if (mounted) {
        final newPos = LatLng(position.latitude, position.longitude);
        _animateMarkerTo(newPos);
      }
    });
  }

  void _animateMarkerTo(LatLng target) {
    _previousPosition = _animatedPosition ?? _currentPosition;
    setState(() => _currentPosition = target);

    _markerMoveController.reset();
    _markerMoveController.forward();

    _markerMoveAnim.addListener(() {
      if (mounted && _previousPosition != null) {
        final t = _markerMoveAnim.value;
        setState(() {
          _animatedPosition = LatLng(
            _previousPosition!.latitude + (target.latitude - _previousPosition!.latitude) * t,
            _previousPosition!.longitude + (target.longitude - _previousPosition!.longitude) * t,
          );
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
    final storePoint = LatLng(order.storeLat ?? 11.3410, order.storeLng ?? 77.7172);
    final destPoint = LatLng(order.destLat ?? 11.3410, order.destLng ?? 77.7172);
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
      final url =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        if (mounted) {
          setState(() {
            _polylinePoints =
                coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
            _isFetchingRoute = false;
            _statusMessage = 'Route ready';
          });
          if (_polylinePoints.isNotEmpty) _fitBounds();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _polylinePoints = [start, end];
          _isFetchingRoute = false;
          _statusMessage = 'Direct path';
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
    _mapController.move(
        LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2), 13.5);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _markerMoveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final order = provider.activeOrders.firstWhere(
      (o) => o.id == widget.orderId,
      orElse: () => provider.activeOrders.first,
    );

    final storePoint = LatLng(order.storeLat ?? 11.3410, order.storeLng ?? 77.7172);
    final destPoint = LatLng(order.destLat ?? 11.3410, order.destLng ?? 77.7172);
    final riderPos = _animatedPosition ?? _currentPosition;

    final isGoingToStore = order.status == DeliveryStatus.allocated || order.status == DeliveryStatus.pickingUp;
    final routeStart = riderPos ?? storePoint;
    final routeEnd = isGoingToStore ? storePoint : destPoint;

    if (_lastRoutedStatus != order.status || (riderPos != null && !_hasRoutedFromRiderPos)) {
      _lastRoutedStatus = order.status;
      if (riderPos != null) _hasRoutedFromRiderPos = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchRoadRoute(routeStart, routeEnd);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── PREMIUM MAP ────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: routeEnd,
              initialZoom: 14.0,
            ),
            children: [
              // CartoDB Voyager - clear labels, premium look
              TileLayer(
                urlTemplate: _currentMapStyleUrl,
                subdomains: const ['0', '1', '2', '3', 'a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.namba.delivery',
                maxZoom: 20,
              ),

              // Route polyline with glow effect
              if (_polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Outer glow
                    Polyline(
                      points: _polylinePoints,
                      color: AppTheme.primaryOrange.withOpacity(0.15),
                      strokeWidth: 16,
                    ),
                    // Mid glow
                    Polyline(
                      points: _polylinePoints,
                      color: AppTheme.primaryOrange.withOpacity(0.3),
                      strokeWidth: 8,
                    ),
                    // Main solid line
                    Polyline(
                      points: _polylinePoints,
                      color: AppTheme.primaryOrange,
                      strokeWidth: 4.5,
                      borderStrokeWidth: 1.5,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // ── STORE MARKER ─────────────────────────────────────────
                  Marker(
                    point: storePoint,
                    width: 80, height: 80,
                    child: _PulsingMarker(
                      color: AppTheme.primaryOrange,
                      icon: icons.Iconsax.shop_copy,
                      label: 'STORE',
                      pulseController: _pulseController,
                    ),
                  ),

                  // ── DESTINATION MARKER ───────────────────────────────────
                  Marker(
                    point: destPoint,
                    width: 80, height: 90,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                  color: AppTheme.accentGreen.withOpacity(0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6)),
                            ],
                          ),
                          child: const Icon(Icons.flag_rounded,
                              color: Colors.white, size: 22),
                        ),
                        CustomPaint(
                          size: const Size(14, 8),
                          painter: _PinTailPainter(color: AppTheme.accentGreen),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('CUSTOMER',
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ),

                  // ── RIDER MARKER (Smooth animated) ───────────────────────
                  if (riderPos != null)
                    Marker(
                      point: riderPos,
                      width: 90, height: 90,
                      child: _PulsingMarker(
                        color: const Color(0xFF0EA5E9),
                        icon: Icons.motorcycle_rounded,
                        label: 'YOU',
                        pulseController: _pulseController,
                        isRider: true,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── GLASS HEADER ────────────────────────────────────────────────
          Positioned(
            top: 50, left: 16, right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.06), blurRadius: 24)],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppTheme.darkText, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ORDER #${order.displayId.isNotEmpty ? order.displayId : order.id.substring(order.id.length - 6).toUpperCase()}',
                              style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.darkText),
                            ),
                            Row(children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (_, __) => Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ).animate(onPlay: (c) => c.repeat())
                                    .shimmer(duration: 1500.ms),
                              ),
                              const SizedBox(width: 8),
                              Text(_isFetchingRoute ? 'Calculating route...' : _statusMessage,
                                  style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: AppTheme.mediumText,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ],
                        ),
                      ),
                      if (_isFetchingRoute)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: AppTheme.primaryOrange, strokeWidth: 2)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: -1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),

          // ── MAP ACTION BUTTONS ────────────────────────────────────────────
          Positioned(
            bottom: 50, right: 16,
            child: Column(
              children: [
                _buildMapAction(
                  icons.Iconsax.shop_copy, AppTheme.primaryOrange,
                  () => _mapController.move(storePoint, 16.5)),
                const SizedBox(height: 10),
                _buildMapAction(
                  Icons.flag_rounded, AppTheme.accentGreen,
                  () => _mapController.move(destPoint, 16.5)),
                const SizedBox(height: 10),
                _buildMapAction(
                  icons.Iconsax.radar_2_copy, const Color(0xFF0EA5E9),
                  () => _fitBounds()),
                if (riderPos != null) ...[
                  const SizedBox(height: 10),
                  _buildMapAction(
                    Icons.motorcycle_rounded, const Color(0xFF0EA5E9),
                    () => _mapController.move(riderPos, 16.5)),
                ],
                const SizedBox(height: 10),
                _buildMapAction(
                  Icons.add, Colors.black87,
                  () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                const SizedBox(height: 10),
                _buildMapAction(
                  Icons.remove, Colors.black87,
                  () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                const SizedBox(height: 10),
                _buildMapStyleSwitcher(),
              ],
            ),
          ).animate().slideX(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
        ],
      ),
    );
  }

  Widget _buildMapStyleSwitcher() {
    return PopupMenuButton<String>(
      tooltip: 'Change Map Style',
      onSelected: (style) {
        setState(() {
          _currentMapStyleUrl = style;
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}', child: Text('Standard (Google)')),
        const PopupMenuItem(value: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}', child: Text('Satellite')),
        const PopupMenuItem(value: 'https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}', child: Text('Terrain')),
        const PopupMenuItem(value: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', child: Text('Voyager')),
        const PopupMenuItem(value: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', child: Text('Dark Mode')),
      ],
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppTheme.primaryOrange.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
          ],
          border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.15), width: 1.5),
        ),
        child: const Icon(Icons.layers_outlined, color: AppTheme.primaryOrange, size: 22),
      ),
    );
  }

  Widget _buildMapAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
          ],
          border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

// ── Premium Pulsing Marker Widget ─────────────────────────────────────────────
class _PulsingMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final AnimationController pulseController;
  final bool isRider;

  const _PulsingMarker({
    required this.color,
    required this.icon,
    required this.label,
    required this.pulseController,
    this.isRider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Pulse rings
            AnimatedBuilder(
              animation: pulseController,
              builder: (_, __) {
                final t = pulseController.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Container(
                        width: 44 + 24 * t, height: 44 + 24 * t,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: ((1 - t) * 0.5).clamp(0.0, 1.0),
                      child: Container(
                        width: 44 + 44 * t, height: 44 + 44 * t,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            // Marker body
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isRider ? Colors.white : color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: isRider ? color : Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 5)),
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08), blurRadius: 6),
                ],
              ),
              child: Icon(icon,
                  color: isRider ? color : Colors.white,
                  size: isRider ? 22 : 18),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)],
          ),
          child: Text(label,
              style: GoogleFonts.outfit(
                  color: Colors.white, fontSize: 7,
                  fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
      ],
    );
  }
}

// Custom painter for pin tail
class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}
