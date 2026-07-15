import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════
// 1. OPERATING HOURS SCREEN
// ═══════════════════════════════════════════════════════════
class OperatingHoursScreen extends StatefulWidget {
  const OperatingHoursScreen({super.key});
  @override
  State<OperatingHoursScreen> createState() => _OperatingHoursScreenState();
}

class _OperatingHoursScreenState extends State<OperatingHoursScreen> {
  final List<Map<String, dynamic>> _days = [
    {'day': 'Monday', 'open': true, 'from': const TimeOfDay(hour: 9, minute: 0), 'to': const TimeOfDay(hour: 21, minute: 0)},
    {'day': 'Tuesday', 'open': true, 'from': const TimeOfDay(hour: 9, minute: 0), 'to': const TimeOfDay(hour: 21, minute: 0)},
    {'day': 'Wednesday', 'open': true, 'from': const TimeOfDay(hour: 9, minute: 0), 'to': const TimeOfDay(hour: 21, minute: 0)},
    {'day': 'Thursday', 'open': true, 'from': const TimeOfDay(hour: 9, minute: 0), 'to': const TimeOfDay(hour: 21, minute: 0)},
    {'day': 'Friday', 'open': true, 'from': const TimeOfDay(hour: 9, minute: 0), 'to': const TimeOfDay(hour: 22, minute: 0)},
    {'day': 'Saturday', 'open': true, 'from': const TimeOfDay(hour: 8, minute: 0), 'to': const TimeOfDay(hour: 22, minute: 0)},
    {'day': 'Sunday', 'open': false, 'from': const TimeOfDay(hour: 10, minute: 0), 'to': const TimeOfDay(hour: 20, minute: 0)},
  ];

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  Future<void> _pickTime(int idx, bool isFrom) async {
    final current = isFrom ? _days[idx]['from'] as TimeOfDay : _days[idx]['to'] as TimeOfDay;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) {
      setState(() {
        if (isFrom) _days[idx]['from'] = picked;
        else _days[idx]['to'] = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Operating Hours', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hours saved!'), backgroundColor: Color(0xFF059669))); },
            child: Text('Save', style: GoogleFonts.outfit(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF4F46E5), size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Set your store timings. Customers can only order during these hours.', style: GoogleFonts.outfit(color: const Color(0xFF4F46E5), fontSize: 12, fontWeight: FontWeight.w600))),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _days.length,
            itemBuilder: (_, i) {
              final day = _days[i];
              final isOpen = day['open'] as bool;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(day['day'], style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16))),
                    Switch.adaptive(
                      value: isOpen,
                      onChanged: (v) => setState(() => _days[i]['open'] = v),
                      activeColor: const Color(0xFF4F46E5),
                    ),
                    Text(isOpen ? 'Open' : 'Closed', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: isOpen ? const Color(0xFF059669) : Colors.red.shade400, fontSize: 13)),
                  ]),
                  if (isOpen) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _timeChip('From', _fmt(day['from'] as TimeOfDay), () => _pickTime(i, true))),
                      const SizedBox(width: 12),
                      Expanded(child: _timeChip('To', _fmt(day['to'] as TimeOfDay), () => _pickTime(i, false))),
                    ]),
                  ],
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _timeChip(String label, String time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            Text(time, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5), fontSize: 14)),
          ]),
          const Icon(Icons.access_time_rounded, color: Color(0xFF4F46E5), size: 18),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 2. CUSTOMER RATINGS SCREEN
// ═══════════════════════════════════════════════════════════
class CustomerRatingsScreen extends StatelessWidget {
  const CustomerRatingsScreen({super.key});

  final List<Map<String, dynamic>> _reviews = const [
    {'name': 'Priya S', 'rating': 5, 'comment': 'Super fast delivery! Items were fresh and well packed.', 'date': 'Today, 2:30 PM', 'order': 'Grocery Order'},
    {'name': 'Rahul K', 'rating': 4, 'comment': 'Good quality groceries. Packaging was excellent.', 'date': 'Yesterday, 6:15 PM', 'order': 'Text Order'},
    {'name': 'Meena T', 'rating': 5, 'comment': 'Love this store! Always fresh and on time.', 'date': 'Mar 29, 11:30 AM', 'order': 'Food Order'},
    {'name': 'Kumar R', 'rating': 3, 'comment': 'Delivery was a bit late but quality was OK.', 'date': 'Mar 28, 7:45 PM', 'order': 'Grocery Order'},
    {'name': 'Anjali M', 'rating': 5, 'comment': 'Excellent! Best local store in the area.', 'date': 'Mar 27, 3:10 PM', 'order': 'Bakery Order'},
    {'name': 'Sundar V', 'rating': 4, 'comment': 'Good service. Will order again.', 'date': 'Mar 26, 1:20 PM', 'order': 'Medicine Order'},
  ];

  @override
  Widget build(BuildContext context) {
    final totalRating = _reviews.fold(0.0, (s, r) => s + (r['rating'] as int)) / _reviews.length;
    final counts = [5, 4, 3, 2, 1].map((s) => _reviews.where((r) => r['rating'] == s).length).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Customer Ratings', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Rating Summary
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(children: [
              Column(children: [
                Text(totalRating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900)),
                Row(children: List.generate(5, (i) => Icon(i < totalRating.round() ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 20))),
                const SizedBox(height: 4),
                Text('${_reviews.length} reviews', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              ]),
              const SizedBox(width: 24),
              Expanded(child: Column(children: List.generate(5, (i) {
                final star = 5 - i;
                final count = counts[i];
                final pct = _reviews.isEmpty ? 0.0 : count / _reviews.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Text('$star', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, backgroundColor: Colors.white.withOpacity(0.2), valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber), minHeight: 6))),
                    const SizedBox(width: 8),
                    Text('$count', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                );
              }))),
            ]),
          ),
          const SizedBox(height: 20),
          ..._reviews.map((r) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 20, backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1), child: Text(r['name'][0], style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4F46E5)))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(r['order'], style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade400)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(children: List.generate(5, (i) => Icon(i < (r['rating'] as int) ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 16))),
                  Text(r['date'], style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade400)),
                ]),
              ]),
              if (r['comment'] != null) ...[
                const SizedBox(height: 10),
                Text(r['comment'], style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
              ],
            ]),
          )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 3. COUPONS & OFFERS SCREEN
// ═══════════════════════════════════════════════════════════
class CouponsOffersScreen extends StatefulWidget {
  const CouponsOffersScreen({super.key});
  @override
  State<CouponsOffersScreen> createState() => _CouponsOffersScreenState();
}

class _CouponsOffersScreenState extends State<CouponsOffersScreen> {
  final List<Map<String, dynamic>> _coupons = [
    {'code': 'NAMBA10', 'type': 'Percentage', 'value': 10, 'minOrder': 200, 'uses': 45, 'active': true, 'expires': 'Apr 30, 2026'},
    {'code': 'FLAT50', 'type': 'Flat', 'value': 50, 'minOrder': 300, 'uses': 23, 'active': true, 'expires': 'Apr 15, 2026'},
    {'code': 'FIRST20', 'type': 'Percentage', 'value': 20, 'minOrder': 100, 'uses': 89, 'active': false, 'expires': 'Mar 31, 2026'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Coupons & Offers', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCouponSheet(context),
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Coupon', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: _coupons.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Iconsax.discount_circle, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No coupons yet', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 16)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: _coupons.length,
              itemBuilder: (_, i) => _couponCard(_coupons[i], i),
            ),
    );
  }

  Widget _couponCard(Map<String, dynamic> c, int i) {
    final isActive = c['active'] as bool;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)] : [Colors.grey.shade300, Colors.grey.shade400],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['code'], style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
              Text('${c['type'] == 'Percentage' ? '${c['value']}% off' : '₹${c['value']} off'} • Min ₹${c['minOrder']}',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
            Switch.adaptive(value: isActive, onChanged: (v) => setState(() => _coupons[i]['active'] = v), activeColor: Colors.white),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.people_rounded, size: 16, color: Colors.grey),
            Text(' ${c['uses']} used', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
            const Spacer(),
            const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
            Text(' Expires: ${c['expires']}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _coupons.removeAt(i)),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
            ),
          ]),
        ),
      ]),
    );
  }

  void _showAddCouponSheet(BuildContext context) {
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final minOrderCtrl = TextEditingController();
    String type = 'Percentage';

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Create Coupon', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          _inputField(codeCtrl, 'Coupon Code e.g. SAVE20', Icons.local_offer_rounded),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _typeBtn('Percentage', type == 'Percentage', () => setS(() => type = 'Percentage'))),
            const SizedBox(width: 10),
            Expanded(child: _typeBtn('Flat', type == 'Flat', () => setS(() => type = 'Flat'))),
          ]),
          const SizedBox(height: 12),
          _inputField(valueCtrl, type == 'Percentage' ? 'Discount % (e.g. 10)' : 'Flat amount ₹ (e.g. 50)', Icons.percent_rounded, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _inputField(minOrderCtrl, 'Minimum Order Value ₹', Icons.shopping_bag_rounded, keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (codeCtrl.text.isNotEmpty) {
                  setState(() => _coupons.insert(0, {
                    'code': codeCtrl.text.toUpperCase(),
                    'type': type,
                    'value': double.tryParse(valueCtrl.text) ?? 10,
                    'minOrder': double.tryParse(minOrderCtrl.text) ?? 100,
                    'uses': 0, 'active': true,
                    'expires': 'Apr 30, 2026',
                  }));
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: Text('Create Coupon', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ]),
      )),
    );
  }

  Widget _typeBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: selected ? Colors.white : Colors.grey.shade600))),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl, keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint, prefixIcon: Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
        filled: true, fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 4. ORDER REPORT SCREEN
// ═══════════════════════════════════════════════════════════
class OrderReportScreen extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const OrderReportScreen({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final delivered = orders.where((o) => o['status'] == 'handedOver').toList();
    final totalRev = delivered.fold(0.0, (s, o) => s + (o['totalAmount'] as double? ?? 0.0));
    final avgOrder = delivered.isEmpty ? 0.0 : totalRev / delivered.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Order Report', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF4F46E5)),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report shared (simulation)'))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Summary Cards
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
            children: [
              _stat('Total Orders', '${orders.length}', Icons.receipt_long_rounded, const Color(0xFF4F46E5)),
              _stat('Completed', '${delivered.length}', Icons.check_circle_rounded, const Color(0xFF059669)),
              _stat('Revenue', '₹${totalRev.toStringAsFixed(0)}', Icons.currency_rupee_rounded, const Color(0xFF7C3AED)),
              _stat('Avg Order', '₹${avgOrder.toStringAsFixed(0)}', Icons.trending_up_rounded, const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Today\'s Summary', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
            child: Column(children: [
              _row('Total Orders', '${orders.length}'),
              _row('Pending', '${orders.where((o) => o['status'] == 'pending').length}'),
              _row('Preparing', '${orders.where((o) => o['status'] == 'preparing').length}'),
              _row('Completed', '${delivered.length}'),
              const Divider(height: 20),
              _row('Revenue', '₹${totalRev.toStringAsFixed(0)}', bold: true),
            ]),
          ),
          const SizedBox(height: 24),
          Text('Payment Breakdown', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
            child: Column(children: [
              _row('Online Payments', '${(delivered.length * 0.7).round()}'),
              _row('Cash on Delivery', '${(delivered.length * 0.3).round()}'),
              const Divider(height: 20),
              _row('Commission (5%)', '-₹${(totalRev * 0.05).toStringAsFixed(0)}', color: Colors.red.shade400),
              _row('Net Earnings', '₹${(totalRev * 0.95).toStringAsFixed(0)}', bold: true, color: const Color(0xFF059669)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: Colors.grey.shade600)),
        const Spacer(),
        Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: color ?? Colors.black87)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 5. PRINT ORDER DIALOG  
// ═══════════════════════════════════════════════════════════
void showPrintOrderDialog(BuildContext context, {required String orderId, required String items, required double total, required String customerName}) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.receipt_long_rounded, size: 48, color: Color(0xFF4F46E5)),
          const SizedBox(height: 16),
          Text('Kitchen Slip', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #$orderId', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
              Text('Customer: $customerName', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600)),
              const Divider(),
              Text(items, style: GoogleFonts.outfit(fontSize: 13, height: 1.6)),
              const Divider(),
              Text('Total: ₹${total.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF4F46E5))),
              Text('Time: ${TimeOfDay.now().format(context)}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Close', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🖨️ Sending to printer...'), backgroundColor: Color(0xFF4F46E5)));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: Text('Print', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
            )),
          ]),
        ]),
      ),
    ),
  );
}

