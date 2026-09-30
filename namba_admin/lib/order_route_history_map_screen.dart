import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderRouteHistoryMapScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderRouteHistoryMapScreen({super.key, required this.order});

  @override
  State<OrderRouteHistoryMapScreen> createState() => _OrderRouteHistoryMapScreenState();
}

class _OrderRouteHistoryMapScreenState extends State<OrderRouteHistoryMapScreen> {
  final MapController _mapController = MapController();
  String _currentMapStyleUrl = 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}';
  bool _isLoadingTrail = true;
  bool _isFetchingRoadRoute = false;
  
  List<LatLng> _trailPoints = [];
  List<LatLng> _roadPolylinePoints = [];
  List<LatLng> _pickupRoadPoints = [];
  
  LatLng? _storePoint;
  LatLng? _destPoint;
  LatLng? _riderLastPoint;
  LatLng? _riderStartPoint;
  
  String _storeName = 'Shop / Store';
  String _storeAddress = 'Pickup Address';
  String _customerName = 'Customer';
  String _customerPhone = '';
  String _deliveryAddress = 'Delivery Address';
  String _driverName = 'Assigned Rider';
  String _driverPhone = '';
  String _driverVehicle = '';
  double _distanceKm = 0.0;
  double _actualKm = 0.0;
  double _riderEarnings = 0.0;
  double _pickupDistanceKm = 0.0;
  double _deliveryDistanceKm = 0.0;
  double _totalTripKm = 0.0;
  double _payableDistanceKm = 0.0;
  bool _includeRiderPickupDistance = false;
  double _driverBaseRatePerKm = 7.0;
  bool _isFetchingPickupRoad = false;
  String? _billPhotoPath;
  String _orderStatus = 'Pending';
  String _orderType = 'Cart';
  String _displayId = '';
  bool _isDriverPaid = false;
  bool _isPayingDriver = false;

  @override
  void initState() {
    super.initState();
    _parseInitialOrderData();
    _fetchFullLocationTrail();
  }

  void _parseInitialOrderData() {
    final o = widget.order;
    _displayId = o['displayId'] ?? o['_id']?.toString().substring(o['_id'].toString().length > 5 ? o['_id'].toString().length - 5 : 0) ?? 'N/A';
    _orderStatus = o['status']?.toString() ?? 'Pending';
    _orderType = o['orderType']?.toString() ?? 'Cart';
    _isDriverPaid = (o['driverPaymentStatus'] ?? '').toString().toLowerCase() == 'paid';
    _distanceKm = double.tryParse(o['distanceKm']?.toString() ?? '0') ?? 0.0;
    _deliveryDistanceKm = _distanceKm;
    _actualKm = double.tryParse(o['actualTravelledKm']?.toString() ?? o['distanceKm']?.toString() ?? '0') ?? _distanceKm;
    final driverEar = double.tryParse(o['driverEarnings']?.toString() ?? '0') ?? 0.0;
    _riderEarnings = driverEar > 0 ? driverEar : (_distanceKm > 0 ? (_distanceKm * 7.0) : 30.0);
    _billPhotoPath = o['billPhotoPath']?.toString();

    final pBreakdown = o['driverPayoutBreakdown'];
    if (pBreakdown is Map && pBreakdown.isNotEmpty) {
      final pKm = double.tryParse(pBreakdown['pickupDistanceKm']?.toString() ?? '');
      if (pKm != null && pKm > 0) _pickupDistanceKm = pKm;

      final dKm = double.tryParse(pBreakdown['tripDistanceKm']?.toString() ?? '');
      if (dKm != null && dKm > 0) {
        _deliveryDistanceKm = dKm;
      } else {
        _deliveryDistanceKm = _distanceKm;
      }
      final tKm = double.tryParse(pBreakdown['totalTripKm']?.toString() ?? '');
      _totalTripKm = tKm ?? (_pickupDistanceKm + _deliveryDistanceKm);
      _payableDistanceKm = _totalTripKm;
      if (pBreakdown['baseRatePerKm'] != null) {
        _driverBaseRatePerKm = double.tryParse(pBreakdown['baseRatePerKm'].toString()) ?? 7.0;
      }
    } else {
      _deliveryDistanceKm = _distanceKm;
      _totalTripKm = _distanceKm;
      _payableDistanceKm = _distanceKm;
    }

    // Customer
    final cust = o['customer'];
    if (cust is Map) {
      _customerName = cust['name'] ?? 'Customer';
      _customerPhone = cust['phone'] ?? '';
    } else {
      _customerName = o['customerName'] ?? 'Customer';
      _customerPhone = o['customerPhone'] ?? '';
    }
    _deliveryAddress = (o['deliveryAddress'] ?? o['deliveryAddressFormatted'] ?? 'Delivery Destination').toString()
        .replaceAll(RegExp(r'\s*\(-?\d+\.\d+,\s*-?\d+\.\d+\)'), '')
        .replaceAll(RegExp(r'^Current Location\s*'), '').trim();

    // Driver
    final drv = o['driver'];
    if (drv is Map) {
      _driverName = drv['name'] ?? 'Assigned Rider';
      _driverPhone = drv['phone'] ?? '';
      _driverVehicle = drv['vehicleNumber'] ?? drv['vehicleType'] ?? '';
    } else {
      _driverName = o['driverName'] ?? 'Assigned Rider';
      _driverPhone = o['driverPhone'] ?? '';
    }

    // Vendor / Store
    final isCustom = o['isCustomStore'] == true || _orderType == 'MapPin' || _orderType == 'map_pin';
    _storeName = isCustom
        ? (o['customStoreName']?.toString().isNotEmpty == true ? o['customStoreName'].toString() : '📍 Pinned Shop')
        : (o['vendor']?['storeName'] ?? 'Store');
    _storeAddress = isCustom
        ? (o['customStoreAddress'] ?? 'Custom Shop Location')
        : (o['vendor']?['address'] ?? 'Store Location');

    // Customer coordinates
    final dCoordsVal = o['deliveryCoordinates'];
    List? dCoords;
    if (dCoordsVal is Map) {
      dCoords = dCoordsVal['coordinates'] as List?;
    } else if (dCoordsVal is List) {
      dCoords = dCoordsVal;
    }
    if (dCoords != null && dCoords.length >= 2) {
      _destPoint = LatLng((dCoords[1] as num).toDouble(), (dCoords[0] as num).toDouble());
    }

    // Store coordinates
    if (o['actualPickupLat'] != null && o['actualPickupLng'] != null) {
      _storePoint = LatLng((o['actualPickupLat'] as num).toDouble(), (o['actualPickupLng'] as num).toDouble());
    } else if (o['pinnedLat'] != null && o['pinnedLng'] != null) {
      _storePoint = LatLng((o['pinnedLat'] as num).toDouble(), (o['pinnedLng'] as num).toDouble());
    } else if (o['vendor']?['location']?['coordinates'] is List && (o['vendor']['location']['coordinates'] as List).length >= 2) {
      final vCoords = o['vendor']['location']['coordinates'] as List;
      _storePoint = LatLng((vCoords[1] as num).toDouble(), (vCoords[0] as num).toDouble());
    }

    // Driver location trail from existing order object
    if (o['driverLocationTrail'] is List && (o['driverLocationTrail'] as List).isNotEmpty) {
      _parseTrailPoints(o['driverLocationTrail'] as List);
    }

    // Fallback straight-line estimations right away
    if (_pickupDistanceKm <= 0 && _riderStartPoint != null && _storePoint != null) {
      final pMeters = const Distance().as(LengthUnit.Meter, _riderStartPoint!, _storePoint!);
      _pickupDistanceKm = double.parse(((pMeters * 1.18) / 1000.0).toStringAsFixed(1));
    }
    if (_deliveryDistanceKm <= 0 && _storePoint != null && _destPoint != null) {
      final dMeters = const Distance().as(LengthUnit.Meter, _storePoint!, _destPoint!);
      _deliveryDistanceKm = double.parse(((dMeters * 1.18) / 1000.0).toStringAsFixed(1));
    }
    _recalculateTotals();

    // Trigger instant routing if points already exist
    _setupRoadRoute();
  }

  void _parseTrailPoints(List rawTrail) {
    final List<LatLng> points = [];
    for (var pt in rawTrail) {
      if (pt is Map) {
        final lat = double.tryParse(pt['lat']?.toString() ?? '');
        final lng = double.tryParse(pt['lng']?.toString() ?? '');
        if (lat != null && lng != null && lat != 0 && lng != 0) {
          points.add(LatLng(lat, lng));
        }
      }
    }
    if (points.isNotEmpty) {
      setState(() {
        _trailPoints = points;
        _riderLastPoint = points.last;
        _riderStartPoint ??= points.first;
      });
      if (_pickupDistanceKm <= 0 && _storePoint != null && _riderStartPoint != null) {
        final pMeters = const Distance().as(LengthUnit.Meter, _riderStartPoint!, _storePoint!);
        _pickupDistanceKm = double.parse(((pMeters * 1.18) / 1000.0).toStringAsFixed(1));
        _recalculateTotals();
      }
    }
  }

  Future<String> _getEffectiveToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('admin_user');
      if (userStr != null) {
        final u = jsonDecode(userStr);
        if (u['token'] != null && u['token'].toString().trim().isNotEmpty) {
          return u['token'].toString().trim();
        }
      }
      final directToken = prefs.getString('admin_token');
      if (directToken != null && directToken.trim().isNotEmpty) {
        return directToken.trim();
      }
    } catch (_) {}
    return (dotenv.isInitialized ? dotenv.env['ADMIN_TOKEN'] : null) ?? '';
  }

  Future<void> _fetchFullLocationTrail() async {
    final orderId = widget.order['_id'] ?? widget.order['id'];
    if (orderId == null) {
      setState(() => _isLoadingTrail = false);
      _setupRoadRoute();
      return;
    }

    final apiBase = (dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null) ?? 'http://54.204.9.126:5000/api/v1';
    final token = await _getEffectiveToken();
    final url = '$apiBase/admin/orders/$orderId/location-trail';

    try {
      final res = await http.get(Uri.parse(url), headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'];

          if (data['store'] != null && data['store']['lat'] != null && data['store']['lng'] != null) {
            _storePoint = LatLng((data['store']['lat'] as num).toDouble(), (data['store']['lng'] as num).toDouble());
            if (data['store']['name'] != null) _storeName = data['store']['name'];
            if (data['store']['address'] != null) _storeAddress = data['store']['address'];
          }

          if (data['customer'] != null && data['customer']['lat'] != null && data['customer']['lng'] != null) {
            _destPoint = LatLng((data['customer']['lat'] as num).toDouble(), (data['customer']['lng'] as num).toDouble());
            if (data['customer']['name'] != null) _customerName = data['customer']['name'];
            if (data['customer']['phone'] != null) _customerPhone = data['customer']['phone'];
            if (data['customer']['address'] != null) _deliveryAddress = data['customer']['address'];
          }

          if (data['driver'] != null) {
            _driverName = data['driver']['name'] ?? _driverName;
            _driverPhone = data['driver']['phone'] ?? _driverPhone;
            _driverVehicle = data['driver']['vehicleNumber'] ?? data['driver']['vehicleType'] ?? _driverVehicle;
          }

          if (data['pickupDistanceKm'] != null) {
            final pKm = (data['pickupDistanceKm'] as num).toDouble();
            if (pKm > 0) _pickupDistanceKm = pKm;
          }
          if (data['deliveryDistanceKm'] != null) {
            final dKm = (data['deliveryDistanceKm'] as num).toDouble();
            if (dKm > 0) _deliveryDistanceKm = dKm;
          }
          if (data['totalDistanceKm'] != null) {
            final tKm = (data['totalDistanceKm'] as num).toDouble();
            if (tKm > 0) _totalTripKm = tKm;
          }
          if (data['payableDistanceKm'] != null) {
            final payKm = (data['payableDistanceKm'] as num).toDouble();
            if (payKm > 0) _payableDistanceKm = payKm;
          }
          if (data['includeRiderPickupDistance'] != null) _includeRiderPickupDistance = data['includeRiderPickupDistance'] == true;
          if (data['driverRates'] != null && data['driverRates']['baseRate'] != null) {
            _driverBaseRatePerKm = (data['driverRates']['baseRate'] as num).toDouble();
          }

          if (data['riderInitialLocation'] != null && data['riderInitialLocation']['lat'] != null) {
            _riderStartPoint = LatLng(
              (data['riderInitialLocation']['lat'] as num).toDouble(),
              (data['riderInitialLocation']['lng'] as num).toDouble(),
            );
          } else if (_trailPoints.isNotEmpty) {
            _riderStartPoint = _trailPoints.first;
          }

          if (data['driverLocationTrail'] is List) {
            _parseTrailPoints(data['driverLocationTrail'] as List);
            if (_riderStartPoint == null && _trailPoints.isNotEmpty) {
              _riderStartPoint = _trailPoints.first;
            }
          }

          // Fallback pickup distance calculation if zero
          if (_pickupDistanceKm <= 0 && _riderStartPoint != null && _storePoint != null) {
            final pMeters = const Distance().as(LengthUnit.Meter, _riderStartPoint!, _storePoint!);
            _pickupDistanceKm = double.parse(((pMeters * 1.18) / 1000.0).toStringAsFixed(1));
          }
          if (_deliveryDistanceKm <= 0 && _storePoint != null && _destPoint != null) {
            final dMeters = const Distance().as(LengthUnit.Meter, _storePoint!, _destPoint!);
            _deliveryDistanceKm = double.parse(((dMeters * 1.18) / 1000.0).toStringAsFixed(1));
          }
          _recalculateTotals();
        }
      }
    } catch (e) {
      debugPrint('[RouteHistoryMap] Trail fetch error: $e');
      if (_pickupDistanceKm <= 0 && _riderStartPoint != null && _storePoint != null) {
        final pMeters = const Distance().as(LengthUnit.Meter, _riderStartPoint!, _storePoint!);
        _pickupDistanceKm = double.parse(((pMeters * 1.18) / 1000.0).toStringAsFixed(1));
      }
      if (_deliveryDistanceKm <= 0 && _storePoint != null && _destPoint != null) {
        final dMeters = const Distance().as(LengthUnit.Meter, _storePoint!, _destPoint!);
        _deliveryDistanceKm = double.parse(((dMeters * 1.18) / 1000.0).toStringAsFixed(1));
      }
      _recalculateTotals();
    } finally {
      if (mounted) {
        setState(() => _isLoadingTrail = false);
        _setupRoadRoute();
      }
    }
  }

  void _recalculateTotals() {
    _totalTripKm = double.parse((_pickupDistanceKm + _deliveryDistanceKm).toStringAsFixed(1));
    _payableDistanceKm = _includeRiderPickupDistance ? _totalTripKm : _deliveryDistanceKm;
    _distanceKm = _payableDistanceKm;
    _riderEarnings = (_payableDistanceKm * _driverBaseRatePerKm).roundToDouble();
  }

  void _setupRoadRoute() {
    if (_storePoint != null && _destPoint != null) {
      _fetchRoadRoute(_storePoint!, _destPoint!);
    }
    if (_riderStartPoint != null && _storePoint != null) {
      _fetchPickupRoadRoute(_riderStartPoint!, _storePoint!);
    }
    _fitBoundsAll();
  }

  Future<void> _fetchPickupRoadRoute(LatLng start, LatLng end) async {
    if (_isFetchingPickupRoad) return;
    setState(() => _isFetchingPickupRoad = true);

    final List<String> osrmEndpoints = [
      'https://routing.openstreetmap.de/routed-bike/route/v1/biking/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&alternatives=3',
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&alternatives=3',
      'https://routing.openstreetmap.de/routed-car/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=3',
    ];

    List<LatLng>? routePoints;
    double? distMeters;

    try {
      final headers = {'User-Agent': 'NambaAdminApp/1.0 (admin.namba@gmail.com)'};
      final responses = await Future.wait(
        osrmEndpoints.map((url) => http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500))),
      );

      dynamic bestRoute;
      double minDistance = double.infinity;

      for (final res in responses) {
        if (res.statusCode == 200 && res.body.isNotEmpty) {
          try {
            final data = jsonDecode(res.body);
            final routes = data['routes'] as List? ?? [];
            for (var r in routes) {
              final d = (r['distance'] as num).toDouble();
              if (d < minDistance && d > 0) {
                minDistance = d;
                bestRoute = r;
              }
            }
          } catch (_) {}
        }
      }

      if (bestRoute != null && minDistance < double.infinity) {
        final List coords = bestRoute['geometry']['coordinates'];
        routePoints = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        distMeters = minDistance;
      }
    } catch (e) {
      debugPrint('[PickupRoadRoute] Error: $e');
    }

    if (routePoints != null && routePoints.isNotEmpty && distMeters != null) {
      final validPoints = routePoints;
      final validDist = distMeters;
      if (mounted) {
        setState(() {
          validPoints.insert(0, start);
          if (validPoints.last != end) validPoints.add(end);
          _pickupRoadPoints = validPoints;
          if (validDist > 0) {
            _pickupDistanceKm = double.parse((validDist / 1000.0).toStringAsFixed(1));
            _recalculateTotals();
          }
          _isFetchingPickupRoad = false;
        });
        _fitBoundsAll();
      }
    } else {
      if (mounted) {
        setState(() {
          _pickupRoadPoints = [start, end];
          if (_pickupDistanceKm <= 0) {
            final straightMeters = const Distance().as(LengthUnit.Meter, start, end);
            _pickupDistanceKm = double.parse(((straightMeters * 1.18) / 1000.0).toStringAsFixed(1));
            _recalculateTotals();
          }
          _isFetchingPickupRoad = false;
        });
        _fitBoundsAll();
      }
    }
  }

  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    if (_isFetchingRoadRoute) return;
    setState(() => _isFetchingRoadRoute = true);

    final List<String> osrmEndpoints = [
      'https://routing.openstreetmap.de/routed-bike/route/v1/biking/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&alternatives=3',
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&steps=true&alternatives=3',
      'https://routing.openstreetmap.de/routed-car/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&alternatives=3',
    ];

    List<LatLng>? routePoints;
    double? distMeters;

    try {
      final headers = {'User-Agent': 'NambaAdminApp/1.0 (admin.namba@gmail.com)'};
      final responses = await Future.wait(
        osrmEndpoints.map((url) => http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500))),
      );

      dynamic bestRoute;
      double minDistance = double.infinity;

      for (final res in responses) {
        if (res.statusCode == 200 && res.body.isNotEmpty) {
          try {
            final data = jsonDecode(res.body);
            final routes = data['routes'] as List? ?? [];
            for (var r in routes) {
              final d = (r['distance'] as num).toDouble();
              if (d < minDistance && d > 0) {
                minDistance = d;
                bestRoute = r;
              }
            }
          } catch (_) {}
        }
      }

      if (bestRoute != null && minDistance < double.infinity) {
        final List coords = bestRoute['geometry']['coordinates'];
        routePoints = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        distMeters = minDistance;
      }
    } catch (e) {
      debugPrint('[RoadRoute] Error: $e');
    }

    if (routePoints != null && routePoints.isNotEmpty && distMeters != null) {
      final validPoints = routePoints;
      final validDist = distMeters;
      if (mounted) {
        setState(() {
          validPoints.insert(0, start);
          if (validPoints.last != end) validPoints.add(end);
          _roadPolylinePoints = validPoints;
          if (validDist > 0) {
            _deliveryDistanceKm = double.parse((validDist / 1000.0).toStringAsFixed(1));
            _recalculateTotals();
          }
          _isFetchingRoadRoute = false;
        });
        _fitBoundsAll();
      }
    } else {
      if (mounted) {
        setState(() {
          _roadPolylinePoints = [start, end];
          if (_deliveryDistanceKm <= 0) {
            final straightMeters = const Distance().as(LengthUnit.Meter, start, end);
            _deliveryDistanceKm = double.parse(((straightMeters * 1.18) / 1000.0).toStringAsFixed(1));
            _recalculateTotals();
          }
          _isFetchingRoadRoute = false;
        });
        _fitBoundsAll();
      }
    }
  }

  void _fitBoundsAll() {
    final List<LatLng> allPts = [];
    if (_riderStartPoint != null) allPts.add(_riderStartPoint!);
    if (_storePoint != null) allPts.add(_storePoint!);
    if (_destPoint != null) allPts.add(_destPoint!);
    if (_riderLastPoint != null) allPts.add(_riderLastPoint!);
    allPts.addAll(_trailPoints);
    allPts.addAll(_roadPolylinePoints);
    allPts.addAll(_pickupRoadPoints);

    _fitMapToPoints(allPts);
  }

  void _fitMapToPoints(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    
    // Calculate span zoom
    double latDiff = (maxLat - minLat).abs();
    double lngDiff = (maxLng - minLng).abs();
    double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    double zoom = 14.0;
    if (maxDiff > 0.5) zoom = 9.5;
    else if (maxDiff > 0.2) zoom = 11.0;
    else if (maxDiff > 0.1) zoom = 12.5;
    else if (maxDiff > 0.05) zoom = 13.5;
    else if (maxDiff > 0.02) zoom = 14.5;
    else zoom = 15.5;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(center, zoom);
      }
    });
  }

  void _showImagePreviewDialog(String imagePath, String title) {
    final clean = imagePath.replaceAll('\\', '/');
    final url = (clean.startsWith('http') || clean.contains(':\\'))
        ? clean
        : '${((dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null) ?? 'http://54.204.9.126:5000').replaceAll('/api/v1', '')}${clean.startsWith('/') ? '' : '/'}$clean';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('Image not available or failed to load'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _payDriverFee() async {
    final orderId = widget.order['_id'] ?? widget.order['id'] ?? '';
    if (orderId.toString().isEmpty || _isPayingDriver) return;
    setState(() => _isPayingDriver = true);
    try {
      final base = ((dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null) ?? 'http://54.204.9.126:5000').replaceAll('/api/v1', '');
      final token = (dotenv.isInitialized ? dotenv.env['ADMIN_TOKEN'] : null) ?? '';
      final res = await http.put(
        Uri.parse('$base/api/v1/admin/orders/$orderId/pay-driver'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'paymentMethod': 'UPI',
          'transactionRef': 'ADMIN-PAY-${DateTime.now().millisecondsSinceEpoch}',
        }),
      );
      if (res.statusCode == 200) {
        setState(() {
          _isDriverPaid = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('✅ Delivery Charge ₹${_riderEarnings.toStringAsFixed(0)} Paid to $_driverName successfully!')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error paying driver fee: $e');
    } finally {
      if (mounted) setState(() => _isPayingDriver = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng defaultCenter = _storePoint ?? _destPoint ?? _riderLastPoint ?? const LatLng(11.3410, 77.7172);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // ── 1. MAIN INTERACTIVE LEAFLET MAP ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: defaultCenter,
              initialZoom: 14.0,
              minZoom: 3.0,
              maxZoom: 20.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _currentMapStyleUrl,
                subdomains: _currentMapStyleUrl.contains('google.com') ? const ['0', '1', '2', '3'] : const ['a', 'b', 'c'],
                userAgentPackageName: 'com.namba.admin',
                maxZoom: 20,
                maxNativeZoom: 19,
              ),

              // 🟠 RIDER TO SHOP PICKUP ROAD TRAJECTORY (Pickup Leg)
              if (_pickupRoadPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Outer dark amber casing
                    Polyline(
                      points: _pickupRoadPoints,
                      color: const Color(0xFF78350F).withValues(alpha: 0.8),
                      strokeWidth: 8.0,
                    ),
                    // Inner glowing amber trajectory
                    Polyline(
                      points: _pickupRoadPoints,
                      color: const Color(0xFFF59E0B),
                      strokeWidth: 5.0,
                    ),
                  ],
                ),

              // 🛣️ ROAD NETWORK NAVIGATION POLYLINE (Turn-by-turn road trajectory)
              if (_roadPolylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Outer road casing / dark stroke
                    Polyline(
                      points: _roadPolylinePoints,
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.8),
                      strokeWidth: 8.0,
                    ),
                    // Inner glowing turn-by-turn navigation line
                    Polyline(
                      points: _roadPolylinePoints,
                      color: const Color(0xFF38BDF8),
                      strokeWidth: 5.0,
                    ),
                  ],
                ),

              // 🟣 RIDER ACTUAL GPS TRAIL (Actual historical path taken by partner)
              if (_trailPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Outer dark casing
                    Polyline(
                      points: _trailPoints,
                      color: const Color(0xFF064E3B).withValues(alpha: 0.9),
                      strokeWidth: 9.0,
                    ),
                    // Inner emerald trajectory
                    Polyline(
                      points: _trailPoints,
                      color: const Color(0xFF10B981),
                      strokeWidth: 6.0,
                    ),
                  ],
                ),

              // 📍 MARKERS LAYER
              MarkerLayer(
                markers: [
                  // 0. RIDER INITIAL START PIN
                  if (_riderStartPoint != null)
                    Marker(
                      point: _riderStartPoint!,
                      width: 150,
                      height: 105,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF92400E),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)],
                            ),
                            child: Text(
                              '🏍️ START: $_driverName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),

                  // 1. STORE / SHOP PICKUP PIN
                  if (_storePoint != null)
                    Marker(
                      point: _storePoint!,
                      width: 160,
                      height: 110,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF065F46),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)],
                            ),
                            child: Text(
                              '🏪 SHOP: $_storeName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),

                  // 2. CUSTOMER DELIVERY DESTINATION PIN
                  if (_destPoint != null)
                    Marker(
                      point: _destPoint!,
                      width: 160,
                      height: 110,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B4B),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)],
                            ),
                            child: Text(
                              '🏠 DELIVER: $_customerName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),

                  // 3. RIDER CURRENT / FINAL LOCATION PIN
                  if (_riderLastPoint != null)
                    Marker(
                      point: _riderLastPoint!,
                      width: 140,
                      height: 100,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6)],
                            ),
                            child: Text(
                              '🛵 $_driverName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFDC2626), width: 3),
                              boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFDC2626), size: 22),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── 2. TOP GLASS HEADER BAR ──
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 25, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Route History #$_displayId',
                                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _orderType == 'MapPin' || _orderType == 'map_pin' ? Colors.purple.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _orderType == 'MapPin' || _orderType == 'map_pin' ? Colors.purple.shade200 : Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    _orderType == 'MapPin' || _orderType == 'map_pin' ? 'MAP PIN' : 'STORE CART',
                                    style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: _orderType == 'MapPin' || _orderType == 'map_pin' ? Colors.purple.shade700 : Colors.blue.shade700),
                                  ),
                                ),
                                if (_isLoadingTrail) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB))),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Delivery Partner GPS Trajectory & Route Audit',
                              style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _orderStatus.toLowerCase() == 'delivered' ? const Color(0xFFECFDF5) : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _orderStatus.toLowerCase() == 'delivered' ? const Color(0xFFA7F3D0) : const Color(0xFFC7D2FE)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _orderStatus.toLowerCase() == 'delivered' ? Icons.check_circle_rounded : Icons.radar_rounded,
                              size: 14,
                              color: _orderStatus.toLowerCase() == 'delivered' ? const Color(0xFF059669) : const Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _orderStatus.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: _orderStatus.toLowerCase() == 'delivered' ? const Color(0xFF065F46) : const Color(0xFF3730A3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 3. MAP CONTROLS (Right Floating Stack) ──
          Positioned(
            right: 20,
            top: 130,
            child: Column(
              children: [
                // Recenter / Fit Bounds
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.fit_screen_rounded, color: Color(0xFF4F46E5)),
                    tooltip: 'Fit Full Route',
                    onPressed: _fitBoundsAll,
                  ),
                ),
                const SizedBox(height: 10),
                
                // Zoom Controls
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, color: Color(0xFF0F172A)),
                        tooltip: 'Zoom In',
                        onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                      ),
                      Container(height: 1, width: 30, color: Colors.grey.shade200),
                      IconButton(
                        icon: const Icon(Icons.remove, color: Color(0xFF0F172A)),
                        tooltip: 'Zoom Out',
                        onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Map Style Switcher
                PopupMenuButton<String>(
                  tooltip: 'Map Layer Style',
                  onSelected: (style) => setState(() => _currentMapStyleUrl = style),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}', child: Text('Google Traffic')),
                    const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', child: Text('Google Satellite')),
                    const PopupMenuItem(value: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', child: Text('Voyager Clean')),
                    const PopupMenuItem(value: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', child: Text('Dark Tactical')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.layers_rounded, color: Color(0xFF4F46E5), size: 22),
                  ),
                ),
              ],
            ),
          ),

          // ── 4. BOTTOM GLASS ROUTE SUMMARY SHEET ──
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: Rider Details & Payout
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF4F46E5), size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _driverName,
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Delivery Partner ${_driverPhone.isNotEmpty ? "• $_driverPhone" : ""} ${_driverVehicle.isNotEmpty ? "($_driverVehicle)" : ""}',
                                  style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          if (_billPhotoPath != null && _billPhotoPath!.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _showImagePreviewDialog(_billPhotoPath!, 'Shop Bill Proof - #$_displayId'),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                                foregroundColor: const Color(0xFF065F46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.receipt_long_rounded, size: 16),
                              label: Text('Shop Bill', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Executive Setting Status Banner ──
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _includeRiderPickupDistance ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _includeRiderPickupDistance ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _includeRiderPickupDistance ? const Color(0xFF059669) : Colors.grey.shade500,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _includeRiderPickupDistance ? Icons.check : Icons.close_rounded,
                                color: Colors.white,
                                size: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF0F172A)),
                                  children: [
                                    const TextSpan(
                                      text: 'Setting: Include Rider Pickup Distance is ',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(
                                      text: _includeRiderPickupDistance ? 'ON (Active)' : 'OFF (Disabled)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: _includeRiderPickupDistance ? const Color(0xFF059669) : Colors.grey.shade800,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _includeRiderPickupDistance
                                          ? ' • Payout includes Rider ➔ Shop (${_pickupDistanceKm.toStringAsFixed(1)} KM) + Shop ➔ Customer (${_deliveryDistanceKm.toStringAsFixed(1)} KM)'
                                          : ' • Payout includes ONLY Shop ➔ Customer (${_deliveryDistanceKm.toStringAsFixed(1)} KM)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Row 1: Split Distance Breakdown Cards (3 Cards) ──
                      Row(
                        children: [
                          // 1. Rider -> Shop (Pickup Distance)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('RIDER ➔ SHOP', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF92400E), letterSpacing: 0.5)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: _includeRiderPickupDistance ? const Color(0xFFD1FAE5) : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _includeRiderPickupDistance ? 'PAID ✅' : 'NOT PAID ❌',
                                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: _includeRiderPickupDistance ? const Color(0xFF065F46) : Colors.grey.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text('🛵 ${_pickupDistanceKm.toStringAsFixed(1)} KM', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF78350F))),
                                  const SizedBox(height: 2),
                                  Text('Pickup Leg (பிக்கப் தூரம்)', style: TextStyle(fontSize: 9.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 2. Shop -> Customer (Delivery Distance)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('SHOP ➔ CUSTOMER', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF1E40AF), letterSpacing: 0.5)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD1FAE5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'PAID ✅',
                                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text('📦 ${_deliveryDistanceKm.toStringAsFixed(1)} KM', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF1E3A8A))),
                                  const SizedBox(height: 2),
                                  Text('Delivery Leg (டெலிவரி தூரம்)', style: TextStyle(fontSize: 9.5, color: Colors.blue.shade900, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 3. Total Trip Distance
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE9D5FF), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('TOTAL DISTANCE', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF6B21A8), letterSpacing: 0.5)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${_payableDistanceKm.toStringAsFixed(1)} KM Pay',
                                          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF581C87)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text('🛣️ ${_totalTripKm.toStringAsFixed(1)} KM', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF581C87))),
                                  const SizedBox(height: 2),
                                  Text('Full Journey (மொத்த தூரம்)', style: TextStyle(fontSize: 9.5, color: Colors.purple.shade900, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Row 2: Operational & Financial Metric Cards ──
                      Row(
                        children: [
                          // 1. Payable Distance
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PAYABLE KM', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.8)),
                                  const SizedBox(height: 2),
                                  Text('🛵 ${_payableDistanceKm.toStringAsFixed(1)} KM', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 2. Trail Points
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('GPS TRAIL', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.8)),
                                  const SizedBox(height: 2),
                                  Text(_actualKm > 0 ? '${_actualKm.toStringAsFixed(1)} KM (${_trailPoints.length} pts)' : '${_trailPoints.length} Points', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF059669))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 3. Rider Earnings
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('RIDER PAY', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF065F46), letterSpacing: 0.8)),
                                      Text('₹${_driverBaseRatePerKm.toStringAsFixed(0)}/KM', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF047857))),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('₹${_riderEarnings.toInt()}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF065F46))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Row 3: 3-Step Journey Audit (Rider Start -> Shop -> Customer) ──
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            // 1. Rider Assigned Start Location
                            Row(
                              children: [
                                const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '1. Rider Start: $_driverName (Assigned GPS Location)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                                  child: Text('Pickup: ${_pickupDistanceKm.toStringAsFixed(1)} KM', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 7),
                              child: Align(alignment: Alignment.centerLeft, child: Text('↓', style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.1))),
                            ),
                            // 2. Store Pickup
                            Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF059669)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '2. Store Pickup: $_storeName ($_storeAddress)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(6)),
                                  child: Text('Delivery: ${_deliveryDistanceKm.toStringAsFixed(1)} KM', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 7),
                              child: Align(alignment: Alignment.centerLeft, child: Text('↓', style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.1))),
                            ),
                            // 3. Customer Delivery
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '3. Customer Drop: $_customerName (${_customerPhone.isNotEmpty ? "$_customerPhone • " : ""}$_deliveryAddress)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(6)),
                                  child: Text('Total: ${_totalTripKm.toStringAsFixed(1)} KM', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B21A8))),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_orderStatus.toLowerCase() == 'delivered') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isDriverPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _isDriverPaid ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_isDriverPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                      size: 14, color: _isDriverPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706)),
                                  const SizedBox(width: 5),
                                  Text(
                                    _isDriverPaid ? 'PAYOUT SETTLED' : 'PAYOUT PENDING',
                                    style: GoogleFonts.outfit(
                                      color: _isDriverPaid ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (!_isDriverPaid)
                              ElevatedButton.icon(
                                onPressed: _isPayingDriver ? null : _payDriverFee,
                                icon: _isPayingDriver
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.payments_rounded, size: 16),
                                label: Text('PAY DELIVERY FEE (₹${_riderEarnings.toInt()})', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                          ],
                        ),
                      ],
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
}
