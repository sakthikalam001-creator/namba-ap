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
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../services/location_accuracy_service.dart';
import 'home_screen.dart';

class MapLocationPickerScreen extends StatefulWidget {
  final bool isInitialSetup;
  final LatLng? initialLocation;
  final String? initialAddress;
  const MapLocationPickerScreen({
    super.key,
    this.isInitialSetup = false,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(11.3410, 77.7172);
  LatLng? _userLiveLocation;
  double _userLiveAccuracy = 0.0;
  String _addressText = "Erode, Tamil Nadu";
  bool _isLoadingGps = false;
  bool _isResolvingAddress = false;
  String _currentMapStyleUrl = 'https://mt{s}.google.com/vt/lyrs=m,traffic&hl=en&gl=IN&x={x}&y={y}&z={z}&scale=2';
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

  void _animatedMoveMap(LatLng destLocation, double destZoom) {
    if (!_isMapReady || !mounted) return;
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final animation = CurvedAnimation(parent: animCtrl, curve: Curves.fastOutSlowIn);

    animCtrl.addListener(() {
      try {
        _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      } catch (_) {}
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        animCtrl.dispose();
      }
    });

    animCtrl.forward();
  }

  void _safeMoveMap(LatLng center, double zoom, {bool animated = true}) {
    _pendingMoveCenter = center;
    _pendingMoveZoom = zoom;
    if (_isMapReady && mounted) {
      if (animated) {
        _animatedMoveMap(center, zoom);
        _pendingMoveCenter = null;
        _pendingMoveZoom = null;
      } else {
        try {
          _mapController.move(center, zoom);
          _pendingMoveCenter = null;
          _pendingMoveZoom = null;
        } catch (e) {
          debugPrint('Safe map move error: $e');
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialLocation != null) {
      _currentCenter = widget.initialLocation!;
      _hasInitialGpsLocked = true;
      _addressText = (widget.initialAddress != null && widget.initialAddress!.isNotEmpty)
          ? widget.initialAddress!
          : 'Live Location Locked';
    } else if (LocationAccuracyService.lastKnownAccuratePosition != null &&
        LocationAccuracyService.isFresh(LocationAccuracyService.lastKnownAccuratePosition!)) {
      _currentCenter = LatLng(
        LocationAccuracyService.lastKnownAccuratePosition!.latitude,
        LocationAccuracyService.lastKnownAccuratePosition!.longitude,
      );
      _hasInitialGpsLocked = true;
      _addressText = (LocationAccuracyService.lastKnownAddress != null && LocationAccuracyService.lastKnownAddress!.isNotEmpty)
          ? LocationAccuracyService.lastKnownAddress!
          : 'Live Location Locked';
    } else {
      _hasInitialGpsLocked = false;
      _addressText = 'Pinpointing live location...';
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

    // Trigger immediate reverse geocoding on current center
    _debouncedReverseGeocode(_currentCenter);

    // Auto-fetch live GPS immediately via continuous stream
    _startLiveGpsTracking(forceCenter: widget.initialLocation == null);
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
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      try {
        final lat = _currentCenter.latitude;
        final lon = _currentCenter.longitude;
        
        // 1. Query Photon Komoot POI search (Super fast, shops, bakeries, landmarks, streets)
        final photonUrl = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&lat=$lat&lon=$lon&limit=8',
        );
        // 2. Query Nominatim search
        final nomUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=jsonv2&q=${Uri.encodeComponent(query)}&countrycodes=in&limit=8&addressdetails=1&extratags=1',
        );

        final results = await Future.wait([
          http.get(photonUrl).timeout(const Duration(milliseconds: 1500)).catchError((_) => http.Response('', 500)),
          http.get(nomUrl, headers: {'User-Agent': 'NambaApp/3.0'}).timeout(const Duration(milliseconds: 2000)).catchError((_) => http.Response('', 500)),
        ]);

        List<Map<String, dynamic>> combined = [];

        // Parse Photon POIs
        if (results[0].statusCode == 200 && results[0].body.isNotEmpty) {
          try {
            final decoded = jsonDecode(results[0].body);
            final features = decoded['features'] as List?;
            if (features != null) {
              for (var f in features) {
                final geom = f['geometry'];
                final coords = geom['coordinates'] as List;
                final props = f['properties'] as Map<String, dynamic>;
                
                final name = props['name'] ?? '';
                final street = props['street'] ?? '';
                final district = props['district'] ?? props['locality'] ?? props['suburb'] ?? '';
                final city = props['city'] ?? props['town'] ?? '';
                
                List<String> labelParts = [];
                if (name.isNotEmpty) labelParts.add(name);
                if (street.isNotEmpty && !labelParts.contains(street)) labelParts.add(street);
                if (district.isNotEmpty && !labelParts.contains(district)) labelParts.add(district);
                if (city.isNotEmpty && !labelParts.contains(city)) labelParts.add(city);

                combined.add({
                  'display_name': labelParts.join(', '),
                  'name': name.isNotEmpty ? name : street,
                  'lat': coords[1].toString(),
                  'lon': coords[0].toString(),
                });
              }
            }
          } catch (_) {}
        }

        // Parse Nominatim results
        if (results[1].statusCode == 200 && results[1].body.isNotEmpty) {
          try {
            final decoded = jsonDecode(results[1].body) as List;
            for (var item in decoded) {
              final dName = item['display_name'] ?? '';
              if (!combined.any((c) => c['display_name'] == dName)) {
                combined.add({
                  'display_name': dName,
                  'name': item['name'] ?? dName.split(',').first,
                  'lat': item['lat'].toString(),
                  'lon': item['lon'].toString(),
                });
              }
            }
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _searchResults = combined;
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

  Future<void> _startLiveGpsTracking({bool forceCenter = true}) async {
    if (!mounted) return;
    setState(() => _isLoadingGps = true);

    try {
      final isPermitted = await LocationAccuracyService.ensurePermission(requestIfNeeded: true);
      if (!isPermitted) {
        if (mounted) setState(() => _isLoadingGps = false);
        return;
      }

      // 1. Subscribe to real-time live position stream
      _positionStreamSub?.cancel();
      _positionStreamSub = LocationAccuracyService.livePositionStream.listen((pos) {
        if (!mounted) return;
        _userLiveLocation = LatLng(pos.latitude, pos.longitude);
        _userLiveAccuracy = pos.accuracy;
        if (!_isDragging && !_userHasManuallyDragged) {
          final realCenter = LatLng(pos.latitude, pos.longitude);
          _currentCenter = realCenter;
          _hasInitialGpsLocked = true;
          _safeMoveMap(realCenter, 17.2);
          _debouncedReverseGeocode(realCenter);
          setState(() {});
        }
      });

      // 2. Query high-accuracy Fused GPS with satellite convergence
      final pos = await LocationAccuracyService.getBestPosition(
        forceFresh: true,
        targetAccuracyMeters: 8,
        quickFixTimeout: const Duration(seconds: 8),
        onPosition: (freshPos) {
          if (!mounted) return;
          if (!_isDragging) {
            final realCenter = LatLng(freshPos.latitude, freshPos.longitude);
            _currentCenter = realCenter;
            _hasInitialGpsLocked = true;
            _safeMoveMap(realCenter, 17.2);
            _debouncedReverseGeocode(realCenter);
            setState(() {});
          }
        },
      );

      if (pos != null && mounted && !_isDragging) {
        final realCenter = LatLng(pos.latitude, pos.longitude);
        _currentCenter = realCenter;
        _hasInitialGpsLocked = true;
        _safeMoveMap(realCenter, 17.2);
        _debouncedReverseGeocode(realCenter);
        setState(() {});
      }
    } catch (e) {
      debugPrint('GPS tracking error: $e');
    } finally {
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
      final formatted = await LocationAccuracyService.reverseGeocode(coords.latitude, coords.longitude);
      if (mounted) {
        setState(() {
          _addressText = formatted;
          _isResolvingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        _setFallbackAddress(coords);
      }
    }
  }

  void _setFallbackAddress(LatLng coords) {
    if (mounted) {
      setState(() {
        _addressText = LocationAccuracyService.resolveKnownArea(coords.latitude, coords.longitude);
        _isResolvingAddress = false;
      });
    }
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
    if (_mapController.camera.zoom < 18.0) {
      _safeMoveMap(targetCenter, 18.5);
    }
    _debouncedReverseGeocode(targetCenter);
  }

  void _openAddressDetailsModal() {
    HapticFeedback.lightImpact();
    String? validationError;

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
                            maxLines: 2,
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
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '*(Required / கட்டாயம்)',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _buildingController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (v) {
                        if (validationError != null) {
                          setSheetState(() => validationError = null);
                        } else {
                          setSheetState(() {});
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "Door No, Flat/Building Name, Floor, Landmark *",
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: validationError != null ? Colors.redAccent : Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: validationError != null ? Colors.redAccent : Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: validationError != null ? Colors.redAccent : _primaryOrange, width: 2),
                        ),
                        filled: true,
                        fillColor: validationError != null ? const Color(0xFFFFF5F5) : const Color(0xFFF9FAFB),
                      ),
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: _darkBg),
                    ),
                    if (validationError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 13, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(
                              validationError!,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
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
                        onPressed: () {
                          final typed = _buildingController.text.trim();
                          if (typed.isEmpty) {
                            HapticFeedback.heavyImpact();
                            setSheetState(() {
                              validationError = 'Please enter House/Flat No or Landmark to continue';
                            });
                            return;
                          }
                          _onSaveAddressAndConfirm(sheetContext);
                        },
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
      duration: const Duration(seconds: 2),
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
    return PopScope(
      canPop: !widget.isInitialSetup,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select and confirm your delivery address on the map. (முகவரியை உறுதி செய்யவும்)',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
            backgroundColor: const Color(0xFF4F46E5),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
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
              initialZoom: 17.0,
              minZoom: 3.0,
              maxZoom: 20.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
                enableMultiFingerGestureRace: true,
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
                maxZoom: 20,
                maxNativeZoom: 19,
                minZoom: 3,
                keepBuffer: 6,
                panBuffer: 3,
                tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 100)),
                tileProvider: NetworkTileProvider(),
                errorTileCallback: (tile, error, stackTrace) {
                  debugPrint('Google Map Tile error: $error');
                },
              ),

            ],
          ),

          Positioned(
            top: 12,
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
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
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
                          textCapitalization: TextCapitalization.words,
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: _darkBg),
                          decoration: InputDecoration(
                            hintText: 'Search street, area, landmark...',
                            hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchResults = []);
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      if (_isSearching)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _primaryOrange),
                        ),
                    ],
                  ),
                ),

                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
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
                  final liftOffset = _pinLiftAnim.value;
                  final bounceOffset = (1.0 - _pinBounceAnim.value) * -20.0;
                  final totalLift = liftOffset + bounceOffset;

                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Target Ground Dot (Millimeter Precision at 0,0)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),

                      // Ground Pin Shadow
                      Transform.translate(
                        offset: const Offset(0, 4),
                        child: Opacity(
                          opacity: (0.35 * _shadowAnim.value).clamp(0.0, 1.0),
                          child: Container(
                            width: 18 * _shadowAnim.value,
                            height: 6 * _shadowAnim.value,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                        ),
                      ),

                      // Pin Head & Needle Tip (Aligned exactly at ground 0,0)
                      Transform.translate(
                        offset: Offset(0, -36 + totalLift),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primaryOrange,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                'SET DELIVERY POINT',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Icon(
                              Icons.location_on_rounded,
                              size: 48,
                              color: _primaryOrange,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  onTap: () async {
                    HapticFeedback.heavyImpact();
                    setState(() {
                      _isLoadingGps = true;
                      _userHasManuallyDragged = false;
                    });
                    try {
                      // 1. Direct hardware satellite GNSS query
                      Position? pos;
                      try {
                        pos = await Geolocator.getCurrentPosition(
                          locationSettings: AndroidSettings(
                            accuracy: LocationAccuracy.bestForNavigation,
                            forceLocationManager: true,
                            intervalDuration: const Duration(milliseconds: 100),
                            timeLimit: const Duration(seconds: 4),
                          ),
                        );
                      } catch (_) {
                        pos = await Geolocator.getCurrentPosition(
                          locationSettings: const LocationSettings(
                            accuracy: LocationAccuracy.bestForNavigation,
                            timeLimit: Duration(seconds: 4),
                          ),
                        );
                      }
                      if (pos != null && mounted) {
                        final realCenter = LatLng(pos.latitude, pos.longitude);
                        _currentCenter = realCenter;
                        _hasInitialGpsLocked = true;
                        _safeMoveMap(realCenter, 17.5);
                        _debouncedReverseGeocode(realCenter);
                      }
                    } catch (_) {}
                    if (mounted) setState(() => _isLoadingGps = false);
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12)],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_rounded, color: Colors.black87, size: 24),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          try {
                            final cur = _mapController.camera.zoom;
                            _mapController.move(_mapController.camera.center, (cur + 1.2).clamp(3.0, 20.0));
                          } catch (_) {}
                        },
                      ),
                      Container(height: 1, width: 24, color: Colors.grey.shade200),
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, color: Colors.black87, size: 24),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          try {
                            final cur = _mapController.camera.zoom;
                            _mapController.move(_mapController.camera.center, (cur - 1.2).clamp(3.0, 20.0));
                          } catch (_) {}
                        },
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

          // Satellite GPS Acquisition Overlay (prevents showing wrong/default location before lock)
          if (!_hasInitialGpsLocked && widget.initialLocation == null)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.gps_fixed_rounded, color: Color(0xFF4F46E5), size: 38)
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(duration: 800.ms, begin: const Offset(0.85, 0.85), end: const Offset(1.15, 1.15)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Pinpointing Your Location...',
                        style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Connecting directly to GPS satellites 🛰️',
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _addressText,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _darkBg,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_isResolvingAddress)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(strokeWidth: 1.5, color: _primaryOrange),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Refining exact address...',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
    ),
    );
  }
}
