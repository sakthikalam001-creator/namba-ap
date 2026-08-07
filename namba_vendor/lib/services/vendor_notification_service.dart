import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_service.dart';
import 'vendor_order_provider.dart';
import '../models/vendor_order_model.dart';
import '../main.dart';
import '../screens/orders/vendor_order_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _orderAlertChannelId = 'namba_vendor_call_alerts_v10';
const String _orderAlertChannelName = 'Vendor Order Alerts';
const String _orderAlertChannelDescription =
    'Urgent alerts for new incoming vendor orders';
const String _orderAlertSound = 'new_order_alert';

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
  final orderId = data['orderId']?.toString() ?? '';
  if (orderId.isEmpty) return;

  try {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('shown_notification_order_ids') ?? [];
    if (list.contains(orderId)) {
      debugPrint('🛡️ [BG NOTIF DUP] Blocked duplicate background notification for orderId $orderId');
      return;
    }
    list.add(orderId);
    await prefs.setStringList('shown_notification_order_ids', list);
    debugPrint('Added orderId $orderId to shown_notification_order_ids in background');
  } catch (e) {
    debugPrint('Error checking background notification duplicates: $e');
  }

  final plugin = FlutterLocalNotificationsPlugin();

  // Initialize plugin with background callback support
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(
    const InitializationSettings(android: androidSettings),
    onDidReceiveNotificationResponse: (response) {
      _handleNotificationAction(response.actionId, response.payload);
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  final sound = (data['alertSound']?.toString() != null && data['alertSound'].toString().isNotEmpty)
      ? data['alertSound'].toString()
      : _orderAlertSound;
  final channelId = 'namba_vendor_call_alerts_v10_$sound';

  // Play the alarm sound manually using AudioPlayer on the alarm stream to override silent/vibrate modes
  try {
    await VendorNotificationService()._playAlarmSoundOverride(sound);
  } catch (e) {
    debugPrint('Error playing background alarm sound: $e');
  }

  // Create / ensure the notification channel exists with custom sound
  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    AndroidNotificationChannel(
      channelId,
      _orderAlertChannelName,
      description: _orderAlertChannelDescription,
      importance: Importance.max,
      showBadge: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(sound),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
  );

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
        _orderAlertChannelName,
        channelDescription: _orderAlertChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF4F46E5),
        enableLights: true,
        // 🔑 FULL_SCREEN_INTENT: wakes the screen even when locked
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        ongoing: true,
        autoCancel: false,
        additionalFlags: Int32List.fromList(<int>[4]),
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          htmlFormatContentTitle: true,
        ),
        actions: [
          const AndroidNotificationAction('accept', 'ACCEPT', showsUserInterface: true),
          const AndroidNotificationAction('decline', 'DECLINE', showsUserInterface: true),
        ],
      ),
    ),
    payload: orderId,
  );
}

String _fallbackTitle(String orderType) {
  if (orderType == 'Text') return 'New list order received';
  if (orderType == 'Photo') return 'New photo order received';
  return 'New order received';
}

String _fallbackBody(String orderType) {
  if (orderType == 'Text') {
    return 'A customer sent a shopping list. Open Namba Vendor to review and quote.';
  }
  if (orderType == 'Photo') {
    return 'A customer uploaded item photos. Open Namba Vendor to review and quote.';
  }
  return 'A customer placed a cart order. Tap to view the order details.';
}

void _handleNotificationAction(String? actionId, String? payload) async {
  // Stop the alarm sound immediately
  try {
    VendorNotificationService().stopAlarmSound();
  } catch (e) {
    debugPrint('Error stopping alarm sound: $e');
  }

  if (payload == null) return;

  // Immediately cancel the notification to stop the looping sound
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    final baseId = payload.hashCode.abs() % 2147483647;
    final textId = '${payload}_text'.hashCode.abs() % 2147483647;
    final photoId = '${payload}_photo'.hashCode.abs() % 2147483647;
    await plugin.cancel(baseId);
    await plugin.cancel(textId);
    await plugin.cancel(photoId);
  } catch (e) {
    debugPrint('Error cancelling notification in action: $e');
  }

  // 🟢 Foreground service notification tapped → open dashboard, NOT order detail
  if (payload == 'dashboard') {
    debugPrint('Dashboard notification tapped → navigating to dashboard.');
    NambaVendorApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    return;
  }

  // Save the pending order ID to SharedPreferences so the main app/isolate can retrieve it
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_notification_order_id', payload);
    if (actionId != null) {
      await prefs.setString('pending_notification_action_id', actionId);
    } else {
      await prefs.remove('pending_notification_action_id');
    }
    debugPrint('Background notification click saved: orderId=$payload, action=$actionId');
  } catch (e) {
    debugPrint('Error saving notification payload in background: $e');
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
      VendorNotificationService.pendingOrderId = payload;
      if (VendorNotificationService.isMainShellActive) {
        final navState = NambaVendorApp.navigatorKey.currentState;
        if (navState != null) {
          navState.push(
            MaterialPageRoute(builder: (_) => VendorOrderDetailScreen(orderId: payload))
          );
        }
      } else {
        debugPrint('Main shell not active yet. Deferred pushing order detail for order: $payload');
      }
    }
  } catch (e) {
    debugPrint('Error handling notification action fallback: $e');
  }
}

class VendorNotificationService {
  static String? pendingOrderId;
  static bool isMainShellActive = false; // Prevents race condition during app cold start / splash screen
  static final VendorNotificationService _instance = VendorNotificationService._internal();
  factory VendorNotificationService() => _instance;
  VendorNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  OverlayEntry? _inAppBannerEntry;
  Timer? _inAppBannerTimer;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  bool _initialized = false;
  bool _firebaseReady = false;
  String? _boundVendorId;
  bool _tokenRefreshListenerAttached = false;
  bool _isRegisteringToken = false;
  Timer? _tokenRetryTimer;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    _orderAlertChannelId,
    _orderAlertChannelName,
    description: _orderAlertChannelDescription,
    importance: Importance.max,
    showBadge: true,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(_orderAlertSound),
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.notification,
  );

  static const AndroidNotificationChannel _fgChannel = AndroidNotificationChannel(
    'namaba_vendor_foreground_v3',
    'Vendor Active Background Engine',
    description: 'Keeps store socket active silently in background for order alerts',
    importance: Importance.low,
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
            AndroidInitializationSettings('@mipmap/ic_launcher');
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
      await _messaging.setAutoInitEnabled(true);

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
    if (vendorId.isEmpty) return;
    _boundVendorId = vendorId;

    await initialize();
    if (!_firebaseReady) {
      _scheduleTokenRetry();
      return;
    }

    unawaited(_registerCurrentFcmToken(vendorId));

    if (!_tokenRefreshListenerAttached) {
      _tokenRefreshListenerAttached = true;
      _messaging.onTokenRefresh.listen((token) {
        final activeVendorId = _boundVendorId;
        if (activeVendorId != null && activeVendorId.isNotEmpty) {
          _registerToken(vendorId: vendorId, token: token);
        }
      });
    }
  }

  void _scheduleTokenRetry() {
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      final activeVendorId = _boundVendorId;
      if (activeVendorId == null || activeVendorId.isEmpty) {
        timer.cancel();
        return;
      }
      await initialize();
      if (_firebaseReady) {
        await _registerCurrentFcmToken(activeVendorId);
        timer.cancel();
      }
    });
  }

  Future<void> _registerCurrentFcmToken(String vendorId) async {
    if (_isRegisteringToken) return;
    _isRegisteringToken = true;

    try {
      for (var attempt = 1; attempt <= 6; attempt++) {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _registerToken(vendorId: vendorId, token: token);
          return;
        }
        debugPrint('FCM token not ready yet. Retry $attempt/6');
        await Future.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('FCM token read error: $e');
    } finally {
      _isRegisteringToken = false;
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

  void _handleRemoteTap(RemoteMessage message) async {
    final orderId = message.data['orderId']?.toString();
    if (orderId == null || orderId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_notification_order_id', orderId);
      await prefs.remove('pending_notification_action_id'); // default tap / view action
      debugPrint('Saved remote tap pending notification: $orderId');
    } catch (e) {
      debugPrint('Error saving remote tap payload: $e');
    }

    if (VendorNotificationService.isMainShellActive) {
      final navState = NambaVendorApp.navigatorKey.currentState;
      if (navState != null) {
        // Clear SharedPreferences before navigating directly
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pending_notification_order_id');
        } catch (_) {}

        navState.push(
          MaterialPageRoute(builder: (_) => VendorOrderDetailScreen(orderId: orderId)),
        );
      }
    }
  }

  int _safeNotifId(String str) {
    return str.hashCode.abs() % 2147483647;
  }

  String _shortOrderId(String orderId, {int length = 6}) {
    if (orderId.isEmpty) return 'ORDER';
    final start = orderId.length > length ? orderId.length - length : 0;
    return orderId.substring(start).toUpperCase();
  }

  final Map<String, DateTime> _recentlyNotifiedOrders = {};

  bool _isDuplicateOrderNotification(String orderId) {
    if (orderId.isEmpty) return false;
    final now = DateTime.now();
    final lastTime = _recentlyNotifiedOrders[orderId];
    if (lastTime != null && now.difference(lastTime).inMinutes < 15) {
      debugPrint('🛡️ [NOTIF DUP] Blocked duplicate notification for orderId $orderId within 15m');
      return true;
    }
    _recentlyNotifiedOrders[orderId] = now;
    _recentlyNotifiedOrders.removeWhere((_, time) => now.difference(time).inMinutes > 30);
    return false;
  }

  Future<void> _markAsNotifiedLocally(String orderId) async {
    if (orderId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('shown_notification_order_ids') ?? [];
      if (!list.contains(orderId)) {
        list.add(orderId);
        await prefs.setStringList('shown_notification_order_ids', list);
        debugPrint('Marked orderId $orderId as notified locally in SharedPreferences');
      }
    } catch (e) {
      debugPrint('Error marking order as notified locally: $e');
    }
  }

  AudioPlayer? _alarmAudioPlayer;

  Future<void> _playAlarmSoundOverride(String? soundName) async {
    try {
      final sound = (soundName == null || soundName.isEmpty) ? 'new_order_alert' : soundName;
      _alarmAudioPlayer?.stop();
      _alarmAudioPlayer = AudioPlayer();
      await _alarmAudioPlayer!.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioMode: AndroidAudioMode.normal,
        ),
      ));
      await _alarmAudioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _alarmAudioPlayer!.play(AssetSource('sounds/$sound.wav'));
      debugPrint('🚨 [AUDIO OVERRIDE] Playing sound "$sound.wav" on ALARM audio stream (Overrides Silent/Vibrate Mode)');
    } catch (e) {
      debugPrint('⚠️ AudioPlayer error playing $soundName: $e');
    }
  }

  void stopAlarmSound() {
    try {
      _alarmAudioPlayer?.stop();
      _alarmAudioPlayer = null;
      debugPrint('🚨 [AUDIO OVERRIDE] Stopped alarm sound.');
    } catch (e) {
      debugPrint('⚠️ Error stopping alarm sound: $e');
    }
  }

  Future<void> showNewOrderNotification({
    required String orderId, 
    required String customerName, 
    required double amount,
    String? alertSound,
  }) async {
    if (_isDuplicateOrderNotification(orderId)) return;
    await _markAsNotifiedLocally(orderId);
    _playAlarmSoundOverride(alertSound);
    final shortId = _shortOrderId(orderId);
    await _show(
      id: _safeNotifId(orderId),
      title: '📦 New Order Received (#$shortId)',
      body: '👤 Customer: $customerName\n💰 Total Amount: ₹${amount.toStringAsFixed(0)}\n⚡ Tap to accept or review.',
      payload: orderId,
      soundName: alertSound,
      actions: [
        const AndroidNotificationAction('accept', '✅ ACCEPT', showsUserInterface: true),
        const AndroidNotificationAction('decline', '❌ DECLINE', showsUserInterface: true),
      ],
      isUrgentOrder: true,
    );
  }

  Future<void> showPaymentReceivedNotification({required String orderId, required double amount}) async {
    final shortId = _shortOrderId(orderId, length: 8);
    await _show(
      id: _safeNotifId('${orderId}_pay'),
      title: '💳 Payment Received (#$shortId)',
      body: '🎉 Payment of ₹${amount.toStringAsFixed(0)} received. Start preparing the items.',
      payload: orderId,
      actions: [
        const AndroidNotificationAction('view', '👁️ VIEW ORDER', showsUserInterface: true),
      ],
    );
  }

  Future<void> showTextOrderNotification({
    required String orderId, 
    required String preview, 
    required String customerName,
    String? alertSound,
  }) async {
    if (_isDuplicateOrderNotification(orderId)) return;
    await _markAsNotifiedLocally(orderId);
    _playAlarmSoundOverride(alertSound);
    final shortId = _shortOrderId(orderId);
    final cleanPreview = preview.trim().isEmpty ? 'shopping list' : preview.trim();
    final shortPreview = cleanPreview.length > 70 ? '${cleanPreview.substring(0, 70)}...' : cleanPreview;
    await _show(
      id: _safeNotifId(orderId),
      title: '🛍️ New List Order (#$shortId)',
      body: '👤 Customer: $customerName\n📝 List: "$shortPreview"\n⚡ Review it and send a quote.',
      payload: orderId,
      soundName: alertSound,
      actions: [
        const AndroidNotificationAction('accept', '✅ ACCEPT', showsUserInterface: true),
        const AndroidNotificationAction('decline', '❌ DECLINE', showsUserInterface: true),
      ],
      isUrgentOrder: true,
    );
  }

  Future<void> showPhotoOrderNotification({
    required String orderId, 
    required String customerName,
    String? alertSound,
  }) async {
    if (_isDuplicateOrderNotification(orderId)) return;
    await _markAsNotifiedLocally(orderId);
    _playAlarmSoundOverride(alertSound);
    final shortId = _shortOrderId(orderId);
    await _show(
      id: _safeNotifId(orderId),
      title: '📸 New Photo Order (#$shortId)',
      body: '👤 Customer: $customerName\n🖼️ Action: Uploaded item photos. Review and send a quote.',
      payload: orderId,
      soundName: alertSound,
      actions: [
        const AndroidNotificationAction('accept', '✅ ACCEPT', showsUserInterface: true),
        const AndroidNotificationAction('decline', '❌ DECLINE', showsUserInterface: true),
      ],
      isUrgentOrder: true,
    );
  }

  Future<void> showOrderCancelledNotification({required String displayId, String? message}) async {
    final body = message ?? 'Order #$displayId has been cancelled.';
    await _show(
      id: _safeNotifId('${displayId}_cancel'),
      title: '🚫 Order Cancelled',
      body: body,
      payload: null,
      actions: [
        const AndroidNotificationAction('view', '👍 OK', showsUserInterface: true),
      ],
    );
  }

  Future<void> showTrialExpiredNotification({int daysExpired = 0}) async {
    final body = daysExpired > 0
        ? 'Your free trial ended $daysExpired day(s) ago. Subscribe now to keep your store live!'
        : 'Your free trial has ended today. Subscribe now to keep your store live!';
    await _show(
      id: 9999,
      title: '⏳ Trial Period Ended',
      body: body,
      payload: 'subscription',
      actions: [
        const AndroidNotificationAction('subscribe', '⭐ SUBSCRIBE NOW', showsUserInterface: true),
      ],
    );
  }

  Future<void> _show({
    required int id, 
    required String title, 
    required String body,
    String? payload,
    String? soundName,
    List<AndroidNotificationAction>? actions,
    bool isUrgentOrder = false,
  }) async {
    debugPrint('Notification: $title - $body');
    final sound = (soundName == null || soundName.isEmpty) ? _orderAlertSound : soundName;
    final channelId = 'namba_vendor_call_alerts_v10_$sound';
    
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final androidImpl = _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.createNotificationChannel(
          AndroidNotificationChannel(
            channelId,
            _orderAlertChannelName,
            description: _orderAlertChannelDescription,
            importance: Importance.max,
            showBadge: true,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(sound),
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );

        final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          channelId,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF2563EB),
          enableLights: true,
          fullScreenIntent: false,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(sound),
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          actions: actions,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          ),
          ongoing: false,
          autoCancel: true,
        );
        final NotificationDetails details = NotificationDetails(android: androidDetails);
        
        try {
          _showInAppBanner(title: title, body: body, payload: payload);
        } catch (bannerErr) {
          debugPrint('Error showing in-app banner: $bannerErr');
        }

        try {
          await _plugin.show(id, title, body, details, payload: payload);
        } catch (pluginErr) {
          debugPrint('Error showing local notification: $pluginErr');
        }
      } catch (e) {
        debugPrint('Error in notification _show: $e');
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

  void _showInAppBanner({
    required String title,
    required String body,
    String? payload,
  }) {
    final context = NambaVendorApp.navigatorKey.currentContext;
    final overlay = NambaVendorApp.navigatorKey.currentState?.overlay;
    debugPrint('🔔 [BANNER] Context: $context, Overlay: $overlay');
    if (context == null || overlay == null) {
      debugPrint('🔔 [BANNER] Skipping overlay insertion: context or overlay is null');
      return;
    }

    _inAppBannerTimer?.cancel();
    _inAppBannerEntry?.remove();

    _inAppBannerEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              _inAppBannerEntry?.remove();
              _inAppBannerEntry = null;
              if (payload != null && payload.isNotEmpty) {
                NambaVendorApp.navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => VendorOrderDetailScreen(orderId: payload),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFFA5B4FC),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_inAppBannerEntry!);
    _inAppBannerTimer = Timer(const Duration(seconds: 6), () {
      _inAppBannerEntry?.remove();
      _inAppBannerEntry = null;
    });
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

