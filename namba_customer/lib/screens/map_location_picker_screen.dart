import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../models/models.dart';
import 'home_screen.dart';

class MapLocationPickerScreen extends StatefulWidget {
  final bool isInitialSetup;
  const MapLocationPickerScreen({super.key, this.isInitialSetup = false});

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(11.3410, 77.7172);
  String _addressText = "Fetching address...";
  bool _isLoadingGps = false;
  bool _isResolvingAddress = false;
  String _currentMapStyleUrl = 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}';
  bool _isDragging = false;
  String _addressLabel = "Home";
  final TextEditingController _buildingController = TextEditingController();

  // Animation controllers
  late AnimationController _pinBounceController;
  late AnimationController _pinLiftController;
  late AnimationController _shadowController;
  late Animation<double> _pinBounceAnim;
  late Animation<double> _pinLiftAnim;
  late Animation<double> _shadowAnim;

  // Color palette (Matching Customer App Theme)
  static const Color _primaryOrange = Color(0xFF4F46E5);
  static const Color _darkBg = Color(0xFF1A1A2E);
  static const Color _cardBg = Color(0xFFFAFAFA);

  bool _isMapReady = false;

  void _safeMoveMap(LatLng center, double zoom) {
    if (_isMapReady && mounted) {
      try {
        _mapController.move(center, zoom);
      } catch (e) {
        debugPrint('Safe map move error: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Check if AuthProvider already has a selected address position to center map instantly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final lat = auth.selectedAddress.lat;
      final lng = auth.selectedAddress.lng;
      if (lat != null && lng != null && lat != 0 && lng != 0) {
        setState(() {
          _currentCenter = LatLng(lat, lng);
        });
        _safeMoveMap(_currentCenter, 18.0);
      }
    });

    // Pin bounce after drop
    _pinBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pinBounceAnim = CurvedAnimation(
      parent: _pinBounceController,
      curve: Curves.bounceOut,
    );

    // Pin lift when dragging
    _pinLiftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pinLiftAnim = Tween<double>(begin: 0, end: -18).animate(
      CurvedAnimation(parent: _pinLiftController, curve: Curves.easeOut),
    );

    // Shadow scale when lifted
    _shadowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _shadowAnim = Tween<double>(begin: 1.0, end: 0.45).animate(
      CurvedAnimation(parent: _shadowController, curve: Curves.easeOut),
    );

    _pinBounceController.forward();
    _determinePosition();
  }

  @override
  void dispose() {
    _pinBounceController.dispose();
    _pinLiftController.dispose();
    _shadowController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('GPS is turned off. Please enable GPS in phone settings.'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
      }

      // 1. Initial fast snap using saved address or last known position
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.selectedAddress.lat != null && auth.selectedAddress.lat != 0) {
        final savedLoc = LatLng(auth.selectedAddress.lat!, auth.selectedAddress.lng!);
        setState(() => _currentCenter = savedLoc);
        _safeMoveMap(savedLoc, 18.0);
        _reverseGeocode(savedLoc);
      } else {
        try {
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null && mounted) {
            final snapCenter = LatLng(lastPos.latitude, lastPos.longitude);
            setState(() => _currentCenter = snapCenter);
            _safeMoveMap(snapCenter, 18.0);
            _reverseGeocode(snapCenter);
          }
        } catch (_) {}
      }

      // 2. High-Precision Hardware GPS Satellite Fix
      LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 1),
        );
      } else {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.otherNavigation,
        );
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      ).timeout(const Duration(seconds: 8));

      if (mounted) {
        final freshCenter = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentCenter = freshCenter;
          _isLoadingGps = false;
        });
        _safeMoveMap(freshCenter, 18.5);
        _reverseGeocode(freshCenter);
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('High precision GPS fetch error: $e');
      if (mounted) {
        setState(() => _isLoadingGps = false);
      }
    }
  }

  Future<void> _reverseGeocode(LatLng coords) async {
    if (!mounted) return;
    setState(() { _isResolvingAddress = true; });
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${coords.latitude}&lon=${coords.longitude}&zoom=18&addressdetails=1');
      final res = await http.get(url,
          headers: {'User-Agent': 'NambaCustomerApp/1.0 (contact: test@namba.com)'})
          .timeout(const Duration(milliseconds: 2500));
      if (res.statusCode == 200 && mounted) {
        final decoded = json.decode(res.body);
        final addrDetails = decoded['address'] ?? {};
        
        final road = addrDetails['road'] ?? addrDetails['street'] ?? addrDetails['suburb'] ?? '';
        final suburb = addrDetails['neighbourhood'] ?? addrDetails['suburb'] ?? addrDetails['residential'] ?? '';
        final city = addrDetails['city'] ?? addrDetails['town'] ?? addrDetails['village'] ?? addrDetails['county'] ?? '';
        final postcode = addrDetails['postcode'] ?? '';
        
        List<String> parts = [];
        if (road.isNotEmpty) parts.add(road);
        if (suburb.isNotEmpty && suburb != road) parts.add(suburb);
        if (city.isNotEmpty) parts.add(city);
        if (postcode.isNotEmpty) parts.add(postcode);
        
        final formattedAddress = parts.isNotEmpty 
            ? parts.join(', ') 
            : (decoded['display_name'] ?? "Pinned Location (${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)})");

        setState(() {
          _addressText = formattedAddress;
          _isResolvingAddress = false;
        });
      } else {
        _setFallbackAddress(coords);
      }
    } catch (e) {
      _setFallbackAddress(coords);
    }
  }

  void _setFallbackAddress(LatLng coords) {
    setState(() {
      _addressText = "Location Pinned (Erode)";
      _isResolvingAddress = false;
    });
  }

  void _onMapDragStart() {
    HapticFeedback.lightImpact();
    setState(() => _isDragging = true);
    _pinLiftController.forward();
    _shadowController.forward();
  }

  void _onMapDragEnd() {
    setState(() => _isDragging = false);
    _pinLiftController.reverse();
    _shadowController.reverse();
    _pinBounceController
      ..reset()
      ..forward();
    final targetCenter = _mapController.camera.center;
    _currentCenter = targetCenter;
    _reverseGeocode(targetCenter);
  }

  void _onConfirmLocation() {
    final typedText = _buildingController.text.trim();
    if (typedText.isEmpty) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Address fill pannuga! (House No. / Street / Landmark)',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ]),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetCenter = _mapController.camera.center;
    String baseGeocoded = _addressText;
    if (baseGeocoded.isEmpty || baseGeocoded == "Fetching address...") {
      baseGeocoded = "Erode, Tamil Nadu";
    }

    String finalAddress = "$typedText, $baseGeocoded";

    final newAddress = UserAddress(
      id: 'a${DateTime.now().millisecondsSinceEpoch}',
      label: _addressLabel,
      address: finalAddress,
      lat: targetCenter.latitude,
      lng: targetCenter.longitude,
    );
    auth.addAddress(newAddress);
    auth.selectAddress(newAddress.id);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Text('Delivery address saved & confirmed! 📍',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ]),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
    ));

    if (widget.isInitialSetup || !Navigator.canPop(context)) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isInitialSetup
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1A1A2E)),
                  ),
                ),
              ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
          ),
          child: Text('Set Delivery Location',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, fontSize: 15, color: _darkBg)),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ── PREMIUM MAP (ALWAYS MOUNTED FOR MAPCONTROLLER SAFETY) ───────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 16.5,
              onMapReady: () {
                if (mounted) {
                  setState(() => _isMapReady = true);
                  _safeMoveMap(_currentCenter, 18.5);
                }
              },
              onPositionChanged: (position, hasGesture) {
                if (position.center != null) {
                  _currentCenter = position.center!;
                  if (hasGesture && !_isDragging) {
                    _onMapDragStart();
                  }
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd && _isDragging) {
                  _onMapDragEnd();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _currentMapStyleUrl,
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.namba.customer',
                maxZoom: 20,
                maxNativeZoom: 19,
              ),
            ],
          ),

                // ── BLINKIT-STYLE ANIMATED CENTER PIN ───────────────────────
                IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge([_pinLiftAnim, _pinBounceAnim]),
                          builder: (context, child) {
                            final liftOffset = _pinLiftAnim.value;
                            return Transform.translate(
                              offset: Offset(0, liftOffset),
                              child: child,
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Pin head
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _primaryOrange,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primaryOrange.withOpacity(0.45),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.location_on_rounded,
                                    color: Colors.white, size: 28),
                              ),
                              // Pin tail
                              CustomPaint(
                                size: const Size(16, 10),
                                painter: _PinTailPainter(color: _primaryOrange),
                              ),
                            ],
                          ),
                        ),

                        // Shadow on the map surface
                        AnimatedBuilder(
                          animation: _shadowController,
                          builder: (context, _) => Transform.scale(
                            scale: _shadowAnim.value,
                            child: Container(
                              width: 22,
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── MAP CONTROLS ──────────────────────────────────────────
                Positioned(
                  top: 100,
                  right: 16,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _determinePosition,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                          ),
                          child: const Icon(Icons.my_location_rounded, color: _primaryOrange, size: 22),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                        ),
                        child: Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.black87, size: 22),
                              onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                            ),
                            Container(height: 1, width: 24, color: Colors.grey.shade200),
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.black87, size: 22),
                              onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      PopupMenuButton<String>(
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
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                          ),
                          child: const Icon(Icons.layers_outlined, color: _primaryOrange, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── DRAGGING INDICATOR ───────────────────────────────────────
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  top: _isDragging ? 80 : -60,
                  left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: _darkBg,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.2), blurRadius: 16)],
                      ),
                      child: Text('Move to adjust location',
                          style: GoogleFonts.outfit(
                              color: Colors.white70, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),

                // ── PREMIUM BOTTOM CARD ──────────────────────────────────────
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 30,
                          offset: const Offset(0, -8),
                        )
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Drag indicator pill
                            Center(
                              child: Container(
                                width: 40, height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Address input field header
                            Row(
                              children: [
                                Text('ENTER COMPLETE ADDRESS',
                                    style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                        color: Colors.grey.shade700)),
                                const SizedBox(width: 4),
                                Text('* Required',
                                    style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.red.shade600)),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Address input
                            TextField(
                              controller: _buildingController,
                              onChanged: (value) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: "House / Flat No, Street Name, Landmark",
                                hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                                prefixIcon: const Icon(Icons.edit_location_alt_rounded, color: _primaryOrange, size: 20),
                                suffixIcon: _buildingController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 18),
                                        onPressed: () {
                                          _buildingController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _primaryOrange, width: 2)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: _darkBg),
                            ),
                            const SizedBox(height: 16),

                            // Save-as label chips
                            Row(
                              children: [
                                Text('Save as',
                                    style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade500)),
                                const SizedBox(width: 14),
                                _labelBtn("Home", Icons.home_rounded),
                                const SizedBox(width: 8),
                                _labelBtn("Work", Icons.work_rounded),
                                const SizedBox(width: 8),
                                _labelBtn("Other", Icons.location_on_rounded),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Save & Confirm CTA
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isResolvingAddress ? null : _onConfirmLocation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryOrange,
                                  disabledBackgroundColor: Colors.grey.shade200,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shadowColor: _primaryOrange.withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.bookmark_added_rounded, size: 20),
                                    const SizedBox(width: 10),
                                    Text('SAVE ADDRESS & CONFIRM',
                                        style: GoogleFonts.outfit(
                                            fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                  ],
                                ),
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
    );
  }

  Widget _labelBtn(String label, IconData icon) {
    final isSelected = _addressLabel == label;
    return GestureDetector(
      onTap: () => setState(() => _addressLabel = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryOrange : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [BoxShadow(color: _primaryOrange.withOpacity(0.3), blurRadius: 8)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.grey.shade500),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.grey.shade600)),
          ],
        ),
      ),
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
