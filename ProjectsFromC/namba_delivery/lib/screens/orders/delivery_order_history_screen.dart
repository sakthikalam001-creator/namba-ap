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
              return _buildHistoryCard(order);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(DeliveryOrder order) {
    final isCancelled = order.status == DeliveryStatus.cancelled;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ORDER #${order.id.substring(order.id.length - 6).toUpperCase()}', 
                    style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(DateFormat('MMM dd, yyyy • hh:mm a').format(order.timestamp), 
                    style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCancelled ? Colors.red.withValues(alpha: 0.1) : AppTheme.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCancelled ? 'CANCELLED' : 'DELIVERED',
                  style: GoogleFonts.outfit(
                    color: isCancelled ? Colors.red : AppTheme.accentGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 32, color: AppTheme.lightBg),
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
                    Text(order.storeAddress, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text('₹${order.totalAmount.toStringAsFixed(0)}', 
                style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
