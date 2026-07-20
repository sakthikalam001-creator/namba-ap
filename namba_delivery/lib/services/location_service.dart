import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class LocationTrackingService {
  IO.Socket? _socket;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

  String? _trackedRiderId;

  void initialize(String serverUrl) {
    _socket = IO.io(serverUrl, 
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableForceNew()
        .disableAutoConnect()
        .build()
    );
    _socket!.connect();
    
    _socket!.onConnect((_) {
      debugPrint('[Socket] Connected to server');
      if (_isTracking && _trackedRiderId != null) {
        _socket!.emit('join_room', 'driver_$_trackedRiderId');
      }
    });
    _socket!.onDisconnect((_) => debugPrint('[Socket] Disconnected'));
  }

  Future<bool> _handlePermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  String? _trackedOrderId;

  Future<void> startTracking(String orderId, String riderId, String riderName) async {
    if (_isTracking && _trackedOrderId == orderId) return;

    if (_isTracking) {
      stopTracking();
    }

    final hasPermission = await _handlePermissions();
    if (!hasPermission) {
      debugPrint('[Location] Permission Denied');
      return;
    }

    _isTracking = true;
    _trackedOrderId = orderId;
    _trackedRiderId = riderId;

    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      } else {
        _socket!.emit('join_room', 'driver_$riderId');
      }
    }

    // Emit current position immediately so it updates the backend instantly
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));
      if (_socket != null && _socket!.connected) {
        _socket!.emit('update_rider_location', {
          'orderId': orderId,
          'riderId': riderId,
          'riderName': riderName,
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('[Location] Sent immediate position for order $orderId: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      debugPrint('[Location] Error getting immediate position: $e');
    }

    LocationSettings locationSettings;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Delivery Partner app is active to receive orders and track location",
          notificationTitle: "Namba Delivery is Online",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (_socket != null && _socket!.connected) {
        _socket!.emit('update_rider_location', {
          'orderId': orderId,
          'riderId': riderId,
          'riderName': riderName,
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('[Location] Sent for order $orderId: ${position.latitude}, ${position.longitude}');
      }
    });
    debugPrint('[Location] Tracking Started for order: $orderId');
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    _trackedOrderId = null;
    debugPrint('[Location] Tracking Stopped');
  }

  void dispose() {
    stopTracking();
    _socket?.dispose();
  }
}
