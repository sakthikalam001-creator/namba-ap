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
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../models/models.dart';
import '../services/location_accuracy_service.dart';
import '../services/cached_tile_provider.dart';
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
  LatLng _currentCenter = (LocationAccuracyService.lastKnownAccuratePosition != null &&
          LocationAccuracyService.lastKnownAccuratePosition!.latitude != 0.0)
      ? LatLng(
          LocationAccuracyService.lastKnownAccuratePosition!.latitude,
          LocationAccuracyService.lastKnownAccuratePosition!.longitude,
        )
      : const LatLng(11.3410, 77.7172);
  LatLng? _userLiveLocation;
  double _userLiveAccuracy = 0.0;
  String _addressText = "Erode, Tamil Nadu";
  bool _isLoadingGps = false;
  bool _isResolvingAddress = false;
  String _currentMapStyleUrl = 'https://mt{s}.google.com/vt/lyrs=m&hl=en&gl=IN&x={x}&y={y}&z={z}';
  String get _effectiveTileUrl => _currentMapStyleUrl;
  AnimationController? _moveAnimCtrl;
  bool _isDragging = false;
  String _addressLabel = "Home";
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _doorNoCtrl = TextEditingController();
  final TextEditingController _streetCtrl = TextEditingController();
  final TextEditingController _landmarkCtrl = TextEditingController();
  final TextEditingController _areaCtrl = TextEditingController();
  final TextEditingController _pincodeCtrl = TextEditingController();
  ParsedAddressDetails? _parsedAddress;

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
    _moveAnimCtrl?.stop();
    _moveAnimCtrl?.dispose();
    _moveAnimCtrl = null;

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
      duration: const Duration(milliseconds: 450),
    );
    _moveAnimCtrl = animCtrl;
    final animation = CurvedAnimation(parent: animCtrl, curve: Curves.easeOutCubic);

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
        if (_moveAnimCtrl == animCtrl) {
          _moveAnimCtrl = null;
        }
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
        LocationAccuracyService.lastKnownAccuratePosition!.latitude != 0.0) {
      _currentCenter = LatLng(
        LocationAccuracyService.lastKnownAccuratePosition!.latitude,
        LocationAccuracyService.lastKnownAccuratePosition!.longitude,
      );
      _hasInitialGpsLocked = true;
      _addressText = (LocationAccuracyService.lastKnownAddress != null && LocationAccuracyService.lastKnownAddress!.isNotEmpty)
          ? LocationAccuracyService.lastKnownAddress!
          : 'Locating address...';
    } else {
      _hasInitialGpsLocked = false;
      _addressText = 'Finding your accurate location...';
      // Query last known hardware position immediately
      Geolocator.getLastKnownPosition().then((pos) {
        if (pos != null && pos.latitude != 0.0 && mounted && !_userHasManuallyDragged) {
          setState(() {
            _currentCenter = LatLng(pos.latitude, pos.longitude);
            _hasInitialGpsLocked = true;
          });
          _safeMoveMap(_currentCenter, 18.5);
          _debouncedReverseGeocode(_currentCenter);
        }
      });
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
    _buildingController.dispose();
    _doorNoCtrl.dispose();
    _streetCtrl.dispose();
    _landmarkCtrl.dispose();
    _areaCtrl.dispose();
    _pincodeCtrl.dispose();
    _pinBounceController.dispose();
    _pinLiftController.dispose();
    _shadowController.dispose();
    _moveAnimCtrl?.dispose();
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
      _safeMoveMap(target, 18.5);
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

      // 1. Quick check on native device last known position (< 10ms)
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted && !_userHasManuallyDragged) {
        final lastCenter = LatLng(lastPos.latitude, lastPos.longitude);
        _userLiveLocation = lastCenter;
        _userLiveAccuracy = lastPos.accuracy;
        _currentCenter = lastCenter;
        _hasInitialGpsLocked = true;
        _safeMoveMap(lastCenter, 18.5);
        _debouncedReverseGeocode(lastCenter);
        setState(() {});
      }

      // 2. Subscribe to real-time live position stream
      _positionStreamSub?.cancel();
      _positionStreamSub = LocationAccuracyService.livePositionStream.listen((pos) {
        if (!mounted) return;
        _userLiveLocation = LatLng(pos.latitude, pos.longitude);
        _userLiveAccuracy = pos.accuracy;
        if (!_isDragging && !_userHasManuallyDragged) {
          final realCenter = LatLng(pos.latitude, pos.longitude);
          _currentCenter = realCenter;
          _hasInitialGpsLocked = true;
          _safeMoveMap(realCenter, 18.5);
          _debouncedReverseGeocode(realCenter);
          setState(() {});
        }
      });

      // 3. Fast high-accuracy direct GPS query
      Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          forceLocationManager: false,
          intervalDuration: const Duration(milliseconds: 100),
          timeLimit: const Duration(seconds: 4),
        ),
      ).then((freshPos) {
        if (!mounted || _userHasManuallyDragged || _isDragging) return;
        final realCenter = LatLng(freshPos.latitude, freshPos.longitude);
        _userLiveLocation = realCenter;
        _userLiveAccuracy = freshPos.accuracy;
        _currentCenter = realCenter;
        _hasInitialGpsLocked = true;
        _safeMoveMap(realCenter, 18.5);
        _debouncedReverseGeocode(realCenter);
        setState(() {
          _isLoadingGps = false;
        });
      }).catchError((_) {});
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
      final structured = await LocationAccuracyService.reverseGeocodeStructured(coords.latitude, coords.longitude);
      if (mounted) {
        setState(() {
          _parsedAddress = structured;
          _addressText = structured.fullAddress;
          _isResolvingAddress = false;
          
          // Auto-fill area & locality
          if (structured.area.isNotEmpty) {
            _areaCtrl.text = structured.area;
          }
          
          // Auto-fill pincode & city
          if (structured.pincode.isNotEmpty) {
            _pincodeCtrl.text = '${structured.city} - ${structured.pincode}';
          } else {
            _pincodeCtrl.text = structured.city;
          }

// User types doorNo, street, and landmark manually
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
      final known = LocationAccuracyService.resolveKnownArea(coords.latitude, coords.longitude);
      setState(() {
        _addressText = known;
        _isResolvingAddress = false;
        if (_areaCtrl.text.isEmpty) {
          _areaCtrl.text = known.split(',').first.trim();
        }
        if (_pincodeCtrl.text.isEmpty) {
          _pincodeCtrl.text = 'Erode - 638012';
        }
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
    _debouncedReverseGeocode(targetCenter);
  }

  void _openAddressDetailsModal() {
    HapticFeedback.lightImpact();
    String? validationError;

// User types doorNo, street, and landmark manually

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Provider.of<ThemeProvider>(context);
        final lang = Provider.of<CustomerLanguageProvider>(context);
        final isDark = theme.isDarkMode;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final bottomPadding = MediaQuery.of(context).padding.bottom;
            return SafeArea(
              top: false,
              bottom: true,
              child: Container(
                padding: EdgeInsets.fromLTRB(22, 12, 22, (bottomPadding > 0 ? bottomPadding + 8 : 20) + bottomInset),
                decoration: BoxDecoration(
                  color: theme.cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Drag Handle Pill
                      Center(
                        child: Container(
                          width: 42,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Header Row with Title and GPS Badge
                      Row(
                        children: [
                          Text(
                            lang.translate('enter_complete_address').toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: theme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'GPS Pin Locked',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Pinpointed Location Summary Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.inputBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.borderCol),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: _primaryOrange, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _addressText,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // FIELD 1: DOOR / FLAT / HOUSE NO (Required)
                      _buildFieldLabel(
                        label: lang.translate('door_no').toUpperCase(),
                        requiredText: '*(Required)',
                        theme: theme,
                      ),
                      const SizedBox(height: 7),
                      _buildAddressTextField(
                        controller: _doorNoCtrl,
                        hint: 'Enter House / Flat / Door No',
                        icon: Icons.home_outlined,
                        theme: theme,
                        onChanged: (v) {
                          if (validationError != null) setSheetState(() => validationError = null);
                        },
                      ),
                      const SizedBox(height: 14),

                      // FIELD 2: STREET / ROAD NAME (Required)
                      _buildFieldLabel(
                        label: lang.translate('street').toUpperCase(),
                        requiredText: '*(Required)',
                        theme: theme,
                      ),
                      const SizedBox(height: 7),
                      _buildAddressTextField(
                        controller: _streetCtrl,
                        hint: 'Enter Apartment / Street / Road Name',
                        icon: Icons.alt_route_rounded,
                        theme: theme,
                        onChanged: (v) {
                          if (validationError != null) setSheetState(() => validationError = null);
                        },
                      ),
                      const SizedBox(height: 14),

                      // FIELD 3: LANDMARK (Optional)
                      _buildFieldLabel(
                        label: lang.translate('landmark').toUpperCase(),
                        requiredText: '(Optional)',
                        isRequired: false,
                        theme: theme,
                      ),
                      const SizedBox(height: 7),
                      _buildAddressTextField(
                        controller: _landmarkCtrl,
                        hint: 'Enter nearby landmark (Optional)',
                        icon: Icons.flag_outlined,
                        theme: theme,
                        onChanged: (v) {
                          if (validationError != null) setSheetState(() => validationError = null);
                        },
                      ),

                      if (validationError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, left: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 15, color: Colors.redAccent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  validationError!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Save as Selector
                      Row(
                        children: [
                          Text('Save as',
                              style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textSecondary)),
                          const SizedBox(width: 14),
                          _labelSheetBtn("Home", Icons.home_rounded, setSheetState, theme),
                          const SizedBox(width: 8),
                          _labelSheetBtn("Work", Icons.work_rounded, setSheetState, theme),
                          const SizedBox(width: 8),
                          _labelSheetBtn("Other", Icons.location_on_rounded, setSheetState, theme),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Save & Confirm CTA Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            final door = _doorNoCtrl.text.trim();
                            final street = _streetCtrl.text.trim();
                            if (door.isEmpty || street.isEmpty) {
                              HapticFeedback.heavyImpact();
                              setSheetState(() {
                                validationError = 'Please enter Door/House No and Street name';
                              });
                              return;
                            }
                            _onSaveAddressAndConfirm(sheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryOrange,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: _primaryOrange.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bookmark_added_rounded, size: 21),
                              const SizedBox(width: 10),
                              Text(
                                lang.translate('save_address').toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
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
    Navigator.pop(sheetContext);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetCenter = _mapController.camera.center;

    final door = _doorNoCtrl.text.trim();
    final street = _streetCtrl.text.trim();
    final landmark = _landmarkCtrl.text.trim();

    final List<String> parts = [];
    if (door.isNotEmpty) parts.add(door);
    if (street.isNotEmpty) parts.add(street);
    if (landmark.isNotEmpty) parts.add('Near $landmark');
    if (_addressText.isNotEmpty && _addressText != 'Live Location Locked' && _addressText != 'Current Location') {
      parts.add(_addressText);
    }

    final finalAddress = parts.isNotEmpty ? parts.join(', ') : _addressText;

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

  Widget _buildFieldLabel({
    required String label,
    required String requiredText,
    bool isRequired = true,
    required ThemeProvider theme,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: theme.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          requiredText,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isRequired ? Colors.redAccent : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ThemeProvider theme,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      onChanged: onChanged,
      style: GoogleFonts.outfit(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: theme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: theme.textSecondary.withValues(alpha: 0.6), fontSize: 12.5),
        prefixIcon: Icon(icon, color: _primaryOrange, size: 18),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.cancel_rounded, color: theme.textSecondary.withValues(alpha: 0.6), size: 16),
                onPressed: () {
                  controller.clear();
                  if (mounted) setState(() {});
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.borderCol),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.borderCol),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryOrange, width: 1.8),
        ),
        filled: true,
        fillColor: theme.inputBg,
      ),
    );
  }

  Widget _labelSheetBtn(String label, IconData icon, StateSetter setSheetState, ThemeProvider theme) {
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
          color: isSelected ? _primaryOrange : (theme.isDarkMode ? const Color(0xFF25293A) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [BoxShadow(color: _primaryOrange.withValues(alpha: 0.3), blurRadius: 8)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? Colors.white : theme.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : theme.textSecondary)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<CustomerLanguageProvider>(context);
    final isDark = theme.isDarkMode;

    return PopScope(
      canPop: !widget.isInitialSetup,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.isTamil ? 'வரைபடத்தில் உங்கள் டெலிவரி முகவரியை உறுதிப்படுத்தவும்.' : lang.isTanglish ? 'Map-il ungal delivery address-ai confirm seiyavum.' : 'Please select and confirm your delivery address on the map.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
            backgroundColor: const Color(0xFF4F46E5),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBg,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBg,
          elevation: 0,
          leading: widget.isInitialSetup
              ? null
              : IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.borderCol),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(lang.translate('set_delivery_location'),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900, fontSize: 15, color: theme.textPrimary)),
          ),
          centerTitle: true,
        ),
        body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 18.5,
              minZoom: 3.0,
              maxZoom: 20.0,
              backgroundColor: theme.mapBg,
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
                urlTemplate: _effectiveTileUrl,
                subdomains: _effectiveTileUrl.contains('google.com') ? const ['0', '1', '2', '3'] : const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.namba.customer',
                maxZoom: 20.0,
                maxNativeZoom: 20,
                minZoom: 3.0,
                keepBuffer: 4,
                panBuffer: 2,
                tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 100)),
                tileProvider: CachedTileProvider(),
                errorTileCallback: (tile, error, stackTrace) {
                  debugPrint('Map Tile error: $error');
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
                    color: theme.cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.borderCol),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12), blurRadius: 16, offset: const Offset(0, 4)),
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
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary),
                          decoration: InputDecoration(
                            hintText: lang.translate('search_map_hint'),
                            hintStyle: GoogleFonts.outfit(fontSize: 13, color: theme.textSecondary),
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
                      color: theme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.borderCol),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12), blurRadius: 16, offset: const Offset(0, 4)),
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
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary),
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
                  final bounceOffset = (1.0 - _pinBounceAnim.value) * -22.0;
                  final totalLift = liftOffset + bounceOffset;

                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Concentric Bullseye Target Ring at exact ground contact (Image 3)
                      Center(
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFF1E293B), width: 2.2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 4.5,
                              height: 4.5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E293B),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Ground Pin Shadow
                      Transform.translate(
                        offset: const Offset(0, 8),
                        child: Opacity(
                          opacity: (0.35 * _shadowAnim.value).clamp(0.0, 1.0),
                          child: Container(
                            width: 22 * _shadowAnim.value,
                            height: 7 * _shadowAnim.value,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                        ),
                      ),

                      // Pin Head (lifts up when dragging, reveals ground bullseye target)
                      Transform.translate(
                        offset: Offset(0, -30 + totalLift),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Top Tag Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEA4335), Color(0xFFC5221F)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEA4335).withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Colors.white, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    'DELIVER HERE',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),

                            // Red Pin Icon with Image 3 concentric center
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 56,
                                  color: Color(0xFFEA4335),
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  top: 13,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFB71C1C),
                                          shape: BoxShape.circle,
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
                        _safeMoveMap(realCenter, 18.5);
                        _debouncedReverseGeocode(realCenter);
                      }
                    } catch (_) {}
                    if (mounted) setState(() => _isLoadingGps = false);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.borderCol),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.35 : 0.12), blurRadius: 12)],
                    ),
                    child: _isLoadingGps
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: _primaryOrange)))
                        : const Icon(Icons.my_location_rounded, color: _primaryOrange, size: 22),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.borderCol),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.35 : 0.15), blurRadius: 12)],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.add_rounded, color: theme.textPrimary, size: 24),
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
                        icon: Icon(Icons.remove_rounded, color: theme.textPrimary, size: 24),
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
                    const PopupMenuItem(
                      value: 'https://mt{s}.google.com/vt/lyrs=m&hl=en&gl=IN&x={x}&y={y}&z={z}',
                      child: Row(
                        children: [
                          Icon(Icons.directions_car_rounded, color: Color(0xFF10B981), size: 18),
                          SizedBox(width: 8),
                          Text('Google Standard Roads (Fast)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'https://mt{s}.google.com/vt/lyrs=m,traffic&hl=en&gl=IN&x={x}&y={y}&z={z}',
                      child: Row(
                        children: [
                          Icon(Icons.traffic_rounded, color: Color(0xFFEF4444), size: 18),
                          SizedBox(width: 8),
                          Text('Google Live Traffic'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'https://mt{s}.google.com/vt/lyrs=y&hl=en&gl=IN&x={x}&y={y}&z={z}',
                      child: Row(
                        children: [
                          Icon(Icons.satellite_alt_rounded, color: Color(0xFFF59E0B), size: 18),
                          SizedBox(width: 8),
                          Text('Google Hybrid Satellite'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'https://mt{s}.google.com/vt/lyrs=p&hl=en&gl=IN&x={x}&y={y}&z={z}',
                      child: Row(
                        children: [
                          Icon(Icons.terrain_rounded, color: Color(0xFF6366F1), size: 18),
                          SizedBox(width: 8),
                          Text('Google Terrain'),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.borderCol),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.35 : 0.12), blurRadius: 12)],
                    ),
                    child: const Icon(Icons.layers_rounded, color: _primaryOrange, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // Non-blocking top floating GPS Status Pill
          if (_isLoadingGps)
            Positioned(
              top: 72,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pinpointing your exact GPS location...',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
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
                color: theme.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: theme.borderCol)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
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
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      lang.translate('order_will_be_delivered'),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: theme.textSecondary,
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
                                  color: theme.textPrimary,
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
                              lang.translate('confirm_location'),
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
