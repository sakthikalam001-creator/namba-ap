import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'services/sync_service.dart';
import 'login_screen.dart';
import 'super_admin_dashboard.dart';
import 'theme/admin_theme.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ BOOT: Env Loaded');
  } catch (e) {
    debugPrint('❌ BOOT: Env Load Failed: $e');
  }
  runApp(const NambaAdminApp());
}

class NambaAdminApp extends StatelessWidget {
  const NambaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Namba Delivery Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AdminColors.primaryIndigo,
          primary: AdminColors.primaryIndigo,
          surface: AdminColors.background,
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
        scaffoldBackgroundColor: AdminColors.background,
        useMaterial3: true,
      ),
      home: const AdminRoot(),
    );
  }
}

class AdminRoot extends StatefulWidget {
  const AdminRoot({super.key});
  @override
  State<AdminRoot> createState() => _AdminRootState();
}

class _AdminRootState extends State<AdminRoot> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('admin_user');
    if (userStr != null) {
      setState(() => _user = jsonDecode(userStr));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return AdminLoginScreen(onLogin: (u) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('admin_user', jsonEncode(u));
        setState(() => _user = u);
      });
    }
    return SuperAdminDashboard(
        user: _user!,
        onLogout: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('admin_user');
          setState(() => _user = null);
        });
  }
}

class AdminDashboard extends StatefulWidget {
  final VoidCallback? onLogout;
  const AdminDashboard({super.key, this.onLogout});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;
  List<CoreOrder> _orders = [];
  Timer? _refreshTimer;
  bool _loading = true;

  // Delivery partner assignment (Admin only)
  final Map<String, String> _assignedPartners = {}; // orderId → partnerName

  final List<Map<String, dynamic>> _partners = [
    {'name': 'Rajan Kumar', 'phone': '+91 98765 43210', 'rating': 4.8, 'vehicle': '🏍️ Bike', 'status': 'Available'},
    {'name': 'Karthik S', 'phone': '+91 87654 32109', 'rating': 4.6, 'vehicle': '🛵 Scooter', 'status': 'Available'},
    {'name': 'Murugan T', 'phone': '+91 76543 21098', 'rating': 4.9, 'vehicle': '🏍️ Bike', 'status': 'Busy'},
    {'name': 'Selvam R', 'phone': '+91 65432 10987', 'rating': 4.5, 'vehicle': '🚲 Cycle', 'status': 'Available'},
    {'name': 'Dinesh K', 'phone': '+91 54321 09876', 'rating': 4.7, 'vehicle': '🏍️ Bike', 'status': 'Available'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final orders = await LocalSyncService.getAllOrders();
    if (mounted) {
      setState(() {
        _orders = orders;
        _loading = false;
      });
    }
  }

  double get _totalRevenue => _orders
      .where((o) => o.status == CoreOrderStatus.delivered)
      .fold(0.0, (s, o) => s + o.total);

  double get _todayRevenue {
    final today = DateTime.now();
    return _orders
        .where((o) =>
            o.status == CoreOrderStatus.delivered &&
            o.createdAt.year == today.year &&
            o.createdAt.month == today.month &&
            o.createdAt.day == today.day)
        .fold(0.0, (s, o) => s + o.total);
  }

  int get _activeOrders => _orders
      .where((o) =>
        o.status != CoreOrderStatus.delivered &&
        o.status != CoreOrderStatus.cancelled)
      .length;

  int get _paidOrders => _orders.where((o) => o.customerPaid).length;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildOrdersList(),
      _buildRevenueChart(),
      _buildDeliveryManagement(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: pages[_tab],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Orders'},
      {'icon': Icons.bar_chart_rounded, 'label': 'Revenue'},
      {'icon': Icons.delivery_dining_rounded, 'label': 'Delivery'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = _tab == i;
              return GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF4F46E5).withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(items[i]['icon'] is IconData ? (items[i]['icon'] as IconData) : Icons.info,
                        size: 24, color: active ? const Color(0xFF4F46E5) : Colors.grey.shade400),
                    const SizedBox(height: 2),
                    Text(items[i]['label']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                          color: active ? const Color(0xFF4F46E5) : Colors.grey.shade400,
                        )),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Dashboard ──────────────────────────────────────────────────────
  Widget _buildDashboard() {
    return CustomScrollView(slivers: [
      SliverAppBar(
        expandedHeight: 140,
        pinned: true,
        backgroundColor: const Color(0xFF4F46E5),
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('👑 Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Last updated: ${DateFormat('h:mm a').format(DateTime.now())}',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            ]),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadData,
          ),
          if (widget.onLogout != null)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: 'Logout',
              onPressed: widget.onLogout,
            ),
        ],
      ),
      SliverPadding(
        padding: const EdgeInsets.all(20),
        sliver: SliverToBoxAdapter(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  // Stat cards
                  _statGrid(),
                  const SizedBox(height: 24),
                  // Recent orders
                  _recentOrders(),
                  const SizedBox(height: 24),
                  // Store breakdown
                  _storeBreakdown(),
                  const SizedBox(height: 100),
                ]),
        ),
      ),
    ]);
  }

  Widget _statGrid() {
    final stats = [
      {'label': 'Total Revenue', 'value': '₹${_totalRevenue.toStringAsFixed(0)}', 'icon': Icons.currency_rupee_rounded, 'color': const Color(0xFF4F46E5), 'sub': 'All time'},
      {'label': "Today's Revenue", 'value': '₹${_todayRevenue.toStringAsFixed(0)}', 'icon': Icons.today_rounded, 'color': const Color(0xFF059669), 'sub': 'Today'},
      {'label': 'Active Orders', 'value': '$_activeOrders', 'icon': Icons.delivery_dining_rounded, 'color': const Color(0xFFD97706), 'sub': 'In progress'},
      {'label': 'Paid Orders', 'value': '$_paidOrders', 'icon': Icons.payment_rounded, 'color': const Color(0xFFDB2777), 'sub': 'Confirmed'},
    ];
    return GridView.count(
      crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
      childAspectRatio: 1.5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      children: stats.map((s) => _statCard(s)).toList(),
    );
  }

  Widget _statCard(Map<String, dynamic> s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (s['color'] is Color ? (s['color'] as Color) : Colors.blue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s['icon'] is IconData ? (s['icon'] as IconData) : Icons.info, color: s['color'] is Color ? (s['color'] as Color) : Colors.blue, size: 20),
          ),
          const Spacer(),
          Text(s['sub']?.toString() ?? '', style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
        const Spacer(),
        Text(s['value']?.toString() ?? '',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: s['color'] is Color ? (s['color'] as Color) : Colors.blue)),
        const SizedBox(height: 2),
        Text(s['label']?.toString() ?? '',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _recentOrders() {
    final recent = _orders.take(5).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _tab = 1),
          child: Text('See all', style: TextStyle(color: const Color(0xFF4F46E5), fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 12),
      if (recent.isEmpty)
        _emptyCard('No orders yet')
      else
        ...recent.map((o) => _orderTile(o)),
    ]);
  }

  Widget _orderTile(CoreOrder o, {bool showAssign = false}) {
    final statusColor = _statusColor(o.status);
    final assignedPartner = _assignedPartners[o.id];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(o.store.name[0],
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.store.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(o.statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
              ),
              if (o.customerPaid) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('💰 Paid', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                ),
              ],
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${o.total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), fontSize: 15)),
            const SizedBox(height: 2),
            Text(DateFormat('h:mm a').format(o.createdAt),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ]),
        ]),
        // Admin-only: Show assigned partner or assign button
        if (showAssign) ...[
          const SizedBox(height: 10),
          if (assignedPartner != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.delivery_dining_rounded, color: Color(0xFF059669), size: 16),
                const SizedBox(width: 6),
                Text('Assigned: $assignedPartner', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF059669), fontSize: 12)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _assignedPartners.remove(o.id)),
                  child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF059669)),
                ),
              ]),
            )
          else
            GestureDetector(
              onTap: () => _showAssignSheet(o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.add_rounded, color: Color(0xFF4F46E5), size: 16),
                  SizedBox(width: 6),
                  Text('Assign Delivery Partner', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4F46E5), fontSize: 12)),
                ]),
              ),
            ),
        ],
      ]),
    );
  }

  void _showAssignSheet(CoreOrder o) {
    int selectedIdx = -1;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Assign Delivery Partner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('Order #${o.id.substring(0, 6)}', style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 16),
          ..._partners.asMap().entries.map((e) {
            final i = e.key; final p = e.value;
            final isSelected = selectedIdx == i;
            final isBusy = p['status'] == 'Busy';
            return GestureDetector(
              onTap: isBusy ? null : () => setS(() => selectedIdx = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.06) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade200, width: isSelected ? 2 : 1),
                ),
                child: Row(children: [
                  CircleAvatar(radius: 20, backgroundColor: isBusy ? Colors.grey.shade200 : const Color(0xFF4F46E5).withOpacity(0.1),
                      child: Text(p['name'][0], style: TextStyle(fontWeight: FontWeight.w900, color: isBusy ? Colors.grey : const Color(0xFF4F46E5)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(p['vehicle'], style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: isBusy ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text(p['status'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isBusy ? Colors.orange.shade700 : Colors.green.shade700)),
                      ),
                    ]),
                    Row(children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                      Text(' ${p['rating']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      Text(' • ${p['phone']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ]),
                  ])),
                  if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5)),
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: selectedIdx < 0 ? null : () {
                setState(() => _assignedPartners[o.id] = _partners[selectedIdx]['name']);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✅ ${_partners[selectedIdx]['name']} assigned to Order #${o.id.substring(0, 6)}!'),
                  backgroundColor: const Color(0xFF059669),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
                disabledBackgroundColor: Colors.grey.shade200,
              ),
              child: const Text('Confirm Assignment', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ]),
      )),
    );
  }

  Widget _storeBreakdown() {
    final storeRevenue = <String, double>{};
    for (var o in _orders.where((o) => o.status == CoreOrderStatus.delivered)) {
      storeRevenue[o.store.name] = (storeRevenue[o.store.name] ?? 0) + o.total;
    }
    final sorted = storeRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Store-wise Revenue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      if (sorted.isEmpty)
        _emptyCard('No delivered orders yet')
      else
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
          child: Column(children: sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final maxVal = sorted.first.value;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: i < sorted.length - 1 ? Border(bottom: BorderSide(color: Colors.grey.shade100)) : null,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const Spacer(),
                  Text('₹${e.value.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), fontSize: 14)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxVal > 0 ? e.value / maxVal : 0,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    minHeight: 6,
                  ),
                ),
              ]),
            );
          }).toList()),
        ),
    ]);
  }

  // ── Orders List ────────────────────────────────────────────────────
  Widget _buildOrdersList() {
    final statusFilters = ['All', 'Active', 'Paid', 'Delivered'];
    return DefaultTabController(
      length: statusFilters.length,
      child: Column(children: [
        Container(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  const Text('All Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${_orders.length} orders',
                        style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              TabBar(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                indicator: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(10)),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade500,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                tabs: statusFilters.map((f) => Tab(text: f)).toList(),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              _orderTab(_orders),
              _orderTab(_orders.where((o) => o.status != CoreOrderStatus.delivered && o.status != CoreOrderStatus.cancelled).toList()),
              _orderTab(_orders.where((o) => o.customerPaid).toList()),
              _orderTab(_orders.where((o) => o.status == CoreOrderStatus.delivered).toList()),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _orderTab(List<CoreOrder> orders) {
    if (orders.isEmpty) return Center(child: _emptyCard('No orders found'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) => _orderTile(orders[i], showAssign: true),
    );
  }

  // ── Revenue Chart ──────────────────────────────────────────────────
  Widget _buildRevenueChart() {
    // Build hourly data for today
    final Map<int, double> hourlyRevenue = {};
    final today = DateTime.now();
    for (var o in _orders.where((o) =>
        o.createdAt.year == today.year &&
        o.createdAt.month == today.month &&
        o.createdAt.day == today.day)) {
      final h = o.createdAt.hour;
      hourlyRevenue[h] = (hourlyRevenue[h] ?? 0) + o.total;
    }

    final spots = List.generate(24, (i) => FlSpot(i.toDouble(), hourlyRevenue[i] ?? 0));
    final maxY = hourlyRevenue.values.isEmpty ? 500.0 : hourlyRevenue.values.reduce((a, b) => a > b ? a : b) * 1.3;

    // Order type breakdown
    final standard = _orders.where((o) => o.type == CoreOrderType.standard).length;
    final text = _orders.where((o) => o.type == CoreOrderType.text).length;
    final photo = _orders.where((o) => o.type == CoreOrderType.photo).length;

    return CustomScrollView(slivers: [
      SliverAppBar(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        pinned: true,
        title: const Text('Revenue Analytics', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      SliverPadding(
        padding: const EdgeInsets.all(20),
        sliver: SliverList(delegate: SliverChildListDelegate([
          // Today summary cards
          Row(children: [
            Expanded(child: _miniStat('Today', '₹${_todayRevenue.toStringAsFixed(0)}', const Color(0xFF4F46E5))),
            const SizedBox(width: 12),
            Expanded(child: _miniStat('Total Orders', '${_orders.length}', const Color(0xFF059669))),
            const SizedBox(width: 12),
            Expanded(child: _miniStat('Delivered', '${_orders.where((o) => o.status == CoreOrderStatus.delivered).length}', const Color(0xFFD97706))),
          ]),
          const SizedBox(height: 24),

          // Line chart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Today's Revenue (Hourly)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: LineChart(LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 40, interval: maxY / 4,
                      getTitlesWidget: (v, _) => Text('₹${v.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    )),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, interval: 6,
                      getTitlesWidget: (v, _) {
                        final h = v.toInt();
                        return Text(h == 0 ? '12AM' : h == 12 ? '12PM' : h < 12 ? '${h}AM' : '${h - 12}PM',
                            style: const TextStyle(fontSize: 9, color: Colors.grey));
                      },
                    )),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0, maxX: 23, minY: 0, maxY: maxY > 0 ? maxY : 500,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFF4F46E5),
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [const Color(0xFF4F46E5).withOpacity(0.2), Colors.transparent],
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                )),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Order type breakdown
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Order Type Breakdown', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 16),
              _breakdownRow('🛒 Standard Orders', standard, _orders.length, const Color(0xFF4F46E5)),
              const SizedBox(height: 10),
              _breakdownRow('💬 Text Orders', text, _orders.length, const Color(0xFF7C3AED)),
              const SizedBox(height: 10),
              _breakdownRow('📷 Photo Orders', photo, _orders.length, const Color(0xFFDB2777)),
            ]),
          ),
          const SizedBox(height: 100),
        ])),
      ),
    ]);
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _breakdownRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const Spacer(),
        Text('$count (${(pct * 100).toStringAsFixed(0)}%)',
            style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, backgroundColor: Colors.grey.shade100,
          valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6,
        ),
      ),
    ]);
  }

  // ── Delivery Management (Admin Only) ─────────────────────────────
  Widget _buildDeliveryManagement() {
    final activeOrders = _orders.where((o) =>
      o.status != CoreOrderStatus.delivered && o.status != CoreOrderStatus.cancelled
    ).toList();

    return CustomScrollView(slivers: [
      SliverAppBar(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white, pinned: true,
        expandedHeight: 120,
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            padding: const EdgeInsets.fromLTRB(20, 54, 20, 16),
            child: Row(children: [
              const Text('🚴 Delivery Management', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('${_partners.where((p) => p['status'] == 'Available').length} Available', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ]),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(delegate: SliverChildListDelegate([
          // Partners Summary
          const Text('Delivery Partners', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _partners.length,
              itemBuilder: (_, i) {
                final p = _partners[i];
                final isBusy = p['status'] == 'Busy';
                final assignedCount = _assignedPartners.values.where((v) => v == p['name']).length;
                return Container(
                  width: 130, margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isBusy ? Colors.orange.shade200 : Colors.green.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(radius: 16, backgroundColor: isBusy ? Colors.orange.shade50 : Colors.green.shade50,
                          child: Text(p['name'][0], style: TextStyle(fontWeight: FontWeight.w900, color: isBusy ? Colors.orange.shade700 : Colors.green.shade700))),
                      const Spacer(),
                      Text(p['vehicle'], style: const TextStyle(fontSize: 14)),
                    ]),
                    const SizedBox(height: 6),
                    Text(p['name'].toString().split(' ')[0], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: isBusy ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Text(assignedCount > 0 ? '$assignedCount orders' : p['status'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isBusy ? Colors.orange.shade700 : Colors.green.shade700)),
                    ),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Orders needing assignment
          Row(children: [
            const Text('Active Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('${activeOrders.length}', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 10),
          if (activeOrders.isEmpty)
            _emptyCard('No active orders to assign')
          else
            ...activeOrders.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _orderTile(o, showAssign: true),
            )),
          const SizedBox(height: 80),
        ])),
      ),
    ]);
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Center(child: Column(children: [
        Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ])),
    );
  }

  Color _statusColor(CoreOrderStatus s) {
    switch (s) {
      case CoreOrderStatus.pending: return const Color(0xFFD97706);
      case CoreOrderStatus.accepted:
      case CoreOrderStatus.confirmed:
      case CoreOrderStatus.preparing:
      case CoreOrderStatus.assigned:
      case CoreOrderStatus.ready: return const Color(0xFF4F46E5);
      case CoreOrderStatus.pickedUp:
      case CoreOrderStatus.onTheWay: return const Color(0xFF059669);
      case CoreOrderStatus.delivered: return const Color(0xFF10B981);
      case CoreOrderStatus.cancelled: return Colors.red;
    }
  }
}
