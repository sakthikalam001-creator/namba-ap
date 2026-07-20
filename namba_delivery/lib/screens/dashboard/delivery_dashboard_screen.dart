import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/delivery_provider.dart';
import '../../services/delivery_auth_service.dart';
import '../../services/voice_dispatch_service.dart';

import '../orders/delivery_order_detail_screen.dart';
import '../orders/delivery_order_history_screen.dart';
import '../profile/rider_profile_screen.dart';
import '../earnings/rider_earnings_screen.dart';
import '../map/rider_heatmap_screen.dart';
import 'admin_stats_screen.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen>
    with TickerProviderStateMixin {
  String _driverName = 'Partner';
  late AnimationController _pulseController;
  late AnimationController _radarController;
  bool _showAssignmentOverlay = false;
  Map<String, dynamic>? _overlayAssignment;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _radarController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    _loadProfile();

    // Register callback for new assignment socket event
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DeliveryProvider>(context, listen: false);
      
      // Check if there's already a pending assignment (e.g. from notification cold start)
      if (provider.pendingAssignment != null) {
        setState(() {
          _overlayAssignment = provider.pendingAssignment;
          _showAssignmentOverlay = true;
        });
      }

      provider.onNewAssignment = (data) {
        if (mounted) {
          setState(() {
            _overlayAssignment = data;
            _showAssignmentOverlay = true;
          });
        }
      };
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final name = await DeliveryAuthService.getDriverName();
    if (mounted) setState(() => _driverName = name);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeliveryProvider>(context);
    final isOnline = provider.isOnline;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Stack(
        children: [
          // ── Ambient Pulse ─────────────────────────────────────────────────
          if (isOnline)
            Positioned(
              top: -100, right: -50,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentGreen.withValues(alpha: 0.03),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(duration: 3.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
            ),

          // ── Main Scrollable Content ───────────────────────────────────────
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildPrimeHeader(),
                        const SizedBox(height: 32),
                        _buildStatusToggle(),
                        const SizedBox(height: 24),
                        _buildPrimeEarningsCard(),
                        const SizedBox(height: 32),
                        Text('TODAY\'S METRICS',
                            style: GoogleFonts.outfit(
                                color: AppTheme.darkText.withValues(alpha: 0.3),
                                fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        _buildPrimeMetricGrid(),
                        const SizedBox(height: 32),
                        _buildHeatmapBanner(context),
                        const SizedBox(height: 32),
                        _buildMissionQueueSection(),
                        const SizedBox(height: 140), // Extra space for sticky bar
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Sticky Active Order Bar (Only shown if ONLINE) ─────────────────
          if (provider.isOnline && provider.activeOrders.isNotEmpty)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildStickyLiveOrderBar(provider.activeOrders.first),
            ),

          // ── New Assignment Overlay ────────────────────────────────────────
          if (_showAssignmentOverlay && _overlayAssignment != null)
            _buildNewAssignmentOverlay(_overlayAssignment!),
        ],
      ),
    );
  }

  // ── NEW ASSIGNMENT FULL-SCREEN OVERLAY ────────────────────────────────────
  Widget _buildNewAssignmentOverlay(Map<String, dynamic> data) {
    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final orderId = data['orderId']?.toString() ?? '';
    final displayId = data['displayId']?.toString() ?? '';
    final vendorName = data['vendorName']?.toString() ?? 'Store';
    final paymentMethod = data['paymentMethod']?.toString() ?? 'COD';
    final amount = data['amount']?.toString() ?? '0';

    return AnimatedOpacity(
      opacity: _showAssignmentOverlay ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Blurred background
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withValues(alpha: 0.6)),
              ),
            ),

            // Pulsing alert ring
            Center(
              child: Container(
                width: 340, height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3), width: 2),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(duration: 1500.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1))
               .fade(begin: 0.3, end: 0.8),
            ),

            // Card
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 20))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Alert Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accentGreen, Color(0xFF00C853)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(icons.Iconsax.box_copy, color: Colors.white, size: 36),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scale(duration: 800.ms, begin: const Offset(1, 1), end: const Offset(1.08, 1.08)),

                    const SizedBox(height: 24),

                    Text('NEW ORDER REQUEST', style: GoogleFonts.outfit(
                      color: AppTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text(vendorName, style: GoogleFonts.outfit(
                      color: AppTheme.darkText, fontSize: 24, fontWeight: FontWeight.w900)),
                    if (displayId.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.lightBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('ORDER #$displayId',
                              style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: (paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(paymentMethod == 'COD' ? '💸 COD' : '💳 PAID',
                              style: GoogleFonts.outfit(color: paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    const SizedBox(height: 32),

                    // Accept Only
                    Row(
                      children: [
                        // Accept
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              setState(() => _showAssignmentOverlay = false);
                              VoiceDispatchService.missionAccepted();
                              if (orderId.isNotEmpty) {
                                await provider.acceptAssignment(orderId);
                              }
                              provider.clearPendingAssignment();
                              if (mounted && orderId.isNotEmpty) {
                                Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: orderId)));
                              }
                            },
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.accentGreen, Color(0xFF00C853)],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text('ACCEPT', style: GoogleFonts.outfit(
                                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack, duration: 400.ms),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimeHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderProfileScreen())),
          child: Row(
            children: [
              Hero(
                tag: 'profile_pic',
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    color: Colors.white,
                    image: const DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1531427186611-ecfd6d936c79?q=80&w=200&auto=format&fit=crop'),
                      fit: BoxFit.cover),
                    boxShadow: AppTheme.softShadow,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GOOD MORNING,', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  Text('${_driverName.toUpperCase()} ⚡', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.softShadow),
          child: const Stack(
            children: [
              Icon(icons.Iconsax.notification_copy, color: AppTheme.darkText, size: 22),
              Positioned(right: 2, top: 0, child: CircleAvatar(radius: 4, backgroundColor: AppTheme.primaryOrange)),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1);
  }

  Widget _buildStatusToggle() {
    final provider = Provider.of<DeliveryProvider>(context);
    final isOnline = provider.isOnline;

    return Container(
      width: double.infinity, height: 84,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: AppTheme.cardShadow),
      child: Stack(
        children: [
          Center(
            child: Text(
              isOnline ? 'SLIDE TO GO OFFLINE' : 'SLIDE TO GO ONLINE',
              style: GoogleFonts.outfit(color: AppTheme.lightText.withValues(alpha: 0.15), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.5),
            ),
          ),
          _StatusSwipeSlider(
            isOnline: isOnline,
            onChanged: (newStatus) async {
              // OPTIMISTIC UPDATE
              provider.updateOnlineStatus(newStatus);
              
              if (newStatus) VoiceDispatchService.systemOnline();
              
              final driverId = await DeliveryAuthService.getDriverId();
              if (driverId.isNotEmpty) {
                final result = await DeliveryAuthService.setDriverStatus(driverId, newStatus);
                
                if (result['success'] != true) {
                  // REVERT ON FAILURE
                  provider.updateOnlineStatus(!newStatus);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚠️ Status Sync Failed: ${result['error'] ?? 'Connection issues'}'),
                        backgroundColor: Colors.red.shade800,
                        action: SnackBarAction(label: 'RETRY', textColor: Colors.white, onPressed: () => {}),
                      )
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildPrimeEarningsCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderEarningsScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2E2E3E), Color(0xFF1A1A2E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: const Color(0xFF1A1A2E).withValues(alpha: 0.3), blurRadius: 25, offset: const Offset(0, 15))],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TOTAL REVENUE', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₹', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    Text('0', style: GoogleFonts.outfit(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, height: 1)),
                    Text('.00', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                ]),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(icons.Iconsax.wallet_3_copy, color: AppTheme.primaryOrange, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(icons.Iconsax.trend_up_copy, color: AppTheme.accentGreen, size: 16),
                const SizedBox(width: 8),
                Text('+0% FROM YESTERDAY', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const Spacer(),
                const Icon(icons.Iconsax.arrow_right_3_copy, color: Colors.white24, size: 14),
              ]),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildHeatmapBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderHeatmapScreen())),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF8C42), Color(0xFFFF5722)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(icons.Iconsax.radar_copy, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('FIND HOT ZONES', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                Text('See where orders are spiking right now', style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1);
  }

  Widget _buildPrimeMetricGrid() {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, child) {
        return Row(
          children: [
            Expanded(child: _metricTile(icons.Iconsax.box_copy, 'Orders', '${provider.orderHistory.length}', AppTheme.accentGreen,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryOrderHistoryScreen())))),
            const SizedBox(width: 12),
            Expanded(child: _metricTile(icons.Iconsax.star_copy, 'Rating', '4.9', Colors.amber)),
          ],
        );
      },
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _metricTile(IconData icon, String label, String value, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _buildMissionQueueSection() {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, child) {
        if (!provider.isOnline) return _buildOfflinePlaceholder();

        final active = provider.activeOrders;
        final incoming = provider.incomingRequests;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ACTIVE MISSIONS ─────────────────────────────────────────────
            if (active.isNotEmpty) ...[
              Text('ACTIVE MISSIONS', style: GoogleFonts.outfit(color: AppTheme.primaryOrange.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 20),
              ...active.map((order) => _buildActiveMissionCard(order)),
              const SizedBox(height: 32),
            ],

            // ── INCOMING JOBS ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('AVAILABLE JOBS', style: GoogleFonts.outfit(color: AppTheme.darkText.withValues(alpha: 0.3), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                if (incoming.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${incoming.length} NEARBY', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            if (incoming.isEmpty)
              _buildSearchingState()
            else
              Column(children: incoming.map((order) => _buildPrimeJobCard(order)).toList()),
          ],
        ).animate().fadeIn(delay: 500.ms);
      },
    );
  }

  Widget _buildOfflinePlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
            child: Icon(icons.Iconsax.radar_copy, color: Colors.grey.shade300, size: 40),
          ),
          const SizedBox(height: 24),
          Text('GO ONLINE TO START', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('You are currently offline. Go online to receive new order assignments and track your earnings.', 
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 13, fontWeight: FontWeight.w500, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSearchingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: AppTheme.softShadow),
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.2), width: 1.5)))
            .animate(onPlay: (c) => c.repeat()).scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.8, 1.8)).fade(),
          Container(width: 70, height: 70, decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: const Icon(icons.Iconsax.radar_2_copy, color: AppTheme.accentGreen, size: 32)),
        ]),
        const SizedBox(height: 28),
        Text('SEARCHING FOR JOBS', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text('Scanning your current sector...', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── JOB CARD (Incoming request shown as list — has Accept/Decline) ─────────
  Widget _buildPrimeJobCard(dynamic order) {
    final provider = Provider.of<DeliveryProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.lightBg), boxShadow: AppTheme.softShadow),
      child: Column(
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: const Icon(icons.Iconsax.box_copy, color: AppTheme.primaryOrange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.store.name.toUpperCase(), style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 18, fontWeight: FontWeight.w900)),
              if (order.displayId.isNotEmpty)
                Text('ORDER #${order.displayId}', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('NEW ORDER', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(order.paymentMethod == 'COD' ? 'COD' : 'PAID',
                  style: GoogleFonts.outfit(color: order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ]),
          ]),
          const SizedBox(height: 20),
          // Items preview
          if (order.items.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(12)),
              child: Text(
                order.items.map((i) => i.product.name).take(3).join(' • ') + (order.items.length > 3 ? ' +${order.items.length - 3} more' : ''),
                style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          Row(children: [
            // Accept
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  VoiceDispatchService.missionAccepted();
                  final ok = await provider.acceptAssignment(order.id);
                  if (ok && mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: order.id)));
                  }
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: Center(child: Text('ACCEPT JOB', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
                ),
              ),
            ),
          ]),
        ],
      ),
    ).animate().slideX(begin: 0.1);
  }

  // ── ACTIVE MISSION CARD (with live status badge) ──────────────────────────
  Widget _buildActiveMissionCard(order) {
    final String rawStatus = order.rawStatus ?? '';
    final statusLabel = _getLiveStatusLabel(rawStatus);
    final statusColor = _getLiveStatusColor(rawStatus);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: order.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white, AppTheme.primaryOrange.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: AppTheme.primaryOrange, shape: BoxShape.circle),
              child: const Icon(icons.Iconsax.routing_copy, color: Colors.white, size: 22)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MISSION IN PROGRESS', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Text(order.storeName.toUpperCase(), style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 18, fontWeight: FontWeight.w900)),
            ])),
            // LIVE STATUS BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withValues(alpha: 0.2))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle))
                  .animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),
                const SizedBox(width: 6),
                Text(statusLabel, style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)),
              ]),
            ),
          ]),
          const Divider(height: 24, color: AppTheme.lightBg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(icons.Iconsax.box_copy, color: AppTheme.lightText, size: 14),
                const SizedBox(width: 8),
                Text('${order.items.length} ITEMS', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('VIEW DETAILS →', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ]),
      ),
    ).animate().shimmer(duration: 2.seconds).slideX(begin: -0.05);
  }

  Widget _buildStickyLiveOrderBar(order) {
    final String rawStatus = order.rawStatus ?? '';
    final statusLabel = _getLiveStatusLabel(rawStatus);
    final statusColor = _getLiveStatusColor(rawStatus);

    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: AppTheme.primaryOrange, shape: BoxShape.circle),
                  child: const Icon(icons.Iconsax.routing_copy,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LIVE MISSION',
                          style: GoogleFonts.outfit(
                              color: AppTheme.primaryOrange,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5)),
                      Text(order.storeName.toUpperCase(),
                          style: GoogleFonts.outfit(
                              color: AppTheme.darkText,
                              fontSize: 15,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(statusLabel,
                              style: GoogleFonts.outfit(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DeliveryOrderDetailScreen(orderId: order.id))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.darkText,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('VIEW →',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 1.0, duration: 400.ms, curve: Curves.easeOutBack);
  }

  String _getLiveStatusLabel(String rawStatus) {
    switch (rawStatus) {
      case 'Assigned': return 'HEAD TO VENDOR';
      case 'Ready':    return 'READY FOR PICKUP';
      case 'PickedUp': return 'HEADING TO CUSTOMER';
      case 'OutForDelivery': return 'OUT FOR DELIVERY';
      default: return rawStatus.toUpperCase();
    }
  }

  Color _getLiveStatusColor(String rawStatus) {
    switch (rawStatus) {
      case 'Ready':    return AppTheme.accentGreen;
      case 'Assigned': return AppTheme.primaryOrange;
      case 'PickedUp': return Colors.indigo;
      case 'OutForDelivery': return AppTheme.accentGreen;
      default: return AppTheme.lightText;
    }
  }
}

// ── Status Swipe Slider ────────────────────────────────────────────────────────
class _StatusSwipeSlider extends StatefulWidget {
  final bool isOnline;
  final Function(bool) onChanged;
  const _StatusSwipeSlider({required this.isOnline, required this.onChanged});
  @override
  State<_StatusSwipeSlider> createState() => _StatusSwipeSliderState();
}

class _StatusSwipeSliderState extends State<_StatusSwipeSlider> {
  double _dragValue = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _dragValue = widget.isOnline ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(_StatusSwipeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnline != widget.isOnline && !_isDragging) {
      setState(() => _dragValue = widget.isOnline ? 1.0 : 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      const margin = 8.0;
      const handleSize = 68.0;
      final usableWidth = maxWidth - (margin * 2) - handleSize;

      return Padding(
        padding: const EdgeInsets.all(margin),
        child: GestureDetector(
          onHorizontalDragStart: (_) => setState(() => _isDragging = true),
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragValue += details.primaryDelta! / usableWidth;
              _dragValue = _dragValue.clamp(0.0, 1.0);
            });
          },
          onHorizontalDragEnd: (details) async {
            setState(() => _isDragging = false);
            if (widget.isOnline) {
              if (_dragValue < 0.3) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    backgroundColor: Colors.white,
                    title: Row(children: [
                      const Icon(icons.Iconsax.warning_2, color: AppTheme.primaryOrange),
                      const SizedBox(width: 10),
                      Text('Go Offline?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20)),
                    ]),
                    content: Text('Are you sure you want to go offline? You will stop receiving new delivery requests and background tracking will pause.',
                        style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 14)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('CANCEL', style: GoogleFonts.outfit(color: AppTheme.lightText, fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('GO OFFLINE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ) ?? false;
                
                if (confirm) {
                  widget.onChanged(false);
                } else {
                  if (mounted) setState(() => _dragValue = 1.0);
                }
              }
              else {
                if (mounted) setState(() => _dragValue = 1.0);
              }
            } else {
              if (_dragValue > 0.7) {
                widget.onChanged(true);
              } else {
                if (mounted) setState(() => _dragValue = 0.0);
              }
            }
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(22)),
            child: Stack(children: [
              AnimatedContainer(
                duration: _isDragging ? Duration.zero : 300.ms,
                width: handleSize + (_dragValue * usableWidth),
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isOnline
                      ? [AppTheme.accentGreen, AppTheme.accentGreen.withValues(alpha: 0.8)]
                      : [AppTheme.primaryOrange, AppTheme.primaryOrange.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              AnimatedPositioned(
                duration: _isDragging ? Duration.zero : 300.ms,
                left: _dragValue * usableWidth, top: 0, bottom: 0,
                child: Container(
                  width: handleSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Center(child: Icon(
                    widget.isOnline ? icons.Iconsax.radar_2_copy : icons.Iconsax.radar_copy,
                    color: widget.isOnline ? AppTheme.accentGreen : AppTheme.primaryOrange,
                    size: 26,
                  )),
                ),
              ),
              if (!_isDragging || _dragValue < 0.5)
                Positioned(
                  left: handleSize + 16, top: 0, bottom: 0,
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.isOnline ? 'ONLINE' : 'OFFLINE',
                        style: GoogleFonts.outfit(color: widget.isOnline ? Colors.white : AppTheme.darkText, fontSize: 16, fontWeight: FontWeight.w900)),
                      Text(widget.isOnline ? 'ACTIVE DUTY' : 'SWIPE TO START',
                        style: GoogleFonts.outfit(color: widget.isOnline ? Colors.white70 : AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      );
    });
  }
}
