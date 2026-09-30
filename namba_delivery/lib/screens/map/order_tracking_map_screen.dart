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
  
  // ── Unified Dual-Route Points & Metrics ──
  List<LatLng> _pickupPolylinePoints = [];   // Rider ➔ Store (Pickup Leg)
  List<LatLng> _deliveryPolylinePoints = []; // Store ➔ Customer (Delivery Leg - Exact Admin Route)
  
  double _pickupDistanceKm = 0.0;
  double _pickupDurationMins = 0.0;
  double _deliveryDistanceKm = 0.0;
  double _deliveryDurationMins = 0.0;
  double _totalTripKm = 0.0;

  bool _isFetchingPickup = false;
  bool _isFetchingDelivery = false;
  bool _hasInitialDeliveryRouted = false;
  LatLng? _lastRoutedRiderPos;

  // 0: Rider ➔ Shop (Pickup), 1: Shop ➔ Customer (Delivery), 2: Full Journey
  int _selectedSegment = 0;

  String _currentMapStyleUrl = 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}';
  bool _isSatellite = false;
  String _statusMessage = 'Calculating accurate road routes...';
  StreamSubscription<Position>? _positionSubscription;

  // Smooth marker animation
  late AnimationController _markerMoveController;
  late Animation<double> _markerMoveAnim;
  LatLng? _previousPosition;

  // Pulsing animation
  late AnimationController _pulseController;

  // In-App Navigation State
  bool _isInAppNavigating = false;
  String _currentNavInstruction = '';

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

  @override
  void initState() {
    super.initState();
    _selectedSegment = widget.focusOnCustomer ? 1 : 0;

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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // Fast-path: load last known position instantly
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        final quickPos = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _currentPosition = quickPos;
          _animatedPosition = quickPos;
        });
      }
    } catch (_) {}

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).timeout(const Duration(seconds: 4), onTimeout: () async {
      return (await Geolocator.getLastKnownPosition()) ??
          Position(
            latitude: 11.3410,
            longitude: 77.7172,
            timestamp: DateTime.now(),
            accuracy: 10,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
    });

    if (mounted) {
      final currentPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = currentPos;
        _animatedPosition = currentPos;
      });

      final provider = Provider.of<DeliveryProvider>(context, listen: false);
      final order = provider.activeOrders.firstWhere(
        (o) => o.id == widget.orderId,
        orElse: () => provider.activeOrders.first,
      );

      final storePoint = LatLng(order.storeLat ?? 11.3410, order.storeLng ?? 77.7172);
      final destPoint = LatLng(order.destLat ?? 11.3410, order.destLng ?? 77.7172);

      // 1. Fetch Delivery Route (Store ➔ Customer - Exact same as Admin)
      _fetchDeliveryRoadRoute(storePoint, destPoint);

      // 2. Fetch Pickup Route (Rider ➔ Store)
      _fetchPickupRoadRoute(currentPos, storePoint);

      _fitInitialView(storePoint, destPoint);
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        final newPos = LatLng(position.latitude, position.longitude);
        _animateMarkerTo(newPos);

        if (_lastRoutedRiderPos == null ||
            Geolocator.distanceBetween(_lastRoutedRiderPos!.latitude, _lastRoutedRiderPos!.longitude, newPos.latitude, newPos.longitude) > 25) {
          _lastRoutedRiderPos = newPos;
          final provider = Provider.of<DeliveryProvider>(context, listen: false);
          final order = provider.activeOrders.firstWhere(
            (o) => o.id == widget.orderId,
            orElse: () => provider.activeOrders.first,
          );
          final storePoint = LatLng(order.storeLat ?? 11.3410, order.storeLng ?? 77.7172);
          _fetchPickupRoadRoute(newPos, storePoint);
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
          if (_pickupPolylinePoints.isNotEmpty) {
            _pickupPolylinePoints[0] = animPos;
          }
        });
      }
    });
  }

  void _fitInitialView(LatLng storePoint, LatLng destPoint) {
    if (widget.focusOnCustomer) {
      _mapController.move(destPoint, 15.0);
    } else {
      _mapController.move(storePoint, 15.0);
    }
  }

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
              if (modifier.contains('left')) {
                dirText = 'Turn Left';
              } else if (modifier.contains('right')) {
                dirText = 'Turn Right';
              } else if (type == 'arrive') {
                dirText = 'Arriving at destination';
              }

              if (name.isNotEmpty) {
                dirText += ' onto $name';
              }
              if (dist > 0) {
                dirText += ' ($dist m)';
              }

              _currentNavInstruction = dirText;
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Step parse error: $e');
    }
  }

  // ── Unified 2-Wheeler / Bike-First Routing Engine (Identical to Admin App) ──
  Future<void> _fetchDeliveryRoadRoute(LatLng start, LatLng end) async {
    if (_isFetchingDelivery) return;
    setState(() => _isFetchingDelivery = true);

    final straightLineMeters = Geolocator.distanceBetween(
      start.latitude, start.longitude, end.latitude, end.longitude
    );

    final urls = [
      'https://routing.openstreetmap.de/routed-bike/route/v1/biking/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&alternatives=3',
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&alternatives=3',
      'https://routing.openstreetmap.de/routed-car/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=3',
    ];

    List<LatLng>? routePoints;
    double? distMeters;
    double? durationSecs;

    try {
      final headers = {'User-Agent': 'NambaDeliveryApp/1.0 (delivery.namba@gmail.com)'};
      final responses = await Future.wait(
        urls.map((url) => http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500))),
      );

      dynamic bestRoute;
      double minDistance = double.infinity;

      for (final res in responses) {
        if (res.statusCode == 200 && res.body.isNotEmpty) {
          try {
            final data = jsonDecode(res.body);
            final routes = data['routes'] as List? ?? [];
            for (var r in routes) {
              final d = (r['distance'] as num).toDouble();
              if (d < minDistance && d > 0) {
                minDistance = d;
                bestRoute = r;
              }
            }
          } catch (_) {}
        }
      }

      if (bestRoute != null && minDistance < double.infinity) {
        final List coords = bestRoute['geometry']['coordinates'];
        routePoints = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        distMeters = minDistance;
        durationSecs = (bestRoute['duration'] as num).toDouble();
      }
    } catch (e) {
      debugPrint('[DeliveryRoute] Fetch error: $e');
    }

    if (routePoints != null && routePoints.isNotEmpty && distMeters != null) {
      final accuratePoints = [start, ...routePoints];
      if (accuratePoints.last != end) accuratePoints.add(end);

      if (mounted) {
        setState(() {
          _deliveryPolylinePoints = accuratePoints;
          _deliveryDistanceKm = double.parse((distMeters! / 1000.0).toStringAsFixed(1));
          _deliveryDurationMins = ((durationSecs ?? (distMeters / 400.0)) / 60.0).clamp(1.0, 120.0);
          _totalTripKm = double.parse((_pickupDistanceKm + _deliveryDistanceKm).toStringAsFixed(1));
          _isFetchingDelivery = false;
          _hasInitialDeliveryRouted = true;
        });
      }
    } else {
      final directKm = (straightLineMeters * 1.18) / 1000.0;
      if (mounted) {
        setState(() {
          _deliveryPolylinePoints = [start, end];
          _deliveryDistanceKm = double.parse(directKm.toStringAsFixed(1));
          _deliveryDurationMins = ((directKm / 25.0) * 60.0).clamp(1.0, 120.0);
          _totalTripKm = double.parse((_pickupDistanceKm + _deliveryDistanceKm).toStringAsFixed(1));
          _isFetchingDelivery = false;
          _hasInitialDeliveryRouted = true;
        });
      }
    }
  }

  Future<void> _fetchPickupRoadRoute(LatLng start, LatLng end) async {
    final straightLineMeters = Geolocator.distanceBetween(
      start.latitude, start.longitude, end.latitude, end.longitude
    );

    if (straightLineMeters < 15) {
      if (mounted) {
        setState(() {
          _pickupPolylinePoints = [start, end];
          _pickupDistanceKm = 0.0;
          _pickupDurationMins = 0.0;
          _isFetchingPickup = false;
        });
      }
      return;
    }

    if (_isFetchingPickup) return;
    setState(() => _isFetchingPickup = true);

    final urls = [
      'https://routing.openstreetmap.de/routed-bike/route/v1/biking/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&alternatives=3',
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&alternatives=3',
      'https://routing.openstreetmap.de/routed-car/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=3',
    ];

    List<LatLng>? routePoints;
    double? distMeters;
    double? durationSecs;

    try {
      final headers = {'User-Agent': 'NambaDeliveryApp/1.0 (delivery.namba@gmail.com)'};
      final responses = await Future.wait(
        urls.map((url) => http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500))),
      );

      dynamic bestRoute;
      double minDistance = double.infinity;

      for (final res in responses) {
        if (res.statusCode == 200 && res.body.isNotEmpty) {
          try {
            final data = jsonDecode(res.body);
            final routes = data['routes'] as List? ?? [];
            for (var r in routes) {
              final d = (r['distance'] as num).toDouble();
              if (d < minDistance && d > 0) {
                minDistance = d;
                bestRoute = r;
              }
            }
          } catch (_) {}
        }
      }

      if (bestRoute != null && minDistance < double.infinity) {
        final List coords = bestRoute['geometry']['coordinates'];
        routePoints = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        distMeters = minDistance;
        durationSecs = (bestRoute['duration'] as num).toDouble();
        if (_selectedSegment == 0) {
          _parseOsrmSteps({'routes': [bestRoute]});
        }
      }
    } catch (e) {
      debugPrint('[PickupRoute] Fetch error: $e');
    }

    if (routePoints != null && routePoints.isNotEmpty && distMeters != null) {
      final currentPos = _animatedPosition ?? _currentPosition ?? start;
      final accuratePoints = [currentPos, ...routePoints];
      if (accuratePoints.last != end) accuratePoints.add(end);

      if (mounted) {
        setState(() {
          _pickupPolylinePoints = accuratePoints;
          _pickupDistanceKm = double.parse((distMeters! / 1000.0).toStringAsFixed(1));
          _pickupDurationMins = ((durationSecs ?? (distMeters / 400.0)) / 60.0).clamp(1.0, 120.0);
          _totalTripKm = double.parse((_pickupDistanceKm + _deliveryDistanceKm).toStringAsFixed(1));
          _isFetchingPickup = false;
          _statusMessage = '${_pickupDistanceKm.toStringAsFixed(1)} KM • ${_pickupDurationMins.round()} mins';
        });
        if (!_isInAppNavigating) _fitBounds();
      }
    } else {
      final directKm = (straightLineMeters * 1.18) / 1000.0;
      if (mounted) {
        setState(() {
          _pickupPolylinePoints = [start, end];
          _pickupDistanceKm = double.parse(directKm.toStringAsFixed(1));
          _pickupDurationMins = ((directKm / 25.0) * 60.0).clamp(1.0, 120.0);
          _totalTripKm = double.parse((_pickupDistanceKm + _deliveryDistanceKm).toStringAsFixed(1));
          _isFetchingPickup = false;
          _statusMessage = '${_pickupDistanceKm.toStringAsFixed(1)} KM • ${_pickupDurationMins.round()} mins';
        });
      }
    }
  }

  void _startInAppNavigation(LatLng targetPoint) {
    setState(() {
      _isInAppNavigating = !_isInAppNavigating;
    });
    if (_isInAppNavigating) {
      final start = _currentPosition ?? _animatedPosition;
      if (start != null) {
        _mapController.move(start, 16.8);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('🟢 Live Turn-by-Turn Navigation Active'),
          ]),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _fitBounds() {
    final List<LatLng> pts = [];
    if (_selectedSegment == 0) {
      pts.addAll(_pickupPolylinePoints);
    } else if (_selectedSegment == 1) {
      pts.addAll(_deliveryPolylinePoints);
    } else {
      pts.addAll(_pickupPolylinePoints);
      pts.addAll(_deliveryPolylinePoints);
    }

    if (pts.isEmpty) return;
    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (var p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController.move(
      LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
      13.8,
    );
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

    // Trigger initial delivery route fetch once if not done yet
    if (!_hasInitialDeliveryRouted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchDeliveryRoadRoute(storePoint, destPoint);
      });
    }

    final targetPoint = _selectedSegment == 1 ? destPoint : storePoint;

    return Scaffold(
      body: Stack(
        children: [
          // ── 1. PREMIUM INTERACTIVE LEAFLET MAP ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: targetPoint,
              initialZoom: 14.5,
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

              // ── DUAL ROUTE POLYLINES LAYER ──
              PolylineLayer(
                polylines: [
                  // 🔵 LEG 2: DELIVERY ROUTE (Shop ➔ Customer - Exact Admin Match)
                  if (_deliveryPolylinePoints.isNotEmpty) ...[
                    // Outer glow
                    Polyline(
                      points: _deliveryPolylinePoints,
                      color: const Color(0xFF2563EB).withValues(alpha: _selectedSegment == 1 ? 0.35 : 0.15),
                      strokeWidth: _selectedSegment == 1 ? 14 : 9,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    // Inner line
                    Polyline(
                      points: _deliveryPolylinePoints,
                      color: const Color(0xFF2563EB),
                      strokeWidth: _selectedSegment == 1 ? 5.5 : 3.8,
                      borderStrokeWidth: _selectedSegment == 1 ? 1.8 : 0.8,
                      borderColor: Colors.white,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],

                  // 🟠 LEG 1: PICKUP ROUTE (Rider ➔ Shop)
                  if (_pickupPolylinePoints.isNotEmpty) ...[
                    // Outer glow
                    Polyline(
                      points: _pickupPolylinePoints,
                      color: const Color(0xFFEA580C).withValues(alpha: _selectedSegment == 0 ? 0.35 : 0.15),
                      strokeWidth: _selectedSegment == 0 ? 14 : 9,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    // Inner line
                    Polyline(
                      points: _pickupPolylinePoints,
                      color: const Color(0xFFEA580C),
                      strokeWidth: _selectedSegment == 0 ? 5.5 : 3.8,
                      borderStrokeWidth: _selectedSegment == 0 ? 1.8 : 0.8,
                      borderColor: Colors.white,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ],
              ),

              // ── ALWAYS-VISIBLE ACCURATE MARKERS LAYER ──
              MarkerLayer(
                markers: [
                  // 🏪 1. STORE MARKER (OM Muruga Restaurant) - Always Visible
                  Marker(
                    point: storePoint,
                    width: 90,
                    height: 90,
                    child: _PulsingMarker(
                      color: const Color(0xFFEA580C),
                      icon: icons.Iconsax.shop_copy,
                      label: 'STORE (SHOP)',
                      pulseController: _pulseController,
                    ),
                  ),

                  // 🚩 2. CUSTOMER MARKER (Karthikeyan) - Always Visible
                  Marker(
                    point: destPoint,
                    width: 90,
                    height: 95,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF059669).withValues(alpha: 0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 24),
                        ),
                        CustomPaint(
                          size: const Size(12, 6),
                          painter: const _PinTailPainter(color: Color(0xFF059669)),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF059669).withValues(alpha: 0.3), blurRadius: 6),
                            ],
                          ),
                          child: Text(
                            'CUSTOMER',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🛵 3. RIDER MARKER ("YOU") - Always Visible
                  if (riderPos != null)
                    Marker(
                      point: riderPos,
                      width: 90,
                      height: 90,
                      child: _PulsingMarker(
                        color: const Color(0xFF0284C7),
                        icon: Icons.motorcycle_rounded,
                        label: 'YOU (RIDER)',
                        pulseController: _pulseController,
                        isRider: true,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── 2. EXECUTIVE TOP BAR & ROUTE SEGMENTS SWITCHER ──
          Positioned(
            top: 45,
            left: 14,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Container
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0E0F172A), blurRadius: 20, offset: Offset(0, 6)),
                          BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Color(0xFF0F172A),
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: _selectedSegment == 1
                                            ? const Color(0xFFEFF6FF)
                                            : const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _selectedSegment == 1
                                              ? const Color(0xFFBFDBFE)
                                              : const Color(0xFFFFEDD5),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _selectedSegment == 1 ? Icons.local_shipping_rounded : icons.Iconsax.shop_copy,
                                            size: 11,
                                            color: _selectedSegment == 1 ? const Color(0xFF2563EB) : const Color(0xFFEA580C),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _selectedSegment == 1
                                                ? 'SHOP ➔ CUSTOMER (DELIVERY)'
                                                : (_selectedSegment == 0 ? 'RIDER ➔ SHOP (PICKUP)' : 'FULL JOURNEY OVERVIEW'),
                                            style: GoogleFonts.outfit(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: _selectedSegment == 1 ? const Color(0xFF2563EB) : const Color(0xFFEA580C),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_isFetchingPickup || _isFetchingDelivery) ...[
                                      const SizedBox(width: 6),
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEA580C)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedSegment == 1
                                      ? (order.customerName.isNotEmpty ? order.customerName : 'Customer Drop')
                                      : (order.storeName.isNotEmpty ? order.storeName : 'Shop Location'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (_, __) => Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        _isInAppNavigating && _currentNavInstruction.isNotEmpty
                                            ? _currentNavInstruction
                                            : ((_isFetchingPickup || _isFetchingDelivery)
                                                ? 'Calculating fastest route...'
                                                : _statusMessage),
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: _isInAppNavigating ? const Color(0xFF059669) : const Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
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

                const SizedBox(height: 8),

                // ── 3-PILL ROUTE SEGMENT SWITCHER ──
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.98),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0E0F172A), blurRadius: 16, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Pill 1: Rider -> Shop (Pickup)
                      Expanded(
                        child: _buildSegmentPill(
                          index: 0,
                          icon: Icons.two_wheeler_rounded,
                          title: 'Rider ➔ Shop',
                          kmText: _pickupDistanceKm > 0 ? '${_pickupDistanceKm.toStringAsFixed(1)} KM' : 'Pickup',
                          activeColor: const Color(0xFFEA580C),
                          activeBg: const Color(0xFFFFF7ED),
                          activeBorder: const Color(0xFFFFEDD5),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Pill 2: Shop -> Customer (Delivery - Exact Admin Match)
                      Expanded(
                        child: _buildSegmentPill(
                          index: 1,
                          icon: Icons.storefront_rounded,
                          title: 'Shop ➔ Customer',
                          kmText: _deliveryDistanceKm > 0 ? '${_deliveryDistanceKm.toStringAsFixed(1)} KM' : 'Delivery',
                          activeColor: const Color(0xFF2563EB),
                          activeBg: const Color(0xFFEFF6FF),
                          activeBorder: const Color(0xFFBFDBFE),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Pill 3: Full Trip
                      Expanded(
                        child: _buildSegmentPill(
                          index: 2,
                          icon: Icons.alt_route_rounded,
                          title: 'Full Journey',
                          kmText: _totalTripKm > 0 ? '${_totalTripKm.toStringAsFixed(1)} KM' : 'Total',
                          activeColor: const Color(0xFF7C3AED),
                          activeBg: const Color(0xFFFAF5FF),
                          activeBorder: const Color(0xFFE9D5FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: -1, end: 0, duration: 500.ms, curve: Curves.easeOutQuart),

          // ── 3. MAP FLOATING ACTION BUTTONS ──
          Positioned(
            bottom: 110,
            right: 14,
            child: Column(
              children: [
                // In-App Navigation trigger
                _buildMapAction(
                  _isInAppNavigating ? Icons.alt_route_rounded : Icons.near_me_rounded,
                  _isInAppNavigating ? Colors.white : const Color(0xFF059669),
                  () => _startInAppNavigation(targetPoint),
                  tooltip: 'In-App Navigation',
                  bgColor: _isInAppNavigating ? const Color(0xFF059669) : Colors.white,
                  iconColor: _isInAppNavigating ? Colors.white : const Color(0xFF059669),
                  customShadow: _isInAppNavigating
                      ? [
                          BoxShadow(
                            color: const Color(0xFF059669).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                const SizedBox(height: 8),
                _buildMapAction(
                  icons.Iconsax.shop_copy,
                  const Color(0xFFEA580C),
                  () => _mapController.move(storePoint, 16.5),
                  tooltip: 'Focus Shop',
                ),
                const SizedBox(height: 8),
                _buildMapAction(
                  Icons.person_pin_circle_rounded,
                  const Color(0xFF059669),
                  () => _mapController.move(destPoint, 16.5),
                  tooltip: 'Focus Customer',
                ),
                const SizedBox(height: 8),
                _buildMapAction(
                  icons.Iconsax.radar_2_copy,
                  const Color(0xFF0284C7),
                  () => _fitBounds(),
                  tooltip: 'Fit Whole Route',
                ),
                if (riderPos != null) ...[
                  const SizedBox(height: 8),
                  _buildMapAction(
                    Icons.motorcycle_rounded,
                    const Color(0xFF0284C7),
                    () => _mapController.move(riderPos, 16.5),
                    tooltip: 'Focus Rider Position',
                  ),
                ],
                const SizedBox(height: 8),
                _buildMapAction(
                  Icons.add,
                  const Color(0xFF475569),
                  () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 8),
                _buildMapAction(
                  Icons.remove,
                  const Color(0xFF475569),
                  () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                  tooltip: 'Zoom Out',
                ),
                const SizedBox(height: 8),
                _buildMapAction(
                  _isSatellite ? Icons.map_outlined : Icons.satellite_alt_rounded,
                  const Color(0xFF0284C7),
                  () => _toggleSatellite(),
                  tooltip: 'Toggle Satellite Map',
                ),
                const SizedBox(height: 8),
                _buildMapStyleSwitcher(),
              ],
            ),
          ).animate().slideX(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),

          // ── 4. BOTTOM ROUTE CARD (KM DISTANCE & NAVIGATION) ──
          _buildBottomRouteCard(order, storePoint, destPoint),
        ],
      ),
    );
  }

  Widget _buildSegmentPill({
    required int index,
    required IconData icon,
    required String title,
    required String kmText,
    required Color activeColor,
    required Color activeBg,
    required Color activeBorder,
  }) {
    final isSelected = _selectedSegment == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSegment = index;
            _isInAppNavigating = false;
          });
          _fitBounds();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeBorder : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 12, color: isSelected ? activeColor : const Color(0xFF64748B)),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      kmText,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? activeColor : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 8.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? activeColor : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomRouteCard(DeliveryOrder order, LatLng storePoint, LatLng destPoint) {
    final targetPoint = _selectedSegment == 1 ? destPoint : storePoint;

    final titleName = _selectedSegment == 1
        ? (order.customerName.isNotEmpty ? order.customerName : 'Customer Location')
        : (order.storeName.isNotEmpty ? order.storeName : 'Shop Location');

    final addressText = _selectedSegment == 1
        ? (order.customerAddress.isNotEmpty ? order.customerAddress : 'Customer Coordinates Set On Map')
        : (order.storeAddress.isNotEmpty ? order.storeAddress : 'Shop Address Set On Map');

    final Color accentColor = _selectedSegment == 1
        ? const Color(0xFF2563EB)
        : (_selectedSegment == 0 ? const Color(0xFFEA580C) : const Color(0xFF7C3AED));

    final Color accentBg = _selectedSegment == 1
        ? const Color(0xFFEFF6FF)
        : (_selectedSegment == 0 ? const Color(0xFFFFF7ED) : const Color(0xFFFAF5FF));

    final Color accentBorder = _selectedSegment == 1
        ? const Color(0xFFBFDBFE)
        : (_selectedSegment == 0 ? const Color(0xFFFFEDD5) : const Color(0xFFE9D5FF));

    String distanceStr;
    String durationStr;

    if (_selectedSegment == 0) {
      distanceStr = '${_pickupDistanceKm.toStringAsFixed(1)} KM';
      durationStr = '${_pickupDurationMins.round()} mins';
    } else if (_selectedSegment == 1) {
      distanceStr = '${_deliveryDistanceKm.toStringAsFixed(1)} KM';
      durationStr = '${_deliveryDurationMins.round()} mins';
    } else {
      distanceStr = '${_totalTripKm.toStringAsFixed(1)} KM';
      durationStr = '${(_pickupDurationMins + _deliveryDurationMins).round()} mins';
    }

    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomInset > 0 ? bottomInset + 10 : 16,
      left: 14,
      right: 14,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x180F172A), blurRadius: 24, offset: Offset(0, 10)),
            BoxShadow(color: Color(0x080F172A), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Tier: Route details
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accentBorder),
                  ),
                  child: Icon(
                    _selectedSegment == 1
                        ? Icons.person_pin_circle_rounded
                        : (_selectedSegment == 0 ? icons.Iconsax.shop_copy : Icons.alt_route_rounded),
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            distanceStr,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            durationStr,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF059669),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accentBorder),
                            ),
                            child: Text(
                              _selectedSegment == 1
                                  ? 'DELIVERY LEG'
                                  : (_selectedSegment == 0 ? 'PICKUP LEG' : 'TOTAL TRIP'),
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _selectedSegment == 2
                            ? 'Full Journey: ${order.storeName} ➔ ${order.customerName}'
                            : '$titleName • $addressText',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom Tier: 2 Action buttons side-by-side
            Row(
              children: [
                // 1. Google Maps Navigation Button
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openExternalGoogleMaps(targetPoint.latitude, targetPoint.longitude),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.directions_rounded, size: 18, color: Color(0xFF1D4ED8)),
                            const SizedBox(width: 6),
                            Text(
                              'GOOGLE MAPS',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1D4ED8),
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. In-App Navigation Toggle Button
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _startInAppNavigation(targetPoint),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isInAppNavigating
                                ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
                                : [accentColor, accentColor.withValues(alpha: 0.85)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: (_isInAppNavigating ? const Color(0xFFDC2626) : accentColor).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isInAppNavigating ? Icons.stop_circle_rounded : Icons.navigation_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isInAppNavigating ? 'STOP NAV' : 'IN-APP NAV',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.layers_rounded, color: Color(0xFF475569), size: 20),
      ),
    );
  }

  Widget _buildMapAction(
    IconData icon,
    Color color,
    VoidCallback onTap, {
    String? tooltip,
    Color? bgColor,
    Color? iconColor,
    List<BoxShadow>? customShadow,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor ?? Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: customShadow ??
                  [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
            ),
            child: Icon(icon, color: iconColor ?? color, size: 20),
          ),
        ),
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
                        width: 44 + 24 * t,
                        height: 44 + 24 * t,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: ((1 - t) * 0.5).clamp(0.0, 1.0),
                      child: Container(
                        width: 44 + 44 * t,
                        height: 44 + 44 * t,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.06),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isRider ? Colors.white : color,
                shape: BoxShape.circle,
                border: Border.all(color: isRider ? color : Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 5)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6),
                ],
              ),
              child: Icon(icon, color: isRider ? color : Colors.white, size: isRider ? 22 : 18),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)],
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
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
