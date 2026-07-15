import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String storeName;
  final dynamic storeLocation; // {lat, lng}

  const OrderTrackingScreen({
    super.key, 
    required this.orderId,
    required this.storeName,
    this.storeLocation,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  IO.Socket? _socket;
  LatLng? _riderLocation;
  final MapController _mapController = MapController();
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    _socket = IO.io('http://localhost:5000', 
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .build()
    );

    _socket!.onConnect((_) {
      setState(() => _isConnected = true);
      _socket!.emit('join_room', 'order_${widget.orderId}');
      debugPrint('[Socket] Joined order room: ${widget.orderId}');
    });

    _socket!.on('rider_location_updated', (data) {
      if (mounted) {
        setState(() {
          _riderLocation = LatLng(data['lat'], data['lng']);
        });
        // Optionally center map on rider
        // _mapController.move(_riderLocation!, _mapController.camera.zoom);
      }
    });

    _socket!.onDisconnect((_) => setState(() => _isConnected = false));
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Track Delivery', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
            Text('Order #${widget.orderId.substring(widget.orderId.length - 8)}', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.lightText)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _isConnected ? Icons.check_circle : Icons.error_outline, 
              color: _isConnected ? Colors.green : Colors.red,
              size: 20,
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _riderLocation ?? const LatLng(11.0168, 76.9558), // Default to Coimbatore if unknown
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.namba.vendor',
              ),
              MarkerLayer(
                markers: [
                  if (widget.storeLocation != null)
                    Marker(
                      point: LatLng(widget.storeLocation['lat'], widget.storeLocation['lng']),
                      width: 80,
                      height: 80,
                      child: const Icon(Iconsax.shop, color: AppTheme.primaryOrange, size: 40),
                    ),
                  if (_riderLocation != null)
                    Marker(
                      point: _riderLocation!,
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                            child: const Icon(Iconsax.truck_fast, color: AppTheme.accentBlue, size: 30),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.accentBlue, borderRadius: BorderRadius.circular(4)),
                            child: const Text('Rider', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          _buildTrackingCard(),
        ],
      ),
    );
  }

  Widget _buildTrackingCard() {
    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.accentBlue.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Iconsax.clock, color: AppTheme.accentBlue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_riderLocation == null ? 'Waiting for rider signal...' : 'Rider is on the way', 
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(_riderLocation == null ? 'Connectivity Active' : 'Real-time sync enabled', 
                    style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 13)),
                ],
              ),
            ),
            if (_riderLocation != null)
              ElevatedButton(
                onPressed: () => _mapController.move(_riderLocation!, 15),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkText,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Icon(Iconsax.gps, color: Colors.white, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
