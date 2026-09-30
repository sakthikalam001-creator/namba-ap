import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/vendor_order_model.dart';
import 'language_provider.dart';
import 'vendor_notification_service.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;
  bool _isDialogShowing = false; // Prevents dialog stacking
  bool _isNewOrderDialogShowing = false;
  String? _activeShowingOrderId;
  String? get activeShowingOrderId => _activeShowingOrderId;
  final Set<String> _dismissedOrderIds = {};

  bool isOrderDismissed(String orderId) => _dismissedOrderIds.contains(orderId);
  void clearDismissedOrders() => _dismissedOrderIds.clear();

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
          Builder(
            builder: (actionCtx) {
              final lang = Provider.of<LanguageProvider>(actionCtx, listen: false);
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                    child: Text(
                      lang.text(en: 'Dismiss', ta: 'சரி', tanglish: 'Dismiss'),
                      style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      _isDialogShowing = false;
                      Navigator.of(ctx).pop();
                      onOpenNow?.call();
                    },
                    icon: const Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
                    label: Text(
                      lang.text(en: 'Go Online Now', ta: 'இப்போதே ஆன்லைனில் செல்ல', tanglish: 'Ippove Online Pannu'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ],
              );
            },
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

  /// Shows interactive popup dialog for new incoming order when vendor opens or views the app
  void showNewOrderPopup(VendorOrderModel order) {
    if (VendorNotificationService.activeOrderDetailOrderId == order.id) return;
    if (_isNewOrderDialogShowing) return;
    if (_dismissedOrderIds.contains(order.id)) return;

    final context = NambaVendorApp.navigatorKey.currentContext;
    if (context == null) return;

    final lang = Provider.of<LanguageProvider>(context, listen: false);

    _isNewOrderDialogShowing = true;
    _activeShowingOrderId = order.id;

    final isOffice = order.isOfficeDelivery;
    final isText = order.orderType == VendorOrderType.text;
    final isPhoto = order.orderType == VendorOrderType.photo;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            lang.text(
                              en: 'NEW ORDER',
                              ta: 'புதிய ஆர்டர்',
                              tanglish: 'PUDHU ORDER',
                            ),
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFDC2626),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (order.displayId.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${order.displayId}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF475569),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Customer & Office Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.person_rounded, color: Color(0xFF4F46E5), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName.isNotEmpty ? order.customerName : 'Customer',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF0F172A),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (order.customerPhone.isNotEmpty)
                            Text(
                              order.customerPhone,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isOffice)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '🏢 OFFICE',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1D4ED8),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Order Content Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isText
                                ? lang.text(en: '📝 SHOPPING LIST (TEXT)', ta: '📝 பொருட்கள் பட்டியல்', tanglish: '📝 ITEMS LIST (TEXT)')
                                : (isPhoto
                                    ? lang.text(en: '📸 PHOTO ORDER', ta: '📸 புகைப்பட ஆர்டர்', tanglish: '📸 PHOTO ORDER')
                                    : lang.text(en: '🛍️ CART ORDER', ta: '🛍️ கார்ட் ஆர்டர்', tanglish: '🛍️ CART ORDER')),
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF475569),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            (isText || isPhoto)
                                ? lang.text(en: 'Send Quote Bill', ta: 'பில் அனுப்பவும்', tanglish: 'Bill Quote Anuppunga')
                                : (order.totalAmount > 0 ? '₹${order.totalAmount.toStringAsFixed(0)}' : lang.text(en: 'Bill Pending', ta: 'பில் நிலுவையில்', tanglish: 'Bill Pending')),
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF059669),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      if (isText && order.textContent != null && order.textContent!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          order.textContent!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (!isText && !isPhoto && order.items.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${order.items.length} Item(s): ${order.items.map((i) => "${i.quantity}x ${i.name}").take(3).join(", ")}${order.items.length > 3 ? "..." : ""}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons (Dismiss / Review & Accept)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          _isNewOrderDialogShowing = false;
                          _activeShowingOrderId = null;
                          _dismissedOrderIds.add(order.id);
                          try {
                            VendorNotificationService().stopAlarmSound();
                          } catch (_) {}
                          Navigator.of(ctx).pop();
                        },
                        child: Text(
                          lang.text(en: 'LATER', ta: 'பிறகு', tanglish: 'APPARAM'),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            _isNewOrderDialogShowing = false;
                            _activeShowingOrderId = null;
                            try {
                              VendorNotificationService().stopAlarmSound();
                            } catch (_) {}
                            Navigator.of(ctx).pop();
                            VendorNotificationService.navigateToOrderDetails(order.id);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  lang.text(en: 'OPEN ORDER', ta: 'ஏற்கவும்', tanglish: 'ORDER THIRA'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      _isNewOrderDialogShowing = false;
      _activeShowingOrderId = null;
    });
  }

  Future<void> speak(String text) async {
    debugPrint("SPEAK: $text");
  }
}

