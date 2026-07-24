import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../models/models.dart';
import '../main.dart';
import '../screens/order_details_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'namaba_orders',
    'Order Updates',
    description: 'Notifications for your Namaba order status',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (Platform.isWindows) return;
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // Create the Android notification channel
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
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

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'namaba_orders',
      'Order Updates',
      channelDescription: 'Notifications for your Namaba order status',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details =
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
    String title = '🧾 Bill Quote Received!';
    String body = '$storeName has sent a bill quote of ₹${amount.toStringAsFixed(0)}. Tap to view bill & pay.';
    if (textContent != null && textContent.isNotEmpty) {
      body = '$storeName sent a quote of ₹${amount.toStringAsFixed(0)} for items:\n${textContent.length > 50 ? '${textContent.substring(0, 50)}...' : textContent}';
    }

    if (Platform.isWindows) {
      _showWindowsFallback(title: title, body: body, payload: orderId);
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'namaba_orders',
      'Order Updates',
      channelDescription: 'Notifications for your Namaba order status',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.show(
      orderId.hashCode + 5000,
      title,
      body,
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
