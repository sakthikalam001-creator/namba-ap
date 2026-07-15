import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'theme/admin_theme.dart';

class LiveTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const LiveTrackingScreen({super.key, required this.order});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  IO.Socket? _socket;
  LatLng? _riderLocation;
  final MapController _mapController = MapController();
  bool _isConnected = false;
  bool _isFetchingRoute = false;
  String _status = 'Initializing Elite Systems...';
  double _progress = 0.0;
  List<LatLng> _polylinePoints = [];
  Timer? _simTimer;
  bool _hasFittedBounds = false;

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    _socket = IO.io('http://127.0.0.1:5000', 
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .build()
    );

    _socket!.onConnect((_) {
      setState(() => _isConnected = true);
      _socket!.emit('join_room', 'order_${widget.order['_id']}');
    });

    _socket!.on('rider_location_updated', (data) {
      if (mounted) {
        final newLoc = LatLng(data['lat'], data['lng']);
        setState(() {
          _riderLocation = newLoc;
          _status = data['status'] ?? 'On the way';
          _progress = (data['progress'] ?? 0.0).toDouble();
        });
        _mapController.move(newLoc, _mapController.camera.zoom);
      }
    });

    _socket!.onDisconnect((_) => setState(() => _isConnected = false));
  }

  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    if (_isFetchingRoute) return;
    setState(() => _isFetchingRoute = true);

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        
        setState(() {
          _polylinePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          _isFetchingRoute = false;
          _status = 'Road Path Synced';
        });
        
        // Auto-fit to show entire route
        _fitCameraToBounds();
      } else {
        throw Exception();
      }
    } catch (e) {
      _polylinePoints = [start, end];
      setState(() => _isFetchingRoute = false);
    }
  }

  void _fitCameraToBounds() {
    if (_polylinePoints.isEmpty) return;
    
    // Simple bound fitting (Calculated from points)
    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (var p in _polylinePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 13.5); // Adjust initial zoom to fit context
  }

  void _startSimulatedDrive() {
    if (_polylinePoints.length < 2) return;
    
    _simTimer?.cancel();
    int currentStep = 0;
    
    _simTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (currentStep >= _polylinePoints.length) {
        timer.cancel();
        setState(() => _status = 'Order Delivered! 🏁');
        return;
      }

      final pos = _polylinePoints[currentStep];
      setState(() {
        _riderLocation = pos;
        _progress = currentStep / (_polylinePoints.length - 1);
        _status = 'Approaching: ${((1.0 - _progress) * 10).toStringAsFixed(1)} km left';
      });
      _mapController.move(pos, 16.5);
      currentStep++;
    });
  }

  @override
  void dispose() {
    _socket?.dispose();
    _simTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final driverName = order['driver'] != null ? order['driver']['name'] : 'N/A';
    final vCoords = order['vendor']?['location']?['coordinates'];
    final dCoords = order['deliveryAddress']?['location']?['coordinates'] ?? order['deliveryCoordinates']?['coordinates'];
    
    double vendorLat = (vCoords is List && vCoords.length >= 2) ? (vCoords[1] as num).toDouble() : 11.0168;
    double vendorLng = (vCoords is List && vCoords.length >= 2) ? (vCoords[0] as num).toDouble() : 76.9558;
    
    double destLat = (dCoords is List && dCoords.length >= 2) ? (dCoords[1] as num).toDouble() : 11.0500;
    double destLng = (dCoords is List && dCoords.length >= 2) ? (dCoords[0] as num).toDouble() : 76.9800;

    final LatLng storePoint = LatLng(vendorLat, vendorLng);
    final LatLng destPoint = LatLng(destLat, destLng);

    if (_polylinePoints.isEmpty && !_isFetchingRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRoadRoute(storePoint, destPoint));
    }

    return Scaffold(
      body: Stack(
        children: [
          // MODERN MAP TILE (CartoDB Voyager)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _riderLocation ?? storePoint,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.namba.admin',
              ),
              if (_polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Glow / Shadow Polyline
                    Polyline(
                      points: _polylinePoints,
                      color: Colors.orange.withOpacity(0.2),
                      strokeWidth: 10,
                    ),
                    // Main Routing Polyline
                    Polyline(
                      points: _polylinePoints,
                      color: Colors.orange,
                      strokeWidth: 4,
                      borderStrokeWidth: 1.5,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // PULSING SHOP MARKER
                  Marker(
                    point: storePoint,
                    width: 80, height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), shape: BoxShape.circle)).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1,1), end: const Offset(2.5, 2.5), duration: 2000.ms).fadeOut(),
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]),
                          child: const Icon(Icons.store_rounded, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                  // DESTINATION MARKER
                  Marker(
                    point: destPoint,
                    width: 60, height: 60,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AdminColors.info, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  // PULSING BIKE MARKER
                  if (_riderLocation != null)
                    Marker(
                      point: _riderLocation!,
                      width: 90, height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(width: 45, height: 45, decoration: BoxDecoration(color: AdminColors.success.withOpacity(0.3), shape: BoxShape.circle)).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1,1), end: const Offset(2.5, 2.5), duration: 1500.ms).fadeOut(),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AdminColors.success, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15)]),
                            child: const Icon(Icons.motorcycle, color: AdminColors.success, size: 30),
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: 800.ms),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ELITE GLASS HEADER
          Positioned(
            top: 50, left: 20, right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30)],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                          child: const Icon(Icons.arrow_back_ios_new, color: AdminColors.textHeading, size: 16),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live Tracking #${order['displayId']}',
                              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AdminColors.textHeading, letterSpacing: -0.8),
                            ),
                            Row(
                              children: [
                                if (_isFetchingRoute)
                                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                                else
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _isConnected ? AdminColors.success : Colors.red, shape: BoxShape.circle)).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms),
                                const SizedBox(width: 10),
                                Text(_isFetchingRoute ? 'Calibrating Route...' : (_isConnected ? 'Live Sync Active' : 'Disconnected'), style: GoogleFonts.outfit(fontSize: 14, color: AdminColors.textMuted, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!_isFetchingRoute)
                        GestureDetector(
                          onTap: _startSimulatedDrive,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Colors.orange, Color(0xFFFF8C42)]),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10)],
                            ),
                            child: Text('PRO TEST', style: GoogleFonts.outfit(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2500.ms),
                        ),
                    ],
                  ),
                ),
              ),
            ).animate().slideY(begin: -2, end: 0, curve: Curves.easeOutQuart, duration: 900.ms),
          ),

          // ELITE GLASS BOTTOM PRO SHEET
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 38),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Hero(
                              tag: 'driver_img_pro',
                              child: Container(
                                width: 75, height: 75,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white, width: 4),
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                                  image: const DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?w=200'), fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(driverName, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AdminColors.textHeading, letterSpacing: -1)),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text('4.9 Rating', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AdminColors.textSub)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), shape: BoxShape.circle),
                              child: IconButton(onPressed: () => _fitCameraToBounds(), icon: Icon(Iconsax.radar, color: Colors.orange, size: 24)),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AdminColors.info, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AdminColors.info.withOpacity(0.4), blurRadius: 15)]),
                              child: Icon(Iconsax.call, color: Colors.white, size: 24),
                            ),
                          ],
                        ),
                        const SizedBox(height: 38),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(22)),
                              child: Icon(Iconsax.routing, color: Colors.orange, size: 28),
                            ),
                            const SizedBox(width: 20),
                            Expanded(child: Text(_status, style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.w900, color: AdminColors.textHeading, height: 1))),
                            if (_riderLocation != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(color: AdminColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                                child: Text('${(10 - (10 * _progress)).toInt()} min', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AdminColors.success)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            children: [
                              LinearProgressIndicator(
                                value: _progress,
                                backgroundColor: AdminColors.border,
                                color: Colors.orange,
                                minHeight: 14,
                              ),
                            ].animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: 0.8, end: 0, curve: Curves.easeOutQuart, duration: 900.ms),
        ],
      ),
    );
  }
}
