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
import 'package:url_launcher/url_launcher.dart';
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
  String _currentMapStyleUrl = 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}';
  bool _isSatellite = false;
  
  void _toggleSatellite() {
    setState(() {
      _isSatellite = !_isSatellite;
      _currentMapStyleUrl = _isSatellite
          ? 'https://mt{s}.google.com/vt/lyrs=y,traffic&x={x}&y={y}&z={z}'
          : 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}';
    });
  }

  Future<void> _openExternalGoogleMaps(double lat, double lng) async {
    final googleNavUrl = 'google.navigation:q=$lat,$lng&mode=d';
    final webUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    final uri = Uri.parse(googleNavUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }
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

    LatLng? lastRoutedPos;

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
    if (mounted) {
      final currentPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = currentPos;
        _animatedPosition = currentPos;
      });
      _fitInitialView();

      final provider = Provider.of<DeliveryProvider>(context, listen: false);
      final order = provider.activeOrders.firstWhere(
        (o) => o.id == widget.orderId,
        orElse: () => provider.activeOrders.first,
      );
      final targetPoint = widget.focusOnCustomer
          ? LatLng(order.destLat ?? 11.3410, order.destLng ?? 77.7172)
          : LatLng(order.storeLat ?? 11.3410, order.storeLng ?? 77.7172);

      _fetchRoadRoute(currentPos, targetPoint);
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (mounted) {
        final newPos = LatLng(position.latitude, position.longitude);
        _animateMarkerTo(newPos);
        
        if (lastRoutedPos == null || Geolocator.distanceBetween(
            lastRoutedPos!.latitude, lastRoutedPos!.longitude, newPos.latitude, newPos.longitude) > 20) {
          lastRoutedPos = newPos;
          final provider = Provider.of<DeliveryProvider>(context, listen: false);
          final order = provider.activeOrders.firstWhere(
            (o) => o.id == widget.orderId,
            orElse: () => provider.activeOrders.first,
          );
          final targetPoint = widget.focusOnCustomer
              ? LatLng(order.destLat ?? 11.3410, order.destLng ?? 77.7172)
              : LatLng(order.storeLat ?? 11.3410, order.storeLng ?? 77.7172);
          _fetchRoadRoute(newPos, targetPoint);
        }
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
        final animPos = LatLng(
          _previousPosition!.latitude + (target.latitude - _previousPosition!.latitude) * t,
          _previousPosition!.longitude + (target.longitude - _previousPosition!.longitude) * t,
        );
        setState(() {
          _animatedPosition = animPos;
          if (_polylinePoints.isNotEmpty) {
            _polylinePoints[0] = animPos;
          }
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

  double _routeDistanceKm = 0.0;
  double _routeDurationMins = 0.0;
  bool _isInAppNavigating = false;
  String _currentNavInstruction = '';
  IconData _currentNavIcon = Icons.navigation_rounded;

  void _parseOsrmSteps(dynamic data) {
    try {
      final legs = data['routes']?[0]?['legs'] as List?;
      if (legs != null && legs.isNotEmpty) {
        final steps = legs[0]['steps'] as List?;
        if (steps != null && steps.isNotEmpty) {
          for (var step in steps) {
            final maneuver = step['maneuver'] ?? {};
            final type = maneuver['type']?.toString() ?? '';
            final modifier = maneuver['modifier']?.toString() ?? '';
            final name = step['name']?.toString() ?? '';
            final dist = ((step['distance'] as num?)?.toDouble() ?? 0).round();

            if (type != 'depart' && dist > 20) {
              String dirText = 'Continue straight';
              IconData icon = Icons.arrow_upward_rounded;

              if (modifier.contains('left')) {
                dirText = 'Turn Left';
                icon = Icons.turn_left_rounded;
              } else if (modifier.contains('right')) {
                dirText = 'Turn Right';
                icon = Icons.turn_right_rounded;
              } else if (type == 'arrive') {
                dirText = 'Arriving at destination';
                icon = Icons.flag_rounded;
              }

              if (name.isNotEmpty) {
                dirText += ' onto $name';
              }
              if (dist > 0) {
                dirText += ' ($dist m)';
              }

              _currentNavInstruction = dirText;
              _currentNavIcon = icon;
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Step parse error: $e');
    }
  }

  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    if (_isFetchingRoute) return;
    setState(() {
      _isFetchingRoute = true;
      _statusMessage = 'Calculating shortest route & distance...';
    });

    final straightLineMeters = Geolocator.distanceBetween(
      start.latitude, start.longitude, end.latitude, end.longitude
    );

    try {
      // 🚴 Use OSRM routed-bike profile: Gives direct, shortest two-wheeler road route without car highway loops
      final bikeUrl =
          'https://routing.openstreetmap.de/routed-bike/route/v1/biking/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&continue_straight=false';
      final carUrl =
          'https://routing.openstreetmap.de/routed-car/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&continue_straight=false';
      final fallbackUrl =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&continue_straight=false';

      http.Response? response;
      try {
        response = await http.get(Uri.parse(bikeUrl)).timeout(const Duration(seconds: 6));
        if (response.statusCode != 200) {
          response = await http.get(Uri.parse(carUrl)).timeout(const Duration(seconds: 6));
        }
      } catch (_) {
        try {
          response = await http.get(Uri.parse(fallbackUrl)).timeout(const Duration(seconds: 6));
        } catch (_) {}
      }

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        double distMeters = (data['routes'][0]['distance'] as num).toDouble();
        double durationSecs = (data['routes'][0]['duration'] as num).toDouble();

        // 🛡️ SANITY CHECK: If OSRM returned an absurd detour (> 2.2x straight line), cap/adjust distance to accurate road distance (straight line * 1.3)
        final maxRealisticMeters = straightLineMeters * 2.2;
        if (straightLineMeters > 50 && distMeters > maxRealisticMeters) {
          distMeters = straightLineMeters * 1.3;
          durationSecs = (distMeters / 1000.0 / 30.0) * 3600.0;
        }

        _parseOsrmSteps(data);

        if (mounted) {
          final List<LatLng> rawPoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          final List<LatLng> seamlessPoints = [];
          final currentPos = _animatedPosition ?? _currentPosition ?? start;
          seamlessPoints.add(currentPos);
          if (rawPoints.isNotEmpty) {
            seamlessPoints.addAll(rawPoints);
          }
          seamlessPoints.add(end);

          setState(() {
            _polylinePoints = seamlessPoints;
            _routeDistanceKm = distMeters / 1000.0;
            _routeDurationMins = (durationSecs / 60.0).clamp(1.0, 120.0);
            _isFetchingRoute = false;
            _statusMessage = '${_routeDistanceKm.toStringAsFixed(1)} KM • ${_routeDurationMins.round()} mins';
          });
          if (_polylinePoints.isNotEmpty && !_isInAppNavigating) _fitBounds();
        }
      } else {
        throw Exception('Routing response invalid');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _polylinePoints = [start, end];
          _routeDistanceKm = (straightLineMeters * 1.35) / 1000.0;
          _routeDurationMins = (_routeDistanceKm / 30.0) * 60.0;
          _isFetchingRoute = false;
          _statusMessage = '${_routeDistanceKm.toStringAsFixed(1)} KM • ${_routeDurationMins.round()} mins';
        });
      }
    }
  }

  void _startInAppNavigation(LatLng targetPoint) {
    setState(() {
      _isInAppNavigating = true;
    });
    final start = _currentPosition ?? _animatedPosition;
    if (start != null) {
      _fetchRoadRoute(start, targetPoint);
      _mapController.move(start, 16.8);
    } else {
      _fitBounds();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('🟢 In-App Live Navigation Active inside Namba App'),
          ]),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
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

    final isFocusingCustomer = widget.focusOnCustomer;
    final targetPoint = isFocusingCustomer ? destPoint : storePoint;
    final routeStart = riderPos ?? targetPoint;
    final routeEnd = targetPoint;

    if (_lastRoutedStatus != order.status || (riderPos != null && !_hasRoutedFromRiderPos)) {
      _lastRoutedStatus = order.status;
      if (riderPos != null) _hasRoutedFromRiderPos = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchRoadRoute(routeStart, routeEnd);
      });
    }

    final accentThemeColor = isFocusingCustomer ? AppTheme.accentGreen : AppTheme.primaryOrange;

    return Scaffold(
      body: Stack(
        children: [
          // ── PREMIUM MAP ──────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: routeEnd,
              initialZoom: 15.0,
              maxZoom: 20.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _currentMapStyleUrl,
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.namba.delivery',
                maxZoom: 20,
                maxNativeZoom: 19,
              ),

              // Route polyline with smooth glow effect
              if (_polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Outer glow
                    Polyline(
                      points: _polylinePoints,
                      color: accentThemeColor.withValues(alpha: 0.18),
                      strokeWidth: 16,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    // Mid glow
                    Polyline(
                      points: _polylinePoints,
                      color: accentThemeColor.withValues(alpha: 0.35),
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    // Main solid line
                    Polyline(
                      points: _polylinePoints,
                      color: accentThemeColor,
                      strokeWidth: 5.5,
                      borderStrokeWidth: 1.8,
                      borderColor: Colors.white,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // ── STORE MARKER (Only shown when viewing shop/store) ─────────
                  if (!isFocusingCustomer)
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

                  // ── DESTINATION MARKER (Only shown when viewing customer) ─────
                  if (isFocusingCustomer)
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

                  // ── RIDER MARKER ─────────────────────────────────────────
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
                              isFocusingCustomer ? 'CUSTOMER LOCATION' : 'SHOP LOCATION',
                              style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: accentThemeColor,
                                  letterSpacing: 1.5),
                            ),
                            Text(
                              isFocusingCustomer
                                  ? (order.customerName.isNotEmpty ? order.customerName : 'Customer Location')
                                  : (order.storeName.isNotEmpty ? order.storeName : 'Shop Location'),
                              style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.darkText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                              Expanded(
                                child: Text(
                                  _isInAppNavigating && _currentNavInstruction.isNotEmpty
                                      ? '🟢 $_currentNavInstruction'
                                      : (_isFetchingRoute ? 'Calculating route...' : _statusMessage),
                                  style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: _isInAppNavigating ? const Color(0xFF10B981) : AppTheme.mediumText,
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
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
            bottom: 85, right: 16,
            child: Column(
              children: [
                // In-App Navigation trigger
                _buildMapAction(
                  Icons.near_me_rounded, AppTheme.accentGreen,
                  () => _startInAppNavigation(targetPoint),
                  tooltip: 'In-App Navigation',
                ),
                const SizedBox(height: 8),
                if (!isFocusingCustomer)
                  _buildMapAction(
                    icons.Iconsax.shop_copy, AppTheme.primaryOrange,
                    () => _mapController.move(storePoint, 16.5),
                    tooltip: 'Focus Shop',
                  ),
                if (isFocusingCustomer)
                  _buildMapAction(
                    Icons.flag_rounded, AppTheme.accentGreen,
                    () => _mapController.move(destPoint, 16.5),
                    tooltip: 'Focus Customer',
                  ),
                const SizedBox(height: 8),
                _buildMapAction(
                  icons.Iconsax.radar_2_copy, const Color(0xFF0EA5E9),
                  () => _fitBounds(),
                  tooltip: 'Fit Whole Route',
                ),
                if (riderPos != null) ...[
                  const SizedBox(height: 8),
                  _buildMapAction(
                    Icons.motorcycle_rounded, const Color(0xFF0EA5E9),
                    () => _mapController.move(riderPos, 16.5),
                    tooltip: 'Focus Rider Position',
                  ),
                ],
                const SizedBox(height: 8),
                _buildMapAction(
                  Icons.add, Colors.black87,
                  () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 8),
                _buildMapAction(
                  Icons.remove, Colors.black87,
                  () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                  tooltip: 'Zoom Out',
                ),
                const SizedBox(height: 8),
                _buildMapAction(
                  _isSatellite ? Icons.map_outlined : Icons.satellite_alt_rounded, Colors.purpleAccent,
                  () => _toggleSatellite(),
                  tooltip: 'Toggle Satellite Map',
                ),
                const SizedBox(height: 8),
                _buildMapStyleSwitcher(),
              ],
            ),
          ).animate().slideX(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),

          // ── BOTTOM ROUTE CARD (KM DISTANCE & NAVIGATION) ───────────────────
          _buildBottomRouteCard(order, isFocusingCustomer, targetPoint),
        ],
      ),
    );
  }

  Widget _buildBottomRouteCard(DeliveryOrder order, bool isFocusingCustomer, LatLng targetPoint) {
    final titleName = isFocusingCustomer
        ? (order.customerName.isNotEmpty ? order.customerName : 'Customer Location')
        : (order.storeName.isNotEmpty ? order.storeName : 'Shop Location');
    final addressText = isFocusingCustomer
        ? (order.customerAddress.isNotEmpty ? order.customerAddress : 'Customer Coordinates Set On Map')
        : (order.storeAddress.isNotEmpty ? order.storeAddress : 'Shop Address Set On Map');

    return Positioned(
      bottom: 24, left: 16, right: 84,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isFocusingCustomer ? AppTheme.accentGreen : AppTheme.primaryOrange).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isFocusingCustomer ? Icons.flag_rounded : icons.Iconsax.shop_copy,
                  color: isFocusingCustomer ? AppTheme.accentGreen : AppTheme.primaryOrange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _routeDistanceKm > 0 
                          ? '${_routeDistanceKm.toStringAsFixed(1)} KM  •  ${_routeDurationMins.round()} mins'
                          : 'Calculating route...',
                      style: GoogleFonts.outfit(
                        fontSize: 14, 
                        fontWeight: FontWeight.w900, 
                        color: AppTheme.darkText
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$titleName - $addressText',
                      style: GoogleFonts.outfit(
                        fontSize: 11, 
                        color: AppTheme.mediumText, 
                        fontWeight: FontWeight.w600
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _startInAppNavigation(targetPoint),
                onLongPress: () => _openExternalGoogleMaps(targetPoint.latitude, targetPoint.longitude),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isInAppNavigating
                        ? const Color(0xFF10B981)
                        : (isFocusingCustomer ? AppTheme.accentGreen : AppTheme.primaryOrange),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isInAppNavigating
                        ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 8)]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isInAppNavigating ? Icons.alt_route_rounded : Icons.navigation_rounded, 
                        size: 14, 
                        color: Colors.white
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isInAppNavigating ? 'LIVE NAV' : 'NAV', 
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 11)
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
        const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}', child: Text('Google Traffic Map')),
        const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=y,traffic&x={x}&y={y}&z={z}', child: Text('Google Hybrid Satellite')),
        const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=r,traffic&x={x}&y={y}&z={z}', child: Text('Google Roads')),
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

  Widget _buildMapAction(IconData icon, Color color, VoidCallback onTap, {String? tooltip}) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 3)),
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6),
          ],
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
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
