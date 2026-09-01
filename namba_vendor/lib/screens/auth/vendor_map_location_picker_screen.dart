import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../utils/tamil_nadu_location_service.dart';

class VendorMapLocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;
  final String? initialStoreName;
  final String? initialOwnerName;
  final String? initialPhone;
  final String? initialCategory;
  final String? initialCity;
  final String? initialPincode;
  final bool fullEditMode;

  const VendorMapLocationPickerScreen({
    super.key,
    this.initialLocation,
    this.initialAddress,
    this.initialStoreName,
    this.initialOwnerName,
    this.initialPhone,
    this.initialCategory,
    this.initialCity,
    this.initialPincode,
    this.fullEditMode = false,
  });

  @override
  State<VendorMapLocationPickerScreen> createState() => _VendorMapLocationPickerScreenState();
}

class _VendorMapLocationPickerScreenState extends State<VendorMapLocationPickerScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late LatLng _currentCenter;
  String _addressText = 'Fetching accurate address...';
  String _area = 'Veerappampalayam';
  String _city = 'Erode';
  String _pincode = '638012';
  bool _isLoadingGps = false;
  bool _isResolvingAddress = false;
  bool _isDragging = false;
  bool _isMapReady = false;
  bool _isSatelliteMode = false;
  double _currentZoom = 19.5;

  // Controllers for Store Details
  late TextEditingController _storeNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _pincodeCtrl;
  late TextEditingController _cityCtrl;
  String _selectedCategory = 'Food';

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];
  Timer? _searchDebounce;
  Timer? _geocodeDebounce;

  // Pin animation
  late AnimationController _pinAnimCtrl;
  late Animation<double> _pinLiftAnim;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialLocation ?? const LatLng(11.337583, 77.682474);
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _addressText = widget.initialAddress!;
    }
    if (widget.initialCity != null && widget.initialCity!.isNotEmpty) {
      _city = widget.initialCity!;
    }
    if (widget.initialPincode != null && widget.initialPincode!.isNotEmpty) {
      _pincode = widget.initialPincode!;
    }

    _storeNameCtrl = TextEditingController(text: widget.initialStoreName ?? 'OM Muruga Mess');
    _ownerNameCtrl = TextEditingController(text: widget.initialOwnerName ?? 'Muruga Raj');
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '9876543212');
    _pincodeCtrl = TextEditingController(text: _pincode);
    _cityCtrl = TextEditingController(text: _city);
    _selectedCategory = widget.initialCategory ?? 'Food';

    _pinAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _pinLiftAnim = Tween<double>(begin: 0.0, end: -16.0).animate(
      CurvedAnimation(parent: _pinAnimCtrl, curve: Curves.easeOutCubic),
    );

    // Initial GPS resolution if no initial location passed
    if (widget.initialLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCurrentGpsLocation(isInitial: true);
      });
    } else {
      _reverseGeocode(_currentCenter.latitude, _currentCenter.longitude);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _geocodeDebounce?.cancel();
    _searchCtrl.dispose();
    _storeNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _pincodeCtrl.dispose();
    _cityCtrl.dispose();
    _pinAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _getCurrentGpsLocation({bool isInitial = false}) async {
    setState(() => _isLoadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!isInitial && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS / Location services on your phone.')),
          );
        }
        setState(() => _isLoadingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingGps = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingGps = false);
        return;
      }

      // ⚡ 1. INSTANT LOCATION: Use last known position immediately
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          final quickCenter = LatLng(lastKnown.latitude, lastKnown.longitude);
          _currentCenter = quickCenter;
          if (_isMapReady) {
            _mapController.move(quickCenter, 19.5);
          }
          _reverseGeocode(lastKnown.latitude, lastKnown.longitude);
        }
      } catch (_) {}

      // ⚡ 2. ACCURATE LOCATION: Live GPS refinement
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );

      final newCenter = LatLng(position.latitude, position.longitude);
      _currentCenter = newCenter;

      if (_isMapReady) {
        _mapController.move(newCenter, 19.5);
      }

      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting GPS location: $e');
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() => _isResolvingAddress = true);
    try {
      final result = await TamilNaduLocationService.reverseGeocode(lat: lat, lng: lng);

      if (mounted) {
        setState(() {
          _addressText = result.formattedAddress;
          _area = result.area.isNotEmpty ? result.area : _area;
          _city = result.city.isNotEmpty ? result.city : _city;
          _pincode = result.pincode.isNotEmpty ? result.pincode : _pincode;
          _pincodeCtrl.text = _pincode;
          _cityCtrl.text = _city;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addressText = 'Pin Location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
        });
      }
    } finally {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      if (!_isDragging) {
        setState(() => _isDragging = true);
        _pinAnimCtrl.forward();
      }
      _currentCenter = camera.center;
      _currentZoom = camera.zoom;

      _geocodeDebounce?.cancel();
      _geocodeDebounce = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() => _isDragging = false);
          _pinAnimCtrl.reverse();
          _reverseGeocode(_currentCenter.latitude, _currentCenter.longitude);
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&countrycodes=in&limit=5&addressdetails=1',
        );
        final response = await http.get(
          url,
          headers: {'User-Agent': 'NambaVendorApp/1.0 (support@nambadelivery.in)'},
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 && mounted) {
          final List data = json.decode(response.body);
          setState(() {
            _searchResults = data;
          });
        }
      } catch (e) {
        debugPrint('Search error: $e');
      }
    });
  }

  void _selectSearchResult(dynamic item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '') ?? _currentCenter.latitude;
    final lon = double.tryParse(item['lon']?.toString() ?? '') ?? _currentCenter.longitude;
    final target = LatLng(lat, lon);

    final address = item['address'] as Map<String, dynamic>? ?? {};
    final city = address['city'] ?? address['town'] ?? address['village'] ?? 'Erode';
    final postcode = address['postcode'] ?? '';

    setState(() {
      _currentCenter = target;
      _addressText = item['display_name'] ?? '';
      _city = city.toString();
      if (postcode.isNotEmpty && postcode.toString().length == 6) {
        _pincode = postcode.toString();
      }
      _searchResults = [];
      _searchCtrl.text = _addressText;
    });

    FocusScope.of(context).unfocus();
    if (_isMapReady) {
      _mapController.move(target, 19.5);
    }
  }

  void _zoomIn() {
    if (_isMapReady) {
      _currentZoom = (_currentZoom + 1).clamp(5.0, 21.0);
      _mapController.move(_currentCenter, _currentZoom);
    }
  }

  void _zoomOut() {
    if (_isMapReady) {
      _currentZoom = (_currentZoom - 1).clamp(5.0, 21.0);
      _mapController.move(_currentCenter, _currentZoom);
    }
  }

  // Quick edit dialog for Pincode & City
  void _showEditPincodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.pin_drop_rounded, color: AppTheme.primaryOrange, size: 22),
            const SizedBox(width: 8),
            Text('Edit City & PIN Code', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _cityCtrl,
              decoration: InputDecoration(
                labelText: 'City / District',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pincodeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: '6-Digit PIN Code',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _city = _cityCtrl.text.trim();
                _pincode = _pincodeCtrl.text.trim();
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmLocation() {
    Navigator.pop(context, {
      'lat': _currentCenter.latitude,
      'lng': _currentCenter.longitude,
      'latitude': _currentCenter.latitude,
      'longitude': _currentCenter.longitude,
      'address': _addressText,
      'formattedAddress': _addressText,
      'area': _area,
      'locality': _area,
      'city': _city,
      'district': _city,
      'pincode': _pincode,
      'storeName': _storeNameCtrl.text.trim(),
      'ownerName': _ownerNameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'category': _selectedCategory,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Color(0xFF4F46E5), size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edit Store & Location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkText,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Update store details and accurate map pin coordinates.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                color: AppTheme.mediumText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Satellite mode toggle button
          IconButton(
            tooltip: _isSatelliteMode ? 'Switch to Standard Map' : 'Switch to Satellite View',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isSatelliteMode ? AppTheme.primaryOrange : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _isSatelliteMode ? Icons.layers_rounded : Icons.satellite_alt_rounded,
                size: 18,
                color: _isSatelliteMode ? Colors.white : AppTheme.darkText,
              ),
            ),
            onPressed: () {
              setState(() => _isSatelliteMode = !_isSatelliteMode);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. High-Resolution Interactive Map (Google Maps / CartoDB HD)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 19.5,
              minZoom: 5.0,
              maxZoom: 21.0,
              onMapReady: () {
                _isMapReady = true;
              },
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatelliteMode
                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                    : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.namba.vendor',
                maxZoom: 21,
                maxNativeZoom: 20,
              ),
            ],
          ),

          // 2. Search Bar on Top with Search Button
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const Icon(Iconsax.search_normal_1, color: AppTheme.primaryOrange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search place or address (e.g. T Nagar, Chennai)...',
                            hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        child: ElevatedButton(
                          onPressed: () {
                            if (_searchCtrl.text.isNotEmpty) {
                              _onSearchChanged(_searchCtrl.text);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Search',
                            style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final item = _searchResults[idx];
                        return ListTile(
                          leading: const Icon(Iconsax.location, color: AppTheme.primaryOrange, size: 20),
                          title: Text(
                            item['display_name'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          onTap: () => _selectSearchResult(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. Center Pin (Admin-Style Floating STORE PIN)
          Center(
            child: AnimatedBuilder(
              animation: _pinLiftAnim,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _pinLiftAnim.value - 28), // Pin tip aligns directly with map center
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade400, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_pin, color: Color(0xFFFACC15), size: 13),
                            const SizedBox(width: 4),
                            Text(
                              'STORE PIN',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFFACC15),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Icon(
                        Icons.location_on_rounded,
                        size: 48,
                        color: Color(0xFFDC2626), // High-visibility red pin
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Coordinate overlay badge
          Positioned(
            left: 16,
            bottom: 230,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.my_location_rounded, color: Color(0xFFFACC15), size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'Lat: ${_currentCenter.latitude.toStringAsFixed(6)} • Lng: ${_currentCenter.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Map Action Controls (Zoom In/Out + Satellite Toggle + GPS Locate)
          Positioned(
            right: 16,
            bottom: 230,
            child: Column(
              children: [
                // Zoom In
                FloatingActionButton.small(
                  heroTag: 'map_zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.darkText,
                  elevation: 3,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add_rounded, size: 20),
                ),
                const SizedBox(height: 8),
                // Zoom Out
                FloatingActionButton.small(
                  heroTag: 'map_zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.darkText,
                  elevation: 3,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove_rounded, size: 20),
                ),
                const SizedBox(height: 12),
                // GPS High-Accuracy Locate
                FloatingActionButton(
                  heroTag: 'gps_locate_shop',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4F46E5),
                  elevation: 4,
                  onPressed: _isLoadingGps ? null : () => _getCurrentGpsLocation(),
                  child: _isLoadingGps
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF4F46E5)),
                        )
                      : const Icon(Icons.my_location_rounded, size: 24),
                ),
              ],
            ),
          ),

          // 5. Admin-Style Bottom Panel with Address, Coordinates & Save Details
          Positioned(
            left: 14,
            right: 14,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header: SHOP LOCATION & LOGISTICS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on_rounded, color: Color(0xFF4F46E5), size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SHOP LOCATION & LOGISTICS',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4F46E5),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      if (_isResolvingAddress)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Pinned Address
                  Text(
                    _addressText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // City & Pincode Chips + Coordinates Row
                  Row(
                    children: [
                      InkWell(
                        onTap: _showEditPincodeDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_city_rounded, size: 13, color: Colors.blueGrey),
                              const SizedBox(width: 4),
                              Text(
                                _city,
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.darkText),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _showEditPincodeDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pin_drop_outlined, size: 13, color: Colors.blueGrey),
                              const SizedBox(width: 4),
                              Text(
                                _pincode.isNotEmpty ? _pincode : 'PIN Code',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.darkText),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit, size: 11, color: AppTheme.primaryOrange),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Live GPS Sync Icon
                      InkWell(
                        onTap: () => _getCurrentGpsLocation(),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF4F46E5)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Bottom Action Buttons (Cancel / Save Details)
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkText),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isResolvingAddress ? null : _confirmLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5), // Royal Indigo/Purple matching Admin Image
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Save Details',
                                style: GoogleFonts.outfit(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
          ),
        ],
      ),
    );
  }
}
