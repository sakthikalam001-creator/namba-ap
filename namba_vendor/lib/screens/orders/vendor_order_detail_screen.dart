import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../models/vendor_order_model.dart';
import '../../services/vendor_order_provider.dart';

import 'vendor_order_actions.dart';
import '../profile/vendor_extra_screens.dart';

class VendorOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const VendorOrderDetailScreen({super.key, required this.orderId});

  @override
  State<VendorOrderDetailScreen> createState() => _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState extends State<VendorOrderDetailScreen> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  // Duplicate dispose removed

  @override
  Widget build(BuildContext context) {
    return Consumer<VendorOrderProvider>(
      builder: (context, provider, _) {
        // Live lookup — always get latest version of this order from provider
        final orderOrNull = provider.orders.cast<VendorOrderModel?>().firstWhere(
          (o) => o?.id == widget.orderId,
          orElse: () => null,
        );
        if (orderOrNull == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Order Details')),
            body: const Center(child: Text('Order not found')),
          );
        }
        final order = orderOrNull;
        return _buildScaffold(context, order);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, VendorOrderModel order) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.lightSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: AppTheme.darkText, size: 18),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Order ${order.displayId}',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.darkText),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.print_rounded, color: AppTheme.darkText),
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
            const SizedBox(height: 24),
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
            // Vendor Payout Badge: Shows Payment Done! only when Admin marks as paid
            Builder(builder: (context) {
              double itemsSum = order.items.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
              double calcTotal = itemsSum > 0 
                  ? (itemsSum - order.discount) 
                  : (order.subTotal > 0 ? (order.subTotal - order.discount) : (order.totalAmount > 0 ? order.totalAmount : 0.0));
              double foodTotal = calcTotal > 0 ? calcTotal : 0.0;
              final isPaidByAdmin = order.vendorPaymentStatus == 'Completed';

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isPaidByAdmin ? const Color(0xFF059669).withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isPaidByAdmin ? const Color(0xFF059669).withValues(alpha: 0.4) : Colors.amber.shade600),
                ),
                child: Row(children: [
                  Icon(isPaidByAdmin ? Icons.check_circle_rounded : Icons.pending_actions_rounded, color: isPaidByAdmin ? const Color(0xFF059669) : Colors.amber.shade800, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    isPaidByAdmin ? 'Payment Done!' : 'Order Confirmed (Payout Pending)',
                    style: TextStyle(color: isPaidByAdmin ? const Color(0xFF059669) : Colors.amber.shade900, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    foodTotal > 0 ? '₹${foodTotal.toStringAsFixed(0)}' : '₹0',
                    style: TextStyle(color: isPaidByAdmin ? const Color(0xFF059669) : Colors.amber.shade900, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ]),
              );
            }),
            // Show Quote Input if it's a text/photo order AND price isn't set yet
            if ((order.orderType == VendorOrderType.text || order.orderType == VendorOrderType.photo) && order.totalAmount <= 0)
              _buildQuoteInput(order)
            else if (order.totalAmount > 0)
              _buildPaymentSummary(order),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context, order),
    );
  }

  Widget _buildOrderInfo(VendorOrderModel order) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 10))],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.displayId,
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.darkText),
              ),
              const SizedBox(height: 4),
              Text(
                'Placed at ${order.timestamp.hour}:${order.timestamp.minute.toString().padLeft(2, '0')}',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.lightText),
              ),
            ],
          ),
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

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      statusLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (order.orderType == VendorOrderType.text)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'TEXT ORDER',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accentBlue,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
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
          Row(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shopping List Content',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.darkText, letterSpacing: -0.5),
                  ),
                  Text(
                    'Itemized from customer requirements',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.lightText),
                  ),
                ],
              ),
            ],
          ),
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
                          item['index']!.padLeft(2, '0'), 
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.accentBlue.withValues(alpha: 0.5), fontSize: 13)
                        )
                      ),
                      Expanded(
                        child: Text(
                          item['name']!, 
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
                          item['qty']!, 
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
                        items.firstWhere((i) => i['type'] == 'note')['name']!,
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
          'index': match.group(1)!,
          'name': match.group(2)!,
          'qty': match.group(3)!,
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
          if (order.photoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                order.photoUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
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

  Widget _buildQuoteInput(VendorOrderModel order) {
    // Check if the order is already accepted by the vendor before showing quote input
    final bool isAccepted = order.status == VendorOrderStatus.accepted || order.status == VendorOrderStatus.preparing;
    
    if (!isAccepted) {
       return Container(
         width: double.infinity,
         padding: const EdgeInsets.all(24),
         decoration: BoxDecoration(
           color: Colors.white,
           borderRadius: BorderRadius.circular(24),
           border: Border.all(color: Colors.grey.shade200),
         ),
         child: const Center(
           child: Text('Accept the order to send a quote bill.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
         ),
       );
    }

    bool isPercentageMode = false;

    return StatefulBuilder(
      builder: (context, setState) {
        double mrp = double.tryParse(_priceController.text) ?? 0.0;
        double input2 = double.tryParse(_discountController.text) ?? 0.0;
        
        double calculatedDiscount = 0.0;
        double calculatedRate = mrp;

        if (input2 > 0) {
          if (isPercentageMode) {
            calculatedDiscount = mrp * (input2 / 100);
            calculatedRate = mrp - calculatedDiscount;
          } else {
            // input2 is RATE (Selling Price)
            calculatedRate = input2;
            calculatedDiscount = mrp - calculatedRate;
            if (calculatedDiscount < 0) calculatedDiscount = 0.0;
          }
        } else {
          calculatedRate = mrp;
          calculatedDiscount = 0.0;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prepare Bill Quote',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.darkText),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() {}),
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.accentBlue),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      hintText: 'MRP (Maximum Retail Price)',
                      hintStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(height: 16),
                  
                  // Toggle Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discount Mode:',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkText),
                      ),
                      Row(
                        children: [
                          Text('RATE ₹', style: GoogleFonts.outfit(fontSize: 13, fontWeight: isPercentageMode ? FontWeight.w500 : FontWeight.w800, color: isPercentageMode ? Colors.grey : AppTheme.accentBlue)),
                          Switch(
                            value: isPercentageMode,
                            activeColor: Colors.green,
                            inactiveThumbColor: AppTheme.accentBlue,
                            inactiveTrackColor: AppTheme.accentBlue.withValues(alpha: 0.2),
                            onChanged: (val) {
                              setState(() {
                                isPercentageMode = val;
                                _discountController.clear();
                              });
                            },
                          ),
                          Text('Percentage %', style: GoogleFonts.outfit(fontSize: 13, fontWeight: isPercentageMode ? FontWeight.w800 : FontWeight.w500, color: isPercentageMode ? Colors.green : Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  
                  const Divider(height: 16),
                  TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(() {}),
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: isPercentageMode ? Colors.green : AppTheme.primaryOrange),
                    decoration: InputDecoration(
                      prefixText: isPercentageMode ? '' : '₹ ',
                      suffixText: isPercentageMode ? ' %' : '',
                      hintText: isPercentageMode ? 'Discount Percentage (Optional)' : 'RATE / Selling Price (Optional)',
                      hintStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                  
                  if (mrp > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Calculated Discount', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                              Text(calculatedDiscount > 0 ? '₹${calculatedDiscount.toStringAsFixed(0)}' : '₹0 (No Discount)', style: GoogleFonts.outfit(fontSize: 14, color: Colors.green, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Final Selling Price', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                              Text('₹${calculatedRate.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.primaryOrange, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.accentBlue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Delivery Fee & Handling Charges will be automatically added to Customer bill.',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (mrp > 0) {
                          context.read<VendorOrderProvider>().updateOrderStatus(
                            order.id,
                            VendorOrderStatus.accepted,
                            newPrice: mrp,
                            discount: calculatedDiscount,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Send Bill to Customer', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Customer Details',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.darkText)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.cardShadow),
          child: Column(children: [
            Row(children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(color: AppTheme.accentTeal.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Iconsax.user, color: AppTheme.accentTeal),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.customerName,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.darkText)),
                Text(order.customerPhone,
                    style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.lightText, fontWeight: FontWeight.w500)),
              ])),
              IconButton(
                onPressed: () => showModalBottomSheet(
                  context: context, isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                  builder: (_) => Padding(
                    padding: MediaQuery.of(context).viewInsets,
                    child: ContactCustomerSheet(
                      phone: order.customerPhone,
                      customerName: order.customerName,
                      orderId: order.id,
                    ),
                  ),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
                ),
              ),
            ]),
          ]),
        ),
      ],
    );
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.quantity}x',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item.name,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ],
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
    // Calculate the actual amount the vendor will receive for items
    double itemsSum = order.items.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
    double calcSum = itemsSum > 0 
        ? (itemsSum - order.discount) 
        : (order.subTotal > 0 ? (order.subTotal - order.discount) : (order.totalAmount > 0 ? order.totalAmount : 0.0));
    final double vendorTotal = calcSum > 0 ? calcSum : 0.0;
        
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryOrange.withValues(alpha: 0.05),
            AppTheme.primaryOrange.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BILL SUMMARY', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.lightText, letterSpacing: 1)),
          const SizedBox(height: 16),
          // Actual price row with strikethrough if discount exists
          if (order.subTotal > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Actual Price', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.lightText)),
                Text(
                  '₹${order.subTotal.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey,
                    decoration: order.discount > 0 ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Discount row
          if (order.discount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.local_offer_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 6),
                  Text('Discount', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                ]),
                Text('-₹${order.discount.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const Divider(height: 20),
          // Final vendor total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Amount', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.darkText)),
              Text(
                '₹${vendorTotal.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primaryOrange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomActions(BuildContext context, VendorOrderModel order) {
    // Removed the null return for pending status so actions can be built

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Builder(
              builder: (context) {
                  // Flow for Text/Photo orders:
                  // 1. Status: Pending -> Show Accept/Decline
                  // 2. Status: Accepted (Total=0) -> Show "Waiting for Quote" in bottom bar (Action is in the body)
                  // 3. Status: Accepted (Total>0) -> Show "Waiting for Customer Approval"

                  // Standard Button Flow
                  if (order.status == VendorOrderStatus.pending) {
                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showDeclineConfirmation(context, order),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryRed,
                              side: BorderSide(color: AppTheme.primaryRed.withValues(alpha: 0.3), width: 2),
                              backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.05),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(
                              'DECLINE',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppTheme.accentGreen, Color(0xFF047857)]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                final nextStatus = VendorOrderStatus.accepted;

                                context.read<VendorOrderProvider>().updateOrderStatus(
                                  order.id,
                                  nextStatus,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text(
                                'ACCEPT',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  String buttonLabel = '';
                  VendorOrderStatus? nextStatus;

                  switch (order.status) {
                    case VendorOrderStatus.accepted:
                      if (order.totalAmount > 0) {
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
                        final isVendorPaid = order.vendorPaymentStatus == 'Completed';
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isVendorPaid ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isVendorPaid ? Colors.green.shade200 : Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isVendorPaid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded, color: isVendorPaid ? Colors.green.shade800 : Colors.amber.shade900, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                isVendorPaid ? 'Vendor Payment Received from Admin ✓' : 'Vendor Payout Pending (Admin Approval)',
                                style: TextStyle(color: isVendorPaid ? Colors.green.shade900 : Colors.amber.shade900, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }),
                      Row(
                        children: [
                          if (nextStatus != null)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isWaiting ? null : () {
                                  context.read<VendorOrderProvider>().updateOrderStatus(
                                    order.id,
                                    nextStatus!,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isWaiting ? Colors.grey.shade200 : AppTheme.accentBlue,
                                  foregroundColor: isWaiting ? Colors.grey.shade600 : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: Text(
                                  buttonLabel,
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDeclineConfirmation(BuildContext context, VendorOrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          'Decline Order?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 24, color: AppTheme.darkText),
        ),
        content: Text(
          'Are you sure you want to decline order #${order.displayId}? This action cannot be undone.',
          style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.lightText, fontWeight: FontWeight.w500),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.mediumText),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<VendorOrderProvider>().updateOrderStatus(order.id, VendorOrderStatus.rejected);
              Navigator.pop(context); // Go back after decline
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Yes, Decline',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

