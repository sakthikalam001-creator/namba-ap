import 'dart:async';
import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocationAccuracyService {
  static const double defaultTargetAccuracyMeters = 10.0;
  static const double defaultMaxUsableAccuracyMeters = 30.0;

  static Position? lastKnownAccuratePosition;
  static double currentAccuracy = 0.0;
  static String? lastKnownAddress;
  static bool _isCachedFromPreviousSession = false;

  // Real-time position broadcast stream
  static final StreamController<Position> _liveStreamController = StreamController<Position>.broadcast();
  static Stream<Position> get livePositionStream => _liveStreamController.stream;
  static StreamSubscription<Position>? _backgroundStreamSub;

  // In-memory LRU cache for reverse-geocoded coordinates -> address
  static final Map<String, String> _addressCache = {};

  static Future<void> initCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('last_accurate_lat');
      final lng = prefs.getDouble('last_accurate_lng');
      final savedAddress = prefs.getString('last_accurate_address');

      if (savedAddress != null && savedAddress.isNotEmpty && !savedAddress.toLowerCase().contains('fetching')) {
        lastKnownAddress = savedAddress;
      }

      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        _isCachedFromPreviousSession = true;
        lastKnownAccuratePosition = Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          accuracy: 999.0, // High accuracy number so any fresh GPS reading immediately replaces it
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      }

      // Start continuous background GPS listening immediately
      startContinuousTracking();
    } catch (_) {}
  }

  static StreamSubscription<Position>? _hwBackgroundStreamSub;

  static void startContinuousTracking() async {
    if (!await ensurePermission(requestIfNeeded: false)) return;
    
    _backgroundStreamSub?.cancel();
    _hwBackgroundStreamSub?.cancel();

    // 1. Active Fused Location stream (Wi-Fi + Cell + A-GPS + Satellites)
    try {
      _backgroundStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen((pos) {
        if (pos.latitude != 0.0 && pos.longitude != 0.0) {
          _acceptIncomingPosition(pos);
        }
      }, onError: (_) {});
    } catch (_) {}

    // 2. Direct Hardware GPS Satellite Chip stream (Direct Space Satellite Receiver)
    try {
      _hwBackgroundStreamSub = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          forceLocationManager: true,
          intervalDuration: const Duration(milliseconds: 200),
        ),
      ).listen((pos) {
        if (pos.latitude != 0.0 && pos.longitude != 0.0) {
          _acceptIncomingPosition(pos, isHardwareGps: true);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  static void _acceptIncomingPosition(Position pos, {bool isHardwareGps = false, void Function(Position)? onPosition}) {
    if (pos.latitude == 0.0 && pos.longitude == 0.0) return;
    // Pure Hardware GPS Satellite fix ALWAYS takes priority over cell towers
    if (isHardwareGps || _isBetter(pos, lastKnownAccuratePosition)) {
      currentAccuracy = pos.accuracy;
      _saveAccuratePosition(pos);
      _liveStreamController.add(pos);
      onPosition?.call(pos);
      reverseGeocode(pos.latitude, pos.longitude);
    }
  }

  static Future<void> _saveAccuratePosition(Position pos) async {
    _isCachedFromPreviousSession = false;
    lastKnownAccuratePosition = pos;
    currentAccuracy = pos.accuracy;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_accurate_lat', pos.latitude);
      await prefs.setDouble('last_accurate_lng', pos.longitude);
    } catch (_) {}
  }

  static Future<void> _saveAccurateAddress(String address) async {
    lastKnownAddress = address;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_accurate_address', address);
    } catch (_) {}
  }

  static LocationSettings highAccuracySettings({Duration? timeLimit, bool forceLocationManager = false}) {
    return AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      forceLocationManager: forceLocationManager,
      intervalDuration: const Duration(milliseconds: 200),
      timeLimit: timeLimit,
    );
  }

  static Future<bool> ensurePermission({bool requestIfNeeded = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if ((permission == LocationPermission.denied ||
            permission == LocationPermission.unableToDetermine) &&
        requestIfNeeded) {
      permission = await Geolocator.requestPermission();
    }

    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return false;
    }

    // Android 12+ Precise Location Check
    try {
      final accuracyStatus = await Geolocator.getLocationAccuracy();
      if (accuracyStatus == LocationAccuracyStatus.reduced && requestIfNeeded) {
        // Prompt user to enable Precise GPS Location
        await Geolocator.requestPermission();
      }
    } catch (_) {}

    return true;
  }

  static bool isFresh(Position pos) {
    if (pos.latitude == 0.0 && pos.longitude == 0.0) return false;
    final age = DateTime.now().difference(pos.timestamp.toLocal()).abs();
    return age < const Duration(seconds: 15) && pos.accuracy <= 25.0;
  }

  /// True Pin-Point Live GPS Acquisition with Active Satellite Convergence
  static Future<Position?> getBestPosition({
    double targetAccuracyMeters = 10.0,
    double maxUsableAccuracyMeters = 30.0,
    Duration quickFixTimeout = const Duration(seconds: 8),
    Duration refineTimeout = const Duration(seconds: 5),
    bool forceFresh = false,
    void Function(Position position)? onPosition,
  }) async {
    if (!await ensurePermission()) {
      return lastKnownAccuratePosition;
    }

    Position? best = (!forceFresh && lastKnownAccuratePosition != null && isFresh(lastKnownAccuratePosition!))
        ? lastKnownAccuratePosition
        : null;

    final completer = Completer<Position?>();
    StreamSubscription<Position>? streamSub;
    StreamSubscription<Position>? hwStreamSub;

    void updateBest(Position pos) {
      if (pos.latitude == 0.0 && pos.longitude == 0.0) return;
      if (_isBetter(pos, best)) {
        best = pos;
        currentAccuracy = pos.accuracy;
        _saveAccuratePosition(pos);
        _liveStreamController.add(pos);
        onPosition?.call(pos);
        reverseGeocode(pos.latitude, pos.longitude);

        // If satellite lock achieved high precision (< 12 meters), complete immediately!
        if (pos.accuracy <= targetAccuracyMeters && !completer.isCompleted) {
          completer.complete(pos);
        }
      }
    }

    // 1. Check native hardware last position only if it is very recent (< 10s) and not forcing fresh GPS
    if (!forceFresh) {
      try {
        final nativeLast = await Geolocator.getLastKnownPosition();
        if (nativeLast != null && nativeLast.latitude != 0.0 && nativeLast.longitude != 0.0) {
          final age = DateTime.now().difference(nativeLast.timestamp.toLocal()).abs();
          if (age < const Duration(seconds: 10) && nativeLast.accuracy <= 25.0) {
            updateBest(nativeLast);
          }
        }
      } catch (_) {}
    }

    // 2. Open active Android Fused GPS satellite stream
    try {
      streamSub = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          forceLocationManager: false,
          intervalDuration: const Duration(milliseconds: 150),
        ),
      ).listen((pos) {
        updateBest(pos);
      }, onError: (_) {});
    } catch (_) {}

    // 3. Concurrently listen to direct Hardware GPS (forceLocationManager: true) to bypass any stale Play Services cache
    try {
      hwStreamSub = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          forceLocationManager: true,
          intervalDuration: const Duration(milliseconds: 200),
        ),
      ).listen((pos) {
        updateBest(pos);
      }, onError: (_) {});
    } catch (_) {}

    // 4. Concurrent Direct Hardware Location Query
    Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        forceLocationManager: true,
        intervalDuration: const Duration(milliseconds: 200),
        timeLimit: quickFixTimeout,
      ),
    ).then((pos) {
      updateBest(pos);
      if (!completer.isCompleted && best != null && best!.accuracy <= maxUsableAccuracyMeters) {
        completer.complete(best);
      }
    }).catchError((_) {});

    // 5. Concurrent Fused GPS Query
    Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        forceLocationManager: false,
        intervalDuration: const Duration(milliseconds: 200),
        timeLimit: quickFixTimeout,
      ),
    ).then((pos) {
      updateBest(pos);
      if (!completer.isCompleted && best != null && best!.accuracy <= maxUsableAccuracyMeters) {
        completer.complete(best);
      }
    }).catchError((_) {});

    // Timeout safety
    Timer(quickFixTimeout, () {
      if (!completer.isCompleted) {
        completer.complete(best ?? lastKnownAccuratePosition);
      }
    });

    final result = await completer.future;
    streamSub?.cancel();
    hwStreamSub?.cancel();
    return result ?? best ?? lastKnownAccuratePosition;
  }

  static bool _isBetter(Position candidate, Position? currentBest) {
    if (candidate.latitude == 0.0 && candidate.longitude == 0.0) return false;
    if (currentBest == null) return true;
    if (_isCachedFromPreviousSession) return true;

    // Any reading with better accuracy ALWAYS wins (e.g. 15m beats 500m)
    if (candidate.accuracy < currentBest.accuracy) {
      return true;
    }

    final now = DateTime.now();
    final candidateAge = now.difference(candidate.timestamp.toLocal()).abs();
    final currentAge = now.difference(currentBest.timestamp.toLocal()).abs();

    // If current best is older than 5s and candidate is fresh (< 10s), prefer candidate
    if (currentAge > const Duration(seconds: 5) && candidateAge <= const Duration(seconds: 10)) {
      return true;
    }

    // If candidate is newer and accuracy is good (<= 25m), update
    if (candidate.timestamp.isAfter(currentBest.timestamp) && candidate.accuracy <= 25.0) {
      return true;
    }

    return false;
  }

  /// High-speed reverse geocoder with rich POI extraction (Shops, Landmarks, Streets, Areas)
  static Future<String> reverseGeocode(double lat, double lng) async {
    final cacheKey = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_addressCache.containsKey(cacheKey)) {
      return _addressCache[cacheKey]!;
    }

    // 1. Primary: Native Device Geocoder (Uses Google Play Services / iOS CoreLocation with street-level accuracy)
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 4));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final List<String> parts = [];
        final name = (p.name ?? '').trim();
        final street = (p.street ?? p.thoroughfare ?? '').trim();
        final subLocality = (p.subLocality ?? p.subAdministrativeArea ?? '').trim();
        final locality = (p.locality ?? 'Erode').trim();

        if (name.isNotEmpty &&
            name != street &&
            name != p.postalCode &&
            !name.contains('Unnamed') &&
            !name.contains('+') &&
            !name.toLowerCase().contains('asia')) {
          parts.add(name);
        }
        if (street.isNotEmpty &&
            !parts.contains(street) &&
            !street.contains('Unnamed') &&
            !street.contains('+') &&
            !street.toLowerCase().contains('asia')) {
          parts.add(street);
        }
        if (subLocality.isNotEmpty &&
            !parts.contains(subLocality) &&
            subLocality != locality &&
            !subLocality.toLowerCase().contains('asia')) {
          parts.add(subLocality);
        }
        if (locality.isNotEmpty && !parts.contains(locality) && !locality.toLowerCase().contains('asia')) {
          parts.add(locality);
        }

        if (parts.isNotEmpty) {
          final formatted = parts.join(', ');
          _addressCache[cacheKey] = formatted;
          _saveAccurateAddress(formatted);
          return formatted;
        }
      }
    } catch (_) {}

    // 2. Secondary: OpenStreetMap Nominatim with POI, Shop, Building & Street extraction
    final clientFingerprint = 'NambaApp_2.0_${(lat * 1000).toInt()}_${(lng * 1000).toInt()}';
    try {
      final nomUri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=19&addressdetails=1&extratags=1&namedetails=1',
      );
      final photonUri = Uri.parse(
        'https://photon.komoot.io/reverse?lat=$lat&lon=$lng',
      );

      final results = await Future.wait([
        http.get(nomUri, headers: {
          'User-Agent': clientFingerprint,
          'Accept': 'application/json',
        }).timeout(const Duration(milliseconds: 2500)).catchError((_) => http.Response('', 500)),
        http.get(photonUri, headers: {
          'User-Agent': clientFingerprint,
          'Accept': 'application/json',
        }).timeout(const Duration(milliseconds: 2000)).catchError((_) => http.Response('', 500)),
      ]);

      final resNom = results[0];
      if (resNom.statusCode == 200 && resNom.body.isNotEmpty) {
        try {
          final decoded = json.decode(resNom.body);
          final addr = (decoded['address'] as Map<String, dynamic>?) ?? {};
          final extra = (decoded['extratags'] as Map<String, dynamic>?) ?? {};
          
          final shop = addr['shop'] ?? extra['shop'] ?? '';
          final amenity = addr['amenity'] ?? extra['amenity'] ?? '';
          final building = addr['building'] ?? extra['building'] ?? '';
          final name = decoded['name'] ?? addr['leisure'] ?? addr['office'] ?? addr['commercial'] ?? addr['tourism'] ?? addr['healthcare'] ?? '';
          
          final houseNumber = addr['house_number'] ?? '';
          final road = addr['road'] ?? addr['street'] ?? addr['pedestrian'] ?? addr['highway'] ?? addr['footway'] ?? addr['path'] ?? '';
          final landmark = (name.isNotEmpty && name != road) ? name : (shop.isNotEmpty ? shop : (amenity.isNotEmpty ? amenity : building));
          
          final suburb = addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'] ?? addr['subdistrict'] ?? addr['quarter'] ?? addr['village'] ?? '';
          final city = addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['county'] ?? addr['state_district'] ?? 'Erode';

          List<String> parts = [];
          if (houseNumber.isNotEmpty) parts.add(houseNumber);
          if (landmark.isNotEmpty && !parts.contains(landmark) && landmark != road && landmark != suburb && landmark != city && !landmark.toLowerCase().contains('asia')) {
            parts.add(landmark);
          }
          if (road.isNotEmpty && !parts.contains(road) && !road.toLowerCase().contains('asia')) {
            parts.add(road);
          }
          if (suburb.isNotEmpty && !parts.contains(suburb) && !suburb.toLowerCase().contains('asia')) {
            parts.add(suburb);
          }
          if (city.isNotEmpty && !parts.contains(city) && !city.toLowerCase().contains('asia')) {
            parts.add(city);
          }

          if (parts.isNotEmpty && (parts.length >= 2 || road.isNotEmpty || landmark.isNotEmpty)) {
            final formatted = parts.join(', ');
            _addressCache[cacheKey] = formatted;
            _saveAccurateAddress(formatted);
            return formatted;
          }
        } catch (_) {}
      }

      final resPhoton = results[1];
      if (resPhoton.statusCode == 200 && resPhoton.body.isNotEmpty) {
        try {
          final decoded = json.decode(resPhoton.body);
          final features = decoded['features'] as List?;
          if (features != null && features.isNotEmpty) {
            final props = (features[0]['properties'] as Map<String, dynamic>?) ?? {};
            final name = props['name'] ?? '';
            final housenumber = props['housenumber'] ?? '';
            final street = props['street'] ?? '';
            final district = props['district'] ?? props['locality'] ?? props['suburb'] ?? '';
            final city = props['city'] ?? props['town'] ?? props['county'] ?? 'Erode';

            List<String> parts = [];
            if (housenumber.isNotEmpty) parts.add(housenumber);
            if (name.isNotEmpty && name != street && name != district && name != city && !name.toLowerCase().contains('asia')) parts.add(name);
            if (street.isNotEmpty && !parts.contains(street) && !street.toLowerCase().contains('asia')) parts.add(street);
            if (district.isNotEmpty && !parts.contains(district) && !district.toLowerCase().contains('asia')) parts.add(district);
            if (city.isNotEmpty && !parts.contains(city) && !city.toLowerCase().contains('asia')) parts.add(city);

            if (parts.isNotEmpty && (parts.length >= 2 || street.isNotEmpty || name.isNotEmpty)) {
              final formatted = parts.join(', ');
              _addressCache[cacheKey] = formatted;
              _saveAccurateAddress(formatted);
              return formatted;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    // 3. Fallback: High-Accuracy Regional Spatial Map Dictionary
    final fallback = resolveKnownArea(lat, lng);
    _addressCache[cacheKey] = fallback;
    return fallback;
  }

  /// High-accuracy localized spatial landmark and neighborhood dictionary for Erode region
  static String resolveKnownArea(double lat, double lng) {
    final List<Map<String, dynamic>> landmarks = [
      {'name': 'Perundurai Road, Nasiyanur', 'lat': 11.3386, 'lng': 77.6600},
      {'name': 'Villarasampatti', 'lat': 11.3350, 'lng': 77.6850},
      {'name': 'Perundurai Road, Thindal', 'lat': 11.3280, 'lng': 77.6980},
      {'name': 'Palayapalayam', 'lat': 11.3350, 'lng': 77.7050},
      {'name': 'Kumalan Kuttai', 'lat': 11.3390, 'lng': 77.7080},
      {'name': 'Sampath Nagar', 'lat': 11.3450, 'lng': 77.7050},
      {'name': 'Veerappanchatram', 'lat': 11.3600, 'lng': 77.7150},
      {'name': 'Brough Road, City Center', 'lat': 11.3410, 'lng': 77.7200},
      {'name': 'Surampatti', 'lat': 11.3250, 'lng': 77.7150},
      {'name': 'Railway Colony, Erode Junction', 'lat': 11.3300, 'lng': 77.7280},
      {'name': 'Marapalam', 'lat': 11.3320, 'lng': 77.7350},
      {'name': 'Kollampalayam', 'lat': 11.3180, 'lng': 77.7320},
      {'name': 'Karungalpalayam', 'lat': 11.3500, 'lng': 77.7400},
      {'name': 'Kasipalayam', 'lat': 11.3200, 'lng': 77.7000},
      {'name': 'Rangampalayam', 'lat': 11.3100, 'lng': 77.7100},
      {'name': 'Solar, Karur Road', 'lat': 11.3050, 'lng': 77.7500},
      {'name': 'Chithode', 'lat': 11.4100, 'lng': 77.6800},
      {'name': 'Bhavani', 'lat': 11.4500, 'lng': 77.6800},
      {'name': 'Perundurai Town', 'lat': 11.2750, 'lng': 77.5850},
      {'name': 'Modakurichi', 'lat': 11.2300, 'lng': 77.7800},
      {'name': 'Gobichettipalayam', 'lat': 11.4550, 'lng': 77.4400},
      {'name': 'Sathyamangalam', 'lat': 11.5050, 'lng': 77.2400},
    ];

    double closestDist = double.infinity;
    String closestName = 'Erode City Area';

    for (final l in landmarks) {
      final double dLat = lat - (l['lat'] as double);
      final double dLng = lng - (l['lng'] as double);
      final double distSq = (dLat * dLat) + (dLng * dLng);
      if (distSq < closestDist) {
        closestDist = distSq;
        closestName = l['name'] as String;
      }
    }

    if (closestName.toLowerCase().contains('erode')) {
      return closestName;
    }
    return '$closestName, Erode';
  }
}
