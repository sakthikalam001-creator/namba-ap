import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_service.dart';
import 'vendor_order_provider.dart';
import '../models/vendor_order_model.dart';
import '../main.dart';
import '../screens/orders/vendor_order_detail_screen.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  _handleNotificationAction(notificationResponse.actionId, notificationResponse.payload);
}

/// ─────────────────────────────────────────────────────────────
/// BACKGROUND HANDLER — runs in a SEPARATE ISOLATE when app is killed.
/// MUST be top-level and MUST be as lightweight as possible.
/// We do NOT call VendorNotificationService().initialize() here —
/// that is too heavy and fails silently in a killed-app isolate.
/// Instead we directly show a local notification using a fresh plugin instance.
/// ─────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Background handler Firebase.initializeApp error: $e');
  }
  // Only handle new_order type messages
  if (message.data['type'] != 'new_order') return;
  await _showBackgroundOrderNotification(message.data);
}

/// Standalone notification display — no dependency on VendorNotificationService singleton.
/// Safe to call from a killed-app isolate.
Future<void> _showBackgroundOrderNotification(Map<String, dynamic> data) async {
  const channelId = 'namaba_vendor_loud_ringtone_v26';
  const channelName = 'Vendor Order Loud Alerts';

  final plugin = FlutterLocalNotificationsPlugin();

  // Initialize plugin minimally
  const androidSettings = AndroidInitializationSettings('ic_launcher');
  await plugin.initialize(const InitializationSettings(android: androidSettings));

  // Create / ensure the notification channel exists with custom sound
  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'High priority alerts for new incoming orders',
      importance: Importance.max,
      showBadge: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('new_order_alert'),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
  );

  final orderId = data['orderId']?.toString() ?? '';
  final orderType = data['orderType']?.toString() ?? 'Cart';
  // Use pre-built title/body sent in data payload from backend
  final title = data['notifTitle']?.toString() ?? _fallbackTitle(orderType);
  final body  = data['notifBody']?.toString()  ?? _fallbackBody(orderType);

  final notifId = orderId.hashCode.abs() % 2147483647;

  await plugin.show(
    notifId,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'High priority alerts for new incoming orders',
        importance: Importance.max,
        priority: Priority.max,
        icon: 'ic_launcher',
        color: const Color(0xFF4F46E5),
        enableLights: true,
        // 🔑 FULL_SCREEN_INTENT: wakes the screen even when locked
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('new_order_alert'),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          htmlFormatContentTitle: true,
        ),
        actions: [
          const AndroidNotificationAction('view', 'VIEW ORDER', showsUserInterface: true),
        ],
      ),
    ),
    payload: orderId,
  );
}

String _fallbackTitle(String orderType) {
  if (orderType == 'Text') return '📝 புதிய LIST ORDER வந்துச்சு!';
  if (orderType == 'Photo') return '📸 புதிய PHOTO ORDER வந்துச்சு!';
  return '🛒 புதிய ORDER வந்துச்சு!';
}

String _fallbackBody(String orderType) {
  if (orderType == 'Text') return 'Customer shopping list அனுப்பினாங்க — confirm பண்ணுங்க!';
  if (orderType == 'Photo') return 'Customer photo order அனுப்பினாங்க — பார்த்து quote கொடுங்க!';
  return 'New cart order received. Tap to view!';
}



void _handleNotificationAction(String? actionId, String? payload) async {
  if (payload == null) return;

  // 🟢 Foreground service notification tapped → open dashboard, NOT order detail
  if (payload == 'dashboard') {
    debugPrint('Dashboard notification tapped → navigating to dashboard.');
    NambaVendorApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    return;
  }
  
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
      // Default tap or "view" action → Navigate to order detail screen
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
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  bool _initialized = false;
  bool _firebaseReady = false;
  String? _boundVendorId;
  bool _tokenRefreshListenerAttached = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'namaba_vendor_loud_ringtone_v26',
    'Vendor Order Loud Alerts',
    description: 'High priority alerts for new incoming orders',
    importance: Importance.max,
    showBadge: true,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('new_order_alert'),
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  static const AndroidNotificationChannel _fgChannel = AndroidNotificationChannel(
    'namaba_vendor_foreground_v2',
    'Vendor Active Background Engine',
    description: 'Keeps store socket active silently in background for order alerts',
    importance: Importance.none,
    showBadge: false,
    playSound: false,
    enableVibration: false,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _initializeFirebaseMessaging();

        const AndroidInitializationSettings androidSettings =
            AndroidInitializationSettings('ic_launcher');
        const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
        
        await _plugin.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            _handleNotificationAction(response.actionId, response.payload);
          },
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
        );
        
        final androidImpl = _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.createNotificationChannel(_channel);
        await androidImpl?.createNotificationChannel(_fgChannel);
        
        // Request permissions for Android 13+
        await androidImpl?.requestNotificationsPermission();
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

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

  Future<void> _initializeFirebaseMessaging() async {
    if (_firebaseReady) return;

    final apiKey = dotenv.env['FIREBASE_API_KEY'];
    final appId = Platform.isAndroid
        ? dotenv.env['FIREBASE_ANDROID_APP_ID']
        : dotenv.env['FIREBASE_IOS_APP_ID'];
    final messagingSenderId = dotenv.env['FIREBASE_MESSAGING_SENDER_ID'];
    final projectId = dotenv.env['FIREBASE_PROJECT_ID'];

    try {
      if (Firebase.apps.isEmpty) {
        if ([apiKey, appId, messagingSenderId, projectId].every((v) => v != null && v.trim().isNotEmpty)) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: apiKey!,
              appId: appId!,
              messagingSenderId: messagingSenderId!,
              projectId: projectId!,
            ),
          );
        } else {
          // Default native initialization from google-services.json
          await Firebase.initializeApp();
          debugPrint('✅ Firebase initialized natively via google-services.json');
        }
      }

      // 🔑 CRITICAL: Enable top status-bar notification banner & sound when app is OPEN in foreground!
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_handleRemoteMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteTap);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        Future.delayed(const Duration(milliseconds: 1200), () => _handleRemoteTap(initialMessage));
      }

      _firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase push init error: $e');
    }
  }

  Future<void> bindVendor(String vendorId) async {
    await initialize();
    if (!_firebaseReady || vendorId.isEmpty) return;

    _boundVendorId = vendorId;
    await _registerCurrentFcmToken(vendorId);

    if (!_tokenRefreshListenerAttached) {
      _tokenRefreshListenerAttached = true;
      _messaging.onTokenRefresh.listen((token) {
        final activeVendorId = _boundVendorId;
        if (activeVendorId != null && activeVendorId.isNotEmpty) {
          _registerToken(vendorId: activeVendorId, token: token);
        }
      });
    }
  }

  Future<void> _registerCurrentFcmToken(String vendorId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(vendorId: vendorId, token: token);
      }
    } catch (e) {
      debugPrint('FCM token read error: $e');
    }
  }

  Future<void> _registerToken({required String vendorId, required String token}) async {
    final platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'unknown';
    final ok = await VendorApiService().registerVendorPushToken(
      vendorId: vendorId,
      token: token,
      platform: platform,
    );
    debugPrint(ok ? 'Vendor push token registered.' : 'Vendor push token registration failed.');
  }

  void handleBackgroundRemoteMessage(RemoteMessage message) {
    _handleRemoteMessage(message);
  }

  void _handleRemoteMessage(RemoteMessage message) {
    final orderId = message.data['orderId']?.toString();
    if (orderId == null || orderId.isEmpty) return;

    final type = message.data['type']?.toString();
    final orderType = message.data['orderType']?.toString() ?? 'Cart';

    if (type == 'new_order') {
      // ✅ FIX: Route to correct notification based on orderType
      if (orderType == 'Text') {
        showTextOrderNotification(
          orderId: orderId,
          preview: message.data['preview']?.toString() ?? 'Shopping List',
          customerName: message.data['customerName']?.toString() ?? 'Customer',
        );
      } else if (orderType == 'Photo') {
        showPhotoOrderNotification(
          orderId: orderId,
          customerName: message.data['customerName']?.toString() ?? 'Customer',
        );
      } else {
        showNewOrderNotification(
          orderId: orderId,
          customerName: message.data['customerName']?.toString() ?? 'Customer',
          amount: double.tryParse(message.data['amount']?.toString() ?? '0') ?? 0,
        );
      }
    }
  }

  void _handleRemoteTap(RemoteMessage message) {
    final orderId = message.data['orderId']?.toString();
    if (orderId == null || orderId.isEmpty) return;

    NambaVendorApp.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => VendorOrderDetailScreen(orderId: orderId)),
    );
  }

  int _safeNotifId(String str) {
    return str.hashCode.abs() % 2147483647;
  }

  Future<void> showNewOrderNotification({required String orderId, required String customerName, required double amount}) async {
    await _show(
      id: _safeNotifId(orderId),
      title: '🛍️ NEW ORDER RECEIVED!',
      body: 'Order #${orderId.substring(orderId.length > 6 ? orderId.length - 6 : 0)} from $customerName • Total: ₹${amount.toStringAsFixed(0)}',
      payload: orderId,
      actions: [
        const AndroidNotificationAction('accept', 'ACCEPT', showsUserInterface: true),
        const AndroidNotificationAction('view', 'VIEW', showsUserInterface: true),
      ],
    );
  }

  Future<void> showPaymentReceivedNotification({required String orderId, required double amount}) async {
    await _show(
      id: _safeNotifId('${orderId}_pay'),
      title: '💰 PAYMENT RECEIVED!',
      body: 'Payment Done for order #${orderId.substring(orderId.length > 8 ? orderId.length - 8 : 0)}. Start preparing items!',
      payload: orderId,
      actions: [
        const AndroidNotificationAction('view', 'VIEW', showsUserInterface: true),
      ],
    );
  }

  Future<void> showTextOrderNotification({required String orderId, required String preview, required String customerName}) async {
    await _show(
      id: _safeNotifId('${orderId}_text'),
      title: '📝 புதிய LIST ORDER வந்துச்சு!',
      body: '$customerName sent a list: "${preview.length > 50 ? '${preview.substring(0, 50)}...' : preview}"',
      payload: orderId,
      actions: [
        const AndroidNotificationAction('accept', 'ACCEPT', showsUserInterface: true),
        const AndroidNotificationAction('view', 'VIEW', showsUserInterface: true),
      ],
    );
  }

  Future<void> showPhotoOrderNotification({required String orderId, required String customerName}) async {
    await _show(
      id: _safeNotifId('${orderId}_photo'),
      title: '📸 புதிய PHOTO ORDER வந்துச்சு!',
      body: '$customerName uploaded a photo of items they need. Tap to view & quote a price.',
      payload: orderId,
      actions: [
        const AndroidNotificationAction('accept', 'ACCEPT', showsUserInterface: true),
        const AndroidNotificationAction('view', 'VIEW', showsUserInterface: true),
      ],
    );
  }

  Future<void> showOrderCancelledNotification({required String displayId, String? message}) async {
    final body = message ?? 'Order #$displayId has been cancelled.';
    await _show(
      id: _safeNotifId('${displayId}_cancel'),
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
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.max,
          icon: 'ic_launcher',
          color: const Color(0xFF4F46E5),
          enableLights: true,
          // 🔑 Wake screen even when locked / screen-off / foreground app
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          actions: actions,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          ),
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('new_order_alert'),
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
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

  static const int _foregroundNotifId = 8888;

  Future<void> startVendorForegroundService() async {
    // Actively cancel any lingering persistent notification
    await stopVendorForegroundService();
    return;
  }

  Future<void> stopVendorForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _plugin.cancel(_foregroundNotifId);
    } catch (e) {
      debugPrint('Error stopping vendor foreground notification: $e');
    }
  }
}

