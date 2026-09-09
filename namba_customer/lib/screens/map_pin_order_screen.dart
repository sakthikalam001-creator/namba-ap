import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/order_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/location_accuracy_service.dart';
import '../services/delivery_hub_service.dart';
import 'order_details_screen.dart';
import '../services/cached_tile_provider.dart';

class MapPinOrderScreen extends StatefulWidget {
  const MapPinOrderScreen({super.key});

  @override
  State<MapPinOrderScreen> createState() => _MapPinOrderScreenState();
}

class _MapPinOrderScreenState extends State<MapPinOrderScreen> with TickerProviderStateMixin {
  final MapController _pickupMapController = MapController();
  final MapController _dropMapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();

  // ── STEP 1 & 2: PICKUP STORE DETAILS ──────────────────────────────────────
  LatLng _pickupLocation = (LocationAccuracyService.lastKnownAccuratePosition != null &&
          LocationAccuracyService.lastKnownAccuratePosition!.latitude != 0.0)
      ? LatLng(
          LocationAccuracyService.lastKnownAccuratePosition!.latitude,
          LocationAccuracyService.lastKnownAccuratePosition!.longitude,
        )
      : const LatLng(11.3410, 77.7172);
  String _pickupAddress = "Selected Shop Location";
  bool _isResolvingPickupAddress = false;

  final TextEditingController _shopNameCtrl = TextEditingController();
  final TextEditingController _shopStreetCtrl = TextEditingController();
  final TextEditingController _shopLandmarkCtrl = TextEditingController();
  final TextEditingController _shopPhoneCtrl = TextEditingController();

  // ── STEP 3 & 4: DROP / DELIVERY DETAILS ────────────────────────────────────
  LatLng _dropLocation = const LatLng(11.3410, 77.7172);
  String _dropAddress = "Selected Delivery Location";
  bool _isResolvingDropAddress = false;

  final TextEditingController _dropHouseNoCtrl = TextEditingController();
  final TextEditingController _dropStreetCtrl = TextEditingController();
  final TextEditingController _dropLandmarkCtrl = TextEditingController();
  final TextEditingController _receiverNameCtrl = TextEditingController();
  final TextEditingController _receiverPhoneCtrl = TextEditingController();
  bool _isDeliverToMe = true;

  // ── STEP 5: ITEMS & ORDER DETAILS ─────────────────────────────────────────
  final TextEditingController _itemNameCtrl = TextEditingController();
  final TextEditingController _itemQtyCtrl = TextEditingController();
  final FocusNode _itemNameFocusNode = FocusNode();
  final FocusNode _itemQtyFocusNode = FocusNode();
  final TextEditingController _notesCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  int _selectedMode = 0; // 0 = Text List, 1 = Photo Upload
  final List<Map<String, String>> _shoppingItems = [];
  File? _selectedPhoto;
  String _selectedDeliveryTag = 'Call on Arrival';

  // Multi-Step Progress: 1 = Shop Pin, 2 = Shop Info, 3 = Drop Pin, 4 = Drop Info, 5 = Items & Fare
  int _currentStep = 1;

  // Search Results
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  // Map Tile Style (Google Standard Roads - Ultra Fast & Clean)
  String _currentMapStyleUrl = 'https://mt{s}.google.com/vt/lyrs=m&hl=en&gl=IN&x={x}&y={y}&z={z}';
  String get _effectiveTileUrl => _currentMapStyleUrl;

  // Tactile pin lift & bounce animations
  late AnimationController _pinLiftController;
  late AnimationController _pinBounceController;
  late AnimationController _shadowController;
  late Animation<double> _pinLiftAnim;
  late Animation<double> _pinBounceAnim;
  late Animation<double> _shadowAnim;
  bool _isDraggingPickup = false;
  bool _isDraggingDrop = false;

  AnimationController? _pickupMoveAnimCtrl;
  AnimationController? _dropMoveAnimCtrl;

  // Admin Custom Map Pin Order Settings (KM-based pricing)
  double _customOrderBaseFee = 25.0;
  double _customOrderBaseKm = 2.0;
  double _customOrderPerKmRate = 10.0;
  double _customOrderHandlingFee = 5.0;
  bool _customOrderPrepayDeliveryFee = false; // Loaded dynamically from Admin Settings
  double _maxServiceRadiusKm = 10.0;
  LatLng _serviceCenter = const LatLng(11.3410, 77.7172);
  String _activeHubName = 'Erode Central Hub';
  List<DeliveryHub> _deliveryHubs = [];

  // Distance & Fee Calculations
  double _distanceFromCenterKm = 0.0;
  double _pickupToDropDistanceKm = 0.0;
  double _baseDeliveryPart = 25.0;
  double _extraKmFeePart = 0.0;
  double _calculatedDeliveryFee = 30.0;
  bool _isOutOfRange = false;
  bool _isSubmitting = false;

  bool _isPickupMapReady = false;
  bool _isDropMapReady = false;
  Timer? _pickupGeocodeDebounce;
  Timer? _dropGeocodeDebounce;

  @override
  void initState() {
    super.initState();

    // Tactile pin lift when dragging
    _pinLiftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _pinLiftAnim = Tween<double>(begin: 0, end: -18).animate(
      CurvedAnimation(parent: _pinLiftController, curve: Curves.easeOut),
    );

    // Ground shadow animation
    _shadowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _shadowAnim = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _shadowController, curve: Curves.easeOut),
    );

    // Soft tactile bounce on drop
    _pinBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _pinBounceAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pinBounceController, curve: Curves.bounceOut),
    );
    _pinBounceController.forward();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (LocationAccuracyService.lastKnownAccuratePosition != null &&
        LocationAccuracyService.lastKnownAccuratePosition!.latitude != 0.0) {
      final loc = LatLng(
        LocationAccuracyService.lastKnownAccuratePosition!.latitude,
        LocationAccuracyService.lastKnownAccuratePosition!.longitude,
      );
      _pickupLocation = loc;
      _dropLocation = loc;
      if (LocationAccuracyService.lastKnownAddress != null &&
          LocationAccuracyService.lastKnownAddress!.isNotEmpty &&
          !LocationAccuracyService.lastKnownAddress!.toLowerCase().contains('fetching')) {
        _dropAddress = LocationAccuracyService.lastKnownAddress!;
      } else {
        _dropAddress = auth.address.isNotEmpty ? auth.address : "Selected Location";
      }
    } else if (auth.selectedAddress.lat != null &&
        auth.selectedAddress.lng != null &&
        auth.selectedAddress.lat != 0 &&
        auth.selectedAddress.lat != 11.3410) {
      _pickupLocation = LatLng(auth.selectedAddress.lat!, auth.selectedAddress.lng!);
      _dropLocation = LatLng(auth.selectedAddress.lat!, auth.selectedAddress.lng!);
      _dropAddress = auth.address.isNotEmpty ? auth.address : "My Saved Address";
    }

    _receiverNameCtrl.text = auth.name;
    _receiverPhoneCtrl.text = auth.phone;

    _fetchAdminLogisticsSettings();
    _reverseGeocodePickupLocation(_pickupLocation);
    _detectLiveGpsForPickup();
  }

  @override
  void dispose() {
    _pinLiftController.dispose();
    _shadowController.dispose();
    _pinBounceController.dispose();
    _pickupMoveAnimCtrl?.dispose();
    _dropMoveAnimCtrl?.dispose();
    _searchCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopStreetCtrl.dispose();
    _shopLandmarkCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _dropHouseNoCtrl.dispose();
    _dropStreetCtrl.dispose();
    _dropLandmarkCtrl.dispose();
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    _itemNameCtrl.dispose();
    _itemQtyCtrl.dispose();
    _pickupGeocodeDebounce?.cancel();
    _dropGeocodeDebounce?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectLiveGpsForPickup() async {
    try {
      final pos = await LocationAccuracyService.getBestPosition(
        forceFresh: true,
        targetAccuracyMeters: 8,
        quickFixTimeout: const Duration(seconds: 7),
        onPosition: (livePos) {
          if (mounted) {
            final liveCenter = LatLng(livePos.latitude, livePos.longitude);
            final quickArea = LocationAccuracyService.resolveKnownArea(liveCenter.latitude, liveCenter.longitude);
            setState(() {
              _pickupLocation = liveCenter;
              _pickupAddress = quickArea;
              if (_dropAddress == "Selected Delivery Location") {
                _dropLocation = liveCenter;
                _dropAddress = quickArea;
              }
            });
            _safeMovePickupMap(liveCenter, 18.0);
            _reverseGeocodePickupLocation(liveCenter);
          }
        },
      );
      if (pos != null && mounted) {
        final liveCenter = LatLng(pos.latitude, pos.longitude);
        final quickArea = LocationAccuracyService.resolveKnownArea(liveCenter.latitude, liveCenter.longitude);
        setState(() {
          _pickupLocation = liveCenter;
          _pickupAddress = quickArea;
          if (_dropAddress == "Selected Delivery Location") {
            _dropLocation = liveCenter;
            _dropAddress = quickArea;
          }
        });
        _safeMovePickupMap(liveCenter, 18.0);
        _reverseGeocodePickupLocation(liveCenter);
      }
    } catch (_) {}
  }

  Future<void> _detectLiveGpsForDrop() async {
    try {
      final pos = await LocationAccuracyService.getBestPosition(
        forceFresh: true,
        targetAccuracyMeters: 8,
        quickFixTimeout: const Duration(seconds: 7),
        onPosition: (livePos) {
          if (mounted) {
            final liveCenter = LatLng(livePos.latitude, livePos.longitude);
            final quickArea = LocationAccuracyService.resolveKnownArea(liveCenter.latitude, liveCenter.longitude);
            setState(() {
              _dropLocation = liveCenter;
              _dropAddress = quickArea;
            });
            _safeMoveDropMap(liveCenter, 18.0);
            _reverseGeocodeDropLocation(liveCenter);
          }
        },
      );
      if (pos != null && mounted) {
        final liveCenter = LatLng(pos.latitude, pos.longitude);
        final quickArea = LocationAccuracyService.resolveKnownArea(liveCenter.latitude, liveCenter.longitude);
        setState(() {
          _dropLocation = liveCenter;
          _dropAddress = quickArea;
        });
        _safeMoveDropMap(liveCenter, 18.0);
        _reverseGeocodeDropLocation(liveCenter);
      }
    } catch (_) {}
  }

  void _onPickupDragStart() {
    HapticFeedback.lightImpact();
    _isDraggingPickup = true;
    _pinLiftController.forward();
    _shadowController.forward();
    if (mounted) setState(() {});
  }

  void _onPickupDragEnd() {
    _isDraggingPickup = false;
    _pinLiftController.reverse();
    _shadowController.reverse();
    _pinBounceController
      ..reset()
      ..forward();
    final targetCenter = _pickupMapController.camera.center;
    _pickupLocation = targetCenter;
    final quickArea = LocationAccuracyService.resolveKnownArea(targetCenter.latitude, targetCenter.longitude);
    _pickupAddress = quickArea;
    _recalculateLogisticsAndRange();
    _pickupGeocodeDebounce?.cancel();
    _pickupGeocodeDebounce = Timer(const Duration(milliseconds: 200), () {
      _reverseGeocodePickupLocation(targetCenter);
      _fetchExactRoadDistance();
    });
    if (mounted) setState(() {});
  }

  void _onDropDragStart() {
    HapticFeedback.lightImpact();
    _isDraggingDrop = true;
    _pinLiftController.forward();
    _shadowController.forward();
    if (mounted) setState(() {});
  }

  void _onDropDragEnd() {
    _isDraggingDrop = false;
    _pinLiftController.reverse();
    _shadowController.reverse();
    _pinBounceController
      ..reset()
      ..forward();
    final targetCenter = _dropMapController.camera.center;
    _dropLocation = targetCenter;
    final quickArea = LocationAccuracyService.resolveKnownArea(targetCenter.latitude, targetCenter.longitude);
    _dropAddress = quickArea;
    _recalculateLogisticsAndRange();
    _dropGeocodeDebounce?.cancel();
    _dropGeocodeDebounce = Timer(const Duration(milliseconds: 200), () {
      _reverseGeocodeDropLocation(targetCenter);
      _fetchExactRoadDistance();
    });
    if (mounted) setState(() {});
  }

  void _animatedMovePickupMap(LatLng destLocation, double destZoom) {
    if (!_isPickupMapReady || !mounted) return;
    _pickupMoveAnimCtrl?.stop();
    _pickupMoveAnimCtrl?.dispose();
    _pickupMoveAnimCtrl = null;

    final latTween = Tween<double>(
      begin: _pickupMapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _pickupMapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _pickupMapController.camera.zoom,
      end: destZoom,
    );

    final animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pickupMoveAnimCtrl = animCtrl;
    final animation = CurvedAnimation(parent: animCtrl, curve: Curves.easeOutCubic);

    animCtrl.addListener(() {
      try {
        _pickupMapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      } catch (_) {}
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        if (_pickupMoveAnimCtrl == animCtrl) {
          _pickupMoveAnimCtrl = null;
        }
        animCtrl.dispose();
      }
    });

    animCtrl.forward();
  }

  void _animatedMoveDropMap(LatLng destLocation, double destZoom) {
    if (!_isDropMapReady || !mounted) return;
    _dropMoveAnimCtrl?.stop();
    _dropMoveAnimCtrl?.dispose();
    _dropMoveAnimCtrl = null;

    final latTween = Tween<double>(
      begin: _dropMapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _dropMapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _dropMapController.camera.zoom,
      end: destZoom,
    );

    final animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dropMoveAnimCtrl = animCtrl;
    final animation = CurvedAnimation(parent: animCtrl, curve: Curves.easeOutCubic);

    animCtrl.addListener(() {
      try {
        _dropMapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      } catch (_) {}
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        if (_dropMoveAnimCtrl == animCtrl) {
          _dropMoveAnimCtrl = null;
        }
        animCtrl.dispose();
      }
    });

    animCtrl.forward();
  }

  void _safeMovePickupMap(LatLng center, double zoom, {bool animated = true}) {
    if (_isPickupMapReady && mounted) {
      if (animated) {
        _animatedMovePickupMap(center, zoom);
      } else {
        try {
          _pickupMapController.move(center, zoom);
        } catch (e) {
          debugPrint('Pickup map move error: $e');
        }
      }
    }
  }

  void _safeMoveDropMap(LatLng center, double zoom, {bool animated = true}) {
    if (_isDropMapReady && mounted) {
      if (animated) {
        _animatedMoveDropMap(center, zoom);
      } else {
        try {
          _dropMapController.move(center, zoom);
        } catch (e) {
          debugPrint('Drop map move error: $e');
        }
      }
    }
  }

  Future<void> _fetchAdminLogisticsSettings() async {
    try {
      final hubs = await DeliveryHubService.fetchHubs(forceRefresh: true);
      _deliveryHubs = hubs;

      final url = Uri.parse('${CustomerApiService.baseUrl}/admin/settings/public');
      final res = await http.get(url).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (data != null) {
          final double baseFee = (data['customOrderBaseFee'] ?? 25.0).toDouble();
          final double baseKm = (data['customOrderBaseKm'] ?? 2.0).toDouble();
          final double perKmRate = (data['customOrderPerKmRate'] ?? 10.0).toDouble();
          final double handlingFee = (data['customOrderHandlingFee'] ?? 5.0).toDouble();
          final bool prepayDeliveryFee = data['customOrderPrepayDeliveryFee'] ?? false;

          if (mounted) {
            setState(() {
              _customOrderBaseFee = baseFee;
              _customOrderBaseKm = baseKm;
              _customOrderPerKmRate = perKmRate;
              _customOrderHandlingFee = handlingFee;
              _customOrderPrepayDeliveryFee = prepayDeliveryFee;
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      _recalculateLogisticsAndRange();
    }
  }

  Future<void> _reverseGeocodePickupLocation(LatLng location) async {
    setState(() {
      _isResolvingPickupAddress = true;
      if (_pickupAddress.isEmpty || _pickupAddress.startsWith('Location (')) {
        _pickupAddress = LocationAccuracyService.resolveKnownArea(location.latitude, location.longitude);
      }
    });
    try {
      final formatted = await LocationAccuracyService.reverseGeocode(location.latitude, location.longitude);
      if (mounted) {
        setState(() {
          _pickupAddress = formatted;
          _isResolvingPickupAddress = false;
        });
        _recalculateLogisticsAndRange();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pickupAddress = LocationAccuracyService.resolveKnownArea(location.latitude, location.longitude);
          _isResolvingPickupAddress = false;
        });
        _recalculateLogisticsAndRange();
      }
    }
  }

  Future<void> _reverseGeocodeDropLocation(LatLng location) async {
    setState(() {
      _isResolvingDropAddress = true;
      if (_dropAddress.isEmpty || _dropAddress.startsWith('Location (')) {
        _dropAddress = LocationAccuracyService.resolveKnownArea(location.latitude, location.longitude);
      }
    });
    try {
      final formatted = await LocationAccuracyService.reverseGeocode(location.latitude, location.longitude);
      if (mounted) {
        setState(() {
          _dropAddress = formatted;
          _isResolvingDropAddress = false;
        });
        _recalculateLogisticsAndRange();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dropAddress = LocationAccuracyService.resolveKnownArea(location.latitude, location.longitude);
          _isResolvingDropAddress = false;
        });
        _recalculateLogisticsAndRange();
      }
    }
  }

  void _recalculateLogisticsAndRange() {
    // 1. Dynamic Multi-Hub Distance Matching using accurate WGS-84 formula
    final match = DeliveryHubService.matchLocation(
      _pickupLocation.latitude,
      _pickupLocation.longitude,
      hubs: _deliveryHubs,
    );

    // 2. Direct Urban Road Distance between Pickup Store and Drop Location
    final double meterDistRoute = Geolocator.distanceBetween(
      _pickupLocation.latitude,
      _pickupLocation.longitude,
      _dropLocation.latitude,
      _dropLocation.longitude,
    );
    final double kmRoute = (meterDistRoute * 1.25) / 1000.0;
    final distKm = double.parse(kmRoute.toStringAsFixed(1));

    // Dynamic Admin KM Logistics Fee Rule:
    final basePart = _customOrderBaseFee;
    final extraPart = (distKm <= _customOrderBaseKm)
        ? 0.0
        : ((distKm - _customOrderBaseKm) * _customOrderPerKmRate).roundToDouble();
    final totalFee = basePart + extraPart + _customOrderHandlingFee;

    if (mounted) {
      setState(() {
        _activeHubName = match.hub.name;
        _maxServiceRadiusKm = match.hub.radiusKm;
        _serviceCenter = LatLng(match.hub.lat, match.hub.lng);
        _distanceFromCenterKm = match.distanceKm;
        _isOutOfRange = !match.isInRange;
        _pickupToDropDistanceKm = distKm;
        _baseDeliveryPart = basePart;
        _extraKmFeePart = extraPart;
        _calculatedDeliveryFee = totalFee;
      });
    } else {
      _activeHubName = match.hub.name;
      _maxServiceRadiusKm = match.hub.radiusKm;
      _serviceCenter = LatLng(match.hub.lat, match.hub.lng);
      _distanceFromCenterKm = match.distanceKm;
      _isOutOfRange = !match.isInRange;
      _pickupToDropDistanceKm = distKm;
      _baseDeliveryPart = basePart;
      _extraKmFeePart = extraPart;
      _calculatedDeliveryFee = totalFee;
    }
  }

  Future<void> _fetchExactRoadDistance() async {
    try {
      final double meterDistRoute = Geolocator.distanceBetween(
        _pickupLocation.latitude,
        _pickupLocation.longitude,
        _dropLocation.latitude,
        _dropLocation.longitude,
      );
      final double straightKm = meterDistRoute / 1000.0;
      final double baseRoadKm = double.parse((straightKm * 1.25).toStringAsFixed(1));

      // Multi-profile routing with real driving road networks (Google Maps / OSRM parity)
      final urls = [
        'https://router.project-osrm.org/route/v1/driving/${_pickupLocation.longitude},${_pickupLocation.latitude};${_dropLocation.longitude},${_dropLocation.latitude}?overview=false',
        'https://routing.openstreetmap.de/routed-car/route/v1/driving/${_pickupLocation.longitude},${_pickupLocation.latitude};${_dropLocation.longitude},${_dropLocation.latitude}?overview=false',
        'https://routing.openstreetmap.de/routed-bike/route/v1/biking/${_pickupLocation.longitude},${_pickupLocation.latitude};${_dropLocation.longitude},${_dropLocation.latitude}?overview=false',
      ];

      double? bestRoadKm;
      for (final urlStr in urls) {
        try {
          final res = await http.get(Uri.parse(urlStr), headers: {
            'User-Agent': 'NambaDelivery_RoadEngine/2.0'
          }).timeout(const Duration(seconds: 3));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
              final double meters = (data['routes'][0]['distance'] as num).toDouble();
              final double parsedKm = meters / 1000.0;
              if (parsedKm >= (straightKm * 0.95)) {
                if (bestRoadKm == null || parsedKm < bestRoadKm) {
                  bestRoadKm = parsedKm;
                }
              }
            }
          }
        } catch (_) {}
        if (bestRoadKm != null) break;
      }

      final double finalKm = double.parse((bestRoadKm ?? baseRoadKm).toStringAsFixed(1));
      if (mounted && finalKm > 0) {
        setState(() {
          _pickupToDropDistanceKm = finalKm;
          _baseDeliveryPart = _customOrderBaseFee;
          if (_pickupToDropDistanceKm <= _customOrderBaseKm) {
            _extraKmFeePart = 0.0;
          } else {
            _extraKmFeePart = ((_pickupToDropDistanceKm - _customOrderBaseKm) * _customOrderPerKmRate).roundToDouble();
          }
          _calculatedDeliveryFee = _baseDeliveryPart + _extraKmFeePart + _customOrderHandlingFee;
        });
      }
    } catch (_) {}
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5&countrycodes=in');
      final res = await http.get(url, headers: {'User-Agent': 'NambaCustomerApp/1.0'}).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _searchResults = list;
            _isSearching = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(dynamic item) {
    final lat = double.tryParse(item['lat'] ?? '');
    final lon = double.tryParse(item['lon'] ?? '');
    if (lat != null && lon != null) {
      final target = LatLng(lat, lon);
      setState(() {
        if (_currentStep == 1) {
          _pickupLocation = target;
          _pickupAddress = item['display_name'] ?? _pickupAddress;
          _safeMovePickupMap(target, 18.0);
        } else if (_currentStep == 3) {
          _dropLocation = target;
          _dropAddress = item['display_name'] ?? _dropAddress;
          _safeMoveDropMap(target, 18.0);
        }
        _searchResults = [];
        _searchCtrl.clear();
      });
      _recalculateLogisticsAndRange();
      _fetchExactRoadDistance();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() {
          _selectedPhoto = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ── NAVIGATION & VALIDATION PER STEP ───────────────────────────────────────
  void _onConfirmStep1() {
    final lang = Provider.of<CustomerLanguageProvider>(context, listen: false);
    if (_isOutOfRange) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              lang.isTamil
                  ? '❌ தேர்ந்தெடுக்கப்பட்ட கடை $_activeHubName சேவை எல்லைக்கு அப்பால் உள்ளது (அதிகபட்சம் ${_maxServiceRadiusKm.toInt()} KM).'
                  : lang.isTanglish
                      ? '❌ Shop $_activeHubName ellaikulla illai (Max ${_maxServiceRadiusKm.toInt()} KM).'
                      : '❌ Out of Service Area! Pinned store is outside $_activeHubName range (Max ${_maxServiceRadiusKm.toInt()} KM).'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 2;
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  void _onConfirmStep2() {
    final lang = Provider.of<CustomerLanguageProvider>(context, listen: false);
    final name = _shopNameCtrl.text.trim();
    final street = _shopStreetCtrl.text.trim();
    final landmark = _shopLandmarkCtrl.text.trim();

    if (name.isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack(lang.isTamil ? 'தயவுசெய்து கடையின் பெயரை உள்ளிடவும்' : lang.isTanglish ? 'Kadai peyarai enter seiyavum' : 'Please enter Store / Shop Name');
      return;
    }
    if (street.isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack(lang.isTamil ? 'தயவுசெய்து கடை தெரு / பகுதி பெயரை உள்ளிடவும்' : lang.isTanglish ? 'Shop theru / area peyarai enter seiyavum' : 'Please enter Shop Street / Area / Market Name');
      return;
    }
    if (landmark.isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack(lang.isTamil ? 'தயவுசெய்து கடை அடையாளக் குறியை உள்ளிடவும்' : lang.isTanglish ? 'Shop landmark enter seiyavum' : 'Please enter Shop Landmark / Nearby Spot');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 3;
      _searchCtrl.clear();
      _searchResults = [];
    });
    _safeMoveDropMap(_dropLocation, 18.0);
    _reverseGeocodeDropLocation(_dropLocation);
    _fetchExactRoadDistance();
  }

  void _onConfirmStep3() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 4;
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  void _onConfirmStep4() {
    final lang = Provider.of<CustomerLanguageProvider>(context, listen: false);
    final houseNo = _dropHouseNoCtrl.text.trim();
    final street = _dropStreetCtrl.text.trim();
    final landmark = _dropLandmarkCtrl.text.trim();
    final recName = _receiverNameCtrl.text.trim();
    final recPhone = _receiverPhoneCtrl.text.trim();

    if (houseNo.isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack(lang.isTamil ? 'தயவுசெய்து வீட்டு எண் / தளத்தை உள்ளிடவும்' : lang.isTanglish ? 'Veetu en / House number enter seiyavum' : 'Please enter House / Flat / Floor Number');
      return;
    }
    if (street.isEmpty && _dropAddress.isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack(lang.isTamil ? 'தயவுசெய்து கட்டிடம் / தெருப் பெயரை உள்ளிடவும்' : lang.isTanglish ? 'Kattidam / theru peyarai enter seiyavum' : 'Please enter Building / Apartment / Street Name');
      return;
    }
    if (landmark.isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack(lang.isTamil ? 'தயவுசெய்து டெலிவரி அடையாளக் குறியை உள்ளிடவும்' : lang.isTanglish ? 'Delivery landmark enter seiyavum' : 'Please enter Delivery Landmark');
      return;
    }
    if (!_isDeliverToMe && (recName.isEmpty || recPhone.isEmpty)) {
      HapticFeedback.vibrate();
      _showErrorSnack(lang.isTamil ? 'தயவுசெய்து பெறுபவர் பெயர் மற்றும் மொபைல் எண்ணை உள்ளிடவும்' : lang.isTanglish ? 'Receiver peyar matrum phone number-ai enter seiyavum' : 'Please enter Recipient Name and Phone Number');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 5;
    });
    _fetchExactRoadDistance();
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _onPlaceOrderPressed() async {
    if (_selectedMode == 0 && _shoppingItems.isEmpty && _notesCtrl.text.trim().isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack('Please add at least 1 item or write your shopping list in the text box.');
      return;
    }
    if (_selectedMode == 1 && _selectedPhoto == null) {
      HapticFeedback.vibrate();
      _showErrorSnack('Please upload or capture a photo of your shopping list.');
      return;
    }

    if (_customOrderPrepayDeliveryFee) {
      _showDeliveryFeePaymentSheet();
    } else {
      _submitMapPinOrder();
    }
  }

  void _showDeliveryFeePaymentSheet() {
    int selectedUpiApp = 0;
    final List<Map<String, dynamic>> upiApps = [
      {'name': 'Google Pay', 'icon': Icons.g_mobiledata_rounded, 'color': const Color(0xFF4285F4)},
      {'name': 'PhonePe', 'icon': Icons.phone_android_rounded, 'color': const Color(0xFF5F259F)},
      {'name': 'Paytm UPI', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF00BAF2)},
      {'name': 'BHIM / Any UPI', 'icon': Icons.currency_rupee_rounded, 'color': const Color(0xFF1E3A5F)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
          decoration: BoxDecoration(
            color: Provider.of<ThemeProvider>(context, listen: false).cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.payment_rounded, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Provider.of<CustomerLanguageProvider>(context, listen: false).isTamil ? 'டெலிவரி கட்டணம்' : 'Pay Delivery Fee',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Provider.of<ThemeProvider>(context, listen: false).textPrimary),
                        ),
                        Text(
                          Provider.of<CustomerLanguageProvider>(context, listen: false).isTamil
                              ? 'டெலிவரி கட்டணத்தை செலுத்தி ஆர்டரை உறுதிசெய்யவும்'
                              : Provider.of<CustomerLanguageProvider>(context, listen: false).isTanglish
                                  ? 'Delivery fee pay panni order confirm pannunga'
                                  : 'Pay delivery fee to confirm your order',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: Provider.of<ThemeProvider>(context, listen: false).textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                    child: Text('₹${_calculatedDeliveryFee.toInt()}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── HOW ITEM BILL WORKS NOTICE ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        Provider.of<CustomerLanguageProvider>(context, listen: false).isTamil
                            ? 'Rider கடைக்குச் சென்று பொருட்களைப் பார்த்து பில் Quote அனுப்பியவுடன், பொருட்களுக்கான தொகையை (Item Bill) Pay செய்யலாம்.'
                            : Provider.of<CustomerLanguageProvider>(context, listen: false).isTanglish
                                ? 'Rider kadai poi bill quote anuppiyavudan item bill pay pannalaam.'
                                : 'Once the rider visits the shop and sends the bill quote, you can pay for the items.',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                Provider.of<CustomerLanguageProvider>(context, listen: false).isTamil
                    ? 'பணம் செலுத்தும் முறையைத் தேர்ந்தெடுக்கவும் (UPI / ONLINE)'
                    : 'SELECT PAYMENT METHOD (UPI / ONLINE)',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.5),
              ),
              const SizedBox(height: 10),

              ...List.generate(upiApps.length, (idx) {
                final app = upiApps[idx];
                final isSel = selectedUpiApp == idx;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setSheetState(() => selectedUpiApp = idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSel ? const Color(0xFF4F46E5) : Colors.grey.shade200, width: isSel ? 1.8 : 1),
                      ),
                      child: Row(
                        children: [
                          Icon(app['icon'] as IconData, color: app['color'] as Color, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              app['name'] as String,
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: Provider.of<ThemeProvider>(context, listen: false).textPrimary),
                            ),
                          ),
                          Icon(
                            isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isSel ? const Color(0xFF4F46E5) : Colors.grey.shade400,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    _processPaymentAndSubmitOrder(upiApps[selectedUpiApp]['name'] as String);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'CONFIRM & PAY ₹${_calculatedDeliveryFee.toInt()}',
                        style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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

  Future<void> _processPaymentAndSubmitOrder(String paymentApp) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              Text('Connecting to $paymentApp...', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 6),
              Text('Processing ₹${_calculatedDeliveryFee.toInt()} Delivery Fee Payment', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );

    // Fast payment simulated gateway flow
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.pop(context); // Close processing dialog

    _submitMapPinOrder();
  }

  Future<void> _submitMapPinOrder() async {
    final shopName = _shopNameCtrl.text.trim();
    final shopStreet = _shopStreetCtrl.text.trim();
    final shopLandmark = _shopLandmarkCtrl.text.trim();
    final shopPhone = _shopPhoneCtrl.text.trim();

    String content = '';
    if (_selectedMode == 0) {
      if (_shoppingItems.isEmpty && _notesCtrl.text.trim().isEmpty) {
        HapticFeedback.vibrate();
        _showErrorSnack('Please add at least 1 item or write your shopping list in the text box.');
        return;
      }

      final itemsText = _shoppingItems.map((e) => "${e['name']} (${e['qty']})").join('\n');
      final notesText = _notesCtrl.text.trim();
      final instructions = "Delivery Preference: $_selectedDeliveryTag";
      content = itemsText.isNotEmpty
          ? "$itemsText\n\nInstructions: $instructions${notesText.isNotEmpty ? '\nNotes: $notesText' : ''}"
          : "$instructions\nNotes: $notesText";
    } else {
      if (_selectedPhoto == null) {
        HapticFeedback.vibrate();
        _showErrorSnack('Please upload or capture a photo of your shopping list.');
        return;
      }
      final notesText = _notesCtrl.text.trim();
      content = "Photo Order Attached.\nDelivery Preference: $_selectedDeliveryTag${notesText.isNotEmpty ? '\nNotes: $notesText' : ''}";
    }

    // Complete Store & Drop Details
    final finalStoreName = '📍 $shopName';
    String finalStoreAddress = '$shopStreet, Landmark: $shopLandmark, $_pickupAddress';
    if (shopPhone.isNotEmpty) {
      finalStoreAddress = '$finalStoreAddress (Store Ph: $shopPhone)';
    }

    final dropHouse = _dropHouseNoCtrl.text.trim();
    final dropStreet = _dropStreetCtrl.text.trim();
    final dropLandmark = _dropLandmarkCtrl.text.trim();
    final receiverName = _receiverNameCtrl.text.trim();
    final receiverPhone = _receiverPhoneCtrl.text.trim();

    String finalDropAddress = dropHouse.isNotEmpty
        ? '$dropHouse, $dropStreet, Landmark: $dropLandmark, $_dropAddress'
        : '$dropStreet, Landmark: $dropLandmark, $_dropAddress';

    if (!_isDeliverToMe && receiverName.isNotEmpty) {
      finalDropAddress = '$finalDropAddress [Receiver: $receiverName, Ph: $receiverPhone]';
    }

    final orders = Provider.of<OrderProvider>(context, listen: false);
    setState(() => _isSubmitting = true);

    try {
      final newOrder = await orders.placeCustomOrder(
        customStoreName: finalStoreName,
        customStoreAddress: finalStoreAddress,
        userAddress: finalDropAddress,
        lat: _dropLocation.latitude,
        lng: _dropLocation.longitude,
        pinnedLat: _pickupLocation.latitude,
        pinnedLng: _pickupLocation.longitude,
        deliveryFee: _calculatedDeliveryFee,
        distanceKm: _pickupToDropDistanceKm,
        type: _selectedMode == 1 ? OrderType.photo : OrderType.mapPin,
        textContent: content,
        photoPath: _selectedMode == 1 ? _selectedPhoto?.path : null,
        deliveryFeePaid: _customOrderPrepayDeliveryFee,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (newOrder != null) {
          // Auto-save the delivery address so existing customer never loses it
          try {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            auth.autoSaveAddress(
              finalDropAddress,
              _dropLocation.latitude,
              _dropLocation.longitude,
              label: _isDeliverToMe ? 'Home' : 'Delivery Address',
            );
          } catch (_) {}

          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_customOrderPrepayDeliveryFee
                  ? '🎉 Delivery Fee Paid & Pickup Order placed! Rider will visit shop and send quote.'
                  : '🎉 Pickup Order placed! Rider will visit shop and send quote.'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: newOrder.id)),
          );
        } else {
          _showErrorSnack('Failed to place order. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorSnack('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 1) {
          setState(() => _currentStep -= 1);
        }
      },
      child: Consumer2<ThemeProvider, CustomerLanguageProvider>(
        builder: (context, theme, lang, _) {
          return Scaffold(
            backgroundColor: theme.scaffoldBg,
            appBar: AppBar(
              title: Text(
                _currentStep == 1
                    ? (lang.isTamil ? '📍 படி 1: கடை இருப்பிடம்' : lang.isTanglish ? '📍 Step 1: Shop Location Pin' : '📍 Step 1: Pin Shop Location')
                    : _currentStep == 2
                        ? (lang.isTamil ? '🏪 படி 2: கடை விவரங்கள்' : lang.isTanglish ? '🏪 Step 2: Shop Details' : '🏪 Step 2: Shop Details')
                        : _currentStep == 3
                            ? (lang.isTamil ? '🏠 படி 3: டெலிவரி இடம்' : lang.isTanglish ? '🏠 Step 3: Drop Location Pin' : '🏠 Step 3: Set Drop Location')
                            : _currentStep == 4
                                ? (lang.isTamil ? '📝 படி 4: முகவரி விவரங்கள்' : lang.isTanglish ? '📝 Step 4: Drop Address Details' : '📝 Step 4: Drop Address Details')
                                : (lang.isTamil ? '🛍️ படி 5: பொருட்கள் & கட்டணம்' : lang.isTanglish ? '🛍️ Step 5: Order Items & Fare' : '🛍️ Step 5: Order Items & Fare'),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: theme.textPrimary),
              ),
              backgroundColor: theme.cardBg,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded, color: theme.textPrimary, size: 18),
                onPressed: () {
                  if (_currentStep > 1) {
                    setState(() => _currentStep -= 1);
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: _build5StepProgressBar(theme, lang),
              ),
            ),
        body: _currentStep == 1
            ? _buildStep1ShopPinMap(lang)
            : _currentStep == 2
                ? _buildStep2ShopDetailsForm(lang)
                : _currentStep == 3
                    ? _buildStep3DropPinMap(lang)
                    : _currentStep == 4
                        ? _buildStep4DropDetailsForm(lang)
                        : _buildStep5ItemsAndFare(lang),
          );
        },
      ),
    );
  }

  // ── 5-STEP PROGRESS BAR ───────────────────────────────────────────────────
  Widget _build5StepProgressBar(ThemeProvider theme, CustomerLanguageProvider lang) {
    return Container(
      color: theme.cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStepChip(step: 1, label: lang.isTamil ? '1. கடை பின்' : '1. Shop Pin', icon: Icons.location_on_rounded),
            _buildStepDivider(1),
            _buildStepChip(step: 2, label: lang.isTamil ? '2. கடை விவரம்' : '2. Shop Info', icon: Icons.storefront_rounded),
            _buildStepDivider(2),
            _buildStepChip(step: 3, label: lang.isTamil ? '3. டெலிவரி பின்' : '3. Drop Pin', icon: Icons.my_location_rounded),
            _buildStepDivider(3),
            _buildStepChip(step: 4, label: lang.isTamil ? '4. முகவரி விவரம்' : '4. Drop Info', icon: Icons.home_rounded),
            _buildStepDivider(4),
            _buildStepChip(step: 5, label: lang.isTamil ? '5. பொருட்கள் & கட்டணம்' : '5. Items & Fare', icon: Icons.shopping_bag_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDivider(int afterStep) {
    return Container(
      width: 12,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: _currentStep > afterStep ? const Color(0xFF4F46E5) : Colors.grey.shade200,
    );
  }

  Widget _buildStepChip({required int step, required String label, required IconData icon}) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;

    return GestureDetector(
      onTap: () {
        if (isDone) setState(() => _currentStep = step);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
              : isDone
                  ? const Color(0xFFECFDF5)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? const Color(0xFF4F46E5)
                : isDone
                    ? const Color(0xFF059669)
                    : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDone ? Icons.check_circle_rounded : icon,
              size: 13,
              color: isActive
                  ? const Color(0xFF4F46E5)
                  : isDone
                      ? const Color(0xFF059669)
                      : Colors.grey.shade400,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isActive
                    ? const Color(0xFF4F46E5)
                    : isDone
                        ? const Color(0xFF059669)
                        : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1: PIN SHOP LOCATION ON GOOGLE MAP
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep1ShopPinMap(CustomerLanguageProvider lang) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDarkMode;
    return Stack(
      children: [
        FlutterMap(
          mapController: _pickupMapController,
          options: MapOptions(
            initialCenter: _pickupLocation,
            initialZoom: 18.0,
            minZoom: 3.0,
            maxZoom: 20.0,
            backgroundColor: theme.mapBg,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
              enableMultiFingerGestureRace: true,
            ),
            onMapReady: () {
              if (mounted) {
                setState(() => _isPickupMapReady = true);
                _safeMovePickupMap(_pickupLocation, 18.0, animated: false);
              }
            },
            onTap: (tapPosition, point) {
              final quickArea = LocationAccuracyService.resolveKnownArea(point.latitude, point.longitude);
              setState(() {
                _pickupLocation = point;
                _pickupAddress = quickArea;
              });
              _safeMovePickupMap(point, _pickupMapController.camera.zoom, animated: true);
              _recalculateLogisticsAndRange();
              _pickupGeocodeDebounce?.cancel();
              _pickupGeocodeDebounce = Timer(const Duration(milliseconds: 200), () {
                _reverseGeocodePickupLocation(point);
                _fetchExactRoadDistance();
              });
            },
            onPositionChanged: (position, hasGesture) {
              _pickupLocation = position.center;
              if (hasGesture && !_isDraggingPickup) {
                _onPickupDragStart();
              }
            },
            onMapEvent: (event) {
              if (event is MapEventMoveEnd && _isDraggingPickup) {
                _onPickupDragEnd();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _effectiveTileUrl,
              subdomains: _effectiveTileUrl.contains('google.com')
                  ? const ['0', '1', '2', '3']
                  : const ['a', 'b', 'c', 'd'],
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
            // Dynamic Active Delivery Hub Range Circle (Exact KM Service Boundary)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _serviceCenter,
                  radius: _maxServiceRadiusKm * 1000.0,
                  useRadiusInMeter: true,
                  color: (_isOutOfRange ? Colors.red : const Color(0xFF10B981)).withValues(alpha: 0.10),
                  borderColor: (_isOutOfRange ? Colors.redAccent : const Color(0xFF10B981)).withValues(alpha: 0.65),
                  borderStrokeWidth: 2.2,
                ),
              ],
            ),
          ],
        ),

        // Search Bar
        Positioned(
          top: 14,
          left: 16,
          right: 76,
          child: _buildSearchBar(lang.isTamil ? 'கடை பெயர், தெரு, மார்க்கெட் தேடவும்...' : lang.isTanglish ? 'Shop name, street thedunga...' : 'Search shop name, street, market...'),
        ),

        // Center Marker (Interactive Tactile Shop Pin)
        Center(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pinBounceAnim, _pinLiftAnim, _shadowAnim]),
              builder: (context, child) {
                final liftOffset = _pinLiftAnim.value;
                final bounceOffset = (1.0 - _pinBounceAnim.value) * -18.0;
                final totalLift = liftOffset + bounceOffset;

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Precise Ground Target Bullseye Ring
                    Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: _isOutOfRange ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                            width: 2.5,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _isOutOfRange ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
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
                          width: 24 * _shadowAnim.value,
                          height: 8 * _shadowAnim.value,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                    ),

                    // Floating Pin Head
                    Transform.translate(
                      offset: Offset(0, -32 + totalLift),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isOutOfRange ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isOutOfRange ? const Color(0xFFEF4444) : const Color(0xFF4F46E5)).withValues(alpha: 0.45),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isOutOfRange ? Icons.warning_amber_rounded : Icons.storefront_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isOutOfRange
                                      ? (lang.isTamil
                                          ? 'எல்லைக்கு அப்பால் • $_activeHubName (அதிகபட்சம் ${_maxServiceRadiusKm.toInt()} KM)'
                                          : lang.isTanglish
                                              ? 'OUT OF RANGE • $_activeHubName (Max ${_maxServiceRadiusKm.toInt()} KM)'
                                              : 'OUT OF RANGE • $_activeHubName (Max ${_maxServiceRadiusKm.toInt()} KM)')
                                      : (lang.isTamil
                                          ? '$_activeHubName • ${_maxServiceRadiusKm.toInt()} KM எல்லைக்குள்'
                                          : lang.isTanglish
                                              ? '$_activeHubName • ${_maxServiceRadiusKm.toInt()} KM Ellaikkul'
                                              : '$_activeHubName • ${_maxServiceRadiusKm.toInt()} KM RANGE'),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 60,
                                color: _isOutOfRange ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                                shadows: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 14,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _isOutOfRange ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
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

        // Map Control Buttons
        Positioned(
          top: 14,
          right: 16,
          child: _buildMapControls(controller: _pickupMapController, onGps: _detectLiveGpsForPickup),
        ),

        // Bottom Step 1 Confirm Bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            decoration: BoxDecoration(
              color: theme.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: theme.borderCol)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12), blurRadius: 20, offset: const Offset(0, -6)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.isTamil ? 'படி 1: கடை இருப்பிடம்' : 'STEP 1: PICKUP SHOP LOCATION',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Provider.of<ThemeProvider>(context, listen: false).textSecondary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isOutOfRange ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isOutOfRange ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          _isOutOfRange
                              ? (lang.isTamil
                                  ? 'எல்லைக்கு அப்பால் (அதிகபட்சம் ${_maxServiceRadiusKm.toInt()} KM)'
                                  : lang.isTanglish
                                      ? 'Out of Range (Max ${_maxServiceRadiusKm.toInt()} KM)'
                                      : 'OUT OF RANGE • $_activeHubName (Max ${_maxServiceRadiusKm.toInt()} KM)')
                              : (lang.isTamil
                                  ? '$_activeHubName: $_distanceFromCenterKm / ${_maxServiceRadiusKm.toInt()} KM'
                                  : lang.isTanglish
                                      ? '$_activeHubName: $_distanceFromCenterKm / ${_maxServiceRadiusKm.toInt()} KM Area'
                                      : '$_activeHubName: $_distanceFromCenterKm / ${_maxServiceRadiusKm.toInt()} KM Area'),
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: _isOutOfRange ? Colors.redAccent : const Color(0xFF065F46)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Provider.of<ThemeProvider>(context, listen: false).cardBgSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Provider.of<ThemeProvider>(context, listen: false).borderCol),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Color(0xFF4F46E5), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _pickupAddress,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: Provider.of<ThemeProvider>(context, listen: false).textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onConfirmStep1,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(lang.isTamil ? 'கடையின் இடத்தை உறுதிப்படுத்துக' : lang.isTanglish ? 'SHOP LOCATION CONFIRM PANNUNGA' : 'CONFIRM SHOP LOCATION', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
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
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2: ENTER MANDATORY SHOP DETAILS (RESPONSIVE VIEWPORT FIT)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep2ShopDetailsForm(CustomerLanguageProvider lang) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = theme.isDarkMode;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pinned Shop Address Summary Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? theme.borderCol : const Color(0xFF4F46E5).withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.location_on_rounded, color: Color(0xFF4F46E5), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.isTamil ? 'தேர்வு செய்யப்பட்ட கடை இடம்' : 'PINNED SHOP LOCATION',
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5)),
                            ),
                            const SizedBox(height: 2),
                            Text(_pickupAddress, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _currentStep = 1),
                        child: Text(
                          lang.isTamil ? 'மாற்றுக' : 'Change Pin',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  lang.isTamil ? 'கடை விவரங்களை உள்ளிடவும்' : 'ENTER SHOP / STORE DETAILS',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: theme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  lang.isTamil
                      ? 'ரைடர் கடையை எளிதில் கண்டறிய சரியான விவரங்களை குறிப்பிடவும்.'
                      : 'Please provide clear details so our delivery rider can easily find the exact shop.',
                  style: GoogleFonts.outfit(fontSize: 11, color: theme.textSecondary),
                ),
                const SizedBox(height: 14),

                _buildFormInputField(
                  controller: _shopNameCtrl,
                  label: lang.isTamil
                      ? 'கடையின் பெயர் *'
                      : lang.isTanglish
                          ? 'Kadai Peyar (Shop Name) *'
                          : 'Store / Shop Name *',
                  hint: '',
                  icon: Icons.storefront_rounded,
                ),
                const SizedBox(height: 12),

                _buildFormInputField(
                  controller: _shopStreetCtrl,
                  label: lang.isTamil
                      ? 'தெரு / பகுதி / மார்க்கெட் பெயர் *'
                      : lang.isTanglish
                          ? 'Street / Area / Market Name *'
                          : 'Street / Area / Market Name *',
                  hint: '',
                  icon: Icons.add_road_rounded,
                ),
                const SizedBox(height: 12),

                _buildFormInputField(
                  controller: _shopLandmarkCtrl,
                  label: lang.isTamil
                      ? 'அடையாளக் குறி (Landmark) *'
                      : lang.isTanglish
                          ? 'Shop Landmark *'
                          : 'Shop Landmark / Nearby Spot *',
                  hint: '',
                  icon: Icons.near_me_rounded,
                ),
                const SizedBox(height: 12),

                _buildFormInputField(
                  controller: _shopPhoneCtrl,
                  label: lang.isTamil
                      ? 'கடை தொடர்பு எண் (விருப்பத்தேர்வு)'
                      : lang.isTanglish
                          ? 'Shop Phone (Optional)'
                          : 'Shop Contact Phone (Optional)',
                  hint: '',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),

        // Sticky Bottom Navigation Action Bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: theme.cardBg,
            border: Border(top: BorderSide(color: theme.borderCol)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06), blurRadius: 10, offset: const Offset(0, -4)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _onConfirmStep2,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(lang.isTamil ? 'அடுத்து: டெலிவரி இடத்தை தேர்வு செய்க' : lang.isTanglish ? 'NEXT: DROP LOCATION SET PANNUNGA' : 'NEXT: SET DROP LOCATION', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3: SET DROP LOCATION ON GOOGLE MAP (DEFAULTS TO CUSTOMER LOCATION)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep3DropPinMap(CustomerLanguageProvider lang) {
    final auth = Provider.of<AuthProvider>(context);

    return Stack(
      children: [
        FlutterMap(
          mapController: _dropMapController,
          options: MapOptions(
            initialCenter: _dropLocation,
            initialZoom: 18.0,
            minZoom: 3.0,
            maxZoom: 20.0,
            backgroundColor: Provider.of<ThemeProvider>(context, listen: false).mapBg,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
              enableMultiFingerGestureRace: true,
            ),
            onMapReady: () {
              if (mounted) {
                setState(() => _isDropMapReady = true);
                _safeMoveDropMap(_dropLocation, 18.0, animated: false);
              }
            },
            onTap: (tapPosition, point) {
              final quickArea = LocationAccuracyService.resolveKnownArea(point.latitude, point.longitude);
              setState(() {
                _dropLocation = point;
                _dropAddress = quickArea;
              });
              _safeMoveDropMap(point, _dropMapController.camera.zoom, animated: true);
              _recalculateLogisticsAndRange();
              _dropGeocodeDebounce?.cancel();
              _dropGeocodeDebounce = Timer(const Duration(milliseconds: 200), () {
                _reverseGeocodeDropLocation(point);
                _fetchExactRoadDistance();
              });
            },
            onPositionChanged: (position, hasGesture) {
              _dropLocation = position.center;
              if (hasGesture && !_isDraggingDrop) {
                _onDropDragStart();
              }
            },
            onMapEvent: (event) {
              if (event is MapEventMoveEnd && _isDraggingDrop) {
                _onDropDragEnd();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _effectiveTileUrl,
              subdomains: _effectiveTileUrl.contains('google.com')
                  ? const ['0', '1', '2', '3']
                  : const ['a', 'b', 'c', 'd'],
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

        // Search Bar
        Positioned(
          top: 14,
          left: 16,
          right: 76,
          child: _buildSearchBar('Search delivery house, area, street...'),
        ),

        // Center Marker (Interactive Tactile Drop Pin)
        Center(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pinBounceAnim, _pinLiftAnim, _shadowAnim]),
              builder: (context, child) {
                final liftOffset = _pinLiftAnim.value;
                final bounceOffset = (1.0 - _pinBounceAnim.value) * -18.0;
                final totalLift = liftOffset + bounceOffset;

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Precise Ground Target Bullseye Ring
                    Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFF059669),
                            width: 2.5,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF059669),
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
                          width: 24 * _shadowAnim.value,
                          height: 8 * _shadowAnim.value,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                    ),

                    // Floating Drop Pin Head
                    Transform.translate(
                      offset: Offset(0, -32 + totalLift),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.45),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.home_rounded, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  lang.isTamil ? 'டெலிவரி இடத்தை தேர்வு செய்யவும்' : 'PIN DELIVERY DROP POINT',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 60,
                                color: Color(0xFF059669),
                                shadows: [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 12,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 14,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF059669),
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

        // Controls
        Positioned(
          top: 14,
          right: 16,
          child: _buildMapControls(controller: _dropMapController, onGps: _detectLiveGpsForDrop),
        ),

        // Bottom Step 3 Card
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, -6)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 8),

                  // Quick Select Saved Address Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildQuickAddressChip(
                          label: '🎯 Current Live GPS',
                          onTap: _detectLiveGpsForDrop,
                        ),
                        if (auth.addresses.isNotEmpty)
                          ...auth.addresses.map((saved) => _buildQuickAddressChip(
                                label: '${saved.label == "Home" ? "🏠" : saved.label == "Work" ? "💼" : "📍"} ${saved.label}',
                                onTap: () {
                                  if (saved.lat != null && saved.lng != null) {
                                    final target = LatLng(saved.lat!, saved.lng!);
                                    setState(() {
                                      _dropLocation = target;
                                      _dropAddress = saved.address;
                                    });
                                    _safeMoveDropMap(target, 18.0);
                                    _recalculateLogisticsAndRange();
                                    _fetchExactRoadDistance();
                                  }
                                },
                              )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Route Distance & Dynamic Fare Badge
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.two_wheeler_rounded, color: Color(0xFF059669), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _customOrderPrepayDeliveryFee
                                ? '🛵 Route: $_pickupToDropDistanceKm KM  •  Est Delivery Fee: ₹${_calculatedDeliveryFee.toInt()}'
                                : '🛵 Route: $_pickupToDropDistanceKm KM',
                            style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFF065F46)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Provider.of<ThemeProvider>(context, listen: false).cardBgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Provider.of<ThemeProvider>(context, listen: false).borderCol),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.home_rounded, color: Color(0xFF059669), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dropAddress,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: Provider.of<ThemeProvider>(context, listen: false).textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onConfirmStep3,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0xFF059669).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(lang.isTamil ? 'டெலிவரி இடத்தை உறுதிப்படுத்துக' : lang.isTanglish ? 'DROP LOCATION CONFIRM PANNUNGA' : 'CONFIRM DROP LOCATION', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
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
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 4: ENTER MANDATORY DROP ADDRESS DETAILS (OPTIONAL HOUSE NO)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep4DropDetailsForm(CustomerLanguageProvider lang) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = theme.isDarkMode;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pinned Drop Address Summary Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? theme.borderCol : const Color(0xFF059669).withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: const Color(0xFF059669).withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.home_rounded, color: Color(0xFF059669), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.isTamil ? 'டெலிவரி இடம்' : 'DELIVERY LOCATION',
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF059669)),
                            ),
                            const SizedBox(height: 2),
                            Text(_dropAddress, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _currentStep = 3),
                        child: Text(
                          lang.isTamil ? 'மாற்றுக' : 'Change Pin',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  lang.isTamil ? 'டெலிவரி முகவரி விவரங்களை உள்ளிடவும்' : 'ENTER DELIVERY ADDRESS DETAILS',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: theme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  lang.isTamil
                      ? 'துல்லியமான டோர்-டெலிவரிக்கு அடையாளக் குறி அல்லது கட்டிட விவரங்களை குறிப்பிடவும்.'
                      : 'Provide landmark or building details for accurate doorstep delivery.',
                  style: GoogleFonts.outfit(fontSize: 11, color: theme.textSecondary),
                ),
                const SizedBox(height: 14),

                _buildFormInputField(
                  controller: _dropHouseNoCtrl,
                  label: lang.isTamil
                      ? 'வீட்டு எண் / தளம் *'
                      : lang.isTanglish
                          ? 'House / Flat / Floor No. *'
                          : 'House / Flat / Floor No. *',
                  hint: '',
                  icon: Icons.door_front_door_rounded,
                ),
                const SizedBox(height: 12),

                _buildFormInputField(
                  controller: _dropStreetCtrl,
                  label: lang.isTamil
                      ? 'கட்டிடம் / அபார்ட்மெண்ட் / தெருப் பெயர் *'
                      : lang.isTanglish
                          ? 'Building / Apartment / Street Name *'
                          : 'Building / Apartment / Street Name *',
                  hint: '',
                  icon: Icons.location_city_rounded,
                ),
                const SizedBox(height: 12),

                _buildFormInputField(
                  controller: _dropLandmarkCtrl,
                  label: lang.isTamil
                      ? 'அடையாளக் குறி (Landmark) *'
                      : lang.isTanglish
                          ? 'Landmark / Nearby Spot *'
                          : 'Landmark / Nearby Spot *',
                  hint: '',
                  icon: Icons.place_rounded,
                ),
                const SizedBox(height: 14),

                // Receiver Contact Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.isTamil
                          ? 'மற்றொருவருக்கு டெலிவரி செய்ய வேண்டுமா?'
                          : 'DELIVER TO SOMEONE ELSE?',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: theme.textSecondary),
                    ),
                    Switch.adaptive(
                      value: !_isDeliverToMe,
                      activeThumbColor: const Color(0xFF4F46E5),
                      onChanged: (val) => setState(() => _isDeliverToMe = !val),
                    ),
                  ],
                ),

                if (!_isDeliverToMe) ...[
                  const SizedBox(height: 10),
                  _buildFormInputField(
                    controller: _receiverNameCtrl,
                    label: lang.isTamil
                        ? 'பெறுபவர் பெயர் *'
                        : lang.isTanglish
                            ? 'Receiver Name *'
                            : 'Receiver Name *',
                    hint: '',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildFormInputField(
                    controller: _receiverPhoneCtrl,
                    label: lang.isTamil
                        ? 'பெறுபவர் மொபைல் எண் *'
                        : lang.isTanglish
                            ? 'Receiver Mobile Number *'
                            : 'Receiver Phone Number *',
                    hint: '',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ],
            ),
          ),
        ),

        // Sticky Bottom Navigation Action Bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: theme.cardBg,
            border: Border(top: BorderSide(color: theme.borderCol)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06), blurRadius: 10, offset: const Offset(0, -4)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _onConfirmStep4,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: const Color(0xFF059669).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(lang.isTamil ? 'அடுத்து: பொருட்கள் & கட்டணம்' : lang.isTanglish ? 'NEXT: ADD ITEMS & FARE' : 'NEXT: ADD ITEMS & FARE', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 5: ITEMS, TRANSPARENT FARE BREAKDOWN & SUBMIT (RESPONSIVE VIEWPORT FIT)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep5ItemsAndFare(CustomerLanguageProvider lang) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = theme.isDarkMode;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── FULL ROUTE SUMMARY BOX (PICKUP ➔ DROP) ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? theme.borderCol : const Color(0xFF4F46E5).withValues(alpha: 0.18)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Pickup Store Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.storefront_rounded, color: Color(0xFF4F46E5), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                                      child: Text(lang.isTamil ? 'கடையின் இடம்' : 'PICKUP SHOP', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5), letterSpacing: 0.5)),
                                    ),
                                    if (_shopPhoneCtrl.text.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text('• ${_shopPhoneCtrl.text}', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: theme.textSecondary)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _shopNameCtrl.text.isNotEmpty ? _shopNameCtrl.text : 'Custom Pinned Shop',
                                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: theme.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _shopStreetCtrl.text.isNotEmpty ? '${_shopStreetCtrl.text}, $_pickupAddress' : _pickupAddress,
                                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() => _currentStep = 2),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 4),
                                  Text('Edit', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Connecting Route Badge
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const SizedBox(width: 15),
                            Container(width: 2, height: 26, color: Colors.grey.shade300),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.directions_bike_rounded, size: 13, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Route: $_pickupToDropDistanceKm KM',
                                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF166534)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Delivery Drop Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on_rounded, color: Color(0xFF059669), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                                      child: Text(lang.isTamil ? 'டெலிவரி இடம்' : 'DELIVER TO', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF059669), letterSpacing: 0.5)),
                                    ),
                                    if (_receiverPhoneCtrl.text.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text('• ${_receiverPhoneCtrl.text}', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: theme.textSecondary)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _receiverNameCtrl.text.isNotEmpty
                                      ? _receiverNameCtrl.text
                                      : (_dropHouseNoCtrl.text.isNotEmpty ? '${_dropHouseNoCtrl.text} ${_dropStreetCtrl.text}' : 'My Delivery Address'),
                                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: theme.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_dropHouseNoCtrl.text.isNotEmpty ? "${_dropHouseNoCtrl.text}, " : ""}${_dropStreetCtrl.text.isNotEmpty ? "${_dropStreetCtrl.text}, " : ""}$_dropAddress',
                                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() => _currentStep = 4),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF059669)),
                                  const SizedBox(width: 4),
                                  Text('Edit', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFF059669))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── ORDER TYPE TABS (TEXT vs PHOTO) ──────────────────────────────
                Text(
                  lang.isTamil ? 'எவ்வாறு ஆர்டர் செய்ய விரும்புகிறீர்கள்?' : 'HOW DO YOU WANT TO ORDER?',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: theme.textSecondary),
                ),
                const SizedBox(height: 6),

                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.cardBgSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.borderCol),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMode = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedMode == 0 ? theme.cardBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedMode == 0
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.format_list_bulleted_rounded,
                                    size: 16, color: _selectedMode == 0 ? const Color(0xFF4F46E5) : Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(
                                  lang.isTamil ? 'பட்டியல்' : 'TEXT LIST',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: _selectedMode == 0 ? const Color(0xFF4F46E5) : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMode = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedMode == 1 ? theme.cardBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedMode == 1
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_camera_rounded,
                                    size: 16, color: _selectedMode == 1 ? const Color(0xFF4F46E5) : Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(
                                  lang.isTamil ? 'புகைப்படம்' : 'PHOTO UPLOAD',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: _selectedMode == 1 ? const Color(0xFF4F46E5) : Colors.grey.shade600,
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
                const SizedBox(height: 14),

                // ── MODE CONTENT ──────────────────────────────────────────────────
                if (_selectedMode == 0) _buildTextModeContent() else _buildPhotoModeContent(),

                const SizedBox(height: 16),

                // ── DELIVERY PREFERENCES (QUICK TAGS) ─────────────────────────────
                Text(
                  lang.isTamil ? 'டெலிவரி விருப்பம்' : 'DELIVERY PREFERENCE',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: theme.textSecondary),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildDeliveryTagChip('📞 Call on Arrival'),
                      _buildDeliveryTagChip(lang.isTamil ? '🚪 வாசலில் வைக்கவும்' : '🚪 Leave at Door'),
                      _buildDeliveryTagChip(lang.isTamil ? '🔔 பெல் அடிக்க வேண்டாம்' : '🔔 Do Not Ring Bell'),
                      _buildDeliveryTagChip(lang.isTamil ? '🤝 கையில் ஒப்படைக்கவும்' : '🤝 Direct Handover'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── SPECIAL INSTRUCTIONS / NOTES ──────────────────────────────────
                Text(
                  lang.isTamil ? 'கூடுதல் குறிப்புகள் (விருப்பத்தேர்வு)' : 'SPECIAL INSTRUCTIONS / NOTES (OPTIONAL)',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: theme.textSecondary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: lang.isTamil ? 'ரைடருக்கான கூடுதல் குறிப்புகள்...' : 'Special instructions for rider...',
                    hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: theme.textSecondary),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.borderCol)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.borderCol)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8)),
                    filled: true,
                    fillColor: theme.cardBg,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary),
                ),
                const SizedBox(height: 16),

                // ── TRANSPARENT DELIVERY FARE BREAKDOWN CARD (Only shown when prepay is ON) ──
                if (_customOrderPrepayDeliveryFee) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.borderCol),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.02), blurRadius: 8)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(lang.isTamil ? 'டெலிவரி கட்டண விவரம்' : 'DELIVERY FEE BREAKDOWN', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.grey.shade600)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                              child: Text(lang.isTamil ? 'தூரம்: $_pickupToDropDistanceKm KM' : 'Route: $_pickupToDropDistanceKm KM', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildFareRow(lang.isTamil ? 'அடிப்படை கட்டணம் (முதல் ${_customOrderBaseKm.toStringAsFixed(0)} KM)' : 'Base Delivery Fee (First ${_customOrderBaseKm.toStringAsFixed(0)} KM)', '₹${_baseDeliveryPart.toInt()}'),
                        if (_extraKmFeePart > 0)
                          _buildFareRow(lang.isTamil ? 'கூடுதல் தூரக் கட்டணம்' : 'Extra Distance Fee (${(_pickupToDropDistanceKm - _customOrderBaseKm).toStringAsFixed(1)} KM @ ₹${_customOrderPerKmRate.toInt()}/KM)', '₹${_extraKmFeePart.toInt()}'),
                        if (_customOrderHandlingFee > 0)
                          _buildFareRow(lang.isTamil ? 'கூடுதல் கையாளுதல் கட்டணம்' : 'Additional Handling Charge', '₹${_customOrderHandlingFee.toInt()}'),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(lang.isTamil ? 'மொத்த டெலிவரி கட்டணம்' : 'Total Delivery Fee', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w900, color: theme.textPrimary)),
                            Text('₹${_calculatedDeliveryFee.toInt()}', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── HOW PAYMENT WORKS INFO CARD ───────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _customOrderPrepayDeliveryFee
                                  ? (lang.isTamil ? 'டெலிவரி கட்டணம் செலுத்தி உறுதி செய்யவும்' : 'Pay Delivery Fee Upfront & Confirm')
                                  : (lang.isTamil ? 'பில் சரிபார்த்த பின் செலுத்தவும்' : 'Pay After Rider Bill Verification'),
                              style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _customOrderPrepayDeliveryFee
                                  ? (lang.isTamil
                                      ? 'ஆர்டரை அனுப்ப டெலிவரி கட்டணம் (₹${_calculatedDeliveryFee.toInt()}) மட்டும் செலுத்தவும். ரைடர் கடையிலிருந்து பில் Quote அனுப்பிய பின் பொருட்களுக்கான தொகையை செலுத்தலாம்.'
                                      : 'Pay delivery fee (₹${_calculatedDeliveryFee.toInt()}) now to dispatch order. Item cost will be paid after rider uploads the shop bill quote.')
                                  : (lang.isTamil
                                      ? 'இப்போது கட்டணம் தேவையில்லை. ரைடர் கடைக்கு சென்று பொருட்களை சரிபார்த்து பில் அனுப்பிய பின் பணம் செலுத்தலாம்.'
                                      : 'No payment needed now. Rider will visit the shop, verify items, and send a bill quote. You can pay after the quote is received.'),
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Sticky Bottom Submit Bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: theme.cardBg,
            border: Border(top: BorderSide(color: theme.borderCol)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06), blurRadius: 10, offset: const Offset(0, -4)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _onPlaceOrderPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_customOrderPrepayDeliveryFee ? Icons.payment_rounded : Icons.shopping_bag_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _customOrderPrepayDeliveryFee
                                ? (lang.isTamil
                                    ? 'டெலிவரி கட்டணம் (₹${_calculatedDeliveryFee.toInt()}) செலுத்தி ஆர்டர் செய்க'
                                    : 'PAY DELIVERY FEE (₹${_calculatedDeliveryFee.toInt()}) & PLACE ORDER')
                                : (lang.isTamil
                                    ? 'பிக்-அப் ஆர்டர் செய்க'
                                    : 'PLACE PICKUP ORDER'),
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFareRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600))),
          Text(value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: Provider.of<ThemeProvider>(context, listen: false).textPrimary)),
        ],
      ),
    );
  }

  String _capitalizeWords(String text) {
    if (text.trim().isEmpty) return text.trim();
    return text.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1) : '');
    }).join(' ');
  }

  Widget _buildFormInputField({
    required TextEditingController controller,
    required String label,
    String hint = '',
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = theme.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: theme.textPrimary),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: theme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.borderCol),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: hint.isNotEmpty ? hint : null,
              hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: theme.textSecondary),
              prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 19),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.borderCol)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.borderCol)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8)),
              filled: true,
              fillColor: theme.cardBg,
            ),
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryTagChip(String label) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isSelected = _selectedDeliveryTag == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedDeliveryTag = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4F46E5) : theme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : theme.borderCol),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : theme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddressChip({required String label, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5)),
          ),
        ),
      ),
    );
  }

  void _addItemFromInput() {
    final rawName = _itemNameCtrl.text.trim();
    final rawQty = _itemQtyCtrl.text.trim().isEmpty ? '1' : _itemQtyCtrl.text.trim();
    if (rawName.isNotEmpty) {
      final formattedName = _capitalizeWords(rawName);
      setState(() {
        _shoppingItems.add({'name': formattedName, 'qty': rawQty});
        _itemNameCtrl.clear();
        _itemQtyCtrl.clear();
      });
      HapticFeedback.lightImpact();
      // Keep focus directly on item name so user can immediately type the next item
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _itemNameFocusNode.requestFocus();
        }
      });
    }
  }

  void _showEditItemDialog(int index) {
    final lang = Provider.of<CustomerLanguageProvider>(context, listen: false);
    final item = _shoppingItems[index];
    final editNameCtrl = TextEditingController(text: item['name'] ?? '');
    final editQtyCtrl = TextEditingController(text: item['qty'] ?? '1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 24),
        decoration: BoxDecoration(
          color: Provider.of<ThemeProvider>(context, listen: false).cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 10),
                Text('Edit Item Details', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Provider.of<ThemeProvider>(context, listen: false).textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            Text('ITEM NAME', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Provider.of<ThemeProvider>(context, listen: false).textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            TextField(
              controller: editNameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: lang.isTamil ? 'பொருளின் பெயர்' : 'Item name',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Text('QUANTITY / UNIT', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Provider.of<ThemeProvider>(context, listen: false).textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            TextField(
              controller: editQtyCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: lang.isTamil ? 'அளவு' : 'Qty',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(modalCtx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey.shade700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final rawName = editNameCtrl.text.trim();
                      final rawQty = editQtyCtrl.text.trim().isEmpty ? '1' : editQtyCtrl.text.trim();
                      if (rawName.isNotEmpty) {
                        final formattedName = _capitalizeWords(rawName);
                        setState(() {
                          _shoppingItems[index] = {'name': formattedName, 'qty': rawQty};
                        });
                        HapticFeedback.lightImpact();
                        Navigator.pop(modalCtx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('Save Changes', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextModeContent() {
    final lang = Provider.of<CustomerLanguageProvider>(context, listen: false);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = theme.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.borderCol),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.isTamil ? 'வாங்க வேண்டிய பொருட்கள்' : 'Add Items to Buy',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: theme.textPrimary),
              ),
              if (_shoppingItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                  child: Text('${_shoppingItems.length} items', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF059669))),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _itemNameCtrl,
                  focusNode: _itemNameFocusNode,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: lang.isTamil ? 'பொருளின் பெயர்' : 'Item name',
                    hintStyle: GoogleFonts.outfit(fontSize: 12, color: theme.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.borderCol)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.borderCol)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8)),
                    filled: true,
                    fillColor: theme.cardBgSecondary,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary),
                  onSubmitted: (_) => _addItemFromInput(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _itemQtyCtrl,
                  focusNode: _itemQtyFocusNode,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: lang.isTamil ? 'அளவு' : 'Qty',
                    hintStyle: GoogleFonts.outfit(fontSize: 11.5, color: theme.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.borderCol)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.borderCol)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8)),
                    filled: true,
                    fillColor: theme.cardBgSecondary,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary),
                  onSubmitted: (_) => _addItemFromInput(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addItemFromInput,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // Emerald Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Icon(Icons.check_rounded, size: 22, color: Colors.white),
              ),
            ],
          ),

          if (_shoppingItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _shoppingItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final item = _shoppingItems[idx];
                final String qtyStr = item['qty'] ?? '1';
                final int? parsedQty = int.tryParse(qtyStr);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.cardBgSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.borderCol),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, size: 14, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => _showEditItemDialog(idx),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? '',
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textPrimary,
                                ),
                              ),
                              Text(
                                'Qty: $qtyStr • Tap to edit',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: theme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Quantity Stepper +/-
                      if (parsedQty != null) ...[
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (parsedQty > 1) {
                              setState(() => _shoppingItems[idx]['qty'] = '${parsedQty - 1}');
                            } else {
                              setState(() => _shoppingItems.removeAt(idx));
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: theme.cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.borderCol)),
                            child: Icon(Icons.remove_rounded, size: 16, color: theme.textPrimary),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('$parsedQty', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
                        ),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _shoppingItems[idx]['qty'] = '${parsedQty + 1}');
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: theme.cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.borderCol)),
                            child: Icon(Icons.add_rounded, size: 16, color: theme.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Edit Button ✏️
                      InkWell(
                        onTap: () => _showEditItemDialog(idx),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.edit_outlined, color: Color(0xFF10B981), size: 16),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Delete Button 🗑️
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _shoppingItems.removeAt(idx));
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 16),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoModeContent() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = theme.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.borderCol),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.02), blurRadius: 8)],
      ),
      child: Column(
        children: [
          if (_selectedPhoto != null) ...[
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(_selectedPhoto!, height: 160, width: double.infinity, fit: BoxFit.cover),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedPhoto = null),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4F46E5), size: 18),
                  label: Text('Camera', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF4F46E5), size: 18),
                  label: Text('Gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── HELPER SEARCH & MAP CONTROLS ──────────────────────────────────────────
  Widget _buildSearchBar(String hint) {
    final theme = Provider.of<ThemeProvider>(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: theme.isDark ? theme.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: theme.isDark ? Border.all(color: theme.borderCol) : null,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Color(0xFF4F46E5), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5))),
                          )
                        : _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18, color: theme.textSecondary),
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
              color: theme.isDark ? theme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.borderCol),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: theme.borderCol),
              itemBuilder: (context, idx) {
                final item = _searchResults[idx];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: Color(0xFF4F46E5), size: 18),
                  title: Text(
                    item['display_name'] ?? '',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectSearchResult(item),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMapControls({required MapController controller, required VoidCallback onGps}) {
    final theme = Provider.of<ThemeProvider>(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // GPS Floating Action Button
        Material(
          color: theme.isDark ? theme.cardBg : Colors.white,
          shape: const CircleBorder(),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              onGps();
            },
            customBorder: const CircleBorder(),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              child: const Icon(Icons.my_location_rounded, color: Color(0xFF4F46E5), size: 22),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Zoom In & Out Card
        Material(
          color: theme.isDark ? theme.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(24),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  try {
                    final currentZoom = controller.camera.zoom;
                    final targetZoom = (currentZoom + 1.2).clamp(3.0, 20.0);
                    controller.move(controller.camera.center, targetZoom);
                  } catch (e) {
                    debugPrint('Zoom in error: $e');
                  }
                },
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Container(
                  width: 46,
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(Icons.add_rounded, color: theme.textPrimary, size: 24),
                ),
              ),
              Container(height: 1, width: 24, color: theme.borderCol),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  try {
                    final currentZoom = controller.camera.zoom;
                    final targetZoom = (currentZoom - 1.2).clamp(3.0, 20.0);
                    controller.move(controller.camera.center, targetZoom);
                  } catch (e) {
                    debugPrint('Zoom out error: $e');
                  }
                },
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: Container(
                  width: 46,
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(Icons.remove_rounded, color: theme.textPrimary, size: 24),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Layer Switcher
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
          child: Material(
            color: theme.isDark ? theme.cardBg : Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              child: const Icon(Icons.layers_rounded, color: Color(0xFF4F46E5), size: 22),
            ),
          ),
        ),
      ],
    );
  }
}
