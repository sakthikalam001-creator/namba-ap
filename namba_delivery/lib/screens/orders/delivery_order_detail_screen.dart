import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../services/voice_dispatch_service.dart';
import '../../services/delivery_auth_service.dart';
import '../../providers/delivery_provider.dart';
import '../../models/delivery_order.dart';
import '../../services/delivery_language_provider.dart';
import '../map/order_tracking_map_screen.dart';
import '../support/rider_chatbot_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const DeliveryOrderDetailScreen({super.key, required this.orderId});

  @override
  State<DeliveryOrderDetailScreen> createState() => _DeliveryOrderDetailScreenState();
}

class _DeliveryOrderDetailScreenState extends State<DeliveryOrderDetailScreen> {
  String? _localPickedPath; // Tracks image before confirmation
  Timer? _unassignTimer;
  Timer? _liveSyncTimer;
  bool _showUnassignedNotice = false;

  // ─── Accurate Route KM & Earnings via Valhalla ───────────────────────────
  double? _routeKm;        // null = still loading
  double? _routeEarnings;  // null = still loading
  bool _routeFetched = false;

  @override
  void initState() {
    super.initState();
    try {
      Provider.of<DeliveryProvider>(context, listen: false).stopAlarmSound();
    } catch (_) {}
    // Fetch accurate route distance and start live sync polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAccurateRoute();
      _startLiveSync();
    });
  }

  void _startLiveSync() {
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      try {
        Provider.of<DeliveryProvider>(context, listen: false).syncOrdersSilently();
      } catch (_) {}
    });
  }

  /// Fetch STORE → CUSTOMER route distance using Valhalla (shortest=true)
  /// and derive rider earnings from it. Updates state when done.
  Future<void> _fetchAccurateRoute() async {
    if (_routeFetched || !mounted) return;
    _routeFetched = true;

    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    DeliveryOrder? order;
    try {
      order = provider.incomingRequests.firstWhere(
        (o) => o.id == widget.orderId || o.displayId == widget.orderId);
    } catch (_) {}
    if (order == null) {
      try {
        order = provider.activeOrders.firstWhere(
          (o) => o.id == widget.orderId || o.displayId == widget.orderId);
      } catch (_) {}
    }
    if (order == null) return;

    final sLat = order.storeLat;
    final sLng = order.storeLng;
    final dLat = order.destLat;
    final dLng = order.destLng;
    if (sLat == null || sLng == null || dLat == null || dLng == null) return;
    if (sLat == 0 || dLat == 0) return;

    try {
      final urls = [
        'https://routing.openstreetmap.de/routed-bike/route/v1/biking/$sLng,$sLat;$dLng,$dLat?overview=false&alternatives=3',
        'https://router.project-osrm.org/route/v1/driving/$sLng,$sLat;$dLng,$dLat?overview=false&alternatives=3',
        'https://routing.openstreetmap.de/routed-car/route/v1/driving/$sLng,$sLat;$dLng,$dLat?overview=false&alternatives=3',
      ];

      final responses = await Future.wait(
        urls.map((url) => http.get(Uri.parse(url), headers: {'User-Agent': 'NambaDeliveryApp/1.0 (delivery.namba@gmail.com)'}).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)))
      );

      double? minKm;
      for (final res in responses) {
        if (res.statusCode == 200 && res.body.isNotEmpty) {
          try {
            final data = jsonDecode(res.body);
            final routes = data['routes'] as List? ?? [];
            for (var r in routes) {
              final d = (r['distance'] as num).toDouble() / 1000.0;
              if (d > 0 && (minKm == null || d < minKm)) minKm = d;
            }
          } catch (_) {}
        }
      }

      double? dropKm = minKm;

      if (dropKm != null && dropKm > 0) {

        // Fetch Admin setting: Driver Pay Rates & Include Rider Pickup Distance
        bool includePickupKm = true;
        double baseRate = 7.0;
        double thresholdKm = 50.0;
        double bonusRate = 2.0;
        double minEarnings = 10.0;
        try {
          final settingsRes = await http.get(Uri.parse('${DeliveryAuthService.baseUrl}/admin/settings/public')).timeout(const Duration(seconds: 2));
          if (settingsRes.statusCode == 200) {
            final sData = jsonDecode(settingsRes.body);
            if (sData['success'] == true && sData['data'] != null) {
              final d = sData['data'];
              includePickupKm = d['includeRiderPickupDistance'] ?? true;
              if (d['driverBaseRatePerKm'] != null) baseRate = (d['driverBaseRatePerKm'] as num).toDouble();
              if (d['driverLongDistanceThresholdKm'] != null) thresholdKm = (d['driverLongDistanceThresholdKm'] as num).toDouble();
              if (d['driverLongDistanceBonusPerKm'] != null) bonusRate = (d['driverLongDistanceBonusPerKm'] as num).toDouble();
              if (d['driverMinEarningsPerOrder'] != null) minEarnings = (d['driverMinEarningsPerOrder'] as num).toDouble();
            }
          }
        } catch (_) {}

        // Pickup KM: Rider Current Location -> Store (ONLY IF Admin setting is ON)
        double pickupKm = 0.0;
        if (includePickupKm) {
          try {
            Position? pos = await Geolocator.getLastKnownPosition();
            pos ??= await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
            ).timeout(const Duration(seconds: 2));
            try {
              final pUrls = [
                'https://routing.openstreetmap.de/routed-bike/route/v1/biking/${pos.longitude},${pos.latitude};$sLng,$sLat?overview=false&alternatives=3',
                'https://router.project-osrm.org/route/v1/driving/${pos.longitude},${pos.latitude};$sLng,$sLat?overview=false&alternatives=3',
                'https://routing.openstreetmap.de/routed-car/route/v1/driving/${pos.longitude},${pos.latitude};$sLng,$sLat?overview=false&alternatives=3',
              ];
              final pResponses = await Future.wait(
                pUrls.map((url) => http.get(Uri.parse(url), headers: {'User-Agent': 'NambaDeliveryApp/1.0 (delivery.namba@gmail.com)'}).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 500)))
              );
              double? pMinKm;
              for (final res in pResponses) {
                if (res.statusCode == 200 && res.body.isNotEmpty) {
                  try {
                    final data = jsonDecode(res.body);
                    final routes = data['routes'] as List? ?? [];
                    for (var r in routes) {
                      final d = (r['distance'] as num).toDouble() / 1000.0;
                      if (d > 0 && (pMinKm == null || d < pMinKm)) pMinKm = d;
                    }
                  } catch (_) {}
                }
              }
              pickupKm = pMinKm ?? ((Geolocator.distanceBetween(pos.latitude, pos.longitude, sLat, sLng) * 1.15) / 1000.0);
            } catch (_) {
              final pickupMeters = Geolocator.distanceBetween(pos.latitude, pos.longitude, sLat, sLng);
              pickupKm = (pickupMeters * 1.15) / 1000.0;
            }
          } catch (_) {}
        }

        final double totalTripKm = pickupKm + dropKm;

        // Rider earnings: Dynamic from admin panel settings
        double earnings = 0;
        if (totalTripKm <= thresholdKm) {
          earnings = totalTripKm * baseRate;
        } else {
          earnings = (thresholdKm * baseRate) + ((totalTripKm - thresholdKm) * (baseRate + bonusRate));
        }
        if (earnings < minEarnings) earnings = minEarnings;

        if (mounted) {
          setState(() {
            _routeKm = totalTripKm;
            _routeEarnings = earnings.roundToDouble();
          });
        }
      }
    } catch (e) {
      debugPrint('[OrderDetail] Route fetch failed: $e');
    }
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    _unassignTimer?.cancel();
    super.dispose();
  }

  void _scheduleUnassignedCheck() {
    if (_unassignTimer != null) return;
    _unassignTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showUnassignedNotice = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final lang = context.watch<DeliveryLanguageProvider>();

    // 1. Check incoming (just assigned, not yet picked up)
    final incomingIdx = provider.incomingRequests.indexWhere(
      (o) => o.id == widget.orderId || o.displayId == widget.orderId
    );
    if (incomingIdx != -1) {
      _unassignTimer?.cancel();
      _unassignTimer = null;
      _showUnassignedNotice = false;
      final coreOrder = provider.incomingRequests[incomingIdx];
      return _buildIncomingOrderUI(context, coreOrder, provider);
    }

    // 2. Check Active orders (Assigned, Preparing, PickedUp, etc.)
    final activeIdx = provider.activeOrders.indexWhere(
      (o) => o.id == widget.orderId || o.displayId == widget.orderId
    );
    if (activeIdx != -1) {
      _unassignTimer?.cancel();
      _unassignTimer = null;
      _showUnassignedNotice = false;
      final dOrder = provider.activeOrders[activeIdx];
      return _buildActiveOrderUI(context, dOrder, provider);
    }

    // 3. Check Order History (Delivered, Cancelled)
    final historyIdx = provider.orderHistory.indexWhere(
      (o) => o.id == widget.orderId || o.displayId == widget.orderId
    );
    if (historyIdx != -1) {
      _unassignTimer?.cancel();
      _unassignTimer = null;
      _showUnassignedNotice = false;
      return _buildCompletedUI(context);
    }

    // 4. Default / Transition state - Show Loading while syncing or Unassigned Notice
    _scheduleUnassignedCheck();

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkText, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_showUnassignedNotice) ...[
                const CircularProgressIndicator(color: AppTheme.primaryOrange),
                const SizedBox(height: 24),
                Text(
                  lang.text(
                    en: 'Syncing order details...',
                    ta: 'ஆர்டர் விவரங்கள் புதுப்பிக்கப்படுகின்றன...',
                    tanglish: 'Order details sync aaguthu...',
                  ),
                  style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.assignment_late_rounded, color: Colors.orange.shade700, size: 56),
                ),
                const SizedBox(height: 24),
                Text(
                  lang.text(
                    en: 'Order Unassigned',
                    ta: 'ஆர்டர் நீக்கப்பட்டது',
                    tanglish: 'Order Unassigned',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  lang.text(
                    en: 'This order is no longer in your active list.',
                    ta: 'இந்த ஆர்டர் உங்களது பட்டியலிலிருந்து நீக்கப்பட்டுவிட்டது.',
                    tanglish: 'Indha order unga list-la irundhu neekappattathu.',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: Text(
                      lang.text(
                        en: 'RETURN TO DASHBOARD',
                        ta: 'முகப்புக்குச் செல்',
                        tanglish: 'RETURN TO DASHBOARD',
                      ),
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedUI(BuildContext context) {
    final lang = Provider.of<DeliveryLanguageProvider>(context);
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 80),
          const SizedBox(height: 16),
          Text(
            lang.text(
              en: 'Order Completed!',
              ta: 'ஆர்டர் முடிந்தது!',
              tanglish: 'Order Completed!',
            ),
            style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              lang.text(
                en: 'Go back',
                ta: 'திரும்பிச் செல்',
                tanglish: 'Go back',
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── INCOMING ORDER — Accept/Decline View ──────────────────────────────────
  Widget _buildIncomingOrderUI(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final lang = Provider.of<DeliveryLanguageProvider>(context);
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.07,
              child: Image.network(
                'https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?q=80&w=2000&auto=format&fit=crop',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppTheme.softShadow),
                        child: const Icon(Icons.close_rounded, color: AppTheme.darkText, size: 20)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        const Icon(icons.Iconsax.clock_copy, color: AppTheme.primaryOrange, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          lang.text(
                            en: 'RESPOND QUICKLY',
                            ta: 'விரைவாக பதிலளிக்கவும்',
                            tanglish: 'RESPOND QUICKLY',
                          ),
                          style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const Spacer(),

                // Details Card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                    boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 40, offset: Offset(0, -10))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 24),
                      
                      // Order ID Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.darkText.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${lang.text(en: 'ORDER ID:', ta: 'ஆர்டர் எண்:', tanglish: 'ORDER ID:')} ${order.displayId.isNotEmpty ? order.displayId : order.id.substring(0, 8).toUpperCase()}',
                          style: GoogleFonts.outfit(
                            color: AppTheme.darkText,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Earning + Distance
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                lang.text(
                                  en: 'RIDER EARNINGS (ROUTE KM)',
                                  ta: 'ரைடர் வருமானம்',
                                  tanglish: 'RIDER EARNINGS',
                                ),
                                style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                              Text('₹', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              _routeEarnings == null
                                ? Row(children: [
                                    const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B35))),
                                    const SizedBox(width: 8),
                                    Text('...', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 24, fontWeight: FontWeight.w900)),
                                  ])
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _routeEarnings!.toStringAsFixed(0),
                                      style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1),
                                    ),
                                  ),
                            ]),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                            child: Column(children: [
                              const Icon(icons.Iconsax.routing_copy, color: AppTheme.primaryOrange, size: 18),
                              const SizedBox(height: 3),
                              _routeKm == null
                                ? Text('...', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w900, fontSize: 11))
                                : Text('${_routeKm!.toStringAsFixed(1)} ${lang.text(en: 'KM', ta: 'கி.மீ', tanglish: 'KM')}', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w900, fontSize: 11)),
                            ]),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(14)),
                            child: Column(children: [
                              const Icon(icons.Iconsax.box_1_copy, color: AppTheme.darkText, size: 18),
                              const SizedBox(height: 3),
                              Text('${order.items.length} ${lang.text(en: 'ITEMS', ta: 'பொருட்கள்', tanglish: 'ITEMS')}', style: GoogleFonts.outfit(color: AppTheme.darkText, fontWeight: FontWeight.w900, fontSize: 11)),
                            ]),
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 28),

                      // Item List
                      if (order.items.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: order.items.map<Widget>((item) {
                              final String itemName = item.toString();
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(children: [
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.primaryOrange, shape: BoxShape.circle)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(
                                    itemName,
                                    style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.w700),
                                  )),
                                ]),
                              );
                            }).toList(),
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Payment Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: (order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              order.paymentMethod == 'COD' ? Icons.payments_outlined : Icons.account_balance_wallet_outlined,
                              color: order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              order.paymentMethod == 'COD'
                                  ? lang.text(en: 'CASH ON DELIVERY', ta: 'நேரடி பண வசூல்', tanglish: 'CASH ON DELIVERY')
                                  : lang.text(en: 'ONLINE PAYMENT RECEIVED', ta: 'ஆன்லைன் கட்டணம் பெறப்பட்டது', tanglish: 'ONLINE PAYMENT RECEIVED'),
                              style: GoogleFonts.outfit(
                                color: order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      _buildRouteStop(icons.Iconsax.shop_copy, lang.text(en: 'STORE', ta: 'கடை', tanglish: 'STORE'), order.storeName.toUpperCase(), AppTheme.primaryOrange, subtext: order.storeAddress.isNotEmpty ? order.storeAddress : null),
                      const SizedBox(height: 12),
                      _buildRouteStop(icons.Iconsax.user_copy, lang.text(en: 'DROP-OFF', ta: 'டெலிவரி இடம்', tanglish: 'DROP-OFF'), order.customerName.toUpperCase(), AppTheme.accentGreen, subtext: order.customerAddress.isNotEmpty && order.customerAddress != 'Check app' ? order.customerAddress : null),
                      const SizedBox(height: 32),

                      // DECLINE | ACCEPT
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              await provider.declineAssignment(order.id);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Center(
                                child: Text(
                                  lang.text(en: 'DECLINE', ta: 'நிராகரி', tanglish: 'DECLINE'),
                                  style: GoogleFonts.outfit(color: Colors.red.shade500, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () async {
                              VoiceDispatchService.missionAccepted();
                              await provider.acceptAssignment(order.id);
                              // Screen transitions automatically via provider sync!
                            },
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [AppTheme.accentGreen, Color(0xFF00C853)]),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                              ),
                              child: Center(
                                child: Text(
                                  lang.text(en: 'ACCEPT ORDER', ta: 'ஏற்றுக்கொள்', tanglish: 'ACCEPT ORDER'),
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ACTIVE ORDER — Live Status + Action Buttons ───────────────────────────
  // ── ACTIVE ORDER — Live Status + Action Buttons ───────────────────────────
  Widget _buildActiveOrderUI(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final lang = Provider.of<DeliveryLanguageProvider>(context);
    final orderLabel = order.displayId.isNotEmpty ? '#${order.displayId}' : '#${order.id.substring(order.id.length - 6).toUpperCase()}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            '${lang.text(en: 'ORDER', ta: 'ஆர்டர்', tanglish: 'ORDER')} $orderLabel',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.2,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF0F172A)),
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms),
                const SizedBox(width: 6),
                Text(
                  lang.text(en: 'ACTIVE', ta: 'செயலில்', tanglish: 'ACTIVE'),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF065F46),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            // Batch Order Switcher Banner (when 2+ active orders exist)
            if (provider.activeOrders.length >= 2)
              _buildBatchOrderSwitcherBanner(context, order, provider),

            // Special Notification for Any Shop Orders
            if (order.isCustomStore)
              _buildCustomOrderBanner(order),

            // Notification for Specific Vendor Text/Photo Orders
            if (!order.isCustomStore && order.orderType != 'Cart')
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.25)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x060F172A), blurRadius: 12, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5), size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text('${lang.text(en: 'STORE SPECIAL ORDER', ta: 'கடை சிறப்பு ஆர்டர்', tanglish: 'STORE SPECIAL ORDER')} (${order.orderType.toUpperCase()})', style: GoogleFonts.outfit(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8)),
                ]),
              ),

            // Live Status Tracker
            _buildLiveStatusTracker(order),
            const SizedBox(height: 24),

            // Text/Photo Content (if any)
            if (order.orderType != 'Cart' && order.textContent != null)
              _buildOrderContentCard(order),
            
            const SizedBox(height: 16),

            // ── PHASE-BASED CARD DISPLAY ───────────────────────────────
            // 1. BEFORE PICKUP: Show ONLY Vendor details (PICKUP FROM)
            if (!(order.status == DeliveryStatus.pickedUp || order.status == DeliveryStatus.onTheWay || order.status == DeliveryStatus.delivered || order.rawStatus == 'PickedUp' || order.rawStatus == 'Picked Up' || order.rawStatus == 'OutForDelivery')) ...[
              _buildRouteStop(
                icons.Iconsax.shop_copy, 
                lang.text(en: 'PICKUP AT STORE', ta: 'கடையிலிருந்து எடுக்கவும்', tanglish: 'PICKUP AT STORE'), 
                order.storeName, 
                const Color(0xFFEA580C), 
                subtext: order.storeAddress.isNotEmpty ? order.storeAddress : null, 
                hasActions: true,
                onNavigate: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => OrderTrackingMapScreen(orderId: widget.orderId, focusOnCustomer: false)),
                ),
                onCall: () => launchUrl(Uri.parse('tel:${order.storePhone}')),
              ),
              const SizedBox(height: 12),
              _buildVendorQrCodeCard(order, provider),
              const SizedBox(height: 12),
            ],

            // 2. AFTER PICKUP: Show ONLY Customer details (DELIVER TO)
            if (order.status == DeliveryStatus.pickedUp || order.status == DeliveryStatus.onTheWay || order.status == DeliveryStatus.delivered || order.rawStatus == 'PickedUp' || order.rawStatus == 'Picked Up' || order.rawStatus == 'OutForDelivery') ...[
              _buildRouteStop(
                icons.Iconsax.user_copy, 
                '${lang.text(en: 'DELIVER TO CUSTOMER', ta: 'வாடிக்கையாளரிடம் சேர்க்கவும்', tanglish: 'DELIVER TO CUSTOMER')} (${order.formattedDistance})', 
                order.customerName, 
                const Color(0xFF059669), 
                subtext: order.customerAddress.isNotEmpty && order.customerAddress != 'Check app' ? order.customerAddress : lang.text(en: 'Customer Destination Set On Map', ta: 'வாடிக்கையாளர் இடம் வரைபடத்தில் உள்ளது', tanglish: 'Customer Destination Set On Map'), 
                hasActions: true,
                onNavigate: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => OrderTrackingMapScreen(orderId: widget.orderId, focusOnCustomer: true)),
                ),
                onCall: () => launchUrl(Uri.parse('tel:${order.customerPhone}')),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 32),

            // Order items & total
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
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
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lang.text(en: 'ORDER SUMMARY', ta: 'ஆர்டர் விவரங்கள்', tanglish: 'ORDER SUMMARY'),
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormat('hh:mm a').format(DateTime.now()),
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF475569),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (order.items.isNotEmpty) ...[
                    ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1E293B),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 8),
                  ],
                  const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.text(en: 'PAYMENT METHOD', ta: 'கட்டண முறை', tanglish: 'PAYMENT METHOD'),
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: (order.paymentMethod == 'COD' ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (order.paymentMethod == 'COD' ? const Color(0xFFF97316).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                        ),
                        child: Text(
                          order.paymentMethod == 'COD'
                              ? lang.text(en: 'CASH ON DELIVERY', ta: 'நேரடி பண வசூல்', tanglish: 'CASH ON DELIVERY')
                              : lang.text(en: 'ONLINE PAYMENT', ta: 'ஆன்லைன் கட்டணம்', tanglish: 'ONLINE PAYMENT'),
                          style: GoogleFonts.outfit(
                            color: order.paymentMethod == 'COD' ? const Color(0xFFEA580C) : const Color(0xFF047857),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── CONDITIONAL PAYMENT STATUS / CASH COLLECTION CARD ──
                  Builder(builder: (context) {
                    final bool isCod = order.paymentMethod == 'COD';
                    final bool isCustom = order.isCustomStore || order.orderType == 'MapPin' || order.orderType == 'map_pin';
                    final double deliveryFee = order.deliveryFee > 0
                        ? order.deliveryFee
                        : (isCustom && order.subTotal == 0 && order.totalAmount > 0 ? order.totalAmount : 0.0);
                    
                    final double shopBill = order.subTotal > 0
                        ? order.subTotal
                        : (order.vendorPaymentDetailsUploadedByDriver && order.totalAmount > deliveryFee ? order.totalAmount - deliveryFee : 0.0);

                    // 1. CASH ON DELIVERY (COD) -> Rider must collect cash from customer
                    if (isCod) {
                      final double cashToCollect = order.totalAmount > 0
                          ? order.totalAmount
                          : (order.subTotal + (order.deliveryFee > 0 ? order.deliveryFee : 0));
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.35), width: 1.2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.payments_rounded,
                                      color: Color(0xFFEA580C),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lang.text(en: 'COLLECT CASH ON DELIVERY', ta: 'நேரடி பண வசூல்', tanglish: 'CASH ON DELIVERY'),
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFEA580C),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          lang.text(en: 'Collect cash from customer', ta: 'வாடிக்கையாளரிடம் ரொக்கம் வாங்கவும்', tanglish: 'Customer kitta cash vangavum'),
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF9A3412),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${cashToCollect.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFEA580C),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // 2. CUSTOM STORE / MAP PIN / PHOTO ORDERS -> Bill Quote / Admin Payment Status
                    if (isCustom) {
                      final bool vendorPaid = order.vendorPaymentStatus == 'Completed' || order.vendorPaymentStatus == 'Paid';
                      if (vendorPaid) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.text(en: 'ADMIN PAID SHOP ✅', ta: 'அட்மின் கடைக்கு செலுத்திவிட்டார் ✅', tanglish: 'ADMIN PAID SHOP ✅'),
                                      style: GoogleFonts.outfit(color: const Color(0xFF047857), fontSize: 11.5, fontWeight: FontWeight.w900),
                                    ),
                                    Text(
                                      lang.text(en: 'Admin paid shop • No payment needed at store', ta: 'கடைக்கு அட்மின் பணம் செலுத்திவிட்டார் • கடைக்கு பணம் கொடுக்க தேவையில்லை', tanglish: 'Admin kadai-ku pay panniyachu • Kadai-ku cash thara vendam'),
                                      style: GoogleFonts.outfit(color: const Color(0xFF065F46), fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (shopBill > 0) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.text(en: 'STORE BILL QUOTE', ta: 'கடை பில் விபரம்', tanglish: 'STORE BILL QUOTE'),
                                    style: GoogleFonts.outfit(color: const Color(0xFFD97706), fontSize: 11.5, fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    lang.text(en: 'Awaiting admin payment', ta: 'அட்மின் பணம் செலுத்த காத்திருக்கிறது', tanglish: 'Admin payment-ku waiting'),
                                    style: GoogleFonts.outfit(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Text(
                                '₹${shopBill.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.text(en: 'STORE BILL QUOTE', ta: 'கடை பில் விபரம்', tanglish: 'STORE BILL QUOTE'),
                                    style: GoogleFonts.outfit(color: const Color(0xFFEA580C), fontSize: 11.5, fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    lang.text(en: 'Upload shop bill receipt', ta: 'கடை பில் ரசீது பதிவேற்றவும்', tanglish: 'Shop bill receipt upload seyyavum'),
                                    style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Text(
                                lang.text(en: 'QUOTE PENDING', ta: 'பில் நிலுவை', tanglish: 'QUOTE PENDING'),
                                style: GoogleFonts.outfit(color: const Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        );
                      }
                    }

                    // 3. CART ORDER WITH ONLINE PAYMENT -> Customer already paid online! Never confuse rider with store bill amounts.
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF059669),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      lang.text(en: 'PAYMENT DONE', ta: 'கட்டணம் செலுத்தப்பட்டது', tanglish: 'PAYMENT DONE'),
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF047857),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF059669),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        lang.text(en: 'PAID ONLINE ✅', ta: 'ஆன்லைனில் வரவானது ✅', tanglish: 'PAID ONLINE ✅'),
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  lang.text(en: 'Customer paid online • Do not collect cash', ta: 'ஆன்லைன் கட்டணம் செலுத்தப்பட்டது • வாடிக்கையாளரிடம் பணம் வாங்க வேண்டாம்', tanglish: 'Customer online-la pay panniyachu • Cash vangathirgal'),
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF065F46),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bill Photo Section (Only for Map Pin / Custom orders)
            if ((order.isCustomStore || order.orderType == 'MapPin' || order.orderType == 'map_pin') && 
                (order.status == DeliveryStatus.pickedUp || order.status == DeliveryStatus.onTheWay))
              _buildBillUploadSection(context, order, provider),
            
            const SizedBox(height: 20),
            
            // Delivery Support / Raise Ticket
            InkWell(
              onTap: () => _showDeliverySupportBottomSheet(context, order),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 12, offset: Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: Color(0xFFF97316), size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.text(en: 'Need help with this order?', ta: 'ஆர்டரில் உதவி தேவையா?', tanglish: 'Indha order-la help thevaiya?'),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14.5, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            lang.text(en: 'Raise a ticket or report an issue', ta: 'புகார் பதிவு செய்ய அல்லது சிக்கல்களை தெரிவிக்க', tanglish: 'Ticket poda or issue report panna'),
                            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 15),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionButton(context, order, provider),
    );
  }



  Widget _buildVendorQrCodeCard(DeliveryOrder order, DeliveryProvider provider) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    // ⚡ Shop bill submission by rider is ONLY for Map Pin / Custom Store orders!
    // For registered shop orders, the shop prepares and sends the bill quote themselves in the Vendor App.
    final bool isMapPinOrder = order.isCustomStore || order.orderType == 'MapPin' || order.orderType == 'map_pin';
    if (!isMapPinOrder) return const SizedBox.shrink();

    final qrUrl = order.vendorQrCodeUrl ?? '';
    final gpayNum = order.vendorGpayNumber ?? '';
    final hasQr = qrUrl.isNotEmpty;
    final hasGpay = gpayNum.isNotEmpty;
    final bool isPaidByAdmin = order.vendorPaymentStatus == 'Completed' || order.vendorPaymentStatus == 'Paid';
    final bool quoteSent = order.subTotal > 0 || hasQr || hasGpay || order.vendorPaymentDetailsUploadedByDriver;

    // Case 1: Admin has paid the vendor (Green Success Card)
    if (isPaidByAdmin) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.text(
                          en: 'SHOP PAYMENT COMPLETED',
                          ta: 'கடைக்கான தொகை செலுத்தப்பட்டது',
                          tanglish: 'SHOP PAYMENT COMPLETED',
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF166534),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        lang.text(
                          en: 'Admin has transferred payment to shop. Please collect items and proceed to delivery.',
                          ta: 'அட்மின் கடைக்கு பணம் செலுத்திவிட்டார். பொருட்களைப் பெற்று டெலிவரிக்குச் செல்லவும்.',
                          tanglish: 'Admin kadai-ku payment anupitaaru. Items vaangitu delivery pogavum.',
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: const Color(0xFF15803D),
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasQr || hasGpay) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF166534),
                    side: const BorderSide(color: Color(0xFF86EFAC), width: 1.5),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: Text(
                    lang.text(
                      en: 'VIEW SHOP PAYMENT DETAILS',
                      ta: 'கடை கட்டண விவரங்களைப் பார்க்கவும்',
                      tanglish: 'SHOP PAYMENT DETAILS PAARKAVUM',
                    ),
                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900),
                  ),
                  onPressed: () => _showVendorQrDialog(order),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Case 2: Quote submitted & Waiting for Admin payment transfer (Orange Pending Card)
    if (quoteSent) {
      final shopAmt = order.subTotal > 0 ? order.subTotal.toInt() : (order.totalAmount > 0 ? order.totalAmount.toInt() : 0);
      final deliveryAmt = order.deliveryFee > 0 ? order.deliveryFee.toInt() : 30;
      final customerTotal = order.totalAmount > 0 ? order.totalAmount.toInt() : (shopAmt + deliveryAmt);
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD97706).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${lang.text(en: 'QUOTE', ta: 'மதிப்பீடு', tanglish: 'QUOTE')}: ₹$customerTotal',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF92400E),
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lang.text(
                                en: 'WAITING ADMIN',
                                ta: 'அட்மினுக்கு காத்திருக்கிறது',
                                tanglish: 'WAITING ADMIN',
                              ),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        lang.text(
                          en: 'Shop Bill: ₹$shopAmt + Delivery Fee: ₹$deliveryAmt = Total: ₹$customerTotal.\nAdmin & Customer notified. Waiting for payment.',
                          ta: 'கடை பில்: ₹$shopAmt + டெலிவரி கட்டணம்: ₹$deliveryAmt = மொத்தம்: ₹$customerTotal.\nஅட்மின் மற்றும் வாடிக்கையாளருக்கு தெரிவிக்கப்பட்டது. பணத்திற்காக காத்திருக்கிறது.',
                          tanglish: 'Kadai Bill: ₹$shopAmt + Delivery Fee: ₹$deliveryAmt = Total: ₹$customerTotal.\nAdmin & Customer-ku therivikapatadhu. Payment-kaga wait pannudhu.',
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: const Color(0xFFB45309),
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    ),
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: Text(
                      lang.text(
                        en: 'VIEW SHOP QR / GPAY',
                        ta: 'கடை QR / GPAY பார்க்க',
                        tanglish: 'SHOP QR / GPAY PAARKA',
                      ),
                      style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                    ),
                    onPressed: () => _showVendorQrDialog(order),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF92400E),
                    side: const BorderSide(color: Color(0xFFFCD34D), width: 1.5),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  child: Text(
                    lang.text(
                      en: 'EDIT',
                      ta: 'மாற்று',
                      tanglish: 'EDIT',
                    ),
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                  onPressed: () => _showQuoteDialog(context, order, provider),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Case 3: Initial State - Need to Enter Quote & Snap Shop QR (Inline Form)
    return QuoteSubmitForm(order: order, provider: provider);
  }

  void _showVendorQrDialog(DeliveryOrder order) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    final gpayNum = order.vendorGpayNumber ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(
              '📍 ${order.storeName} - ${lang.text(en: 'Payment Details', ta: 'கட்டண விவரங்கள்', tanglish: 'Payment Details')}',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.darkText),
            ),
            const SizedBox(height: 16),
            if (order.vendorQrCodeUrl != null && order.vendorQrCodeUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  order.vendorQrCodeUrl!.startsWith('http')
                      ? order.vendorQrCodeUrl!
                      : 'http://54.204.9.126:5000${order.vendorQrCodeUrl}',
                  height: 220,
                  width: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.qr_code_2_rounded, size: 100, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── GPAY NUMBER CARD ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, color: Color(0xFF059669), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.text(en: 'Google Pay / PhonePe Number', ta: 'கூகுள் பே / போன்பே எண்', tanglish: 'Google Pay / PhonePe Number'),
                              style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.lightText, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              gpayNum.isNotEmpty ? gpayNum : lang.text(en: 'Not set yet', ta: 'இன்னும் அமைக்கப்படவில்லை', tanglish: 'Innum set pannala'),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: gpayNum.isNotEmpty ? const Color(0xFF059669) : Colors.grey,
                              ),
                            ),
                            if (order.vendorGpayName != null && order.vendorGpayName!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                '${lang.text(en: 'Account Name', ta: 'கணக்கு பெயர்', tanglish: 'Account Name')}: ${order.vendorGpayName}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF4F46E5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (gpayNum.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: gpayNum));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(lang.text(en: '📋 GPay number copied to clipboard!', ta: '📋 கூகுள் பே எண் நகலெடுக்கப்பட்டது!', tanglish: '📋 GPay number copy aagiduchu!')),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, color: Color(0xFF059669), size: 20),
                          tooltip: 'Copy GPay Number',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    label: Text(
                      order.vendorQrCodeUrl != null && order.vendorQrCodeUrl!.isNotEmpty
                          ? lang.text(en: 'RE-TAKE QR', ta: 'மீண்டும் QR எடுக்க', tanglish: 'RE-TAKE QR')
                          : lang.text(en: 'SNAP QR', ta: 'QR படம் எடுக்க', tanglish: 'SNAP QR'),
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                      if (image != null) {
                        final provider = Provider.of<DeliveryProvider>(context, listen: false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(lang.text(en: 'Uploading Shop QR Code...', ta: 'கடை QR கோட் பதிவேற்றப்படுகிறது...', tanglish: 'Shop QR Code upload aagudhu...'))),
                        );
                        final success = await provider.uploadVendorQrCode(order.id, image.path);
                        if (mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(lang.text(en: '🎉 Shop QR Code saved successfully!', ta: '🎉 கடை QR கோட் சேமிக்கப்பட்டது!', tanglish: '🎉 Shop QR Code save aagiduchu!')),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(lang.text(en: 'Failed to save QR code.', ta: 'QR கோட் சேமிக்க முடியவில்லை.', tanglish: 'QR code save panna mudila.')),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                    label: Text(
                      gpayNum.isNotEmpty
                          ? lang.text(en: 'EDIT GPAY', ta: 'GPAY மாற்ற', tanglish: 'EDIT GPAY')
                          : lang.text(en: 'ADD GPAY', ta: 'GPAY சேர்க்க', tanglish: 'ADD GPAY'),
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditGpayDialog(order);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showEditGpayDialog(DeliveryOrder order) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    final controller = TextEditingController(text: order.vendorGpayNumber ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          lang.text(en: 'Google Pay / PhonePe Number', ta: 'கூகுள் பே / போன்பே எண்', tanglish: 'Google Pay / PhonePe Number'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.text(
                en: 'Enter shop GPay number to save for this order:',
                ta: 'இந்த ஆர்டருக்கான கடை கூகுள் பே எண்ணை உள்ளிடவும்:',
                tanglish: 'Indha order-kaga shop GPay number enter pannavum:',
              ),
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: lang.text(
                  en: 'Enter 10-digit GPay number',
                  ta: '10 இலக்க கூகுள் பே எண்ணை உள்ளிடவும்',
                  tanglish: '10-digit GPay number type pannavum',
                ),
                prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF059669)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              lang.text(en: 'CANCEL', ta: 'ரத்து செய்', tanglish: 'CANCEL'),
              style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newNum = controller.text.trim();
              if (newNum.isEmpty) return;
              Navigator.pop(ctx);
              final provider = Provider.of<DeliveryProvider>(context, listen: false);
              final ok = await provider.updateVendorGpayNumber(order.id, newNum);
              if (mounted) {
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang.text(
                        en: '🎉 Google Pay number saved successfully!',
                        ta: '🎉 கூகுள் பே எண் வெற்றிகரமாக சேமிக்கப்பட்டது!',
                        tanglish: '🎉 Google Pay number save aagiduchu!',
                      )),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang.text(
                        en: 'Failed to save GPay number.',
                        ta: 'கூகுள் பே எண் சேமிக்க முடியவில்லை.',
                        tanglish: 'GPay number save panna mudila.',
                      )),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text(
              lang.text(en: 'SAVE GPAY NUMBER', ta: 'எண்ணை சேமிக்கவும்', tanglish: 'GPAY NUMBER SAVE PANNAVUM'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchOrderSwitcherBanner(
    BuildContext context,
    DeliveryOrder currentOrder,
    DeliveryProvider provider,
  ) {
    final lang = Provider.of<DeliveryLanguageProvider>(context);
    final otherOrders = provider.activeOrders.where((o) => o.id != currentOrder.id).toList();
    if (otherOrders.isEmpty) return const SizedBox.shrink();
    final otherOrder = otherOrders.first;

    final currentIndex = provider.activeOrders.indexWhere((o) => o.id == currentOrder.id);
    final orderNum = currentIndex != -1 ? currentIndex + 1 : 1;
    final totalOrders = provider.activeOrders.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x180F172A), blurRadius: 14, offset: Offset(0, 4)),
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
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms),
                  const SizedBox(width: 6),
                  Text(
                    lang.text(
                      en: 'BATCH TRIP • $totalOrders ORDERS ACTIVE',
                      ta: 'தொகுப்பு டெலிவரி • $totalOrders ஆர்டர்கள் செயலில் உள்ளன',
                      tanglish: 'BATCH TRIP • $totalOrders ORDERS ACTIVE',
                    ),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF34D399),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${lang.text(en: 'VIEWING', ta: 'தற்போது', tanglish: 'VIEWING')} $orderNum / $totalOrders',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFB923C),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${lang.text(en: 'OTHER ORDER', ta: 'அடுத்த ஆர்டர்', tanglish: 'OTHER ORDER')}: ${otherOrder.storeName.toUpperCase()}',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      otherOrder.customerAddress.isNotEmpty ? otherOrder.customerAddress : 'Customer Destination',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeliveryOrderDetailScreen(orderId: otherOrder.id),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang.text(en: 'SWITCH', ta: 'மாறு', tanglish: 'SWITCH'),
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.swap_horiz_rounded, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomOrderBanner(DeliveryOrder order) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7D2FE), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.stars_rounded, color: Color(0xFF4F46E5), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.text(
                    en: 'ANY SHOP ORDER',
                    ta: 'நேரடி கடை ஆர்டர்',
                    tanglish: 'ANY SHOP ORDER',
                  ),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF4338CA),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lang.text(
                    en: 'Ask shop for bill amount and send quote.',
                    ta: 'கடையிடம் பில் கேட்டு தொகையை Quote ஆக அனுப்பவும்.',
                    tanglish: 'Kadai-kitta bill kettu quote amount anupavum.',
                  ),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderContentCard(DeliveryOrder order) {
    final rawText = order.textContent ?? '';
    final parsedItems = _extractItemsFromText(rawText);
    final instructions = _extractInstructionsFromText(rawText);

    final title = order.orderType == 'Text'
        ? 'CUSTOMER SHOPPING LIST'
        : (order.orderType == 'Photo' ? 'PHOTO ORDER DETAILS' : 'ORDER ITEMS & QUANTITIES');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏷️ Header with Category Icon & Count Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF4F46E5), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${parsedItems.isNotEmpty ? parsedItems.length : 1} ITEMS',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 📋 Items List with Separated Item Name & Quantity
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (parsedItems.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      rawText.isNotEmpty ? rawText : 'No item details specified.',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E293B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ...parsedItems.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final item = entry.value;
                    final isLast = entry.key == parsedItems.length - 1;

                    return Container(
                      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          // Index Circle
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2F6),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$index',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Item Name (Left Column)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Item to pickup',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Quantity Badge (Right Column)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'QTY: ',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  item.qty,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                // 🔔 Special Delivery Instructions Callout
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.phone_callback_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DELIVERY PREFERENCE / INSTRUCTIONS',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFB45309),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                instructions,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF78350F),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_ParsedOrderItem> _extractItemsFromText(String rawText) {
    final List<_ParsedOrderItem> items = [];
    final lines = rawText.split('\n');

    for (var rawLine in lines) {
      String trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();

      // Skip instruction headers, dummy section headers, and "Items requested:"
      if (lower.startsWith('instruction') ||
          lower.startsWith('special instruction') ||
          lower.startsWith('delivery preference') ||
          lower.startsWith('note:') ||
          lower.startsWith('notes:') ||
          lower.startsWith('items requested') ||
          lower.startsWith('items to purchase') ||
          lower.startsWith('shopping list') ||
          lower == 'items:' ||
          lower == 'items' ||
          lower.startsWith('special request')) {
        continue;
      }

      if (lower.contains('call on arrival') ||
          lower.contains('ring bell') ||
          lower.contains('leave at door') ||
          lower.contains('leave at gate')) {
        continue;
      }

      // Strip leading numbering e.g. "1. " or "2) "
      final leadMatch = RegExp(r'^\d+[\.\)]\s*(.*)$').firstMatch(trimmed);
      if (leadMatch != null) trimmed = leadMatch.group(1)!.trim();

      // Match "Biriyani (22)" or "Biriyani [22]" with optional "qty/nos/pcs"
      final bracketMatch = RegExp(r'^(.*?)\s*[\(\[]\s*(\d+)(?:\s*(?:qty|nos|pcs|plates?|packet))?\s*[\)\]]$', caseSensitive: false).firstMatch(trimmed);
      if (bracketMatch != null) {
        final name = bracketMatch.group(1)!.trim();
        final qty = bracketMatch.group(2)!.trim();
        if (name.isNotEmpty) {
          items.add(_ParsedOrderItem(name: name, qty: qty));
          continue;
        }
      }

      // Match "22x Biriyani" or "22 x Biriyani"
      final prefixX = RegExp(r'^(\d+)\s*[xX]\s*(.*?)$').firstMatch(trimmed);
      if (prefixX != null) {
        final qty = prefixX.group(1)!.trim();
        final name = prefixX.group(2)!.trim();
        if (name.isNotEmpty) {
          items.add(_ParsedOrderItem(name: name, qty: qty));
          continue;
        }
      }

      // Match "Biriyani - 22" or "Biriyani: 22" or "Biriyani x 22"
      final suffixMatch = RegExp(r'^(.*?)\s*[\:\-xX]\s*(\d+)\s*$').firstMatch(trimmed);
      if (suffixMatch != null) {
        final name = suffixMatch.group(1)!.trim();
        final qty = suffixMatch.group(2)!.trim();
        if (name.isNotEmpty) {
          items.add(_ParsedOrderItem(name: name, qty: qty));
          continue;
        }
      }

      items.add(_ParsedOrderItem(name: trimmed, qty: '1'));
    }

    return items;
  }

  String _extractInstructionsFromText(String rawText) {
    final List<String> instructionLines = [];
    final lines = rawText.split('\n');
    bool inInstructionBlock = false;

    for (var rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();

      if (lower.startsWith('instruction') ||
          lower.startsWith('special instruction') ||
          lower.startsWith('delivery preference') ||
          lower.startsWith('note:') ||
          lower.startsWith('notes:') ||
          lower.startsWith('special request')) {
        inInstructionBlock = true;
        final cleaned = trimmed.replaceAll(RegExp(r'^(special\s+instructions?|instructions?|delivery\s+preferences?|notes?|special\s+requests?)\s*[:\-]?\s*', caseSensitive: false), '').trim();
        if (cleaned.isNotEmpty) instructionLines.add(cleaned);
        continue;
      }

      if (lower.contains('call on arrival') ||
          lower.contains('ring bell') ||
          lower.contains('leave at door') ||
          lower.contains('leave at gate')) {
        instructionLines.add(trimmed);
        continue;
      }

      if (inInstructionBlock) {
        instructionLines.add(trimmed);
      }
    }

    final cleanedList = instructionLines
        .map((s) => s.replaceAll(RegExp(r'^(delivery\s+preferences?|instructions?)\s*[:\-]?\s*', caseSensitive: false), '').trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return cleanedList.join(' • ');
  }

  Widget _buildBillUploadSection(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_rounded, color: Color(0xFF059669), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.text(
                          en: 'SHOP BILL RECEIPT',
                          ta: 'கடை பில் ரசீது',
                          tanglish: 'SHOP BILL RECEIPT',
                        ),
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        lang.text(
                          en: 'Attach shop bill photo',
                          ta: 'கடை பில் ரசீது படம்',
                          tanglish: 'Shop bill photo attach pannavum',
                        ),
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF059669),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                ),
                child: Text(
                  lang.text(
                    en: 'DELIVERY SYNC',
                    ta: 'நேரலை இணைப்பு',
                    tanglish: 'DELIVERY SYNC',
                  ),
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF059669),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (order.billPhotoPath != null && (order.billPhotoPath?.isNotEmpty ?? false))
            _buildBillPreview(order.billPhotoPath ?? '', lang)
          else
            _buildUploadPlaceholder(context, order, provider),
        ],
      ),
    );
  }

  Widget _buildBillPreview(String path, DeliveryLanguageProvider lang) {
    // Basic detection for network vs local path
    final isNetwork = path.startsWith('http') || path.startsWith('/public');
    final fullUrl = isNetwork && path.startsWith('/public') 
       ? '${DeliveryAuthService.baseUrl.split('/api').first}$path' 
       : path;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: isNetwork 
            ? Image.network(fullUrl, height: 200, width: double.infinity, fit: BoxFit.cover)
            : Image.file(File(path), height: 200, width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
              const SizedBox(width: 8),
              Text(
                lang.text(
                  en: 'BILL ATTACHED & SYNCED',
                  ta: 'பில் இணைக்கப்பட்டு புதுப்பிக்கப்பட்டது',
                  tanglish: 'BILL ATTACHED & SYNCED',
                ),
                style: GoogleFonts.outfit(
                  color: const Color(0xFF059669),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showImageSourceDialog(BuildContext context, Function(String path) onImageSelected) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(
              lang.text(
                en: 'SELECT IMAGE SOURCE',
                ta: 'பட மூலத்தைத் தேர்ந்தெடுக்கவும்',
                tanglish: 'IMAGE SOURCE SELECT PANNAVUM',
              ),
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B)),
            ),
            const SizedBox(height: 6),
            Text(
              lang.text(
                en: 'Take a photo of the shop bill receipt',
                ta: 'கடை பில் ரசீது படத்தை எடுக்கவும்',
                tanglish: 'Shop bill receipt photo edukkavum',
              ),
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            Builder(
              builder: (innerCtx) {
                final allowGallery = innerCtx.watch<DeliveryProvider>().allowGalleryUpload;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _pickerOption(Icons.camera_alt_rounded, lang.text(en: 'CAMERA', ta: 'கேமரா', tanglish: 'CAMERA'), () async {
                      Navigator.pop(ctx);
                      final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
                      if (photo != null) {
                        setState(() => _localPickedPath = photo.path);
                        onImageSelected(photo.path);
                      }
                    }),
                    if (allowGallery)
                      _pickerOption(Icons.photo_library_rounded, lang.text(en: 'GALLERY', ta: 'கேலரி', tanglish: 'GALLERY'), () async {
                        Navigator.pop(ctx);
                        final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
                        if (photo != null) {
                          setState(() => _localPickedPath = photo.path);
                          onImageSelected(photo.path);
                        }
                      }),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _pickerOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: const Color(0xFF059669), size: 32),
          ),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: const Color(0xFF1E1B4B))),
        ],
      ),
    );
  }

  Widget _buildUploadPlaceholder(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    if (_localPickedPath != null) {
      return _buildPreviewSection(context, order, provider);
    }

    return GestureDetector(
      onTap: () => _showImageSourceDialog(context, (path) {}),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF059669), size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              lang.text(
                en: 'SNAP SHOP PHYSICAL BILL',
                ta: 'கடை பில் படம் எடுக்கவும்',
                tanglish: 'SHOP BILL PHOTO EDUKKAVUM',
              ),
              style: GoogleFonts.outfit(
                color: const Color(0xFF059669),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lang.text(
                en: 'Take a photo of the bill before delivery',
                ta: 'டெலிவரி செய்வதற்கு முன் பில்லை போட்டோ எடுக்கவும்',
                tanglish: 'Delivery seivadharku mun bill-ai photo edukkavum',
              ),
              style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.text(
                  en: 'CONFIRM BILL PHOTO',
                  ta: 'பில் படம் உறுதிப்படுத்தவும்',
                  tanglish: 'CONFIRM BILL PHOTO',
                ),
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _localPickedPath != null
                ? Image.file(
                    File(_localPickedPath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showImageSourceDialog(context, (path) {}),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    lang.text(en: 'RE-TAKE', ta: 'மீண்டும் எடுக்க', tanglish: 'RE-TAKE'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade800,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_localPickedPath == null) return;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFF059669))),
                    );
                    final success = await provider.uploadBillPhoto(order.id, _localPickedPath!);
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (success) {
                        setState(() => _localPickedPath = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang.text(
                              en: '🎉 Bill photo uploaded successfully!',
                              ta: '🎉 பில் படம் வெற்றிகரமாக பதிவேற்றப்பட்டது!',
                              tanglish: '🎉 Bill photo upload aagiduchu!',
                            )),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang.text(
                              en: 'Failed to upload bill.',
                              ta: 'பில் பதிவேற்ற முடியவில்லை.',
                              tanglish: 'Bill upload panna mudila.',
                            )),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(
                    lang.text(en: 'UPLOAD', ta: 'பதிவேற்று', tanglish: 'UPLOAD'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── LIVE STATUS TRACKER ──────────────────────────────────────────────────
  Widget _buildLiveStatusTracker(DeliveryOrder order) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    // Map rawStatus to step index: 0=Assigned, 1=PickedUp, 2=OutForDelivery, 3=Delivered
    final rawStatus = order.rawStatus;

    final List<_StatusStep> steps;
    final int activeIdx;

    final bool isMapPinOrder = order.isCustomStore || order.orderType == 'MapPin' || order.orderType == 'map_pin';

    if (isMapPinOrder) {
      final isQuoteSent = order.subTotal > 0 || order.vendorPaymentDetailsUploadedByDriver;
      final isAdminPaid = order.vendorPaymentStatus == 'Completed' || order.vendorPaymentStatus == 'Paid';
      final isPickedUp = rawStatus == 'PickedUp' || rawStatus == 'Picked Up' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered';
      final isDelivered = rawStatus == 'Delivered';

      // 5-Step Professional Flow for Quote / Any Shop / Custom Store
      steps = [
        _StatusStep(
          lang.text(en: 'CONFIRMED', ta: 'உறுதியானது', tanglish: 'CONFIRMED'),
          Icons.assignment_turned_in_rounded,
          true,
        ),
        _StatusStep(
          lang.text(en: 'QUOTE SENT', ta: 'மதிப்பீடு அனுப்பப்பட்டது', tanglish: 'QUOTE SENT'),
          icons.Iconsax.magicpen_copy,
          isQuoteSent,
        ),
        _StatusStep(
          lang.text(en: 'ADMIN PAID', ta: 'அட்மின் செலுத்தினார்', tanglish: 'ADMIN PAID'),
          icons.Iconsax.bank_copy,
          isAdminPaid,
        ),
        _StatusStep(
          lang.text(en: 'PICKED UP', ta: 'எடுக்கப்பட்டது', tanglish: 'PICKED UP'),
          icons.Iconsax.box_tick_copy,
          isPickedUp,
        ),
        _StatusStep(
          lang.text(en: 'DELIVERED', ta: 'டெலிவரி முடிந்தது', tanglish: 'DELIVERED'),
          Icons.check_circle_rounded,
          isDelivered,
        ),
      ];

      activeIdx = isDelivered ? 4 
          : isPickedUp ? 3
          : isAdminPaid ? 3
          : isQuoteSent ? 2
          : 1; 
    } else {
      // Flow C: Standard Menu Order
      steps = [
        _StatusStep(
          lang.text(en: 'CONFIRMED', ta: 'உறுதியானது', tanglish: 'CONFIRMED'),
          Icons.assignment_turned_in_rounded,
          true,
        ),
        _StatusStep(
          lang.text(en: 'PREPARING', ta: 'தயாராகிறது', tanglish: 'PREPARING'),
          icons.Iconsax.box_copy,
          rawStatus == 'Preparing' || rawStatus == 'Ready' || rawStatus == 'HandedOver' || rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered',
        ),
        _StatusStep(
          lang.text(en: 'READY', ta: 'தயார்', tanglish: 'READY'),
          icons.Iconsax.box_tick_copy,
          rawStatus == 'Ready' || rawStatus == 'HandedOver' || rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered',
        ),
        _StatusStep(
          lang.text(en: 'ON THE WAY', ta: 'வழியில் உள்ளது', tanglish: 'ON THE WAY'),
          icons.Iconsax.routing_copy,
          rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered',
        ),
        _StatusStep(
          lang.text(en: 'DELIVERED', ta: 'டெலிவரி முடிந்தது', tanglish: 'DELIVERED'),
          Icons.check_circle_rounded,
          rawStatus == 'Delivered',
        ),
      ];

      activeIdx = rawStatus == 'Delivered' ? 4
          : (rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery') ? 3
          : (rawStatus == 'Ready' || rawStatus == 'HandedOver') ? 2
          : rawStatus == 'Preparing' ? 1
          : 0;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 16, offset: Offset(0, 4)),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.alt_route_rounded, color: Color(0xFFF97316), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lang.text(
                      en: 'ORDER PROGRESS',
                      ta: 'ஆர்டர் முன்னேற்றம்',
                      tanglish: 'ORDER PROGRESS',
                    ),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms),
                    const SizedBox(width: 6),
                    Text(
                      lang.text(
                        en: 'LIVE DISPATCH',
                        ta: 'நேரலை அனுப்புதல்',
                        tanglish: 'LIVE DISPATCH',
                      ),
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF047857),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                // connector line
                final lineIdx = i ~/ 2;
                final filled = steps[lineIdx + 1].isDone;
                return Expanded(
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: filled ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
              final stepIdx = i ~/ 2;
              final step = steps[stepIdx];
              final isActive = stepIdx == activeIdx;
              return _buildStatusNode(step.label, step.isDone, step.icon, isActive: isActive);
            }),
          ),
          const SizedBox(height: 16),
          // Current status text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF97316)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusDescription(order, rawStatus, lang),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E293B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDescription(DeliveryOrder order, String rawStatus, DeliveryLanguageProvider lang) {
    final bool isMapPinOrder = order.isCustomStore || order.orderType == 'MapPin' || order.orderType == 'map_pin';
    if (isMapPinOrder) {
      if (rawStatus == 'Delivered') {
        return lang.text(en: '🏁 Successfully delivered to customer!', ta: '🏁 வாடிக்கையாளரிடம் வெற்றிகரமாக டெலிவரி செய்யப்பட்டது!', tanglish: '🏁 Successfully customer-kitta deliver aagiruchu!');
      }
      if (rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery') {
        return lang.text(en: '🚀 Order picked up — heading to customer', ta: '🚀 ஆர்டர் எடுக்கப்பட்டது — வாடிக்கையாளரை நோக்கி செல்கிறது', tanglish: '🚀 Order pick panniyaachu — customer-kitta pogudhu');
      }
      if (order.vendorPaymentStatus == 'Completed' || order.vendorPaymentStatus == 'Paid') {
        return lang.text(en: '✅ Admin transferred payment to Shop! Collect items now.', ta: '✅ அட்மின் கடைக்கு பணம் செலுத்திவிட்டார்! பொருட்களை இப்போது வாங்கவும்.', tanglish: '✅ Admin kadai-ku payment anupitaaru! Items vaangikonga.');
      }
      if (order.subTotal > 0 || order.vendorPaymentDetailsUploadedByDriver) {
        return lang.text(en: '⏳ Quote submitted! Waiting for Admin payment transfer to shop.', ta: '⏳ மதிப்பீடு அனுப்பப்பட்டது! அட்மின் கடைக்கு பணம் செலுத்தும் வரை காத்திருக்கவும்.', tanglish: '⏳ Quote submit aagiruchu! Admin payment panra varaikum wait pannavum.');
      }
      return lang.text(en: '📝 Please enter Shop Bill & Payment details above', ta: '📝 கடை பில் மற்றும் கட்டண விவரங்களை உள்ளிடவும்', tanglish: '📝 Shop Bill matrum Payment details enter pannavum');
    }

    switch (rawStatus.toLowerCase()) {
      case 'accepted':
      case 'assigned': 
        return (order.orderType != 'Cart' && order.subTotal == 0)
            ? lang.text(en: '⏳ Waiting for shop to prepare quote & order', ta: '⏳ கடை மதிப்பீடு மற்றும் ஆர்டரை தயாரிக்கும் வரை காத்திருக்கவும்', tanglish: '⏳ Kadai quote prepare panra varaikum wait pannavum')
            : lang.text(en: '✅ Order confirmed by vendor', ta: '✅ ஆர்டர் கடையால் உறுதிப்படுத்தப்பட்டது', tanglish: '✅ Vendor order confirm pannitaaru');
      case 'preparing':
        return lang.text(en: '👨‍🍳 Vendor started preparing your order', ta: '👨‍🍳 கடைக்காரர் தயாரிப்பைத் தொடங்கிவிட்டார்', tanglish: '👨‍🍳 Kadai order ready panna start pannitaaru');
      case 'ready':
      case 'ready for handover':
        return lang.text(en: '📦 Order is ready for handover!', ta: '📦 ஆர்டர் ஒப்படைக்க தயாராக உள்ளது!', tanglish: '📦 Order ready-ah irukku!');
      case 'pickedup':
      case 'picked up':
        return lang.text(en: '🚀 Order picked up — heading to customer', ta: '🚀 ஆர்டர் எடுக்கப்பட்டது — வாடிக்கையாளரை நோக்கி செல்கிறது', tanglish: '🚀 Order pick panniyaachu — customer-kitta pogudhu');
      case 'outfordelivery':
        return lang.text(en: '📍 Almost there! Out for delivery', ta: '📍 கிட்டத்தட்ட வந்தாச்சு! டெலிவரிக்கு புறப்பட்டாச்சு', tanglish: '📍 Almost anga vandhaachu! Out for delivery');
      case 'delivered':
        return lang.text(en: '🏁 Successfully delivered!', ta: '🏁 வெற்றிகரமாக டெலிவரி செய்யப்பட்டது!', tanglish: '🏁 Delivery successfully mudinjadhu!');
      default:
        return rawStatus;
    }
  }

  Widget _buildStatusNode(String label, bool isDone, IconData icon, {bool isActive = false}) {
    Color bg = isDone
        ? const Color(0xFF10B981)
        : (isActive ? const Color(0xFFF97316) : Colors.white);
    Color borderColor = isDone
        ? const Color(0xFF10B981)
        : (isActive ? const Color(0xFFF97316) : const Color(0xFFCBD5E1));
    Color iconColor = isDone || isActive ? Colors.white : const Color(0xFF94A3B8);
    Color textColor = isDone
        ? const Color(0xFF047857)
        : (isActive ? const Color(0xFFEA580C) : const Color(0xFF64748B));

    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: isActive ? 2.5 : 1.5),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ]
                : (isDone
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null),
          ),
          child: Icon(
            isDone ? Icons.check_rounded : icon,
            color: iconColor,
            size: 17,
          ),
        ).animate(target: isActive ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08)),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: textColor,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRouteStop(
    IconData icon,
    String title,
    String name,
    Color color, {
    String? subtext,
    bool hasActions = false,
    VoidCallback? onNavigate,
    VoidCallback? onCall,
  }) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    final bool isPickup = title.contains('STORE') || title.contains('PICKUP');
    final Color badgeBg = isPickup ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5);
    final Color badgeBorder = isPickup ? const Color(0xFFFFEDD5) : const Color(0xFFA7F3D0);
    final Color accentColor = isPickup ? const Color(0xFFEA580C) : const Color(0xFF059669);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 16, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x020F172A), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeBorder),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subtext != null && subtext.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      subtext,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF059669)),
                      label: Text(
                        lang.text(en: 'CALL', ta: 'அழைக்க', tanglish: 'CALL'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF059669),
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFECFDF5),
                        side: const BorderSide(color: Color(0xFFA7F3D0)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (onCall != null && onNavigate != null) const SizedBox(width: 10),
                if (onNavigate != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onNavigate,
                      icon: const Icon(Icons.navigation_rounded, size: 16, color: Colors.white),
                      label: Text(
                        lang.text(en: 'MAP NAV', ta: 'வழிசெலுத்தல்', tanglish: 'MAP NAV'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── BOTTOM ACTION BUTTON ─────────────────────────────────────────────────
  Widget _buildActionButton(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    String label = '';
    String subtitle = '';
    DeliveryStatus? next;
    bool isBlocked = false;

    if (order.status == DeliveryStatus.allocated || order.status == DeliveryStatus.pickingUp) {
      final bool isMapPinOrder = order.isCustomStore || order.orderType == 'MapPin' || order.orderType == 'map_pin';
      final bool quoteDone = order.subTotal > 0 || order.vendorPaymentDetailsUploadedByDriver;
      final bool needsQuote = isMapPinOrder && !quoteDone;
      
      if (needsQuote) {
        return const SizedBox.shrink(); // Quote form is inline directly on screen!
      } else {
        final bool isPaidByAdmin = order.vendorPaymentStatus == 'Completed' || order.vendorPaymentStatus == 'Paid';
        
        if (isMapPinOrder) {
          if (isPaidByAdmin) {
            label = lang.text(en: '📦 COLLECT ITEMS & PICK UP', ta: '📦 பொருட்களைப் பெற்றுக்கொள்', tanglish: '📦 COLLECT ITEMS & PICK UP');
            subtitle = lang.text(en: 'Collect items from the shop', ta: 'பொருட்களை கடையில் பெற்றுக்கொள்ளவும்', tanglish: 'Items-ah kadaila vaangikavum');
            next = DeliveryStatus.pickedUp;
          } else {
            label = lang.text(en: '⏳ WAITING FOR ADMIN PAYMENT', ta: '⏳ அட்மின் பணத்திற்கு காத்திருக்கிறது', tanglish: '⏳ WAITING FOR ADMIN PAYMENT');
            subtitle = lang.text(en: 'Wait until admin transfers payment', ta: 'அட்மின் கடைக்கு பணம் செலுத்தும் வரை காத்திருக்கவும்', tanglish: 'Admin payment panra varaikum wait pannavum');
            next = DeliveryStatus.pickedUp;
          }
        } else {
          final isReady = order.rawStatus == 'Ready' || order.rawStatus == 'HandedOver' || order.rawStatus == 'PickedUp' || order.rawStatus == 'Picked Up';
          label = isReady
              ? lang.text(en: '📦 COLLECT ITEMS & PICK UP', ta: '📦 பொருட்களைப் பெற்றுக்கொள்', tanglish: '📦 COLLECT ITEMS & PICK UP')
              : lang.text(en: '⏳ WAITING FOR VENDOR PREPARATION', ta: '⏳ கடை தயாரிக்கும் வரை காத்திருக்கவும்', tanglish: '⏳ WAITING FOR VENDOR PREPARATION');
          subtitle = isReady
              ? lang.text(en: 'Collect items from the shop', ta: 'பொருட்களை கடையில் பெற்றுக்கொள்ளவும்', tanglish: 'Items-ah kadaila vaangikavum')
              : lang.text(en: 'Wait for shop to prepare items', ta: 'கடை தயாரிக்கும் வரை காத்திருக்கவும்', tanglish: 'Kadai ready panra varaikum wait pannavum');
          next = isReady ? DeliveryStatus.pickedUp : null;
        }
      }
    } else if (order.status == DeliveryStatus.pickedUp || order.status == DeliveryStatus.onTheWay) {
      label = lang.text(en: '🏁 REACHED & DELIVERED', ta: '🏁 டெலிவரி முடிந்தது', tanglish: '🏁 REACHED & DELIVERED');
      subtitle = lang.text(en: 'Delivered successfully to customer', ta: 'வாடிக்கையாளரிடம் வெற்றிகரமாக டெலிவரி செய்', tanglish: 'Customer-kitta deliver seivom');
      next = DeliveryStatus.delivered;
      
      // BLOCK DELIVERY IF BILL IS NOT UPLOADED for Map Pin / Custom orders
      final bool isMapPinOrder = order.isCustomStore || order.orderType == 'MapPin' || order.orderType == 'map_pin';
      if (isMapPinOrder && order.billPhotoPath == null) {
        isBlocked = true;
      }
    }

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: GestureDetector(
        onTap: isBlocked ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.text(
                en: 'Please upload bill photo before delivering',
                ta: 'டெலிவரி செய்வதற்கு முன் பில் ரசீது படத்தை பதிவேற்றவும்',
                tanglish: 'Delivery panradhuku munnadi bill photo upload pannavum',
              )),
              backgroundColor: Colors.redAccent,
            ),
          );
          _showImageSourceDialog(context, (path) {});
        } : ((label == 'SEND SHOP BILL QUOTE & QR' || label == 'SEND PRICE QUOTE') ? () => _showQuoteDialog(context, order, provider) : (next == null ? null : () async {
          final targetNext = next;
          if (targetNext == null) return;

          if (targetNext == DeliveryStatus.delivered) {
            final bool isCod = order.paymentMethod == 'COD';
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Row(
                  children: [
                    Icon(
                      isCod ? Icons.payments_rounded : Icons.check_circle_rounded,
                      color: isCod ? Colors.orange : const Color(0xFF059669),
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isCod
                            ? lang.text(en: 'Cash Collected? (COD)', ta: 'பணம் பெறப்பட்டதா?', tanglish: 'Cash Vaangiyaacha? (COD)')
                            : lang.text(en: 'Confirm Order Delivery?', ta: 'டெலிவரியை உறுதிப்படுத்துக?', tanglish: 'Order Delivery Confirm Pannava?'),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCod) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.text(
                                en: 'Have you collected cash from customer?',
                                ta: 'வாடிக்கையாளரிடம் பணத்தை வாங்கினீர்களா?',
                                tanglish: 'Customer kitta cash vaangiteengala?',
                              ),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.orange.shade900, fontSize: 13),
                            ),
                            if (order.totalAmount > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${lang.text(en: 'COLLECT CASH', ta: 'வாங்க வேண்டிய பணம்', tanglish: 'COLLECT CASH')}: ₹${order.totalAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppTheme.darkText, fontSize: 16),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Text(
                        lang.text(
                          en: 'Mark this order as successfully delivered to customer?',
                          ta: 'இந்த ஆர்டர் வாடிக்கையாளரிடம் ஒப்படைக்கப்பட்டதாகக் குறிக்கவா?',
                          tanglish: 'Indha order customer-kitta delivered nu mark pannava?',
                        ),
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      lang.text(en: 'CANCEL', ta: 'ரத்து செய்', tanglish: 'CANCEL'),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCod ? Colors.orange.shade700 : const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      isCod
                          ? lang.text(en: 'YES, CASH RECEIVED ✓', ta: 'ஆம், பணம் பெறப்பட்டது ✓', tanglish: 'AAMA, CASH VAANGIYAASU ✓')
                          : lang.text(en: 'DELIVERED ✓', ta: 'டெலிவரி முடிந்தது ✓', tanglish: 'DELIVERED ✓'),
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              VoiceDispatchService.missionCompleted();
              await provider.updateOrderStatus(order.id, targetNext);
              if (context.mounted) Navigator.pop(context);
            }
          } else {
            await provider.updateOrderStatus(order.id, targetNext);
            // Screen seamlessly transitions to PickedUp/OnTheWay in-place via provider sync!
          }
        })),
        child: Container(
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: isBlocked
                ? null
                : LinearGradient(
                    colors: (next == DeliveryStatus.delivered)
                        ? const [Color(0xFF10B981), Color(0xFF059669)]
                        : const [Color(0xFFF97316), Color(0xFFEA580C)],
                  ),
            color: isBlocked ? Colors.grey.shade200 : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isBlocked ? [] : [
              BoxShadow(
                color: (next == DeliveryStatus.delivered ? const Color(0xFF10B981) : const Color(0xFFF97316)).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            border: isBlocked ? Border.all(color: Colors.grey.shade300, width: 1) : null,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label, 
                      style: GoogleFonts.outfit(
                        color: isBlocked ? Colors.grey.shade600 : Colors.white, 
                        fontSize: 14, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (isBlocked) ...[
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        lang.text(
                          en: 'UPLOAD BILL TO PROCEED',
                          ta: 'தொடர பில் ரசீது பதிவேற்றவும்',
                          tanglish: 'UPLOAD BILL TO PROCEED',
                        ),
                        style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                  ] else if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }

  void _showQuoteDialog(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    final TextEditingController amountCtrl = TextEditingController(
      text: (order.subTotal > 0 && order.vendorPaymentDetailsUploadedByDriver)
          ? order.subTotal.toStringAsFixed(0)
          : '',
    );
    final TextEditingController gpayCtrl = TextEditingController(text: order.vendorGpayNumber ?? '');
    final TextEditingController gpayNameCtrl = TextEditingController(text: order.vendorGpayName ?? '');
    String? localQrPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.text(
                              en: 'Submit Shop Quote & QR',
                              ta: 'கடை பில் மற்றும் QR அனுப்பவும்',
                              tanglish: 'Shop Bill & QR Anuppunga',
                            ),
                            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.darkText),
                          ),
                          Text(
                            lang.text(
                              en: 'Enter bill amount and attach shop payment details',
                              ta: 'பில் தொகை மற்றும் கட்டண விவரங்களை உள்ளிடவும்',
                              tanglish: 'Bill amount mattrum payment details podavum',
                            ),
                            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.lightText, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. BILL AMOUNT (MANDATORY)
                Text(
                  lang.text(
                    en: '1. ORIGINAL BILL AMOUNT *',
                    ta: '1. பொருட்களின் மொத்த விலை *',
                    tanglish: '1. SHOP BILL AMOUNT *',
                  ),
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5)),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5)),
                    hintText: '0.00',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. SHOP QR CODE (CAMERA / GALLERY)
                Text(
                  lang.text(
                    en: '2. SHOP QR CODE',
                    ta: '2. கடை கூகுள் பே QR கோட்',
                    tanglish: '2. KADAI GPAY QR CODE',
                  ),
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                if (localQrPath != null) ...[
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(File(localQrPath!), height: 130, width: double.infinity, fit: BoxFit.cover),
                      ),
                      GestureDetector(
                        onTap: () => setDialogState(() => localQrPath = null),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: localQrPath != null ? const Color(0xFF10B981) : const Color(0xFF4F46E5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text(localQrPath != null ? 'Retake QR Photo' : 'Snap Shop QR', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800)),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                          if (img != null) {
                            setDialogState(() => localQrPath = img.path);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 18, color: Colors.grey),
                        label: Text('Gallery', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade700)),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (img != null) {
                            setDialogState(() => localQrPath = img.path);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. SHOP GPAY / UPI NUMBER (OPTIONAL)
                Text(
                  lang.text(
                    en: '3. SHOP GPAY / PHONE NUMBER (Optional)',
                    ta: '3. கடை கூகுள் பே / தொலைபேசி எண் (விருப்பத்தேர்வு)',
                    tanglish: '3. SHOP GPAY / PHONE NUMBER (Optional)',
                  ),
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: gpayCtrl,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'e.g. 9876543210',
                    prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF059669), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF059669), width: 2)),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. GPAY ACCOUNT / SHOP NAME (OPTIONAL)
                Text(
                  lang.text(
                    en: '4. SHOP GPAY ACCOUNT NAME (Optional)',
                    ta: '4. கணக்கு பெயர் (விருப்பத்தேர்வு)',
                    tanglish: '4. SHOP GPAY ACCOUNT NAME (Optional)',
                  ),
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: gpayNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'e.g. Raja Stores / Selvam',
                    prefixIcon: const Icon(Icons.person_pin_rounded, color: Color(0xFF4F46E5), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                  ),
                ),
                const SizedBox(height: 24),

                // SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang.text(
                              en: 'Please enter a valid bill amount',
                              ta: 'சரியான பில் தொகையை உள்ளிடவும்',
                              tanglish: 'Sariyana bill amount-ah enter pannavum',
                            )),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (confirmCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.verified_rounded, color: Color(0xFF4F46E5), size: 22),
                              ),
                              const SizedBox(width: 10),
                               Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.text(en: 'CONFIRM DETAILS', ta: 'விவரங்களை உறுதிப்படுத்துக', tanglish: 'CONFIRM DETAILS'),
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      lang.text(en: 'Verify bill details', ta: 'விவரங்களை சரிபார்க்கவும்', tanglish: 'Details verify pannavum'),
                                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF4F46E5), fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  final double deliveryFee = order.deliveryFee > 0 ? order.deliveryFee : 30.0;
                                  final double customerTotal = amount + deliveryFee;
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: const Color(0xFFC7D2FE)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              lang.text(en: '🛍️ Shop Bill:', ta: '🛍️ பொருட்கள் விலை:', tanglish: '🛍️ Kadai Bill:'),
                                              style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)),
                                            ),
                                            Text('₹${amount.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF312E81))),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              lang.text(en: '🛵 Delivery Fee:', ta: '🛵 டெலிவரி கட்டணம்:', tanglish: '🛵 Delivery Charge:'),
                                              style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)),
                                            ),
                                            Text('+₹${deliveryFee.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF059669))),
                                          ],
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                          child: Divider(color: Color(0xFFC7D2FE), height: 1),
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  lang.text(en: 'TOTAL TO CUSTOMER', ta: 'வாடிக்கையாளர் தொகை', tanglish: 'TOTAL TO CUSTOMER'),
                                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF4338CA), letterSpacing: 0.5),
                                                ),
                                                Text(
                                                  lang.text(en: 'Amount to be paid', ta: 'செலுத்த வேண்டிய தொகை', tanglish: 'Pay panna vendiya amount'),
                                                  style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                                                ),
                                              ],
                                            ),
                                            Text('₹${customerTotal.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    localQrPath != null ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                    color: localQrPath != null ? const Color(0xFF059669) : Colors.grey.shade500,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    localQrPath != null ? 'Shop QR Code Attached ✓' : 'No QR Code attached',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: localQrPath != null ? const Color(0xFF059669) : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              if (localQrPath != null) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(File(localQrPath!), height: 80, width: double.infinity, fit: BoxFit.cover),
                                ),
                              ],
                              if (gpayCtrl.text.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_android_rounded, color: Color(0xFF059669), size: 18),
                                    const SizedBox(width: 8),
                                    Text('GPay Number: ${gpayCtrl.text.trim()}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                              ],
                              if (gpayNameCtrl.text.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.badge_rounded, color: Color(0xFF4F46E5), size: 18),
                                    const SizedBox(width: 8),
                                    Text('Account Name: ${gpayNameCtrl.text.trim()}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5))),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(confirmCtx, false),
                              child: Text(
                                lang.text(en: 'EDIT', ta: 'மாற்று', tanglish: 'MAATRU'),
                                style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.w800),
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onPressed: () => Navigator.pop(confirmCtx, true),
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: Text('CONFIRM & SEND (₹${(amount + (order.deliveryFee > 0 ? order.deliveryFee : 30.0)).toStringAsFixed(0)})', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;

                      Navigator.pop(ctx);
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
                      );

                      final double deliveryFee = order.deliveryFee > 0 ? order.deliveryFee : 30.0;
                      final double customerTotal = amount + deliveryFee;

                      final success = await provider.sendQuote(
                        order.id,
                        amount,
                        deliveryFee: deliveryFee,
                        customerTotal: customerTotal,
                        qrImagePath: localQrPath,
                        gpayNumber: gpayCtrl.text.trim(),
                        gpayName: gpayNameCtrl.text.trim(),
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Quote & Shop QR sent! Waiting for Customer & Admin payment.'),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to send quote.'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
                    child: Text('SUBMIT QUOTE & SHOP PAYMENT DETAILS', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeliverySupportBottomSheet(BuildContext context, DeliveryOrder order) {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Text(
                lang.text(en: 'Order Support', ta: 'ஆர்டர் உதவி மையம்', tanglish: 'Order Support'),
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                lang.text(
                  en: 'How can we help you with Order #${order.displayId}?',
                  ta: 'ஆர்டர் #${order.displayId} தொடர்பாக உங்களுக்கு எவ்வாறு உதவலாம்?',
                  tanglish: 'Order #${order.displayId}-ku enna help venum?',
                ),
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _supportOptionTile(
                      icon: Icons.smart_toy_rounded,
                      color: const Color(0xFF4F46E5),
                      title: lang.text(
                        en: 'AI Instant Assistant',
                        ta: 'உடனடி உதவி பாட்',
                        tanglish: 'AI Instant Assistant',
                      ),
                      subtitle: lang.text(
                        en: 'Fast AI assistant for order resolution',
                        ta: 'விரைவான தீர்வுக்கான உடனடி பாட்',
                        tanglish: 'Fast AI assistant for order resolution',
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RiderChatbotScreen(
                              relatedOrderId: order.displayId,
                              initialQuery: 'Help regarding Order #${order.displayId}',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _supportOptionTile(
                      icon: Icons.mark_chat_unread_rounded,
                      color: const Color(0xFF6366F1),
                      title: lang.text(
                        en: 'Raise Support Ticket',
                        ta: 'புகார் பதிவு செய்ய',
                        tanglish: 'Support Ticket Poda',
                      ),
                      subtitle: lang.text(
                        en: 'Report vendor delay, customer issue, or vehicle problem',
                        ta: 'கடை தாமதம், வாடிக்கையாளர் அல்லது வாகன சிக்கலைத் தெரிவிக்கவும்',
                        tanglish: 'Delay, customer issue, vandi problem report pannavum',
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showRaiseTicketDialog(context, order);
                      },
                    ),
                    const SizedBox(height: 10),
                    _supportOptionTile(
                      icon: Icons.phone_in_talk_rounded,
                      color: const Color(0xFF10B981),
                      title: lang.text(
                        en: 'Call Delivery Support',
                        ta: 'உதவி மையத்தை அழைக்க',
                        tanglish: 'Delivery Support-ku Call Panna',
                      ),
                      subtitle: lang.text(
                        en: 'Toll-free 1800-123-4567 (24x7 Assistance)',
                        ta: 'கட்டணமில்லா எண் 1800-123-4567 (24x7 உதவி)',
                        tanglish: 'Toll-free 1800-123-4567 (24x7 Assistance)',
                      ),
                      onTap: () async {
                        final uri = Uri.parse('tel:18001234567');
                        if (await canLaunchUrl(uri)) launchUrl(uri);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _supportOptionTile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  void _showRaiseTicketDialog(BuildContext context, DeliveryOrder order) {
    int selectedIssue = 0;
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    final isTa = lang.isTamil;
    final isTg = lang.isTanglish;

    final issueKeys = [
      'Vendor Delay / Food Not Ready',
      'Customer Unreachable',
      'Vehicle Issue / Puncture',
      'Payout / Earnings Issue',
      'Other Custom Query',
    ];

    final List<String> issues;
    if (isTa) {
      issues = [
        '👨‍🍳 கடை தாமதம்',
        '👤 வாடிக்கையாளரை தொடர்பு கொள்ள முடியவில்லை',
        '🛵 வாகனப் பழுது',
        '💰 வருமானம் அல்லது கட்டண சிக்கல்',
        '📝 மற்ற காரணங்கள்',
      ];
    } else if (isTg) {
      issues = [
        '👨‍🍳 Vendor Delay',
        '👤 Customer Phone Edukala',
        '🛵 Vandi Problem',
        '💰 Earnings Settlement Issue',
        '📝 Matra Kaaranangal',
      ];
    } else {
      issues = [
        '👨‍🍳 Vendor Delay',
        '👤 Customer Unreachable',
        '🛵 Vehicle Breakdown',
        '💰 Earnings Issue',
        '📝 Other Query',
      ];
    }

    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang.text(en: 'Raise Ticket', ta: 'புகார் பதிவு செய்ய', tanglish: 'Raise Ticket'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17, color: const Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.text(en: 'Select Issue Topic:', ta: 'பிரச்சனை வகையைத் தேர்ந்தெடுக்கவும்:', tanglish: 'Problem Category Select Pannavum:'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  ...issues.asMap().entries.map((e) => RadioListTile<int>(
                    value: e.key,
                    groupValue: selectedIssue,
                    activeColor: const Color(0xFF4F46E5),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    onChanged: (val) => setState(() => selectedIssue = val ?? 0),
                  )),
                  const SizedBox(height: 12),
                  Text(
                    lang.text(en: 'Type your message:', ta: 'உங்கள் செய்தியை உள்ளிடவும்:', tanglish: 'Unga message type pannavum:'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5, color: const Color(0xFF4F46E5)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    style: GoogleFonts.outfit(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: lang.text(
                        en: 'Type your issue description here...',
                        ta: 'உங்கள் பிரச்சனையை இங்கே தட்டச்சு செய்யவும்...',
                        tanglish: 'Unga problem-ah inga type pannavum...',
                      ),
                      hintStyle: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  lang.text(en: 'Cancel', ta: 'ரத்து செய்', tanglish: 'Cancel'),
                  style: GoogleFonts.outfit(color: Colors.grey.shade600, fontWeight: FontWeight.w700),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final messageText = noteController.text.trim();
                  Navigator.pop(ctx);
                  
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (c) => const Center(child: CircularProgressIndicator()),
                  );

                  final driverId = await DeliveryAuthService.getDriverId();
                  
                  final ticketData = {
                    'userType': 'DeliveryPartner',
                    'userId': driverId.isNotEmpty ? driverId : 'unknown_id',
                    'userName': 'Delivery Partner',
                    'userPhone': 'Unknown',
                    'orderId': order.id,
                    'issueType': issueKeys[selectedIssue],
                    'message': messageText,
                  };
                  
                  final result = await DeliveryAuthService.createSupportTicket(ticketData);
                  if (!context.mounted) return;
                  Navigator.pop(context); // close loading
                  
                  final ticketId = (result != null && result['ticketId'] != null) 
                    ? result['ticketId'] 
                    : 'TK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                  
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
                      title: Text(
                        lang.text(en: 'Ticket Registered!', ta: 'புகார் பதிவு செய்யப்பட்டது!', tanglish: 'Ticket Registered!'),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            lang.text(
                              en: 'Ticket #$ticketId has been created successfully.',
                              ta: 'புகார் #$ticketId வெற்றிகரமாக பதிவு செய்யப்பட்டது.',
                              tanglish: 'Ticket #$ticketId success-ah create aagiduchu.',
                            ),
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if (messageText.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                              child: Text('"$messageText"', style: GoogleFonts.outfit(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            lang.text(
                              en: 'Our support team will review and respond shortly.',
                              ta: 'எங்கள் உதவி குழு விரைவில் பரிசீலித்து பதிலளிக்கும்.',
                              tanglish: 'Support team seekiram review panni respond pannuvanga.',
                            ),
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      actions: [
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(c),
                            child: Text(
                              lang.text(en: 'Done', ta: 'சரி', tanglish: 'Done'),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  lang.text(en: 'Send Message', ta: 'அனுப்பு', tanglish: 'Send Message'),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusStep {
  final String label;
  final IconData icon;
  final bool isDone;
  _StatusStep(this.label, this.icon, this.isDone);
}

class QuoteSubmitForm extends StatefulWidget {
  final DeliveryOrder order;
  final DeliveryProvider provider;
  
  const QuoteSubmitForm({super.key, required this.order, required this.provider});

  @override
  State<QuoteSubmitForm> createState() => _QuoteSubmitFormState();
}

class _QuoteSubmitFormState extends State<QuoteSubmitForm> {
  late TextEditingController amountCtrl;
  late TextEditingController gpayCtrl;
  late TextEditingController gpayNameCtrl;
  String? localQrPath;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    amountCtrl = TextEditingController(
      text: (widget.order.subTotal > 0 && widget.order.vendorPaymentDetailsUploadedByDriver)
          ? widget.order.subTotal.toStringAsFixed(0)
          : '',
    );
    amountCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    gpayCtrl = TextEditingController(text: widget.order.vendorGpayNumber ?? '');
    gpayNameCtrl = TextEditingController(text: widget.order.vendorGpayName ?? '');
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    gpayCtrl.dispose();
    gpayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool fromCamera) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        localQrPath = image.path;
      });
    }
  }

  void _submitQuote() async {
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
    final amtText = amountCtrl.text.trim();
    if (amtText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: 'Please enter bill amount',
              ta: 'தயவுசெய்து பில் தொகையை உள்ளிடவும்',
              tanglish: 'Bill amount enter pannavum',
            ),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final double? billAmt = double.tryParse(amtText);
    if (billAmt == null || billAmt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: 'Enter a valid bill amount',
              ta: 'சரியான பில் தொகையை உள்ளிடவும்',
              tanglish: 'Sariyana bill amount podavum',
            ),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final double deliveryFee = widget.order.deliveryFee > 0 ? widget.order.deliveryFee : 30.0;
    final double customerTotal = billAmt + deliveryFee;

    // Confirmation Dialog before sending to Admin & Customer
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified_rounded, color: Color(0xFF4F46E5), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.text(en: 'CONFIRM DETAILS', ta: 'விவரங்களை உறுதிப்படுத்துக', tanglish: 'CONFIRM DETAILS'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    lang.text(en: 'Verify bill details', ta: 'விவரங்களை சரிபார்க்கவும்', tanglish: 'Details verify pannavum'),
                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF4F46E5), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.text(en: '🛍️ Shop Bill:', ta: '🛍️ பொருட்கள் விலை:', tanglish: '🛍️ Kadai Bill:'),
                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)),
                      ),
                      Text('₹${billAmt.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF312E81))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.text(en: '🛵 Delivery Fee:', ta: '🛵 டெலிவரி கட்டணம்:', tanglish: '🛵 Delivery Charge:'),
                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)),
                      ),
                      Text('+₹${deliveryFee.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF059669))),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFFC7D2FE), height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.text(en: 'TOTAL TO CUSTOMER', ta: 'வாடிக்கையாளர் தொகை', tanglish: 'TOTAL TO CUSTOMER'),
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF4338CA), letterSpacing: 0.5),
                          ),
                          Text(
                            lang.text(en: 'Amount to be paid', ta: 'செலுத்த வேண்டிய தொகை', tanglish: 'Pay panna vendiya amount'),
                            style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                          ),
                        ],
                      ),
                      Text('₹${customerTotal.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  localQrPath != null ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: localQrPath != null ? const Color(0xFF059669) : Colors.grey.shade500,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  localQrPath != null
                      ? lang.text(en: 'Shop QR Code Attached ✓', ta: 'கடை QR கோட் இணைக்கப்பட்டது ✓', tanglish: 'Shop QR Attached ✓')
                      : lang.text(en: 'No QR Code attached', ta: 'QR கோட் இணைக்கப்படவில்லை', tanglish: 'QR Code attach pannala'),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: localQrPath != null ? const Color(0xFF059669) : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (localQrPath != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(localQrPath!), height: 80, width: double.infinity, fit: BoxFit.cover),
              ),
            ],
            if (gpayCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.phone_android_rounded, color: Color(0xFF059669), size: 18),
                  const SizedBox(width: 8),
                  Text('GPay Number: ${gpayCtrl.text.trim()}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                ],
              ),
            ],
            if (gpayNameCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.badge_rounded, color: Color(0xFF4F46E5), size: 18),
                  const SizedBox(width: 8),
                  Text('Account Name: ${gpayNameCtrl.text.trim()}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5))),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.text(en: 'EDIT', ta: 'மாற்று', tanglish: 'MAATRU'),
              style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.w800),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text('CONFIRM & SEND (₹${customerTotal.toStringAsFixed(0)})', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    
    setState(() => isSubmitting = true);

    try {
      final success = await widget.provider.sendQuote(
        widget.order.id,
        billAmt,
        deliveryFee: deliveryFee,
        customerTotal: customerTotal,
        gpayNumber: gpayCtrl.text.trim(),
        gpayName: gpayNameCtrl.text.trim(),
        qrImagePath: localQrPath,
      );

      if (success) {
        if (mounted) {
          final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lang.text(
                        en: '🎉 Bill & payment details submitted!',
                        ta: '🎉 பில் மற்றும் கட்டண விவரங்கள் அனுப்பப்பட்டது!',
                        tanglish: '🎉 Bill and payment details submit aagiduchu!',
                      ),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        if (mounted) {
          final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lang.text(
                  en: 'Failed to send. Please try again.',
                  ta: 'அனுப்புவதில் தோல்வி. மீண்டும் முயற்சிக்கவும்.',
                  tanglish: 'Send aagala. Marubadiyum try pannavum.',
                ),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<DeliveryLanguageProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP GRADIENT ACCENT HEADER ─────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 16 : 20,
                vertical: 16,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                lang.text(
                                  en: 'Submit Shop Bill & Details',
                                  ta: 'கடை பில் விவரங்களைச் சமர்ப்பிக்கவும்',
                                  tanglish: 'Shop Bill & Details Submit Pannavum',
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: isCompact ? 15 : 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1E1B4B),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'STEP 1',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lang.text(
                            en: 'Enter bill amount and payment info',
                            ta: 'கடையிடம் கேட்டு வாடிக்கையாளர் பில் தொகையை உள்ளிடவும்',
                            tanglish: 'Kadai bill amount enter pannavum',
                          ),
                          style: GoogleFonts.outfit(
                            fontSize: isCompact ? 10.5 : 11.5,
                            color: const Color(0xFF4F46E5),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── BODY CONTENT ───────────────────────────────────────────
            Padding(
              padding: EdgeInsets.all(isCompact ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. BILL AMOUNT (MANDATORY)
                  _buildSectionHeader(
                    stepNumber: '1',
                    title: lang.text(en: 'ORIGINAL BILL AMOUNT', ta: 'மொத்த பில் தொகை', tanglish: 'ORIGINAL BILL AMOUNT'),
                    subtitle: lang.text(en: 'Total item cost from shop', ta: 'பொருட்களின் மொத்த அசல் விலை', tanglish: 'Shop-oda total items cost'),
                    isRequired: true,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                    ),
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E1B4B),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Container(
                          width: 50,
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '₹',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ),
                        hintText: '0',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade400,
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: InputBorder.none,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. SHOP QR CODE (OPTIONAL)
                  _buildSectionHeader(
                    stepNumber: '2',
                    title: lang.text(en: 'SHOP QR CODE', ta: 'கடை QR கோட்', tanglish: 'SHOP QR CODE'),
                    subtitle: lang.text(en: 'Shop Google Pay QR photo', ta: 'கடை கூகுள் பே QR கோட் படம்', tanglish: 'Shop Google Pay QR photo'),
                    badgeText: lang.text(en: 'OPTIONAL', ta: 'விருப்பத்தேர்வு', tanglish: 'OPTIONAL'),
                    badgeColor: const Color(0xFF4F46E5),
                    badgeBgColor: const Color(0xFFEEF2FF),
                  ),
                  const SizedBox(height: 10),
                  if (localQrPath != null) ...[
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(
                            File(localQrPath!),
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 5),
                                    Text(
                                      lang.text(en: 'QR Attached', ta: 'QR இணைக்கப்பட்டது', tanglish: 'QR Attached'),
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => localQrPath = null),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(true),
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Color(0xFF4F46E5)),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              localQrPath != null
                                  ? lang.text(en: 'Retake QR', ta: 'மீண்டும் எடுக்க', tanglish: 'Retake QR')
                                  : lang.text(en: 'Snap Shop QR', ta: 'QR படம் எடுக்க', tanglish: 'Snap Shop QR'),
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF4F46E5),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: localQrPath != null ? const Color(0xFF4F46E5) : const Color(0xFF6366F1).withValues(alpha: 0.45),
                              width: localQrPath != null ? 1.8 : 1.2,
                            ),
                            backgroundColor: const Color(0xFFEEF2FF),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(false),
                          icon: Icon(Icons.photo_library_rounded, size: 18, color: Colors.grey.shade700),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              lang.text(en: 'Gallery', ta: 'கேலரி', tanglish: 'Gallery'),
                              style: GoogleFonts.outfit(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300, width: 1.2),
                            backgroundColor: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. GPAY OR PHONE NUMBER
                  _buildSectionHeader(
                    stepNumber: '3',
                    title: lang.text(en: 'SHOP GPAY / PHONE NUMBER', ta: 'கடை கூகுள் பே / தொலைபேசி எண்', tanglish: 'SHOP GPAY / PHONE NUMBER'),
                    subtitle: lang.text(en: 'Enter shop payment number', ta: 'கடைக்கான தொலைபேசி எண்', tanglish: 'Shop payment number enter pannavum'),
                    badgeText: lang.text(en: 'OPTIONAL', ta: 'விருப்பத்தேர்வு', tanglish: 'OPTIONAL'),
                    badgeColor: Colors.grey.shade700,
                    badgeBgColor: Colors.grey.shade100,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                    ),
                    child: TextField(
                      controller: gpayCtrl,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E1B4B),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF4F46E5), size: 22),
                        hintText: 'e.g. 98765 43210',
                        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 14),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        border: InputBorder.none,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. GPAY ACCOUNT / SHOP NAME
                  _buildSectionHeader(
                    stepNumber: '4',
                    title: lang.text(en: 'GPAY ACCOUNT / SHOP NAME', ta: 'கணக்கு பெயர் / கடை பெயர்', tanglish: 'GPAY ACCOUNT / SHOP NAME'),
                    subtitle: lang.text(en: 'Name linked to shop payment', ta: 'கூகுள் பே கணக்கு பெயர்', tanglish: 'Payment account name'),
                    badgeText: lang.text(en: 'OPTIONAL', ta: 'விருப்பத்தேர்வு', tanglish: 'OPTIONAL'),
                    badgeColor: Colors.grey.shade700,
                    badgeBgColor: Colors.grey.shade100,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                    ),
                    child: TextField(
                      controller: gpayNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E1B4B),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_pin_rounded, color: Color(0xFF4F46E5), size: 22),
                        hintText: 'e.g. Raja Stores / Selvam',
                        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 13),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        border: InputBorder.none,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // LIVE PRICE BREAKDOWN PREVIEW
                  Builder(
                    builder: (context) {
                      final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);
                      final double enteredBill = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      final double deliveryFee = widget.order.deliveryFee > 0 ? widget.order.deliveryFee : 30.0;
                      final double totalToCustomer = enteredBill > 0 ? (enteredBill + deliveryFee) : 0.0;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: enteredBill > 0 ? const Color(0xFF4F46E5).withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
                            width: enteredBill > 0 ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF475569)),
                                    const SizedBox(width: 6),
                                    Text(
                                      lang.text(en: 'Shop Bill:', ta: 'பொருட்கள் விலை:', tanglish: 'Kadai Bill:'),
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                                Text(enteredBill > 0 ? '₹${enteredBill.toStringAsFixed(0)}' : '₹0', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF059669)),
                                    const SizedBox(width: 6),
                                    Text(
                                      lang.text(en: 'Delivery Fee:', ta: 'டெலிவரி கட்டணம்:', tanglish: 'Delivery Charge:'),
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                                    ),
                                  ],
                                ),
                                Text('+₹${deliveryFee.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(color: Color(0xFFCBD5E1), height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.text(en: 'TOTAL TO CUSTOMER', ta: 'வாடிக்கையாளர் தொகை', tanglish: 'TOTAL TO CUSTOMER'),
                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B), letterSpacing: 0.5),
                                    ),
                                    Text(
                                      lang.text(en: 'Amount to be paid', ta: 'செலுத்த வேண்டிய தொகை', tanglish: 'Pay panna vendiya amount'),
                                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                                    ),
                                  ],
                                ),
                                Text(
                                  enteredBill > 0 ? '₹${totalToCustomer.toStringAsFixed(0)}' : '₹${deliveryFee.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // SUBMIT BUTTON (RESPONSIVE AUTO SCALED)
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: isSubmitting ? null : _submitQuote,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Builder(
                                    builder: (context) {
                                      final double enteredBill = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                                      final double deliveryFee = widget.order.deliveryFee > 0 ? widget.order.deliveryFee : 30.0;
                                      final double customerTotal = enteredBill + deliveryFee;
                                      return Text(
                                        enteredBill > 0
                                            ? '${lang.text(en: 'CONFIRM & SEND', ta: 'உறுதிசெய்து அனுப்பவும்', tanglish: 'CONFIRM & SEND')} (₹${customerTotal.toStringAsFixed(0)})'
                                            : lang.text(en: 'SUBMIT BILL & SHOP DETAILS', ta: 'பில் விவரங்களைச் சமர்ப்பிக்கவும்', tanglish: 'SUBMIT BILL & SHOP DETAILS'),
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      );
                                    },
                                  ),
                                ],
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
    );
  }

  Widget _buildSectionHeader({
    required String stepNumber,
    required String title,
    required String subtitle,
    bool isRequired = false,
    String? badgeText,
    Color? badgeColor,
    Color? badgeBgColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            stepNumber,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isRequired)
                    Text(
                      ' *',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.redAccent,
                      ),
                    ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: badgeBgColor ?? Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: badgeColor ?? Colors.grey.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParsedOrderItem {
  final String name;
  final String qty;
  const _ParsedOrderItem({required this.name, required this.qty});
}
