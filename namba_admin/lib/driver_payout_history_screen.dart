import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'order_route_history_map_screen.dart';

class DriverPayoutHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> driver;
  final List<dynamic>? allOrdersFallback;

  const DriverPayoutHistoryScreen({
    super.key,
    required this.driver,
    this.allOrdersFallback,
  });

  @override
  State<DriverPayoutHistoryScreen> createState() => _DriverPayoutHistoryScreenState();
}

class _DriverPayoutHistoryScreenState extends State<DriverPayoutHistoryScreen> {
  bool _isLoading = true;
  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  List<Map<String, dynamic>> _payoutOrders = [];

  double _totalEarnings = 0.0;
  double _totalPaid = 0.0;
  double _totalPending = 0.0;
  double _totalDistanceKm = 0.0;
  int _paidCount = 0;
  int _pendingCount = 0;

  static const double defaultBaseRate = 7.0;

  @override
  void initState() {
    super.initState();
    _loadPayoutData();
  }

  String get _driverId => (widget.driver['_id'] ?? widget.driver['id'] ?? '').toString();
  String get _driverName => (widget.driver['name'] ?? 'Driver Partner').toString();
  String get _driverPhone => (widget.driver['phone'] ?? '').toString();
  String get _vehicleInfo => '${(widget.driver['vehicleType'] ?? "Bike").toString().toUpperCase()} • ${(widget.driver['vehicleNumber'] ?? "TN-33").toString().toUpperCase()}';
  String get _upiId => (widget.driver['upiId'] ?? (widget.driver['bankDetails'] is Map ? widget.driver['bankDetails']['upiId'] : null) ?? '$_driverPhone@upi').toString();
  String get _bankName => ((widget.driver['bankDetails'] is Map ? widget.driver['bankDetails']['bankName'] : null) ?? 'State Bank of India').toString();
  String get _accountNumber => ((widget.driver['bankDetails'] is Map ? widget.driver['bankDetails']['accountNumber'] : null) ?? 'XXXXXXXX1012').toString();
  String get _ifsc => ((widget.driver['bankDetails'] is Map ? widget.driver['bankDetails']['ifsc'] : null) ?? 'SBIN0004321').toString();

  Future<void> _loadPayoutData() async {
    setState(() => _isLoading = true);

    final apiBase = (dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null) ?? 'http://54.204.9.126:5000/api/v1';
    final token = (dotenv.isInitialized ? dotenv.env['ADMIN_TOKEN'] : null) ?? '';
    final url = '$apiBase/admin/drivers/$_driverId/payout-history';

    bool fetchedFromApi = false;

    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] is List) {
          final List list = body['data'];
          if (list.isNotEmpty) {
            final List<Map<String, dynamic>> parsed = [];
            for (final item in list) {
              if (item is Map) parsed.add(Map<String, dynamic>.from(item));
            }
            _payoutOrders = parsed;
            fetchedFromApi = true;
          }
        }
      }
    } catch (e) {
      debugPrint('[DriverPayoutScreen] API fetch error: $e');
    }

    // If API didn't return or endpoint not deployed yet, extract from allOrdersFallback
    if (!fetchedFromApi && widget.allOrdersFallback != null && widget.allOrdersFallback!.isNotEmpty) {
      final List<Map<String, dynamic>> fallbackList = [];
      for (final raw in widget.allOrdersFallback!) {
        if (raw is! Map) continue;
        final o = Map<String, dynamic>.from(raw);

        // Check if this order was assigned/delivered by this driver
        final oDriver = o['driver'];
        final oDriverId = (oDriver is Map ? oDriver['_id'] : oDriver)?.toString() ?? '';
        final oDriverName = (oDriver is Map ? oDriver['name'] : o['driverName'])?.toString() ?? '';

        final matchesDriver = (oDriverId.isNotEmpty && oDriverId == _driverId) ||
            (oDriverName.isNotEmpty && oDriverName.toLowerCase() == _driverName.toLowerCase()) ||
            (o['driverPhone'] != null && o['driverPhone'].toString() == _driverPhone);

        if (!matchesDriver) continue;

        final status = (o['status'] ?? '').toString();
        final double dist = double.tryParse(o['distanceKm']?.toString() ?? '0') ?? 0.0;
        final double actualKm = double.tryParse(o['actualTravelledKm']?.toString() ?? o['distanceKm']?.toString() ?? '0') ?? dist;
        final double driverEar = double.tryParse(o['driverEarnings']?.toString() ?? '0') ?? 0.0;
        final double finalEarnings = driverEar > 0 ? driverEar : (dist > 0 ? (dist * defaultBaseRate) : 25.0);

        final bool isPaid = (o['driverPaymentStatus'] ?? '').toString().toLowerCase() == 'paid';

        String storeName = 'Shop / Store';
        String storeAddr = '';
        if (o['vendor'] is Map) {
          storeName = o['vendor']['storeName'] ?? 'Shop';
          storeAddr = o['vendor']['address'] ?? '';
        } else if (o['customStoreName'] != null && o['customStoreName'].toString().isNotEmpty) {
          storeName = o['customStoreName'].toString();
          storeAddr = o['customStoreAddress']?.toString() ?? '';
        }

        String custName = 'Customer';
        String custAddr = o['deliveryAddress']?.toString() ?? '';
        if (o['customer'] is Map) {
          custName = o['customer']['name'] ?? 'Customer';
          if (custAddr.isEmpty) custAddr = o['customer']['address'] ?? '';
        }

        fallbackList.add({
          '_id': o['_id'] ?? o['id'],
          'orderId': o['_id'] ?? o['id'],
          'displayId': o['displayId'] ?? (o['_id'] != null ? '#${o['_id'].toString().substring(o['_id'].toString().length > 5 ? o['_id'].toString().length - 5 : 0).toUpperCase()}' : '#ORDER'),
          'status': status,
          'orderType': o['orderType'] ?? 'Cart',
          'orderAmount': o['totalAmount'] ?? 0,
          'distanceKm': dist,
          'actualTravelledKm': actualKm,
          'driverEarnings': finalEarnings,
          'driverPaymentStatus': isPaid ? 'Paid' : 'Pending',
          'driverPaidAt': o['driverPaidAt'],
          'driverPaymentRef': o['driverPaymentRef'] ?? '',
          'createdAt': o['createdAt'],
          'deliveredAt': o['deliveredAt'] ?? o['updatedAt'],
          'storeName': storeName,
          'storeAddress': storeAddr,
          'customerName': custName,
          'deliveryAddress': custAddr,
          'rawOrder': o,
        });
      }

      _payoutOrders = fallbackList;
    }

    _recalculateSummary();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _recalculateSummary() {
    _totalEarnings = 0.0;
    _totalPaid = 0.0;
    _totalPending = 0.0;
    _totalDistanceKm = 0.0;
    _paidCount = 0;
    _pendingCount = 0;

    for (final p in _payoutOrders) {
      final earn = double.tryParse(p['driverEarnings']?.toString() ?? '0') ?? 0.0;
      final dist = double.tryParse(p['distanceKm']?.toString() ?? '0') ?? 0.0;
      final isPaid = (p['driverPaymentStatus'] ?? '').toString().toLowerCase() == 'paid';

      _totalEarnings += earn;
      _totalDistanceKm += dist;
      if (isPaid) {
        _totalPaid += earn;
        _paidCount++;
      } else {
        _totalPending += earn;
        _pendingCount++;
      }
    }
    setState(() {});
  }

  void _showEditKmDialog(Map<String, dynamic> item) {
    final orderId = (item['_id'] ?? item['orderId']).toString();
    final currentKm = double.tryParse(item['distanceKm']?.toString() ?? '0') ?? 0.0;
    final currentEarnings = double.tryParse(item['driverEarnings']?.toString() ?? '0') ?? 0.0;
    final displayId = item['displayId'] ?? '#ORDER';

    final TextEditingController kmController = TextEditingController(text: currentKm > 0 ? currentKm.toStringAsFixed(1) : '1.0');
    final TextEditingController feeController = TextEditingController(text: currentEarnings > 0 ? currentEarnings.toStringAsFixed(0) : '20');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final parsedKm = double.tryParse(kmController.text.trim()) ?? 0.0;
            final computedFee = math.max(10.0, (parsedKm * defaultBaseRate).roundToDouble());

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.edit_road_rounded, color: Color(0xFF4F46E5), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vary & Adjust Trip KM', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A))),
                      Text('Order $displayId • Rate: ₹$defaultBaseRate/KM', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('DISTANCE IN KILOMETERS (KM)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: TextField(
                              controller: kmController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                              onChanged: (v) {
                                final km = double.tryParse(v.trim()) ?? 0.0;
                                final autoFee = math.max(10.0, (km * defaultBaseRate).roundToDouble());
                                feeController.text = autoFee.toStringAsFixed(0);
                                setDialogState(() {});
                              },
                              decoration: InputDecoration(
                                suffixText: 'KM',
                                suffixStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick Increments (-0.5, +0.5, +1.0, +2.0)
                    Row(
                      children: [
                        _quickKmChip('-0.5 KM', () {
                          final cur = double.tryParse(kmController.text.trim()) ?? 0.0;
                          final next = math.max(0.5, cur - 0.5);
                          kmController.text = next.toStringAsFixed(1);
                          feeController.text = math.max(10.0, (next * defaultBaseRate).roundToDouble()).toStringAsFixed(0);
                          setDialogState(() {});
                        }),
                        const SizedBox(width: 8),
                        _quickKmChip('+0.5 KM', () {
                          final cur = double.tryParse(kmController.text.trim()) ?? 0.0;
                          final next = cur + 0.5;
                          kmController.text = next.toStringAsFixed(1);
                          feeController.text = math.max(10.0, (next * defaultBaseRate).roundToDouble()).toStringAsFixed(0);
                          setDialogState(() {});
                        }),
                        const SizedBox(width: 8),
                        _quickKmChip('+1.0 KM', () {
                          final cur = double.tryParse(kmController.text.trim()) ?? 0.0;
                          final next = cur + 1.0;
                          kmController.text = next.toStringAsFixed(1);
                          feeController.text = math.max(10.0, (next * defaultBaseRate).roundToDouble()).toStringAsFixed(0);
                          setDialogState(() {});
                        }),
                        const SizedBox(width: 8),
                        _quickKmChip('+2.0 KM', () {
                          final cur = double.tryParse(kmController.text.trim()) ?? 0.0;
                          final next = cur + 2.0;
                          kmController.text = next.toStringAsFixed(1);
                          feeController.text = math.max(10.0, (next * defaultBaseRate).roundToDouble()).toStringAsFixed(0);
                          setDialogState(() {});
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('RECALCULATED RIDER PAYOUT FEE (₹)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: TextField(
                        controller: feeController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF059669)),
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          prefixStyle: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF059669)),
                          suffixText: 'PAYOUT',
                          suffixStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Formula: ${parsedKm.toStringAsFixed(1)} KM × ₹$defaultBaseRate/KM = ₹${computedFee.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF15803D))),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final newKm = double.tryParse(kmController.text.trim()) ?? currentKm;
                    final newFee = double.tryParse(feeController.text.trim()) ?? currentEarnings;

                    await _updateOrderKmAndFee(orderId, newKm, newFee);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('APPLY & UPDATE KM', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateOrderKmAndFee(String orderId, double newKm, double newFee) async {
    final apiBase = (dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null) ?? 'http://54.204.9.126:5000/api/v1';
    final token = (dotenv.isInitialized ? dotenv.env['ADMIN_TOKEN'] : null) ?? '';

    // Update locally immediately
    for (var p in _payoutOrders) {
      if ((p['_id'] ?? p['orderId']).toString() == orderId) {
        p['distanceKm'] = newKm;
        p['actualTravelledKm'] = newKm;
        p['driverEarnings'] = newFee;
      }
    }
    _recalculateSummary();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Updated distance to ${newKm.toStringAsFixed(1)} KM (Payout: ₹${newFee.toStringAsFixed(0)})'),
        backgroundColor: const Color(0xFF4F46E5),
        behavior: SnackBarBehavior.floating,
      ));
    }

    try {
      await http.put(
        Uri.parse('$apiBase/admin/orders/$orderId/update-distance'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'distanceKm': newKm,
          'actualTravelledKm': newKm,
          'driverEarnings': newFee,
        }),
      );
    } catch (e) {
      debugPrint('Error saving distance update to backend: $e');
    }
  }

  Widget _quickKmChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF334155)),
        ),
      ),
    );
  }

  Future<void> _paySingleOrder(String orderId, double amount) async {
    final apiBase = (dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null) ?? 'http://54.204.9.126:5000/api/v1';
    final token = (dotenv.isInitialized ? dotenv.env['ADMIN_TOKEN'] : null) ?? '';
    final ref = 'PAY-IND-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final res = await http.put(
        Uri.parse('$apiBase/admin/orders/$orderId/pay-driver'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'paymentMethod': 'UPI',
          'transactionRef': ref,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        for (var p in _payoutOrders) {
          if ((p['_id'] ?? p['orderId']).toString() == orderId) {
            p['driverPaymentStatus'] = 'Paid';
            p['driverPaidAt'] = DateTime.now().toIso8601String();
            p['driverPaymentRef'] = ref;
          }
        }
        _recalculateSummary();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('✅ Delivery Fee ₹${amount.toStringAsFixed(0)} paid to $_driverName successfully!')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error paying single order: $e');
    }
  }

  Future<void> _settleAllPendingOrders() async {
    if (_pendingCount == 0 || _totalPending <= 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 22),
            ),
            const SizedBox(width: 12),
            Text('Settle All Pending Payouts?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to settle and mark all $_pendingCount pending orders (Total: ₹${_totalPending.toStringAsFixed(0)}) as PAID to $_driverName via UPI ($_upiId)?',
          style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.done_all_rounded, size: 16),
            label: Text('CONFIRM & PAY ₹${_totalPending.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final apiBase = (dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null) ?? 'http://54.204.9.126:5000/api/v1';
    final token = (dotenv.isInitialized ? dotenv.env['ADMIN_TOKEN'] : null) ?? '';
    final ref = 'BULK-PAY-${DateTime.now().millisecondsSinceEpoch}';

    try {
      await http.put(
        Uri.parse('$apiBase/admin/drivers/$_driverId/pay-all-pending'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'paymentMethod': 'UPI', 'transactionRef': ref}),
      );

      for (var p in _payoutOrders) {
        if ((p['driverPaymentStatus'] ?? '').toString().toLowerCase() != 'paid') {
          p['driverPaymentStatus'] = 'Paid';
          p['driverPaidAt'] = DateTime.now().toIso8601String();
          p['driverPaymentRef'] = ref;
        }
      }
      _recalculateSummary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🎉 All pending deliveries (₹${_totalPaid.toStringAsFixed(0)}) successfully marked as PAID!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('Error bulk paying: $e');
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('📋 $label copied to clipboard!'),
      backgroundColor: const Color(0xFF4F46E5),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _payoutOrders.where((p) {
      final status = (p['driverPaymentStatus'] ?? 'Pending').toString().toLowerCase();
      if (_selectedFilter == 'PAID' && status != 'paid') return false;
      if (_selectedFilter == 'PENDING' && status == 'paid') return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final disp = (p['displayId'] ?? '').toString().toLowerCase();
        final store = (p['storeName'] ?? '').toString().toLowerCase();
        final cust = (p['customerName'] ?? '').toString().toLowerCase();
        if (!disp.contains(q) && !store.contains(q) && !cust.contains(q)) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── TOP EXECUTIVE COMMAND BAR ──
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF4F46E5),
                  child: Text(
                    _driverName.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _driverName,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              _vehicleInfo,
                              style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_rounded, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 5),
                          Text(_driverPhone, style: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 16),
                          Icon(Icons.account_balance_wallet_rounded, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 5),
                          Text('UPI: $_upiId', style: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _copyToClipboard(_upiId, 'UPI ID'),
                            child: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF818CF8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Rate Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 8),
                      Text('Base Rate: ₹$defaultBaseRate / KM', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Refresh Action Button
                IconButton(
                  onPressed: _loadPayoutData,
                  tooltip: 'Refresh Ledger',
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // ── MAIN CONTENT AREA ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. 4-KPI EXECUTIVE DASHBOARD CARDS
                        Row(
                          children: [
                            _buildKpiCard('TOTAL DRIVER EARNINGS', '₹${_totalEarnings.toStringAsFixed(0)}', '${_payoutOrders.length} Total Deliveries', Icons.account_balance_wallet_rounded, const Color(0xFF0F172A), const Color(0xFF4F46E5), const Color(0xFFEEF2FF)),
                            const SizedBox(width: 18),
                            _buildKpiCard('SETTLED / PAID OUT', '₹${_totalPaid.toStringAsFixed(0)}', '$_paidCount Orders Settled', Icons.check_circle_rounded, const Color(0xFF065F46), const Color(0xFF10B981), const Color(0xFFDCFCE7)),
                            const SizedBox(width: 18),
                            _buildKpiCard('PENDING PAYOUT', '₹${_totalPending.toStringAsFixed(0)}', '$_pendingCount Orders Unpaid', Icons.hourglass_top_rounded, const Color(0xFF9A3412), const Color(0xFFF97316), const Color(0xFFFEF3C7)),
                            const SizedBox(width: 18),
                            _buildKpiCard('TOTAL DISTANCE COVERED', '${_totalDistanceKm.toStringAsFixed(1)} KM', 'Fleet Distance Audit', Icons.route_rounded, const Color(0xFF1E1B4B), const Color(0xFF6366F1), const Color(0xFFF5F3FF)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 2. BANK DETAILS & BULK SETTLE ACTION HERO BAR
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                                child: const Icon(Icons.account_balance_rounded, color: Color(0xFF4F46E5), size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('DIRECT SETTLEMENT ACCOUNT', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 1)),
                                    const SizedBox(height: 3),
                                    Text('$_bankName • A/C: $_accountNumber • IFSC: $_ifsc', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                              if (_totalPending > 0) ...[
                                ElevatedButton.icon(
                                  onPressed: _settleAllPendingOrders,
                                  icon: const Icon(Icons.done_all_rounded, size: 18),
                                  label: Text('SETTLE ALL PENDING (₹${_totalPending.toStringAsFixed(0)})', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF86EFAC))),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 18),
                                      const SizedBox(width: 8),
                                      Text('ALL SETTLED — NO PENDING DUES', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A))),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // 3. FILTER CHIPS & SEARCH BAR
                        Row(
                          children: [
                            _buildFilterChip('ALL', 'All Deliveries (${_payoutOrders.length})'),
                            const SizedBox(width: 10),
                            _buildFilterChip('PENDING', 'Pending Settlement ($_pendingCount)'),
                            const SizedBox(width: 10),
                            _buildFilterChip('PAID', 'Settled & Paid ($_paidCount)'),
                            const Spacer(),
                            // Search box
                            Container(
                              width: 320,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                decoration: InputDecoration(
                                  hintText: 'Search by Order ID, Shop...',
                                  hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12.5),
                                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 4. ITEMIZED ORDER PAYOUT TABLE / LEDGER
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                color: const Color(0xFFF8FAFC),
                                child: Row(
                                  children: [
                                    Expanded(flex: 2, child: Text('ORDER ID & DATE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.8))),
                                    Expanded(flex: 3, child: Text('PICKUP & DROP ROUTE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.8))),
                                    Expanded(flex: 2, child: Text('DISTANCE & KM ADJUST', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.8))),
                                    Expanded(flex: 2, child: Text('RIDER PAYOUT', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.8))),
                                    Expanded(flex: 2, child: Text('STATUS & ACTION', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.8))),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),

                              if (filtered.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(48),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.receipt_long_rounded, size: 52, color: Colors.grey.shade300),
                                        const SizedBox(height: 14),
                                        Text('No Delivery Records Found', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                                        const SizedBox(height: 4),
                                        Text('No orders matching the selected filter for $_driverName.', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  itemBuilder: (context, idx) {
                                    final item = filtered[idx];
                                    final isPaid = (item['driverPaymentStatus'] ?? 'Pending').toString().toLowerCase() == 'paid';
                                    final earnVal = double.tryParse(item['driverEarnings']?.toString() ?? '0') ?? 0.0;
                                    final distKm = double.tryParse(item['distanceKm']?.toString() ?? '0') ?? 0.0;
                                    final dateStr = item['createdAt'] != null
                                        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(item['createdAt'].toString()).toLocal())
                                        : '--';
                                    final rawOrder = item['rawOrder'] ?? item;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      child: Row(
                                        children: [
                                          // 1. Order ID & Date
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                                                      child: Text(
                                                        item['displayId'] ?? '#ORDER',
                                                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12.5, color: const Color(0xFF4F46E5)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(dateStr, style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                              ],
                                            ),
                                          ),

                                          // 2. Pickup & Drop Route
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFFF97316)),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        item['storeName'] ?? 'Shop',
                                                        style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF10B981)),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        '${item['customerName'] ?? "Customer"} (${item['deliveryAddress'] ?? ""})',
                                                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // 3. Distance & Interactive KM Vary / Edit & Route Verify
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                              children: [
                                                // Distance Chip
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                                  ),
                                                  child: Text(
                                                    distKm > 0 ? '${distKm.toStringAsFixed(1)} KM' : 'City Trip',
                                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),

                                                // Vary / Edit KM Button
                                                Tooltip(
                                                  message: 'Vary / Adjust KM & Recalculate Payout',
                                                  child: InkWell(
                                                    onTap: () => _showEditKmDialog(item),
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEEF2FF),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: const Color(0xFFC7D2FE)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.edit_rounded, size: 13, color: Color(0xFF4F46E5)),
                                                          const SizedBox(width: 4),
                                                          Text('VARY KM', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),

                                                // View Route Map Button
                                                Tooltip(
                                                  message: 'Verify GPS Route Trail & Road Curvature',
                                                  child: InkWell(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(builder: (_) => OrderRouteHistoryMapScreen(order: rawOrder)),
                                                      );
                                                    },
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF8FAFC),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                                      ),
                                                      child: const Icon(Icons.map_rounded, size: 14, color: Color(0xFF475569)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // 4. Rider Payout Amount
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '₹${earnVal.toStringAsFixed(0)}',
                                                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                                                ),
                                                Text('EARNED FEE (@ ₹$defaultBaseRate/KM)', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF059669), letterSpacing: 0.4)),
                                              ],
                                            ),
                                          ),

                                          // 5. Status & Pay Button
                                          Expanded(
                                            flex: 2,
                                            child: isPaid
                                                ? Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFDCFCE7),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFF86EFAC)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                                        const SizedBox(width: 5),
                                                        Text('PAID ✅', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A))),
                                                      ],
                                                    ),
                                                  )
                                                : ElevatedButton.icon(
                                                    onPressed: () {
                                                      final oId = (item['_id'] ?? item['orderId']).toString();
                                                      _paySingleOrder(oId, earnVal);
                                                    },
                                                    icon: const Icon(Icons.payments_rounded, size: 14),
                                                    label: Text('PAY ₹${earnVal.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11.5)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF10B981),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                      elevation: 0,
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
    );
  }

  Widget _buildKpiCard(String title, String mainValue, String subValue, IconData icon, Color textColor, Color iconColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(mainValue, style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: textColor)),
            const SizedBox(height: 3),
            Text(subValue, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1)),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.25), blurRadius: 8)] : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
