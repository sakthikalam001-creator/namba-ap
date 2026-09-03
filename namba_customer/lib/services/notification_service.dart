import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io' show Platform;
import '../models/models.dart';
import '../main.dart';
import '../screens/order_details_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'namaba_orders_v5',
    'Order Updates',
    description: 'Notifications for your Namaba order status',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _quoteChannel = AndroidNotificationChannel(
    'namba_customer_quote_channel_v5',
    'Bill Quote Alerts',
    description: 'Urgent sound and ringtone notifications for price quote updates',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('new_order_alert'),
    enableVibration: true,
  );

  Future<void> initialize() async {
    if (Platform.isWindows) return;
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // Create the Android notification channels
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);
    await androidImpl?.createNotificationChannel(_quoteChannel);
    await androidImpl?.requestNotificationsPermission();
  }

  Future<bool> areNotificationsEnabled() async {
    if (Platform.isWindows) return true;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final bool? enabled = await androidImpl?.areNotificationsEnabled();
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> checkAndPromptNotificationPermission(BuildContext context) async {
    if (Platform.isWindows) return;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final bool? granted = await androidImpl?.requestNotificationsPermission();
      final bool enabled = await areNotificationsEnabled();

      if ((granted == false || !enabled) && context.mounted) {
        showModalBottomSheet(
          context: context,
          isDismissible: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFDC2626), size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enable Order & Quote Alerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Allow notifications so you never miss store bill quotes, price updates, and delivery alerts when your screen is locked or you are using other apps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await androidImpl?.requestNotificationsPermission();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('ALLOW NOTIFICATIONS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Maybe Later', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Notification Permission Prompt Error: $e');
    }
  }

  Future<void> playQuoteAlertSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.play(AssetSource('sounds/new_order_alert.wav'));
    } catch (e) {
      debugPrint('⚠️ [Audio] Quote alert sound play error: $e');
    }
  }

  Future<void> showOrderNotification({
    required String orderId,
    required OrderStatus status,
    required String storeName,
    String? customTitle,
    String? customBody,
  }) async {
    final (defTitle, defBody, icon) = _getNotificationContent(status, storeName);
    final title = customTitle ?? '$icon $defTitle';
    final body = customBody ?? defBody;

    if (Platform.isWindows) {
      _showWindowsFallback(title: title, body: body, payload: orderId);
      return;
    }

    final String shortId = orderId.length > 6 ? '#${orderId.substring(orderId.length - 6).toUpperCase()}' : '#$orderId';

    final bigTextStyle = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: '<b>$title</b>',
      htmlFormatContentTitle: true,
      summaryText: 'Namba Express • $shortId',
      htmlFormatSummaryText: true,
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'namaba_orders_v5',
      'Order Updates',
      channelDescription: 'Notifications for your Namaba order status',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.status,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFEF4444),
      styleInformation: bigTextStyle,
      subText: shortId,
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.show(
      orderId.hashCode,
      title,
      body,
      details,
    );
  }

  Future<void> showQuoteNotification({
    required String orderId,
    required String storeName,
    required double amount,
    String? textContent,
  }) async {
    final String shortId = orderId.length > 6 ? '#${orderId.substring(orderId.length - 6).toUpperCase()}' : '#$orderId';
    final quoteTitle = '🧾 Bill Quote Received: ₹${amount.toStringAsFixed(0)}';
    String quoteBody = '🏬 <b>$storeName</b> has sent your bill quote.<br>💰 <b>Amount:</b> <font color="#059669">₹${amount.toStringAsFixed(0)}</font><br>👉 <b>Tap to view bill & make payment</b>';
    if (textContent != null && textContent.isNotEmpty) {
      quoteBody = '🏬 <b>$storeName</b> sent a quote of <font color="#059669">₹${amount.toStringAsFixed(0)}</font><br>📝 <i>${textContent.length > 60 ? '${textContent.substring(0, 60)}...' : textContent}</i><br>👉 <b>Tap to view bill photo & pay</b>';
    }

    // Play in-app loud alert sound immediately
    playQuoteAlertSound();

    if (Platform.isWindows) {
      _showWindowsFallback(title: quoteTitle, body: '$storeName sent a quote of ₹${amount.toStringAsFixed(0)}', payload: orderId);
      return;
    }

    final bigTextStyle = BigTextStyleInformation(
      quoteBody,
      htmlFormatBigText: true,
      contentTitle: '<b>$quoteTitle</b>',
      htmlFormatContentTitle: true,
      summaryText: 'Namba Express • Bill Ready • $shortId',
      htmlFormatSummaryText: true,
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'namba_customer_quote_channel_v5',
      'Bill Quote Alerts',
      channelDescription: 'Urgent sound and ringtone notifications for price quote updates',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('new_order_alert'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFEF4444),
      styleInformation: bigTextStyle,
      subText: shortId,
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.show(
      orderId.hashCode + 5000,
      quoteTitle,
      '$storeName sent a quote of ₹${amount.toStringAsFixed(0)}',
      details,
    );
  }

  void _showWindowsFallback({required String title, required String body, String? payload}) {
    try {
      final context = NambaApp.navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $body'),
            duration: const Duration(seconds: 8),
            backgroundColor: const Color(0xFF4F46E5),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                if (payload != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: payload)));
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error showing Windows fallback: $e');
    }
  }

  (String, String, String) _getNotificationContent(
      OrderStatus status, String storeName) {
    switch (status) {
      case OrderStatus.placed:
        return (
          'Order Placed!',
          'Your order from $storeName has been confirmed.',
          '✅'
        );
      case OrderStatus.accepted:
        return (
          'Order Accepted!',
          'Your order is confirmed by $storeName. Preparing soon.',
          '🏪'
        );
      case OrderStatus.preparing:
        return (
          'Preparing Order',
          '$storeName is preparing your items. Hang tight!',
          '👨‍🍳'
        );
      case OrderStatus.assigned:
        return (
          'Rider Assigned',
          'A delivery partner is on the way to pick up your order.',
          '🚴'
        );
      case OrderStatus.ready:
        return (
          'Rider Reached Shop',
          'Your rider has arrived at $storeName and is collecting items.',
          '📍'
        );
      case OrderStatus.pickedUp:
        return (
          'Picked Up!',
          'Your rider is on the way to your location. Enjoy the wait!',
          '🚴'
        );
      case OrderStatus.outForDelivery:
        return (
          'Out for Delivery!',
          'Your order is on the way. Delivery partner is heading to you.',
          '🚴'
        );
      case OrderStatus.arrived:
        return (
          'Rider Arrived!',
          'Your rider is at your location. Please meet them.',
          '🏠'
        );
      case OrderStatus.delivered:
        return (
          'Delivered!',
          'Your order from $storeName has been delivered. Enjoy!',
          '🎉'
        );
      case OrderStatus.rejected:
        return (
          'Order Rejected',
          'Sorry, $storeName could not accept your order.',
          '❌'
        );
    }
  }
}
