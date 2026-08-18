import 'dart:async';
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
import '../services/location_accuracy_service.dart';
import 'home_screen.dart';

class MapLocationPickerScreen extends StatefulWidget {
  final bool isInitialSetup;
  final LatLng? initialLocation;
  const MapLocationPickerScreen({super.key, this.isInitialSetup = false, this.initialLocation});

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(11.3410, 77.7172);
  LatLng? _userLiveLocation;
  String _addressText = "Fetching address...";
  bool _isLoadingGps = false;
  bool _isResolvingAddress = false;
  String _currentMapStyleUrl = 'https://mt{s}.google.com/vt/lyrs=m&hl=en&x={x}&y={y}&z={z}';
  bool _isDragging = false;
  String _addressLabel = "Home";
  final TextEditingController _buildingController = TextEditingController();

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  // Animation controllers
  late AnimationController _pinBounceController;
  late AnimationController _pinLiftController;
  late AnimationController _shadowController;
  late Animation<double> _pinBounceAnim;
  late Animation<double> _pinLiftAnim;
  late Animation<double> _shadowAnim;

  // Color palette
  static const Color _primaryOrange = Color(0xFF4F46E5);
  static const Color _darkBg = Color(0xFF1A1A2E);
  static const Color _cardBg = Color(0xFFFAFAFA);

  bool _isMapReady = false;
  LatLng? _pendingMoveCenter;
  double? _pendingMoveZoom;
  StreamSubscription<Position>? _positionStreamSub;
  bool _userHasManuallyDragged = false;
  bool _hasInitialGpsLocked = false;

  void _safeMoveMap(LatLng center, double zoom) {
    _pendingMoveCenter = center;
    _pendingMoveZoom = zoom;
    if (_isMapReady && mounted) {
      try {
        _mapController.move(center, zoom);
        _pendingMoveCenter = null;
        _pendingMoveZoom = null;
      } catch (e) {
        debugPrint('Safe map move error: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialLocation != null) {
      _currentCenter = widget.initialLocation!;
      _hasInitialGpsLocked = true;
    } else if (LocationAccuracyService.lastKnownAccuratePosition != null) {
      _currentCenter = LatLng(
        LocationAccuracyService.lastKnownAccuratePosition!.latitude,
        LocationAccuracyService.lastKnownAccuratePosition!.longitude,
      );
      _hasInitialGpsLocked = true;
    } else {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.selectedAddress.lat != null && auth.selectedAddress.lat != 0 && auth.selectedAddress.lat != 11.3410) {
        _currentCenter = LatLng(auth.selectedAddress.lat!, auth.selectedAddress.lng!);
        _hasInitialGpsLocked = true;
      }
    }

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

    // Auto-fetch live GPS immediately via continuous stream
    _startLiveGpsTracking();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _searchDebounce?.cancel();
    _geocodeDebounce?.cancel();
    _searchCtrl.dispose();
    _pinBounceController.dispose();
    _pinLiftController.dispose();
    _shadowController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      try {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&countrycodes=in&limit=5');
        final res = await http.get(url, headers: {'User-Agent': 'NambaCustomer/1.0'}).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200 && mounted) {
          final decoded = jsonDecode(res.body) as List;
          setState(() {
            _searchResults = decoded;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _selectSearchResult(dynamic item) {
    try {
      final lat = double.parse(item['lat']);
      final lon = double.parse(item['lon']);
      final target = LatLng(lat, lon);
      setState(() {
        _currentCenter = target;
        _searchResults = [];
        _searchCtrl.clear();
      });
      _safeMoveMap(target, 18.8);
      _reverseGeocode(target);
      FocusScope.of(context).unfocus();
    } catch (_) {}
  }

  Future<void> _startLiveGpsTracking() async {
    if (!mounted) return;
    setState(() => _isLoadingGps = true);

    try {
      final isPermitted = await LocationAccuracyService.ensurePermission(requestIfNeeded: true);
      if (!isPermitted) {
        if (mounted) {
          setState(() => _isLoadingGps = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enable GPS Location in your phone settings.'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }

      // 1. Get best high-accuracy position with fast callback
      LocationAccuracyService.getBestPosition(
        targetAccuracyMeters: 10,
        maxUsableAccuracyMeters: 35,
        quickFixTimeout: const Duration(seconds: 3),
        refineTimeout: const Duration(seconds: 6),
        onPosition: (pos) {
          if (!mounted) return;
          final realCenter = LatLng(pos.latitude, pos.longitude);
          setState(() {
            _userLiveLocation = realCenter;
            if (!_userHasManuallyDragged) {
              _currentCenter = realCenter;
              _hasInitialGpsLocked = true;
              _isLoadingGps = false;
            }
          });
          if (!_userHasManuallyDragged) {
            _safeMoveMap(realCenter, 19.2);
            _debouncedReverseGeocode(realCenter);
          }
        },
      );

      // 2. Start continuous live GPS stream
      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: LocationAccuracyService.highAccuracySettings(),
      ).listen((Position position) {
        if (!mounted) return;
        if (position.accuracy > 35.0) return; // Strict filter: discard cell tower jumps
        final realCenter = LatLng(position.latitude, position.longitude);
        setState(() {
          _userLiveLocation = realCenter;
          if (!_userHasManuallyDragged) {
            _currentCenter = realCenter;
            _hasInitialGpsLocked = true;
            _isLoadingGps = false;
          }
        });

        if (!_userHasManuallyDragged) {
          _safeMoveMap(realCenter, 19.2);
          _debouncedReverseGeocode(realCenter);
        }
      }, onError: (e) {
        debugPrint('GPS stream error: $e');
      });
    } catch (e) {
      debugPrint('GPS tracking error: $e');
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  Timer? _geocodeDebounce;

  void _debouncedReverseGeocode(LatLng coords) {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 100), () {
      _reverseGeocode(coords);
    });
  }

  Future<void> _reverseGeocode(LatLng coords) async {
    if (!mounted) return;
    setState(() => _isResolvingAddress = true);

    try {
      final nomUri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${coords.latitude}&lon=${coords.longitude}&zoom=18&addressdetails=1');
      final bdcUri = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${coords.latitude}&longitude=${coords.longitude}&localityLanguage=en');

      final results = await Future.wait([
        http.get(nomUri, headers: {'User-Agent': 'NambaCustomerApp/1.0'}).timeout(const Duration(milliseconds: 1500)).catchError((_) => http.Response('', 500)),
        http.get(bdcUri).timeout(const Duration(milliseconds: 1500)).catchError((_) => http.Response('', 500)),
      ]);

      if (!mounted) return;

      final resNom = results[0];
      if (resNom.statusCode == 200 && resNom.body.isNotEmpty) {
        try {
          final decoded = json.decode(resNom.body);
          final addr = decoded['address'] ?? {};
          final road = addr['road'] ?? addr['street'] ?? addr['pedestrian'] ?? addr['highway'] ?? '';
          final suburb = addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'] ?? addr['commercial'] ?? addr['village'] ?? addr['town'] ?? '';
          final city = addr['city'] ?? addr['town'] ?? addr['county'] ?? 'Erode';

          List<String> parts = [];
          if (road.isNotEmpty) parts.add(road);
          if (suburb.isNotEmpty && suburb != road) parts.add(suburb);
          if (city.isNotEmpty && !parts.contains(city)) parts.add(city);

          final formatted = parts.isNotEmpty ? parts.join(', ') : (decoded['display_name'] ?? '');
          if (formatted.isNotEmpty && formatted.trim() != 'Erode') {
            setState(() {
              _addressText = formatted;
              _isResolvingAddress = false;
            });
            return;
          }
        } catch (_) {}
      }

      final resBdc = results[1];
      if (resBdc.statusCode == 200 && resBdc.body.isNotEmpty) {
        try {
          final decoded = json.decode(resBdc.body);
          String area = '';
          if (decoded['localityInfo'] != null && decoded['localityInfo']['informative'] != null) {
            final List informative = decoded['localityInfo']['informative'];
            for (var item in informative) {
              final name = item['name'] ?? '';
              if (name.isNotEmpty && !name.contains('Erode') && !name.contains('Tamil Nadu') && !name.contains('India')) {
                area = name;
                break;
              }
            }
          }
          final locality = (decoded['locality'] != null && (decoded['locality'] as String).isNotEmpty)
              ? decoded['locality']
              : area;
          final city = decoded['city'] ?? decoded['principalSubdivision'] ?? 'Erode';

          List<String> parts = [];
          if (locality.isNotEmpty) parts.add(locality);
          if (city.isNotEmpty && city != locality) parts.add(city);

          final formatted = parts.join(', ');
          if (formatted.isNotEmpty && formatted.trim() != 'Erode') {
            setState(() {
              _addressText = formatted;
              _isResolvingAddress = false;
            });
            return;
          }
        } catch (_) {}
      }

      final resPhoton = await http
          .get(Uri.parse('https://photon.komoot.io/reverse?lat=${coords.latitude}&lon=${coords.longitude}'))
          .timeout(const Duration(milliseconds: 1500))
          .catchError((_) => http.Response('', 500));
      if (resPhoton.statusCode == 200 && resPhoton.body.isNotEmpty) {
        try {
          final decoded = json.decode(resPhoton.body);
          final features = decoded['features'] as List?;
          if (features != null && features.isNotEmpty) {
            final props = features[0]['properties'] ?? {};
            final name = props['name'] ?? props['street'] ?? props['district'] ?? props['city'] ?? '';
            final city = props['city'] ?? props['state'] ?? 'Erode';
            final formatted = name.isNotEmpty && city.isNotEmpty ? '$name, $city' : name.isNotEmpty ? name : city;
            if (formatted.isNotEmpty && formatted.trim() != 'Erode') {
              setState(() {
                _addressText = formatted;
                _isResolvingAddress = false;
              });
              return;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    _setFallbackAddress(coords);
  }

  void _setFallbackAddress(LatLng coords) {
    if (mounted) {
      setState(() {
        _addressText = "Selected Location, Erode";
        _isResolvingAddress = false;
      });
    }
  }

  void _onMapDragStart() {
    HapticFeedback.lightImpact();
    if (_hasInitialGpsLocked) {
      _userHasManuallyDragged = true;
    }
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
    _debouncedReverseGeocode(targetCenter);
  }

  void _openAddressDetailsModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final bottomPadding = MediaQuery.of(context).padding.bottom;
            return SafeArea(
              top: false,
              bottom: true,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 14, 20, (bottomPadding > 0 ? bottomPadding + 10 : 22) + bottomInset),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'ENTER COMPLETE ADDRESS',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: _darkBg,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: _primaryOrange, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _addressText,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'HOUSE / FLAT / BLOCK NO',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(Optional)',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _buildingController,
                      autofocus: false,
                      onChanged: (v) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: "House / Flat No, Landmark (Optional)",
                        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.edit_location_alt_rounded, color: _primaryOrange, size: 20),
                        suffixIcon: _buildingController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 18),
                                onPressed: () {
                                  _buildingController.clear();
                                  setSheetState(() {});
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _primaryOrange, width: 2)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                      ),
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: _darkBg),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Save as',
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade500)),
                        const SizedBox(width: 14),
                        _labelSheetBtn("Home", Icons.home_rounded, setSheetState),
                        const SizedBox(width: 8),
                        _labelSheetBtn("Work", Icons.work_rounded, setSheetState),
                        const SizedBox(width: 8),
                        _labelSheetBtn("Other", Icons.location_on_rounded, setSheetState),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => _onSaveAddressAndConfirm(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: _primaryOrange.withOpacity(0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bookmark_added_rounded, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'SAVE ADDRESS & CONFIRM',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
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
        },
      );
    },
  );
}

  void _onSaveAddressAndConfirm(BuildContext sheetContext) {
    final typedText = _buildingController.text.trim();
    Navigator.pop(sheetContext);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetCenter = _mapController.camera.center;
    String baseGeocoded = _addressText;
    if (baseGeocoded.isEmpty || baseGeocoded == "Fetching address...") {
      baseGeocoded = "Current Location";
    }

    String finalAddress = typedText.isNotEmpty ? "$typedText, $baseGeocoded" : baseGeocoded;

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

  Widget _labelSheetBtn(String label, IconData icon, StateSetter setSheetState) {
    final isSelected = _addressLabel == label;
    return GestureDetector(
      onTap: () {
        setState(() => _addressLabel = label);
        setSheetState(() {});
      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.isInitialSetup
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _darkBg, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text('Set Delivery Location',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, fontSize: 15, color: _darkBg)),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 19.2,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
              ),
              onMapReady: () {
                if (mounted) {
                  setState(() => _isMapReady = true);
                  if (_pendingMoveCenter != null) {
                    try {
                      _mapController.move(_pendingMoveCenter!, _pendingMoveZoom ?? 19.2);
                    } catch (_) {}
                    _pendingMoveCenter = null;
                    _pendingMoveZoom = null;
                  }
                  _startLiveGpsTracking();
                }
              },
              onPositionChanged: (position, hasGesture) {
                _currentCenter = position.center;
                if (hasGesture && !_isDragging) {
                  _onMapDragStart();
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
                maxZoom: 22,
                maxNativeZoom: 18,
                minZoom: 3,
                keepBuffer: 12,
                panBuffer: 6,
                tileProvider: NetworkTileProvider(),
                errorTileCallback: (tile, error, stackTrace) {},
              ),
            ],
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 76,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: _primaryOrange, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: _darkBg),
                          decoration: InputDecoration(
                            hintText: 'Search street, area, landmark...',
                            hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _primaryOrange)),
                                  )
                                : _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() => _searchResults = []);
                                        },
                                      )
                                    : null,
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
                        BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final item = _searchResults[idx];
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined, color: _primaryOrange, size: 20),
                          title: Text(
                            item['display_name'] ?? '',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          Center(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pinBounceAnim, _pinLiftAnim, _shadowAnim]),
                builder: (context, child) {
                  final bounceOffset = (1.0 - _pinBounceAnim.value) * -30.0;
                  final liftOffset = _pinLiftAnim.value;
                  final totalOffset = bounceOffset + liftOffset;
                  final shadowScale = _shadowAnim.value;

                  return SizedBox(
                    width: 120,
                    height: 130,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Ground Pin Shadow
                        Positioned(
                          bottom: 26,
                          child: Opacity(
                            opacity: (0.35 * shadowScale).clamp(0.0, 1.0),
                            child: Container(
                              width: 24 * shadowScale,
                              height: 8 * shadowScale,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                          ),
                        ),

                        // Pin Head & Needle Tip
                        Positioned(
                          bottom: 26 - totalOffset,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _primaryOrange,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
                                  ],
                                ),
                                child: Text(
                                  'SET DELIVERY POINT',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Icon(
                                Icons.location_on_rounded,
                                size: 48,
                                color: _primaryOrange,
                                shadows: [
                                  Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _hasInitialGpsLocked = false;
                    _userHasManuallyDragged = false;
                    if (_userLiveLocation != null) {
                      _currentCenter = _userLiveLocation!;
                      _safeMoveMap(_userLiveLocation!, 19.2);
                      _debouncedReverseGeocode(_userLiveLocation!);
                    }
                    _startLiveGpsTracking();
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                    ),
                    child: _isLoadingGps
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: _primaryOrange)))
                        : const Icon(Icons.my_location_rounded, color: _primaryOrange, size: 22),
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
                    const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}', child: Text('Google Maps (Roadmap & Traffic)')),
                    const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', child: Text('Google Hybrid Satellite')),
                    const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=p&x={x}&y={y}&z={z}', child: Text('Google Terrain View')),
                    const PopupMenuItem(value: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', child: Text('OpenStreetMap')),
                  ],
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                    ),
                    child: const Icon(Icons.layers_rounded, color: _primaryOrange, size: 22),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 25,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'ORDER WILL BE DELIVERED HERE',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryOrange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on_rounded, color: _primaryOrange, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _addressText,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _darkBg,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _openAddressDetailsModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: _primaryOrange.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'CONFIRM LOCATION',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
