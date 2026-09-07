import 'dart:async';

import 'package:flutter/material.dart';
import '../main.dart';
import 'vendor_notification_service.dart';
import '../screens/orders/vendor_order_detail_screen.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;
  bool _isDialogShowing = false; // Prevents dialog stacking

  void showAlert({required String title, required String message}) {
    if (_isDialogShowing) return; // Skip if a dialog is already showing

    final context = NambaVendorApp.navigatorKey.currentContext;
    if (context == null) return;

    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              _isDialogShowing = false;
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Interactive modal dialog for 10-minute store opening reminder with sound
  void showOpeningReminderDialog({
    required String title,
    required String message,
    VoidCallback? onOpenNow,
    VoidCallback? onDismiss,
  }) {
    if (_isDialogShowing) return;

    final context = NambaVendorApp.navigatorKey.currentContext;
    if (context == null) return;

    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.alarm_on_rounded, color: Color(0xFFD97706), size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Color(0xFF334155),
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              _isDialogShowing = false;
              Navigator.of(ctx).pop();
              onDismiss?.call();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: const Text(
              'சரி / Dismiss',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _isDialogShowing = false;
              Navigator.of(ctx).pop();
              onOpenNow?.call();
            },
            icon: const Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
            label: const Text(
              'இப்போதே Online செய்',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  static void showToast(String message, {bool isError = false}) {
    final context = NambaVendorApp.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void showTopBanner({
    required String title,
    required String message,
    Color color = const Color(0xFF1F2937),
    IconData icon = Icons.info_outline_rounded,
    Duration duration = const Duration(seconds: 4),
  }) {
    final context = NambaVendorApp.navigatorKey.currentContext;
    final overlay = NambaVendorApp.navigatorKey.currentState?.overlay;
    if (context == null || overlay == null) return;

    _bannerTimer?.cancel();
    _bannerEntry?.remove();

    _bannerEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(_bannerEntry!);
    _bannerTimer = Timer(duration, () {
      _bannerEntry?.remove();
      _bannerEntry = null;
    });
  }

  /// Triggered when a new order arrives (both Cart, Text & Photo orders)
  Future<void> playNewOrderAlert(String orderId, {String? orderType, String? customerName, double? amount, String? alertSound}) async {
    final type = orderType ?? 'Cart';
    final name = customerName ?? 'Customer';
    final amt = amount ?? 0.0;

    if (type == 'Text') {
      await VendorNotificationService().showTextOrderNotification(
        orderId: orderId,
        preview: 'Shopping List',
        customerName: name,
        alertSound: alertSound,
      );
    } else if (type == 'Photo') {
      await VendorNotificationService().showPhotoOrderNotification(
        orderId: orderId,
        customerName: name,
        alertSound: alertSound,
      );
    } else {
      await VendorNotificationService().showNewOrderNotification(
        orderId: orderId,
        customerName: name,
        amount: amt,
        alertSound: alertSound,
      );
    }

    // Notification sound & top status bar banner are triggered via VendorNotificationService
    debugPrint('🔔 [ALERT] New order alert triggered for orderId: $orderId (type: $type)');
  }

  Future<void> speak(String text) async {
    debugPrint("SPEAK: $text");
  }
}

