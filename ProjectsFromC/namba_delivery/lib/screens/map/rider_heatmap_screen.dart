import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';

class RiderHeatmapScreen extends StatefulWidget {
  const RiderHeatmapScreen({super.key});

  @override
  State<RiderHeatmapScreen> createState() => _RiderHeatmapScreenState();
}

class _RiderHeatmapScreenState extends State<RiderHeatmapScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _orderPoints = [];
  List<LatLng> _riderPoints = [];
  bool _isLoading = false;

  static String get _baseUrl {
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5000/api/v1';
    } catch (_) {}
    return 'http://localhost:5000/api/v1';
  }

  @override
  void initState() {
    super.initState();
    _fetchHeatmap();
  }

  Future<void> _fetchHeatmap() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/heatmap'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orders = data['data']['orders'] as List;
        final riders = data['data']['riders'] as List;
        
        setState(() {
          _orderPoints = orders.map<LatLng>((o) => LatLng(o['lat'], o['lng'])).toList();
          _riderPoints = riders.map<LatLng>((r) => LatLng(r['lat'], r['lng'])).toList();
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _orderPoints.isNotEmpty ? _orderPoints.first : LatLng(13.0827, 80.2707),
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.namba.delivery',
              ),
              CircleLayer(
                circles: _orderPoints.map<CircleMarker>((p) => CircleMarker(
                  point: p,
                  radius: 150,
                  useRadiusInMeter: true,
                  color: AppTheme.primaryOrange.withOpacity(0.35),
                  borderColor: AppTheme.primaryOrange,
                  borderStrokeWidth: 1.5,
                )).toList(),
              ),
              MarkerLayer(
                markers: _riderPoints.map<Marker>((p) => Marker(
                  point: p,
                  width: 30, height: 30,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppTheme.softShadow),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.delivery_dining, color: AppTheme.accentGreen, size: 18),
                  ),
                )).toList(),
              ),
            ],
          ),
          
          // Custom Header
          Positioned(
            top: 60, left: 24, right: 24,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppTheme.softShadow),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.softShadow),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NAMBA HOT ZONES', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppTheme.primaryOrange, fontSize: 12, letterSpacing: 1)),
                        Text('Find orders faster in red zones', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Legend
          Positioned(
            bottom: 40, left: 24, right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      _legendDot(AppTheme.primaryOrange, 'HIGH DEMAND'),
                      const SizedBox(width: 24),
                      _legendDot(AppTheme.accentGreen, 'OTHER RIDERS'),
                    ],
                  ),
                ),
                FloatingActionButton(
                  onPressed: _fetchHeatmap,
                  backgroundColor: AppTheme.primaryOrange,
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ],
    );
  }
}
