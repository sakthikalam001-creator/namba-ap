import 'package:flutter/material.dart';
import '../main.dart';
import 'vendor_notification_service.dart';
import '../screens/orders/vendor_order_detail_screen.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  void showAlert({required String title, required String message}) {
    final context = NambaVendorApp.navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Triggered when a new order arrives (both Cart, Text & Photo orders)
  Future<void> playNewOrderAlert(String orderId, {String? orderType, String? customerName, double? amount}) async {
    final type = orderType ?? 'Cart';
    final name = customerName ?? 'Customer';
    final amt = amount ?? 0.0;

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

    // In-app alert triggers native high-priority system notification (no bottom overlay card)
    return;
  }

  Future<void> speak(String text) async {
    debugPrint("SPEAK: $text");
  }
}

