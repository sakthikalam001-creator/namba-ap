import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class VendorBackgroundService {
  static final VendorBackgroundService _instance = VendorBackgroundService._internal();
  factory VendorBackgroundService() => _instance;
  VendorBackgroundService._internal();

  StreamSubscription<Position>? _positionStream;
  bool _isRunning = false;

  Future<void> start() async {
    if (_isRunning) return;
    try {
      // 1. Request location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[BackgroundService] Location service disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[BackgroundService] Location permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('[BackgroundService] Location permission denied forever');
        return;
      }

      _isRunning = true;

      // 2. Start geolocator position stream with Android foreground service settings
      LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 15,
          intervalDuration: const Duration(seconds: 15),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: "🟢 Namba Store Partner Active",
            notificationText: "Online & listening for new orders in background.",
            notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 15,
        );
      }

      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((_) {
        // Dummy listener to keep foreground service alive
      });
      debugPrint('[BackgroundService] Foreground service started successfully');
    } catch (e) {
      debugPrint('[BackgroundService] Error starting foreground service: $e');
      _isRunning = false;
    }
  }

  void stop() {
    _positionStream?.cancel();
    _positionStream = null;
    _isRunning = false;
    debugPrint('[BackgroundService] Foreground service stopped');
  }
}
