import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../main.dart';
import '../screens/order_details_screen.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _alertTimeoutTimer;

  // Single-display tracking to prevent multiple popup sheets
  bool _isQuoteSheetOpen = false;
  final Set<String> _shownQuoteKeys = {};

  static const List<String> availableSounds = [
    'new_order_alert',
    'bell_ring',
    'loud_alarm',
    'chime_alert',
  ];

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'namaba_orders_v6_chime',
    'Order Updates',
    description: 'Notifications for your Namaba order status',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('chime_alert'),
    enableVibration: true,
  );

  Future<void> initialize() async {
    if (Platform.isWindows) return;
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        stopQuoteAlertSound();
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          final context = NambaApp.navigatorKey.currentContext;
          if (context != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: payload)));
          }
        }
      },
    );

    // Create the Android notification channels (1 standard + 4 ringtone channels for accurate dynamic sound)
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);

    for (final s in availableSounds) {
      await androidImpl?.createNotificationChannel(
        AndroidNotificationChannel(
          'namba_customer_quote_channel_v6_$s',
          'Bill Quote Alerts ($s)',
          description: 'Urgent sound and ringtone notifications for price quote updates',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(s),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
    }
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

  Future<bool> requestNotificationPermission() async {
    if (Platform.isWindows) return true;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final bool? granted = await androidImpl?.requestNotificationsPermission();
      final bool enabled = await areNotificationsEnabled();
      return (granted == true) || enabled;
    } catch (e) {
      debugPrint('requestNotificationPermission error: $e');
      return false;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } catch (_) {
      try {
        await AppSettings.openAppSettings();
      } catch (e) {
        debugPrint('openNotificationSettings error: $e');
      }
    }
  }

  Future<void> showTestNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language_code') ?? 'en';
    final isTa = langCode == 'ta';
    final isTg = langCode == 'tanglish';

    final storeName = isTa ? 'நம்பா எக்ஸ்பிரஸ்' : 'Namba Express';
    final customTitle = isTa
        ? '🔔 அறிவிப்பு இயக்கப்பட்டது!'
        : (isTg ? '🔔 Notification Alert Active-la Irukku!' : '🔔 Notification Alert Active!');
    final customBody = isTa
        ? '🎉 நேரலை ஆர்டர் விபரங்கள் மற்றும் டெலிவரி அறிவிப்புகள் இந்த மொபைலில் தயாராக உள்ளன!'
        : (isTg
            ? '🎉 Live order updates matrum delivery alerts unga device-la active-aa irukku!'
            : '🎉 Live order updates, store quotes, and delivery notifications are active on your device!');

    await showOrderNotification(
      orderId: 'test_${DateTime.now().millisecondsSinceEpoch}',
      status: OrderStatus.accepted,
      storeName: storeName,
      customTitle: customTitle,
      customBody: customBody,
    );
    await playQuoteAlertSound();
  }

  Future<void> checkAndPromptNotificationPermission(BuildContext context) async {
    if (Platform.isWindows) return;
    try {
      // ONLY ASK ONCE: Check if we have already prompted the user before
      final prefs = await SharedPreferences.getInstance();
      final bool alreadyPrompted = prefs.getBool('has_prompted_notification_permission') ?? false;
      if (alreadyPrompted) {
        return; // Do not ask repeatedly!
      }

      // Mark as prompted immediately so it never pops up again automatically
      await prefs.setBool('has_prompted_notification_permission', true);

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

  static String _cleanSound(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'new_order_alert';
    String s = raw.trim().replaceAll('.wav', '').replaceAll('.mp3', '').replaceAll('.ogg', '');
    if (!availableSounds.contains(s)) return 'new_order_alert';
    return s;
  }

  Future<void> playQuoteAlertSound([String? soundName]) async {
    try {
      stopQuoteAlertSound();
      final sound = _cleanSound(soundName);
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          stayAwake: true,
          audioFocus: AndroidAudioFocus.gainTransient,
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioMode: AndroidAudioMode.normal,
        ),
      ));
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/$sound.wav'));
      debugPrint('🔔 [Customer Audio] Looping quote alert: $sound.wav on ALARM stream (call-style)');

      // Safety timeout: stop ringing after 40 seconds (like an unanswered phone call)
      _alertTimeoutTimer?.cancel();
      _alertTimeoutTimer = Timer(const Duration(seconds: 40), () {
        stopQuoteAlertSound();
      });
    } catch (e) {
      debugPrint('⚠️ [Audio] Quote alert sound play error: $e');
    }
  }

  void stopQuoteAlertSound() {
    _alertTimeoutTimer?.cancel();
    try {
      _audioPlayer.stop();
    } catch (_) {}
  }

  Future<void> playNotificationSound([String? soundName]) async {
    try {
      final sound = _cleanSound(soundName ?? 'chime_alert');
      final player = AudioPlayer();
      await player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          stayAwake: true,
          audioFocus: AndroidAudioFocus.gainTransient,
          usageType: AndroidUsageType.notification,
          contentType: AndroidContentType.sonification,
          audioMode: AndroidAudioMode.normal,
        ),
      ));
      await player.setVolume(1.0);
      await player.play(AssetSource('sounds/$sound.wav'));
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      debugPrint('⚠️ [Customer Audio] playNotificationSound error: $e');
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

    // Trigger audible chime alert sound
    playNotificationSound('chime_alert');

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
      'namaba_orders_v6_chime',
      'Order Updates',
      channelDescription: 'Notifications for your Namaba order status',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('chime_alert'),
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
      payload: orderId,
    );
  }

  Future<void> showQuoteNotification({
    required String orderId,
    required String storeName,
    double? totalAmount,
    double? amount,
    double? shopBill,
    double? deliveryFee,
    double? discount,
    double? platformFee,
    String? textContent,
    String? alertSound,
  }) async {
    final double finalFee = deliveryFee ?? 30.0;
    final double finalDiscount = discount ?? 0.0;
    final double finalBill = shopBill ?? 0.0;
    final double finalPlatform = platformFee ?? 5.0;
    final double calculatedTotal = (finalBill - finalDiscount) + finalFee + finalPlatform;
    final double finalTotal = (totalAmount != null && totalAmount > 0)
        ? totalAmount
        : ((amount != null && amount > 0)
            ? amount
            : (calculatedTotal > 0 ? calculatedTotal : 0.0));
    final double effectiveTotal = finalTotal > 0 ? finalTotal : calculatedTotal;

    final String shortId = orderId.length > 6 ? '#${orderId.substring(orderId.length - 6).toUpperCase()}' : '#$orderId';
    final quoteTitle = '🧾 Bill Quote Ready: ₹${effectiveTotal.toStringAsFixed(0)}';
    
    // Ultra-clean HTML formatted body for expandable Android Notification
    final String discountHtml = finalDiscount > 0
        ? '🏷️ Shop Discount: <b><font color="#059669">-₹${finalDiscount.toStringAsFixed(0)}</font></b><br>'
        : '';
    final String platformHtml = finalPlatform > 0
        ? '⚡ Platform Fee: <b><font color="#D97706">+₹${finalPlatform.toStringAsFixed(0)}</font></b><br>'
        : '';
    final quoteBody = '🏬 <b>$storeName</b><br>'
        '🛍️ Shop Bill: <b>₹${finalBill.toStringAsFixed(0)}</b><br>'
        '$discountHtml'
        '🛵 Delivery Fee: <b>+₹${finalFee.toStringAsFixed(0)}</b><br>'
        '$platformHtml'
        '💳 <b>Total Payable: <font color="#059669">₹${effectiveTotal.toStringAsFixed(0)}</font></b><br>'
        '👉 <b>Tap to view bill & make payment</b>';

    final sound = _cleanSound(alertSound);

    // Play in-app loud call-style loop ringtone immediately
    playQuoteAlertSound(sound);

    if (Platform.isWindows) {
      _showWindowsFallback(
        title: quoteTitle,
        body: '$storeName • Shop Bill ₹${finalBill.toStringAsFixed(0)} + Delivery ₹${finalFee.toStringAsFixed(0)} + Platform ₹${finalPlatform.toStringAsFixed(0)} = Total ₹${effectiveTotal.toStringAsFixed(0)}',
        payload: orderId,
      );
      return;
    }

    final bigTextStyle = BigTextStyleInformation(
      quoteBody,
      htmlFormatBigText: true,
      contentTitle: '<b>$quoteTitle</b>',
      htmlFormatContentTitle: true,
      summaryText: 'Namba Express • Total: ₹${effectiveTotal.toStringAsFixed(0)} • $shortId',
      htmlFormatSummaryText: true,
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'namba_customer_quote_channel_v6_$sound',
      'Bill Quote Alerts ($sound)',
      channelDescription: 'Urgent sound and ringtone notifications for price quote updates',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(sound),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFEF4444),
      styleInformation: bigTextStyle,
      subText: shortId,
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    // Play looping alarm ringtone for bill quote
    playQuoteAlertSound(sound);

    await _plugin.show(
      orderId.hashCode + 5000,
      quoteTitle,
      'Shop Bill: ₹${finalBill.toStringAsFixed(0)} + Delivery: ₹${finalFee.toStringAsFixed(0)} + Platform: ₹${finalPlatform.toStringAsFixed(0)} = Total: ₹${effectiveTotal.toStringAsFixed(0)}',
      details,
      payload: orderId,
    );

    // In-app interactive BottomSheet with strict deduplication (shown ONCE only)
    _showInAppQuoteDialog(
      orderId: orderId,
      storeName: storeName,
      shopBill: finalBill,
      deliveryFee: finalFee,
      discount: finalDiscount,
      platformFee: finalPlatform,
      totalAmount: effectiveTotal,
    );
  }

  void _showInAppQuoteDialog({
    required String orderId,
    required String storeName,
    required double shopBill,
    required double deliveryFee,
    required double totalAmount,
    double? discount,
    double? platformFee,
  }) {
    final String quoteKey = '${orderId}_${totalAmount.toStringAsFixed(0)}';

    // STRICT CHECK: If already open or already shown for this order and quote total, do not show again!
    if (_isQuoteSheetOpen || _shownQuoteKeys.contains(quoteKey)) {
      debugPrint('[NotificationService] Quote popup already open or already shown for $quoteKey. Skipping.');
      return;
    }

    try {
      final context = NambaApp.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      _isQuoteSheetOpen = true;
      _shownQuoteKeys.add(quoteKey);

      final double finalDiscount = discount ?? 0.0;
      final double finalPlatform = platformFee ?? 5.0;
      final lang = Provider.of<CustomerLanguageProvider>(context, listen: false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 25,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Card with verified badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                lang.text(
                                  en: 'Bill Quote Ready',
                                  ta: 'விலைப்பட்டியல் தயார்',
                                  tanglish: 'Bill Quote Vandhuduchu',
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  lang.text(
                                    en: 'PAYMENT READY',
                                    ta: 'பணம் செலுத்தலாம்',
                                    tanglish: 'PAYMENT READY',
                                  ),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  storeName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF475569),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Itemized Bill Box with Full Pricing Clarity
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.text(
                          en: 'BILL BREAKDOWN',
                          ta: 'விலைப்பட்டியல் விவரம்',
                          tanglish: 'BILL VIVARAM',
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Shop Bill MRP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lang.text(
                              en: '🛍️ Shop Bill:',
                              ta: '🛍️ பொருட்கள் விலை:',
                              tanglish: '🛍️ Kadai Bill:',
                            ),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          Text(
                            '₹${shopBill.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      // Discount (if any)
                      if (finalDiscount > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  lang.text(
                                    en: '🏷️ Store Discount:',
                                    ta: '🏷️ கடை தள்ளுபடி:',
                                    tanglish: '🏷️ Kadai Discount:',
                                  ),
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '-₹${finalDiscount.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Delivery Fee
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lang.text(
                              en: '🛵 Delivery Fee:',
                              ta: '🛵 டெலிவரி கட்டணம்:',
                              tanglish: '🛵 Delivery Charge:',
                            ),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          Text(
                            '+₹${deliveryFee.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      // Platform Fee (if applicable)
                      if (finalPlatform > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang.text(
                                en: '⚡ Platform Fee:',
                                ta: '⚡ தள கட்டணம்:',
                                tanglish: '⚡ Platform Charge:',
                              ),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            Text(
                              '+₹${finalPlatform.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Color(0xFFCBD5E1), height: 1),
                      ),
                      // Total Payable
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.text(
                                  en: 'TOTAL PAYABLE',
                                  ta: 'செலுத்த வேண்டிய தொகை',
                                  tanglish: 'MOTHTHA AMOUNT',
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                lang.text(
                                  en: 'Final Amount',
                                  ta: 'இறுதி தொகை',
                                  tanglish: 'Kadaisi Amount',
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${totalAmount.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      if (finalDiscount > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.celebration_rounded, size: 15, color: Color(0xFF059669)),
                              const SizedBox(width: 6),
                              Text(
                                lang.text(
                                  en: 'You are saving ₹${finalDiscount.toStringAsFixed(0)} on this order!',
                                  ta: 'இந்த ஆர்டரில் ₹${finalDiscount.toStringAsFixed(0)} சேமிக்கிறீர்கள்!',
                                  tanglish: 'Indha order-la ₹${finalDiscount.toStringAsFixed(0)} micham!',
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Action CTA
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      stopQuoteAlertSound();
                      Navigator.pop(ctx);
                      // Check if customer is already on OrderDetailsScreen
                      bool isAlreadyOnOrderDetails = false;
                      context.visitAncestorElements((element) {
                        if (element.widget is OrderDetailsScreen) {
                          isAlreadyOnOrderDetails = true;
                          return false;
                        }
                        return true;
                      });
                      if (!isAlreadyOnOrderDetails) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: 'OrderDetailsScreen'),
                            builder: (_) => OrderDetailsScreen(orderId: orderId),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.credit_card_rounded, size: 20),
                    label: Text(
                      lang.text(
                        en: 'VIEW BILL & PAY (₹${totalAmount.toStringAsFixed(0)})',
                        ta: 'பணம் செலுத்த தொடரவும் (₹${totalAmount.toStringAsFixed(0)})',
                        tanglish: 'BILL PAARTHU PAY PANNU (₹${totalAmount.toStringAsFixed(0)})',
                      ),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    stopQuoteAlertSound();
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    lang.text(
                      en: 'Pay Later',
                      ta: 'பிறகு செலுத்தவும்',
                      tanglish: 'Apparam Katturen',
                    ),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).then((_) {
        _isQuoteSheetOpen = false;
        stopQuoteAlertSound();
      });
    } catch (e) {
      _isQuoteSheetOpen = false;
      debugPrint('Error showing in-app quote dialog: $e');
    }
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
