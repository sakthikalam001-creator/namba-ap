import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/delivery_provider.dart';
import '../../models/delivery_order.dart';

class DeliveryOrderHistoryScreen extends StatelessWidget {
  const DeliveryOrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('ORDER HISTORY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, child) {
          final history = provider.orderHistory;

          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppTheme.softShadow),
                    child: const Icon(icons.Iconsax.box_copy, color: AppTheme.lightText, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text('NO ORDERS YET', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.darkText)),
                  const SizedBox(height: 8),
                  Text('Your completed deliveries will appear here.', style: GoogleFonts.outfit(color: AppTheme.lightText, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final order = history[index];
              return _buildHistoryCard(context, order);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, DeliveryOrder order) {
    final earningsVal = order.computedDriverEarnings > 0 
        ? order.computedDriverEarnings 
        : (order.driverEarningsBackend ?? 10.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ORDER #${order.displayId.isNotEmpty ? order.displayId : order.id.substring(0, 6).toUpperCase()}', 
                style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('DELIVERED', 
                  style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(order.timestamp),
                style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.lightBg),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.lightBg, shape: BoxShape.circle),
                child: const Icon(icons.Iconsax.shop_copy, color: AppTheme.primaryOrange, size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.storeName, style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 16, fontWeight: FontWeight.w900)),
                    if (order.storeAddress.isNotEmpty)
                      Text(order.storeAddress, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${earningsVal.toStringAsFixed(0)}', 
                    style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('RIDER PAYOUT', 
                    style: GoogleFonts.outfit(color: AppTheme.accentGreen.withValues(alpha: 0.9), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
