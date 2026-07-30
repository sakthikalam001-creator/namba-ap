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

    // 2. Show top banner SnackBar alert if app is open
    final context = NambaVendorApp.navigatorKey.currentContext;
    if (context != null) {
      try {
        final shortId = orderId.length > 6 ? orderId.substring(orderId.length - 6).toUpperCase() : orderId.toUpperCase();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(top: 10, left: 16, right: 16),
            backgroundColor: const Color(0xFF1E1B4B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            duration: const Duration(seconds: 8),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4F46E5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type == 'Text' ? '📝 புதிய LIST ORDER! #$shortId' : type == 'Photo' ? '📸 புதிய PHOTO ORDER! #$shortId' : '🛒 புதிய ORDER! #$shortId',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Customer: $name ${amt > 0 ? '• ₹${amt.toStringAsFixed(0)}' : ''}',
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    NambaVendorApp.navigatorKey.currentState?.push(
                      MaterialPageRoute(builder: (_) => VendorOrderDetailScreen(orderId: orderId)),
                    );
                  },
                  child: const Text('VIEW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
        );
      } catch (e) {
        debugPrint('SnackBar error: $e');
      }
    }
  }

  Future<void> speak(String text) async {
    debugPrint("SPEAK: $text");
  }
}

