import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

const String _orderAlertChannelId = 'namba_vendor_call_alerts_v1';

// ─────────────────────────────────────────────────────────────────
// TOP-LEVEL entry point — runs in a separate Isolate
// ─────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(VendorBackgroundTaskHandler());
}

// ─────────────────────────────────────────────────────────────────
// TASK HANDLER — Socket.IO + Local Notification (no Firebase)
// ─────────────────────────────────────────────────────────────────
class VendorBackgroundTaskHandler extends TaskHandler {
  io.Socket? _socket;
  final fln.FlutterLocalNotificationsPlugin _notifPlugin =
      fln.FlutterLocalNotificationsPlugin();
  String? _vendorId;
  String? _socketUrl;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[BGTask] Background service started');
    await _initNotifications();
    await _loadConfig();
    if (_vendorId != null && _socketUrl != null) {
      _connectSocket();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat every 30s: reconnect socket if disconnected
    if (_socket != null && !(_socket!.connected)) {
      debugPrint('[BGTask] Socket disconnected — reconnecting...');
      _socket!.connect();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _socket?.disconnect();
    _socket?.dispose();
    debugPrint('[BGTask] Background service stopped');
  }

  // ── Load saved vendorId & URLs from SharedPreferences ──
  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _vendorId = prefs.getString('bg_vendor_id');
    _socketUrl =
        prefs.getString('bg_socket_url') ?? 'http://54.204.9.126:5000';
    debugPrint(
        '[BGTask] Loaded config: vendorId=$_vendorId socketUrl=$_socketUrl');
  }

  // ── Socket Connection ──
  void _connectSocket() {
    final vendorId = _vendorId;
    if (vendorId == null || vendorId.isEmpty) return;

    _socket = io.io(_socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 99999,
      'reconnectionDelay': 2000,
    });

    _socket!.onConnect((_) {
      debugPrint('[BGTask] Socket connected — joining room vendor_$vendorId');
      _socket!.emit('join_room', 'vendor_$vendorId');
    });

    _socket!.on('new_order_alert', (data) async {
      debugPrint('[BGTask] 🔔 New order alert: $data');
      final orderId = data['orderId']?.toString() ?? '';
      final customerName = data['customerName']?.toString() ?? 'Customer';
      final amount = data['totalAmount']?.toString() ??
          data['amount']?.toString() ??
          '0';
      // ✅ FIX: Read orderType to show correct Tamil lock screen notification
      final orderType = data['orderType']?.toString() ?? 'Cart';

      if (orderType == 'Text') {
        await _showTextOrderNotification(
          orderId: orderId,
          customerName: customerName,
        );
      } else if (orderType == 'Photo') {
        await _showPhotoOrderNotification(
          orderId: orderId,
          customerName: customerName,
        );
      } else {
        await _showNewOrderNotification(
          orderId: orderId,
          customerName: customerName,
          amount: amount,
        );
      }
    });

    _socket!.on('vendor_payment_completed', (data) async {
      debugPrint('[BGTask] 💰 Payment completed: $data');
      final orderId = data['orderId']?.toString() ?? '';
      await _showPaymentNotification(orderId: orderId);
    });

    _socket!.onDisconnect((_) => debugPrint('[BGTask] Socket disconnected'));
    _socket!.onError((e) => debugPrint('[BGTask] Socket error: $e'));
  }

  // ── Init Local Notifications ──
  Future<void> _initNotifications() async {
    const androidSettings =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifPlugin
        .initialize(const fln.InitializationSettings(android: androidSettings));

    final androidPlugin = _notifPlugin
        .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
        const fln.AndroidNotificationChannel(
      _orderAlertChannelId,
      'Vendor Order Loud Alerts',
      description: 'High priority alerts for new incoming orders',
      importance: fln.Importance.max,
      showBadge: true,
      playSound: true,
      sound: fln.RawResourceAndroidNotificationSound('new_order_alert'),
      enableVibration: true,
      audioAttributesUsage: fln.AudioAttributesUsage.alarm,
    ));
  }

  // ── Show New Order Notification ──
  Future<void> _showNewOrderNotification({
    required String orderId,
    required String customerName,
    required String amount,
  }) async {
    final shortId = orderId.length > 6
        ? orderId.substring(orderId.length - 6).toUpperCase()
        : orderId.toUpperCase();
    final androidDetails = fln.AndroidNotificationDetails(
      _orderAlertChannelId,
      'Vendor Order Loud Alerts',
      channelDescription: 'High priority alerts for new incoming orders',
      importance: fln.Importance.max,
      priority: fln.Priority.max,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF4F46E5),
      enableLights: true,
      fullScreenIntent: true,
      category: fln.AndroidNotificationCategory.alarm,
      visibility: fln.NotificationVisibility.public,
      playSound: true,
      sound: const fln.RawResourceAndroidNotificationSound('new_order_alert'),
      enableVibration: true,
      audioAttributesUsage: fln.AudioAttributesUsage.alarm,
      ongoing: true,
      autoCancel: false,
      additionalFlags: Int32List.fromList(<int>[4]),
      actions: [
        const fln.AndroidNotificationAction('accept', 'ACCEPT',
            showsUserInterface: true),
        const fln.AndroidNotificationAction('decline', 'DECLINE',
            showsUserInterface: true),
      ],
      styleInformation: fln.BigTextStyleInformation(
        '$customerName placed an order • ₹$amount',
        contentTitle: '🛍️ NEW ORDER #$shortId',
        htmlFormatContentTitle: true,
      ),
    );
    await _notifPlugin.show(
      orderId.hashCode.abs() % 2147483647,
      '🛍️ NEW ORDER #$shortId',
      '$customerName placed an order • ₹$amount',
      fln.NotificationDetails(android: androidDetails),
      payload: orderId,
    );
  }

  // ── Show Payment Notification ──
  Future<void> _showPaymentNotification({required String orderId}) async {
    final shortId = orderId.length > 6
        ? orderId.substring(orderId.length - 6).toUpperCase()
        : orderId.toUpperCase();
    final androidDetails = fln.AndroidNotificationDetails(
      _orderAlertChannelId,
      'Vendor Order Loud Alerts',
      importance: fln.Importance.high,
      priority: fln.Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF10B981),
      playSound: true,
    );
    await _notifPlugin.show(
      '${orderId}_pay'.hashCode.abs() % 2147483647,
      '💰 PAYMENT RECEIVED!',
      'Payment done for Order #$shortId. Start preparing!',
      fln.NotificationDetails(android: androidDetails),
      payload: orderId,
    );
  }

  // ── Show Text Order Notification (LIST ORDER) ──
  Future<void> _showTextOrderNotification({
    required String orderId,
    required String customerName,
  }) async {
    final shortId = orderId.length > 6
        ? orderId.substring(orderId.length - 6).toUpperCase()
        : orderId.toUpperCase();
    final androidDetails = fln.AndroidNotificationDetails(
      _orderAlertChannelId,
      'Vendor Order Loud Alerts',
      channelDescription: 'High priority alerts for new incoming orders',
      importance: fln.Importance.max,
      priority: fln.Priority.max,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF059669),
      enableLights: true,
      fullScreenIntent: true,
      category: fln.AndroidNotificationCategory.alarm,
      visibility: fln.NotificationVisibility.public,
      playSound: true,
      sound: const fln.RawResourceAndroidNotificationSound('new_order_alert'),
      enableVibration: true,
      audioAttributesUsage: fln.AudioAttributesUsage.alarm,
      ongoing: true,
      autoCancel: false,
      additionalFlags: Int32List.fromList(<int>[4]),
      actions: [
        const fln.AndroidNotificationAction('accept', 'ACCEPT',
            showsUserInterface: true),
        const fln.AndroidNotificationAction('decline', 'DECLINE',
            showsUserInterface: true),
      ],
      styleInformation: fln.BigTextStyleInformation(
        '$customerName shopping list அனுப்பினாங்க — confirm பண்ணுங்க!',
        contentTitle: '📝 புதிய LIST ORDER #$shortId',
        htmlFormatContentTitle: true,
      ),
    );
    await _notifPlugin.show(
      '${orderId}_text'.hashCode.abs() % 2147483647,
      '📝 புதிய LIST ORDER #$shortId',
      '$customerName shopping list அனுப்பினாங்க — confirm பண்ணுங்க!',
      fln.NotificationDetails(android: androidDetails),
      payload: orderId,
    );
  }

  // ── Show Photo Order Notification (PHOTO ORDER) ──
  Future<void> _showPhotoOrderNotification({
    required String orderId,
    required String customerName,
  }) async {
    final shortId = orderId.length > 6
        ? orderId.substring(orderId.length - 6).toUpperCase()
        : orderId.toUpperCase();
    final androidDetails = fln.AndroidNotificationDetails(
      _orderAlertChannelId,
      'Vendor Order Loud Alerts',
      channelDescription: 'High priority alerts for new incoming orders',
      importance: fln.Importance.max,
      priority: fln.Priority.max,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF7C3AED),
      enableLights: true,
      fullScreenIntent: true,
      category: fln.AndroidNotificationCategory.alarm,
      visibility: fln.NotificationVisibility.public,
      playSound: true,
      sound: const fln.RawResourceAndroidNotificationSound('new_order_alert'),
      enableVibration: true,
      audioAttributesUsage: fln.AudioAttributesUsage.alarm,
      ongoing: true,
      autoCancel: false,
      additionalFlags: Int32List.fromList(<int>[4]),
      actions: [
        const fln.AndroidNotificationAction('accept', 'ACCEPT',
            showsUserInterface: true),
        const fln.AndroidNotificationAction('decline', 'DECLINE',
            showsUserInterface: true),
      ],
      styleInformation: fln.BigTextStyleInformation(
        '$customerName photo order அனுப்பினாங்க — பார்த்து quote கொடுங்க!',
        contentTitle: '📸 புதிய PHOTO ORDER #$shortId',
        htmlFormatContentTitle: true,
      ),
    );
    await _notifPlugin.show(
      '${orderId}_photo'.hashCode.abs() % 2147483647,
      '📸 புதிய PHOTO ORDER #$shortId',
      '$customerName photo order அனுப்பினாங்க — பார்த்து quote கொடுங்க!',
      fln.NotificationDetails(android: androidDetails),
      payload: orderId,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PUBLIC API — called from the main app to manage the service
// ─────────────────────────────────────────────────────────────────
class VendorBackgroundService {
  static final VendorBackgroundService _instance =
      VendorBackgroundService._internal();
  factory VendorBackgroundService() => _instance;
  VendorBackgroundService._internal();

  /// Call once at app startup to configure the foreground task
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'namaba_vendor_foreground_v4',
        channelName: 'Namba Vendor Store Engine',
        channelDescription: 'Keeps store online in background for instant order alerts',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction:
            ForegroundTaskEventAction.repeat(30000), // Heartbeat every 30s
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the background socket engine for a specific vendor
  static Future<void> startForVendor({
    required String vendorId,
    required String socketUrl,
  }) async {
    // Save config so the isolate can access it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bg_vendor_id', vendorId);
    await prefs.setString('bg_socket_url', socketUrl);

    // ✅ FIX: Actually start the foreground service so socket works on lock screen
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: 'Namba Vendor • Store Active',
        notificationText: 'Receiving orders in background 📦',
        callback: startCallback,
      );
    }
    debugPrint('[BGService] Foreground service started for vendor: $vendorId');
  }

  /// Stop the background engine (when vendor goes offline / logs out)
  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bg_vendor_id');
    debugPrint('[BGService] Stopped');
  }
}
