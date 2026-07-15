import re

filepath = 'lib/super_admin_dashboard.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add switch case
content = re.sub(
    r'(case 18: return _buildFinancialIntelligence\(\);\n)',
    r'\1      case 19: return _buildFailedPayments();\n',
    content
)

# 2. Add Sidebar Item
content = re.sub(
    r"(\{'icon': Icons.paid_rounded, 'label': 'Financial IQ'\},)",
    r"\1\n      {'icon': Icons.money_off_rounded, 'label': 'Failed Payments'},",
    content
)

# 3. Add Method
method_code = """
  bool _isFailedPaymentsLoading = false;
  List<dynamic> _failedPayments = [];

  Future<void> _fetchFailedPayments() async {
    setState(() => _isFailedPaymentsLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/orders/failed-payments'), headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _failedPayments = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching failed payments: $e');
    } finally {
      if (mounted) setState(() => _isFailedPaymentsLoading = false);
    }
  }

  Widget _buildFailedPayments() {
    return _BaseTabContainer(
      title: 'Failed Payments',
      icon: Icons.money_off_rounded,
      onRefresh: _fetchFailedPayments,
      child: _isFailedPaymentsLoading
          ? const Center(child: CircularProgressIndicator())
          : _failedPayments.isEmpty
              ? const Center(child: Text('No failed payments found.', style: TextStyle(fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _failedPayments.length,
                  itemBuilder: (context, index) {
                    final order = _failedPayments[index];
                    final customerName = order['customer'] != null ? order['customer']['name'] : 'Unknown';
                    final vendorName = order['vendor'] != null ? order['vendor']['storeName'] : 'Unknown';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.error_outline_rounded, color: Colors.red),
                        ),
                        title: Text('Order: ${order['displayId'] ?? order['_id']} - ₹${order['totalAmount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Customer: $customerName\\nVendor: $vendorName', style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(order['paymentMethod'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(order['createdAt'] != null ? order['createdAt'].toString().substring(0, 10) : '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
"""

content = re.sub(r'\}\s*$', method_code, content)

# 4. Add to initState
content = re.sub(
    r'(_fetchServiceZones\(\);\n)',
    r'\1    _fetchFailedPayments();\n',
    content
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched successfully")
