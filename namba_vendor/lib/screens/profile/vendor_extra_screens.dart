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
    final titleCtrl = TextEditingController(text: 'Special Discount Feast');
    final subtitleCtrl = TextEditingController(text: 'Order delicious items directly to your doorstep!');
    final imageCtrl = TextEditingController();

    int selectedThemeIndex = 0;
    String selectedOfferTag = '🔥 50% OFF';
    String? localPhotoPath;
    bool isUploadingPhoto = false;

    final List<Map<String, dynamic>> posterThemes = [
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
        'name': 'Midnight Neon',
        'colors': [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF3B82F6)],
        'accent': const Color(0xFF38BDF8),
      },
      {
        'name': 'Ruby Sale',
        'colors': [const Color(0xFF991B1B), const Color(0xFFDC2626), const Color(0xFFF87171)],
        'accent': const Color(0xFFFEF9C3),
      },
    ];

    final List<String> offerTags = [
      '🔥 50% OFF',
      '⚡ FLAT ₹100 OFF',
      '🎁 BUY 1 GET 1 FREE',
      '🚚 FREE DELIVERY',
      '✨ FESTIVE SPECIAL',
      '⭐ TODAY\'S SPECIAL',
      '🏷️ MEGA COMBO',
      '⚡ FLASH DEAL',
    ];

    final vendor = Provider.of<VendorOrderProvider>(context, listen: false).profile;
    final storeName = vendor?.storeName ?? 'Your Store';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final currentTheme = posterThemes[selectedThemeIndex];
          final gradientColors = currentTheme['colors'] as List<Color>;

          return Container(
            height: MediaQuery.of(context).size.height * 0.90,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
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
                const SizedBox(height: 16),
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
                              'Customize live poster banner for Customer App',
                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
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
                const Divider(height: 16, color: Color(0xFFF1F5F9)),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. LIVE BANNER PREVIEW CARD
                        Text(
                          'LIVE BANNER PREVIEW',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: gradientColors.first.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Decorative Background Elements
                              Positioned(
                                right: -20,
                                top: -20,
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 40,
                                bottom: -30,
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              ),

                              // Content
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Store Name Badge
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
                                              const Icon(Icons.verified_rounded, color: Colors.white, size: 13),
                                              const SizedBox(width: 4),
                                              Text(
                                                storeName,
                                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Selected Offer Tag Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            selectedOfferTag,
                                            style: GoogleFonts.outfit(
                                              color: currentTheme['accent'] as Color,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Title Headline
                                    Text(
                                      titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Your Ad Headline Here',
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // Subtitle
                                    Text(
                                      subtitleCtrl.text.isNotEmpty ? subtitleCtrl.text : 'Tap to explore menu & place order',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // CTA Pill
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.15),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'ORDER NOW',
                                                style: GoogleFonts.outfit(
                                                  color: gradientColors.first,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(Icons.arrow_forward_rounded, color: gradientColors.first, size: 14),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          'Featured in Customer App',
                                          style: GoogleFonts.outfit(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 2. POSTER COLOR THEMES SELECTOR
                        Text(
                          'CHOOSE POSTER THEME',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 52,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: posterThemes.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (ctx, idx) {
                              final item = posterThemes[idx];
                              final isSel = selectedThemeIndex == idx;
                              final colors = item['colors'] as List<Color>;

                              return GestureDetector(
                                onTap: () => setSheetState(() => selectedThemeIndex = idx),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                      width: isSel ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
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
                                          fontSize: 13,
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

                        const SizedBox(height: 24),

                        // 3. OFFER TAG PRESETS
                        Text(
                          'OFFER & DEAL TAGS',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: offerTags.map((tag) {
                            final isSel = selectedOfferTag == tag;
                            return GestureDetector(
                              onTap: () => setSheetState(() => selectedOfferTag = tag),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: GoogleFonts.outfit(
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 12.5,
                                    color: isSel ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // 4. TEXT INPUTS
                        Text(
                          'AD TEXT & CONTENT',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: titleCtrl,
                          onChanged: (_) => setSheetState(() {}),
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Campaign Headline / Title *',
                            labelStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
                            prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF4F46E5), size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: subtitleCtrl,
                          onChanged: (_) => setSheetState(() {}),
                          maxLines: 2,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Tagline / Subtitle Details',
                            labelStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
                            prefixIcon: const Icon(Icons.subtitles_rounded, color: Color(0xFF4F46E5), size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Image upload / URL
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: imageCtrl,
                                onChanged: (_) => setSheetState(() {}),
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Image URL (optional)',
                                  labelStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
                                  prefixIcon: const Icon(Icons.image_rounded, color: Color(0xFF4F46E5), size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: () async {
                                final picker = ImagePicker();
                                final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                if (img != null) {
                                  setSheetState(() {
                                    localPhotoPath = img.path;
                                    isUploadingPhoto = true;
                                  });
                                  try {
                                    final provider = Provider.of<VendorOrderProvider>(context, listen: false);
                                    final url = await provider.uploadImage(img.path);
                                    if (url != null && url.isNotEmpty) {
                                      setSheetState(() {
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
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFEEF2FF),
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: isUploadingPhoto
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // BOTTOM ACTION BAR
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (titleCtrl.text.trim().isNotEmpty) {
                            Navigator.pop(ctx);

                            final adData = {
                              'vendorId': vendor?.id ?? '',
                              'title': titleCtrl.text.trim(),
                              'subtitle': subtitleCtrl.text.trim(),
                              'imageUrl': imageCtrl.text.trim(),
                              'offerTag': selectedOfferTag,
                              'theme': currentTheme['name'],
                              'gradient': gradientColors.map((c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}').toList(),
                            };

                            final apiService = VendorApiService();
                            await apiService.createAd(adData);
                            _fetchAds();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🎉 Poster Banner published live to Customer App!'),
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                        label: Text(
                          'PUBLISH AD POSTER TO CUSTOMER APP',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.4),
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
          );
        },
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

