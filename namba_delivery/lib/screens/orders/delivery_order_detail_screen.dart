import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
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
import '../map/order_tracking_map_screen.dart';
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
        'https://routing.openstreetmap.de/routed-foot/route/v1/foot/$sLng,$sLat;$dLng,$dLat?overview=false&alternatives=true',
        'https://routing.openstreetmap.de/routed-bike/route/v1/biking/$sLng,$sLat;$dLng,$dLat?overview=false&alternatives=true',
        'https://router.project-osrm.org/route/v1/driving/$sLng,$sLat;$dLng,$dLat?overview=false&alternatives=true',
      ];

      final responses = await Future.wait(
        urls.map((url) => http.get(Uri.parse(url)).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 500)))
      );

      double? minKm;
      for (final res in responses) {
        if (res.statusCode == 200 && res.body.isNotEmpty) {
          try {
            final data = jsonDecode(res.body);
            final routes = data['routes'] as List? ?? [];
            for (var r in routes) {
              final d = (r['distance'] as num).toDouble() / 1000.0;
              if (minKm == null || d < minKm!) minKm = d;
            }
          } catch (_) {}
        }
      }

      double? dropKm = minKm;

      if (dropKm != null && dropKm > 0) {
        // Sanity cap: max 1.25x straight line
        final straightKm = Geolocator.distanceBetween(sLat, sLng, dLat, dLng) / 1000.0;
        if (dropKm > straightKm * 1.25) dropKm = straightKm * 1.15;

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
            final pos = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium).timeout(const Duration(seconds: 2));
            if (pos != null) {
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
                  'Syncing order details...',
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
                  'ஆர்டர் நீக்கப்பட்டது / மாற்றப்பட்டது',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order Unassigned or No Longer Available',
                  style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  'இந்த ஆர்டர் உங்களது பட்டியலிலிருந்து நீக்கப்பட்டுவிட்டது.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 12),
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
                      'RETURN TO DASHBOARD • டாஷ்போர்டு செல்க',
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
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 80),
          const SizedBox(height: 16),
          Text('Order Completed!', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go back')),
        ]),
      ),
    );
  }

  // ── INCOMING ORDER — Accept/Decline View ──────────────────────────────────
  Widget _buildIncomingOrderUI(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
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
                        Text('RESPOND QUICKLY', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 10, fontWeight: FontWeight.w900)),
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
                          'ORDER ID: ${order.displayId.isNotEmpty ? order.displayId : order.id.substring(0, 8).toUpperCase()}',
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
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('RIDER EARNINGS (ROUTE KM)', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                            Text('₹', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            _routeEarnings == null
                              ? Row(children: [
                                  const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B35))),
                                  const SizedBox(width: 8),
                                  Text('...', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 28, fontWeight: FontWeight.w900)),
                                ])
                              : Text(
                                  _routeEarnings!.toStringAsFixed(0),
                                  style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -1),
                                ),
                          ]),
                        ]),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: AppTheme.primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                            child: Column(children: [
                              const Icon(icons.Iconsax.routing_copy, color: AppTheme.primaryOrange, size: 20),
                              const SizedBox(height: 4),
                              _routeKm == null
                                ? Text('...', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w900, fontSize: 12))
                                : Text('${_routeKm!.toStringAsFixed(1)} KM', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w900, fontSize: 12)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(16)),
                            child: Column(children: [
                              const Icon(icons.Iconsax.box_1_copy, color: AppTheme.darkText, size: 20),
                              const SizedBox(height: 4),
                              Text('${order.items.length} ITEMS', style: GoogleFonts.outfit(color: AppTheme.darkText, fontWeight: FontWeight.w900, fontSize: 12)),
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
                              order.paymentMethod == 'COD' ? 'CASH ON DELIVERY' : 'ONLINE PAYMENT RECEIVED',
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

                      _buildRouteStop(icons.Iconsax.shop_copy, 'STORE', order.storeName.toUpperCase(), AppTheme.primaryOrange, subtext: order.storeAddress.isNotEmpty ? order.storeAddress : null),
                      const SizedBox(height: 12),
                      _buildRouteStop(icons.Iconsax.user_copy, 'DROP-OFF', order.customerName.toUpperCase(), AppTheme.accentGreen, subtext: order.customerAddress.isNotEmpty && order.customerAddress != 'Check app' ? order.customerAddress : null),
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
                              child: Center(child: Text('DECLINE', style: GoogleFonts.outfit(color: Colors.red.shade500, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1))),
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
                              child: Center(child: Text('ACCEPT ORDER', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1))),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ).animate().slideY(begin: 1.0, end: 0, curve: Curves.easeOutBack, duration: 600.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ACTIVE ORDER — Live Status + Action Buttons ───────────────────────────
  Widget _buildActiveOrderUI(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final orderLabel = order.displayId.isNotEmpty ? '#${order.displayId}' : '#${order.id.substring(order.id.length - 6).toUpperCase()}';

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('ORDER $orderLabel', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Special Notification for Any Shop Orders
            if (order.isCustomStore)
              _buildCustomOrderBanner(order),

            // Notification for Specific Vendor Text/Photo Orders
            if (!order.isCustomStore && order.orderType != 'Cart')
               Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.1)),
                ),
                child: Row(children: [
                  const Icon(icons.Iconsax.info_circle_copy, color: AppTheme.primaryOrange, size: 18),
                  const SizedBox(width: 12),
                  Text('CUSTOM ORDER (TEXT/PHOTO)', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                ]),
              ),

            // Live Status Tracker
            _buildLiveStatusTracker(order),
            const SizedBox(height: 32),

            // Text/Photo Content (if any)
            if (order.orderType != 'Cart' && order.textContent != null)
              _buildOrderContentCard(order),
            
            const SizedBox(height: 24),

            // ── PHASE-BASED CARD DISPLAY ───────────────────────────────
            // 1. BEFORE PICKUP: Show ONLY Vendor details (PICKUP FROM)
            if (!(order.status == DeliveryStatus.pickedUp || order.status == DeliveryStatus.onTheWay || order.status == DeliveryStatus.delivered || order.rawStatus == 'PickedUp' || order.rawStatus == 'Picked Up' || order.rawStatus == 'OutForDelivery')) ...[
              _buildRouteStop(
                icons.Iconsax.shop_copy, 
                'PICKUP FROM', 
                order.storeName, 
                AppTheme.primaryOrange, 
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
                'DELIVER TO (${order.formattedDistance})', 
                order.customerName, 
                AppTheme.accentGreen, 
                subtext: order.customerAddress.isNotEmpty && order.customerAddress != 'Check app' ? order.customerAddress : 'Customer Destination Set On Map', 
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
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
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
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5), size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ORDER SUMMARY',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E293B),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                              color: Color(0xFF059669),
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
                        'PAYMENT METHOD',
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
                          color: (order.paymentMethod == 'COD' ? Colors.orange : const Color(0xFF059669)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (order.paymentMethod == 'COD' ? Colors.orange : const Color(0xFF059669)).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          order.paymentMethod == 'COD' ? 'CASH ON DELIVERY' : 'ONLINE PAYMENT',
                          style: GoogleFonts.outfit(
                            color: order.paymentMethod == 'COD' ? Colors.orange.shade800 : const Color(0xFF059669),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── STORE / FOOD BILL (ONLY VENDOR BILL SHOWN TO RIDER) ──
                  Builder(builder: (context) {
                    final bool isCustom = order.isCustomStore || order.orderType == 'MapPin' || order.orderType == 'map_pin' || order.orderType == 'Photo' || order.orderType == 'Text';
                    final double deliveryFee = order.deliveryFee > 0
                        ? order.deliveryFee
                        : (isCustom && order.subTotal == 0 && order.totalAmount > 0 ? order.totalAmount : 0.0);
                    
                    final double shopBill = order.subTotal > 0
                        ? order.subTotal
                        : (order.vendorPaymentDetailsUploadedByDriver && order.totalAmount > deliveryFee ? order.totalAmount - deliveryFee : 0.0);

                    return Container(
                      padding: const EdgeInsets.all(14),
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
                                'STORE / FOOD BILL',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF4F46E5),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'கடை பில் தொகை',
                                style: GoogleFonts.outfit(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            shopBill > 0 ? '₹${shopBill.toStringAsFixed(0)}' : 'QUOTE PENDING',
                            style: GoogleFonts.outfit(
                              color: shopBill > 0 ? const Color(0xFF0F172A) : const Color(0xFFD97706),
                              fontSize: shopBill > 0 ? 22 : 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 24),



            // Bill Photo Section (Only for Text/Photo/Custom orders)
            if ((order.isCustomStore || order.orderType != 'Cart') && 
                (order.status == DeliveryStatus.pickedUp || order.status == DeliveryStatus.onTheWay))
              _buildBillUploadSection(context, order, provider),
            
            const SizedBox(height: 24),
            
            // Delivery Support / Raise Ticket
            InkWell(
              onTap: () => _showDeliverySupportBottomSheet(context, order),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.help_outline_rounded, color: AppTheme.primaryOrange, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Need help with this order?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.darkText)),
                          Text('Raise a ticket or report an issue', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _buildActionButton(context, order, provider),
    );
  }

  Widget _buildAdminPaymentSection(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    if (order.vendorPaymentStatus == 'Completed' || order.vendorPaymentStatus == 'Paid') {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.2))),
        child: Row(children: [
          const Icon(icons.Iconsax.tick_circle_copy, color: AppTheme.accentGreen, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('VENDOR PAID BY ADMIN', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('You can proceed with the delivery.', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
        ]),
      );
    }

    if (order.vendorPaymentDetailsUploadedByDriver) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
        child: Row(children: [
          const CircularProgressIndicator(color: Colors.orange, strokeWidth: 2),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('WAITING FOR ADMIN PAYMENT', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('Admin is processing the vendor payment.', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(icons.Iconsax.bank_copy, color: Color(0xFF6366F1), size: 20),
          const SizedBox(width: 10),
          Text('VENDOR PAYMENT', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
        const SizedBox(height: 16),
        Text('Customer paid online. Need Admin to pay the vendor directly?', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _showVendorPaymentDialog(context, order, provider),
          icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
          label: Text('REQUEST ADMIN PAYMENT', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
      ]),
    );
  }

  Widget _buildVendorQrCodeCard(DeliveryOrder order, DeliveryProvider provider) {
    final bool isCustom = order.isCustomStore || order.orderType == 'MapPin' || order.orderType == 'map_pin' || order.orderType == 'Photo' || order.orderType == 'Text';
    if (!isCustom) return const SizedBox.shrink();

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
                        'SHOP PAYMENT COMPLETED ✅',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF166534),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Admin has transferred payment to shop. Please collect items and proceed to delivery.',
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
                  label: Text('VIEW SHOP PAYMENT DETAILS', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900)),
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
      final quoteAmt = order.subTotal > 0 ? order.subTotal.toInt() : (order.totalAmount > 0 ? order.totalAmount.toInt() : 0);
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
                              'QUOTE SENT: ₹$quoteAmt',
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
                              'WAITING ADMIN',
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
                        'Admin & Customer notified. Waiting for Admin to transfer ₹$quoteAmt to shop.',
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
                      'VIEW SHOP QR / GPAY',
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
                    'EDIT',
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
              '📍 ${order.storeName} - Payment Details',
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
                              'Google Pay / PhonePe Number',
                              style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.lightText, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              gpayNum.isNotEmpty ? gpayNum : 'Not set yet',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: gpayNum.isNotEmpty ? const Color(0xFF059669) : Colors.grey,
                              ),
                            ),
                            if (order.vendorGpayName != null && order.vendorGpayName!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Account Name: ${order.vendorGpayName}',
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
                              const SnackBar(content: Text('📋 GPay number copied to clipboard!'), backgroundColor: Color(0xFF059669)),
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
                      order.vendorQrCodeUrl != null && order.vendorQrCodeUrl!.isNotEmpty ? 'RE-TAKE QR' : 'SNAP QR',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                      if (image != null) {
                        final provider = Provider.of<DeliveryProvider>(context, listen: false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading Shop QR Code...')));
                        final success = await provider.uploadVendorQrCode(order.id, image.path);
                        if (mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('🎉 Shop QR Code saved successfully!'), backgroundColor: Color(0xFF059669)),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to save QR code.'), backgroundColor: Colors.redAccent),
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
                      gpayNum.isNotEmpty ? 'EDIT GPAY' : 'ADD GPAY',
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
    final controller = TextEditingController(text: order.vendorGpayNumber ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Google Pay / PhonePe Number', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter shop GPay number to save for this order:', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Enter 10-digit GPay number',
                prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF059669)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w700)),
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
                    const SnackBar(content: Text('🎉 Google Pay number saved successfully!'), backgroundColor: Color(0xFF059669)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to save GPay number.'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: Text('SAVE GPAY NUMBER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVendorPaymentDialog(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final upiCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 32),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Request Vendor Payment', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Send the vendor\'s payment details to Admin.', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 14)),
          const SizedBox(height: 32),
          
          TextField(
            controller: upiCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Vendor UPI Mobile Number',
              hintText: 'e.g. 9876543210',
              prefixIcon: const Icon(Icons.phone_android_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('OR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () {
              _showImageSourceDialog(ctx, (path) {
                Navigator.pop(ctx);
                _submitPaymentRequest(context, order, provider, filePath: path);
              });
            },
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('SCAN OR UPLOAD QR CODE'),
          ),
          const SizedBox(height: 24),
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () {
              if (upiCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                _submitPaymentRequest(context, order, provider, upiNumber: upiCtrl.text);
              }
            },
            child: Text('SEND NUMBER TO ADMIN', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  void _submitPaymentRequest(BuildContext context, DeliveryOrder order, DeliveryProvider provider, {String? filePath, String? upiNumber}) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)));
    final success = await provider.submitVendorPaymentDetails(order.id, filePath: filePath, upiNumber: upiNumber);
    if (context.mounted) {
      Navigator.pop(context); // close loading
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit request to Admin.')));
      }
    }
  }

  Widget _buildCustomOrderBanner(DeliveryOrder order) {
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
                  'ANY SHOP / ASSISTANT ORDER',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF4338CA),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'கடையிடம் பில் கேட்டு தொகையை Quote ஆக அனுப்பவும்.',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF4F46E5), size: 18),
              const SizedBox(width: 8),
              Text(
                order.orderType == 'Text' ? 'CUSTOMER SHOPPING LIST' : 'PHOTO ORDER DETAILS',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF4F46E5),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              order.textContent ?? '',
              style: GoogleFonts.outfit(
                color: const Color(0xFF1E293B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillUploadSection(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
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
                        'SHOP BILL RECEIPT',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'கடை பில் ரசீது படம்',
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
                  'DELIVERY SYNC',
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
            _buildBillPreview(order.billPhotoPath ?? '')
          else
            _buildUploadPlaceholder(context, order, provider),
        ],
      ),
    );
  }

  Widget _buildBillPreview(String path) {
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
                'BILL ATTACHED & SYNCED',
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
            Text('SELECT IMAGE SOURCE', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B))),
            const SizedBox(height: 6),
            Text('கடை பில் ரசீது படத்தை எடுக்கவும்', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _pickerOption(Icons.camera_alt_rounded, 'CAMERA', () async {
                  Navigator.pop(ctx);
                  final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
                  if (photo != null) {
                    setState(() => _localPickedPath = photo.path);
                    onImageSelected(photo.path);
                  }
                }),
                _pickerOption(Icons.photo_library_rounded, 'GALLERY', () async {
                  Navigator.pop(ctx);
                  final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
                  if (photo != null) {
                    setState(() => _localPickedPath = photo.path);
                    onImageSelected(photo.path);
                  }
                }),
              ],
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
              'SNAP SHOP PHYSICAL BILL',
              style: GoogleFonts.outfit(
                color: const Color(0xFF059669),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'டெலிவரி செய்வதற்கு முன் பில்லை போட்டோ எடுக்கவும்',
              style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
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
                'CONFIRM BILL PHOTO',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B)),
              ),
              Text(
                'பில் படம் உறுதிப்படுத்தவும்',
                style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
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
                  label: Text('RE-TAKE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
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
                          const SnackBar(
                            content: Text('🎉 Bill photo uploaded successfully!'),
                            backgroundColor: Color(0xFF059669),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to upload bill.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text('UPLOAD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
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
    // Map rawStatus to step index: 0=Assigned, 1=PickedUp, 2=OutForDelivery, 3=Delivered
    final rawStatus = order.rawStatus;

    final List<_StatusStep> steps;
    final int activeIdx;

    final bool isQuoteOrder = order.isCustomStore || order.orderType == 'Text' || order.orderType == 'Photo' || order.orderType == 'MapPin' || order.orderType == 'map_pin';

    if (isQuoteOrder) {
      final isQuoteSent = order.subTotal > 0 || order.vendorPaymentDetailsUploadedByDriver;
      final isAdminPaid = order.vendorPaymentStatus == 'Completed' || order.vendorPaymentStatus == 'Paid';
      final isPickedUp = rawStatus == 'PickedUp' || rawStatus == 'Picked Up' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered';
      final isDelivered = rawStatus == 'Delivered';

      // 5-Step Professional Flow for Quote / Any Shop / Custom Store
      steps = [
        _StatusStep('CONFIRMED', Icons.assignment_turned_in_rounded, true),
        _StatusStep('QUOTE SENT', icons.Iconsax.magicpen_copy, isQuoteSent),
        _StatusStep('ADMIN PAID', icons.Iconsax.bank_copy, isAdminPaid),
        _StatusStep('PICKED UP', icons.Iconsax.box_tick_copy, isPickedUp),
        _StatusStep('DELIVERED', Icons.check_circle_rounded, isDelivered),
      ];

      activeIdx = isDelivered ? 4 
          : isPickedUp ? 3
          : isAdminPaid ? 3
          : isQuoteSent ? 2
          : 1; 
    } else {
      // Flow C: Standard Menu Order
      steps = [
        _StatusStep('CONFIRMED', Icons.assignment_turned_in_rounded, true),
        _StatusStep('PREPARING', icons.Iconsax.box_copy, rawStatus == 'Preparing' || rawStatus == 'Ready' || rawStatus == 'HandedOver' || rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered'),
        _StatusStep('READY', icons.Iconsax.box_tick_copy, rawStatus == 'Ready' || rawStatus == 'HandedOver' || rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered'),
        _StatusStep('ON THE WAY', icons.Iconsax.routing_copy, rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered'),
        _StatusStep('DELIVERED', Icons.check_circle_rounded, rawStatus == 'Delivered'),
      ];

      activeIdx = rawStatus == 'Delivered' ? 4
          : (rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery') ? 3
          : (rawStatus == 'Ready' || rawStatus == 'HandedOver') ? 2
          : rawStatus == 'Preparing' ? 1
          : 0;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('LIVE STATUS', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle))
                  .animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms),
                const SizedBox(width: 6),
                Text('LIVE', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 9, fontWeight: FontWeight.w900)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                // connector line
                final lineIdx = i ~/ 2;
                final filled = steps[lineIdx + 1].isDone;
                return Expanded(child: Container(height: 2, color: filled ? AppTheme.accentGreen.withValues(alpha: 0.4) : AppTheme.lightBg));
              }
              final stepIdx = i ~/ 2;
              final step = steps[stepIdx];
              final isActive = stepIdx == activeIdx;
              return _buildStatusNode(step.label, step.isDone, step.icon, isActive: isActive);
            }),
          ),
          const SizedBox(height: 12),
          // Current status text
          Center(
            child: Text(
              _getStatusDescription(order, rawStatus),
              style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDescription(DeliveryOrder order, String rawStatus) {
    final bool isQuoteOrder = order.isCustomStore || order.orderType == 'Text' || order.orderType == 'Photo' || order.orderType == 'MapPin' || order.orderType == 'map_pin';
    if (isQuoteOrder) {
      if (rawStatus == 'Delivered') return '🏁 Successfully delivered to customer!';
      if (rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery') return '🚀 Order picked up — heading to customer';
      if (order.vendorPaymentStatus == 'Completed' || order.vendorPaymentStatus == 'Paid') return '✅ Admin transferred payment to Shop! Collect items now.';
      if (order.subTotal > 0 || order.vendorPaymentDetailsUploadedByDriver) return '⏳ Quote submitted! Waiting for Admin payment transfer to shop.';
      return '📝 Please enter Shop Bill & Payment details above';
    }

    switch (rawStatus.toLowerCase()) {
      case 'accepted':
      case 'assigned': return '✅ Order confirmed by vendor';
      case 'preparing': return '👨‍🍳 Vendor started preparing your order';
      case 'ready':
      case 'ready for handover': return '📦 Order is ready for handover!';
      case 'pickedup':
      case 'picked up': return '🚀 Order picked up — heading to customer';
      case 'outfordelivery': return '📍 Almost there! Out for delivery';
      case 'delivered': return '🏁 Successfully delivered!';
      default: return rawStatus;
    }
  }

  Widget _buildStatusNode(String label, bool isDone, IconData icon, {bool isActive = false}) {
    Color color = isDone ? AppTheme.accentGreen : (isActive ? AppTheme.primaryOrange : AppTheme.lightBg);

    return Column(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isDone ? AppTheme.accentGreen : (isActive ? AppTheme.primaryOrange : Colors.white),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: isActive ? [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.25), blurRadius: 10)] : null,
          ),
          child: Icon(
            isDone ? Icons.check_rounded : icon,
            color: isDone || isActive ? Colors.white : AppTheme.lightText,
            size: 16,
          ),
        ).animate(target: isActive ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.outfit(
          color: isActive ? AppTheme.primaryOrange : (isDone ? AppTheme.accentGreen : AppTheme.lightText),
          fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildRouteStop(IconData icon, String label, String value, Color color,
      {bool hasActions = false, String? subtext, bool isLocked = false, VoidCallback? onNavigate, VoidCallback? onCall}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isLocked ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isLocked ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: isLocked ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLocked ? Colors.grey.shade200 : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: isLocked ? Colors.grey.shade400 : color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: isLocked ? Colors.grey.shade500 : color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: isLocked ? AppTheme.lightText : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtext != null && subtext.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtext,
                    style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (hasActions) ...[
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onCall != null)
                  _buildCircularAction(Icons.call_rounded, const Color(0xFFECFDF5), const Color(0xFF059669), onTap: onCall),
                if (onNavigate != null) ...[
                  const SizedBox(width: 8),
                  _buildCircularAction(Icons.navigation_rounded, const Color(0xFFEEF2FF), const Color(0xFF4F46E5), onTap: onNavigate),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircularAction(IconData icon, Color bg, Color iconColor, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  // ── BOTTOM ACTION BUTTON ─────────────────────────────────────────────────
  Widget _buildActionButton(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    String label = '';
    String subtitle = '';
    DeliveryStatus? next;
    Color color = AppTheme.primaryOrange;
    bool isBlocked = false;

    if (order.status == DeliveryStatus.allocated || order.status == DeliveryStatus.pickingUp) {
      final bool isCustom = order.isCustomStore || order.orderType == 'MapPin' || order.orderType == 'map_pin' || order.orderType == 'Photo' || order.orderType == 'Text';
      final bool quoteDone = order.subTotal > 0 || order.vendorPaymentDetailsUploadedByDriver;
      final bool needsQuote = isCustom && !quoteDone;
      
      if (needsQuote) {
        return const SizedBox.shrink(); // Quote form is inline directly on screen!
      } else {
        final bool isPaidByAdmin = order.vendorPaymentStatus == 'Completed' || order.vendorPaymentStatus == 'Paid';
        
        if (isCustom) {
          if (isPaidByAdmin) {
            label = '📦 COLLECT ITEMS & PICK UP';
            subtitle = 'பொருட்களை கடையில் பெற்றுக்கொள்ளவும்';
            color = const Color(0xFF059669);
            next = DeliveryStatus.pickedUp;
          } else {
            label = '⏳ WAITING FOR ADMIN PAYMENT';
            subtitle = 'அட்மின் கடைக்கு பணம் செலுத்தும் வரை காத்திருக்கவும்';
            color = const Color(0xFFD97706);
            next = DeliveryStatus.pickedUp;
          }
        } else {
          final isReady = order.rawStatus == 'Ready' || order.rawStatus == 'HandedOver' || order.rawStatus == 'PickedUp' || order.rawStatus == 'Picked Up';
          label = isReady ? '📦 COLLECT ITEMS & PICK UP' : '⏳ WAITING FOR VENDOR PREPARATION';
          subtitle = isReady ? 'பொருட்களை கடையில் பெற்றுக்கொள்ளவும்' : 'கடை தயாரிக்கும் வரை காத்திருக்கவும்';
          next = isReady ? DeliveryStatus.pickedUp : null;
          color = isReady ? const Color(0xFF059669) : Colors.grey.shade400;
        }
      }
    } else if (order.status == DeliveryStatus.pickedUp || order.status == DeliveryStatus.onTheWay) {
      label = '🏁 REACHED & DELIVERED';
      subtitle = 'வாடிக்கையாளரிடம் வெற்றிகரமாக டெலிவரி செய்';
      next = DeliveryStatus.delivered;
      color = const Color(0xFF059669);
      
      // BLOCK DELIVERY IF BILL IS NOT UPLOADED for Custom/Text orders
      if ((order.isCustomStore || order.orderType != 'Cart') && order.billPhotoPath == null) {
        isBlocked = true;
      }
    }

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
      child: GestureDetector(
        onTap: isBlocked ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('டெலிவரி செய்வதற்கு முன் பில் ரசீது படத்தை பதிவேற்றவும் (Please upload bill photo before delivering)'),
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
                        isCod ? 'பணம் பெறப்பட்டதா? (COD)' : 'Confirm Order Delivery?',
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
                              'வாடிக்கையாளரிடம் பணத்தை வாங்கினீர்களா?',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.orange.shade900, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Have you collected cash from the customer?',
                              style: GoogleFonts.outfit(color: Colors.orange.shade800, fontSize: 11),
                            ),
                            if (order.totalAmount > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                'COLLECT CASH: ₹${order.totalAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppTheme.darkText, fontSize: 16),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      isCod 
                        ? 'பணம் பெற்றுக்கொண்டு ஆர்டரை டெலிவரி செய்ய "YES, CASH RECEIVED" என்பதை அழுத்தவும்.'
                        : 'Confirm that you have successfully delivered this package to the customer.',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.darkText),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('CANCEL', style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCod ? Colors.orange.shade700 : const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      isCod ? 'YES, CASH RECEIVED ✓' : 'DELIVERED ✓',
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
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isBlocked ? Colors.grey.shade300 : color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isBlocked ? [] : [
              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
            ],
            border: isBlocked ? Border.all(color: Colors.grey.shade400, width: 1) : null,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        'UPLOAD BILL TO PROCEED (பில் ரசீது பதிவேற்றவும்)', 
                        style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                  ] else if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
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
    ).animate().slideY(begin: 1, end: 0, duration: 400.ms);
  }

  void _showQuoteDialog(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
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
                          Text('Submit Shop Quote & QR', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.darkText)),
                          Text('கடை பில் தொகை & Shop QR விவரங்களை அனுப்பவும்', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.lightText, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. BILL AMOUNT (MANDATORY)
                Text('1. ORIGINAL BILL AMOUNT (பொருட்களின் மொத்த விலை) *', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5)),
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
                Text('2. SHOP QR CODE (கடை கூகுள் பே QR கோட்)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5)),
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
                Text('3. SHOP GPAY / PHONE NUMBER (Optional - கடை எண்)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5)),
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
                Text('4. SHOP GPAY ACCOUNT NAME (Optional - கணக்கு பெயர்)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5)),
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
                          const SnackBar(content: Text('Please enter valid bill amount (பில் தொகையை உள்ளிடவும்)'), backgroundColor: Colors.redAccent),
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
                                    Text('CONFIRM DETAILS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFF0F172A))),
                                    Text('விவரங்களை உறுதிப்படுத்தவும்', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
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
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFC7D2FE)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('SHOP BILL AMOUNT:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4338CA))),
                                    Text('₹${amount.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF312E81))),
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
                                    localQrPath != null ? 'Shop QR Code Attached ✓' : 'No QR Code attached',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: localQrPath != null ? const Color(0xFF059669) : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
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
                              child: Text('EDIT / மாற்று', style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.w800)),
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
                              label: Text('CONFIRM & SEND', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
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

                      final success = await provider.sendQuote(
                        order.id,
                        amount,
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
              Text('Order Support / Help', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Text('How can we help you with Order #${order.displayId}?', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _supportOptionTile(
                      icon: Icons.mark_chat_unread_rounded,
                      color: const Color(0xFF4F46E5),
                      title: 'Raise Support Ticket (பற்றுச்சீட்டு / புகார் பதிவு)',
                      subtitle: 'Report vendor delay, customer issue, or vehicle problem',
                      onTap: () {
                        Navigator.pop(context);
                        _showRaiseTicketDialog(context, order);
                      },
                    ),
                    const SizedBox(height: 10),
                    _supportOptionTile(
                      icon: Icons.phone_in_talk_rounded,
                      color: const Color(0xFF10B981),
                      title: 'Call Delivery Support (உதவி மையம்)',
                      subtitle: 'Toll-free 1800-123-4567 (24x7 Assistance)',
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
    final issues = [
      '👨‍🍳 Vendor Delay / Food Not Ready (விற்பனையாளர் தாமதம்)',
      '👤 Customer Unreachable (வாடிக்கையாளரை தொடர்பு கொள்ள முடியவில்லை)',
      '🛵 Vehicle Issue / Puncture (வாகனப் பழுது / பஞ்சர்)',
      '💰 Payout / Earnings Issue (வருமானம் / பணம் சம்பந்தப்பட்டவை)',
      '📝 Other Custom Query (மற்றவை / சொந்தக் காரணம்)',
    ];
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
                  child: Text('Raise Ticket', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17, color: const Color(0xFF1E293B))),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Topic / Issue Category:', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.grey.shade700)),
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
                  Text('Type your message:', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5, color: const Color(0xFF4F46E5))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    style: GoogleFonts.outfit(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Type your issue description here (உங்கள் மெசேஜை டைப் செய்யவும்)...',
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
                child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
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
                    'issueType': issues[selectedIssue].split(' (')[0].replaceAll(RegExp(r'[^a-zA-Z\s\/]'), '').trim(),
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
                      title: Text('Ticket Registered!', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Ticket #$ticketId has been created successfully.', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)), textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          if (messageText.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                              child: Text('"$messageText"', style: GoogleFonts.outfit(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text('Our Delivery Partner Support will review your ticket and respond shortly.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
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
                            child: Text('Done', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Text('Send Message', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
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
    final amtText = amountCtrl.text.trim();
    if (amtText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('தயவுசெய்து பில் தொகையை உள்ளிடவும் (Please enter bill amount)', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
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
          content: Text('சரியான பில் தொகையை உள்ளிடவும் (Enter a valid bill amount)', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Confirmation Dialog before sending to Admin
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
                  Text('CONFIRM DETAILS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFF0F172A))),
                  Text('விவரங்களை உறுதிப்படுத்தவும்', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SHOP BILL AMOUNT:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4338CA))),
                  Text('₹${billAmt.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF312E81))),
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
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('EDIT / மாற்று', style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.w800)),
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
            label: Text('CONFIRM & SEND', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
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
        gpayNumber: gpayCtrl.text.trim(),
        gpayName: gpayNameCtrl.text.trim(),
        qrImagePath: localQrPath,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '🎉 பில் & பணம் செலுத்தும் விவரங்கள் அனுப்பப்பட்டது!',
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('அனுப்புவதில் தோல்வி. மீண்டும் முயற்சிக்கவும்.', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
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
                                'Submit Shop Bill & Details',
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
                          'கடையிடம் கேட்டு வாடிக்கையாளர் பில் தொகையை உள்ளிடவும்',
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
                    title: 'ORIGINAL BILL AMOUNT',
                    subtitle: 'பொருட்களின் மொத்த அசல் விலை',
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
                    title: 'SHOP QR CODE',
                    subtitle: 'கடை கூகுள் பே QR கோட் படம்',
                    badgeText: 'OPTIONAL',
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
                                      'QR Attached',
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
                              localQrPath != null ? 'Retake QR' : 'Snap Shop QR',
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
                              'Gallery',
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
                    title: 'SHOP GPAY / PHONE NUMBER',
                    subtitle: 'கடை கூகுள் பே / தொலைபேசி எண்',
                    badgeText: 'OPTIONAL',
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
                    title: 'GPAY ACCOUNT / SHOP NAME',
                    subtitle: 'கூகுள் பே கணக்கு பெயர் / கடை பெயர்',
                    badgeText: 'OPTIONAL',
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
                  const SizedBox(height: 26),

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
                                  Text(
                                    'SUBMIT BILL & SHOP DETAILS',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
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

