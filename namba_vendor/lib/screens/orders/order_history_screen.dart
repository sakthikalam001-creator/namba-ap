import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/vendor_order_provider.dart';
import '../../services/language_provider.dart';
import '../../models/vendor_order_model.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  VendorOrderStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final orderProvider = Provider.of<VendorOrderProvider>(context);
    
    final filteredOrders = orderProvider.orders.where((order) {
      final matchesSearch = order.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.customerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatus == null || order.status == _selectedStatus;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.lightSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.translate('order_history'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(lang),
          Expanded(
            child: filteredOrders.isEmpty
                ? _buildEmptyState(lang)
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(filteredOrders[index], lang);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: lang.translate('search'),
              hintStyle: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 14),
              prefixIcon: const Icon(Iconsax.search_normal, size: 18, color: AppTheme.lightText),
              filled: true,
              fillColor: AppTheme.lightSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _statusFilterChip(null, 'All Orders'),
                _statusFilterChip(VendorOrderStatus.pending, 'Pending'),
                _statusFilterChip(VendorOrderStatus.preparing, 'Preparing'),
                _statusFilterChip(VendorOrderStatus.ready, 'Ready'),
                _statusFilterChip(VendorOrderStatus.handedOver, 'Delivered'),
                _statusFilterChip(VendorOrderStatus.rejected, 'Cancelled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusFilterChip(VendorOrderStatus? status, String label) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
        selected: isSelected,
        onSelected: (v) => setState(() => _selectedStatus = v ? status : null),
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryOrange.withValues(alpha: 0.1),
        labelStyle: TextStyle(color: isSelected ? AppTheme.primaryOrange : AppTheme.mediumText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildOrderCard(VendorOrderModel order, LanguageProvider lang) {
    Color statusColor;
    String statusLabel = order.status.name.toUpperCase();
    switch (order.status) {
      case VendorOrderStatus.pending: statusColor = AppTheme.primaryOrange; break;
      case VendorOrderStatus.preparing: statusColor = AppTheme.accentBlue; break;
      case VendorOrderStatus.ready: statusColor = AppTheme.accentGreen; break;
      case VendorOrderStatus.handedOver: statusColor = AppTheme.accentTeal; break;
      case VendorOrderStatus.rejected: statusColor = AppTheme.primaryRed; statusLabel = 'CANCELLED'; break;
      default: statusColor = AppTheme.lightText;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${order.id}',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                    ),
                  ),
                  Text(
                    '${order.timestamp.day} ${_getMonthName(order.timestamp.month)} • ${order.timestamp.hour}:${order.timestamp.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.lightText),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.1),
                child: const Icon(Iconsax.user, size: 14, color: AppTheme.primaryOrange),
              ),
              const SizedBox(width: 8),
              Text(
                order.customerName,
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '₹${order.totalAmount}',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.darkText),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildEmptyState(LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.box_search, size: 64, color: AppTheme.lightText),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.mediumText),
          ),
          Text(
            'Try searching for something else.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.lightText),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

