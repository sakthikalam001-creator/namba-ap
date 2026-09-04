import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/vendor_order_model.dart';
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
// 4. ADVANCED ORDER REPORT SCREEN (100% REAL DATA & ANALYTICS)
// ═══════════════════════════════════════════════════════════
class OrderReportScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? orders;
  const OrderReportScreen({super.key, this.orders});

  @override
  State<OrderReportScreen> createState() => _OrderReportScreenState();
}

class _OrderReportScreenState extends State<OrderReportScreen> {
  String _selectedRange = 'Today'; // 'Today', 'This Week', 'This Month', 'All Time'

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VendorOrderProvider>(context);
    final allOrders = provider.allOrders;

    final now = DateTime.now();

    // 1. Filter orders based on selected time range
    final filteredOrders = allOrders.where((order) {
      if (_selectedRange == 'Today') {
        return order.timestamp.year == now.year &&
               order.timestamp.month == now.month &&
               order.timestamp.day == now.day;
      } else if (_selectedRange == 'This Week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startZero = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return order.timestamp.isAfter(startZero) || order.timestamp.isAtSameMomentAs(startZero);
      } else if (_selectedRange == 'This Month') {
        return order.timestamp.year == now.year && order.timestamp.month == now.month;
      }
      return true; // 'All Time'
    }).toList();

    // 2. Compute accurate metrics
    final completedOrders = filteredOrders.where((o) => o.status == VendorOrderStatus.handedOver).toList();
    final inProgressOrders = filteredOrders.where((o) =>
        o.status == VendorOrderStatus.accepted ||
        o.status == VendorOrderStatus.preparing ||
        o.status == VendorOrderStatus.ready).toList();
    final pendingOrders = filteredOrders.where((o) => o.status == VendorOrderStatus.pending).toList();
    final cancelledOrders = filteredOrders.where((o) => o.status == VendorOrderStatus.rejected).toList();

    final totalOrdersCount = filteredOrders.length;
    final completedCount = completedOrders.length;
    final totalGrossRevenue = completedOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final avgOrderValue = completedCount > 0 ? (totalGrossRevenue / completedCount) : 0.0;
    final platformCommission = totalGrossRevenue * 0.05;
    final netVendorPayout = totalGrossRevenue - platformCommission;

    // 3. Compute Real Payment Breakdown
    int onlineCount = 0;
    double onlineRev = 0.0;
    int codCount = 0;
    double codRev = 0.0;

    for (var o in completedOrders) {
      final method = o.paymentMethod.toUpperCase();
      if (method.contains('COD') || method.contains('CASH')) {
        codCount++;
        codRev += o.totalAmount;
      } else {
        onlineCount++;
        onlineRev += o.totalAmount;
      }
    }

    // 4. Compute Top Selling Items in this filtered period
    final Map<String, Map<String, dynamic>> productStats = {};
    for (var o in completedOrders) {
      for (var item in o.items) {
        if (!productStats.containsKey(item.name)) {
          productStats[item.name] = {'name': item.name, 'qty': 0, 'sales': 0.0};
        }
        productStats[item.name]!['qty'] = (productStats[item.name]!['qty'] as int) + item.quantity;
        productStats[item.name]!['sales'] = (productStats[item.name]!['sales'] as double) + (item.price * item.quantity);
      }
    }
    final topItems = productStats.values.toList()
      ..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Order Report & Analytics',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.darkText),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppTheme.primaryOrange, size: 22),
            onPressed: () {
              final reportText = StringBuffer();
              reportText.writeln('📊 NAMBA STORE - ORDER REPORT');
              reportText.writeln('📅 Period: $_selectedRange (${DateFormat('dd MMM yyyy').format(DateTime.now())})');
              reportText.writeln('--------------------------------');
              reportText.writeln('📦 Total Orders: $totalOrdersCount');
              reportText.writeln('✅ Completed Orders: $completedCount');
              reportText.writeln('⏳ In Progress: ${inProgressOrders.length}');
              reportText.writeln('❌ Cancelled/Rejected: ${cancelledOrders.length}');
              reportText.writeln('--------------------------------');
              reportText.writeln('💰 Gross Revenue: ₹${totalGrossRevenue.toStringAsFixed(2)}');
              reportText.writeln('📈 Average Order Value: ₹${avgOrderValue.toStringAsFixed(2)}');
              reportText.writeln('📉 Platform Fee (5%): -₹${platformCommission.toStringAsFixed(2)}');
              reportText.writeln('💵 Net Vendor Earnings: ₹${netVendorPayout.toStringAsFixed(2)}');
              reportText.writeln('--------------------------------');
              reportText.writeln('💳 Online Payments: $onlineCount (₹${onlineRev.toStringAsFixed(0)})');
              reportText.writeln('💵 Cash on Delivery: $codCount (₹${codRev.toStringAsFixed(0)})');

              Clipboard.setData(ClipboardData(text: reportText.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📋 Order Report summary copied to clipboard! Ready to share or export.'),
                  backgroundColor: Color(0xFF059669),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Filter Range Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Today', 'This Week', 'This Month', 'All Time'].map((range) {
                  final isSelected = _selectedRange == range;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        range,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.darkText,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryOrange,
                      backgroundColor: Colors.white,
                      elevation: isSelected ? 2 : 0,
                      side: BorderSide(color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade300),
                      onSelected: (val) {
                        if (val) setState(() => _selectedRange = range);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // 2. 4-Grid Key Analytics Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _buildStatCard(
                  'Total Orders',
                  '$totalOrdersCount',
                  Icons.receipt_long_rounded,
                  const Color(0xFF4F46E5),
                  '${completedCount} fulfilled',
                ),
                _buildStatCard(
                  'Completed',
                  '$completedCount',
                  Icons.check_circle_rounded,
                  const Color(0xFF059669),
                  totalOrdersCount > 0 ? '${((completedCount / totalOrdersCount) * 100).toStringAsFixed(0)}% completion' : '0%',
                ),
                _buildStatCard(
                  'Gross Sales',
                  '₹${totalGrossRevenue.toStringAsFixed(0)}',
                  Icons.currency_rupee_rounded,
                  const Color(0xFF7C3AED),
                  'Before 5% fee',
                ),
                _buildStatCard(
                  'Avg Order (AOV)',
                  '₹${avgOrderValue.toStringAsFixed(0)}',
                  Icons.trending_up_rounded,
                  const Color(0xFFD97706),
                  'Per delivered order',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. Net Payout & Commission Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Vendor Earnings',
                        style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text('95% Payout', style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${netVendorPayout.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gross Order Total: ₹${totalGrossRevenue.toStringAsFixed(0)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                      Text('Platform Fee: -₹${platformCommission.toStringAsFixed(0)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Order Pipeline Breakdown
            Text('Order Pipeline Status', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.darkText)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                children: [
                  _buildReportRow('Completed & Handed Over', '$completedCount', icon: Icons.check_circle_rounded, color: const Color(0xFF059669)),
                  _buildReportRow('In Preparation / Ready', '${inProgressOrders.length}', icon: Icons.outdoor_grill_rounded, color: AppTheme.primaryOrange),
                  _buildReportRow('Pending Acceptance', '${pendingOrders.length}', icon: Icons.hourglass_top_rounded, color: const Color(0xFFD97706)),
                  _buildReportRow('Cancelled / Declined', '${cancelledOrders.length}', icon: Icons.cancel_rounded, color: const Color(0xFFDC2626)),
                  const Divider(height: 24),
                  _buildReportRow('Total Orders Processed', '$totalOrdersCount', bold: true, color: AppTheme.darkText),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Payment Methods Breakdown
            Text('Payment Breakdown', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.darkText)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                children: [
                  _buildReportRow('Online (UPI / Card / NetBanking)', '$onlineCount orders  (₹${onlineRev.toStringAsFixed(0)})', icon: Icons.qr_code_2_rounded, color: const Color(0xFF4F46E5)),
                  _buildReportRow('Cash on Delivery (COD)', '$codCount orders  (₹${codRev.toStringAsFixed(0)})', icon: Icons.payments_rounded, color: const Color(0xFF059669)),
                  const Divider(height: 24),
                  _buildReportRow('Total Collected Revenue', '₹${totalGrossRevenue.toStringAsFixed(0)}', bold: true, color: AppTheme.darkText),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. Top Selling Products Table
            if (topItems.isNotEmpty) ...[
              Text('Top Selling Products ($_selectedRange)', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.darkText)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topItems.take(5).length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = topItems[idx];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.1),
                        child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryOrange, fontSize: 12)),
                      ),
                      title: Text(item['name'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text('${item['qty']} units sold', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      trailing: Text(
                        '₹${(item['sales'] as double).toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.darkText),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, String subtext) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Flexible(
                child: Text(
                  subtext,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: color),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value, {bool bold = false, Color? color, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color ?? Colors.grey.shade500),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: bold ? AppTheme.darkText : Colors.grey.shade600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: color ?? AppTheme.darkText,
            ),
          ),
        ],
      ),
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
  String _selectedCategoryTab = 'All';

  final List<String> _categoryTabs = [
    'All',
    '🎨 Pure Themes',
    '🍽️ Food & Dine',
    '🛒 Grocery',
    '💊 Medical',
    '🎂 Bakery',
    '🥦 Fruits & Veg',
    '🥩 Meat & Fish',
  ];

  final List<Map<String, dynamic>> _posterTemplates = [
    // 0. PURE COLOR THEMES
    {
      'category': '🎨 Pure Themes',
      'title': '⚡ FLASH SALE - Mega Super Discount',
      'subtitle': 'Hurry! Limited hours only. Order now on Namba app!',
      'offerTag': '🔥 FLAT 50% OFF',
      'imageUrl': '',
      'theme': 'Spicy Orange',
      'colors': [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFBBF24)],
      'accent': Colors.white,
      'mode': 'gradient',
      'ctaText': 'ORDER NOW',
      'fontFamily': 'Outfit',
      'fontSize': 20.0,
      'alignment': 'left',
    },
    {
      'category': '🎨 Pure Themes',
      'title': '👑 VIP Exclusive Weekend Special Deal',
      'subtitle': 'Special discount for all loyal store customers today!',
      'offerTag': '🎁 BUY 1 GET 1 FREE',
      'imageUrl': '',
      'theme': 'Royal Violet',
      'colors': [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFEC4899)],
      'accent': Color(0xFFFDE047),
      'mode': 'gradient',
      'ctaText': 'GRAB DEAL',
      'fontFamily': 'Poppins',
      'fontSize': 20.0,
      'alignment': 'left',
    },
    {
      'category': '🎨 Pure Themes',
      'title': '🌾 Monthly Super Saver Wholesale Combo',
      'subtitle': 'Save big on total bill amount. Wholesale prices delivered!',
      'offerTag': '🏷️ SAVE UP TO ₹250',
      'imageUrl': '',
      'theme': 'Fresh Emerald',
      'colors': [Color(0xFF047857), Color(0xFF059669), Color(0xFF34D399)],
      'accent': Color(0xFFFEF08A),
      'mode': 'gradient',
      'ctaText': 'SHOP NOW',
      'fontFamily': 'Montserrat',
      'fontSize': 20.0,
      'alignment': 'left',
    },
    {
      'category': '🎨 Pure Themes',
      'title': '🚚 FREE Fast Express Doorstep Delivery',
      'subtitle': 'Zero delivery charges! Fresh & hot items straight to your home.',
      'offerTag': '⚡ ZERO DELIVERY FEE',
      'imageUrl': '',
      'theme': 'Ocean Cyan',
      'colors': [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF38BDF8)],
      'accent': Colors.white,
      'mode': 'gradient',
      'ctaText': 'ORDER NOW',
      'fontFamily': 'Outfit',
      'fontSize': 20.0,
      'alignment': 'left',
    },
    {
      'category': '🎨 Pure Themes',
      'title': '🔥 Super Sunday Mega Dhamaka Sale',
      'subtitle': 'Extra cashback & discounts on every single order today!',
      'offerTag': '💥 MEGA DHAMAKA',
      'imageUrl': '',
      'theme': 'Ruby Sale',
      'colors': [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFF87171)],
      'accent': Color(0xFFFEF9C3),
      'mode': 'gradient',
      'ctaText': 'GET OFFER',
      'fontFamily': 'Montserrat',
      'fontSize': 20.0,
      'alignment': 'left',
    },
    {
      'category': '🎨 Pure Themes',
      'title': '✨ Festival Celebration Special Box Offer',
      'subtitle': 'Exclusive festive packages & gifts for your loved ones!',
      'offerTag': '⭐ FESTIVAL SPECIAL',
      'imageUrl': '',
      'theme': 'Golden Sun',
      'colors': [Color(0xFF854D0E), Color(0xFFCA8A04), Color(0xFFFACC15)],
      'accent': Color(0xFF1E1B4B),
      'mode': 'gradient',
      'ctaText': 'EXPLORE MENU',
      'fontFamily': 'Poppins',
      'fontSize': 20.0,
      'alignment': 'left',
    },

    // 1. RESTAURANT & FOOD
    {
      'category': '🍽️ Food & Dine',
      'title': 'Weekend Biryani & Meals Feast',
      'subtitle': 'Piping hot authentic biryani with raita & sweet!',
      'offerTag': '🔥 50% OFF',
      'imageUrl': 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800',
      'theme': 'Spicy Orange',
      'colors': [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFBBF24)],
      'accent': Colors.white,
      'mode': 'photo',
    },
    {
      'category': '🍽️ Food & Dine',
      'title': 'Buy 1 Get 1 FREE Pizza & Burger Fest',
      'subtitle': 'Order any medium pizza or burger & get one absolutely FREE!',
      'offerTag': '🎁 BUY 1 GET 1 FREE',
      'imageUrl': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800',
      'theme': 'Ruby Sale',
      'colors': [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFF87171)],
      'accent': Color(0xFFFEF9C3),
      'mode': 'photo',
    },
    {
      'category': '🍽️ Food & Dine',
      'title': 'Crispy Ghee Roast Dosa & Tiffin Combo',
      'subtitle': 'Hot crispy dosa served with 3 chutneys & piping sambar!',
      'offerTag': '⚡ FLAT ₹50 OFF',
      'imageUrl': 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=800',
      'theme': 'Spicy Orange',
      'colors': [Color(0xFFC2410C), Color(0xFFEA580C), Color(0xFFF59E0B)],
      'accent': Colors.white,
      'mode': 'photo',
    },
    {
      'category': '🍽️ Food & Dine',
      'title': 'Grand Family Dinner Feast Combo',
      'subtitle': 'Starters, Main Course, Breads & Desserts for whole family!',
      'offerTag': '🏷️ FAMILY PACK ₹499',
      'imageUrl': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
      'theme': 'Royal Violet',
      'colors': [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFEC4899)],
      'accent': Color(0xFFFDE047),
      'mode': 'gradient',
    },

    // 2. GROCERY & SUPERMARKET
    {
      'category': '🛒 Grocery',
      'title': 'Monthly Ration Mega Saver Combo',
      'subtitle': 'Atta, Rice, Dal, Cooking Oil & Spices at Wholesale Price!',
      'offerTag': '🌾 WHOLESALE RATION',
      'imageUrl': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800',
      'theme': 'Fresh Emerald',
      'colors': [Color(0xFF065F46), Color(0xFF059669), Color(0xFF34D399)],
      'accent': Colors.white,
      'mode': 'photo',
    },
    {
      'category': '🛒 Grocery',
      'title': 'Supermarket Super Saver Sunday',
      'subtitle': 'Flat ₹150 OFF on cart orders above ₹999. Fast delivery!',
      'offerTag': '⚡ FLAT ₹150 OFF',
      'imageUrl': 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800',
      'theme': 'Royal Violet',
      'colors': [Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF818CF8)],
      'accent': Color(0xFFFEF08A),
      'mode': 'photo',
    },
    {
      'category': '🛒 Grocery',
      'title': 'Free Doorstep Delivery on Daily Grocery',
      'subtitle': 'No minimum order value! 30-minute express doorstep delivery!',
      'offerTag': '🚚 FREE DELIVERY',
      'imageUrl': 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=800',
      'theme': 'Fresh Emerald',
      'colors': [Color(0xFF047857), Color(0xFF10B981), Color(0xFF6EE7B7)],
      'accent': Colors.white,
      'mode': 'gradient',
    },

    // 3. MEDICAL & PHARMACY
    {
      'category': '💊 Medical',
      'title': 'Flat 20% OFF on All Medicines',
      'subtitle': '100% Genuine prescription drugs & daily wellness products!',
      'offerTag': '💊 20% OFF MEDICINES',
      'imageUrl': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800',
      'theme': 'Ocean Cyan',
      'colors': [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF38BDF8)],
      'accent': Colors.white,
      'mode': 'photo',
    },
    {
      'category': '💊 Medical',
      'title': 'First Aid & Family Wellness Kit',
      'subtitle': 'Immunity boosters, vitamins, BP monitors & health drinks!',
      'offerTag': '✨ HEALTH SPECIAL',
      'imageUrl': 'https://images.unsplash.com/photo-1583421171928-847bbad1ec9b?w=800',
      'theme': 'Fresh Emerald',
      'colors': [Color(0xFF065F46), Color(0xFF0D9488), Color(0xFF2DD4BF)],
      'accent': Color(0xFFFEF9C3),
      'mode': 'photo',
    },
    {
      'category': '💊 Medical',
      'title': 'Emergency Medicine 20-Min Delivery',
      'subtitle': 'Upload doctor prescription & get medicines delivered quickly!',
      'offerTag': '⚡ EMERGENCY DISPATCH',
      'imageUrl': 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800',
      'theme': 'Ruby Sale',
      'colors': [Color(0xFF881337), Color(0xFFBE123C), Color(0xFFFB7185)],
      'accent': Colors.white,
      'mode': 'gradient',
    },

    // 4. BAKERY & SWEETS
    {
      'category': '🎂 Bakery',
      'title': 'Oven Fresh Birthday Cakes & Pastries',
      'subtitle': 'Custom customized celebration cakes delivered with candles!',
      'offerTag': '🎂 30% OFF CAKES',
      'imageUrl': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=800',
      'theme': 'Sunset Rose',
      'colors': [Color(0xFF831843), Color(0xFFBE185D), Color(0xFFF472B6)],
      'accent': Color(0xFFFDE047),
      'mode': 'photo',
    },
    {
      'category': '🎂 Bakery',
      'title': 'Hot Tea Time Puffs, Samosas & Buns',
      'subtitle': 'Evening fresh bakes combo with free spicy mint chutney!',
      'offerTag': '🏷️ TEA COMBO ₹99',
      'imageUrl': 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=800',
      'theme': 'Spicy Orange',
      'colors': [Color(0xFF9A3412), Color(0xFFC2410C), Color(0xFFFB923C)],
      'accent': Colors.white,
      'mode': 'photo',
    },
    {
      'category': '🎂 Bakery',
      'title': 'Authentic Pure Ghee Festive Sweets',
      'subtitle': 'Laddu, Gulab Jamun, Mysore Pak & Mixture special box!',
      'offerTag': '✨ FESTIVE SWEETS',
      'imageUrl': 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=800',
      'theme': 'Golden Sun',
      'colors': [Color(0xFF854D0E), Color(0xFFCA8A04), Color(0xFFFACC15)],
      'accent': Color(0xFF1E1B4B),
      'mode': 'photo',
    },

    // 5. FRUITS & VEGETABLES
    {
      'category': '🥦 Fruits & Veg',
      'title': '100% Farm Fresh Morning Veggies',
      'subtitle': 'Directly from local farmers, handpicked, fresh & cleaned!',
      'offerTag': '🌿 100% FARM FRESH',
      'imageUrl': 'https://images.unsplash.com/photo-1610348725531-843dff563e2c?w=800',
      'theme': 'Fresh Emerald',
      'colors': [Color(0xFF14532D), Color(0xFF16A34A), Color(0xFF4ADE80)],
      'accent': Colors.white,
      'mode': 'photo',
    },
    {
      'category': '🥦 Fruits & Veg',
      'title': 'Exotic Juicy Fresh Fruits Combo',
      'subtitle': 'Apples, Pomegranates, Mangoes, Bananas & Seasonal Fruits!',
      'offerTag': '🍎 FRUIT BOX ₹199',
      'imageUrl': 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=800',
      'theme': 'Spicy Orange',
      'colors': [Color(0xFF7C2D12), Color(0xFFEA580C), Color(0xFFFDBA74)],
      'accent': Colors.white,
      'mode': 'photo',
    },

    // 6. MEAT & FISH
    {
      'category': '🥩 Meat & Fish',
      'title': 'Tender Fresh Country Chicken & Mutton',
      'subtitle': '100% Halal, hygienic cut & vacuum packed delivery!',
      'offerTag': '🥩 FRESH CUT SPECIAL',
      'imageUrl': 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=800',
      'theme': 'Ruby Sale',
      'colors': [Color(0xFF7F1D1D), Color(0xFFB91C1C), Color(0xFFEF4444)],
      'accent': Color(0xFFFEF9C3),
      'mode': 'photo',
    },
    {
      'category': '🥩 Meat & Fish',
      'title': 'Daily Ocean Fresh Fish & Jumbo Prawns',
      'subtitle': 'Cleaned, descaled & ready-to-cook sea fresh catch!',
      'offerTag': '🐟 OCEAN FRESH',
      'imageUrl': 'https://images.unsplash.com/photo-1534939561126-855b8675edd7?w=800',
      'theme': 'Ocean Cyan',
      'colors': [Color(0xFF0C4A6E), Color(0xFF0284C7), Color(0xFF38BDF8)],
      'accent': Colors.white,
      'mode': 'photo',
    },
  ];

  final Map<String, List<Map<String, String>>> _stockPhotoLibrary = {
    '🍽️ Food & Dine': [
      {'name': 'Biryani Feast', 'url': 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800'},
      {'name': 'Pizza & Burger', 'url': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800'},
      {'name': 'South Tiffin', 'url': 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=800'},
      {'name': 'Food Table', 'url': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800'},
    ],
    '🛒 Grocery': [
      {'name': 'Supermarket Basket', 'url': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800'},
      {'name': 'Aisle Goods', 'url': 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800'},
      {'name': 'Daily Provisions', 'url': 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=800'},
      {'name': 'Grains & Pulses', 'url': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=800'},
    ],
    '💊 Medical': [
      {'name': 'Pills & Medicines', 'url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800'},
      {'name': 'First Aid & Health', 'url': 'https://images.unsplash.com/photo-1583421171928-847bbad1ec9b?w=800'},
      {'name': 'Pharmacy Counter', 'url': 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800'},
      {'name': 'Stethoscope & Care', 'url': 'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=800'},
    ],
    '🎂 Bakery': [
      {'name': 'Celebration Cake', 'url': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=800'},
      {'name': 'Fresh Pastry & Croissant', 'url': 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=800'},
      {'name': 'Indian Sweets', 'url': 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=800'},
      {'name': 'Cupcakes & Treats', 'url': 'https://images.unsplash.com/photo-1587314168485-3236d6710814?w=800'},
    ],
    '🥦 Fruits & Veg': [
      {'name': 'Fresh Veggies', 'url': 'https://images.unsplash.com/photo-1610348725531-843dff563e2c?w=800'},
      {'name': 'Juicy Fruits Tray', 'url': 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=800'},
      {'name': 'Green Harvest', 'url': 'https://images.unsplash.com/photo-1566385101042-1a0aa0c1268c?w=800'},
      {'name': 'Citrus & Apples', 'url': 'https://images.unsplash.com/photo-1519996529931-28324d5a630e?w=800'},
    ],
    '🥩 Meat & Fish': [
      {'name': 'Fresh Cut Meat', 'url': 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=800'},
      {'name': 'Ocean Catch Fish', 'url': 'https://images.unsplash.com/photo-1534939561126-855b8675edd7?w=800'},
      {'name': 'Raw Chicken Feast', 'url': 'https://images.unsplash.com/photo-1587593810167-a84920ea0781?w=800'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchAds();
  }

  Future<void> _fetchAds() async {
    final provider = Provider.of<VendorOrderProvider>(context, listen: false);
    final vendor = provider.profile;
    if (vendor == null || vendor.id.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (vendor.phone.isNotEmpty) {
      try {
        await provider.fetchProfile(vendor.phone);
      } catch (_) {}
    }
    final freshVendor = provider.profile ?? vendor;
    final apiService = VendorApiService();
    final data = await apiService.getVendorAds(freshVendor.id);

    if (mounted) {
      if (data != null) {
        setState(() {
          _canRunAds = data['canRunAds'] == true || freshVendor.canRunAds == true;
          _ads = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _canRunAds = freshVendor.canRunAds == true;
          _isLoading = false;
        });
      }
    }
  }

  TextStyle _getPosterTextStyle({
    required String fontFamily,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) {
    switch (fontFamily) {
      case 'Poppins':
        return GoogleFonts.poppins(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing, height: height);
      case 'Montserrat':
        return GoogleFonts.montserrat(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing, height: height);
      case 'Inter':
        return GoogleFonts.inter(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing, height: height);
      case 'Playfair':
        return GoogleFonts.playfairDisplay(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing, height: height);
      case 'Outfit':
      default:
        return GoogleFonts.outfit(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing, height: height);
    }
  }

  List<Color> _parseColors(dynamic gradient, {List<Color>? fallback}) {
    if (gradient is List && gradient.isNotEmpty) {
      try {
        return gradient.map((c) {
          if (c is Color) return c;
          if (c is String) {
            final hex = c.replaceAll('#', '');
            return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
          }
          return const Color(0xFF4F46E5);
        }).toList();
      } catch (_) {}
    }
    return fallback ?? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)];
  }

  Future<void> _launchTemplateAd(Map<String, dynamic> template) async {
    final provider = Provider.of<VendorOrderProvider>(context, listen: false);
    final vendor = provider.profile;
    final colors = (template['colors'] as List<Color>).map((c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}').toList();

    final adData = {
      'vendorId': vendor?.id ?? '',
      'title': template['title'],
      'subtitle': template['subtitle'],
      'imageUrl': template['imageUrl'],
      'offerTag': template['offerTag'],
      'theme': template['theme'],
      'gradient': colors,
      'ctaText': template['ctaText'] ?? 'ORDER NOW',
      'fontFamily': template['fontFamily'] ?? 'Outfit',
      'fontSize': (template['fontSize'] as num?)?.toDouble() ?? 20.0,
      'alignment': template['alignment'] ?? 'left',
    };

    final apiService = VendorApiService();
    final res = await apiService.createAd(adData);
    if (res != null) {
      _fetchAds();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 "${template['title']}" poster banner launched live on Customer App!'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalClicks = _ads.fold(0, (sum, a) => sum + ((a['clickCount'] ?? 0) as num).toInt());
    final vendor = Provider.of<VendorOrderProvider>(context, listen: false).profile;
    final storeName = vendor?.storeName ?? 'Your Store';

    final filteredTemplates = _selectedCategoryTab == 'All'
        ? _posterTemplates
        : _posterTemplates.where((t) => (t['category'] as String?) == _selectedCategoryTab).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1E293B)), onPressed: () => Navigator.pop(context)),
        title: Text('Ad Campaign Studio', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: const Color(0xFF1E293B))),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4F46E5)),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchAds();
            },
          ),
        ],
      ),
      floatingActionButton: _canRunAds
          ? FloatingActionButton.extended(
              onPressed: () => _showAddBannerSheet(context),
              backgroundColor: const Color(0xFF4F46E5),
              elevation: 4,
              icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
              label: Text('Create Poster', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
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
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4338CA).withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
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
                                Text('$totalClicks Clicks', style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontSize: 20, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 1. SHOP CATEGORY TABS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706), size: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ready Poster Templates',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        Text(
                          '1-Tap Launch',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Horizontal Category Filter Pills
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _categoryTabs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, idx) {
                          final tab = _categoryTabs[idx];
                          final isSel = _selectedCategoryTab == tab;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategoryTab = tab),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF4F46E5) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: isSel
                                    ? [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Text(
                                tab,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                  color: isSel ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Horizontal Scroll of Poster Cards
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredTemplates.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (ctx, idx) => _buildTemplateCard(filteredTemplates[idx], storeName),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 2. ACTIVE LIVE POSTER BANNERS
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFF4F46E5), size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text('Your Active Customer Posters', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                          child: Text('${_ads.length}', style: GoogleFonts.outfit(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w800, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (_ads.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                              child: const Icon(Iconsax.gallery_copy, size: 36, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(height: 14),
                            Text('No Active Ad Posters Yet', style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                              'Choose any ready-made shop template above or tap "+ Create Poster" to attract thousands of customers!',
                              style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 12.5, height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_ads.length, (i) => _adCard(_ads[i], i, storeName)),
                  ],
                ),
              ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template, String storeName) {
    final colors = template['colors'] as List<Color>;
    final offerTag = template['offerTag'] as String;
    final title = template['title'] as String;
    final subtitle = template['subtitle'] as String;
    final img = template['imageUrl'] as String;
    final accent = template['accent'] as Color? ?? Colors.white;
    final isGradientMode = template['mode'] == 'gradient';
    final fontFamily = template['fontFamily'] as String? ?? 'Outfit';
    final fontSize = (template['fontSize'] as num?)?.toDouble() ?? 15.0;
    final ctaText = template['ctaText'] as String? ?? '1-Tap Launch';

    return Container(
      width: 295,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Background Image (if photo mode)
            if (!isGradientMode && img.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  img,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: colors.first),
                ),
              ),

            // Gradient Overlay & Decorative Watermarks
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isGradientMode
                        ? [colors.first, colors.length > 1 ? colors[1] : colors.first]
                        : [
                            colors.first.withValues(alpha: 0.35),
                            colors.length > 1 ? colors[1].withValues(alpha: 0.78) : colors.first.withValues(alpha: 0.78),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: isGradientMode
                    ? Stack(
                        children: [
                          Positioned(
                            top: -25,
                            right: -20,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white.withValues(alpha: 0.14),
                              size: 48,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, color: Colors.white, size: 11),
                            const SizedBox(width: 4),
                            Text(
                              storeName,
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          offerTag,
                          style: GoogleFonts.outfit(color: accent, fontWeight: FontWeight.w900, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _getPosterTextStyle(
                      fontFamily: fontFamily,
                      fontSize: fontSize.clamp(13.0, 16.0),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _getPosterTextStyle(
                      fontFamily: fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _launchTemplateAd(template),
                          icon: const Icon(Icons.rocket_launch_rounded, size: 13, color: Color(0xFF1E1B4B)),
                          label: Text(ctaText, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1E1B4B),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showAddBannerSheet(context, initialTemplate: template),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                              const SizedBox(width: 4),
                              Text('Edit', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
              'In-App Customer Ads feature is not enabled for your store yet. Please contact Namba Admin Support or wait for Admin approval to grant Ad permissions.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchAds();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Check Access Status', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adCard(Map<String, dynamic> ad, int index, String storeName) {
    final adId = (ad['_id'] ?? ad['id'] ?? '').toString();
    final title = (ad['title'] ?? 'Featured Offer').toString();
    final subtitle = (ad['subtitle'] ?? '').toString();
    final offerTag = (ad['offerTag'] ?? '🔥 SPECIAL OFFER').toString();
    final img = (ad['imageUrl'] ?? '').toString();
    final clicks = (ad['clickCount'] ?? 0).toString();
    final isActive = (ad['status'] ?? 'Active') == 'Active';
    final colors = _parseColors(ad['gradient']);
    final ctaText = (ad['ctaText'] ?? 'ORDER NOW').toString();
    final fontFamily = (ad['fontFamily'] ?? 'Outfit').toString();
    final fontSize = (ad['fontSize'] as num?)?.toDouble() ?? 19.0;
    final alignmentStr = (ad['alignment'] ?? 'left').toString();
    final alignment = alignmentStr == 'center' ? TextAlign.center : (alignmentStr == 'right' ? TextAlign.right : TextAlign.left);
    final crossAlign = alignmentStr == 'center' ? CrossAxisAlignment.center : (alignmentStr == 'right' ? CrossAxisAlignment.end : CrossAxisAlignment.start);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LIVE POSTER VISUAL
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                children: [
                  // Poster Background Image if any
                  if (img.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        img,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: colors.first),
                      ),
                    ),

                  // Gradient Overlay
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isActive
                            ? (img.isNotEmpty
                                ? [
                                    colors.first.withValues(alpha: 0.35),
                                    colors.length > 1 ? colors[1].withValues(alpha: 0.78) : colors.first.withValues(alpha: 0.78),
                                  ]
                                : [
                                    colors.first,
                                    colors.length > 1 ? colors[1] : colors.first,
                                  ])
                            : [Colors.grey.shade600, Colors.grey.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: crossAlign,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    storeName,
                                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                offerTag,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFDE047),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          textAlign: alignment,
                          style: _getPosterTextStyle(
                            fontFamily: fontFamily,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            textAlign: alignment,
                            style: _getPosterTextStyle(
                              fontFamily: fontFamily,
                              fontSize: (fontSize * 0.65).clamp(11.0, 14.0),
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    ctaText,
                                    style: _getPosterTextStyle(
                                      fontFamily: fontFamily,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: colors.first,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, color: colors.first, size: 13),
                                ],
                              ),
                            ),
                            Text(
                              isActive ? '● Live on Customer App' : '○ Campaign Paused',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: isActive ? const Color(0xFFBBF7D0) : Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // POSTER CONTROLS & STATS BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.touch_app_rounded, color: Color(0xFF4F46E5), size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL CLICKS', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
                    Text('$clicks Customer Clicks', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.5, color: const Color(0xFF1E293B))),
                  ],
                ),
                const Spacer(),
                Switch.adaptive(
                  value: isActive,
                  onChanged: (v) async {
                    setState(() => _ads[index]['status'] = v ? 'Active' : 'Paused');
                    if (adId.isNotEmpty) {
                      final apiService = VendorApiService();
                      await apiService.updateAd(adId, {'status': v ? 'Active' : 'Paused'});
                    }
                  },
                  activeColor: const Color(0xFF4F46E5),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  tooltip: 'Delete Ad',
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
  void _showAddBannerSheet(BuildContext context, {Map<String, dynamic>? initialTemplate}) {
    final titleCtrl = TextEditingController(text: initialTemplate != null ? initialTemplate['title'] : 'Special Mega Discount Feast');
    final subtitleCtrl = TextEditingController(text: initialTemplate != null ? initialTemplate['subtitle'] : 'Order delicious items directly to your doorstep!');
    final imageCtrl = TextEditingController(text: initialTemplate != null ? (initialTemplate['imageUrl'] ?? '') : '');
    final customCtaCtrl = TextEditingController();
    final customOfferTagCtrl = TextEditingController();

    int selectedThemeIndex = 0;
    String selectedOfferTag = initialTemplate != null ? (initialTemplate['offerTag'] ?? '🔥 50% OFF') : '🔥 50% OFF';
    String posterCreationMode = initialTemplate != null && initialTemplate['mode'] == 'gradient' ? 'gradient' : 'photo';
    String selectedStockCategory = '🍽️ Food & Dine';
    bool isUploadingPhoto = false;

    double selectedFontSize = (initialTemplate != null && initialTemplate['fontSize'] != null)
        ? (initialTemplate['fontSize'] as num).toDouble()
        : 20.0;
    String selectedFontFamily = (initialTemplate != null && initialTemplate['fontFamily'] != null)
        ? (initialTemplate['fontFamily'] as String)
        : 'Outfit';
    TextAlign selectedAlignment = (initialTemplate != null && initialTemplate['alignment'] == 'center')
        ? TextAlign.center
        : ((initialTemplate != null && initialTemplate['alignment'] == 'right') ? TextAlign.right : TextAlign.left);
    String selectedCtaText = (initialTemplate != null && initialTemplate['ctaText'] != null)
        ? (initialTemplate['ctaText'] as String)
        : 'ORDER NOW';

    final List<Map<String, dynamic>> posterThemes = [
      {
        'name': '🚫 None (Natural Photo / அசல் படம்)',
        'colors': [const Color(0xFF0F172A), const Color(0xFF1E293B)],
        'accent': const Color(0xFFFDE047),
        'isNone': true,
      },
      {
        'name': 'Royal Violet',
        'colors': [const Color(0xFF4F46E5), const Color(0xFF7C3AED), const Color(0xFFEC4899)],
        'accent': const Color(0xFFFDE047),
      },
      {
        'name': 'Spicy Orange',
        'colors': [const Color(0xFFEA580C), const Color(0xFFF97316), const Color(0xFFFBBF24)],
        'accent': Colors.white,
      },
      {
        'name': 'Fresh Emerald',
        'colors': [const Color(0xFF047857), const Color(0xFF10B981), const Color(0xFF34D399)],
        'accent': const Color(0xFFFEF08A),
      },
      {
        'name': 'Ocean Cyan',
        'colors': [const Color(0xFF0369A1), const Color(0xFF0284C7), const Color(0xFF38BDF8)],
        'accent': Colors.white,
      },
      {
        'name': 'Ruby Sale',
        'colors': [const Color(0xFF991B1B), const Color(0xFFDC2626), const Color(0xFFF87171)],
        'accent': const Color(0xFFFEF9C3),
      },
      {
        'name': 'Sunset Rose',
        'colors': [const Color(0xFF831843), const Color(0xFFBE185D), const Color(0xFFF472B6)],
        'accent': const Color(0xFFFDE047),
      },
      {
        'name': 'Golden Sun',
        'colors': [const Color(0xFF854D0E), const Color(0xFFCA8A04), const Color(0xFFFACC15)],
        'accent': const Color(0xFF1E1B4B),
      },
      {
        'name': 'Midnight Neon',
        'colors': [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF3B82F6)],
        'accent': const Color(0xFF38BDF8),
      },
    ];

    if (initialTemplate != null) {
      final tTheme = initialTemplate['theme'] as String?;
      if (tTheme != null) {
        final fIdx = posterThemes.indexWhere((t) => t['name'] == tTheme);
        if (fIdx != -1) selectedThemeIndex = fIdx;
      }
      final tCat = initialTemplate['category'] as String?;
      if (tCat != null && _stockPhotoLibrary.containsKey(tCat)) {
        selectedStockCategory = tCat;
      }
    } else {
      if (posterCreationMode == 'photo') {
        selectedThemeIndex = 0;
      } else {
        selectedThemeIndex = 1;
      }
    }

    final Map<String, List<String>> categoryOfferTags = {
      '🍽️ Food & Dine': [
        '🔥 50% OFF',
        '🎁 BUY 1 GET 1 FREE',
        '⚡ FLAT ₹100 OFF',
        '🏷️ MEAL COMBO ₹149',
        '🚚 FREE DELIVERY',
        '⭐ TODAY\'S SPECIAL',
      ],
      '🛒 Grocery': [
        '🌾 WHOLESALE RATION',
        '⚡ FLAT ₹150 OFF',
        '🚚 FREE DELIVERY',
        '🏷️ MONTHLY SAVER',
        '✨ MEGA DISCOUNT',
        '🌿 100% CLEAN RICE',
      ],
      '💊 Medical': [
        '💊 20% OFF MEDICINES',
        '⚡ EMERGENCY DISPATCH',
        '✨ HEALTH SPECIAL',
        '🚚 FREE MEDICINE DELIVERY',
        '⭐ 100% GENUINE',
      ],
      '🎂 Bakery': [
        '🎂 30% OFF CAKES',
        '🎁 BUY 1 GET 1 PASTRY',
        '🏷️ TEA COMBO ₹99',
        '✨ FESTIVE SWEETS',
        '⚡ FLASH DEAL',
      ],
      '🥦 Fruits & Veg': [
        '🌿 100% FARM FRESH',
        '🍎 FRUIT BOX ₹199',
        '🥬 MORNING HARVEST',
        '⚡ FLAT 25% OFF',
      ],
      '🥩 Meat & Fish': [
        '🥩 FRESH CUT SPECIAL',
        '🐟 OCEAN FRESH',
        '🍗 SUNDAY COMBO',
        '⭐ 100% HALAL',
      ],
    };

    final List<String> headlineSuggestions = [
      '⚡ Flash Sale - Mega 50% Discount',
      '👑 Weekend Special Discount Deal',
      '🌾 Monthly Super Saver Ration Combo',
      '🚚 FREE Doorstep Express Delivery',
      '🔥 Super Sunday Mega Dhamaka Sale',
      '✨ Festive Celebration Special Box',
    ];

    final List<String> ctaPresets = [
      'ORDER NOW',
      'SHOP NOW',
      'GRAB DEAL',
      'EXPLORE MENU',
      'BUY NOW',
      'GET OFFER',
    ];

    final List<Map<String, dynamic>> fontStyles = [
      {'id': 'Outfit', 'name': 'Modern', 'desc': 'Bold & Stylish'},
      {'id': 'Poppins', 'name': 'Clean', 'desc': 'Minimal & Neat'},
      {'id': 'Montserrat', 'name': 'Impact', 'desc': 'Heavy Poster'},
      {'id': 'Inter', 'name': 'Minimal', 'desc': 'Subtle Pro'},
      {'id': 'Playfair', 'name': 'Luxury', 'desc': 'Premium Classic'},
    ];

    final List<Map<String, dynamic>> fontSizes = [
      {'size': 16.0, 'label': 'S (16px)'},
      {'size': 20.0, 'label': 'M (20px)'},
      {'size': 24.0, 'label': 'L (24px)'},
      {'size': 28.0, 'label': 'XL (28px)'},
    ];

    final vendor = Provider.of<VendorOrderProvider>(context, listen: false).profile;
    final storeName = vendor?.storeName ?? 'Your Store';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            final currentTheme = posterThemes[selectedThemeIndex];
            final gradientColors = currentTheme['colors'] as List<Color>;
            final isNoneTheme = currentTheme['isNone'] == true;
            final activeOfferTags = categoryOfferTags[selectedStockCategory] ?? categoryOfferTags['🍽️ Food & Dine']!;
            final crossAlignment = selectedAlignment == TextAlign.center
                ? CrossAxisAlignment.center
                : (selectedAlignment == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start);

            return Container(
              height: MediaQuery.of(context).size.height * 0.94,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: GestureDetector(
                onTap: () => FocusScope.of(ctx).unfocus(),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.palette_rounded, color: Color(0xFF4F46E5), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ad Campaign Poster Studio',
                                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B)),
                                ),
                                Text(
                                  'Design eye-catching live poster ads for customer app',
                                  style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 14, color: Color(0xFFF1F5F9)),

                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. LIVE BANNER PREVIEW CARD (AT THE TOP)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'LIVE BANNER PREVIEW',
                                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: const Color(0xFF475569)),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '100% Live View',
                                          style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: gradientColors.first.withValues(alpha: 0.3),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Stack(
                                        children: [
                                          if (posterCreationMode == 'photo' && imageCtrl.text.trim().isNotEmpty)
                                            Positioned.fill(
                                              child: Image.network(
                                                imageCtrl.text.trim(),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(color: gradientColors.first),
                                              ),
                                            ),

                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: (posterCreationMode == 'photo' && imageCtrl.text.trim().isNotEmpty)
                                                    ? (isNoneTheme
                                                        ? [
                                                            Colors.black.withValues(alpha: 0.15),
                                                            Colors.black.withValues(alpha: 0.75),
                                                          ]
                                                        : [
                                                            gradientColors.first.withValues(alpha: 0.35),
                                                            (gradientColors.length > 1 ? gradientColors[1] : gradientColors.first).withValues(alpha: 0.78),
                                                          ])
                                                    : [
                                                        gradientColors.first,
                                                        gradientColors.length > 1 ? gradientColors[1] : gradientColors.first,
                                                      ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            child: Stack(
                                              children: [
                                                if (posterCreationMode == 'gradient' || imageCtrl.text.trim().isEmpty) ...[
                                                  Positioned(
                                                    top: -25,
                                                    right: -15,
                                                    child: Container(
                                                      width: 85,
                                                      height: 85,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.white.withValues(alpha: 0.09),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 8,
                                                    bottom: 0,
                                                    child: Icon(
                                                      Icons.stars_rounded,
                                                      color: Colors.white.withValues(alpha: 0.15),
                                                      size: 55,
                                                    ),
                                                  ),
                                                ],

                                                Column(
                                                  crossAxisAlignment: crossAlignment,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white.withValues(alpha: 0.25),
                                                            borderRadius: BorderRadius.circular(14),
                                                            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                storeName,
                                                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withValues(alpha: 0.35),
                                                            borderRadius: BorderRadius.circular(14),
                                                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                                          ),
                                                          child: Text(
                                                            selectedOfferTag,
                                                            style: GoogleFonts.outfit(
                                                              color: currentTheme['accent'] as Color,
                                                              fontWeight: FontWeight.w900,
                                                              fontSize: 10.5,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Your Ad Headline Here',
                                                      textAlign: selectedAlignment,
                                                      style: _getPosterTextStyle(
                                                        fontFamily: selectedFontFamily,
                                                        fontSize: selectedFontSize,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.white,
                                                        letterSpacing: -0.3,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      subtitleCtrl.text.isNotEmpty ? subtitleCtrl.text : 'Tap to explore menu & place order',
                                                      textAlign: selectedAlignment,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: _getPosterTextStyle(
                                                        fontFamily: selectedFontFamily,
                                                        fontSize: (selectedFontSize * 0.62).clamp(11.0, 14.5),
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.white.withValues(alpha: 0.9),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(16),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors.black.withValues(alpha: 0.15),
                                                                blurRadius: 6,
                                                                offset: const Offset(0, 2),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                selectedCtaText,
                                                                style: _getPosterTextStyle(
                                                                  fontFamily: selectedFontFamily,
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w900,
                                                                  color: gradientColors.first,
                                                                  letterSpacing: 0.4,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 5),
                                                              Icon(Icons.arrow_forward_rounded, color: gradientColors.first, size: 12),
                                                            ],
                                                          ),
                                                        ),
                                                        Text(
                                                          'Customer App Banner',
                                                          style: GoogleFonts.outfit(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. AD TEXT & HEADLINE INPUTS (DIRECTLY UNDER PREVIEW - NEVER HIDDEN BY KEYBOARD)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.edit_note_rounded, color: Color(0xFF4F46E5), size: 20),
                                          const SizedBox(width: 6),
                                          Text(
                                            'AD TEXT & HEADLINE',
                                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: const Color(0xFF1E293B)),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Type here to update live',
                                        style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF6366F1)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Headline Input Field
                                  TextField(
                                    controller: titleCtrl,
                                    onChanged: (_) => setSheetState(() {}),
                                    style: _getPosterTextStyle(
                                      fontFamily: selectedFontFamily,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E293B),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Campaign Headline / விளம்பர தலைப்பு *',
                                      labelStyle: GoogleFonts.outfit(fontSize: 12.5, color: Colors.grey.shade600),
                                      prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF4F46E5), size: 20),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Quick 1-Tap Headline Suggestions
                                  SizedBox(
                                    height: 30,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: headlineSuggestions.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                                      itemBuilder: (ctx, idx) {
                                        final sug = headlineSuggestions[idx];
                                        return GestureDetector(
                                          onTap: () {
                                            titleCtrl.text = sug;
                                            setSheetState(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEEF2FF),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFC7D2FE)),
                                            ),
                                            child: Center(
                                              child: Text(
                                                sug,
                                                style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5)),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Subtitle Input Field
                                  TextField(
                                    controller: subtitleCtrl,
                                    onChanged: (_) => setSheetState(() {}),
                                    maxLines: 2,
                                    style: _getPosterTextStyle(
                                      fontFamily: selectedFontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF334155),
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Tagline & Details / கூடுதல் விவரங்கள்',
                                      labelStyle: GoogleFonts.outfit(fontSize: 12.5, color: Colors.grey.shade600),
                                      prefixIcon: const Icon(Icons.subtitles_rounded, color: Color(0xFF4F46E5), size: 20),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 3. TYPOGRAPHY & FONT STUDIO
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.text_fields_rounded, color: Color(0xFF4F46E5), size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        'TYPOGRAPHY & STYLES',
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: const Color(0xFF1E293B)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Font Family Chips
                                  SizedBox(
                                    height: 48,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: fontStyles.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                                      itemBuilder: (ctx, idx) {
                                        final item = fontStyles[idx];
                                        final id = item['id'] as String;
                                        final isSel = selectedFontFamily == id;
                                        return GestureDetector(
                                          onTap: () => setSheetState(() => selectedFontFamily = id),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSel ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                                width: isSel ? 2 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['name'] as String,
                                                  style: _getPosterTextStyle(
                                                    fontFamily: id,
                                                    fontSize: 12.5,
                                                    fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                                                    color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                                                  ),
                                                ),
                                                Text(
                                                  item['desc'] as String,
                                                  style: GoogleFonts.outfit(fontSize: 9.5, color: isSel ? const Color(0xFF6366F1) : Colors.grey.shade500),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Headline Size & Alignment in a Row
                                  Row(
                                    children: [
                                      // Size selector
                                      Expanded(
                                        flex: 6,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'HEADLINE SIZE',
                                              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
                                            ),
                                            const SizedBox(height: 6),
                                            SizedBox(
                                              height: 36,
                                              child: ListView.separated(
                                                scrollDirection: Axis.horizontal,
                                                itemCount: fontSizes.length,
                                                separatorBuilder: (_, __) => const SizedBox(width: 6),
                                                itemBuilder: (ctx, idx) {
                                                  final fs = fontSizes[idx];
                                                  final val = fs['size'] as double;
                                                  final isSel = selectedFontSize == val;
                                                  return GestureDetector(
                                                    onTap: () => setSheetState(() => selectedFontSize = val),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFF8FAFC),
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          fs['label'] as String,
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 11,
                                                            fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                                                            color: isSel ? Colors.white : const Color(0xFF334155),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Alignment buttons
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'ALIGNMENT',
                                              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              height: 36,
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: GestureDetector(
                                                      onTap: () => setSheetState(() => selectedAlignment = TextAlign.left),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: selectedAlignment == TextAlign.left ? const Color(0xFF4F46E5) : Colors.transparent,
                                                          borderRadius: BorderRadius.circular(7),
                                                        ),
                                                        child: Icon(
                                                          Icons.format_align_left_rounded,
                                                          size: 16,
                                                          color: selectedAlignment == TextAlign.left ? Colors.white : const Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: GestureDetector(
                                                      onTap: () => setSheetState(() => selectedAlignment = TextAlign.center),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: selectedAlignment == TextAlign.center ? const Color(0xFF4F46E5) : Colors.transparent,
                                                          borderRadius: BorderRadius.circular(7),
                                                        ),
                                                        child: Icon(
                                                          Icons.format_align_center_rounded,
                                                          size: 16,
                                                          color: selectedAlignment == TextAlign.center ? Colors.white : const Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: GestureDetector(
                                                      onTap: () => setSheetState(() => selectedAlignment = TextAlign.right),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: selectedAlignment == TextAlign.right ? const Color(0xFF4F46E5) : Colors.transparent,
                                                          borderRadius: BorderRadius.circular(7),
                                                        ),
                                                        child: Icon(
                                                          Icons.format_align_right_rounded,
                                                          size: 16,
                                                          color: selectedAlignment == TextAlign.right ? Colors.white : const Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 4. POSTER CANVAS MODE & THEMES
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.brush_rounded, color: Color(0xFF4F46E5), size: 20),
                                          const SizedBox(width: 6),
                                          Text(
                                            'CANVAS MODE & THEMES',
                                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: const Color(0xFF1E293B)),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            posterCreationMode == 'photo' ? '📸 Photo Mode' : '🎨 Pure Themes',
                                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5)),
                                          ),
                                          const SizedBox(width: 4),
                                          Switch.adaptive(
                                            value: posterCreationMode == 'photo',
                                            activeColor: const Color(0xFF059669),
                                            inactiveThumbColor: const Color(0xFF4F46E5),
                                            inactiveTrackColor: const Color(0xFFC7D2FE),
                                            onChanged: (isPhoto) {
                                              setSheetState(() {
                                                posterCreationMode = isPhoto ? 'photo' : 'gradient';
                                                if (!isPhoto) {
                                                  imageCtrl.clear();
                                                  if (selectedThemeIndex == 0) selectedThemeIndex = 1;
                                                } else {
                                                  final photos = _stockPhotoLibrary[selectedStockCategory];
                                                  if (photos != null && photos.isNotEmpty) {
                                                    imageCtrl.text = photos.first['url']!;
                                                  }
                                                }
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // If photo mode: Stock Photo Picker
                                  if (posterCreationMode == 'photo') ...[
                                    SizedBox(
                                      height: 32,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _stockPhotoLibrary.keys.length,
                                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                                        itemBuilder: (ctx, idx) {
                                          final catKey = _stockPhotoLibrary.keys.elementAt(idx);
                                          final isSel = selectedStockCategory == catKey;
                                          return ChoiceChip(
                                            label: Text(catKey, style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: isSel ? FontWeight.w800 : FontWeight.w600)),
                                            selected: isSel,
                                            selectedColor: const Color(0xFFEEF2FF),
                                            backgroundColor: const Color(0xFFF8FAFC),
                                            labelStyle: TextStyle(color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF475569)),
                                            side: BorderSide(color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
                                            onSelected: (v) {
                                              if (v) {
                                                setSheetState(() {
                                                  selectedStockCategory = catKey;
                                                  final photos = _stockPhotoLibrary[catKey];
                                                  if (photos != null && photos.isNotEmpty) {
                                                    imageCtrl.text = photos.first['url']!;
                                                  }
                                                  final catTags = categoryOfferTags[catKey];
                                                  if (catTags != null && catTags.isNotEmpty) {
                                                    selectedOfferTag = catTags.first;
                                                  }
                                                });
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 80,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: (_stockPhotoLibrary[selectedStockCategory] ?? []).length + 1,
                                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                                        itemBuilder: (ctx, idx) {
                                          if (idx == (_stockPhotoLibrary[selectedStockCategory] ?? []).length) {
                                            return GestureDetector(
                                              onTap: () async {
                                                final picker = ImagePicker();
                                                final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                                if (img != null) {
                                                  setSheetState(() => isUploadingPhoto = true);
                                                  try {
                                                    final provider = Provider.of<VendorOrderProvider>(context, listen: false);
                                                    final url = await provider.uploadImage(img.path);
                                                    if (url != null && url.isNotEmpty) {
                                                      setSheetState(() {
                                                        posterCreationMode = 'photo';
                                                        imageCtrl.text = url;
                                                        isUploadingPhoto = false;
                                                      });
                                                    } else {
                                                      setSheetState(() => isUploadingPhoto = false);
                                                    }
                                                  } catch (_) {
                                                    setSheetState(() => isUploadingPhoto = false);
                                                  }
                                                }
                                              },
                                              child: Container(
                                                width: 80,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (isUploadingPhoto)
                                                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                                    else ...[
                                                      const Icon(Icons.add_a_photo_rounded, color: Color(0xFF4F46E5), size: 20),
                                                      const SizedBox(height: 4),
                                                      Text('Gallery', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5))),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            );
                                          }

                                          final photoItem = _stockPhotoLibrary[selectedStockCategory]![idx];
                                          final isSelectedPhoto = imageCtrl.text.trim() == photoItem['url'];

                                          return GestureDetector(
                                            onTap: () => setSheetState(() {
                                              posterCreationMode = 'photo';
                                              imageCtrl.text = photoItem['url']!;
                                            }),
                                            child: Container(
                                              width: 100,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: isSelectedPhoto ? const Color(0xFF4F46E5) : Colors.transparent,
                                                  width: 2.5,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Image.network(photoItem['url']!, fit: BoxFit.cover),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          begin: Alignment.topCenter,
                                                          end: Alignment.bottomCenter,
                                                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      left: 6,
                                                      right: 6,
                                                      bottom: 4,
                                                      child: Text(
                                                        photoItem['name']!,
                                                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (isSelectedPhoto)
                                                      Positioned(
                                                        top: 4,
                                                        right: 4,
                                                        child: Container(
                                                          padding: const EdgeInsets.all(2.5),
                                                          decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
                                                          child: const Icon(Icons.check, color: Colors.white, size: 9),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],

                                  // Poster Color Themes Palette
                                  Text(
                                    'COLOR THEME PALETTE',
                                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 46,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: posterThemes.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                                      itemBuilder: (ctx, idx) {
                                        final item = posterThemes[idx];
                                        final isSel = selectedThemeIndex == idx;
                                        final colors = item['colors'] as List<Color>;

                                        return GestureDetector(
                                          onTap: () => setSheetState(() => selectedThemeIndex = idx),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSel ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                                width: isSel ? 2 : 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 20,
                                                  height: 20,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(colors: colors),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  item['name'] as String,
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                                    fontSize: 12,
                                                    color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 5. OFFER TAGS & ACTION BUTTON (CTA)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.local_offer_rounded, color: Color(0xFF4F46E5), size: 20),
                                          const SizedBox(width: 6),
                                          Text(
                                            'OFFER TAGS & CTA BUTTON',
                                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: const Color(0xFF1E293B)),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        selectedStockCategory,
                                        style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Offer tags chips
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ...activeOfferTags.map((tag) {
                                        final isSel = selectedOfferTag == tag;
                                        return GestureDetector(
                                          onTap: () => setSheetState(() => selectedOfferTag = tag),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                                            decoration: BoxDecoration(
                                              color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                                width: isSel ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Text(
                                              tag,
                                              style: GoogleFonts.outfit(
                                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                                fontSize: 11.5,
                                                color: isSel ? Colors.white : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      GestureDetector(
                                        onTap: () {
                                          setSheetState(() {
                                            if (customOfferTagCtrl.text.trim().isNotEmpty) {
                                              selectedOfferTag = customOfferTagCtrl.text.trim();
                                            } else {
                                              selectedOfferTag = '🔥 SPECIAL OFFER';
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                                          decoration: BoxDecoration(
                                            color: (!activeOfferTags.contains(selectedOfferTag)) ? const Color(0xFF4F46E5) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: (!activeOfferTags.contains(selectedOfferTag)) ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          child: Text(
                                            '✏️ Custom Tag',
                                            style: GoogleFonts.outfit(
                                              fontWeight: (!activeOfferTags.contains(selectedOfferTag)) ? FontWeight.w800 : FontWeight.w600,
                                              fontSize: 11.5,
                                              color: (!activeOfferTags.contains(selectedOfferTag)) ? Colors.white : const Color(0xFF4F46E5),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!activeOfferTags.contains(selectedOfferTag)) ...[
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: customOfferTagCtrl,
                                      onChanged: (val) {
                                        if (val.trim().isNotEmpty) {
                                          setSheetState(() => selectedOfferTag = val.trim());
                                        }
                                      },
                                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
                                      decoration: InputDecoration(
                                        hintText: 'Enter custom offer tag (e.g. 🔥 40% OFF, DIWALI SPECIAL)',
                                        hintStyle: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400),
                                        prefixIcon: const Icon(Icons.local_offer_rounded, color: Color(0xFF4F46E5), size: 18),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),

                                  // CTA Buttons Presets
                                  Text(
                                    'ACTION BUTTON (CTA)',
                                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ...ctaPresets.map((cta) {
                                        final isSel = selectedCtaText == cta;
                                        return GestureDetector(
                                          onTap: () => setSheetState(() => selectedCtaText = cta),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                                            decoration: BoxDecoration(
                                              color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                                width: isSel ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Text(
                                              cta,
                                              style: GoogleFonts.outfit(
                                                fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                                                fontSize: 11,
                                                color: isSel ? Colors.white : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      GestureDetector(
                                        onTap: () {
                                          setSheetState(() {
                                            if (customCtaCtrl.text.trim().isNotEmpty) {
                                              selectedCtaText = customCtaCtrl.text.trim();
                                            } else {
                                              selectedCtaText = 'CUSTOM';
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                                          decoration: BoxDecoration(
                                            color: (!ctaPresets.contains(selectedCtaText)) ? const Color(0xFF4F46E5) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: (!ctaPresets.contains(selectedCtaText)) ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          child: Text(
                                            '✏️ Custom CTA',
                                            style: GoogleFonts.outfit(
                                              fontWeight: (!ctaPresets.contains(selectedCtaText)) ? FontWeight.w900 : FontWeight.w700,
                                              fontSize: 11,
                                              color: (!ctaPresets.contains(selectedCtaText)) ? Colors.white : const Color(0xFF4F46E5),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!ctaPresets.contains(selectedCtaText)) ...[
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: customCtaCtrl,
                                      onChanged: (val) {
                                        if (val.trim().isNotEmpty) {
                                          setSheetState(() => selectedCtaText = val.trim());
                                        }
                                      },
                                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
                                      decoration: InputDecoration(
                                        hintText: 'Enter custom button text (e.g. BOOK NOW, முன்பதிவு செய்)',
                                        hintStyle: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400),
                                        prefixIcon: const Icon(Icons.touch_app_rounded, color: Color(0xFF4F46E5), size: 18),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // BOTTOM ACTION BAR
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4)),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (titleCtrl.text.trim().isNotEmpty) {
                                Navigator.pop(ctx);

                                final adData = {
                                  'vendorId': vendor?.id ?? '',
                                  'title': titleCtrl.text.trim(),
                                  'subtitle': subtitleCtrl.text.trim(),
                                  'imageUrl': posterCreationMode == 'photo' ? imageCtrl.text.trim() : '',
                                  'offerTag': selectedOfferTag,
                                  'theme': currentTheme['name'],
                                  'gradient': gradientColors.map((c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}').toList(),
                                  'ctaText': selectedCtaText,
                                  'fontFamily': selectedFontFamily,
                                  'fontSize': selectedFontSize,
                                  'alignment': selectedAlignment == TextAlign.center ? 'center' : (selectedAlignment == TextAlign.right ? 'right' : 'left'),
                                };

                                final apiService = VendorApiService();
                                await apiService.createAd(adData);
                                _fetchAds();

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('🎉 Poster Banner published live to Customer App!'),
                                      backgroundColor: Color(0xFF059669),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                            label: Text(
                              'PUBLISH AD POSTER TO CUSTOMER APP',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.3),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
