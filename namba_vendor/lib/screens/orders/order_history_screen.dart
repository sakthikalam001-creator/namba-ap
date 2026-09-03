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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filteredOrders = orderProvider.orders.where((order) {
      final matchesSearch = order.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.customerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatus == null || order.status == _selectedStatus;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: isDark ? Colors.white : AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.translate('order_history'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.darkText,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(lang, isDark),
          Expanded(
            child: filteredOrders.isEmpty
                ? _buildEmptyState(lang, isDark)
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(filteredOrders[index], lang, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      color: isDark ? const Color(0xFF131B2E) : Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: GoogleFonts.outfit(color: isDark ? Colors.white : AppTheme.darkText, fontSize: 14),
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: lang.translate('search'),
              hintStyle: GoogleFonts.outfit(color: isDark ? const Color(0xFF64748B) : AppTheme.lightText, fontSize: 14),
              prefixIcon: Icon(Iconsax.search_normal, size: 18, color: isDark ? const Color(0xFF94A3B8) : AppTheme.lightText),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
                _statusFilterChip(null, 'All Orders', isDark),
                _statusFilterChip(VendorOrderStatus.pending, 'Pending', isDark),
                _statusFilterChip(VendorOrderStatus.preparing, 'Preparing', isDark),
                _statusFilterChip(VendorOrderStatus.ready, 'Ready', isDark),
                _statusFilterChip(VendorOrderStatus.handedOver, 'Delivered', isDark),
                _statusFilterChip(VendorOrderStatus.rejected, 'Cancelled', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusFilterChip(VendorOrderStatus? status, String label, bool isDark) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
        selected: isSelected,
        onSelected: (v) => setState(() => _selectedStatus = v ? status : null),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedColor: isDark ? const Color(0xFF2563EB) : AppTheme.primaryOrange.withValues(alpha: 0.1),
        labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), 
          side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
        ),
      ),
    );
  }

  Widget _buildOrderCard(VendorOrderModel order, LanguageProvider lang, bool isDark) {
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
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: const Color(0xFF273552), width: 1.2) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
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
                    order.shortDisplayId,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.darkText,
                    ),
                  ),
                  Text(
                    '${order.timestamp.day} ${_getMonthName(order.timestamp.month)} • ${order.timestamp.hour}:${order.timestamp.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.outfit(fontSize: 12, color: isDark ? const Color(0xFF64748B) : AppTheme.lightText),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
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
          Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.15),
                child: const Icon(Iconsax.user, size: 14, color: AppTheme.primaryOrange),
              ),
              const SizedBox(width: 8),
              Text(
                order.customerName,
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFFE2E8F0) : AppTheme.darkText),
              ),
              const Spacer(),
              Text(
                order.formattedPrice,
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.darkText),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildEmptyState(LanguageProvider lang, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.box_search, size: 64, color: isDark ? const Color(0xFF475569) : AppTheme.lightText),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.mediumText),
          ),
          Text(
            'Try searching for something else.',
            style: GoogleFonts.outfit(fontSize: 14, color: isDark ? const Color(0xFF64748B) : AppTheme.lightText),
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

