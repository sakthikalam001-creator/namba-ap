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
        .enableAutoConnect()
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(3000)
        .setReconnectionAttempts(999999)
        .enableForceNew()
        .build()
    );
    _socket!.connect();
    
    _socket!.onConnect((_) {
      debugPrint('[Socket] Connected to server');
      if (_isTracking && _trackedRiderId != null) {
        _socket!.emit('join_room', 'driver_$_trackedRiderId');
      }
    });
    _socket!.onReconnect((_) {
      debugPrint('[Socket] Reconnected to server');
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

    if (permission == LocationPermission.whileInUse) {
      try {
        permission = await Geolocator.requestPermission();
      } catch (_) {}
    }
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
      if (_socket != null) {
        if (!_socket!.connected) _socket!.connect();
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
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Online & tracking location continuously in background.",
          notificationTitle: "🟢 Namba Delivery Partner Active",
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 2,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      );
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (_socket != null) {
        if (!_socket!.connected) _socket!.connect();
        _socket!.emit('update_rider_location', {
          'orderId': orderId,
          'riderId': riderId,
          'riderName': riderName,
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('[Location Background Stream] Sent for $riderName ($orderId): ${position.latitude}, ${position.longitude}');
      }
    });
    debugPrint('[Location] Background Tracking Started for rider $riderId (order: $orderId)');
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
