import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/delivery_provider.dart';
import '../../models/delivery_order.dart';

class DeliveryOrderHistoryScreen extends StatefulWidget {
  const DeliveryOrderHistoryScreen({super.key});

  @override
  State<DeliveryOrderHistoryScreen> createState() => _DeliveryOrderHistoryScreenState();
}

class _DeliveryOrderHistoryScreenState extends State<DeliveryOrderHistoryScreen> {
  String _selectedFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'ORDER HISTORY',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2, color: const Color(0xFF0F172A)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, child) {
          final allHistory = provider.orderHistory;

          // Filter history
          final history = allHistory.where((order) {
            if (_selectedFilter == 'DELIVERED') return order.status == DeliveryStatus.delivered;
            if (_selectedFilter == 'CANCELLED') return order.status == DeliveryStatus.cancelled;
            return true;
          }).toList();

          // Total Earnings calculation
          double totalEarnings = 0.0;
          for (final o in allHistory) {
            if (o.status == DeliveryStatus.delivered) {
              final earn = o.computedDriverEarnings > 0 ? o.computedDriverEarnings : (o.driverEarningsBackend ?? 10.0);
              totalEarnings += earn;
            }
          }

          return Column(
            children: [
              // ── Summary Card: Amount, Date & Time Only ──
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL EARNINGS', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text('₹${totalEarnings.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: const Color(0xFF4ADE80), fontSize: 28, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 5),
                            Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 5),
                            Text(DateFormat('hh:mm a').format(DateTime.now()), style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Filter Chips ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All (${allHistory.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('DELIVERED', 'Delivered (${allHistory.where((o) => o.status == DeliveryStatus.delivered).length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('CANCELLED', 'Cancelled (${allHistory.where((o) => o.status == DeliveryStatus.cancelled).length})'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Order Cards List (Clean: Order ID, Date & Time, Payout Amount) ──
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppTheme.softShadow),
                              child: const Icon(icons.Iconsax.box_copy, color: Color(0xFF94A3B8), size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text('NO ORDERS FOUND', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            Text('No records matching the selected filter.', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        physics: const BouncingScrollPhysics(),
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final order = history[index];
                          return _buildHistoryCard(context, order);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.25), blurRadius: 6)] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, DeliveryOrder order) {
    final earningsVal = order.computedDriverEarnings > 0 ? order.computedDriverEarnings : (order.driverEarningsBackend ?? 10.0);
    final isDelivered = order.status == DeliveryStatus.delivered;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Order ID & Date / Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      order.displayId.isNotEmpty ? order.displayId : '#${order.id.substring(0, 6).toUpperCase()}',
                      style: GoogleFonts.outfit(color: const Color(0xFF4F46E5), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDelivered ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isDelivered ? 'DELIVERED' : 'CANCELLED',
                      style: GoogleFonts.outfit(
                        color: isDelivered ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(order.timestamp.toLocal()),
                    style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),

          // Right: Payout Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${earningsVal.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  color: isDelivered ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'PAYOUT',
                style: GoogleFonts.outfit(
                  color: isDelivered ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
