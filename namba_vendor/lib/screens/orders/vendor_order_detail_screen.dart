import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../models/vendor_order_model.dart';
import '../../services/vendor_order_provider.dart';
import '../../services/language_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../profile/vendor_extra_screens.dart';
import '../../widgets/cancel_order_dialog.dart';
import '../../services/vendor_notification_service.dart';

class _QuoteCalculation {
  final double mrp;
  final double calculatedDiscount;
  final double calculatedRate;
  final double discountPercent;

  const _QuoteCalculation({
    required this.mrp,
    required this.calculatedDiscount,
    required this.calculatedRate,
    required this.discountPercent,
  });
}

class VendorOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const VendorOrderDetailScreen({super.key, required this.orderId});

  @override
  State<VendorOrderDetailScreen> createState() => _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState extends State<VendorOrderDetailScreen> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  bool _isPercentageMode = false;
  final Set<String> _playedUrgentSoundOrderIds = {};
  final Set<String> _playedOverdueSoundOrderIds = {};

  @override
  void initState() {
    super.initState();
    VendorNotificationService().stopAlarmSound();
    VendorNotificationService.activeOrderDetailOrderId = widget.orderId;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VendorNotificationService().stopAlarmSound();
      if (mounted) {
        final provider = Provider.of<VendorOrderProvider>(context, listen: false);
        final hasOrder = provider.orders.any((o) => o.id == widget.orderId);
        if (!hasOrder) {
          provider.refreshOrders();
        }
      }
    });
  }

  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    if (VendorNotificationService.activeOrderDetailOrderId == widget.orderId) {
      VendorNotificationService.activeOrderDetailOrderId = null;
    }
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VendorOrderProvider>(
      builder: (context, provider, _) {
        // Live lookup — always get latest version of this order from provider
        final orderOrNull = provider.orders.cast<VendorOrderModel?>().firstWhere(
          (o) => o?.id == widget.orderId,
          orElse: () => null,
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;
        if (orderOrNull == null) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: Text('Order Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.darkText)),
              backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
              elevation: 0,
            ),
            body: const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          );
        }
        final order = orderOrNull;
        return _buildScaffold(context, order);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, VendorOrderModel order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC), 
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : AppTheme.lightSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.transparent),
                        ),
                        child: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : AppTheme.darkText, size: 18),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Order ${order.displayId}',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.print_rounded, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText),
                onPressed: () {
                  String itemsText = '';
                  if (order.orderType == VendorOrderType.text) {
                    final parsed = _parseShoppingList(order.textContent ?? '');
                    if (parsed.isNotEmpty) {
                      itemsText = parsed.map((i) => i['type'] == 'note' ? 'Note: ${i['name']}' : '${i['index']}. ${i['name']} (${i['qty']})').join('\n');
                    } else {
                      itemsText = order.textContent ?? '';
                    }
                  } else {
                    itemsText = order.items.map((i) => '${i.quantity}x ${i.name} — ₹${(i.price * i.quantity).toStringAsFixed(0)}').join('\n');
                  }

                  showPrintOrderDialog(
                    context,
                    orderId: order.id,
                    items: itemsText,
                    total: order.totalAmount,
                    customerName: order.customerName,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderInfo(order),
            const SizedBox(height: 16),
            _buildLivePackingCountdownCard(order),
            _buildStatusTimeline(order),
            const SizedBox(height: 24),
            _buildCustomerInfo(order),
            const SizedBox(height: 24),
            if (order.orderType == VendorOrderType.text)
              _buildTextContent(order)
            else if (order.orderType == VendorOrderType.photo)
              _buildPhotoContent(order)
            else
              _buildItemsList(order),
            const SizedBox(height: 24),

            // Vendor Support / Raise Ticket
            InkWell(
              onTap: () => _showVendorSupportBottomSheet(context, order),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.help_outline_rounded, color: AppTheme.primaryOrange, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Need help with this order?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.darkText)),
                          Text('Raise a ticket or report an issue', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Vendor Payout Badge: Shows Payment Done! only when Admin marks as paid
            Builder(builder: (context) {
              final isTextOrPhoto = order.orderType == VendorOrderType.text || order.orderType == VendorOrderType.photo;
              final isOrderActiveForQuote = order.status == VendorOrderStatus.pending || order.status == VendorOrderStatus.accepted;
              // For active text/photo orders awaiting quote, hide payout badge until vendor creates quote
              if (isTextOrPhoto && order.subTotal <= 0 && isOrderActiveForQuote) return const SizedBox.shrink();

              double itemsSum = order.items.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
              double calcTotal = itemsSum > 0 
                  ? (itemsSum - order.discount) 
                  : (order.subTotal > 0 ? (order.subTotal - order.discount) : (order.totalAmount > 0 ? order.totalAmount : 0.0));
              double foodTotal = calcTotal > 0 ? calcTotal : 0.0;
              final isPaidByAdmin = order.vendorPaymentStatus == 'Paid' || order.vendorPaymentStatus == 'Completed';

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isPaidByAdmin 
                      ? const Color(0xFFECFDF5) 
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPaidByAdmin 
                        ? const Color(0xFF10B981).withValues(alpha: 0.5) 
                        : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isPaidByAdmin ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPaidByAdmin 
                            ? const Color(0xFF10B981).withValues(alpha: 0.15) 
                            : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPaidByAdmin ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                        color: isPaidByAdmin ? const Color(0xFF047857) : const Color(0xFFB45309),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isPaidByAdmin ? 'Payment Received' : 'Order Confirmed',
                            style: GoogleFonts.outfit(
                              color: isPaidByAdmin ? const Color(0xFF065F46) : const Color(0xFF92400E),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPaidByAdmin ? 'Settled by Admin' : 'Vendor Payout Pending',
                            style: GoogleFonts.outfit(
                              color: isPaidByAdmin ? const Color(0xFF047857) : const Color(0xFFB45309),
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isPaidByAdmin ? const Color(0xFF059669) : const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (isPaidByAdmin ? const Color(0xFF059669) : const Color(0xFFD97706)).withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          foodTotal > 0 ? '₹${foodTotal.toStringAsFixed(0)}' : '₹0',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Show Quote Input ONLY if it's an active text/photo order waiting for quote
            Builder(builder: (context) {
              final isOrderActiveForQuote = order.status == VendorOrderStatus.pending || order.status == VendorOrderStatus.accepted;
              final isNeedQuote = (order.orderType == VendorOrderType.text || order.orderType == VendorOrderType.photo) && order.subTotal <= 0 && isOrderActiveForQuote;

              if (isNeedQuote) {
                return _buildQuoteInput(order);
              }
              return _buildPaymentSummary(order);
            }),
            const SizedBox(height: 140),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context, order),
    );
  }

  Widget _buildOrderInfo(VendorOrderModel order) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8))],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            order.displayId,
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.darkText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (order.isOfficeDelivery) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.business_center_rounded, size: 11, color: Color(0xFF2563EB)),
                                const SizedBox(width: 3),
                                Text(
                                  'OFFICE',
                                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF1D4ED8)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Placed on ${_formatFullDateTime(order.timestamp)}',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.lightText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  Color statusColor = AppTheme.primaryOrange;
                  String statusLabel = order.status.name.toUpperCase();
                  switch (order.status) {
                    case VendorOrderStatus.pending: statusColor = AppTheme.primaryRed; statusLabel = 'NEW ORDER'; break;
                    case VendorOrderStatus.accepted: statusColor = AppTheme.primaryOrange; statusLabel = 'CONFIRMED'; break;
                    case VendorOrderStatus.preparing: statusColor = AppTheme.accentBlue; statusLabel = 'PREPARING'; break;
                    case VendorOrderStatus.ready: statusColor = AppTheme.accentGreen; statusLabel = 'READY FOR HANDOVER'; break;
                    case VendorOrderStatus.handedOver: statusColor = AppTheme.lightText; statusLabel = 'HANDED OVER'; break;
                    case VendorOrderStatus.rejected: statusColor = AppTheme.primaryRed; statusLabel = 'CANCELLED'; break;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      _buildPrepTimerBadge(order),
                      if (order.orderType == VendorOrderType.text)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE), width: 1),
                          ),
                          child: Text(
                            'TEXT ORDER',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4338CA),
                              letterSpacing: 0.8,
                            ),
                          ),
                        )
                      else if (order.orderType == VendorOrderType.photo)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF2F8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFBCFE8), width: 1),
                          ),
                          child: Text(
                            'PHOTO ORDER',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFBE185D),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (order.status == VendorOrderStatus.rejected) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cancelled by ${order.cancelledBy ?? "Vendor / Customer"}',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.red.shade900, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Reason: ${order.cancellationReason != null && order.cancellationReason!.isNotEmpty ? order.cancellationReason : "No reason specified"}',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.red.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextContent(VendorOrderModel order) {
    // Parse the shopping list
    final List<Map<String, String>> items = _parseShoppingList(order.textContent ?? '');
    
    // Premium Section Header
    Widget sectionHeader = Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Iconsax.receipt_2, color: AppTheme.accentBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shopping List Content',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.darkText, letterSpacing: -0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Itemized from customer requirements',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.lightText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.1)),
              ),
              child: Text(
                '${items.where((i) => i['type'] == 'item').length} ITEMS',
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.accentBlue, letterSpacing: 1),
              ),
            ),
        ],
      ),
    );

    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10)),
              ],
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.message_text, size: 18, color: AppTheme.lightText),
                    const SizedBox(width: 10),
                    Text('Direct Message', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.lightText)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  order.textContent ?? 'No message provided',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.darkText, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader,
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 30, offset: const Offset(0, 15)),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            children: [
              // Enhanced Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 40, child: Text('ID', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppTheme.lightText, fontSize: 11, letterSpacing: 1))),
                    Expanded(child: Text('ITEM DESCRIPTION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppTheme.lightText, fontSize: 11, letterSpacing: 1))),
                    Text('QTY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppTheme.lightText, fontSize: 11, letterSpacing: 1)),
                  ],
                ),
              ),
              // Table Body with alternating highlights or clean dividers
              ...items.where((i) => i['type'] == 'item').map((item) {
                final bool isLast = items.where((i) => i['type'] == 'item').last == item;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.05), width: 1)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40, 
                        child: Text(
                          (item['index'] ?? '').padLeft(2, '0'), 
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.accentBlue.withValues(alpha: 0.5), fontSize: 13)
                        )
                      ),
                      Expanded(
                        child: Text(
                          item['name'] ?? '', 
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.darkText, fontSize: 16, height: 1.2)
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item['qty'] ?? '', 
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.darkText)
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Elegant Note Footer
              if (items.any((i) => i['type'] == 'note')) 
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                    border: Border(top: BorderSide(color: Colors.amber.withValues(alpha: 0.1), width: 1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Iconsax.info_circle, size: 16, color: Colors.amber.shade800),
                          const SizedBox(width: 8),
                          Text('CUSTOMER NOTE', style: GoogleFonts.outfit(fontSize: 11, color: Colors.amber.shade800, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        items.firstWhere((i) => i['type'] == 'note', orElse: () => {'name': ''})['name'] ?? '',
                        style: GoogleFonts.outfit(fontSize: 14, color: Colors.amber.shade900, fontWeight: FontWeight.w600, height: 1.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, String>> _parseShoppingList(String content) {
    if (content.isEmpty) return [];
    
    final List<Map<String, String>> items = [];
    final lines = content.split('\n');
    
    // Improved logic: Even if the "Shopping List Order:" header is missing,
    // if we find lines matching the pattern, we parse them.
    for (String line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      // Skip the header
      if (trimmed.toLowerCase().contains('shopping list order')) continue;
      
      if (trimmed.startsWith('Note:')) {
        items.add({'name': trimmed.replaceFirst('Note:', '').trim(), 'qty': '', 'index': '', 'type': 'note'});
        continue;
      }
      
      // More flexible regex:
      // Works for "1. Bread (Qty: 2)" or "1 Bread (Qty: 2)" or "1. Bread (Qty:2)"
      final match = RegExp(r'^(\d+)[\.\s]+(.*?)\s+\(Qty:\s*(.*?)\)$', caseSensitive: false).firstMatch(trimmed);
      if (match != null) {
        items.add({
          'index': match.group(1) ?? '',
          'name': match.group(2) ?? '',
          'qty': match.group(3) ?? '',
          'type': 'item',
        });
      }
    }
    return items;
  }

  Widget _buildPhotoContent(VendorOrderModel order) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_rounded, color: AppTheme.primaryOrange, size: 24),
              const SizedBox(width: 12),
              Text(
                'Photo Order',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.darkText),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (order.photoUrl != null && order.photoUrl!.isNotEmpty)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog.fullscreen(
                    backgroundColor: Colors.black,
                    child: Stack(
                      children: [
                        Center(
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.network(
                              order.photoUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
                              },
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 60),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 40,
                          right: 20,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.network(
                        order.photoUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey.shade100,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                          child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Tap to Fullscreen', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Text('No photo attached'),
          const SizedBox(height: 12),
          Text(
            'Please examine the photo list and provide a total quote below.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.lightText, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  _QuoteCalculation _calculateQuoteValues() {
    final double mrp = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final double input2 = double.tryParse(_discountController.text.trim()) ?? 0.0;
    double calculatedDiscount = 0.0;
    double calculatedRate = mrp;
    double discountPercent = 0.0;

    if (mrp > 0 && input2 > 0) {
      if (_isPercentageMode) {
        discountPercent = input2.clamp(0.0, 100.0);
        calculatedDiscount = mrp * (discountPercent / 100.0);
        if (calculatedDiscount > mrp) calculatedDiscount = mrp;
        calculatedRate = (mrp - calculatedDiscount).clamp(0.0, mrp);
      } else {
        // Flat ₹ Discount: input2 is the discount amount directly (e.g. MRP 200, Discount 50 => Customer Pays 150)
        calculatedDiscount = input2.clamp(0.0, mrp);
        calculatedRate = (mrp - calculatedDiscount).clamp(0.0, mrp);
        discountPercent = mrp > 0 ? (calculatedDiscount / mrp) * 100.0 : 0.0;
      }
    } else {
      calculatedRate = mrp;
      calculatedDiscount = 0.0;
      discountPercent = 0.0;
    }

    return _QuoteCalculation(
      mrp: mrp,
      calculatedDiscount: calculatedDiscount,
      calculatedRate: calculatedRate,
      discountPercent: discountPercent,
    );
  }

  Future<void> _handleSendQuote(BuildContext context, VendorOrderModel order) async {
    final calc = _calculateQuoteValues();
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (calc.mrp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang.text(
                    en: 'Please enter MRP / Total bill amount above.',
                    ta: 'தயவுசெய்து மேலே உள்ள MRP / பில் தொகையை உள்ளிடவும்.',
                    tanglish: 'Please enter MRP / Total bill amount above.',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final orderProvider = context.read<VendorOrderProvider>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildQuoteConfirmationSheet(ctx, order, calc),
    );

    if (confirmed == true && mounted) {
      await orderProvider.updateOrderStatus(
        order.id,
        VendorOrderStatus.accepted,
        newPrice: calc.mrp,
        discount: calc.calculatedDiscount,
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang.text(
                      en: 'Bill Quote sent to customer successfully!',
                      ta: 'வாடிக்கையாளருக்கு பில் வெற்றிகரமாக அனுப்பப்பட்டது!',
                      tanglish: 'Bill Quote customer-ku vetrigarama anuppiyachu!',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _buildQuoteConfirmationSheet(
    BuildContext ctx,
    VendorOrderModel order,
    _QuoteCalculation calc,
  ) {
    final lang = Provider.of<LanguageProvider>(ctx, listen: false);
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).padding.bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: AppTheme.primaryOrange, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.text(
                        en: 'Confirm & Send Bill Quote',
                        ta: 'பில் கொட்டேஷனை உறுதி செய்',
                        tanglish: 'Confirm & Send Bill Quote',
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppTheme.darkTextMain : AppTheme.darkText,
                      ),
                    ),
                    Text(
                      'Order ${order.shortDisplayId}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextSub : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        lang.text(en: 'Total Shop MRP', ta: 'கடை மொத்த MRP', tanglish: 'Total Shop MRP'),
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          color: isDark ? AppTheme.darkTextSub : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${calc.mrp.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkTextMain : AppTheme.darkText,
                      ),
                    ),
                  ],
                ),
                if (calc.calculatedDiscount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          lang.text(en: 'Shop Discount Given', ta: 'வழங்கப்பட்ட தள்ளுபடி', tanglish: 'Discount Given'),
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            color: const Color(0xFF059669),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '-₹${calc.calculatedDiscount.toStringAsFixed(0)} (${calc.discountPercent.toStringAsFixed(0)}% OFF)',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        lang.text(en: 'Customer Payable (Items)', ta: 'வாடிக்கையாளர் கட்டணம்', tanglish: 'Customer Item Total'),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextMain : AppTheme.darkText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${calc.calculatedRate.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notifications_active_rounded, size: 16, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.text(
                    en: 'Customer will receive this quote notification instantly to approve and pay.',
                    ta: 'வாடிக்கையாளர் இந்த பில்லை ஏற்று பணம் செலுத்த உடனடியாக அறிவிப்பு அனுப்பப்படும்.',
                    tanglish: 'Customer-kku intha bill quote notification udane pogum.',
                  ),
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkTextSub : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      lang.text(en: 'EDIT', ta: 'மாற்று', tanglish: 'EDIT'),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          lang.text(en: 'CONFIRM & SEND', ta: 'உறுதி செய்து அனுப்பு', tanglish: 'CONFIRM & SEND'),
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
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
    );
  }

  Widget _buildPresetChip({
    required String label,
    required double value,
    required bool isForPercentage,
  }) {
    final double inputVal = double.tryParse(_discountController.text.trim()) ?? -1.0;
    final bool isCurrentMode = _isPercentageMode == isForPercentage;
    final bool isSelected = isCurrentMode && (value == 0 ? _discountController.text.isEmpty : inputVal == value);

    final Color activeColor = isForPercentage ? const Color(0xFF059669) : AppTheme.primaryOrange;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _isPercentageMode = isForPercentage;
          if (value == 0) {
            _discountController.clear();
          } else {
            _discountController.text = value.toStringAsFixed(0);
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextSub : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBillReceiptCard(
    _QuoteCalculation calc,
    bool isDark,
    LanguageProvider lang,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Live Bill Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 15,
                  color: AppTheme.primaryOrange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.text(
                    en: 'BILL BREAKDOWN PREVIEW',
                    ta: 'பில் விவரக் கணக்கு',
                    tanglish: 'BILL BREAKDOWN PREVIEW',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? AppTheme.darkTextMain : const Color(0xFF334155),
                  ),
                ),
              ),
              if (calc.mrp > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lang.text(en: 'Live Bill', ta: 'நேரடி பில்', tanglish: 'Live Bill'),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // MRP Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  lang.text(en: 'Original Items MRP', ta: 'பொருட்கள் அசல் MRP', tanglish: 'Items Original MRP'),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkTextSub : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                calc.mrp > 0 ? '₹${calc.mrp.toStringAsFixed(0)}' : '₹0',
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextMain : AppTheme.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Discount Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        lang.text(en: 'Shop Discount', ta: 'கடை தள்ளுபடி', tanglish: 'Shop Discount'),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkTextSub : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    if (calc.calculatedDiscount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${calc.discountPercent.toStringAsFixed(0)}% OFF',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                calc.calculatedDiscount > 0
                    ? '-₹${calc.calculatedDiscount.toStringAsFixed(0)}'
                    : lang.text(en: '₹0 (No Discount)', ta: '₹0 (தள்ளுபடி இல்லை)', tanglish: '₹0 (No Discount)'),
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: calc.calculatedDiscount > 0 ? const Color(0xFF059669) : (isDark ? AppTheme.darkTextSub : const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Customer Payable Highlight Box (Guaranteed no overflow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang.text(
                          en: 'Customer Pays for Items',
                          ta: 'வாடிக்கையாளர் செலுத்தும் தொகை',
                          tanglish: 'Customer Item Total',
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextMain : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lang.text(
                          en: 'Delivery & fees added at checkout',
                          ta: 'டெலிவரி கட்டணம் செக் அவுட்டில் சேரும்',
                          tanglish: 'Delivery fee added at checkout',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkTextSub : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '₹${calc.calculatedRate.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryOrange,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          if (calc.calculatedDiscount > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_outlined, size: 15, color: Color(0xFF047857)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang.text(
                        en: 'Customer saves ₹${calc.calculatedDiscount.toStringAsFixed(0)} (${calc.discountPercent.toStringAsFixed(0)}% OFF) on this order!',
                        ta: 'இந்த ஆர்டரில் வாடிக்கையாளர் ₹${calc.calculatedDiscount.toStringAsFixed(0)} (${calc.discountPercent.toStringAsFixed(0)}% தள்ளுபடி) சேமிக்கிறார்!',
                        tanglish: 'Customer saves ₹${calc.calculatedDiscount.toStringAsFixed(0)} (${calc.discountPercent.toStringAsFixed(0)}% OFF) in this order!',
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Informational note
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppTheme.primaryOrange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lang.text(
                      en: 'Delivery charge and platform fee will be added automatically to the customer checkout bill.',
                      ta: 'டெலிவரி மற்றும் பிளாட்பார்ம் கட்டணம் வாடிக்கையாளர் கட்டணத்தில் தானாக சேர்க்கப்படும்.',
                      tanglish: 'Delivery fee and handling charges will be automatically added to Customer bill.',
                    ),
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.primaryOrange : const Color(0xFFC2410C),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteInput(VendorOrderModel order) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calc = _calculateQuoteValues();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.primaryOrange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.text(
                          en: 'Prepare Bill Quote',
                          ta: 'பில் கொட்டேஷன் தயாரிக்கவும்',
                          tanglish: 'Prepare Bill Quote',
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextMain : AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lang.text(
                          en: 'For Text / Photo Prescription Order',
                          ta: 'வாடிக்கையாளர் அனுப்பிய பொருட்களுக்கான பில்',
                          tanglish: 'Customer order items-kku bill podunga',
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkTextSub : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pending_actions_rounded, size: 13, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        lang.text(en: 'Pending', ta: 'நிலுவை', tanglish: 'Pending'),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // STEP 1: MRP Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.text(
                        en: 'Shop Bill Amount (MRP) *',
                        ta: 'கடை பில் தொகை (MRP) *',
                        tanglish: 'Shop Bill Amount (MRP) *',
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkTextMain : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      lang.text(
                        en: 'As per store bill',
                        ta: 'கடை பில்படி',
                        tanglish: 'Store bill-padi',
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: calc.mrp > 0
                          ? AppTheme.primaryOrange
                          : (isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
                      width: calc.mrp > 0 ? 1.8 : 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '₹',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.darkTextMain : AppTheme.darkText,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_priceController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 20, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _priceController.clear();
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // STEP 2: Discount Mode & Presets
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.text(
                        en: 'Shop Discount (Optional)',
                        ta: 'கடை தள்ளுபடி (விருப்பத்தேர்வு)',
                        tanglish: 'Shop Discount (Optional)',
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkTextMain : const Color(0xFF1E293B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (!_isPercentageMode ? AppTheme.primaryOrange : const Color(0xFF059669)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        !_isPercentageMode
                            ? lang.text(en: 'Flat Discount (₹)', ta: 'நேரடி தள்ளுபடி (₹)', tanglish: 'Flat Discount (₹)')
                            : lang.text(en: 'Percentage (% OFF)', ta: 'சதவீத முறை (% OFF)', tanglish: 'Percentage (% OFF)'),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: !_isPercentageMode ? AppTheme.primaryOrange : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Segmented Toggle Tabs
                Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      // Flat Discount Tab
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (_isPercentageMode) {
                              setState(() {
                                _isPercentageMode = false;
                                _discountController.clear();
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: !_isPercentageMode ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !_isPercentageMode
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x0F000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.currency_rupee_rounded,
                                  size: 15,
                                  color: !_isPercentageMode ? AppTheme.primaryOrange : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  lang.text(
                                    en: 'Flat Discount (₹)',
                                    ta: 'தள்ளுபடி (₹)',
                                    tanglish: 'Flat Discount (₹)',
                                  ),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: !_isPercentageMode ? FontWeight.w800 : FontWeight.w600,
                                    color: !_isPercentageMode ? (isDark ? AppTheme.darkTextMain : AppTheme.darkText) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Percentage Tab
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (!_isPercentageMode) {
                              setState(() {
                                _isPercentageMode = true;
                                _discountController.clear();
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _isPercentageMode ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _isPercentageMode
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x0F000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.percent_rounded,
                                  size: 15,
                                  color: _isPercentageMode ? const Color(0xFF059669) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  lang.text(
                                    en: 'Discount %',
                                    ta: 'தள்ளுபடி %',
                                    tanglish: 'Discount %',
                                  ),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: _isPercentageMode ? FontWeight.w800 : FontWeight.w600,
                                    color: _isPercentageMode ? (isDark ? AppTheme.darkTextMain : AppTheme.darkText) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Quick Preset Chips for Easy 1-Tap Calculation
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: !_isPercentageMode
                        ? [
                            _buildPresetChip(
                              label: lang.text(en: 'No Discount', ta: 'தள்ளுபடி இல்லை', tanglish: 'No Discount'),
                              value: 0,
                              isForPercentage: false,
                            ),
                            const SizedBox(width: 8),
                            _buildPresetChip(label: '₹10 OFF', value: 10, isForPercentage: false),
                            const SizedBox(width: 8),
                            _buildPresetChip(label: '₹20 OFF', value: 20, isForPercentage: false),
                            const SizedBox(width: 8),
                            _buildPresetChip(label: '₹30 OFF', value: 30, isForPercentage: false),
                            const SizedBox(width: 8),
                            _buildPresetChip(label: '₹50 OFF', value: 50, isForPercentage: false),
                            const SizedBox(width: 8),
                            _buildPresetChip(label: '₹100 OFF', value: 100, isForPercentage: false),
                          ]
                        : [
                            _buildPresetChip(
                              label: lang.text(en: '0% None', ta: '0% இல்லை', tanglish: '0% None'),
                              value: 0,
                              isForPercentage: true,
                            ),
                            const SizedBox(width: 8),
                            _buildPresetChip(label: '5% OFF', value: 5, isForPercentage: true),
                            const SizedBox(width: 8),
                            _buildPresetChip(label: '10% OFF', value: 10, isForPercentage: true),
                            const SizedBox(width: 8),
                            _buildPresetChip(label: '15% OFF', value: 15, isForPercentage: true),
                            const SizedBox(width: 8),
                            _buildPresetChip(label: '20% OFF', value: 20, isForPercentage: true),
                            const SizedBox(width: 8),
                            _buildPresetChip(label: '25% OFF', value: 25, isForPercentage: true),
                          ],
                  ),
                ),

                const SizedBox(height: 12),

                // Dynamic Discount / Rate Input Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (_isPercentageMode ? const Color(0xFF059669) : AppTheme.primaryOrange).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _isPercentageMode ? '%' : '₹',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _isPercentageMode ? const Color(0xFF059669) : AppTheme.primaryOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _discountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.darkTextMain : AppTheme.darkText,
                          ),
                          decoration: InputDecoration(
                            hintText: _isPercentageMode
                                ? lang.text(en: 'Enter discount % (e.g. 10)', ta: 'தள்ளுபடி % (எ.கா. 10)', tanglish: 'Enter discount % (e.g. 10)')
                                : lang.text(en: 'Enter discount in ₹ (e.g. 50)', ta: 'தள்ளுபடி தொகையை உள்ளிடவும் (எ.கா. 50)', tanglish: 'Enter discount in ₹ (e.g. 50)'),
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_discountController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _discountController.clear();
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),

                if (calc.mrp > 0 && calc.calculatedDiscount > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF15803D)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lang.text(
                              en: 'MRP ₹${calc.mrp.toStringAsFixed(0)} - Discount ₹${calc.calculatedDiscount.toStringAsFixed(0)} = Customer Pays ₹${calc.calculatedRate.toStringAsFixed(0)}',
                              ta: 'MRP ₹${calc.mrp.toStringAsFixed(0)} - தள்ளுபடி ₹${calc.calculatedDiscount.toStringAsFixed(0)} = வாடிக்கையாளர் ₹${calc.calculatedRate.toStringAsFixed(0)}',
                              tanglish: 'MRP ₹${calc.mrp.toStringAsFixed(0)} - Discount ₹${calc.calculatedDiscount.toStringAsFixed(0)} = Customer Pays ₹${calc.calculatedRate.toStringAsFixed(0)}',
                            ),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // STEP 3: Live Bill Breakdown Receipt (Always Visible)
                _buildLiveBillReceiptCard(calc, isDark, lang),

                const SizedBox(height: 16),

                // In-Card Action Status Helper
                InkWell(
                  onTap: () => _handleSendQuote(context, order),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                    decoration: BoxDecoration(
                      color: calc.mrp > 0
                          ? const Color(0xFFECFDF5)
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: calc.mrp > 0
                            ? const Color(0xFFA7F3D0)
                            : (isDark ? AppTheme.darkBorder : const Color(0xFFBFDBFE)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          calc.mrp > 0 ? Icons.send_rounded : Icons.info_outline_rounded,
                          size: 18,
                          color: calc.mrp > 0 ? const Color(0xFF059669) : AppTheme.primaryOrange,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            calc.mrp > 0
                                ? lang.text(
                                    en: 'Send Bill Quote • ₹${calc.calculatedRate.toStringAsFixed(0)} (Review & Send)',
                                    ta: 'பில் கொட்டேஷன் அனுப்புக • ₹${calc.calculatedRate.toStringAsFixed(0)}',
                                    tanglish: 'Send Bill Quote • ₹${calc.calculatedRate.toStringAsFixed(0)} (Review & Send)',
                                  )
                                : lang.text(
                                    en: 'Enter Shop MRP above to create bill quote',
                                    ta: 'பில் தயாரிக்க மேலே கடை MRP தொகையை உள்ளிடவும்',
                                    tanglish: 'Enter Shop MRP above to create bill quote',
                                  ),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: calc.mrp > 0 ? const Color(0xFF047857) : AppTheme.primaryOrange,
                            ),
                          ),
                        ),
                        if (calc.mrp > 0) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF047857)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(VendorOrderModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Status',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.darkText),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              _buildTimelineStep('Order Accepted', 'Vendor confirmed the order',
                  order.status != VendorOrderStatus.pending, true),
              _buildTimelineStep(
                  'Start Preparing',
                  'Order is being prepared',
                  order.status == VendorOrderStatus.preparing ||
                      order.status == VendorOrderStatus.ready ||
                      order.status == VendorOrderStatus.handedOver,
                  true),
              _buildTimelineStep(
                  'Make as Ready',
                  'Waiting for handover',
                  order.status == VendorOrderStatus.ready ||
                      order.status == VendorOrderStatus.handedOver,
                  true),
              _buildTimelineStep('Hand Over', 'Handed over to delivery',
                  order.status == VendorOrderStatus.handedOver, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep(
      String title, String subtitle, bool isCompleted, bool hasNext) {
    final color = isCompleted ? AppTheme.accentGreen : Colors.grey.shade300;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? AppTheme.accentGreen : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (hasNext)
              Container(
                width: 2,
                height: 40,
                color: color,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isCompleted ? AppTheme.darkText : AppTheme.lightText,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppTheme.lightText,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfo(VendorOrderModel order) {
    return const SizedBox.shrink();
  }

  Widget _buildItemsList(VendorOrderModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Items to Prepare',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.darkText),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: order.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primaryOrange.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              item.name.toLowerCase().contains('kg')
                                  ? 'QTY: ${item.quantity} kg'
                                  : 'QTY: ${item.quantity}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.name,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkText,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                    Text(
                      '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummary(VendorOrderModel order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate item sum and total payable to store
    double itemsSum = order.items.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
    double calcSum = itemsSum > 0 
        ? (itemsSum - order.discount) 
        : (order.subTotal > 0 ? (order.subTotal - order.discount) : (order.totalAmount > 0 ? order.totalAmount : 0.0));
    final double vendorTotal = calcSum > 0 ? calcSum : 0.0;
    final double actualPrice = itemsSum > 0 ? itemsSum : (order.subTotal > 0 ? order.subTotal : (vendorTotal + order.discount));
    final isPaidByAdmin = order.vendorPaymentStatus == 'Paid' || order.vendorPaymentStatus == 'Completed';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF273552) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryOrange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BILL SUMMARY',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Store earnings breakdown',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Text(
                      '0% COMMISSION',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF047857),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              thickness: 1.2,
            ),
          ),

          // 1. Gross Shop Items Total
          if (actualPrice > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Shop Items MRP / Total',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${actualPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: order.discount > 0 ? (isDark ? const Color(0xFF64748B) : Colors.grey) : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    decoration: order.discount > 0 ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // 2. Shop Discount Row
          if (order.discount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer_rounded, color: Color(0xFF10B981), size: 15),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Store Discount Offered',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-₹${order.discount.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // 3. Platform Fee / Commission Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Platform Commission (0%)',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'FREE',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Net Store Payout Highlight Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPaidByAdmin
                    ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
                    : [
                        AppTheme.primaryOrange.withValues(alpha: 0.08),
                        AppTheme.primaryOrange.withValues(alpha: 0.14),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPaidByAdmin
                    ? const Color(0xFFA7F3D0)
                    : AppTheme.primaryOrange.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Store Payout',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isPaidByAdmin ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Direct payout to your Bank / UPI',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isPaidByAdmin ? const Color(0xFF047857) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '₹${vendorTotal.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isPaidByAdmin ? const Color(0xFF059669) : AppTheme.primaryOrange,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 5. Settlement Status Strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isPaidByAdmin ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPaidByAdmin ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPaidByAdmin ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  size: 14,
                  color: isPaidByAdmin ? const Color(0xFF059669) : const Color(0xFFD97706),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isPaidByAdmin
                        ? 'Payment Received in Full from Admin (Settled)'
                        : 'Payout Pending • Admin will transfer via Bank/UPI',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isPaidByAdmin ? const Color(0xFF065F46) : const Color(0xFF92400E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomActions(BuildContext context, VendorOrderModel order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF273552) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (context) {
                  final lang = Provider.of<LanguageProvider>(context, listen: false);
                  // Pending Status: Accept & Decline Buttons
                  if (order.status == VendorOrderStatus.pending) {
                    return Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => _showDeclineConfirmation(context, order),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryRed,
                                side: BorderSide(color: AppTheme.primaryRed.withValues(alpha: 0.35), width: 1.5),
                                backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'DECLINE',
                                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                context.read<VendorOrderProvider>().updateOrderStatus(
                                  order.id,
                                  VendorOrderStatus.accepted,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'ACCEPT',
                                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  String buttonLabel = '';
                  VendorOrderStatus? nextStatus;

                  final bool isTextOrPhoto = order.orderType == VendorOrderType.text || order.orderType == VendorOrderType.photo;
                  final bool isOrderActiveForQuote = order.status == VendorOrderStatus.pending || order.status == VendorOrderStatus.accepted;
                  final bool isNeedQuote = isTextOrPhoto && order.subTotal <= 0 && isOrderActiveForQuote;

                  if (isNeedQuote) {
                    final calc = _calculateQuoteValues();
                    final isReady = calc.mrp > 0;
                    final lang = Provider.of<LanguageProvider>(context, listen: false);

                    return SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handleSendQuote(context, order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isReady ? AppTheme.primaryOrange : const Color(0xFFE2E8F0),
                          foregroundColor: isReady ? Colors.white : const Color(0xFF64748B),
                          elevation: isReady ? 3 : 0,
                          shadowColor: isReady ? AppTheme.primaryOrange.withValues(alpha: 0.35) : Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isReady ? Icons.send_rounded : Icons.edit_note_rounded,
                                size: 18,
                                color: isReady ? Colors.white : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isReady
                                    ? lang.text(
                                        en: 'SEND BILL QUOTE (₹${calc.calculatedRate.toStringAsFixed(0)})',
                                        ta: 'பில் கொட்டேஷன் அனுப்பு (₹${calc.calculatedRate.toStringAsFixed(0)})',
                                        tanglish: 'SEND BILL QUOTE (₹${calc.calculatedRate.toStringAsFixed(0)})',
                                      )
                                    : lang.text(
                                        en: 'ENTER MRP BILL AMOUNT ABOVE',
                                        ta: 'மேலே MRP பில் தொகையை உள்ளிடவும்',
                                        tanglish: 'ENTER MRP BILL AMOUNT ABOVE',
                                      ),
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: isReady ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                              if (isReady) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  switch (order.status) {
                    case VendorOrderStatus.accepted:
                      if (order.subTotal > 0 || order.totalAmount > 0) {
                        buttonLabel = 'START PREPARING';
                        nextStatus = VendorOrderStatus.preparing;
                      } else {
                        buttonLabel = 'WAITING FOR QUOTE...';
                        nextStatus = null;
                      }
                      break;
                    case VendorOrderStatus.preparing:
                      buttonLabel = 'MAKE AS READY';
                      nextStatus = VendorOrderStatus.ready;
                      break;
                    case VendorOrderStatus.ready:
                      buttonLabel = 'HAND OVER';
                      nextStatus = VendorOrderStatus.handedOver;
                      break;
                    case VendorOrderStatus.handedOver:
                      buttonLabel = 'ALREADY HANDED OVER';
                      nextStatus = null;
                      break;
                    default:
                      buttonLabel = '';
                      nextStatus = null;
                  }

                  if (buttonLabel.isEmpty) return const SizedBox.shrink();

                  final bool isWaiting = nextStatus == null;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(builder: (context) {
                        final isVendorPaid = order.vendorPaymentStatus == 'Paid' || order.vendorPaymentStatus == 'Completed';
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isVendorPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isVendorPaid ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isVendorPaid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                                color: isVendorPaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    isVendorPaid ? 'Vendor Payment Received from Admin ✓' : 'Vendor Payout Pending (Admin Approval)',
                                    style: GoogleFonts.outfit(
                                      color: isVendorPaid ? const Color(0xFF047857) : const Color(0xFFB45309),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (order.status == VendorOrderStatus.handedOver)
                        Container(
                          height: 52,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                lang.isTamil ? 'ஆர்டர் ஒப்படைக்கப்பட்டது (டெலிவரி)' : 'ORDER HANDED OVER & COMPLETED',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF047857),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (order.status == VendorOrderStatus.rejected)
                        Container(
                          height: 52,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cancel_rounded, color: AppTheme.primaryRed, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                lang.isTamil ? 'ஆர்டர் நிராகரிக்கப்பட்டது' : 'ORDER DECLINED / CANCELLED',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryRed,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isWaiting ? null : () {
                              final targetStatus = nextStatus;
                              if (targetStatus == null) return;
                              context.read<VendorOrderProvider>().updateOrderStatus(
                                order.id,
                                targetStatus,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isWaiting ? Colors.grey.shade200 : AppTheme.accentBlue,
                              foregroundColor: isWaiting ? Colors.grey.shade600 : Colors.white,
                              elevation: isWaiting ? 0 : 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                buttonLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeclineConfirmation(BuildContext context, VendorOrderModel order) {
    CancelOrderDialog.show(
      context: context,
      role: 'Vendor',
      onConfirm: (reason) {
        context.read<VendorOrderProvider>().updateOrderStatus(
          order.id, 
          VendorOrderStatus.rejected,
          cancelledBy: 'Vendor',
          cancellationReason: reason,
        );
        Navigator.pop(context); // Go back after decline
      },
    );
  }

  void _showVendorSupportBottomSheet(BuildContext context, VendorOrderModel order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Text('Order Support / Help', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Text('How can we help you with Order #${order.displayId}?', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _supportOptionTile(
                      icon: Icons.mark_chat_unread_rounded,
                      color: const Color(0xFF4F46E5),
                      title: Provider.of<LanguageProvider>(context, listen: false).text(
                        en: 'Raise Support Ticket',
                        ta: 'புகார் பதிவு செய்ய',
                        tanglish: 'Support Ticket Poda',
                      ),
                      subtitle: 'Report payment, customer or delivery issue',
                      onTap: () {
                        Navigator.pop(context);
                        _showRaiseTicketDialog(context, order);
                      },
                    ),
                    const SizedBox(height: 10),
                    _supportOptionTile(
                      icon: Icons.phone_in_talk_rounded,
                      color: const Color(0xFF10B981),
                      title: Provider.of<LanguageProvider>(context, listen: false).text(
                        en: 'Call Vendor Care',
                        ta: 'விற்பனையாளர் உதவிக்கு அழைக்க',
                        tanglish: 'Vendor Care-ku Call Panna',
                      ),
                      subtitle: 'Toll-free 1800-123-4567 (24x7 Assistance)',
                      onTap: () async {
                        final uri = Uri.parse('tel:18001234567');
                        if (await canLaunchUrl(uri)) launchUrl(uri);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _supportOptionTile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  void _showRaiseTicketDialog(BuildContext context, VendorOrderModel order) {
    int selectedIssue = 0;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isTa = lang.isTamil;
    final isTg = lang.isTanglish;

    final issueKeys = [
      'Payment / Settlement Issue',
      'Customer Behavior / Cancellation',
      'Delivery Partner Delay',
      'Menu / Inventory Error',
      'Other Custom Query',
    ];

    final List<String> issues;
    if (isTa) {
      issues = [
        '💰 கட்டணம் மற்றும் செட்டில்மெண்ட் பிரச்சனை',
        '👤 வாடிக்கையாளர் பிரச்சனை',
        '🛵 டெலிவரி தாமதம்',
        '📦 பொருள் இருப்பு பிழை',
        '📝 பிற காரணங்கள்',
      ];
    } else if (isTg) {
      issues = [
        '💰 Panam matrum Settlement Issue',
        '👤 Customer Problem',
        '🛵 Delivery Delay',
        '📦 Item Stock Error',
        '📝 Matra Kaaranangal',
      ];
    } else {
      issues = [
        '💰 Payment and Settlement Issue',
        '👤 Customer Behavior or Cancellation',
        '🛵 Delivery Partner Delay',
        '📦 Menu / Inventory Error',
        '📝 Other Custom Query',
      ];
    }

    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Raise Ticket', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17, color: const Color(0xFF1E293B))),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Topic / Issue Category:', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  ...issues.asMap().entries.map((e) => RadioListTile<int>(
                    value: e.key,
                    groupValue: selectedIssue,
                    activeColor: const Color(0xFF4F46E5),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    onChanged: (val) => setState(() => selectedIssue = val ?? 0),
                  )),
                  const SizedBox(height: 12),
                  Text('Type your message:', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5, color: const Color(0xFF4F46E5))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    style: GoogleFonts.outfit(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: lang.text(
                        en: 'Type your issue description here...',
                        ta: 'உங்கள் பிரச்சனையை இங்கே தட்டச்சு செய்யவும்...',
                        tanglish: 'Unga problem-ah inga type pannavum...',
                      ),
                      hintStyle: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final messageText = noteController.text.trim();
                  Navigator.pop(ctx);
                  
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (c) => const Center(child: CircularProgressIndicator()),
                  );

                  final apiService = VendorApiService();
                  final vendorData = Provider.of<VendorOrderProvider>(context, listen: false).profile;
                  
                  final ticketData = {
                    'userType': 'Vendor',
                    'userId': vendorData?.id ?? 'unknown_id',
                    'userName': vendorData?.storeName ?? 'Vendor',
                    'userPhone': vendorData?.phone ?? 'Unknown',
                    'orderId': order.id,
                    'issueType': issueKeys[selectedIssue],
                    'message': messageText,
                  };
                  
                  final result = await apiService.createSupportTicket(ticketData);
                  Navigator.pop(context); // close loading
                  
                  final ticketId = (result != null && result['ticketId'] != null) 
                    ? result['ticketId'] 
                    : 'TK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                  
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
                      title: Text('Ticket Registered!', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Ticket #$ticketId has been created successfully.', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)), textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          if (messageText.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                              child: Text('"$messageText"', style: GoogleFonts.outfit(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text('Our Vendor Care executive will review your ticket and respond within 15 minutes.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
                        ],
                      ),
                      actions: [
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(c),
                            child: Text('Done', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Text('Send Message', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatFullDateTime(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[local.month - 1];
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final min = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month ${local.year}, ${hour.toString().padLeft(2, '0')}:$min $period';
  }

  Widget _buildLivePackingCountdownCard(VendorOrderModel order) {
    if (order.status == VendorOrderStatus.pending || order.status == VendorOrderStatus.rejected) {
      return const SizedBox.shrink();
    }

    // ─── STATE 1: PACKING COMPLETED (Ready or HandedOver) ───
    final isPacked = order.status == VendorOrderStatus.ready || order.status == VendorOrderStatus.handedOver;
    if (isPacked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF047857).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORDER PACKING COMPLETED',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFA7F3D0),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Packed in ${order.packedTimeFormatted}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    order.status == VendorOrderStatus.handedOver ? 'Handed over to rider' : 'Waiting for rider pickup',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ─── STATE 2: LIVE PACKING COUNTDOWN (Starts from order acceptance) ───
    final remainingSecs = order.remainingPrepSeconds;
    final totalSecs = (order.prepTimeMinutes > 0 ? order.prepTimeMinutes : 10) * 60;
    final progress = totalSecs > 0 ? (remainingSecs / totalSecs).clamp(0.0, 1.0) : 0.0;

    final isUrgent = order.isPrepUrgent;
    final isOverdue = order.isPrepOverdue;

    final mins = (remainingSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (remainingSecs % 60).toString().padLeft(2, '0');

    List<Color> cardGradient;
    Color accentColor;
    String headerText;
    String subText;

    if (isOverdue) {
      cardGradient = [const Color(0xFF450A0A), const Color(0xFF1F0505)];
      accentColor = const Color(0xFFEF4444);
      headerText = '⚠️ PACKING OVERDUE!';
      subText = 'Prep time expired! Complete packing and handover immediately.';
    } else if (isUrgent) {
      cardGradient = [const Color(0xFF581C1C), const Color(0xFF2E0909)];
      accentColor = const Color(0xFFF87171);
      headerText = '🚨 URGENT: LESS THAN 1 MINUTE!';
      subText = 'Final packing countdown running! Finish items immediately.';
    } else if (order.status == VendorOrderStatus.accepted) {
      cardGradient = [const Color(0xFF0B192E), const Color(0xFF132742)];
      accentColor = const Color(0xFF38BDF8);
      headerText = '⏱️ LIVE PACKING COUNTDOWN';
      subText = 'Order accepted! Live timer running. Tap "START PREPARING" below.';
    } else {
      cardGradient = [const Color(0xFF0B192E), const Color(0xFF132742)];
      accentColor = const Color(0xFF38BDF8);
      headerText = '🔥 KITCHEN PREPARATION IN PROGRESS';
      subText = 'Live packing countdown active. Pack items before timer ends.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cardGradient.first.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: accentColor.withValues(alpha: isUrgent || isOverdue ? 0.6 : 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isUrgent || isOverdue ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isUrgent || isOverdue ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        headerText,
                        style: GoogleFonts.outfit(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  '${order.prepTimeMinutes} Min Limit',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildDigitalUnitBox(value: mins, label: 'MINUTES', accentColor: accentColor),
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
                child: Text(
                  ':',
                  style: GoogleFonts.outfit(
                    color: accentColor,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildDigitalUnitBox(value: secs, label: 'SECONDS', accentColor: accentColor),
            ],
          ),
          const SizedBox(height: 14),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 7,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverdue
                      ? const Color(0xFFEF4444)
                      : (isUrgent ? const Color(0xFFF97316) : const Color(0xFF38BDF8)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% Remaining',
                style: GoogleFonts.outfit(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                isOverdue ? '0s left' : '${remainingSecs}s left',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subText,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalUnitBox({
    required String value,
    required String label,
    required Color accentColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 84, minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF050B14).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildPrepTimerBadge(VendorOrderModel order) {
    return const SizedBox.shrink();
  }
}

