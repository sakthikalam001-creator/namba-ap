import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class LocationTrackingService {
  IO.Socket? _socket;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

  void initialize(String serverUrl) {
    _socket = IO.io(serverUrl, 
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build()
    );
    _socket!.connect();
    
    _socket!.onConnect((_) => debugPrint('[Socket] Connected to server'));
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

  Future<void> startTracking(String orderId, String riderId) async {
    if (_isTracking) return;
    
    final hasPermission = await _handlePermissions();
    if (!hasPermission) {
      debugPrint('[Location] Permission Denied');
      return;
    }

    _isTracking = true;
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      )
    ).listen((Position position) {
      if (_socket != null && _socket!.connected) {
        _socket!.emit('update_rider_location', {
          'orderId': orderId,
          'riderId': riderId,
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('[Location] Sent: ${position.latitude}, ${position.longitude}');
      }
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    debugPrint('[Location] Tracking Stopped');
  }

  void dispose() {
    stopTracking();
    _socket?.dispose();
  }
}
