import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class DeliveryHub {
  final String id;
  final String name;
  final String district;
  final double lat;
  final double lng;
  final double radiusKm;
  final bool isActive;

  const DeliveryHub({
    required this.id,
    required this.name,
    required this.district,
    required this.lat,
    required this.lng,
    required this.radiusKm,
    this.isActive = true,
  });

  factory DeliveryHub.fromJson(Map<String, dynamic> json) {
    return DeliveryHub(
      id: json['id']?.toString() ?? 'hub_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? 'Delivery Hub',
      district: json['district']?.toString() ?? 'Erode',
      lat: (json['lat'] as num?)?.toDouble() ?? 11.3410,
      lng: (json['lng'] as num?)?.toDouble() ?? 77.7172,
      radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 10.0,
      isActive: json['isActive'] == null ? true : (json['isActive'] as bool),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'district': district,
    'lat': lat,
    'lng': lng,
    'radiusKm': radiusKm,
    'isActive': isActive,
  };
}

class DeliveryHubMatch {
  final DeliveryHub hub;
  final double distanceKm;
  final bool isInRange;

  const DeliveryHubMatch({
    required this.hub,
    required this.distanceKm,
    required this.isInRange,
  });
}

class DeliveryHubService {
  static final DeliveryHubService _instance = DeliveryHubService._internal();
  factory DeliveryHubService() => _instance;
  DeliveryHubService._internal();

  static final List<DeliveryHub> defaultHubs = [
    const DeliveryHub(
      id: 'hub_erode_central',
      name: 'Erode Central Hub',
      district: 'Erode',
      lat: 11.3410,
      lng: 77.7172,
      radiusKm: 10.0,
      isActive: true,
    ),
    const DeliveryHub(
      id: 'hub_perundurai',
      name: 'Perundurai Hub',
      district: 'Erode',
      lat: 11.2750,
      lng: 77.5830,
      radiusKm: 8.0,
      isActive: true,
    ),
    const DeliveryHub(
      id: 'hub_bhavani',
      name: 'Bhavani Hub',
      district: 'Erode',
      lat: 11.4460,
      lng: 77.6830,
      radiusKm: 6.0,
      isActive: true,
    ),
  ];

  static List<DeliveryHub> _cachedHubs = List.from(defaultHubs);
  static DateTime? _lastFetchTime;
  static double _fallbackMaxRadiusKm = 10.0;

  static List<DeliveryHub> get cachedHubs => _cachedHubs;

  static Future<List<DeliveryHub>> fetchHubs({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 2 &&
        _cachedHubs.isNotEmpty) {
      return _cachedHubs;
    }

    try {
      final url = Uri.parse('${CustomerApiService.baseUrl}/admin/settings/public');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'];
        if (data != null) {
          if (data['maxServiceRadiusKm'] != null && (data['maxServiceRadiusKm'] as num) > 0) {
            _fallbackMaxRadiusKm = (data['maxServiceRadiusKm'] as num).toDouble();
          }

          final List<DeliveryHub> loaded = [];
          if (data['deliveryHubs'] is List && (data['deliveryHubs'] as List).isNotEmpty) {
            for (final item in (data['deliveryHubs'] as List)) {
              if (item is Map) {
                final hub = DeliveryHub.fromJson(Map<String, dynamic>.from(item));
                if (hub.isActive) {
                  loaded.add(hub);
                }
              }
            }
          }

          if (loaded.isNotEmpty) {
            _cachedHubs = loaded;
            _lastFetchTime = now;
            return _cachedHubs;
          }
        }
      }
    } catch (e) {
      debugPrint('DeliveryHubService.fetchHubs error: $e');
    }

    // Fallback: update default Erode Central Hub with _fallbackMaxRadiusKm
    _cachedHubs = [
      DeliveryHub(
        id: 'hub_erode_central',
        name: 'Erode Central Hub',
        district: 'Erode',
        lat: 11.3410,
        lng: 77.7172,
        radiusKm: _fallbackMaxRadiusKm > 0 ? _fallbackMaxRadiusKm : 10.0,
        isActive: true,
      ),
      const DeliveryHub(
        id: 'hub_perundurai',
        name: 'Perundurai Hub',
        district: 'Erode',
        lat: 11.2750,
        lng: 77.5830,
        radiusKm: 8.0,
        isActive: true,
      ),
      const DeliveryHub(
        id: 'hub_bhavani',
        name: 'Bhavani Hub',
        district: 'Erode',
        lat: 11.4460,
        lng: 77.6830,
        radiusKm: 6.0,
        isActive: true,
      ),
    ];
    return _cachedHubs;
  }

  static DeliveryHubMatch matchLocation(double lat, double lng, {List<DeliveryHub>? hubs}) {
    final activeHubs = (hubs != null && hubs.isNotEmpty) ? hubs : _cachedHubs;
    if (activeHubs.isEmpty) {
      return DeliveryHubMatch(
        hub: defaultHubs.first,
        distanceKm: 0.0,
        isInRange: true,
      );
    }

    final List<DeliveryHubMatch> inRangeMatches = [];
    final List<DeliveryHubMatch> allMatches = [];

    for (final hub in activeHubs) {
      final meterDist = Geolocator.distanceBetween(hub.lat, hub.lng, lat, lng);
      final kmDist = double.parse((meterDist / 1000.0).toStringAsFixed(1));
      final match = DeliveryHubMatch(
        hub: hub,
        distanceKm: kmDist,
        isInRange: kmDist <= hub.radiusKm,
      );
      allMatches.add(match);
      if (match.isInRange) {
        inRangeMatches.add(match);
      }
    }

    if (inRangeMatches.isNotEmpty) {
      // Sort by closest distance
      inRangeMatches.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return inRangeMatches.first;
    }

    // Out of range: pick the nearest hub overall
    allMatches.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return allMatches.first;
  }
}
