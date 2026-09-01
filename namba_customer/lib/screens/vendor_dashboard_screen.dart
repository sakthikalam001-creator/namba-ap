import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Vendor Dashboard', 
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF4F46E5)),
            tooltip: 'Vendor Help & Support Desk',
            onPressed: () => _showVendorSupportDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          final allOrders = orderProvider.orders;
          
          if (allOrders.isEmpty) {
            return const Center(child: Text('No orders to manage.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allOrders.length,
            itemBuilder: (context, index) {
              final order = allOrders[index];
              return _buildOrderCard(context, order, orderProvider);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, DeliveryOrder order, OrderProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('ID: #${order.id.substring(order.id.length - 6)}', 
            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.grey)),
          _statusBadge(order.status),
        ]),
        const Divider(height: 24),
        Text('Customer Address:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Text(order.deliveryAddress, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 12),
        if (order.orderType == OrderType.text)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text('Text Order: ${order.textContent}', style: const TextStyle(fontSize: 13)),
          ),
        const SizedBox(height: 16),
        
        // Management Actions
        Row(children: [
          if (order.status == OrderStatus.placed)
            Expanded(child: _actionBtn('Accept', const Color(0xFF10B981), () {
              // Usually we'd use a vendor-specific provider, but for mock we use OrderProvider's update
              // In production, this would be an API call
              _updateSimulatedStatus(order, OrderStatus.accepted, provider);
            })),
          if (order.status == OrderStatus.accepted)
            Expanded(child: _actionBtn('Out for Delivery', const Color(0xFF6366F1), () {
              _updateSimulatedStatus(order, OrderStatus.outForDelivery, provider);
            })),
          if (order.status == OrderStatus.outForDelivery)
            Expanded(child: _actionBtn('Mark Delivered', const Color(0xFF4F46E5), () {
              _updateSimulatedStatus(order, OrderStatus.delivered, provider);
            })),
        ]),
      ]),
    );
  }

  void _updateSimulatedStatus(DeliveryOrder order, OrderStatus status, OrderProvider provider) {
    // We use reflection/access to update the order status
    // For this mock, we'll just call the provider's private simulation-like update
    // Actually, I'll add a public updateOrderStatus to OrderProvider
    provider.updateOrderStatus(order.id, status);
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _statusBadge(OrderStatus s) {
    final color = {
      OrderStatus.placed: const Color(0xFFF59E0B),
      OrderStatus.accepted: const Color(0xFF3B82F6),
      OrderStatus.outForDelivery: const Color(0xFF8B5CF6),
      OrderStatus.delivered: const Color(0xFF10B981),
      OrderStatus.rejected: const Color(0xFFEF4444),
    }[s]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(s.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  void _showVendorSupportDialog(BuildContext context) {
    String selectedCategory = 'Menu / Pricing Update';
    String selectedPriority = 'Medium';
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final orderCtrl = TextEditingController();
    bool isSubmitting = false;

    final categories = [
      'Menu / Pricing Update',
      'Settlement & Payout Dispute',
      'Driver Delay / No Show',
      'Packaging / Order Mismatch',
      'Store App / Device Issue',
      'General Support',
    ];

    showDialog(
      context: context,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.storefront_rounded, color: Color(0xFF7C3AED), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vendor Help Desk', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        Text('Raise a support ticket to Super Admin', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setDialogState(() => selectedCategory = val ?? categories.first),
                      ),
                      const SizedBox(height: 14),

                      const Text('ORDER ID (OPTIONAL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: orderCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. ORD-9821',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text('PROBLEM DESCRIPTION *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: messageCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Explain the issue or required change in detail...',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    final msg = messageCtrl.text.trim();
                    if (msg.isEmpty) return;

                    setDialogState(() => isSubmitting = true);
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final userName = auth.name.isNotEmpty ? auth.name : 'Partner Store';
                    final userPhone = auth.phone.isNotEmpty ? auth.phone : '9876543210';

                    final payload = {
                      'userType': 'Vendor',
                      'userId': auth.uid,
                      'userName': userName,
                      'userPhone': userPhone,
                      'subject': '$selectedCategory - $userName',
                      'category': selectedCategory,
                      'issueType': selectedCategory,
                      'priority': selectedPriority,
                      'orderDisplayId': orderCtrl.text.trim(),
                      'message': msg,
                    };

                    final res = await CustomerApiService().createSupportTicket(payload);
                    setDialogState(() => isSubmitting = false);
                    Navigator.pop(dCtx);

                    if (res != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🎉 Ticket #${res['ticketId']} raised! Admin team notified.'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isSubmitting ? 'Submitting...' : 'SUBMIT TICKET'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
