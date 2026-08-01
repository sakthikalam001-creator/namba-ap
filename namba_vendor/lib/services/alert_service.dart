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
  Future<void> playNewOrderAlert(String orderId, {String? orderType, String? customerName, double? amount}) async {
    final type = orderType ?? 'Cart';
    final name = customerName ?? 'Customer';
    final amt = amount ?? 0.0;

    // 🌟 DIAGNOSTIC: Show visible in-app dialog and top banner immediately
    try {
      showAlert(
        title: '🚨 New Order Triggered!',
        message: 'Order: #$orderId\nCustomer: $name\nAmount: Rs. $amt\nType: $type',
      );
      
      showTopBanner(
        title: '🔔 NEW ORDER ALERT (V4)',
        message: 'New $type order from $name (Rs. $amt)',
        color: const Color(0xFFDC2626), // Vibrant Red
        icon: Icons.notifications_active_rounded,
        duration: const Duration(seconds: 10),
      );
    } catch (diagErr) {
      debugPrint('Error showing diagnostic alerts: $diagErr');
    }

    // 1. Play loud notification sound via VendorNotificationService
    if (type == 'Text') {
      await VendorNotificationService().showTextOrderNotification(
        orderId: orderId,
        preview: 'Shopping List',
        customerName: name,
      );
    } else if (type == 'Photo') {
      await VendorNotificationService().showPhotoOrderNotification(
        orderId: orderId,
        customerName: name,
      );
    } else {
      await VendorNotificationService().showNewOrderNotification(
        orderId: orderId,
        customerName: name,
        amount: amt,
      );
    }

    // Notification sound & top status bar banner are triggered via VendorNotificationService
    debugPrint('🔔 [ALERT] New order alert triggered for orderId: $orderId (type: $type)');
  }

  Future<void> speak(String text) async {
    debugPrint("SPEAK: $text");
  }
}

