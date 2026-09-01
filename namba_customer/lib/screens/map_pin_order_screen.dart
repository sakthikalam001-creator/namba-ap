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
import '../providers/order_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/location_accuracy_service.dart';
import 'order_details_screen.dart';

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
  LatLng _pickupLocation = const LatLng(11.3410, 77.7172);
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

  // Map Tile Style (Ultra High-Detail Google Maps Vector with Places, Landmarks & Retina 2x)
  String _currentMapStyleUrl = 'https://mt{s}.google.com/vt/lyrs=m,traffic&hl=en&gl=IN&x={x}&y={y}&z={z}&scale=2';

  // Admin Custom Map Pin Order Settings (KM-based pricing)
  double _customOrderBaseFee = 25.0;
  double _customOrderBaseKm = 2.0;
  double _customOrderPerKmRate = 10.0;
  double _customOrderHandlingFee = 5.0;
  bool _customOrderPrepayDeliveryFee = false; // Loaded dynamically from Admin Settings
  double _maxServiceRadiusKm = 20.0;
  LatLng _serviceCenter = const LatLng(11.3410, 77.7172);

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

  @override
  void initState() {
    super.initState();

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
            setState(() {
              _pickupLocation = liveCenter;
              if (_dropAddress == "Selected Delivery Location") {
                _dropLocation = liveCenter;
              }
            });
            _safeMovePickupMap(liveCenter, 18.8);
            _reverseGeocodePickupLocation(liveCenter);
          }
        },
      );
      if (pos != null && mounted) {
        final liveCenter = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _pickupLocation = liveCenter;
          if (_dropAddress == "Selected Delivery Location") {
            _dropLocation = liveCenter;
          }
        });
        _safeMovePickupMap(liveCenter, 18.8);
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
            setState(() {
              _dropLocation = liveCenter;
            });
            _safeMoveDropMap(liveCenter, 18.8);
            _reverseGeocodeDropLocation(liveCenter);
          }
        },
      );
      if (pos != null && mounted) {
        final liveCenter = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _dropLocation = liveCenter;
        });
        _safeMoveDropMap(liveCenter, 18.8);
        _reverseGeocodeDropLocation(liveCenter);
      }
    } catch (_) {}
  }

  void _animatedMovePickupMap(LatLng destLocation, double destZoom) {
    if (!_isPickupMapReady || !mounted) return;
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
      duration: const Duration(milliseconds: 600),
    );
    final animation = CurvedAnimation(parent: animCtrl, curve: Curves.fastOutSlowIn);

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
        animCtrl.dispose();
      }
    });

    animCtrl.forward();
  }

  void _animatedMoveDropMap(LatLng destLocation, double destZoom) {
    if (!_isDropMapReady || !mounted) return;
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
      duration: const Duration(milliseconds: 600),
    );
    final animation = CurvedAnimation(parent: animCtrl, curve: Curves.fastOutSlowIn);

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
      final url = Uri.parse('${CustomerApiService.baseUrl}/admin/settings/public');
      final res = await http.get(url).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (data != null) {
          final double maxRadius = (data['customOrderMaxRadiusKm'] ?? data['maxServiceRadiusKm'] ?? 20.0).toDouble();
          final double centerLat = (data['serviceCenterLat'] ?? 11.3410).toDouble();
          final double centerLng = (data['serviceCenterLng'] ?? 77.7172).toDouble();
          final double baseFee = (data['customOrderBaseFee'] ?? 25.0).toDouble();
          final double baseKm = (data['customOrderBaseKm'] ?? 2.0).toDouble();
          final double perKmRate = (data['customOrderPerKmRate'] ?? 10.0).toDouble();
          final double handlingFee = (data['customOrderHandlingFee'] ?? 5.0).toDouble();
          final bool prepayDeliveryFee = data['customOrderPrepayDeliveryFee'] ?? false;

          if (mounted) {
            setState(() {
              _maxServiceRadiusKm = maxRadius > 0 ? maxRadius : 20.0;
              _serviceCenter = LatLng(centerLat, centerLng);
              _customOrderBaseFee = baseFee;
              _customOrderBaseKm = baseKm;
              _customOrderPerKmRate = perKmRate;
              _customOrderHandlingFee = handlingFee;
              _customOrderPrepayDeliveryFee = prepayDeliveryFee;
            });
            _recalculateLogisticsAndRange();
          }
        }
      }
    } catch (_) {}
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
    // 1. Distance from Hub to Pickup Store using accurate WGS-84 formula
    final double meterDistCenter = Geolocator.distanceBetween(
      _serviceCenter.latitude,
      _serviceCenter.longitude,
      _pickupLocation.latitude,
      _pickupLocation.longitude,
    );
    _distanceFromCenterKm = double.parse(((meterDistCenter * 1.25) / 1000.0).toStringAsFixed(1));
    _isOutOfRange = _distanceFromCenterKm > _maxServiceRadiusKm;

    // 2. Direct Urban Road Distance between Pickup Store and Drop Location
    final double meterDistRoute = Geolocator.distanceBetween(
      _pickupLocation.latitude,
      _pickupLocation.longitude,
      _dropLocation.latitude,
      _dropLocation.longitude,
    );
    final double kmRoute = (meterDistRoute * 1.25) / 1000.0;
    _pickupToDropDistanceKm = double.parse(kmRoute.toStringAsFixed(1));

    // Dynamic Admin KM Logistics Fee Rule:
    _baseDeliveryPart = _customOrderBaseFee;
    if (_pickupToDropDistanceKm <= _customOrderBaseKm) {
      _extraKmFeePart = 0.0;
    } else {
      _extraKmFeePart = ((_pickupToDropDistanceKm - _customOrderBaseKm) * _customOrderPerKmRate).roundToDouble();
    }
    _calculatedDeliveryFee = _baseDeliveryPart + _extraKmFeePart + _customOrderHandlingFee;
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
          _safeMovePickupMap(target, 19.0);
        } else if (_currentStep == 3) {
          _dropLocation = target;
          _dropAddress = item['display_name'] ?? _dropAddress;
          _safeMoveDropMap(target, 19.0);
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
    if (_isOutOfRange) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '❌ Out of Service Area! Pinned pickup store is $_distanceFromCenterKm KM away (Max allowed: ${_maxServiceRadiusKm.toStringAsFixed(0)} KM).'),
          backgroundColor: Colors.redAccent,
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
    final name = _shopNameCtrl.text.trim();
    final street = _shopStreetCtrl.text.trim();
    final landmark = _shopLandmarkCtrl.text.trim();

    if (name.isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack('Please enter Store / Shop Name (கடையின் பெயர்)');
      return;
    }
    if (street.isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack('Please enter Shop Street / Area / Market Name (தெரு / பகுதி பெயர்)');
      return;
    }
    if (landmark.isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack('Please enter Shop Landmark (அடையாளக் குறி / Near bus stand, opp bank)');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 3;
      _searchCtrl.clear();
      _searchResults = [];
    });
    _safeMoveDropMap(_dropLocation, 19.0);
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
    final street = _dropStreetCtrl.text.trim();
    final landmark = _dropLandmarkCtrl.text.trim();
    final recName = _receiverNameCtrl.text.trim();
    final recPhone = _receiverPhoneCtrl.text.trim();

    if (street.isEmpty && _dropAddress.isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack('Please enter Building / Apartment / Street Name (தெரு / கட்டடம்)');
      return;
    }
    if (landmark.isEmpty) {
      HapticFeedback.vibrate();
      _showErrorSnack('Please enter Landmark (அடையாளக் குறி / Near place)');
      return;
    }
    if (!_isDeliverToMe && (recName.isEmpty || recPhone.isEmpty)) {
      HapticFeedback.vibrate();
      _showErrorSnack('Please enter Recipient Name and Phone Number');
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                        Text('Pay Delivery Fee', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B))),
                        Text('டெலிவரி கட்டணத்தை செலுத்தி ஆர்டரை உறுதிசெய்யவும்', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
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
                        'Rider கடைக்குச் சென்று பொருட்களைப் பார்த்து பில் Quote அனுப்பியவுடன், பொருட்களுக்கான தொகையை (Item Bill) Pay செய்யலாம்.',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text('SELECT PAYMENT METHOD (UPI / ONLINE)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.5)),
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
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF1E1B4B)),
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
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            _currentStep == 1
                ? '📍 Step 1: Pin Shop Location'
                : _currentStep == 2
                    ? '🏪 Step 2: Shop Details'
                    : _currentStep == 3
                        ? '🏠 Step 3: Set Drop Location'
                        : _currentStep == 4
                            ? '📝 Step 4: Drop Address Details'
                            : '🛍️ Step 5: Order Items & Fare',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E1B4B)),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1E1B4B), size: 18),
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
            child: _build5StepProgressBar(),
          ),
        ),
        body: _currentStep == 1
            ? _buildStep1ShopPinMap()
            : _currentStep == 2
                ? _buildStep2ShopDetailsForm()
                : _currentStep == 3
                    ? _buildStep3DropPinMap()
                    : _currentStep == 4
                        ? _buildStep4DropDetailsForm()
                        : _buildStep5ItemsAndFare(),
      ),
    );
  }

  // ── 5-STEP PROGRESS BAR ───────────────────────────────────────────────────
  Widget _build5StepProgressBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStepChip(step: 1, label: '1. Shop Pin', icon: Icons.location_on_rounded),
            _buildStepDivider(1),
            _buildStepChip(step: 2, label: '2. Shop Info', icon: Icons.storefront_rounded),
            _buildStepDivider(2),
            _buildStepChip(step: 3, label: '3. Drop Pin', icon: Icons.my_location_rounded),
            _buildStepDivider(3),
            _buildStepChip(step: 4, label: '4. Drop Info', icon: Icons.home_rounded),
            _buildStepDivider(4),
            _buildStepChip(step: 5, label: '5. Items & Fare', icon: Icons.shopping_bag_rounded),
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
  Widget _buildStep1ShopPinMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _pickupMapController,
          options: MapOptions(
            initialCenter: _pickupLocation,
            initialZoom: 18.8,
            minZoom: 3.0,
            maxZoom: 20.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
              enableMultiFingerGestureRace: true,
            ),
            onMapReady: () {
              if (mounted) {
                setState(() => _isPickupMapReady = true);
                _safeMovePickupMap(_pickupLocation, 19.0, animated: true);
              }
            },
            onTap: (tapPosition, point) {
              setState(() => _pickupLocation = point);
              _safeMovePickupMap(point, 19.0, animated: true);
              _reverseGeocodePickupLocation(point);
              _fetchExactRoadDistance();
            },
            onPositionChanged: (position, hasGesture) {
              if (hasGesture) {
                _pickupLocation = position.center;
                _recalculateLogisticsAndRange();
              }
            },
            onMapEvent: (event) {
              if (event is MapEventMoveEnd) {
                if (_pickupMapController.camera.zoom < 18.5) {
                  _safeMovePickupMap(_pickupLocation, 19.0, animated: true);
                }
                _reverseGeocodePickupLocation(_pickupLocation);
                _fetchExactRoadDistance();
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

        // Search Bar
        Positioned(
          top: 14,
          left: 16,
          right: 76,
          child: _buildSearchBar('Search shop name, street, market...'),
        ),

        // Center Marker (Location Pin)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 38),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                        _isOutOfRange ? 'OUT OF SERVICE RADIUS' : 'PIN SHOP LOCATION',
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
                const SizedBox(height: 4),
                Icon(
                  Icons.location_on_rounded,
                  size: 52,
                  color: _isOutOfRange ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ],
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
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STEP 1: PICKUP SHOP LOCATION',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.grey.shade500),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isOutOfRange ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isOutOfRange ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          _isOutOfRange ? 'OUT OF RANGE' : '$_distanceFromCenterKm KM from Hub',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: _isOutOfRange ? Colors.redAccent : const Color(0xFF065F46)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Color(0xFF4F46E5), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _pickupAddress,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E1B4B)),
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
                          Text('CONFIRM SHOP LOCATION', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
  Widget _buildStep2ShopDetailsForm() {
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
                            Text('PINNED SHOP LOCATION', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
                            const SizedBox(height: 2),
                            Text(_pickupAddress, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E1B4B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _currentStep = 1),
                        child: Text('Change Pin', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'ENTER SHOP / STORE DETAILS',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: const Color(0xFF1E1B4B)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Please provide clear details so our delivery rider can easily find the exact shop.',
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),

                _buildFormInputField(
                  controller: _shopNameCtrl,
                  label: 'Store / Shop Name (கடையின் பெயர்) *',
                  hint: 'e.g. Sri Krishna Sweets / Annapoorna Bakery',
                  icon: Icons.storefront_rounded,
                ),
                const SizedBox(height: 12),

                _buildFormInputField(
                  controller: _shopStreetCtrl,
                  label: 'Street / Area / Market Name (தெரு / பகுதி) *',
                  hint: 'e.g. Brough Road, Main Bazaar',
                  icon: Icons.add_road_rounded,
                ),
                const SizedBox(height: 12),

                _buildFormInputField(
                  controller: _shopLandmarkCtrl,
                  label: 'Shop Landmark / Nearby Spot (அடையாளக் குறி) *',
                  hint: 'e.g. Near Bus Stand, Opp SBI Bank, 2nd Floor',
                  icon: Icons.near_me_rounded,
                ),
                const SizedBox(height: 12),

                _buildFormInputField(
                  controller: _shopPhoneCtrl,
                  label: 'Shop Contact Phone (Optional - கடை எண்)',
                  hint: 'e.g. 9876543210',
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
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4)),
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
                    Text('NEXT: SET DROP LOCATION', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
  Widget _buildStep3DropPinMap() {
    final auth = Provider.of<AuthProvider>(context);

    return Stack(
      children: [
        FlutterMap(
          mapController: _dropMapController,
          options: MapOptions(
            initialCenter: _dropLocation,
            initialZoom: 18.8,
            minZoom: 3.0,
            maxZoom: 20.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
              enableMultiFingerGestureRace: true,
            ),
            onMapReady: () {
              if (mounted) {
                setState(() => _isDropMapReady = true);
                _safeMoveDropMap(_dropLocation, 19.0, animated: true);
              }
            },
            onTap: (tapPosition, point) {
              setState(() => _dropLocation = point);
              _safeMoveDropMap(point, 19.0, animated: true);
              _reverseGeocodeDropLocation(point);
              _fetchExactRoadDistance();
            },
            onPositionChanged: (position, hasGesture) {
              if (hasGesture) {
                _dropLocation = position.center;
                _recalculateLogisticsAndRange();
              }
            },
            onMapEvent: (event) {
              if (event is MapEventMoveEnd) {
                if (_dropMapController.camera.zoom < 18.5) {
                  _safeMoveDropMap(_dropLocation, 19.0, animated: true);
                }
                _reverseGeocodeDropLocation(_dropLocation);
                _fetchExactRoadDistance();
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

        // Search Bar
        Positioned(
          top: 14,
          left: 16,
          right: 76,
          child: _buildSearchBar('Search delivery house, area, street...'),
        ),

        // Center Marker (Drop Pin)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 38),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                        'PIN DELIVERY DROP POINT',
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
                const SizedBox(height: 4),
                Icon(
                  Icons.location_on_rounded,
                  size: 52,
                  color: const Color(0xFF059669),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ],
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
                                    _safeMoveDropMap(target, 19.0);
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
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.home_rounded, color: Color(0xFF059669), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dropAddress,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E1B4B)),
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
                          Text('CONFIRM DROP LOCATION', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
  Widget _buildStep4DropDetailsForm() {
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
                            Text('DELIVERY LOCATION', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF059669))),
                            const SizedBox(height: 2),
                            Text(_dropAddress, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E1B4B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _currentStep = 3),
                        child: Text('Change Pin', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'ENTER DELIVERY ADDRESS DETAILS',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: const Color(0xFF1E1B4B)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Provide landmark or building details for accurate doorstep delivery.',
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),

                _buildFormInputField(
                  controller: _dropHouseNoCtrl,
                  label: 'House / Flat / Floor No. (வீட்டு எண் - Optional)',
                  hint: 'e.g. Flat 302, 3rd Floor, Door No. 12/A (Optional)',
                  icon: Icons.door_front_door_rounded,
                ),
                const SizedBox(height: 12),

                _buildFormInputField(
                  controller: _dropStreetCtrl,
                  label: 'Building / Apartment / Street Name (தெரு / கட்டடம்) *',
                  hint: 'e.g. Green Gardens, 4th Cross Street',
                  icon: Icons.location_city_rounded,
                ),
                const SizedBox(height: 12),

                _buildFormInputField(
                  controller: _dropLandmarkCtrl,
                  label: 'Landmark / Nearby Spot (அடையாளக் குறி) *',
                  hint: 'e.g. Opposite Water Tank, Near Vinayagar Temple',
                  icon: Icons.place_rounded,
                ),
                const SizedBox(height: 14),

                // Receiver Contact Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DELIVER TO SOMEONE ELSE?',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.grey.shade600),
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
                    label: 'Receiver Name (பெறுபவர் பெயர்) *',
                    hint: 'e.g. Ramesh Kumar',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildFormInputField(
                    controller: _receiverPhoneCtrl,
                    label: 'Receiver Phone Number (மொபைல் எண்) *',
                    hint: 'e.g. 9876543210',
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
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4)),
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
                    Text('NEXT: ADD ITEMS & FARE', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
  Widget _buildStep5ItemsAndFare() {
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.18)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
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
                                      child: Text('PICKUP SHOP', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5), letterSpacing: 0.5)),
                                    ),
                                    if (_shopPhoneCtrl.text.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text('• ${_shopPhoneCtrl.text}', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _shopNameCtrl.text.isNotEmpty ? _shopNameCtrl.text : 'Custom Pinned Shop',
                                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _shopStreetCtrl.text.isNotEmpty ? '${_shopStreetCtrl.text}, $_pickupAddress' : _pickupAddress,
                                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
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
                                      child: Text('DELIVER TO', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF059669), letterSpacing: 0.5)),
                                    ),
                                    if (_receiverPhoneCtrl.text.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text('• ${_receiverPhoneCtrl.text}', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _receiverNameCtrl.text.isNotEmpty
                                      ? _receiverNameCtrl.text
                                      : (_dropHouseNoCtrl.text.isNotEmpty ? '${_dropHouseNoCtrl.text} ${_dropStreetCtrl.text}' : 'My Delivery Address'),
                                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_dropHouseNoCtrl.text.isNotEmpty ? "${_dropHouseNoCtrl.text}, " : ""}${_dropStreetCtrl.text.isNotEmpty ? "${_dropStreetCtrl.text}, " : ""}$_dropAddress',
                                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
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
                  'HOW DO YOU WANT TO ORDER?',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),

                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMode = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedMode == 0 ? Colors.white : Colors.transparent,
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
                                  'TEXT LIST',
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
                              color: _selectedMode == 1 ? Colors.white : Colors.transparent,
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
                                  'PHOTO UPLOAD',
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
                  'DELIVERY PREFERENCE',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildDeliveryTagChip('📞 Call on Arrival'),
                      _buildDeliveryTagChip('🚪 Leave at Door'),
                      _buildDeliveryTagChip('🔔 Do Not Ring Bell'),
                      _buildDeliveryTagChip('🤝 Direct Handover'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── SPECIAL INSTRUCTIONS / NOTES ──────────────────────────────────
                Text(
                  'SPECIAL INSTRUCTIONS / NOTES (OPTIONAL)',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Please check expiry date, buy fresh items only...',
                    hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                // ── TRANSPARENT DELIVERY FARE BREAKDOWN CARD (Only shown when prepay is ON) ──
                if (_customOrderPrepayDeliveryFee) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('DELIVERY FEE BREAKDOWN', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.grey.shade600)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                              child: Text('Route: $_pickupToDropDistanceKm KM', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildFareRow('Base Delivery Fee (First ${_customOrderBaseKm.toStringAsFixed(0)} KM)', '₹${_baseDeliveryPart.toInt()}'),
                        if (_extraKmFeePart > 0)
                          _buildFareRow('Extra Distance Fee (${(_pickupToDropDistanceKm - _customOrderBaseKm).toStringAsFixed(1)} KM @ ₹${_customOrderPerKmRate.toInt()}/KM)', '₹${_extraKmFeePart.toInt()}'),
                        if (_customOrderHandlingFee > 0)
                          _buildFareRow('Additional Handling Charge', '₹${_customOrderHandlingFee.toInt()}'),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Delivery Fee', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B))),
                            Text('₹${_calculatedDeliveryFee.toInt()}', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
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
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
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
                                  ? 'Pay Delivery Fee Upfront & Confirm'
                                  : 'Pay After Rider Bill Verification',
                              style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, color: const Color(0xFF166534)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _customOrderPrepayDeliveryFee
                                  ? 'Pay delivery fee (₹${_calculatedDeliveryFee.toInt()}) now to dispatch order. Item cost will be paid after rider uploads the shop bill quote.'
                                  : 'No payment needed now. Rider will visit the shop, verify items, and send a bill quote. You can pay after the quote is received.',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF15803D)),
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
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4)),
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
                                ? 'PAY DELIVERY FEE (₹${_calculatedDeliveryFee.toInt()}) & PLACE ORDER'
                                : 'PLACE PICKUP ORDER',
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
          Text(value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1E1B4B))),
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
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1E1B4B)),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
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
              hintText: hint,
              hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 19),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8)),
              filled: true,
              fillColor: Colors.white,
            ),
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E1B4B)),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryTagChip(String label) {
    final isSelected = _selectedDeliveryTag == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedDeliveryTag = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade300),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : const Color(0xFF1E1B4B),
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
    final item = _shoppingItems[index];
    final editNameCtrl = TextEditingController(text: item['name'] ?? '');
    final editQtyCtrl = TextEditingController(text: item['qty'] ?? '1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                Text('Edit Item Details', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B))),
              ],
            ),
            const SizedBox(height: 16),
            Text('ITEM NAME', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            TextField(
              controller: editNameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Mutton Biryani',
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
            Text('QUANTITY / UNIT', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            TextField(
              controller: editQtyCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. 2 or 1kg or 500g',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Items to Buy',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B)),
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
                    hintText: 'Item name (e.g. Mutton Biryani)',
                    hintStyle: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
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
                    hintText: 'Qty (e.g. 2)',
                    hintStyle: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
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
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
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
                                  color: const Color(0xFF1E1B4B),
                                ),
                              ),
                              Text(
                                'Qty: $qtyStr • Tap to edit',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
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
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                            child: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF1E1B4B)),
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
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                            child: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF1E1B4B)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
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
    return Column(
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
              const Icon(Icons.search_rounded, color: Color(0xFF4F46E5), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E1B4B)),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12),
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
                  leading: const Icon(Icons.location_on_outlined, color: Color(0xFF4F46E5), size: 18),
                  title: Text(
                    item['display_name'] ?? '',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // GPS Floating Action Button
        Material(
          color: Colors.white,
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
          color: Colors.white,
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
                  child: const Icon(Icons.add_rounded, color: Color(0xFF0F172A), size: 24),
                ),
              ),
              Container(height: 1, width: 24, color: Colors.grey.shade200),
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
                  child: const Icon(Icons.remove_rounded, color: Color(0xFF0F172A), size: 24),
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
            const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}', child: Text('Google Standard Traffic')),
            const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', child: Text('Google Hybrid Satellite')),
            const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=p&x={x}&y={y}&z={z}', child: Text('Google Terrain View')),
            const PopupMenuItem(value: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', child: Text('OpenStreetMap')),
          ],
          child: Material(
            color: Colors.white,
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
