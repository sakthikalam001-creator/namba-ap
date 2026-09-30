import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';

const String _quoteAlertChannelBase = 'namba_customer_quote_channel_v6';
const String _orderStatusChannelId = 'namba_customer_order_status_v2';

// ─────────────────────────────────────────────────────────────────
// TOP-LEVEL entry point — runs in a separate Isolate
// ─────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void startCustomerCallback() {
  FlutterForegroundTask.setTaskHandler(CustomerBackgroundTaskHandler());
}

// ─────────────────────────────────────────────────────────────────
// TASK HANDLER — Background Socket.IO + Local Notification
// ─────────────────────────────────────────────────────────────────
class CustomerBackgroundTaskHandler extends TaskHandler {
  io.Socket? _socket;
  final fln.FlutterLocalNotificationsPlugin _notifPlugin =
      fln.FlutterLocalNotificationsPlugin();
  String? _customerId;
  String? _customerPhone;
  String? _socketUrl;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[CustomerBGTask] Background service started');
    await _initNotifications();
    await _loadConfig();
    if (_socketUrl != null &&
        ((_customerId != null && _customerId!.isNotEmpty) ||
            (_customerPhone != null && _customerPhone!.isNotEmpty))) {
      _connectSocket();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat every 30s: reconnect socket if disconnected
    if (_socket != null && !(_socket!.connected)) {
      debugPrint('[CustomerBGTask] Socket disconnected — reconnecting...');
      _socket!.connect();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _socket?.disconnect();
    _socket?.dispose();
    debugPrint('[CustomerBGTask] Background service stopped');
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _customerId = prefs.getString('bg_customer_id');
    _customerPhone = prefs.getString('bg_customer_phone');
    _socketUrl = prefs.getString('bg_socket_url') ?? 'http://54.204.9.126:5000';
    debugPrint('[CustomerBGTask] Loaded config: customerId=$_customerId phone=$_customerPhone socketUrl=$_socketUrl');
  }

  void _connectSocket() {
    final socketUrl = _socketUrl ?? 'http://54.204.9.126:5000';

    _socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 99999,
      'reconnectionDelay': 2000,
    });

    _socket!.onConnect((_) {
      debugPrint('[CustomerBGTask] Socket connected');
      _joinRooms();
    });

    _socket!.onReconnect((_) {
      debugPrint('[CustomerBGTask] Socket reconnected');
      _joinRooms();
    });

    _socket!.on('quote_received_alert', (data) async {
      debugPrint('[CustomerBGTask] 🚨 Quote received via background socket: $data');
      if (data == null) return;
      await _handleQuoteAlert(data);
    });

    _socket!.on('order_price_updated', (data) async {
      debugPrint('[CustomerBGTask] 💰 Price updated via background socket: $data');
      if (data == null) return;
      await _handleQuoteAlert(data);
    });

    _socket!.on('order_status_update', (data) async {
      debugPrint('[CustomerBGTask] 📦 Order status updated: $data');
      if (data == null) return;
      await _handleStatusUpdate(data);
    });

    _socket!.onDisconnect((_) => debugPrint('[CustomerBGTask] Socket disconnected'));
    _socket!.onError((e) => debugPrint('[CustomerBGTask] Socket error: $e'));
  }

  void _joinRooms() {
    if (_socket == null || !_socket!.connected) return;

    if (_customerId != null && _customerId!.isNotEmpty) {
      debugPrint('[CustomerBGTask] Joining customer_$_customerId');
      _socket!.emit('join_room', 'customer_$_customerId');
    }

    if (_customerPhone != null && _customerPhone!.isNotEmpty) {
      debugPrint('[CustomerBGTask] Joining customer_$_customerPhone');
      _socket!.emit('join_room', 'customer_$_customerPhone');

      final cleanPhone = _customerPhone!.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length >= 10) {
        final phoneSuffix = cleanPhone.substring(cleanPhone.length - 10);
        if (phoneSuffix != _customerPhone) {
          debugPrint('[CustomerBGTask] Joining customer_$phoneSuffix');
          _socket!.emit('join_room', 'customer_$phoneSuffix');
        }
      }
    }
  }

  Future<void> _initNotifications() async {
    const androidSettings = fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifPlugin.initialize(const fln.InitializationSettings(android: androidSettings));

    final androidPlugin = _notifPlugin
        .resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const fln.AndroidNotificationChannel(
        _orderStatusChannelId,
        'Order Status Updates',
        description: 'Updates when your order is placed, confirmed, or out for delivery',
        importance: fln.Importance.high,
        showBadge: true,
        playSound: true,
        sound: fln.RawResourceAndroidNotificationSound('chime_alert'),
        enableVibration: true,
      ),
    );
  }

  Future<String> _ensureSoundChannel(String soundName) async {
    final sound = soundName.isNotEmpty ? soundName : 'new_order_alert';
    final channelId = '${_quoteAlertChannelBase}_$sound';

    final androidPlugin = _notifPlugin
        .resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      fln.AndroidNotificationChannel(
        channelId,
        'Bill Quote Alerts ($sound)',
        description: 'Urgent sound alerts for shop quotes and bills',
        importance: fln.Importance.max,
        showBadge: true,
        playSound: true,
        sound: fln.RawResourceAndroidNotificationSound(sound),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        audioAttributesUsage: fln.AudioAttributesUsage.alarm,
      ),
    );
    return channelId;
  }

  Future<void> _handleQuoteAlert(dynamic data) async {
    try {
      if (data is! Map) return;
      final orderId = data['orderId']?.toString() ?? data['_id']?.toString() ?? '';
      if (orderId.isEmpty) return;

      final storeName = data['storeName']?.toString() ??
          data['customStoreName']?.toString() ??
          'Store';
      final double subTotal = (data['subTotal'] as num?)?.toDouble() ??
          (data['quoteAmount'] as num?)?.toDouble() ??
          0.0;
      final double discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
      final double deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ??
          (data['deliveryCharge'] as num?)?.toDouble() ??
          30.0;
      final double platformFee = (data['customerPlatformFee'] as num?)?.toDouble() ??
          (data['platformFee'] as num?)?.toDouble() ??
          5.0;

      final double calculatedTotal = (subTotal - discount) + deliveryFee + platformFee;
      final double totalAmount = (data['totalAmount'] as num?)?.toDouble() ??
          (calculatedTotal > 0 ? calculatedTotal : 0.0);
      final double effectiveTotal = totalAmount > 0 ? totalAmount : calculatedTotal;

      final soundName = data['alertSound']?.toString() ?? 'new_order_alert';
      final channelId = await _ensureSoundChannel(soundName);

      final shortId = orderId.length > 6
          ? orderId.substring(orderId.length - 6).toUpperCase()
          : orderId.toUpperCase();

      final notifTitle = '🧾 Bill Quote Ready: ₹${effectiveTotal.toStringAsFixed(0)}';
      final discountLine = discount > 0 ? ' • Disc: -₹${discount.toStringAsFixed(0)}' : '';
      final notifBody = '$storeName • Bill: ₹${subTotal.toStringAsFixed(0)}$discountLine + Delivery: ₹${deliveryFee.toStringAsFixed(0)} + Platform: ₹${platformFee.toStringAsFixed(0)} • Total: ₹${effectiveTotal.toStringAsFixed(0)}';

      final androidDetails = fln.AndroidNotificationDetails(
        channelId,
        'Bill Quote Alerts',
        channelDescription: 'High priority alerts for shop price quotes',
        importance: fln.Importance.max,
        priority: fln.Priority.max,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF10B981),
        enableLights: true,
        fullScreenIntent: true,
        category: fln.AndroidNotificationCategory.call,
        visibility: fln.NotificationVisibility.public,
        playSound: true,
        sound: fln.RawResourceAndroidNotificationSound(soundName),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        audioAttributesUsage: fln.AudioAttributesUsage.alarm,
        ongoing: true,
        autoCancel: false,
        additionalFlags: Int32List.fromList(<int>[4]),
        actions: [
          const fln.AndroidNotificationAction(
            'view_quote',
            'VIEW & PAY',
            showsUserInterface: true,
          ),
        ],
        styleInformation: fln.BigTextStyleInformation(
          '🏬 $storeName\n🛍️ Shop Bill: ₹${subTotal.toStringAsFixed(0)}${discount > 0 ? '\n🏷️ Discount: -₹${discount.toStringAsFixed(0)}' : ''}\n🛵 Delivery: +₹${deliveryFee.toStringAsFixed(0)}\n⚡ Platform: +₹${platformFee.toStringAsFixed(0)}\n💳 Total Payable: ₹${effectiveTotal.toStringAsFixed(0)}\n\n👉 Tap to view bill & make payment',
          contentTitle: notifTitle,
          summaryText: '#$shortId',
        ),
      );

      await _notifPlugin.show(
        orderId.hashCode.abs() % 2147483647,
        notifTitle,
        notifBody,
        fln.NotificationDetails(android: androidDetails),
        payload: orderId,
      );
    } catch (e) {
      debugPrint('[CustomerBGTask] Error showing quote notification: $e');
    }
  }

  Future<void> _handleStatusUpdate(dynamic data) async {
    try {
      if (data is! Map) return;
      final orderId = data['orderId']?.toString() ?? data['_id']?.toString() ?? '';
      final status = data['status']?.toString() ?? '';
      if (orderId.isEmpty || status.isEmpty) return;

      // Don't duplicate quote alerts via status update
      if (status == 'payment_pending' || status == 'quote_ready') return;

      final shortId = orderId.length > 6
          ? orderId.substring(orderId.length - 6).toUpperCase()
          : orderId.toUpperCase();

      String title = 'Order Update #$shortId';
      String body = 'Your order is being processed';

      switch (status) {
        case 'assigned':
          title = '🛵 Delivery Partner Assigned #$shortId';
          body = 'A rider is on the way to the store for your order.';
          break;
        case 'picked_up':
          title = '🛍️ Order Picked Up #$shortId';
          body = 'Your order has been picked up from the store and is heading to you!';
          break;
        case 'delivered':
          title = '🎉 Order Delivered #$shortId';
          body = 'Your order has been safely delivered. Thank you for using Namba Express!';
          break;
        case 'cancelled':
          title = '❌ Order Cancelled #$shortId';
          body = 'Your order has been cancelled.';
          break;
        default:
          return;
      }

      final androidDetails = fln.AndroidNotificationDetails(
        _orderStatusChannelId,
        'Order Status Updates',
        importance: fln.Importance.high,
        priority: fln.Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF4F46E5),
        playSound: true,
        sound: const fln.RawResourceAndroidNotificationSound('chime_alert'),
      );

      await _notifPlugin.show(
        (orderId.hashCode + 100).abs() % 2147483647,
        title,
        body,
        fln.NotificationDetails(android: androidDetails),
        payload: orderId,
      );
    } catch (e) {
      debugPrint('[CustomerBGTask] Error showing status update: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// PUBLIC API — called from the main app to manage the background service
// ─────────────────────────────────────────────────────────────────
class CustomerBackgroundService {
  static final CustomerBackgroundService _instance =
      CustomerBackgroundService._internal();
  factory CustomerBackgroundService() => _instance;
  CustomerBackgroundService._internal();

  /// Call once at app startup in main.dart
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'namba_customer_foreground_v2',
        channelName: 'Namba Customer Order Alerts',
        channelDescription: 'Keeps order tracking and instant bill quote alerts active in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000), // Heartbeat every 30s
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start background socket engine for customer
  static Future<void> startForCustomer({
    required String customerId,
    required String phone,
    String? socketUrl,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final url = socketUrl ?? 'http://54.204.9.126:5000';

    final prefs = await SharedPreferences.getInstance();
    if (customerId.isNotEmpty) {
      await prefs.setString('bg_customer_id', customerId);
    }
    if (cleanPhone.isNotEmpty) {
      await prefs.setString('bg_customer_phone', cleanPhone);
    }
    await prefs.setString('bg_socket_url', url);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 2001,
        notificationTitle: 'Namba Express • Order Live',
        notificationText: 'Listening for store bill quotes & order updates 🛵',
        callback: startCustomerCallback,
      );
    }
    debugPrint('[CustomerBGService] Foreground service started for customer: $customerId, phone: $cleanPhone');
  }

  /// Stop service (on customer logout)
  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bg_customer_id');
    await prefs.remove('bg_customer_phone');
    debugPrint('[CustomerBGService] Stopped');
  }
}
