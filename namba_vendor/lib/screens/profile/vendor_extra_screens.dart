import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/vendor_order_provider.dart';
import '../../services/api_service.dart';

// ═══════════════════════════════════════════════════════════
// 1. OPERATING HOURS SCREEN
// ═══════════════════════════════════════════════════════════
class OperatingHoursScreen extends StatefulWidget {
  const OperatingHoursScreen({super.key});
  @override
  State<OperatingHoursScreen> createState() => _OperatingHoursScreenState();
}

class _OperatingHoursScreenState extends State<OperatingHoursScreen> {
  bool _autoSchedulingEnabled = false;
  late List<Map<String, dynamic>> _days;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<VendorOrderProvider>().profile;
    _autoSchedulingEnabled = profile?.autoSchedulingEnabled ?? false;
    
    if (profile != null && profile.operatingHours != null && profile.operatingHours!.isNotEmpty) {
      _days = profile.operatingHours!.map((item) {
        return {
          'day': item['day']?.toString() ?? '',
          'open': item['open'] == true,
          'from': _parseTimeOfDay(item['from']?.toString() ?? '09:00'),
          'to': _parseTimeOfDay(item['to']?.toString() ?? '21:00'),
        };
      }).toList();
    } else {
      _days = [
        {'day': 'Monday', 'open': true, 'from': const TimeOfDay(hour: 9, minute: 0), 'to': const TimeOfDay(hour: 21, minute: 0)},
        {'day': 'Tuesday', 'open': true, 'from': const TimeOfDay(hour: 9, minute: 0), 'to': const TimeOfDay(hour: 21, minute: 0)},
        {'day': 'Wednesday', 'open': true, 'from': const TimeOfDay(hour: 9, minute: 0), 'to': const TimeOfDay(hour: 21, minute: 0)},
        {'day': 'Thursday', 'open': true, 'from': const TimeOfDay(hour: 9, minute: 0), 'to': const TimeOfDay(hour: 21, minute: 0)},
        {'day': 'Friday', 'open': true, 'from': const TimeOfDay(hour: 9, minute: 0), 'to': const TimeOfDay(hour: 22, minute: 0)},
        {'day': 'Saturday', 'open': true, 'from': const TimeOfDay(hour: 8, minute: 0), 'to': const TimeOfDay(hour: 22, minute: 0)},
        {'day': 'Sunday', 'open': false, 'from': const TimeOfDay(hour: 10, minute: 0), 'to': const TimeOfDay(hour: 20, minute: 0)},
      ];
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _timeToStr(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

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

  Future<void> _saveTimings() async {
    setState(() => _isSaving = true);
    final payload = _days.map((item) {
      return {
        'day': item['day'],
        'open': item['open'],
        'from': _timeToStr(item['from'] as TimeOfDay),
        'to': _timeToStr(item['to'] as TimeOfDay),
      };
    }).toList();

    final provider = context.read<VendorOrderProvider>();
    final success = await provider.saveOperatingHours(payload, _autoSchedulingEnabled);
    
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timings saved successfully!'), backgroundColor: Color(0xFF059669)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save timings. Please try again.'), backgroundColor: Colors.red),
        );
      }
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
          _isSaving
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
              : TextButton(
                  onPressed: _saveTimings,
                  child: Text('Save', style: GoogleFonts.outfit(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w900, fontSize: 16)),
                ),
        ],
      ),
      body: Column(children: [
        // ⏰ Auto-Scheduling Switch Card
        Container(
          margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            border: Border.all(
              color: _autoSchedulingEnabled ? const Color(0xFF4F46E5).withOpacity(0.2) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.alarm_on_rounded, color: Color(0xFF4F46E5), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-Scheduling',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.darkText),
                    ),
                    Text(
                      'Auto open/close store at set times',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _autoSchedulingEnabled,
                onChanged: (v) => setState(() => _autoSchedulingEnabled = v),
                activeColor: const Color(0xFF4F46E5),
              ),
            ],
          ),
        ),
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
// ═══════════════════════════════════════════════════════════
// 2. CUSTOMER RATINGS SCREEN
// ═══════════════════════════════════════════════════════════
class CustomerRatingsScreen extends StatefulWidget {
  const CustomerRatingsScreen({super.key});

  @override
  State<CustomerRatingsScreen> createState() => _CustomerRatingsScreenState();
}

class _CustomerRatingsScreenState extends State<CustomerRatingsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 5.0;
  int _totalCount = 0;
  List<int> _counts = [0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    final vendor = Provider.of<VendorOrderProvider>(context, listen: false).profile;
    if (vendor == null || vendor.id.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final apiService = VendorApiService();
    final data = await apiService.getVendorReviews(vendor.id);

    if (data != null && mounted) {
      final rawList = List<Map<String, dynamic>>.from(data['reviews'] ?? []);
      final avg = (data['averageRating'] != null) ? (data['averageRating'] as num).toDouble() : 5.0;
      final total = data['totalCount'] ?? rawList.length;
      final rawCounts = data['counts'] as Map<String, dynamic>?;

      List<int> countList = [0, 0, 0, 0, 0];
      if (rawCounts != null) {
        countList = [
          (rawCounts['5'] as num?)?.toInt() ?? 0,
          (rawCounts['4'] as num?)?.toInt() ?? 0,
          (rawCounts['3'] as num?)?.toInt() ?? 0,
          (rawCounts['2'] as num?)?.toInt() ?? 0,
          (rawCounts['1'] as num?)?.toInt() ?? 0,
        ];
      } else {
        countList = [5, 4, 3, 2, 1].map((s) => rawList.where((r) => r['rating'] == s).length).toList();
      }

      setState(() {
        _reviews = rawList;
        _averageRating = avg;
        _totalCount = total;
        _counts = countList;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Customer Ratings', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5))))
          : SingleChildScrollView(
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
                      Text(_averageRating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900)),
                      Row(children: List.generate(5, (i) => Icon(i < _averageRating.round() ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 20))),
                      const SizedBox(height: 4),
                      Text('$_totalCount reviews', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    ]),
                    const SizedBox(width: 24),
                    Expanded(child: Column(children: List.generate(5, (i) {
                      final star = 5 - i;
                      final count = _counts[i];
                      final pct = _totalCount == 0 ? 0.0 : count / _totalCount;
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
                if (_reviews.isEmpty) ...[
                  const SizedBox(height: 40),
                  Center(child: Column(children: [
                    Icon(Icons.star_outline_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No customer reviews yet', style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Reviews will appear here when customers rate your orders.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400), textAlign: TextAlign.center),
                  ])),
                ] else
                  ..._reviews.map((r) {
                    final name = (r['customerName'] ?? r['name'] ?? 'Customer').toString();
                    final ratingVal = (r['rating'] != null) ? (r['rating'] as num).toInt() : 5;
                    final commentStr = (r['comment'] ?? r['review'] ?? '').toString();
                    final orderStr = (r['orderType'] ?? r['order'] ?? 'Order').toString();
                    final dateStr = r['createdAt'] != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(r['createdAt'].toString()).toLocal())
                        : (r['date'] ?? 'Recent').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          CircleAvatar(radius: 20, backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4F46E5)))),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                            Text(orderStr, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade400)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Row(children: List.generate(5, (i) => Icon(i < ratingVal ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 16))),
                            Text(dateStr, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade400)),
                          ]),
                        ]),
                        if (commentStr.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(commentStr, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
                        ],
                      ]),
                    );
                  }),
              ]),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 3. COUPONS & OFFERS SCREEN (PROFESSIONAL VENDOR DESIGN)
// ═══════════════════════════════════════════════════════════
class CouponsOffersScreen extends StatefulWidget {
  const CouponsOffersScreen({super.key});
  @override
  State<CouponsOffersScreen> createState() => _CouponsOffersScreenState();
}

class _CouponsOffersScreenState extends State<CouponsOffersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _coupons = [];

  @override
  void initState() {
    super.initState();
    _fetchCoupons();
  }

  Future<void> _fetchCoupons() async {
    final vendor = Provider.of<VendorOrderProvider>(context, listen: false).profile;
    if (vendor == null || vendor.id.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final apiService = VendorApiService();
    final rawList = await apiService.getVendorOffers(vendor.id);
    if (mounted) {
      setState(() {
        _coupons = rawList;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _coupons.where((c) => (c['isActive'] ?? c['active'] ?? true) == true).length;
    final totalRedemptions = _coupons.fold(0, (sum, c) => sum + ((c['usesCount'] ?? c['uses'] ?? 0) as num).toInt());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1E293B)), onPressed: () => Navigator.pop(context)),
        title: Text('Coupons & Marketing', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: const Color(0xFF1E293B))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCouponSheet(context),
        backgroundColor: const Color(0xFF4F46E5),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Coupon', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5))))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Marketing Metrics Header Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E1B4B).withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACTIVE COUPONS',
                                style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$activeCount / ${_coupons.length}',
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.white.withOpacity(0.15)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL USAGE',
                                style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$totalRedemptions Redemptions',
                                style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Active Promos & Discounts',
                    style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),

                  if (_coupons.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Iconsax.discount_circle_copy, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No coupons created yet', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('Tap + New Coupon to offer discounts and boost store orders.', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_coupons.length, (i) => _couponCard(_coupons[i], i)),
                ],
              ),
            ),
    );
  }

  Widget _couponCard(Map<String, dynamic> c, int i) {
    final offerId = (c['_id'] ?? c['id'] ?? '').toString();
    final code = (c['code'] ?? 'COUPON').toString();
    final type = (c['discountType'] ?? c['type'] ?? 'Percentage').toString();
    final value = (c['discountValue'] ?? c['value'] ?? 10).toString();
    final minOrder = (c['minOrderAmount'] ?? c['minOrder'] ?? 0).toString();
    final uses = (c['usesCount'] ?? c['uses'] ?? 0).toString();
    final isActive = (c['isActive'] ?? c['active'] ?? true) == true;

    final dateStr = c['expiresAt'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(c['expiresAt'].toString()).toLocal())
        : (c['expires'] ?? 'Never').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isActive ? const Color(0xFF818CF8).withOpacity(0.3) : Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [const Color(0xFF4F46E5), const Color(0xFF6366F1)]
                    : [Colors.grey.shade400, Colors.grey.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                      Text(
                        '${type == 'Percentage' ? '$value% OFF' : 'FLAT ₹$value OFF'} • Min Order ₹$minOrder',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isActive,
                  onChanged: (v) async {
                    setState(() => _coupons[i]['isActive'] = v);
                    if (offerId.isNotEmpty) {
                      final apiService = VendorApiService();
                      await apiService.updateOffer(offerId, {'isActive': v});
                    }
                  },
                  activeColor: Colors.white,
                ),
              ],
            ),
          ),

          // Bottom Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 4),
                      Text(
                        '$uses Used',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Expires: $dateStr',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  onPressed: () async {
                    setState(() => _coupons.removeAt(i));
                    if (offerId.isNotEmpty) {
                      final apiService = VendorApiService();
                      await apiService.deleteOffer(offerId);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCouponSheet(BuildContext context) {
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final minOrderCtrl = TextEditingController();
    String type = 'Percentage';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Create New Coupon',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B)),
              ),
              const SizedBox(height: 4),
              Text(
                'Attract more customers with exclusive discount codes',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),

              _inputField(codeCtrl, 'Coupon Code (e.g. NAMBA20)', Icons.local_offer_rounded),
              const SizedBox(height: 14),

              // Discount Type Switcher
              Row(
                children: [
                  Expanded(child: _typeBtn('Percentage %', type == 'Percentage', () => setS(() => type = 'Percentage'))),
                  const SizedBox(width: 12),
                  Expanded(child: _typeBtn('Flat Amount ₹', type == 'Flat', () => setS(() => type = 'Flat'))),
                ],
              ),
              const SizedBox(height: 14),

              _inputField(
                valueCtrl,
                type == 'Percentage' ? 'Discount Value % (e.g. 15)' : 'Flat Discount Amount ₹ (e.g. 50)',
                Icons.percent_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),

              _inputField(
                minOrderCtrl,
                'Minimum Order Amount ₹ (e.g. 200)',
                Icons.shopping_bag_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (codeCtrl.text.trim().isNotEmpty) {
                      final code = codeCtrl.text.trim().toUpperCase();
                      final val = double.tryParse(valueCtrl.text.trim()) ?? 10;
                      final minOrd = double.tryParse(minOrderCtrl.text.trim()) ?? 100;
                      final vendor = Provider.of<VendorOrderProvider>(context, listen: false).profile;

                      Navigator.pop(ctx);

                      final newOfferData = {
                        'vendorId': vendor?.id ?? '',
                        'code': code,
                        'title': '$code Special Offer',
                        'description': 'Get ${type == 'Percentage' ? '$val%' : '₹$val'} OFF on orders above ₹$minOrd',
                        'discountType': type,
                        'discountValue': val,
                        'minOrderAmount': minOrd,
                      };

                      final apiService = VendorApiService();
                      final created = await apiService.createOffer(newOfferData);

                      if (created != null) {
                        _fetchCoupons();
                      } else {
                        setState(() {
                          _coupons.insert(0, {
                            'code': code,
                            'discountType': type,
                            'discountValue': val,
                            'minOrderAmount': minOrd,
                            'usesCount': 0,
                            'isActive': true,
                            'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                          });
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    'CREATE & PUBLISH COUPON',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

// ═══════════════════════════════════════════════════════════
// 6. IN-APP AD CAMPAIGNS SCREEN (VENDOR ADS MANAGEMENT)
// ═══════════════════════════════════════════════════════════
class VendorAdCampaignsScreen extends StatefulWidget {
  const VendorAdCampaignsScreen({super.key});

  @override
  State<VendorAdCampaignsScreen> createState() => _VendorAdCampaignsScreenState();
}

class _VendorAdCampaignsScreenState extends State<VendorAdCampaignsScreen> {
  bool _isLoading = true;
  bool _canRunAds = false;
  List<Map<String, dynamic>> _ads = [];

  @override
  void initState() {
    super.initState();
    _fetchAds();
  }

  Future<void> _fetchAds() async {
    final vendor = Provider.of<VendorOrderProvider>(context, listen: false).profile;
    if (vendor == null || vendor.id.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final apiService = VendorApiService();
    final data = await apiService.getVendorAds(vendor.id);

    if (mounted) {
      if (data != null) {
        setState(() {
          _canRunAds = data['canRunAds'] == true;
          _ads = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalClicks = _ads.fold(0, (sum, a) => sum + ((a['clickCount'] ?? 0) as num).toInt());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1E293B)), onPressed: () => Navigator.pop(context)),
        title: Text('In-App Advertisements', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: const Color(0xFF1E293B))),
      ),
      floatingActionButton: _canRunAds
          ? FloatingActionButton.extended(
              onPressed: () => _showAddBannerSheet(context),
              backgroundColor: const Color(0xFF4F46E5),
              elevation: 4,
              icon: const Icon(Icons.campaign_rounded, color: Colors.white),
              label: Text('New Ad Banner', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5))))
          : !_canRunAds
              ? _buildLockedAdScreen()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Analytics Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF4338CA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ACTIVE CAMPAIGNS', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                  const SizedBox(height: 4),
                                  Text('${_ads.length}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 40, color: Colors.white.withOpacity(0.15)),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('TOTAL AD CLICKS', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                  const SizedBox(height: 4),
                                  Text('$totalClicks Clicks', style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontSize: 18, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text('Your Active Customer Banners', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
                      const SizedBox(height: 12),

                      if (_ads.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(Iconsax.gallery_copy, size: 56, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text('No active ad banners', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text('Tap + New Ad Banner to feature your store on Customer App!', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(_ads.length, (i) => _adCard(_ads[i], i)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLockedAdScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
              child: const Icon(Icons.lock_rounded, size: 48, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 24),
            Text(
              'Ad Campaigns Locked',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B)),
            ),
            const SizedBox(height: 10),
            Text(
              'In-App Customer Ads feature is not enabled for your store yet. Please contact Namba Admin Support to grant Ad permissions.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adCard(Map<String, dynamic> ad, int index) {
    final adId = (ad['_id'] ?? ad['id'] ?? '').toString();
    final title = (ad['title'] ?? 'Store Ad').toString();
    final subtitle = (ad['subtitle'] ?? '').toString();
    final clicks = (ad['clickCount'] ?? 0).toString();
    final isActive = (ad['status'] ?? 'Active') == 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive ? [const Color(0xFF4F46E5), const Color(0xFF6366F1)] : [Colors.grey.shade400, Colors.grey.shade500],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isActive,
                  onChanged: (v) async {
                    setState(() => _ads[index]['status'] = v ? 'Active' : 'Paused');
                    if (adId.isNotEmpty) {
                      final apiService = VendorApiService();
                      await apiService.updateAd(adId, {'status': v ? 'Active' : 'Paused'});
                    }
                  },
                  activeColor: Colors.white,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, color: Color(0xFF4F46E5), size: 18),
                const SizedBox(width: 6),
                Text('$clicks Customer Clicks', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF1E293B))),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  onPressed: () async {
                    setState(() => _ads.removeAt(index));
                    if (adId.isNotEmpty) {
                      final apiService = VendorApiService();
                      await apiService.deleteAd(adId);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBannerSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    final imageCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            Text('Create Ad Banner', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B))),
            const SizedBox(height: 4),
            Text('Promote your store to all active customers in your area', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 24),

            _inputField(titleCtrl, 'Ad Campaign Title (e.g. 20% Off Weekend Feast)', Icons.title_rounded),
            const SizedBox(height: 14),
            _inputField(subtitleCtrl, 'Tagline / Subtitle (e.g. Freshly Baked Goodness)', Icons.subtitles_rounded),
            const SizedBox(height: 14),
            _inputField(imageCtrl, 'Banner Image URL (optional)', Icons.image_rounded),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isNotEmpty) {
                    final vendor = Provider.of<VendorOrderProvider>(context, listen: false).profile;
                    Navigator.pop(ctx);

                    final adData = {
                      'vendorId': vendor?.id ?? '',
                      'title': titleCtrl.text.trim(),
                      'subtitle': subtitleCtrl.text.trim(),
                      'imageUrl': imageCtrl.text.trim(),
                    };

                    final apiService = VendorApiService();
                    await apiService.createAd(adData);
                    _fetchAds();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: Text('PUBLISH AD BANNER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500),
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
      ),
    );
  }
}

