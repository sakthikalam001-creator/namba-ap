import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationAccuracyService {
  static const double defaultTargetAccuracyMeters = 15.0;
  static const double defaultMaxUsableAccuracyMeters = 120.0;
  static const Duration maxLastKnownAge = Duration(minutes: 60);

  static Position? lastKnownAccuratePosition;

  static Future<void> initCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('last_accurate_lat');
      final lng = prefs.getDouble('last_accurate_lng');
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        lastKnownAccuratePosition = Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      }
    } catch (_) {}
  }

  static Future<void> _saveAccuratePosition(Position pos) async {
    lastKnownAccuratePosition = pos;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_accurate_lat', pos.latitude);
      await prefs.setDouble('last_accurate_lng', pos.longitude);
    } catch (_) {}
  }

  static LocationSettings highAccuracySettings({Duration? timeLimit, bool forceLocationManager = false}) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 250),
        forceLocationManager: forceLocationManager,
        timeLimit: timeLimit,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: false,
        timeLimit: timeLimit,
      );
    }

    return LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
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

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<Position?> getBestPosition({
    double targetAccuracyMeters = defaultTargetAccuracyMeters,
    double maxUsableAccuracyMeters = defaultMaxUsableAccuracyMeters,
    Duration quickFixTimeout = const Duration(seconds: 2),
    Duration refineTimeout = const Duration(seconds: 4),
    void Function(Position position)? onPosition,
  }) async {
    // 0. If cached position is available in memory/prefs, emit immediately (0ms latency!)
    if (lastKnownAccuratePosition != null) {
      onPosition?.call(lastKnownAccuratePosition!);
    }

    if (!await ensurePermission()) {
      return lastKnownAccuratePosition;
    }

    Position? best = lastKnownAccuratePosition;

    void acceptIfBetter(Position position) {
      if (!_isUsable(position, maxAccuracyMeters: maxUsableAccuracyMeters)) {
        return;
      }
      if (_isBetter(position, best)) {
        best = position;
        _saveAccuratePosition(position);
        onPosition?.call(position);
      }
    }

    // 1. Check last known position immediately
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null &&
          _isUsable(
            lastKnown,
            maxAccuracyMeters: 30.0,
            maxAge: maxLastKnownAge,
          )) {
        acceptIfBetter(lastKnown);
      }
    } catch (_) {}

    final completer = Completer<Position?>();
    StreamSubscription<Position>? hwSub;
    StreamSubscription<Position>? fusedSub;
    Timer? timeout;

    void finish() {
      if (!completer.isCompleted) {
        completer.complete(best);
      }
    }

    try {
      // 2. Direct Hardware Satellite GNSS stream (Bypasses slow WiFi / ISP DNS delays)
      hwSub = Geolocator.getPositionStream(
        locationSettings: highAccuracySettings(forceLocationManager: true),
      ).listen(
        (position) {
          acceptIfBetter(position);
          if (position.accuracy <= targetAccuracyMeters) {
            finish();
          }
        },
        onError: (_) {},
      );

      // 3. Parallel Fused stream
      fusedSub = Geolocator.getPositionStream(
        locationSettings: highAccuracySettings(forceLocationManager: false),
      ).listen(
        (position) {
          acceptIfBetter(position);
          if (position.accuracy <= targetAccuracyMeters) {
            finish();
          }
        },
        onError: (_) {},
      );

      // 4. Quick direct hardware satellite query
      Geolocator.getCurrentPosition(
        locationSettings: highAccuracySettings(forceLocationManager: true, timeLimit: quickFixTimeout),
      ).then((current) {
        acceptIfBetter(current);
        if (current.accuracy <= targetAccuracyMeters) {
          finish();
        }
      }).catchError((_) {});

      timeout = Timer(refineTimeout, finish);
      await completer.future;
    } catch (_) {
    } finally {
      timeout?.cancel();
      await hwSub?.cancel();
      await fusedSub?.cancel();
    }

    return best;
  }

  static bool _isBetter(Position candidate, Position? currentBest) {
    if (currentBest == null) {
      return true;
    }
    // Always prefer higher accuracy (lower meter value)
    if (candidate.accuracy < currentBest.accuracy) {
      return true;
    }
    // If accuracy is similar within 3 meters, accept the newer timestamp
    if (candidate.accuracy <= currentBest.accuracy + 3 &&
        candidate.timestamp.isAfter(currentBest.timestamp)) {
      return true;
    }
    return false;
  }

  static bool _isUsable(
    Position position, {
    required double maxAccuracyMeters,
    Duration? maxAge,
  }) {
    if (position.latitude == 0.0 && position.longitude == 0.0) {
      return false;
    }
    // Discard any position with accuracy worse than maxAccuracyMeters (e.g. > 35m)
    if (position.accuracy <= 0 || position.accuracy > maxAccuracyMeters) {
      return false;
    }
    if (maxAge != null &&
        DateTime.now().difference(position.timestamp.toLocal()) > maxAge) {
      return false;
    }
    return true;
  }
}
