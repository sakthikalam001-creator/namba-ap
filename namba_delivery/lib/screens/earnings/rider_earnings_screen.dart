import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/delivery_provider.dart';
import '../../models/delivery_order.dart';

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});

  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('EARNINGS & PAYOUTS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, child) {
          final allDelivered = provider.orderHistory
              .where((o) => o.status == DeliveryStatus.delivered)
              .toList();

          double totalEarnings = 0.0;
          double totalDistance = 0.0;
          for (final o in allDelivered) {
            final earn = o.computedDriverEarnings > 0
                ? o.computedDriverEarnings
                : (o.driverEarningsBackend ?? 10.0);
            totalEarnings += earn;
            totalDistance += (o.distanceKmBackend ?? 0.0);
          }

          final String formattedTotal = totalEarnings.toStringAsFixed(2);
          final parts = formattedTotal.split('.');
          final mainAmount = parts[0];
          final decimalAmount = parts.length > 1 ? '.${parts[1]}' : '.00';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRealWalletCard(mainAmount, decimalAmount, allDelivered.length),
                const SizedBox(height: 24),
                _buildAdminSettlementNotice(),
                const SizedBox(height: 28),
                _buildRealEarningBreakdown(allDelivered.length, totalDistance, totalEarnings),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('COMPLETED DELIVERY EARNINGS', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.darkText.withValues(alpha: 0.4), letterSpacing: 1)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${allDelivered.length} SETTLED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.accentGreen)),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 16),
                if (allDelivered.isEmpty)
                  _buildEmptyTransactions()
                else
                  _buildRealTransactionList(allDelivered),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRealWalletCard(String mainAmount, String decimalAmount, int orderCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(icons.Iconsax.wallet_3_copy, color: Color(0xFF818CF8), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'TOTAL EARNED BALANCE',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFCBD5E1),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(
                      'LIVE SYNC',
                      style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('₹', style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(width: 4),
              Text(
                mainAmount,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              Text(
                decimalAmount,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(icons.Iconsax.box_tick_copy, color: Color(0xFF34D399), size: 16),
                const SizedBox(width: 8),
                Text(
                  '$orderCount Deliveries Completed',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  'Admin Settled',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildAdminSettlementNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(icons.Iconsax.bank_copy, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DIRECT ADMIN SETTLEMENT',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF065F46),
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Earnings are calculated automatically per order and transferred directly to your bank account / UPI by Super Admin.',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF047857),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildRealEarningBreakdown(int totalOrders, double totalKm, double totalEarnings) {
    final avgPerOrder = totalOrders > 0 ? (totalEarnings / totalOrders).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(icons.Iconsax.chart_2_copy, color: AppTheme.primaryOrange, size: 18),
              const SizedBox(width: 10),
              Text(
                'PERFORMANCE BREAKDOWN',
                style: GoogleFonts.outfit(
                  color: AppTheme.darkText,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _breakdownItem('Delivered', '$totalOrders Trips', AppTheme.darkText),
              _breakdownItem('Total Distance', '${totalKm.toStringAsFixed(1)} KM', AppTheme.accentGreen),
              _breakdownItem('Avg / Trip', '₹$avgPerOrder', const Color(0xFF4F46E5)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _breakdownItem(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(val, style: GoogleFonts.outfit(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(icons.Iconsax.receipt_item_copy, color: Color(0xFF94A3B8), size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'NO COMPLETED ORDERS YET',
            style: GoogleFonts.outfit(
              color: AppTheme.darkText,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Go online on your dashboard to accept and deliver orders. Your payout transactions will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppTheme.lightText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildRealTransactionList(List<DeliveryOrder> orders) {
    return Column(
      children: orders.map((order) {
        final earn = order.computedDriverEarnings > 0
            ? order.computedDriverEarnings
            : (order.driverEarningsBackend ?? 10.0);
        final earnStr = '+₹${earn.toStringAsFixed(0)}';
        final displayId = order.displayId.isNotEmpty ? order.displayId : order.id.substring(order.id.length > 5 ? order.id.length - 5 : 0);
        final dateStr = DateFormat('dd MMM, hh:mm a').format(order.timestamp);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.borderLight, width: 1.5),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(icons.Iconsax.receive_square_copy, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.storeName.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: AppTheme.darkText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order #$displayId • $dateStr',
                      style: GoogleFonts.outfit(
                        color: AppTheme.lightText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  earnStr,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF059669),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).animate().fadeIn(delay: 400.ms);
  }
}
