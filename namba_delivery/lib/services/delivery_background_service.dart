import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'dart:typed_data';
import 'dart:convert';

const String _deliveryAlertChannelId = 'namba_delivery_order_alerts_v22';

// ─────────────────────────────────────────────────────────────────
// TOP-LEVEL entry point — runs in a separate Isolate when app is closed/locked
// ─────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void startDeliveryCallback() {
  FlutterForegroundTask.setTaskHandler(DeliveryBackgroundTaskHandler());
}

// ─────────────────────────────────────────────────────────────────
// TASK HANDLER — Background Socket.IO + Local Notification
// ─────────────────────────────────────────────────────────────────
class DeliveryBackgroundTaskHandler extends TaskHandler {
  io.Socket? _socket;
  final fln.FlutterLocalNotificationsPlugin _notifPlugin =
      fln.FlutterLocalNotificationsPlugin();
  String? _driverId;
  String? _socketUrl;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[RiderBGTask] Background service started');
    await _initNotifications();
    await _loadConfig();
    if (_driverId != null && _driverId!.isNotEmpty && _socketUrl != null) {
      _connectSocket();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat: reconnect socket if disconnected
    if (_socket != null && !(_socket!.connected)) {
      debugPrint('[RiderBGTask] Socket disconnected — reconnecting...');
      _socket!.connect();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _socket?.disconnect();
    _socket?.dispose();
    debugPrint('[RiderBGTask] Background service stopped');
  }

  // ── Load saved driverId & URLs from SharedPreferences ──
  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _driverId = prefs.getString('bg_driver_id');
    _socketUrl = prefs.getString('bg_socket_url') ?? 'http://54.204.9.126:5000';
    debugPrint('[RiderBGTask] Loaded config: driverId=$_driverId socketUrl=$_socketUrl');
  }

  // ── Socket Connection ──
  void _connectSocket() {
    final driverId = _driverId;
    if (driverId == null || driverId.isEmpty) return;

    _socket = io.io(_socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 99999,
      'reconnectionDelay': 2000,
    });

    _socket!.onConnect((_) {
      debugPrint('[RiderBGTask] Socket connected — joining room driver_$driverId');
      _socket!.emit('join_room', 'driver_$driverId');
    });

    _socket!.on('new_assignment', (data) async {
      debugPrint('[RiderBGTask] 🚨 New assignment event received via background socket: $data');
      if (data == null) return;

      try {
        final orderId = data['orderId']?.toString() ?? data['_id']?.toString() ?? '';
        final displayId = data['displayId']?.toString() ?? '';
        final vendorName = data['vendorName']?.toString() ?? data['storeName']?.toString() ?? 'Store';
        final paymentMethod = data['paymentMethod']?.toString() ?? 'COD';
        final driverEarnings = data['driverEarnings']?.toString() ?? '';
        final distanceKm = data['distanceKm']?.toString() ?? '';

        await _showNewOrderNotification(
          orderId: orderId,
          displayId: displayId,
          vendorName: vendorName,
          paymentMethod: paymentMethod,
          driverEarnings: driverEarnings,
          distanceKm: distanceKm,
        );
      } catch (e) {
        debugPrint('[RiderBGTask] Error showing notification in background socket: $e');
      }
    });
  }

  // ── Notification System ──
  Future<void> _initNotifications() async {
    const androidInit = fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = fln.InitializationSettings(android: androidInit);
    await _notifPlugin.initialize(initSettings);

    final androidPlugin = _notifPlugin
        .resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const fln.AndroidNotificationChannel(
          _deliveryAlertChannelId,
          'Rider New Order Alerts',
          description: 'Loud alert channel for incoming delivery assignments',
          importance: fln.Importance.max,
          playSound: true,
          sound: fln.RawResourceAndroidNotificationSound('new_order_alert'),
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFF00C853),
          showBadge: true,
          audioAttributesUsage: fln.AudioAttributesUsage.alarm,
        ),
      );
    }
  }

  Future<void> _showNewOrderNotification({
    required String orderId,
    required String displayId,
    required String vendorName,
    required String paymentMethod,
    required String driverEarnings,
    required String distanceKm,
  }) async {
    final payment = paymentMethod == 'COD' ? '💸 COD' : '💳 PAID';
    final earningsStr = driverEarnings.isNotEmpty ? 'Pay: ₹$driverEarnings' : '';
    final distStr = distanceKm.isNotEmpty ? ' ($distanceKm KM)' : '';
    final orderTag = displayId.isNotEmpty ? 'Order #$displayId' : (orderId.length >= 6 ? 'Order #${orderId.substring(0, 6)}' : 'Order');

    final androidDetails = fln.AndroidNotificationDetails(
      _deliveryAlertChannelId,
      'Rider New Order Alerts',
      channelDescription: 'Loud alert channel for incoming delivery assignments',
      importance: fln.Importance.max,
      priority: fln.Priority.max,
      fullScreenIntent: true,
      playSound: true,
      sound: const fln.RawResourceAndroidNotificationSound('new_order_alert'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
      enableLights: true,
      ledColor: const Color(0xFF00C853),
      ledOnMs: 500,
      ledOffMs: 500,
      ticker: '🚨 New Namba Delivery Request! $orderTag $earningsStr$distStr',
      visibility: fln.NotificationVisibility.public,
      category: fln.AndroidNotificationCategory.call,
      audioAttributesUsage: fln.AudioAttributesUsage.alarm,
    );

    await _notifPlugin.show(
      orderId.isNotEmpty ? orderId.hashCode : DateTime.now().millisecondsSinceEpoch,
      '🚨 New Delivery Request! $orderTag $earningsStr$distStr',
      '[$payment] $orderTag from $vendorName — $earningsStr$distStr — Tap to Accept',
      fln.NotificationDetails(android: androidDetails),
      payload: jsonEncode({
        'orderId': orderId,
        'displayId': displayId,
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SERVICE CONTROLLER — Start / Stop foreground service from UI Isolate
// ─────────────────────────────────────────────────────────────────
class DeliveryBackgroundService {
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'namba_delivery_fg_service_v2',
        channelName: 'Namba Rider Foreground Service',
        channelDescription: 'Keeps rider connected for instant order alerts.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000), // 15s heartbeat
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> requestPermissions() async {
    try {
      await Permission.notification.request();
      await Permission.location.request();
      await Permission.locationAlways.request();
      await Permission.systemAlertWindow.request();
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
      // Android 14+ — Request USE_FULL_SCREEN_INTENT permission for lock screen pop-up
      try {
        if (await Permission.manageExternalStorage.isDenied) {
          // ignore — not needed
        }
        // Full screen intent permission (Android 14+)
        final fsIntent = await FlutterForegroundTask.canScheduleExactAlarms;
        if (!fsIntent) {
          await FlutterForegroundTask.openAlarmsAndRemindersSettings();
        }
      } catch (_) {}
      try {
        final autoStartAvailable = await isAutoStartAvailable ?? false;
        if (autoStartAvailable) {
          await getAutoStartPermission();
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[Permission] Error requesting permissions: $e');
    }
  }

  static Future<bool> startService({
    required String driverId,
    required String socketUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bg_driver_id', driverId);
    await prefs.setString('bg_socket_url', socketUrl);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return true;
    }

    final ServiceRequestResult result = await FlutterForegroundTask.startService(
      serviceId: 201,
      notificationTitle: 'Namba Rider Active',
      notificationText: 'Online & ready for new delivery orders.',
      callback: startDeliveryCallback,
    );

    return result is ServiceRequestSuccess;
  }

  static Future<bool> stopService() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bg_driver_id');

    if (await FlutterForegroundTask.isRunningService) {
      final ServiceRequestResult result = await FlutterForegroundTask.stopService();
      return result is ServiceRequestSuccess;
    }
    return true;
  }
}
