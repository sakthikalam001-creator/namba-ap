import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'api_service.dart';
import 'vendor_order_provider.dart';
import '../models/vendor_order_model.dart';
import '../main.dart';
import '../screens/orders/vendor_order_detail_screen.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  _handleNotificationAction(notificationResponse.actionId, notificationResponse.payload);
}

void _handleNotificationAction(String? actionId, String? payload) async {
  if (payload == null) return;
  
  final context = NambaVendorApp.navigatorKey.currentContext;
  if (context != null) {
    try {
      final provider = Provider.of<VendorOrderProvider>(context, listen: false);
      if (actionId == 'accept') {
        await provider.updateOrderStatus(payload, VendorOrderStatus.accepted);
        debugPrint('Order $payload accepted via provider.');
        return;
      } else if (actionId == 'decline') {
        await provider.updateOrderStatus(payload, VendorOrderStatus.rejected);
        debugPrint('Order $payload declined via provider.');
        return;
      }
    } catch (e) {
      debugPrint('Error using provider for notification action: $e');
    }
  }

  // Fallback if context is not available
  final apiService = VendorApiService();
  
  try {
    if (actionId == 'accept') {
      await apiService.updateOrderStatus(payload, 'Accepted');
      debugPrint('Order $payload accepted from notification.');
    } else if (actionId == 'decline') {
      await apiService.updateOrderStatus(payload, 'Rejected');
      debugPrint('Order $payload declined from notification.');
    } else {
      // Default tap or "view" action -> Navigate to detail screen
      NambaVendorApp.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => VendorOrderDetailScreen(orderId: payload))
      );
    }
  } catch (e) {
    debugPrint('Error handling notification action fallback: $e');
  }
}

class VendorNotificationService {
  static final VendorNotificationService _instance = VendorNotificationService._internal();
  factory VendorNotificationService() => _instance;
  VendorNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'namaba_vendor_orders',
    'Vendor Order Alerts',
    description: 'Notifications for new orders and customer payments',
    importance: Importance.max,
    showBadge: true,
    playSound: true,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        const AndroidInitializationSettings androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
        
        await _plugin.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            _handleNotificationAction(response.actionId, response.payload);
          },
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
        );
        
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
        
        // Request permissions for Android 13+
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();

        final NotificationAppLaunchDetails? notificationAppLaunchDetails = 
            await _plugin.getNotificationAppLaunchDetails();
        if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
          final response = notificationAppLaunchDetails!.notificationResponse;
          if (response != null) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              _handleNotificationAction(response.actionId, response.payload);
            });
          }
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  Future<void> showNewOrderNotification({required String orderId, required String customerName, required double amount}) async {
    await _show(
      id: orderId.hashCode,
      title: '🛒 New Order!',
      body: '$customerName placed a new order.',
      payload: orderId,
      actions: [
        const AndroidNotificationAction('view', 'VIEW', showsUserInterface: true),
        const AndroidNotificationAction('accept', 'ACCEPT'),
        const AndroidNotificationAction('decline', 'DECLINE'),
      ],
    );
  }

  Future<void> showPaymentReceivedNotification({required String orderId, required double amount}) async {
    await _show(
      id: orderId.hashCode + 1000,
      title: '💰 Payment Received!',
      body: 'Payment Done for order #${orderId.substring(orderId.length > 8 ? orderId.length - 8 : 0)}. Start preparing!',
      payload: orderId,
      actions: [
        const AndroidNotificationAction('view', 'VIEW', showsUserInterface: true),
      ],
    );
  }

  Future<void> showTextOrderNotification({required String orderId, required String preview, required String customerName}) async {
    await _show(
      id: orderId.hashCode + 2000,
      title: '💬 New Shopping List Order!',
      body: '$customerName sent a list: "${preview.length > 50 ? '${preview.substring(0, 50)}...' : preview}"',
      payload: orderId,
      actions: [
        const AndroidNotificationAction('view', 'VIEW', showsUserInterface: true),
        const AndroidNotificationAction('accept', 'ACCEPT'),
        const AndroidNotificationAction('decline', 'DECLINE'),
      ],
    );
  }

  Future<void> showOrderCancelledNotification({required String displayId, String? message}) async {
    final body = message ?? 'Order #$displayId has been cancelled.';
    await _show(
      id: displayId.hashCode + 3000,
      title: '❌ Order Cancelled',
      body: body,
      payload: null,
      actions: [
        const AndroidNotificationAction('view', 'OK', showsUserInterface: true),
      ],
    );
  }

  Future<void> showTrialExpiredNotification({int daysExpired = 0}) async {
    final body = daysExpired > 0
        ? 'Your free trial ended $daysExpired day(s) ago. Subscribe now to keep your store live!'
        : 'Your free trial has ended today. Subscribe now to keep your store live!';
    await _show(
      id: 9999,
      title: '⚠️ Trial Period Ended!',
      body: body,
      payload: 'subscription',
      actions: [
        const AndroidNotificationAction('subscribe', 'SUBSCRIBE NOW', showsUserInterface: true),
      ],
    );
  }

  Future<void> _show({
    required int id, 
    required String title, 
    required String body,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    debugPrint('🔔 NOTIFICATION: $title - $body');
    
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'namaba_vendor_orders',
          'Vendor Order Alerts',
          channelDescription: 'Notifications for new orders and customer payments',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF4F46E5),
          enableLights: true,
          actions: actions,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          ),
          playSound: true,
          enableVibration: true,
        );
        final NotificationDetails details = NotificationDetails(android: androidDetails);
        await _plugin.show(id, title, body, details, payload: payload);
      } catch (e) {
        debugPrint('Error showing local notification: $e');
      }
    } else {
      // For Windows/Desktop, we use a global snackbar as fallback
      try {
        final context = NambaVendorApp.navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  if (payload != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VendorOrderDetailScreen(orderId: payload)),
                    );
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(body, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              duration: const Duration(seconds: 15),
              backgroundColor: const Color(0xFF1E1B4B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error showing fallback snackbar: $e');
      }
    }
  }
}

