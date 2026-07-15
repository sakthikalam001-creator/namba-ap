import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'driver_verification_screen.dart';
import 'services/admin_service.dart';
import 'services/subscription_service.dart';
import 'services/sync_service.dart';
import 'theme/admin_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SuperAdminDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const SuperAdminDashboard({super.key, required this.user, required this.onLogout});
  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _tab = 0;
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.user['token']}',
  };
  int _selectedVendorIdx = 0;
  int _selectedAdminIdx = 0;
  int _settingsTabIdx = 0;
  String _vendorSearch = '';
  bool _regEnabled = true;
  bool _maintenanceMode = false;
  bool _autoAssign = true;
  double _commissionPct = 5.0;
  int _deliveryRadius = 20;
  double _serviceCenterLat = 11.3410;
  double _serviceCenterLng = 77.7172;
  int _serviceRadius = 20;

  // Admin Permissions Map
  Map<String, bool> _adminPermissions = {
    'Overview': true,
    'Vendors': true,
    'Admins': false,
    'Drivers': true,
    'Verification': false,
    'Dispatch Hub': true,
    'Customer Orders': true,
    'Broadcasts': false,
    'Support Hub': false,
    'Intelligence': false,
    'Security Audit': false,
    'Report Center': false,
    'Settings': false,
    'Subscription Plans': true,
  };

  // Partner Program Toggles
  bool _partnerInsuranceEnabled = true;
  bool _partnerFlexibilityEnabled = true;
  bool _partnerIncentivesEnabled = true;
  bool _partnerWelfareEnabled = true;

  // ── V3 Full Management Suite State ────────────────────────────────
  bool _aiSurgeEnabled = false;
  double _surgeMultiplier = 1.0;

  // Account Settings Controllers
  late TextEditingController _accountNameCtrl;
  late TextEditingController _accountEmailCtrl;
  final TextEditingController _accountPassCtrl = TextEditingController();

  List<Map<String, dynamic>> _supportTickets = [
    {'id': 'T-882', 'user': 'Selvam (Vendor)', 'issue': 'Payment failed for Order #12', 'status': 'Pending', 'priority': 'High', 'time': '5m ago'},
    {'id': 'T-881', 'user': 'Customer #22', 'issue': 'Delivery partner not reachable', 'status': 'Active', 'priority': 'Critical', 'time': '12m ago'},
    {'id': 'T-880', 'user': 'Urban Bakery', 'issue': 'Menu item update pending', 'status': 'Resolved', 'priority': 'Low', 'time': '1h ago'},
  ];
  List<Map<String, dynamic>> _adminAuditLogs = [
    {'action': 'SETTING_UPDATE', 'detail': 'Commission changed to 6.5%', 'user': 'SuperAdmin', 'time': '2m ago'},
    {'action': 'VENDOR_APPROVE', 'detail': 'Approved Fresh Mart', 'user': 'Admin_Karthik', 'time': '15m ago'},
    {'action': 'BROADCAST_SENT', 'detail': 'System maintenance alert', 'user': 'SuperAdmin', 'time': '45m ago'},
  ];
  String _broadcastTarget = 'All'; // 'All', 'Vendors', 'Drivers'

  // ── API State ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> _pendingVendors = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _dispatchOrders = [];
  List<Map<String, dynamic>> _onlineDrivers = [];
  List<Map<String, dynamic>> _pendingDrivers = [];
  List<Map<String, dynamic>> _allDrivers = [];
  List<Map<String, dynamic>> _customerOrders = [];
  List<Map<String, dynamic>> _customerOrderHistory = [];
  List<Map<String, dynamic>> _processedBillOrders = [];
  List<Map<String, dynamic>> _serviceZones = [];
  bool _isPendingLoading = false;
  bool _isVendorsLoading = false;
  bool _isDispatchLoading = false;
  bool _isDriversLoading = false;
  bool _isPendingDriversLoading = false;
  bool _isAdminsLoading = false;
  bool _isCustomerOrdersLoading = false;
  bool _isCustomerHistoryLoading = false;
  bool _isZonesLoading = false;
  List<AdminSubscriptionPlan> _subscriptionPlans = [];
  bool _isPlansLoading = false;
  Map<String, Map<String, dynamic>> _liveRiders = {}; // { riderId: { lat, lng, name, status } }
  io.Socket? _socket;

  // Heatmap State
  List<LatLng> _heatmapOrderPoints = [];
  List<Map<String, dynamic>> _heatmapRiders = [];
  bool _isHeatmapLoading = false;
  final MapController _mapController = MapController();
  Timer? _refreshTimer;
  Map<String, dynamic>? _financialSummary;
  List<dynamic> _financialTrends = [];
  bool _isFinancialLoading = false;
  String? _lastNotifiedOrderId;
  List<Map<String, dynamic>> _topVendors = [];
  List<Map<String, dynamic>> _driverPerformance = [];
  bool _isPerformanceLoading = false;
  List<Map<String, dynamic>> _payouts = [];
  List<Map<String, dynamic>> _auditLog = [];
  bool _isReportsLoading = false;

  static String get _baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://100.53.131.76:5000/api/v1';

  @override
  void initState() {
    super.initState();
    _accountNameCtrl = TextEditingController(text: widget.user['name'] ?? '');
    _accountEmailCtrl = TextEditingController(text: widget.user['email'] ?? '');
    
    // Load per-admin permissions if not superadmin
    if (widget.user['role'] != 'superadmin' && widget.user['permissions'] != null) {
      final userPerms = Map<String, dynamic>.from(widget.user['permissions']);
      userPerms.forEach((key, value) {
        if (_adminPermissions.containsKey(key)) {
          _adminPermissions[key] = value == true;
        }
      });
    }

    _fetchSettings();
    _fetchPendingVendors();
    _fetchAllVendors();
    _fetchDispatchOrders();
    _fetchAvailableDrivers();
    _fetchPendingDrivers();
    _fetchAllDrivers();
    _fetchAllAdmins();
    _fetchCustomerOrders();
    _fetchCustomerOrderHistory();
    _fetchHeatmapData();
    _fetchServiceZones();
    _fetchSubscriptionPlans();
    _fetchFinancialStats();
    _fetchPerformanceAnalytics();
    _fetchReportData();
    _initSocket();
    
    // FAST AUTOMATIC REFRESH - Every 1 second (Blink-free via silent updates)
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _fetchPendingVendors(silent: true);
        _fetchAllVendors(silent: true);
        _fetchDispatchOrders(silent: true);
        _fetchAvailableDrivers(silent: true);
        _fetchPendingDrivers(silent: true);
        _fetchAllDrivers(silent: true);
        _fetchAllAdmins(silent: true);
        _fetchCustomerOrders(silent: true);
        _fetchCustomerOrderHistory(silent: true);
        _fetchServiceZones(silent: true);
        _fetchSubscriptionPlans(silent: true);
        _fetchFinancialStats(silent: true);
        _fetchReportData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _accountNameCtrl.dispose();
    _accountEmailCtrl.dispose();
    _accountPassCtrl.dispose();
    super.dispose();
  }



  Future<void> _fetchSubscriptionPlans({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isPlansLoading = true);
    final plans = await SubscriptionService.getAllPlans();
    if (mounted) {
      setState(() {
        _subscriptionPlans = plans;
        _isPlansLoading = false;
      });
    }
  }

  void _initSocket() {
    try {
      final socketUrl = _baseUrl.replaceAll('/api/v1', '');
      _socket = io.io(socketUrl, io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build());

      _socket!.onConnect((_) => debugPrint('✅ Admin Socket Connected'));

      // Listen for Live Rider Tracking
      _socket!.on('update_rider_location', (data) {
        debugPrint('📍 RIDER LOCATION UPDATE: $data');
        if (mounted) {
          setState(() {
            final rid = data['riderId'];
            _liveRiders[rid] = {
              'lat': (data['lat'] as num?)?.toDouble() ?? 0.0,
              'lng': (data['lng'] as num?)?.toDouble() ?? 0.0,
              'lastUpdate': DateTime.now(),
              'name': data['riderName'] ?? 'Driver #$rid',
              'status': data['status'] ?? 'Active',
            };
          });
        }
      });

      _socket!.on('vendor_status_update', (data) {
        debugPrint('🏪 LIVE VENDOR STATUS UPDATE: $data');
        if (mounted) {
          setState(() {
            final vid = data['vendorId'];
            final isOpen = data['isOpen'];

            // Update vendors list
            final idx = _vendors.indexWhere((v) => v['_id'] == vid);
            if (idx != -1) {
              _vendors[idx]['isOpen'] = isOpen;
            }

            // Update pending vendors list
            final pIdx = _pendingVendors.indexWhere((v) => v['_id'] == vid);
            if (pIdx != -1) {
              _pendingVendors[pIdx]['isOpen'] = isOpen;
            }
          });
        }
      });

      _socket!.on('new_customer_order', (data) {
        debugPrint('🛍️ NEW CUSTOMER ORDER: $data');
        if (mounted) {
          _fetchCustomerOrders();
          
          final orderId = data['orderId']?.toString();
          final notifyKey = 'NEW_$orderId';
          if (notifyKey == _lastNotifiedOrderId) return; 
          _lastNotifiedOrderId = notifyKey;

          final customerName = data['customerName']?.toString() ?? 'A Customer';
          final displayId = data['displayId'] != null ? ' #${data['displayId']}' : '';
          
          final isCustom = data['isCustomOrder'] == true || (data['orderType'] != null && data['orderType'] != 'Cart');
          
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.shopping_basket_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                isCustom 
                  ? 'New Any Shop Order$displayId from $customerName — Please Dispatch'
                  : 'New Customer Order$displayId from $customerName — Waiting for Vendor', 
                style: const TextStyle(fontWeight: FontWeight.w700)
              )),
            ]),
            backgroundColor: isCustom ? const Color(0xFF10B981) : Colors.blue.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'VIEW', 
              textColor: Colors.white, 
              onPressed: () => setState(() => _tab = 5) // Always route to Dispatch Hub (Tab 5)
            ),
          ));
        }
      });

      _socket!.on('new_vendor_payment_request', (data) {
        debugPrint('💸 NEW VENDOR PAYMENT REQUEST: $data');
        if (mounted) {
          _fetchCustomerOrders();
          
          final orderId = data['orderId']?.toString();
          final notifyKey = 'VPAY_$orderId';
          if (notifyKey == _lastNotifiedOrderId) return; 
          _lastNotifiedOrderId = notifyKey;

          final vendorName = data['vendorName']?.toString() ?? 'Vendor';
          final amount = data['amount']?.toString() ?? '0';
          
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('Driver requests ₹$amount payment for $vendorName', style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(label: 'PAY NOW', textColor: Colors.white, onPressed: () => setState(() => _tab = 15)), // Vendor Payments tab is at index 15
          ));
        }
      });
      
      _socket!.on('vendor_payment_update', (data) {
        if (mounted) {
          _fetchCustomerOrders();
        }
      });

      _socket!.on('customer_payment_received', (data) {
        debugPrint('💰 CUSTOMER PAYMENT RECEIVED: $data');
        if (mounted) {
          _fetchCustomerOrders(); // Always refresh order lists to get updated payment status
          
          // Show notification for ALL payment receipts
          final isCustom = data['isCustomOrder'] == true;

          final customerName = data['customerName']?.toString() ?? 'A Customer';
          final amount = data['amount']?.toString() ?? '0';
          final displayId = data['displayId'] != null ? ' #${data['displayId']}' : '';
          
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('₹$amount Received from $customerName (Order$displayId)', style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            backgroundColor: const Color(0xFF059669), // Emerald Green
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(label: 'VIEW', textColor: Colors.white, onPressed: () => setState(() => _tab = 16)), // Index 16 is Customer Payments
          ));
        }
      });

      _socket!.on('new_dispatch_request', (data) {
        debugPrint('🚚 NEW DISPATCH REQUEST: $data');
        if (mounted) {
          _fetchDispatchOrders(silent: true);
          _fetchCustomerOrders(silent: true);
          
          final orderId = data['orderId']?.toString();
          final message = data['message']?.toString() ?? '';
          final notifyKey = 'DISPATCH_${orderId}_$message';
          
          if (notifyKey == _lastNotifiedOrderId) return; 
          _lastNotifiedOrderId = notifyKey;

          final storeName = data['vendorName']?.toString().isNotEmpty == true
              ? data['vendorName']
              : 'A Vendor';
          final displayId = data['displayId'] != null ? ' #${data['displayId']}' : '';
          final isVendorAccepted = data['vendorAccepted'] == true;
          
          final displayMessage = isVendorAccepted 
              ? 'Order Accepted by $storeName — Please Assign Rider'
              : (message.isNotEmpty ? message : 'New dispatch request for $storeName');
          
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              Icon(
                isVendorAccepted ? Icons.store_rounded : Icons.local_shipping_rounded, 
                color: Colors.white, 
                size: 20
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(
                displayMessage + displayId, 
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)
              )),
            ]),
            backgroundColor: isVendorAccepted ? const Color(0xFF6366F1) : const Color(0xFF10B981), // Indigo for Vendor, Green for New
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(20),
            elevation: 8,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'DISPATCH', 
              textColor: Colors.white, 
              onPressed: () => setState(() => _tab = 5)
            ),
          ));
        }
      });

      _socket!.on('dispatch_update', (data) {
        if (mounted) {
          _fetchDispatchOrders();
          _fetchCustomerOrders();

          // Only show notification if it is a driver assignment event
          final msg = data['message']?.toString() ?? '';
          if (msg.contains('Assigned') || msg.contains('Auto-Assigned')) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Successfully assigned delivery partner', style: TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
              backgroundColor: const Color(0xFF10B981), // Green (Emerald)
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ));
          }
        }
      });
      
      _socket!.on('order_update_alert', (data) {
        debugPrint('🔔 LIVE ORDER STATUS UPDATE: $data');
        if (mounted) {
          _fetchCustomerOrders(silent: true);
          _fetchDispatchOrders(silent: true);
        }
      });

      _socket!.on('driver_status_update', (data) {
        debugPrint('🚴 LIVE DRIVER STATUS UPDATE: $data');
        if (mounted) {
          final driverId = data['driverId'];
          final isOnline = data['isOnline'] == true;

          setState(() {
            // Optimistically update ALL DRIVERS list instantly
            final idx = _allDrivers.indexWhere((d) => d['_id'] == driverId);
            if (idx != -1) {
              _allDrivers[idx]['isOnline'] = isOnline;
            }

            // Also refresh API lists in background just to be safe
            _fetchAllDrivers();
            _fetchAvailableDrivers();
          });
        }
      });

      _socket!.on('new_driver_registered', (data) {
        debugPrint('🆕 NEW DRIVER REGISTERED: $data');
        if (mounted) {
          _fetchPendingDrivers();
          _fetchAllDrivers();
        }
      });

      _socket!.on('permission_update', (data) {
        debugPrint('🔐 LIVE PERMISSION UPDATE: $data');
        if (mounted && data['adminId'] == widget.user['_id']) {
          setState(() {
            final perms = Map<String, dynamic>.from(data['permissions']);
            perms.forEach((key, value) {
              if (_adminPermissions.containsKey(key)) {
                _adminPermissions[key] = value == true;
              }
            });

            // Redirect to Overview if current tab is revoked
            final labels = ['Overview', 'Vendors', 'Admins', 'Drivers', 'Verification', 'Dispatch Hub', 'Broadcasts', 'Support Hub', 'Intelligence', 'Security Audit', 'Report Center', 'Settings'];
            final currentLabel = labels[_tab];
            if (_adminPermissions[currentLabel] == false) {
              _tab = 0;
            }
          });
        }
      });

      _socket!.on('settings_update', (data) {
        debugPrint('⚙️ LIVE SETTINGS UPDATE: $data');
        if (mounted) {
          final s = data['settings'];
          setState(() {
            _regEnabled = s['registrationEnabled'] ?? true;
            _autoAssign = s['autoAssign'] ?? true;
            _maintenanceMode = s['maintenanceMode'] ?? false;
            _commissionPct = (s['platformCommissionPct'] ?? 5.0).toDouble();
            _deliveryRadius = (s['maxDispatchRadiusKm'] ?? 10).toInt();
            _partnerInsuranceEnabled = s['partnerInsuranceEnabled'] ?? true;
            _partnerFlexibilityEnabled = s['partnerFlexibilityEnabled'] ?? true;
            _partnerIncentivesEnabled = s['partnerIncentivesEnabled'] ?? true;
            _partnerWelfareEnabled = s['partnerWelfareEnabled'] ?? true;

            // Map global permissions to local state
            if (s['adminPermissions'] != null) {
              final p = s['adminPermissions'];
              final Map<String, String> keyMap = {
                'overview': 'Overview', 'vendors': 'Vendors', 'admins': 'Admins',
                'drivers': 'Drivers', 'verification': 'Verification', 'dispatch': 'Dispatch Hub',
                'broadcasts': 'Broadcasts', 'support': 'Support Hub', 'intelligence': 'Intelligence',
                'security': 'Security Audit', 'reports': 'Report Center', 'settings': 'Settings'
              };
              keyMap.forEach((apiKey, label) {
                if (p.containsKey(apiKey)) {
                  _adminPermissions[label] = p[apiKey] == true;
                }
              });
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error initializing socket: $e');
    }
  }



  Future<void> _fetchAllVendors({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isVendorsLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/vendors'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _vendors = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching vendors: $e');
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load vendors: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted && !silent) setState(() => _isVendorsLoading = false);
    }
  }

  Future<void> _fetchPendingVendors({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isPendingLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/vendors/pending'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _pendingVendors = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching pending vendors: $e');
      if (mounted && !silent) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load pending vendors: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted && !silent) setState(() => _isPendingLoading = false);
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/settings'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final s = data['data'];
        if (mounted) {
          setState(() {
            _autoAssign = s['autoAssign'] ?? true;
            _maintenanceMode = s['maintenanceMode'] ?? false;
            _commissionPct = (s['platformCommissionPct'] ?? 5.0).toDouble();
            _deliveryRadius = (s['maxDispatchRadiusKm'] ?? 10).toInt();
            _partnerInsuranceEnabled = s['partnerInsuranceEnabled'] ?? true;
            _partnerFlexibilityEnabled = s['partnerFlexibilityEnabled'] ?? true;
            _partnerIncentivesEnabled = s['partnerIncentivesEnabled'] ?? true;
            _partnerWelfareEnabled = s['partnerWelfareEnabled'] ?? true;
            _serviceCenterLat = (s['serviceCenterLat'] ?? 11.3410).toDouble();
            _serviceCenterLng = (s['serviceCenterLng'] ?? 77.7172).toDouble();
            _serviceRadius = (s['maxServiceRadiusKm'] ?? 20).toInt();
            
            // Map backend permissions to frontend labels
            if (s['adminPermissions'] != null) {
              final p = s['adminPermissions'];
              _adminPermissions = {
                'Overview': p['overview'] ?? true,
                'Vendors': p['vendors'] ?? true,
                'Admins': p['admins'] ?? false,
                'Drivers': p['drivers'] ?? true,
                'Verification': p['verification'] ?? false,
                'Dispatch Hub': p['dispatch'] ?? true,
                'Broadcasts': p['broadcasts'] ?? false,
                'Support Hub': p['support'] ?? false,
                'Intelligence': p['intelligence'] ?? false,
                'Security Audit': p['security'] ?? false,
                'Report Center': p['reports'] ?? false,
                'Settings': p['settings'] ?? false,
              };
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
    }
  }

  Future<void> _fetchServiceZones({bool silent = false}) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/zones'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _serviceZones = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching zones: $e');
    }
  }

  Future<void> _addServiceZone(Map<String, dynamic> zone) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/zones'),
        headers: _headers,
        body: jsonEncode(zone),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchServiceZones();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service Zone Added!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Error adding zone: $e');
    }
  }

  Future<void> _deleteServiceZone(String id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/admin/zones/$id'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchServiceZones();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zone Deleted'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint('Error deleting zone: $e');
    }
  }

  Future<void> _toggleZoneStatus(String id, bool status) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/zones/$id'),
        headers: _headers,
        body: jsonEncode({'isActive': status}),
      );
      if (response.statusCode == 200) _fetchServiceZones();
    } catch (e) {
      debugPrint('Error toggling zone: $e');
    }
  }

  Future<void> _fetchAllAdmins({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isAdminsLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/admins'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _admins = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching admins: $e');
    } finally {
      if (mounted && !silent) setState(() => _isAdminsLoading = false);
    }
  }

  Future<void> _provisionAdmin(Map<String, dynamic> adminData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/admins'),
        headers: _headers,
        body: jsonEncode(adminData),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchAllAdmins();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${adminData['name']} provisioned as Admin!'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        throw data['error'] ?? 'Provisioning failed';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _resetAdminPassword(String id, String password) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/admins/$id/reset-password'),
        headers: _headers,
        body: jsonEncode({'password': password}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password reset successful!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        throw data['error'] ?? 'Reset failed';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _toggleAdminRole(Map<String, dynamic> adminData) async {
    final actId = adminData['_id'];
    final newRole = adminData['role'] == 'superadmin' ? 'admin' : 'superadmin';
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/admins/$actId/role'),
        headers: _headers,
        body: jsonEncode({'role': newRole}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchAllAdmins();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${adminData['name']} role updated to $newRole!'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        throw data['error'] ?? 'Role update failed';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _updateSettings(Map<String, dynamic> body) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/settings'),
        headers: _headers,
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchSettings();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Platform settings updated!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('Error updating settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update: Backend server is unreachable!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _fetchHeatmapData() async {
    if (mounted) setState(() => _isHeatmapLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/heatmap'), headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final orders = data['data']['orders'] as List;
          final riders = data['data']['riders'] as List;

          if (mounted) {
            setState(() {
              _heatmapOrderPoints = orders.map((o) => LatLng((o['lat'] as num?)?.toDouble() ?? 0.0, (o['lng'] as num?)?.toDouble() ?? 0.0)).toList();
              _heatmapRiders = riders.map((r) => r as Map<String, dynamic>).toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Heatmap Error: $e');
    } finally {
      if (mounted) setState(() => _isHeatmapLoading = false);
    }
  }

  Future<void> _approveVendor(String id) async {
    try {
      final response = await http.put(Uri.parse('$_baseUrl/admin/vendors/$id/approve'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchPendingVendors();
        _fetchAllVendors();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vendor Approved Successfully!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      debugPrint('Error approving vendor: $e');
    }
  }

  Future<void> _rejectVendor(String id, String reason) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/vendors/$id/reject'),
        headers: _headers,
        body: jsonEncode({'reason': reason}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchPendingVendors();
        _fetchAllVendors();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vendor Rejected.'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      debugPrint('Error rejecting vendor: $e');
    }
  }

  Future<void> _fetchDispatchOrders({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isDispatchLoading = true);
    try {
      // 1. Fetch from API
      final response = await http.get(Uri.parse('$_baseUrl/admin/dispatch/orders'), headers: _headers);
      final data = jsonDecode(response.body);
      List<Map<String, dynamic>> apiOrders = [];
      if (data['success'] == true) {
        apiOrders = List<Map<String, dynamic>>.from(data['data']);
      }

      // 2. Fetch from Local Sync (Shared DB) for local simulation testing
      List<Map<String, dynamic>> localOrders = [];
      if (LocalSyncService.isEnabled) {
        final local = await LocalSyncService.getAllOrders();
        localOrders = local.where((o) => 
          o.status != CoreOrderStatus.delivered && 
          o.status != CoreOrderStatus.cancelled
        ).map((o) {
          final m = o.toMap();
          // Normalize local data types for UI compatibility
          m['status'] = o.status.name.substring(0, 1).toUpperCase() + o.status.name.substring(1);
          if (m['status'] == 'OnTheWay') m['status'] = 'OutForDelivery';
          
          m['orderType'] = o.type == CoreOrderType.text ? 'Text' : (o.type == CoreOrderType.photo ? 'Photo' : 'Standard');
          m['createdAt'] = o.createdAt.toIso8601String();
          m['displayId'] = o.id.substring(0, 6);
          m['isLocal'] = true; // Mark as local for manual dispatch logic
          
          // Calculate financial breakdown if missing (for simulation)
          final double totalVal = (o.total > 10.0) ? o.total.toDouble() : 450.0;
          m['totalAmount'] = totalVal;
          m['deliveryCharge'] = (totalVal > 100) ? 40.0 : 0.0;
          m['tax'] = (totalVal * 0.05).roundToDouble();
          m['subTotal'] = (totalVal - m['deliveryCharge'] - m['tax']).clamp(0.0, totalVal);
          m['platformFee'] = (totalVal * 0.05).roundToDouble();
          m['paymentStatus'] = o.customerPaid ? 'Completed' : 'Pending';
          final pm = o.paymentMethod.toUpperCase();
          m['paymentMethod'] = (pm == 'ONLINE' || pm == 'UPI' || pm == 'RAZORPAY' || pm == 'ONLINE PAYMENT') 
              ? 'Online Payment' 
              : 'Cash on Delivery';

          // Map local 'store' to API 'vendor' structure
          m['vendor'] = {
            'storeName': o.store.name,
            'address': 'Anna Nagar, Chennai',
            'category': o.store.category,
            'contact': '+91 98765 43210',
          };
          
          // Ensure customer exists as a map
          m['customer'] = {
            'name': 'Sakthi (Guest)',
            'phone': '+91 9123456789',
          };
          
          m['deliveryAddressFormatted'] = '123, Main Street, Chennai - 600040';

          return m;
        }).toList();
      }

      // 3. Merge and De-duplicate (Prioritize API orders)
      final merged = [...apiOrders];
      final apiIds = apiOrders.map((o) => o['_id']?.toString() ?? o['id']?.toString()).toSet();
      
      for (var lo in localOrders) {
        final lid = lo['_id']?.toString() ?? lo['id']?.toString();
        if (!apiIds.contains(lid)) {
          merged.add(lo);
        }
      }

      if (mounted) {
        setState(() {
          _dispatchOrders = merged;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dispatch orders: $e');
    } finally {
      if (mounted && !silent) setState(() => _isDispatchLoading = false);
    }
  }

  Future<void> _fetchCustomerOrders({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isCustomerOrdersLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/orders/customer'), headers: _headers);
      final data = jsonDecode(response.body);
      List<Map<String, dynamic>> apiOrders = [];
      if (data['success'] == true) {
        apiOrders = List<Map<String, dynamic>>.from(data['data']);
      }

      // Merge with local if enabled
      final merged = [...apiOrders];
      if (LocalSyncService.isEnabled) {
        final apiIds = apiOrders.map((o) => o['_id']?.toString() ?? o['id']?.toString()).toSet();
        final local = await LocalSyncService.getAllOrders();
        for (var lo in local) {
          final lid = lo.id;
          if (!apiIds.contains(lid)) {
            final m = lo.toMap();
            m['status'] = lo.status.name.substring(0, 1).toUpperCase() + lo.status.name.substring(1);
            m['orderType'] = lo.type == CoreOrderType.text ? 'Text' : (lo.type == CoreOrderType.photo ? 'Photo' : 'Standard');
            m['createdAt'] = lo.createdAt.toIso8601String();
            m['displayId'] = lo.id.substring(0, 6);
            
            final double totalVal = (lo.total > 10.0) ? lo.total.toDouble() : 450.0;
            m['totalAmount'] = totalVal;
            m['deliveryCharge'] = (totalVal > 100) ? 40.0 : 0.0;
            m['tax'] = (totalVal * 0.05).roundToDouble();
            m['subTotal'] = (totalVal - m['deliveryCharge'] - m['tax']).clamp(0.0, totalVal);
            m['paymentStatus'] = lo.customerPaid ? 'Completed' : 'Pending';
            final pm = lo.paymentMethod.toUpperCase();
            m['paymentMethod'] = (pm == 'ONLINE' || pm == 'UPI' || pm == 'RAZORPAY' || pm == 'ONLINE PAYMENT') 
                ? 'Online Payment' 
                : 'Cash on Delivery';
            
            m['vendor'] = {
              'storeName': lo.store.name,
              'address': 'Anna Nagar, Chennai',
              'category': lo.store.category,
              'contact': '+91 98765 43210',
            };
            
            m['customer'] = {
              'name': 'Sakthi (Guest)',
              'phone': '+91 9123456789',
            };
            
            m['deliveryAddressFormatted'] = '123, Main Street, Chennai - 600040';
            
            merged.add(m);
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _customerOrders = merged;
          _updateProcessedBills();
        });
      }
    } catch (e) {
      debugPrint('Error fetching customer orders: $e');
    } finally {
      if (mounted && !silent) setState(() => _isCustomerOrdersLoading = false);
    }
  }

  Future<void> _fetchCustomerOrderHistory({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isCustomerHistoryLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/orders/customer/history'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _customerOrderHistory = List<Map<String, dynamic>>.from(data['data']);
          });
          _updateProcessedBills();
        }
      }
    } catch (e) {
      debugPrint('Error fetching customer order history: $e');
    } finally {
      if (mounted && !silent) setState(() => _isCustomerHistoryLoading = false);
    }
  }

  void _updateProcessedBills() {
    // Perform filtering safely, NO SORTING to avoid hangs
    final active = List<Map<String, dynamic>>.from(_customerOrders);
    final history = List<Map<String, dynamic>>.from(_customerOrderHistory);
    final all = [...active, ...history];
    
    final bills = all.where((o) => 
      o != null && 
      o is Map &&
      o['billPhotoPath'] != null && 
      o['billPhotoPath'].toString().isNotEmpty
    ).toList();

    if (mounted) {
      setState(() {
        _processedBillOrders = bills;
      });
    }
  }

  Future<void> _fetchAvailableDrivers({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isDriversLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/dispatch/drivers'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _onlineDrivers = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching available drivers: $e');
    } finally {
      if (mounted && !silent) setState(() => _isDriversLoading = false);
    }
  }

  Future<void> _assignDriver(String orderId, String driverId) async {
    try {
      final driver = _allDrivers.firstWhere((d) => d['_id'] == driverId, orElse: () => {});
      final order = _dispatchOrders.firstWhere((o) => o['id'] == orderId || o['_id'] == orderId, orElse: () => {});
      
      if (order['isLocal'] == true) {
        await LocalSyncService.assignDriver(orderId, driver);
        _fetchDispatchOrders();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Driver assigned (Local Sync)!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/admin/dispatch/assign'),
        headers: _headers,
        body: jsonEncode({
          'orderId': orderId,
          'driverId': driverId,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchDispatchOrders();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Driver assigned successfully!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('Error assigning driver: $e');
    }
  }

  Future<void> _unassignDriver(String orderId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unassign Partner', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to unassign the current delivery partner from this order? The order will be placed back into the awaiting queue.', style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.put(Uri.parse('$_baseUrl/admin/dispatch/unassign/$orderId'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchDispatchOrders();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Partner unassigned successfully!'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      debugPrint('Error unassigning driver: $e');
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Order', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.red)),
        content: Text('Are you absolutely sure you want to cancel this order? This action cannot be undone and will notify the customer and vendor.', style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Wait, No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.put(Uri.parse('$_baseUrl/admin/orders/$orderId/cancel'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchCustomerOrders();
        _fetchDispatchOrders();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order Cancelled!'),
          backgroundColor: Colors.red,
        ));
        // Also close order detail modal if it's open
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error cancelling order: $e');
    }
  }

  // ── DRIVER MANAGEMENT ─────────────────────────────────────────────────
  Future<void> _fetchPendingDrivers({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isPendingDriversLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/drivers/pending'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) setState(() => _pendingDrivers = List<Map<String, dynamic>>.from(data['data']));
      }
    } catch (e) {
      debugPrint('Error fetching pending drivers: $e');
    } finally {
      if (mounted && !silent) setState(() => _isPendingDriversLoading = false);
    }
  }

  Future<void> _fetchAllDrivers({bool silent = false}) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/drivers'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) setState(() => _allDrivers = List<Map<String, dynamic>>.from(data['data']));
      }
    } catch (e) {
      debugPrint('Error fetching all drivers: $e');
    }
  }

  Future<void> _approveDriver(String id) async {
    try {
      final response = await http.put(Uri.parse('$_baseUrl/admin/drivers/$id/approve'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchPendingDrivers();
        _fetchAllDrivers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Driver Approved! They will be notified instantly.'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('Error approving driver: $e');
    }
  }

  Future<void> _forceOfflineDriver(String id) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/auth/driver-status'),
        headers: _headers,
        body: jsonEncode({'driverId': id, 'isOnline': false}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchAllDrivers();
        _fetchAvailableDrivers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🛑 Driver forced to Offline.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('Error forcing driver offline: $e');
    }
  }

  Future<void> _rejectDriver(String id, String reason) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/drivers/$id/reject'),
        headers: _headers,
        body: jsonEncode({'reason': reason}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchPendingDrivers();
        _fetchAllDrivers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Driver application rejected.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('Error rejecting driver: $e');
    }
  }

  void _showRejectDriverDialog(String driverId, String driverName) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Reject Application', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Provide a reason for rejecting $driverName\'s application:', style: GoogleFonts.outfit(color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. Incomplete documents, invalid license...',
              hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectDriver(driverId, reasonCtrl.text.trim().isEmpty ? 'Does not meet platform requirements.' : reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Reject', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _admins = [];

  double get _totalRevenue => _vendors.fold(0.0, (s, v) => s + (double.tryParse(v['revenue']?.toString() ?? '0') ?? 0.0));
  int get _totalOrders => _vendors.fold(0, (s, v) => s + (int.tryParse(v['orders']?.toString() ?? '0') ?? 0));
  int get _activeVendors => _vendors.where((v) => (v['status'] ?? v['approvalStatus']) == 'Active' || (v['status'] ?? v['approvalStatus']) == 'approved').length;
  double get _commission => _totalRevenue * 0.05;



  Future<void> _updateVendorAccess({
    required String vendorId,
    bool? isLocked,
    String? lockReason,
    DateTime? trialExpiry,
    DateTime? subscriptionExpiry,
    bool? isSubscribed,
    bool? showSubscriptionBadge,
    Map<String, bool>? permissions,
  }) async {
    try {
      final body = {
        if (isLocked != null) 'isLocked': isLocked,
        if (lockReason != null) 'lockReason': lockReason,
        if (trialExpiry != null) 'trialExpiry': trialExpiry.toIso8601String(),
        if (subscriptionExpiry != null) 'subscriptionExpiry': subscriptionExpiry.toIso8601String(),
        if (isSubscribed != null) 'isSubscribed': isSubscribed,
        if (showSubscriptionBadge != null) 'showSubscriptionBadge': showSubscriptionBadge,
        if (permissions != null) 'permissions': permissions,
      };

      final response = await http.put(
        Uri.parse('$_baseUrl/admin/vendors/$vendorId/access'),
        headers: _headers,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchAllVendors(); // Refresh the list
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Vendor access updated successfully!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        throw Exception(data['error'] ?? 'Update failed');
      }
    } catch (e) {
      debugPrint('Error updating vendor access: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Error: ${e.toString()}'),
        backgroundColor: AdminColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showVendorAccessDialog(Map<String, dynamic> vendor) {
    bool isLocked = vendor['isLocked'] ?? false;
    final reasonCtrl = TextEditingController(text: vendor['lockReason'] ?? '');
    DateTime? trialExp = vendor['trialExpiry'] != null ? DateTime.parse(vendor['trialExpiry']) : null;
    DateTime? subExp = vendor['subscriptionExpiry'] != null ? DateTime.parse(vendor['subscriptionExpiry']) : null;
    bool showBadge = vendor['showSubscriptionBadge'] ?? true;

    // Feature Permissions
    Map<String, dynamic> perms = vendor['permissions'] ?? {};
    bool allowAutoAccept = perms['allowAutoAccept'] ?? false;
    bool allowSurgeBoost = perms['allowSurgeBoost'] ?? false;
    bool allowExtraWait = perms['allowExtraWait'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Row(
            children: [
              const Icon(Icons.security_rounded, color: AdminColors.primaryIndigo),
              const SizedBox(width: 12),
              Text('Manage Access', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vendor: ${vendor['storeName'] ?? 'Unnamed'}', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 24),
                
                // Lock Toggle
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ACCOUNT LOCK', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: isLocked ? Colors.red : Colors.green, letterSpacing: 1)),
                          Text(isLocked ? 'Access Restricted' : 'Access Active', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                        ],
                      ),
                    ),
                    Switch(
                      value: isLocked,
                      onChanged: (v) => setModalState(() => isLocked = v),
                      activeColor: Colors.red,
                    ),
                  ],
                ),
                if (isLocked) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      labelText: 'Lock Reason',
                      hintText: 'e.g., Pending documents, Non-payment...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.info_outline_rounded),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // FEATURE PERMISSIONS SECTION
                Text('FEATURE PERMISSIONS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: AdminColors.primaryIndigo, letterSpacing: 1)),
                const SizedBox(height: 16),
                
                // Auto Accept
                _permissionToggle(
                  title: 'Auto-Accept Orders',
                  subtitle: 'Allow vendor to automatically accept new orders',
                  icon: Icons.auto_awesome_rounded,
                  value: allowAutoAccept,
                  onChanged: (v) => setModalState(() => allowAutoAccept = v),
                ),
                const SizedBox(height: 12),
                
                // Surge Boost
                _permissionToggle(
                  title: 'Surge Boost',
                  subtitle: 'Allow vendor to enable surge pricing during peak hours',
                  icon: Icons.bolt_rounded,
                  value: allowSurgeBoost,
                  onChanged: (v) => setModalState(() => allowSurgeBoost = v),
                ),
                const SizedBox(height: 12),
                
                // +10m Wait
                _permissionToggle(
                  title: '+10m Wait Time',
                  subtitle: 'Allow vendor to request 10 mins extra preparation time',
                  icon: Icons.more_time_rounded,
                  value: allowExtraWait,
                  onChanged: (v) => setModalState(() => allowExtraWait = v),
                ),

                const SizedBox(height: 32),
                
                // Trial Management
                Text('TRIAL PERIOD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trialExp != null ? 'Expires: ${DateFormat('dd MMM, yyyy').format(trialExp!)}' : 'No trial set',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: trialExp ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setModalState(() => trialExp = picked);
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [7, 30, 90].map((days) => ActionChip(
                    label: Text('+$days Days', style: const TextStyle(fontSize: 10)),
                    onPressed: () => setModalState(() => trialExp = (trialExp ?? DateTime.now()).add(Duration(days: days))),
                  )).toList(),
                ),
                const SizedBox(height: 24),

                // Subscription Management
                Text('SUBSCRIPTION PLAN', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subExp != null ? 'Valid Until: ${DateFormat('dd MMM, yyyy').format(subExp!)}' : 'No active subscription',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_month_rounded, color: AdminColors.primaryIndigo),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: subExp ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setModalState(() => subExp = picked);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Display Settings (Super Admin Only)
                Text('DISPLAY SETTINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Show Status Badge', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('Toggles TRIAL/PRO/INACTIVE badge visibility', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                        ],
                      ),
                    ),
                    Switch(
                      value: showBadge,
                      onChanged: (v) => setModalState(() => showBadge = v),
                      activeColor: AdminColors.primaryIndigo,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateVendorAccess(
                  vendorId: vendor['_id'],
                  isLocked: isLocked,
                  lockReason: reasonCtrl.text,
                  trialExpiry: trialExp,
                  subscriptionExpiry: subExp,
                  showSubscriptionBadge: showBadge,
                  permissions: {
                    'allowAutoAccept': allowAutoAccept,
                    'allowSurgeBoost': allowSurgeBoost,
                    'allowExtraWait': allowExtraWait,
                  },
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Apply Changes', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchReportData({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isReportsLoading = true);
    try {
      final res = await http.get(Uri.parse('$_baseUrl/admin/financial-analytics/reports'), headers: _headers);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success']) {
          if (mounted) {
            setState(() {
              _payouts = List<Map<String, dynamic>>.from(body['data']['payouts']);
              _auditLog = List<Map<String, dynamic>>.from(body['data']['auditLog']);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching report data: $e');
    } finally {
      if (mounted && !silent) setState(() => _isReportsLoading = false);
    }
  }

  IconData _getAuditIcon(String iconStr) {
    switch (iconStr) {
      case 'Storage': return Icons.storage_rounded;
      case 'Verified': return Icons.verified_user_rounded;
      case 'Security': return Icons.security_rounded;
      case 'Settings': return Icons.settings_suggest_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  Color _getAuditColor(String colorStr) {
    switch (colorStr) {
      case 'Blue': return Colors.blue;
      case 'Green': return Colors.green;
      case 'Orange': return Colors.orange;
      case 'Indigo': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  Widget _getTabWidget() {
    switch (_tab) {
      case 0: return _buildOverview();
      case 1: return _buildVendors();
      case 2: return _buildAdmins();
      case 3: return _buildDriversTab();
      case 4: return const DriverVerificationScreen();
      case 5: return _buildDispatch();
      case 6: return _buildLiveTrackingTab();
      case 7: return _buildCustomerOrdersTab();
      case 8: return _buildBroadcastCenter();
      case 9: return _buildSupportHub();
      case 10: return _buildMarketIntelligence();
      case 11: return _buildSecurityAudit();
      case 12: return _buildReports();
      case 13: return _buildSettings();
      case 14: return _buildPlansTab();
      case 15: return _buildVendorPaymentsTab();
      case 16: return _buildCustomerPaymentsTab();
      case 17: return OrderBillsHubView(
                processedBills: _processedBillOrders,
                isLoading: _isCustomerOrdersLoading || _isCustomerHistoryLoading,
                onRefresh: () { _fetchCustomerOrders(); _fetchCustomerOrderHistory(); },
                onViewOrder: (order) => _showOrderDetails(order),
                onPreviewImage: (url, title) => _showImagePreviewDialog(url, title),
                baseUrl: _baseUrl,
              );
      case 18: return _buildFinancialIntelligence();
      default: return _buildOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: KeyedSubtree(key: ValueKey(_tab), child: _getTabWidget())),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final items = [
      {'icon': Icons.grid_view_rounded, 'label': 'Overview'},
      {'icon': Icons.storefront_rounded, 'label': 'Vendors'},
      {'icon': Icons.admin_panel_settings_rounded, 'label': 'Admins'},
      {'icon': Icons.two_wheeler_rounded, 'label': 'Drivers'},
      {'icon': Icons.verified_rounded, 'label': 'Verification'},
      {'icon': Icons.radar_rounded, 'label': 'Dispatch Hub'},
      {'icon': Icons.map_rounded, 'label': 'Live Tracking'},
      {'icon': Icons.shopping_basket_rounded, 'label': 'Customer Orders'},
      {'icon': Icons.campaign_rounded, 'label': 'Broadcasts'},
      {'icon': Icons.support_agent_rounded, 'label': 'Support Hub'},
      {'icon': Icons.insights_rounded, 'label': 'Intelligence'},
      {'icon': Icons.verified_user_rounded, 'label': 'Security Audit'},
      {'icon': Icons.analytics_outlined, 'label': 'Report Center'},
      {'icon': Icons.tune_rounded, 'label': 'Settings'},
      {'icon': Icons.card_membership_rounded, 'label': 'Subscription Plans'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Vendor Payments'},
      {'icon': Icons.payments_rounded, 'label': 'Customer Payments'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Order Bills'},
      {'icon': Icons.paid_rounded, 'label': 'Financial IQ'},
    ];

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: AdminColors.sidebarBg,
      ),
      child: Column(
        children: [
          // PRO BRANDING HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminColors.primaryIndigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.primaryIndigo.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.shield_rounded, color: AdminColors.primaryIndigo, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('NAMBA', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.user['role'] == 'superadmin' ? Colors.amber.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.user['role'] == 'superadmin' ? 'SYSTEM EXECUTIVE' : 'STAFF ACCESS',
                    style: GoogleFonts.outfit(
                      color: widget.user['role'] == 'superadmin' ? AdminColors.warning : AdminColors.info,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildPulseIndicator(),
              ],
            ),
          ),

          const Divider(color: Colors.white12, indent: 24, endIndent: 24),
          const SizedBox(height: 16),

          // MENU ITEMS
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final active = _tab == i;
                final label = items[i]['label']?.toString() ?? '';
                
                // ROLE BASED FILTERING
                if (widget.user['role'] != 'superadmin' && _adminPermissions[label] == false) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: InkWell(
                  onTap: () {
                    setState(() => _tab = i);
                    // EXPLICIT TRIGGER - Only if not already loading
                    if (label == 'Order Bills' && !_isCustomerOrdersLoading) {
                      _fetchCustomerOrders();
                      _fetchCustomerOrderHistory();
                    }
                  },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: active ? Colors.white.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: active ? Border.all(color: Colors.white12) : null,
                      ),
                      child: Row(
                        children: [
                          Icon(items[i]['icon'] is IconData ? (items[i]['icon'] as IconData) : Icons.info, size: 22,
                              color: active ? AdminColors.primaryIndigo : Colors.grey.shade600),
                          const SizedBox(width: 16),
                          Text(
                            items[i]['label']?.toString() ?? '',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                              color: active ? Colors.white : Colors.grey.shade500,
                            ),
                          ),
                          const Spacer(),
                          if (active)
                            Container(width: 4, height: 16, decoration: BoxDecoration(color: AdminColors.primaryIndigo, borderRadius: BorderRadius.circular(2))),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ADMIN PROFILE SECTION
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black12,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AdminColors.primaryIndigo,
                  child: Text(
                    widget.user['name'] != null && widget.user['name'].toString().isNotEmpty 
                        ? widget.user['name'].toString()[0].toUpperCase() 
                        : '?', 
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 12)
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.user['name'].toString(), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(widget.user['email']?.toString() ?? '', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      Text('Online', style: TextStyle(color: Colors.green.shade400, fontSize: 10)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white38, size: 18),
                  tooltip: 'End Session',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulsingDot(),
          const SizedBox(width: 10),
          Text('SYSTEM PULSE', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // ── DRIVERS MANAGEMENT TAB ─────────────────────────────────────────────
  Widget _buildDriversTab() {
    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(40, 48, 40, 32),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DELIVERY PARTNERS', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('Driver Management', style: GoogleFonts.outfit(color: AdminColors.textHeading, fontWeight: FontWeight.w900, fontSize: 32)),
                ]),
                const Spacer(),
                _driverStatChip('PENDING', _pendingDrivers.length.toString(), Colors.orange),
                const SizedBox(width: 24),
                _driverStatChip('TOTAL', _allDrivers.length.toString(), AdminColors.primaryIndigo),
                const SizedBox(width: 24),
                _driverStatChip('ACTIVE', _allDrivers.where((d) => d['isOnline'] == true).length.toString(), Colors.green),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: () { _fetchPendingDrivers(); _fetchAllDrivers(); },
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7C3AED)),
                  style: IconButton.styleFrom(backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1), padding: const EdgeInsets.all(12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── PENDING APPLICATIONS ─────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 16),
                        const SizedBox(width: 6),
                        Text('PENDING APPLICATIONS', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Text('${_pendingDrivers.length} waiting for review', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13)),
                  ]),
                  const SizedBox(height: 20),
                  _isPendingDriversLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _pendingDrivers.isEmpty
                          ? _buildDriverEmptyState('No Pending Applications', 'All driver applications have been reviewed.')
                          : Column(
                              children: _pendingDrivers.map((driver) => _buildPendingDriverCard(driver)).toList(),
                            ),
                  const SizedBox(height: 40),

                  // ── ALL DRIVERS ──────────────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Icon(Icons.two_wheeler_rounded, color: Color(0xFF7C3AED), size: 16),
                        const SizedBox(width: 6),
                        Text('ALL DELIVERY PARTNERS', style: GoogleFonts.outfit(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _allDrivers.isEmpty
                      ? _buildDriverEmptyState('No Drivers Yet', 'Drivers will appear here once they register.')
                      : _buildAllDriversTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverStatChip(String label, String count, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(count, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1)),
    ]);
  }

  Widget _buildPendingDriverCard(Map<String, dynamic> driver) {
    final vehicleIcons = {'bike': '🏍️', 'scooter': '🛵', 'bicycle': '🚲', 'car': '🚗', 'auto': '🛺'};
    final vehicleEmoji = vehicleIcons[driver['vehicleType'] ?? 'bike'] ?? '🏍️';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        // Orange left accent
        Container(width: 6, height: 120, color: Colors.orange),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.orange.withOpacity(0.1),
                child: Text(
                  (driver['name'] as String? ?? 'D').substring(0, 1).toUpperCase(),
                  style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 22),
                ),
              ),
              const SizedBox(width: 20),
              // Driver Info
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(driver['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: AdminColors.textHeading)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('PENDING', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 10)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('📞 ${driver['phone'] ?? 'N/A'}', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Text('$vehicleEmoji ${(driver['vehicleType'] as String? ?? 'bike').toUpperCase()} • ${driver['vehicleNumber'] ?? 'N/A'} • License: ${driver['licenseNumber'] ?? 'N/A'}',
                    style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
              ])),
              // Action Buttons
              Column(children: [
                SizedBox(
                  width: 130,
                  child: ElevatedButton.icon(
                    onPressed: () => _approveDriver(driver['_id']),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text('Approve', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 130,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDriverDialog(driver['_id'], driver['name'] ?? 'Driver'),
                    icon: const Icon(Icons.cancel_rounded, size: 16),
                    label: Text('Reject', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildAllDriversTable() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: AdminColors.background,
          child: Row(children: [
            Expanded(flex: 3, child: Text('DRIVER', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
            Expanded(flex: 2, child: Text('VEHICLE', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
            Expanded(flex: 1, child: Text('ORDERS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
            Expanded(flex: 1, child: Text('DECLINED', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
            Expanded(flex: 1, child: Text('DAYS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
            Expanded(flex: 1, child: Text('STATUS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
            Expanded(flex: 1, child: Text('ONLINE', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _allDrivers.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
          itemBuilder: (context, i) {
            final d = _allDrivers[i];
            final status = d['driverApprovalStatus'] ?? 'pending';
            final isOnline = d['isOnline'] == true;
            Color statusColor = status == 'approved' ? const Color(0xFF059669) : (status == 'rejected' ? Colors.redAccent : Colors.orange);
            return InkWell(
              onTap: () => _showDriverProfile(d),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(children: [
                  Expanded(flex: 3, child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1),
                      child: Text((d['name'] as String? ?? 'D').substring(0, 1).toUpperCase(), style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['name'] ?? 'N/A', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: AdminColors.textHeading)),
                      Text(d['phone'] ?? 'N/A', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 12)),
                    ]),
                  ])),
                  Expanded(flex: 2, child: Text('${(d['vehicleType'] as String? ?? '').toUpperCase()}\n${d['vehicleNumber'] ?? 'N/A'}', style: GoogleFonts.outfit(fontSize: 13, color: AdminColors.textHeading))),
                  Expanded(flex: 1, child: Text(d['deliveryCount']?.toString() ?? '0', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF059669)))),
                  Expanded(flex: 1, child: Text(d['declinedCount']?.toString() ?? '0', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.redAccent))),
                  Expanded(flex: 1, child: Text('${d['daysWorked']?.toString() ?? '0'}d', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo))),
                  Expanded(flex: 1, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(status.toUpperCase(), style: GoogleFonts.outfit(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10)),
                  )),
                  Expanded(flex: 1, child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? Colors.green : Colors.grey.shade300)),
                    const SizedBox(width: 6),
                    Text(isOnline ? 'Online' : 'Offline', style: GoogleFonts.outfit(fontSize: 12, color: isOnline ? Colors.green : Colors.grey.shade400)),
                    if (isOnline) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _forceOfflineDriver(d['_id']),
                        child: Icon(Icons.power_settings_new_rounded, size: 14, color: Colors.redAccent.withOpacity(0.5)),
                      ),
                    ],
                  ])),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildDriverEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.two_wheeler_rounded, size: 56, color: Colors.grey.shade200),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.grey.shade400)),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade300, fontSize: 13)),
      ])),
    );
  }


  // ── DISPATCH (TACTICAL COMMAND HUB) ───────────────────────────────────
  Widget _buildDispatch() {
    final Map<String, Map<String, dynamic>> dispatchHistoryMap = {};
    for (var o in _customerOrderHistory) {
      final id = o['_id']?.toString() ?? o['displayId']?.toString() ?? '';
      if (id.isNotEmpty) dispatchHistoryMap[id] = o;
    }
    // Also include Delivered/Cancelled from active dispatch list
    for (var o in _dispatchOrders) {
      final s = o['status']?.toString().toLowerCase() ?? '';
      if (s == 'delivered' || s == 'cancelled') {
        final id = o['_id']?.toString() ?? o['displayId']?.toString() ?? '';
        if (id.isNotEmpty) dispatchHistoryMap[id] = o;
      }
    }
    final dispatchHistory = dispatchHistoryMap.values.toList();
    final liveDispatchOrders = _dispatchOrders.where((o) => o['status']?.toString().toLowerCase() != 'delivered' && o['status']?.toString().toLowerCase() != 'cancelled').toList();

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTacticalHeader(),
          Expanded(
            child: (_isDispatchLoading && _dispatchOrders.isEmpty) 
                ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 60, top: 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(40, 24, 40, 16),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              const Icon(Icons.route_rounded, color: Colors.orange, size: 16),
                              const SizedBox(width: 6),
                              Text('LIVE DISPATCH QUEUE', style: GoogleFonts.outfit(color: Colors.orange.shade700, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                            ]),
                          ),
                        ]),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: liveDispatchOrders.isEmpty 
                            ? _buildEmptyDispatchState()
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: liveDispatchOrders.length,
                                itemBuilder: (context, index) => _buildTacticalOrderCard(liveDispatchOrders[index]),
                              ),
                      ),

                      const SizedBox(height: 60),

                      // DISPATCH HISTORY SECTION
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              const Icon(Icons.history_rounded, color: AdminColors.primaryIndigo, size: 16),
                              const SizedBox(width: 6),
                              Text('DISPATCH LOGS (HISTORY)', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                            ]),
                          ),
                          const Spacer(),
                          IconButton(onPressed: _fetchCustomerOrderHistory, icon: const Icon(Icons.refresh_rounded, size: 20, color: AdminColors.primaryIndigo)),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: (_isCustomerHistoryLoading && dispatchHistory.isEmpty)
                            ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo))
                            : dispatchHistory.isEmpty
                                ? _buildEmptyStateMini('No Logistics History', 'Completed or cancelled assignments will appear here.')
                                : _buildHistoryTable(dispatchHistory),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingTab() {
    // Fallback to Chennai center if no riders active
    final centerLat = _liveRiders.isNotEmpty ? (_liveRiders.values.first['lat'] as num?)?.toDouble() ?? 13.0827 : 13.0827;
    final centerLng = _liveRiders.isNotEmpty ? (_liveRiders.values.first['lng'] as num?)?.toDouble() ?? 80.2707 : 80.2707;

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('LIVE TRACKING', 'Global Delivery Pulse'),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(centerLat, centerLng),
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.namba.admin',
                    ),
                    MarkerLayer(
                      markers: _liveRiders.entries.map((e) {
                        final data = e.value;
                        final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
                        final lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
                        
                        return Marker(
                          point: LatLng(lat, lng),
                          width: 120,
                          height: 120,
                          child: _RadarNode(name: data['name'] ?? 'RIDER', status: data['status'] ?? 'Active'),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                
                // Overlay HUD
                Positioned(
                  top: 32, left: 32,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _PulsingDot(),
                        const SizedBox(width: 12),
                        Text('ACTIVE PARTNERS: ${_liveRiders.length}', 
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: AdminColors.textHeading, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),

                // Map Legend / Theme Switcher mockup area
                Positioned(
                  bottom: 32, left: 32,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.layers_outlined, color: AdminColors.primaryIndigo, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDispatchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade100)),
              child: Icon(Icons.radar_rounded, size: 80, color: Colors.grey.shade200),
            ),
            const SizedBox(height: 32),
            Text('Dispatch Queue காலியாக உள்ளது', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey.shade400)),
            Text('தற்போது எந்த ஆர்டரும் இல்லை.', style: TextStyle(color: Colors.grey.shade300, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('REAL-TIME LOGISTICS', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text('Dispatch Control Centre', style: GoogleFonts.outfit(color: AdminColors.textHeading, fontWeight: FontWeight.w900, fontSize: 32)),
            ],
          ),
          const Spacer(),
          _statusCounter('AWAITING', _dispatchOrders.length.toString(), Colors.orange),
          const SizedBox(width: 24),
          _statusCounter('ACTIVE DRIVERS', _onlineDrivers.length.toString(), Colors.green),
          const SizedBox(width: 32),
          IconButton(
            onPressed: () { _fetchDispatchOrders(); _fetchAvailableDrivers(); },
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7C3AED)),
            style: IconButton.styleFrom(backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1), padding: const EdgeInsets.all(12)),
          ),
        ],
      ),
    );
  }

  Widget _statusCounter(String label, String count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(count, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1)),
      ],
    );
  }
  Widget _buildTacticalOrderCard(Map<String, dynamic> order) {
    final driver = order['driver'];
    final isAssigned = driver != null;
    final isCustom = order['isCustomStore'] == true;
    final status = order['status']?.toString() ?? 'Pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 12, color: isAssigned ? const Color(0xFF10B981) : AdminColors.primaryIndigo),
            Expanded(
              child: InkWell(
                onTap: () => _showOrderDetailSheet(order),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                       Row(
                        children: [
                          Text('TRACKING ID: #${order['displayId']}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.textHeading, fontSize: 14)),
                          const SizedBox(width: 12),
                          _buildOrderTypeBadge(order['orderType'] ?? 'Cart'),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: (isAssigned ? Colors.green : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text(isAssigned ? status.toUpperCase() : 'AWAITING ASSIGNMENT', style: GoogleFonts.outfit(color: isAssigned ? Colors.green.shade700 : Colors.orange.shade800, fontWeight: FontWeight.w900, fontSize: 10)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('STATUS: ', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontWeight: FontWeight.w800, fontSize: 10)),
                          Text(status.toUpperCase(), style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 10)),
                          if (isCustom) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.purple.shade100)),
                              child: Text('PERSONAL ASSISTANT', style: GoogleFonts.outfit(color: Colors.purple, fontWeight: FontWeight.w900, fontSize: 8)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          _locationNode('PICKUP FROM', order['vendor']?['storeName'] ?? 'Vendor', Icons.store_rounded),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Icon(Icons.keyboard_double_arrow_right_rounded, color: Colors.grey, size: 24)),
                          _locationNode('DELIVER TO', order['customer']?['name'] ?? 'Customer', Icons.person_pin_circle_rounded),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          if (isAssigned) ...[
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ASSIGNED PARTNER', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  Text('${driver['name']} (${driver['vehicleNumber'] ?? 'N/A'})', style: GoogleFonts.outfit(color: AdminColors.textHeading, fontSize: 13, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ] else ...[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CONTENT SUMMARY', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatItemsSummary(order),
                                    style: GoogleFonts.outfit(color: AdminColors.textHeading, fontSize: 13, fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(order['createdAt'] != null ? DateFormat('hh:mm a').format(DateTime.parse(order['createdAt'])) : 'Ongoing', 
                                style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 13)),
                              Text('ORDER TIME', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded, size: 12, color: Colors.grey.shade300),
                          const SizedBox(width: 4),
                          Text('விவரங்கள் பார்க்க click செய்யுங்கள்', style: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, color: Colors.grey.shade100),
            Container(
              width: 250,
              padding: const EdgeInsets.all(32),
              color: AdminColors.background,
              child: isAssigned 
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('PARTNER CALL', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Text(driver['phone'] ?? 'N/A', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.sidebarBg)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text('LIVE TRACKING', style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 10)),
                      ),
                    ],
                  )
                : ElevatedButton(
                    onPressed: () => _showAssignDriverSheet(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.sidebarBg,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('MANUAL DISPATCH', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatItemsSummary(Map<String, dynamic> order) {
    final type = order['orderType'] ?? 'Cart';
    if (type == 'Text') return '📝 manual list: ${order['textContent'] ?? 'No text provided'}';
    if (type == 'Photo') return '🖼️ Photo Order (check details)';
    final isCustom = order['isCustomStore'] == true;
    final vendorName = isCustom ? (order['customStoreName'] ?? 'Personal Assistant') : (order['vendor']?['storeName'] ?? 'Vendor');
    final vendorAddress = isCustom ? (order['customStoreAddress'] ?? 'Custom Pickup') : (order['vendor']?['address'] ?? 'N/A');

    final items = order['items'];
    if (items == null) return 'No items';
    final list = items as List?;
    if (list == null || list.isEmpty) return 'No items found';
    return list.take(3).map((item) {
      if (item is Map) {
        final name = item['productName']?.toString() ?? item['name']?.toString() ?? 'Item';
        final qty = item['quantity']?.toString() ?? '1';
        return '$name ×$qty';
      }
      return item.toString();
    }).join(', ') + (list.length > 3 ? ' +${list.length - 3} more' : '');
  }

  void _showOrderDetailSheet(Map<String, dynamic> order) {
    final driver = order['driver'];
    final isAssigned = driver != null;
    final status = order['status']?.toString() ?? 'Pending';
    final items = (order['items'] as List?) ?? [];
    final vendorName = order['vendor']?['storeName'] ?? 'Vendor';
    final customerName = order['customer']?['name'] ?? 'Customer';
    final customerPhone = order['customer']?['phone'] ?? 'N/A';

    // Vendor status label
    String vendorStatus = 'Unknown';
    Color vendorStatusColor = Colors.grey;
    IconData vendorStatusIcon = Icons.hourglass_empty_rounded;
    if (status == 'Pending') {
      vendorStatus = 'Received order — Awaiting preparation';
      vendorStatusColor = Colors.orange;
      vendorStatusIcon = Icons.inbox_rounded;
    } else if (status == 'Accepted') {
      vendorStatus = 'Order accepted — Preparing now';
      vendorStatusColor = Colors.blue;
      vendorStatusIcon = Icons.restaurant_rounded;
    } else if (status == 'Preparing') {
      vendorStatus = 'Packing / Preparing items';
      vendorStatusColor = Colors.indigo;
      vendorStatusIcon = Icons.shopping_bag_rounded;
    } else if (status.contains('Ready')) {
      vendorStatus = 'Ready for Handover — Awaiting Partner pickup';
      vendorStatusColor = Colors.green.shade700;
      vendorStatusIcon = Icons.check_circle_rounded;
    } else if (status == 'PickedUp') {
      vendorStatus = 'Picked up by delivery partner ✓';
      vendorStatusColor = const Color(0xFF10B981);
      vendorStatusIcon = Icons.done_all_rounded;
    } else if (status == 'OutForDelivery') {
      vendorStatus = 'Out for delivery';
      vendorStatusColor = const Color(0xFF10B981);
      vendorStatusIcon = Icons.local_shipping_rounded;
    } else if (status == 'Delivered') {
      vendorStatus = 'Delivered successfully ✓';
      vendorStatusColor = Colors.green;
      vendorStatusIcon = Icons.verified_rounded;
    }

    // Driver status label
    String driverStatus = 'No partner assigned yet';
    Color driverStatusColor = Colors.orange;
    IconData driverStatusIcon = Icons.person_search_rounded;
    if (isAssigned) {
      if (status == 'Assigned') {
        driverStatus = 'Heading to vendor for pickup';
        driverStatusColor = Colors.blue;
        driverStatusIcon = Icons.directions_bike_rounded;
      } else if (status == 'PickedUp') {
        driverStatus = 'Package picked up — En route to customer';
        driverStatusColor = Colors.indigo;
        driverStatusIcon = Icons.two_wheeler_rounded;
      } else if (status == 'OutForDelivery') {
        driverStatus = 'Out for delivery 🚴';
        driverStatusColor = const Color(0xFF10B981);
        driverStatusIcon = Icons.delivery_dining_rounded;
      } else if (status == 'Delivered') {
        driverStatus = 'Delivered successfully ✓';
        driverStatusColor = Colors.green;
        driverStatusIcon = Icons.task_alt_rounded;
      } else {
        driverStatus = 'Assigned — Awaiting pickup';
        driverStatusColor = Colors.orange;
        driverStatusIcon = Icons.pending_rounded;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.receipt_long_rounded, color: AdminColors.primaryIndigo, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order Details', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
                        Text('Order #${order['displayId']} • $customerName', style: GoogleFonts.outfit(color: AdminColors.textSub, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: (isAssigned ? Colors.green : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(isAssigned ? status.toUpperCase() : 'AWAITING',
                      style: GoogleFonts.outfit(color: isAssigned ? Colors.green.shade700 : Colors.orange.shade800, fontWeight: FontWeight.w900, fontSize: 10)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // ── Items / Content Section ─────────────────────────────
                  _buildOrderContentSection(order),
                  const SizedBox(height: 16),
                  // ── Vendor Status ────────────────────────────────────────
                  _detailSection(
                    icon: Icons.storefront_rounded,
                    iconColor: Colors.blue.shade700,
                    title: 'Vendor Status',
                    badge: vendorName,
                    badgeColor: Colors.blue.shade700,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: vendorStatusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: Icon(vendorStatusIcon, color: vendorStatusColor, size: 22),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Current Status', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(vendorStatus, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: vendorStatusColor)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(width: double.infinity, padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              Icon(Icons.store_rounded, size: 16, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Text('Shop: $vendorName', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Delivery Partner Status ──────────────────────────────
                  _detailSection(
                    icon: Icons.delivery_dining_rounded,
                    iconColor: isAssigned ? const Color(0xFF10B981) : Colors.orange.shade700,
                    title: 'Delivery Partner Status',
                    badge: isAssigned ? (driver['name'] ?? 'Partner') : 'Not Assigned',
                    badgeColor: isAssigned ? const Color(0xFF10B981) : Colors.orange.shade700,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: isAssigned
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: driverStatusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                    child: Icon(driverStatusIcon, color: driverStatusColor, size: 22),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Current Status', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        Text(driverStatus, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: driverStatusColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _driverInfoRow(Icons.person_rounded, 'Name', driver['name'] ?? 'N/A'),
                              const SizedBox(height: 8),
                              _driverInfoRow(Icons.phone_rounded, 'Phone', driver['phone'] ?? 'N/A'),
                              const SizedBox(height: 8),
                              _driverInfoRow(Icons.two_wheeler_rounded, 'Vehicle Type', driver['vehicleType'] ?? 'N/A'),
                              const SizedBox(height: 8),
                              _driverInfoRow(Icons.badge_rounded, 'Vehicle No.', driver['vehicleNumber'] ?? 'N/A'),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _unassignDriver(order['_id']);
                                  },
                                  icon: const Icon(Icons.person_remove_rounded, size: 18),
                                  label: Text('UNASSIGN PARTNER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange.shade700,
                                    side: BorderSide(color: Colors.orange.shade700),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Container(
                                width: double.infinity, padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade100)),
                                child: Column(
                                  children: [
                                    Icon(Icons.person_search_rounded, size: 40, color: Colors.orange.shade400),
                                    const SizedBox(height: 12),
                                    Text('No delivery partner assigned yet',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.orange.shade700, fontSize: 13), textAlign: TextAlign.center),
                                    const SizedBox(height: 8),
                                    Text('Use Manual Dispatch or wait for Auto-Assign',
                                      style: TextStyle(color: Colors.orange.shade400, fontSize: 11), textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () { Navigator.pop(context); _showAssignDriverSheet(order); },
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text('இப்போதே Assign செய்யுங்கள்', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                                  style: ElevatedButton.styleFrom(backgroundColor: AdminColors.sidebarBg, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Customer Info ────────────────────────────────────────
                  _detailSection(
                    icon: Icons.person_rounded,
                    iconColor: Colors.purple.shade600,
                    title: 'Customer Info',
                    badge: customerPhone,
                    badgeColor: Colors.purple.shade600,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _driverInfoRow(Icons.person_outline_rounded, 'Name', customerName),
                          const SizedBox(height: 8),
                          _driverInfoRow(Icons.phone_android_rounded, 'Phone', customerPhone),
                          if (order['isCustomStore'] != true && order['totalAmount'] != null && order['totalAmount'] > 0) ...[
                            const SizedBox(height: 8),
                            _driverInfoRow(Icons.currency_rupee_rounded, 'Consolidated Total', '₹${order['totalAmount']}', color: Colors.green.shade700),
                            const SizedBox(height: 8),
                            _driverInfoRow(Icons.store_rounded, 'Vendor Value', '₹${((order['totalAmount'] ?? 0) - (order['deliveryCharge'] ?? 0) - (order['platformFee'] ?? (order['totalAmount'] * 0.05))).toStringAsFixed(2)}', color: Colors.blue.shade700),
                            const SizedBox(height: 8),
                            _driverInfoRow(Icons.delivery_dining_rounded, 'Delivery Charge', '₹${order['deliveryCharge'] ?? 0}'),
                            const SizedBox(height: 8),
                            _driverInfoRow(Icons.account_balance_wallet_rounded, 'Platform Yield (5%)', '₹${(order['platformFee'] ?? (order['totalAmount'] * 0.05)).toStringAsFixed(2)}'),
                          ],
                          if (order['isCustomStore'] != true && order['paymentMethod'] != null) ...[
                            const SizedBox(height: 8),
                            _buildPaymentRow(order['paymentMethod'].toString()),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Don't pop context yet, let the confirmation dialog handle it.
                        _cancelOrder(order['_id']);
                      },
                      icon: const Icon(Icons.cancel_rounded, size: 18),
                      label: Text('CANCEL ORDER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTypeBadge(String? type) {
    Color color = Colors.blue;
    String label = 'NEW ORDER';
    IconData icon = Icons.shopping_basket_rounded;

    if (type == 'Text') {
      color = Colors.orange;
      label = 'TEXT ORDER';
      icon = Icons.edit_note_rounded;
    } else if (type == 'Photo') {
      color = Colors.purple;
      label = 'PHOTO ORDER';
      icon = Icons.camera_alt_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildOrderContentSection(Map<String, dynamic> order) {
    final type = order['orderType'] ?? 'Cart';
    final items = (order['items'] as List?) ?? [];

    if (type == 'Text' && order['isCustomStore'] == true) {
      return Column(
        children: [
          _detailSection(
            icon: Icons.description_rounded,
            iconColor: Colors.purple,
            title: 'Manual Text Order',
            badge: 'Instructions',
            badgeColor: Colors.purple,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple.withOpacity(0.1))),
                child: Text(
                  order['textContent'] ?? 'No text provided by customer',
                  style: GoogleFonts.outfit(fontSize: 15, height: 1.5, color: AdminColors.textHeading, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          if (order['totalAmount'] != null && order['totalAmount'] > 0) ...[
            const SizedBox(height: 16),
            _buildVendorQuoteSection(order),
          ],
        ],
      );
    }

    if (type == 'Photo') {
      return Column(
        children: [
          _detailSection(
            icon: Icons.image_rounded,
            iconColor: Colors.orange,
            title: 'Photo Reference',
            badge: 'Order List',
            badgeColor: Colors.orange,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (order['photoUrl'] != null && order['photoUrl'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        order['photoUrl'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(height: 200, color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator())),
                        errorBuilder: (ctx, err, stack) => Container(
                          height: 200, color: Colors.grey.shade100, 
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.broken_image_rounded, color: Colors.grey.shade400, size: 40), const SizedBox(height: 12), Text('Failed to load image', style: TextStyle(color: Colors.grey.shade400))]),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 150, width: double.infinity, alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Text('No photo provided', style: TextStyle(color: Colors.grey.shade400)),
                    ),
                  const SizedBox(height: 12),
                  Text('வாடிக்கையாளர் அனுப்பிய லிஸ்ட் படத்தை மேலே பார்க்கலாம்', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
          if (order['totalAmount'] != null && order['totalAmount'] > 0) ...[
            const SizedBox(height: 16),
            _buildVendorQuoteSection(order),
          ],
        ],
      );
    }

    // Default: Cart items
    return _detailSection(
      icon: Icons.shopping_basket_rounded,
      iconColor: AdminColors.primaryIndigo,
      title: 'Order Items',
      badge: '${items.length} item${items.length == 1 ? '' : 's'}',
      badgeColor: AdminColors.primaryIndigo,
      child: items.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              type == 'Text' 
                ? (order['textContent'] ?? 'No instructions provided') 
                : 'பொருட்கள் எதுவும் இல்லை', 
              style: GoogleFonts.outfit(
                color: type == 'Text' ? AdminColors.textHeading : Colors.grey.shade400, 
                fontStyle: type == 'Text' ? FontStyle.normal : FontStyle.italic,
                fontWeight: type == 'Text' ? FontWeight.w600 : FontWeight.normal
              )
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                String itemName = 'Item ${i + 1}';
                String itemQty = '1';
                double? itemPrice;
                if (item is Map) {
                  // Handle both flat and nested structure
                  final product = item['product'];
                  if (product is Map) {
                    itemName = product['name']?.toString() ?? itemName;
                    itemPrice = (product['price'] as num?)?.toDouble();
                  } else {
                    itemName = item['productName']?.toString() ?? item['name']?.toString() ?? itemName;
                    itemPrice = (item['price'] as num?)?.toDouble();
                  }
                  itemQty = item['quantity']?.toString() ?? '1';
                } else {
                  itemName = item.toString();
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text('${i + 1}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo, fontSize: 13))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(itemName, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: AdminColors.textHeading))),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                            child: Text('Qty: $itemQty', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo, fontSize: 12)),
                          ),
                          if (itemPrice != null) ...[
                            const SizedBox(height: 4),
                            Text('₹${itemPrice.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey.shade600, fontSize: 11)),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
    );
  }

  Widget _buildVendorQuoteSection(Map<String, dynamic> order) {
    final amount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final delivery = (order['deliveryCharge'] as num?)?.toDouble() ?? 0.0;
    final platformFee = (order['platformFee'] as num?)?.toDouble() ?? (amount * 0.05);

    return _detailSection(
      icon: Icons.receipt_long_rounded,
      iconColor: Colors.green.shade700,
      title: 'VENDOR QUOTE',
      badge: 'PRICE RECEIVED',
      badgeColor: Colors.green.shade700,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _driverInfoRow(Icons.payments_rounded, 'Order Total', '₹$amount', color: Colors.green.shade700),
            const Divider(height: 24),
            _driverInfoRow(Icons.delivery_dining_rounded, 'Delivery Charge', '₹$delivery'),
            const SizedBox(height: 8),
            _driverInfoRow(Icons.account_balance_wallet_rounded, 'Platform Fee (5%)', '₹${platformFee.toStringAsFixed(2)}'),
            const Divider(height: 24),
            Row(
              children: [
                Text('VENDOR EARNINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.grey.shade600)),
                const Spacer(),
                Text('₹${(amount - platformFee).toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationNode(String tag, String name, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 14, color: Colors.grey.shade400), const SizedBox(width: 8), Text(tag, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500))]),
          const SizedBox(height: 8),
          Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: AdminColors.textHeading)),
        ],
      ),
    );
  }

  Widget _detailSection({required IconData icon, required Color iconColor, required String title, required String badge, required Color badgeColor, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 18)),
                const SizedBox(width: 12),
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: AdminColors.textHeading)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: badgeColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(badge, style: GoogleFonts.outfit(color: badgeColor, fontWeight: FontWeight.w800, fontSize: 10))),
              ],
            ),
          ),
          Container(height: 1, color: Colors.grey.shade100),
          child,
        ],
      ),
    );
  }

  Widget _driverInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade500),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: color ?? AdminColors.textHeading)),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String method) {
    final m = method.toUpperCase();
    final isOnline = m == 'UPI' || m == 'CARD' || m == 'ONLINE';
    final displayLabel = isOnline ? 'Online Payment' : 'Cash on Delivery';
    final displayCode = ' ($m)';
    final color = isOnline ? AdminColors.primaryIndigo : Colors.green.shade600;
    final icon = isOnline ? Icons.language_rounded : Icons.money_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.15))),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text('Payment Method', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: displayLabel, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: color)),
                TextSpan(text: displayCode, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 11, color: color.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerOrdersTab() {
    // Merge all available orders to ensure no data is missed during status transitions
    final Map<String, Map<String, dynamic>> allOrdersMap = {};
    for (var o in _customerOrders) {
      final id = o['_id']?.toString() ?? o['displayId']?.toString() ?? '';
      if (id.isNotEmpty) allOrdersMap[id] = o;
    }
    for (var o in _customerOrderHistory) {
      final id = o['_id']?.toString() ?? o['displayId']?.toString() ?? '';
      if (id.isNotEmpty) allOrdersMap[id] = o;
    }

    final liveOrders = allOrdersMap.values.where((o) {
      final s = o['status']?.toString() ?? '';
      return s != 'Delivered' && s != 'Cancelled';
    }).toList();

    final historyOrders = allOrdersMap.values.where((o) {
      final s = o['status']?.toString() ?? '';
      return s == 'Delivered' || s == 'Cancelled' || s == 'HandedOver' || s == 'Rejected';
    }).toList();
    
    // Add local orders that are finalized to history
    LocalSyncService.getAllOrders().then((locals) {
      if (mounted) {
        bool changed = false;
        for (var lo in locals) {
          if (lo.status == CoreOrderStatus.delivered || lo.status == CoreOrderStatus.cancelled) {
             final id = lo.id;
             if (!allOrdersMap.containsKey(id)) {
               // This would require a setState but since we are inside build, 
               // it's better to have merged them before.
             }
          }
        }
      }
    });

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('LIVE FEED', 'Customer Orders Hub'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(40),
              children: [
                // ── LIVE FEED SECTION ──────────────────────────────────
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.bolt_rounded, color: Colors.blue, size: 16),
                      const SizedBox(width: 6),
                      Text('LIVE ORDERS', style: GoogleFonts.outfit(color: Colors.blue.shade700, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                    ]),
                  ),
                  const Spacer(),
                  IconButton(onPressed: _fetchCustomerOrders, icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.blue)),
                ]),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _isCustomerOrdersLoading
                      ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo))
                      : liveOrders.isEmpty
                          ? _buildEmptyStateMini('No New Orders', 'Waiting for new customer orders...')
                          : Column(children: liveOrders.map((o) => _buildCustomerOrderCard(o)).toList()),
                ),

                const SizedBox(height: 60),

                // ── HISTORY SECTION ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Icon(Icons.history_rounded, color: AdminColors.primaryIndigo, size: 16),
                        const SizedBox(width: 6),
                        Text('ORDER HISTORY', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                      ]),
                    ),
                    const Spacer(),
                    IconButton(onPressed: _fetchCustomerOrderHistory, icon: const Icon(Icons.refresh_rounded, size: 20, color: AdminColors.primaryIndigo)),
                  ]),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _isCustomerHistoryLoading
                      ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo))
                      : historyOrders.isEmpty
                          ? _buildEmptyStateMini('History Empty', 'Finalized orders will appear here.')
                          : _buildHistoryTable(historyOrders),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateMini(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.grey.shade400)),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHistoryTable(List<Map<String, dynamic>> orders) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 20, offset: const Offset(0, 10))]),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(1),
          5: FlexColumnWidth(1),
          6: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade50),
            children: ['ORDER ID', 'CUSTOMER', 'VENDOR', 'DRIVER', 'AMOUNT', 'STATUS', 'DATE'].map((h) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(h, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1)),
            )).toList(),
          ),
          ...orders.map((o) => TableRow(
            children: [
              _interactiveCell(o, Text('#${o['displayId'] ?? 'N/A'}', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13))),
              _interactiveCell(o, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o['customer']?['name'] ?? 'Guest', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(o['customer']?['phone'] ?? '', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
              ])),
              _interactiveCell(o, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o['isCustomStore'] == true ? (o['customStoreName'] ?? 'Any Store') : (o['vendor']?['storeName'] ?? 'Unknown'), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(o['isCustomStore'] == true ? 'Personal Assistant' : (o['vendor']?['category'] ?? ''), style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
              ])),
              _interactiveCell(o, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o['driver']?['name'] ?? 'Unassigned', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: o['driver'] != null ? AdminColors.success : Colors.grey)),
                if (o['driver'] != null) Text('${o['driver']?['vehicleNumber'] ?? ''}', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
              ])),
              _interactiveCell(o, Text('₹${o['totalAmount']}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: AdminColors.textHeading))),
              _interactiveCell(o, Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _statusBadge(o['status'] ?? 'Unknown'),
                  const SizedBox(height: 6),
                  _paymentStatusBadge(o['paymentStatus'] ?? 'Pending'),
                ],
              )),
              _interactiveCell(o, Text(o['updatedAt'] != null ? DateFormat('MMM dd, hh:mm').format(DateTime.parse(o['updatedAt'])) : 'N/A', style: TextStyle(color: Colors.grey.shade500, fontSize: 11))),
            ],
          )).toList(),
        ],
      ),
    );
  }

  Widget _tableCell(Widget child) => Padding(padding: const EdgeInsets.all(24), child: child);
  
  Widget _interactiveCell(Map<String, dynamic> o, Widget child) {
    return TableCell(
      child: InkWell(
        onTap: () => _showOrderDetails(o),
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    );
  }

  Widget _statusBadge(String status) {
    // Normalizing status string for comparison
    final normalized = status.trim().toLowerCase();
    
    Color color;
    String displayStatus = status;

    if (normalized == 'delivered') {
      color = Colors.green;
      displayStatus = 'Delivered';
    } else if (normalized == 'cancelled' || normalized == 'rejected') {
      color = Colors.red;
      displayStatus = 'Cancelled';
    } else if (normalized == 'accepted') {
      color = Colors.blue;
      displayStatus = 'Accepted';
    } else if (normalized == 'ready' || normalized == 'prepared') {
      color = Colors.teal;
      displayStatus = 'Ready';
    } else if (normalized == 'pending') {
      color = Colors.orange;
      displayStatus = 'Pending';
    } else if (normalized == 'picked up' || normalized == 'in transit') {
      color = Colors.indigo;
      displayStatus = 'In Transit';
    } else {
      color = Colors.grey;
      displayStatus = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(displayStatus.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }

  Widget _paymentStatusBadge(String status) {
    final normalized = status.trim().toLowerCase();
    Color color;
    IconData icon;
    
    if (normalized == 'completed' || normalized == 'success') {
      color = Colors.green;
      icon = Icons.verified_rounded;
    } else if (normalized == 'failed') {
      color = Colors.red;
      icon = Icons.error_outline_rounded;
    } else if (normalized == 'pending') {
      color = Colors.orange;
      icon = Icons.hourglass_empty_rounded;
    } else {
      color = Colors.grey;
      icon = Icons.payments_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text('PAYMENT: ${status.toUpperCase()}', style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildCustomerOrderCard(Map<String, dynamic> order) {
    final orderType = order['orderType'] ?? 'Standard';
    final textSnippet = order['textContent'] != null && order['textContent'].toString().length > 50 
        ? '${order['textContent'].toString().substring(0, 47)}...' 
        : order['textContent'];

    return InkWell(
      onTap: () => _showOrderDetails(order),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderTypeBadge(orderType),
                const SizedBox(height: 16),
                Text('Order #${order['displayId'] ?? 'N/A'}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 24)),
                Text(order['createdAt'] != null ? DateFormat('MMM dd, hh:mm a').format(DateTime.parse(order['createdAt'].toString())) : 'Recently', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 48),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _orderDetailMini(Icons.person_rounded, 'CUSTOMER', order['customer']?['name'] ?? 'Guest'),
                      const SizedBox(width: 32),
                      _orderDetailMini(Icons.storefront_rounded, 'VENDOR', order['isCustomStore'] == true ? (order['customStoreName'] ?? 'Any Store') : (order['vendor']?['storeName'] ?? 'Unknown')),
                      const SizedBox(width: 32),
                      _orderDetailMini(Icons.payments_rounded, 'AMOUNT', '₹${order['totalAmount']}'),
                    ],
                  ),
                  if (orderType == 'Text' && textSnippet != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text('Note: "$textSnippet"', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 13)),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusBadge(order['status'] ?? 'Pending'),
                const SizedBox(height: 8),
                _paymentStatusBadge(order['paymentStatus'] ?? 'Pending'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDriverProfile(Map<String, dynamic> driver) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        final docs = driver['documents'] ?? {};
        final selfie = docs['selfie']?['front'];
        final aadhaarFront = docs['aadhaar']?['front'];
        final aadhaarBack = docs['aadhaar']?['back'];
        final licenseFront = docs['license']?['front'];
        final licenseBack = docs['license']?['back'];

        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.height * 0.85,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AdminColors.background,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 20))],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AdminColors.primaryIndigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                            image: selfie != null 
                              ? DecorationImage(
                                  image: NetworkImage('${_baseUrl.split('/api').first}$selfie'),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          ),
                          child: selfie == null 
                            ? Icon(Icons.person_rounded, size: 48, color: AdminColors.primaryIndigo.withOpacity(0.5))
                            : null,
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driver['driverApprovalStatus']?.toString().toUpperCase() ?? 'PENDING', 
                                style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                              const SizedBox(height: 8),
                              Text(driver['name'] ?? 'N/A', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 32, color: AdminColors.textHeading)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone_rounded, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 8),
                                  Text(driver['phone'] ?? 'N/A', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 24),
                                  Icon(Icons.email_rounded, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 8),
                                  Text(driver['email'] ?? 'N/A', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 28, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          // Top Row: Stats & Vehicle
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _detailSectionCard('Performance Overview', Icons.analytics_rounded, [
                                  Row(
                                    children: [
                                      _driverMiniStat('TOTAL ORDERS', driver['deliveryCount']?.toString() ?? '0', Colors.green),
                                      _driverMiniStat('ATTENDANCE', '${driver['daysWorked']?.toString() ?? '0'}d', AdminColors.primaryIndigo),
                                      _driverMiniStat('RATING', '⭐ ${driver['rating']?.toString() ?? '4.8'}', Colors.orange),
                                    ],
                                  ),
                                ]),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: _detailSectionCard('Vehicle Information', Icons.directions_bike_rounded, [
                                  _detailRow('Vehicle Type', (driver['vehicleType'] ?? 'N/A').toUpperCase()),
                                  _detailRow('Vehicle Number', driver['vehicleNumber'] ?? 'N/A'),
                                ]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Documents Section
                          _detailSectionCard('Identification Documents', Icons.badge_rounded, [
                            Row(
                              children: [
                                // Aadhaar
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('AADHAAR CARD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade400, letterSpacing: 1)),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _docThumbnail('FRONT', aadhaarFront),
                                          const SizedBox(width: 12),
                                          _docThumbnail('BACK', aadhaarBack),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 32),
                                // License
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('DRIVING LICENSE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade400, letterSpacing: 1)),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _docThumbnail('FRONT', licenseFront),
                                          const SizedBox(width: 12),
                                          _docThumbnail('BACK', licenseBack),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _driverMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: color.withOpacity(0.6), letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _docThumbnail(String label, String? path) {
    final fullUrl = path != null ? '${_baseUrl.split('/api').first}$path' : null;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              if (fullUrl != null) _showImagePreviewDialog(fullUrl, 'Driver Document - $label');
            },
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: AdminColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
                image: fullUrl != null 
                  ? DecorationImage(image: NetworkImage(fullUrl), fit: BoxFit.cover)
                  : null,
              ),
              child: fullUrl == null 
                ? Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade300))
                : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.85,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AdminColors.background,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 20))],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ORDER DETAILS', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                          const SizedBox(height: 4),
                          Text('Order #${order['displayId'] ?? 'N/A'}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 32, color: AdminColors.textHeading)),
                        ],
                      ),
                      const Spacer(),
                      _statusBadge(order['status'] ?? 'Pending'),
                      const SizedBox(width: 24),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 28, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Customer & Vendor info
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _detailSectionCard('Customer Details', Icons.person_rounded, [
                                _detailRow('Name', order['customer']?['name'] ?? 'Guest'),
                                _detailRow('Phone', order['customer']?['phone'] ?? 'N/A'),
                                _detailRow('Address', order['deliveryAddressFormatted'] ?? 'N/A'),
                              ]),
                              const SizedBox(height: 24),
                              _detailSectionCard('Vendor Details', Icons.storefront_rounded, [
                                _detailRow('Store Name', order['isCustomStore'] == true ? (order['customStoreName'] ?? 'Any Store') : (order['vendor']?['storeName'] ?? 'Unknown')),
                                _detailRow('Category', order['isCustomStore'] == true ? 'Personal Assistant' : (order['vendor']?['category'] ?? 'N/A')),
                                _detailRow('Contact', order['isCustomStore'] == true ? 'N/A (Custom Shop)' : (order['vendor']?['contact'] ?? 'N/A')),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        // Right Column: Items and Payment breakdown
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _detailSectionCard('Order Summary', Icons.shopping_bag_rounded, [
                                // 1. Requirements (for Text only)
                                if (order['orderType'] == 'Text') ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(color: AdminColors.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 20),
                                          const SizedBox(width: 8),
                                          Text('ORDER REQUIREMENTS (TEXT)', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.orange.shade800)),
                                        ]),
                                        const SizedBox(height: 16),
                                        Text(order['textContent'] ?? 'No text provided.', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16, height: 1.5, color: AdminColors.textHeading)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // 2. Itemized List
                                Text('ITEMS DELIVERED', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey.shade600, letterSpacing: 1)),
                                const SizedBox(height: 16),
                                if (order['items'] != null && (order['items'] as List).isNotEmpty)
                                  ... (order['items'] as List).map((item) => _itemRow(item)).toList()
                                else
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('No itemized list provided', style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic, fontSize: 13)),
                                  ),

                                const Divider(height: 32),
                                _priceRow('Subtotal', '₹${order['subTotal'] ?? ((order['totalAmount'] ?? 0) - (order['deliveryCharge'] ?? 0))}', isBold: false),
                                _priceRow('Delivery Fee', '₹${order['deliveryCharge'] ?? '0'}', isBold: false),
                                _priceRow('Taxes', '₹${order['tax'] ?? '0'}', isBold: false),
                                const SizedBox(height: 16),
                                _priceRow('TOTAL AMOUNT', '₹${(order['totalAmount'] ?? 0).toString()}', isBold: true, color: AdminColors.primaryIndigo),

                                // 🧾 3. Proof of Purchase (Bill) - Shown at the bottom (Hidden for Customer Orders Tab)
                                if (order['billPhotoPath'] != null && _tab != 7) ...[
                                  const SizedBox(height: 32),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F9FF),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.blue.shade200, width: 2),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(children: [
                                              const Icon(Icons.receipt_long_rounded, color: Colors.blue, size: 24),
                                              const SizedBox(width: 12),
                                              Text('OFFICIAL SHOP RECEIPT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.blue.shade900)),
                                            ]),
                                            if (order['billUploadedAt'] != null)
                                              Text(
                                                DateFormat('hh:mm a').format(DateTime.parse(order['billUploadedAt'].toString())),
                                                style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        GestureDetector(
                                          onTap: () => _showImagePreviewDialog(order['billPhotoPath'].toString(), 'OFFICIAL RECEIPT'),
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.zoomIn,
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: (order['billPhotoPath']?.toString() ?? '').contains(':\\') || (order['billPhotoPath']?.toString().isNotEmpty == true && order['billPhotoPath']?.toString().startsWith('http') != true && order['billPhotoPath']?.toString().startsWith('/public') != true)
                                                ? Image.file(
                                                    File(order['billPhotoPath']),
                                                    width: double.infinity,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (c, e, s) => Container(padding: const EdgeInsets.all(24), color: Colors.grey.shade50, child: const Icon(Icons.broken_image_outlined, color: Colors.grey)),
                                                  )
                                                : Image.network(
                                                    order['billPhotoPath'].toString().contains('http') 
                                                      ? order['billPhotoPath'] 
                                                      : 'https://namba-backend.onrender.com${order['billPhotoPath']}',
                                                    width: double.infinity,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (c, e, s) => Container(
                                                      padding: const EdgeInsets.all(24),
                                                      color: Colors.grey.shade50,
                                                      child: const Center(child: Column(
                                                        children: [
                                                          Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                                                          SizedBox(height: 8),
                                                          Text('Bill photo uploaded but unreachable', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                                        ],
                                                      )),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ]),
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
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: ScaleTransition(scale: anim1.drive(Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack))), child: child));
      },
    );
  }

  Widget _detailSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AdminColors.primaryIndigo),
              const SizedBox(width: 12),
              Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
            ],
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }


  Widget _itemRow(dynamic item) {
    String name = 'Item';
    num qty = 1;
    num price = 0;

    if (item is Map) {
      final product = item['product'];
      if (product is Map) {
        name = product['name']?.toString() ?? 'Item';
        price = product['price'] ?? 0;
      } else {
        name = item['productName'] ?? item['name'] ?? 'Item';
        price = item['price'] ?? 0;
      }
      qty = item['quantity'] ?? 1;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AdminColors.background, borderRadius: BorderRadius.circular(8)),
            child: Text('${qty}x', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: AdminColors.primaryIndigo)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14))),
          Text('₹${price * qty}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, fontSize: isBold ? 16 : 14, color: isBold ? AdminColors.textHeading : Colors.grey.shade500)),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: isBold ? 20 : 15, color: color ?? AdminColors.textHeading)),
        ],
      ),
    );
  }

  Widget _orderDetailMini(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.grey.shade400, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 14, color: AdminColors.primaryIndigo),
            const SizedBox(width: 8),
            Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: AdminColors.textHeading)),
          ],
        ),
      ],
    );
  }

  void _showAssignDriverSheet(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Inner function to fetch inside modal context
          Future<void> refresh() async {
            setModalState(() => _isDriversLoading = true);
            await _fetchAvailableDrivers();
            if (ctx.mounted) {
              setModalState(() => _isDriversLoading = false);
            }
          }

          // Initial fetch if empty or just to be sure
          if (_onlineDrivers.isEmpty && !_isDriversLoading) {
            refresh();
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Assign Driver', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 24)),
                    Text('For Order #${order['displayId']}', style: TextStyle(color: Colors.grey.shade500)),
                  ]),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: () => refresh()),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Expanded(
                child: _isDriversLoading
                  ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo))
                  : _onlineDrivers.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No online drivers found.', style: TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(height: 8),
                          Text('Only approved and online partners appear here.', style: TextStyle(color: Colors.grey.shade300, fontSize: 11)),
                        ],
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _onlineDrivers.length,
                        itemBuilder: (ctx, idx) {
                          final driver = _onlineDrivers[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade100),
                              color: Colors.white
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.delivery_dining_rounded, color: AdminColors.primaryIndigo, size: 20),
                              ),
                              title: Text(driver['name'] ?? 'Partner', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15)),
                              subtitle: Text(driver['phone'] ?? 'N/A', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                              trailing: ElevatedButton(
                                onPressed: () { Navigator.pop(ctx); _assignDriver(order['_id'], driver['_id']); },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ),
                                child: Text('ASSIGN', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          );
        },
      ),
    );
  }
  Widget _buildBroadcastCenter() {
    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('SYSTEM BROADCAST', 'Mass Communication Centre'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBroadcastComposer(),
                  const SizedBox(height: 40),
                  Text('RECENT BROADCASTS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 24),
                  _buildBroadcastHistory(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastComposer() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compose Announcement', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 24),
          TextField(
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Type your platform-wide message here...',
              filled: true, fillColor: AdminColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _targetChip('VENDORS', Colors.blue),
              const SizedBox(width: 12),
              _targetChip('DRIVERS', Colors.green),
              const SizedBox(width: 12),
              _targetChip('CUSTOMERS', Colors.orange),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text('PUBLISH NOW', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _targetChip(String label, Color color) {
    return FilterChip(
      label: Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
      onSelected: (v) {},
      backgroundColor: color.withOpacity(0.05),
      selectedColor: color.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withOpacity(0.1))),
    );
  }

  Widget _buildBroadcastHistory() {
    final history = [
      {'msg': 'Platform Maintenance tonight at 12 PM', 'target': 'All Users', 'time': '2h ago'},
      {'msg': 'New delivery incentives for Monsoon orders!', 'target': 'Drivers', 'time': '5h ago'},
    ];
    return Column(
      children: history.map((b) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: Colors.grey),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b['msg']!, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('Target: ${b['target']} • ${b['time']}', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ]),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildTabHeader(String tag, String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AdminColors.border))),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tag, style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(title, style: GoogleFonts.outfit(color: AdminColors.textHeading, fontWeight: FontWeight.w900, fontSize: 32)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildActivityTicker(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(40),
              children: [
                _buildEliteHeader(),
                const SizedBox(height: 32),
                _buildProfessionalStatsGrid(),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildRevenueChart()),
                    const SizedBox(width: 40),
                    Expanded(flex: 2, child: _buildMarketShareChart()),
                  ],
                ),
                const SizedBox(height: 48),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTopVendorsElite()),
                    const SizedBox(width: 40),
                    Expanded(child: _buildOperationHealthGrid()),
                  ],
                ),
                const SizedBox(height: 48),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDriverPerformanceElite()),
                    const SizedBox(width: 40),
                    const Spacer(), // Empty space for now or can add activity ticker
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopVendorsElite() {
    final list = _topVendors.isEmpty ? _vendors.take(4).toList() : _topVendors.take(4).toList();
    final fmt = (dynamic v) => NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN').format(v ?? 0);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TOP PERFORMING VENDORS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
              const Spacer(),
              if (_isPerformanceLoading) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.primaryIndigo)),
            ],
          ),
          const SizedBox(height: 32),
          if (list.isEmpty) _buildEmptyStateMini('No Sales Data', 'Top vendors will appear here after orders are delivered.')
          else ...list.map((v) => GestureDetector(
            onTap: () {
              // Find index in main _vendors list
              int idx = _vendors.indexWhere((vendor) => vendor['_id'] == v['_id']);
              if (idx != -1) {
                setState(() {
                  _tab = 1; // Switch to Vendors Tab
                  _selectedVendorIdx = idx;
                });
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: AdminColors.background, borderRadius: BorderRadius.circular(16)), child: Center(child: Text(v['storeName']?[0] ?? 'V', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF7C3AED))))),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v['storeName'] ?? 'Vendor', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('${v['orderCount'] ?? v['orders'] ?? 0} Orders • ${v['category'] ?? "Retail"}', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(fmt(v['totalSales'] ?? v['revenue']), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
                      Text('Earnings', style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
                    ]),
                  ],
                ),
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildDriverPerformanceElite() {
    final list = _driverPerformance.isEmpty ? _allDrivers.take(4).toList() : _driverPerformance.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('DELIVERY PARTNER PERFORMANCE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
              const Spacer(),
              if (_isPerformanceLoading) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.primaryIndigo)),
            ],
          ),
          const SizedBox(height: 32),
          if (list.isEmpty) _buildEmptyStateMini('No Performance Data', 'Driver metrics will appear here after deliveries.')
          else ...list.map((d) => GestureDetector(
            onTap: () {
              // Find index in main _allDrivers list
              int idx = _allDrivers.indexWhere((driver) => driver['_id'] == d['_id']);
              if (idx != -1) {
                setState(() {
                  _tab = 3; // Switch to Drivers Tab
                });
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48, 
                      decoration: BoxDecoration(
                        color: (d['isOnline'] == true) ? Colors.green.withOpacity(0.1) : AdminColors.background, 
                        borderRadius: BorderRadius.circular(16)
                      ), 
                      child: Center(child: Icon(Icons.person_rounded, color: (d['isOnline'] == true) ? Colors.green : Colors.grey, size: 24))
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['name'] ?? 'Driver', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('${d['daysWorked'] ?? 0} Days Active • ${d['vehicleType']?.toUpperCase() ?? "BIKE"}', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${d['deliveryCount'] ?? 0}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo)),
                      Text('Deliveries', style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
                    ]),
                  ],
                ),
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildOperationHealthGrid() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PLATFORM DIAGNOSTICS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
          const SizedBox(height: 32),
          _healthGauge('API LATENCY', '14ms', Colors.green, 0.2),
          const SizedBox(height: 24),
          _healthGauge('SYSTEM LOAD', '2.1%', Colors.blue, 0.1),
          const SizedBox(height: 24),
          _healthGauge('SOCKET STRENGTH', '99.9%', AdminColors.primaryIndigo, 0.99),
        ],
      ),
    );
  }

  Widget _healthGauge(String label, String value, Color color, double percent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: GoogleFonts.outfit(color: AdminColors.textSub, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1)),
          const Spacer(),
          Text(value, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Container(
          height: 8, width: double.infinity,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percent,
            child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTicker() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: AdminColors.sidebarBg,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _auditLog.length,
        itemBuilder: (context, i) {
          final log = _auditLog[i];
          return Container(
            margin: const EdgeInsets.only(right: 40),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: _getAuditColor(log['color']?.toString() ?? ''), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(log['action'], style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('• ${log['time']}', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEliteHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SYSTEM EXECUTIVE SUMMARY', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('Platform Performance Overview', 
                    style: GoogleFonts.outfit(color: AdminColors.textHeading, fontWeight: FontWeight.w900, fontSize: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(DateFormat('MMM dd').format(DateTime.now()), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AdminColors.textHeading, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfessionalStatsGrid() {
    return GridView.count(
      crossAxisCount: 4, mainAxisSpacing: 24, crossAxisSpacing: 24,
      childAspectRatio: 2.3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      children: [
        _proStatCard('TOTAL GROSS REVENUE', '₹${NumberFormat('#,##,###').format(_totalRevenue)}', Icons.payments_rounded, AdminColors.primaryIndigo, '↑ 12.4%'),
        _proStatCard('PLATFORM NET PROFIT', '₹${NumberFormat('#,##,###').format(_commission)}', Icons.account_balance_rounded, AdminColors.success, 'STABLE'),
        _proStatCard('ACTIVE MARKET ORDERS', '$_totalOrders', Icons.shopping_basket_rounded, AdminColors.primaryIndigo, '+45 Today'),
        _proStatCard('VERIFIED PARTNERS', '$_activeVendors', Icons.verified_user_rounded, AdminColors.warning, 'Operational'),
      ],
    );
  }

  Widget _proStatCard(String label, String value, IconData icon, Color color, String trend) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 18)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Text(trend, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900))),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AdminColors.textHeading), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(label, style: GoogleFonts.outfit(fontSize: 9, color: AdminColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Revenue Trajectory', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
              const Spacer(),
              Text('Last 7 Days', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30.0, interval: 1.0, getTitlesWidget: (v, meta) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][v.toInt() % 7], style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 11))))),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 5000.0, reservedSize: 42.0, getTitlesWidget: (v, meta) => Text('₹${(v/1000).toStringAsFixed(0)}k', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 10)))),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [FlSpot(0.0, 3000.0), FlSpot(1.0, 5000.0), FlSpot(2.0, 4000.0), FlSpot(3.0, 7000.0), FlSpot(4.0, 6000.0), FlSpot(5.0, 9000.0), FlSpot(6.0, 12000.0)],
                    isCurved: true,
                    color: AdminColors.primaryIndigo,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AdminColors.primaryIndigo.withOpacity(0.2), AdminColors.primaryIndigo.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketShareChart() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Market Distribution', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
          const Spacer(),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4, centerSpaceRadius: 45,
                sections: [
                  PieChartSectionData(color: AdminColors.primaryIndigo, value: 40.0, title: '40%', radius: 25.0, titleStyle: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(color: AdminColors.info, value: 30.0, title: '30%', radius: 20.0, titleStyle: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(color: AdminColors.success, value: 15.0, title: '15%', radius: 18.0, titleStyle: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(color: AdminColors.border, value: 15.0, title: '15%', radius: 15.0, titleStyle: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: AdminColors.textHeading)),
                ],
              ),
            ),
          ),
          const Spacer(),
          _buildMarketLegend(),
        ],
      ),
    );
  }

  Widget _buildMarketLegend() {
    return Column(
      children: [
        _legendItem('Grocery & Daily', AdminColors.primaryIndigo),
        const SizedBox(height: 8),
        _legendItem('Food & Dining', const Color(0xFFC026D3)),
        const SizedBox(height: 8),
        _legendItem('Health & Pharma', const Color(0xFFF472B6)),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
      ],
    );
  }

  // ── REPORTS (FINANCIAL AUDIT CENTRE) ──────────────────────────────────
  Widget _buildReports() {
    if (_isReportsLoading && _payouts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo));
    }
    final totalCommission = _payouts.fold(0.0, (s, p) => s + ((p['commission'] as num?)?.toDouble() ?? 0.0));
    final pendingCommission = _payouts.where((p) => p['status'] == 'Pending').fold(0.0, (s, p) => s + ((p['commission'] as num?)?.toDouble() ?? 0.0));
    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('FINANCIAL INTELLIGENCE', 'Revenue & Audit Log'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _eliteReportCard('TOTAL REVENUE YIELD', '₹${NumberFormat('#,###').format(totalCommission)}', Icons.account_balance_rounded, AdminColors.sidebarBg)),
                      const SizedBox(width: 24),
                      Expanded(child: _eliteReportCard('PENDING SETTLEMENTS', '₹${NumberFormat('#,###').format(pendingCommission)}', Icons.pending_actions_rounded, AdminColors.warning)),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Text('TRANSACTION LEDGER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 24),
                  _buildPayoutTable(),
                  const SizedBox(height: 48),
                  Text('SYSTEM AUDIT TRAIL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 24),
                  _buildAuditTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eliteReportCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 24),
          Text(value, style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AdminColors.textMuted, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildPayoutTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100)),
      child: DataTable(
        headingRowHeight: 60, dataRowHeight: 80,
        headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AdminColors.textMuted, fontSize: 11, letterSpacing: 1),
        dataTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AdminColors.textHeading, fontSize: 14),
        columns: const [
          DataColumn(label: Text('PARTNER')),
          DataColumn(label: Text('DATE')),
          DataColumn(label: Text('TOTAL VOLUME')),
          DataColumn(label: Text('YIELD')),
          DataColumn(label: Text('STATUS')),
        ],
        rows: _payouts.map((p) => DataRow(cells: [
          DataCell(Text(p['vendor'], style: const TextStyle(fontWeight: FontWeight.w900))),
          DataCell(Text(p['date'], style: TextStyle(color: AdminColors.textMuted))),
          DataCell(Text('₹${NumberFormat('#,###').format(p['amount'])}')),
          DataCell(Text('₹${NumberFormat('#,###').format(p['commission'])}', style: const TextStyle(color: AdminColors.primaryIndigo))),
          DataCell(_payoutStatusBadge(p['status'])),
        ])).toList(),
      ),
    );
  }

  Widget _buildAuditTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100)),
      child: DataTable(
        headingRowHeight: 60, dataRowHeight: 80,
        headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.grey.shade400, fontSize: 11, letterSpacing: 1),
        columns: const [
          DataColumn(label: Text('EVENT')),
          DataColumn(label: Text('OPERATOR')),
          DataColumn(label: Text('TIMESTAMP')),
        ],
        rows: _auditLog.map((log) => DataRow(cells: [
          DataCell(Row(children: [
            Icon(_getAuditIcon(log['icon']?.toString() ?? ''), color: _getAuditColor(log['color']?.toString() ?? ''), size: 20),
            const SizedBox(width: 16),
            Text(log['action']?.toString() ?? 'Unknown Action', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
          ])),
          DataCell(Text(log['by']?.toString() ?? 'System', style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text(log['time']?.toString() ?? 'Recent', style: TextStyle(color: Colors.grey.shade400))),
        ])).toList(),
      ),
    );
  }

  Widget _payoutStatusBadge(String status) {
    final isPaid = status == 'Paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: GoogleFonts.outfit(color: isPaid ? Colors.green.shade700 : Colors.orange.shade700, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }

  Widget _cityBreakdown() {
    final cities = <String, double>{};
    for (var v in _vendors) {
      final city = v['city'] ?? 'Chennai';
      final revenue = double.tryParse(v['revenue']?.toString() ?? '0') ?? 0.0;
      cities[city] = (cities[city] ?? 0) + revenue;
    }
    if (cities.isEmpty) return const SizedBox(height: 100, child: Center(child: Text('No data')));
    final sorted = cities.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.first.value > 0 ? sorted.first.value : 1.0;
    final colors = [AdminColors.primaryIndigo, AdminColors.primaryIndigo, const Color(0xFF059669), const Color(0xFFD97706)];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
      child: Column(children: sorted.asMap().entries.map((e) {
        final color = colors[e.key % colors.length];
        return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(e.value.key, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Text('₹${NumberFormat('#,##,###').format(e.value.value)}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: color, fontSize: 14)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: e.value.value / max, backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6,
          )),
        ]));
      }).toList()),
    );
  }

  Widget _categoryBreakdown() {
    final cats = <String, int>{};
    for (var v in _vendors) {
      final cat = v['category'] ?? 'General';
      final orders = int.tryParse(v['orders']?.toString() ?? '0') ?? 0;
      cats[cat] = (cats[cat] ?? 0) + orders;
    }
    final total = cats.values.fold(0, (s, c) => s + c);
    final icons = {'Grocery': '🛒', 'Bakery': '🥐', 'Medicine': '💊', 'Food': '🍱', 'Fruits & Vegetables': '🥦'};
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
      child: Column(children: cats.entries.map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(icons[e.key] ?? '📦', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(e.key, style: GoogleFonts.outfit(fontWeight: FontWeight.w700))),
          Text('${e.value} orders', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(width: 8),
          Text('${total > 0 ? (e.value / total * 100).toStringAsFixed(0) : 0}%',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo)),
        ]),
      )).toList()),
    );
  }

  // ── VENDORS (SPLIT PANE LAYOUT) ──────────────────────────────────────
  Widget _buildVendors() {
    final search = _vendorSearch.toLowerCase();
    final filtered = _vendors.where((v) {
      final storeName = (v['storeName'] ?? v['name'] ?? '').toString().toLowerCase();
      final ownerName = (v['ownerName'] ?? '').toString().toLowerCase();
      final address = (v['address'] ?? v['city'] ?? '').toString().toLowerCase();
      return storeName.contains(search) || ownerName.contains(search) || address.contains(search);
    }).toList();
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: AdminColors.textHeading, elevation: 0.5,
        title: Text('Vendor Management', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
        actions: [
          if (_pendingVendors.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Chip(
                label: Text('${_pendingVendors.length} PENDING', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                backgroundColor: Colors.orange.shade700,
                padding: EdgeInsets.zero,
              ),
            ),
          IconButton(
            onPressed: () {
              _fetchSettings();
              _fetchPendingVendors();
              _fetchAllVendors();
            },
            icon: const Icon(Icons.refresh_rounded, color: AdminColors.primaryIndigo),
            tooltip: 'Refresh Directory',
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showAddVendorSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Add Vendor', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.sidebarBg, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(children: [
        // LEFT PANE: Directory List
        Container(
          width: 350,
          decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.grey.shade200))),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (v) => setState(() => _vendorSearch = v),
                decoration: InputDecoration(
                  hintText: 'Search vendors...',
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                  filled: true, fillColor: Colors.grey.shade100,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            
            // Sub-tabs for Directory vs Pending
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Expanded(child: _subTab('Directory', _selectedVendorIdx >= 0, () => setState(() => _selectedVendorIdx = 0))),
                const SizedBox(width: 8),
                Expanded(child: _subTab('Approvals (${_pendingVendors.length})', _selectedVendorIdx == -1, () => setState(() => _selectedVendorIdx = -1))),
              ]),
            ),

            Container(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: _selectedVendorIdx == -1 
                ? _buildPendingList()
                : filtered.isEmpty
                  ? Center(child: Text('No vendors found', style: TextStyle(color: Colors.grey.shade400)))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      itemBuilder: (_, i) {

                              final v = filtered[i];
                              final actualIdx = _vendors.indexOf(v);
                              final isSelected = _selectedVendorIdx == actualIdx;
                              final status = v['approvalStatus'] ?? 'pending';
                              final isActive = status == 'approved';
                              final displayName = v['storeName'] ?? v['name'] ?? 'Vendor';
                              
                              return InkWell(
                                onTap: () => setState(() => _selectedVendorIdx = actualIdx),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AdminColors.background : Colors.transparent,
                                    border: isSelected ? const Border(left: BorderSide(color: Color(0xFF4F46E5), width: 4)) : const Border(left: BorderSide(color: Colors.transparent, width: 4)),
                                  ),
                                  child: Row(children: [
                                    CircleAvatar(
                                      backgroundColor: isActive ? AdminColors.primaryIndigo.withOpacity(0.1) : Colors.grey.shade200, 
                                      foregroundColor: isActive ? AdminColors.primaryIndigo : Colors.grey.shade600, 
                                      child: Text(displayName.isNotEmpty ? displayName[0] : '?', style: const TextStyle(fontWeight: FontWeight.w900))
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(displayName, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                                      Text('${v['city'] ?? 'Chennai'} • ${v['category'] ?? 'General'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                    ])),
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: isActive ? Colors.green.shade500 : (status == 'pending' ? Colors.orange.shade400 : Colors.red.shade400), shape: BoxShape.circle)),
                                  ]),
                                ),
                              );
                    },
                  ),
            ),
          ]),
        ),
        // RIGHT PANE: Deep Details
        Expanded(
          child: _selectedVendorIdx == -1
              ? _buildPendingApprovalsPane()
              : _selectedVendorIdx < _vendors.length
                  ? _buildVendorDetailPane(_vendors[_selectedVendorIdx], _selectedVendorIdx)
                  : Center(child: Text('Select an item to view', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 16))),
        ),
      ]),
    );
  }

  Widget _buildAccountSettings() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Account Security', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
      const SizedBox(height: 8),
      Text('Update your administrative credentials and security settings.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AdminColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Personal Information', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: AdminColors.textHeading)),
          const SizedBox(height: 24),
          _inputField(_accountNameCtrl, 'Full Name', Icons.person_rounded),
          const SizedBox(height: 16),
          _inputField(_accountEmailCtrl, 'Email Address', Icons.email_rounded),
          const SizedBox(height: 32),
          Text('Security', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: AdminColors.textHeading)),
          const SizedBox(height: 24),
          _inputField(_accountPassCtrl, 'New Password (Leave blank to keep current)', Icons.lock_outline_rounded, obscure: true),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _updateAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primaryIndigo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Save Profile Changes', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _updateAccount() async {
    final name = _accountNameCtrl.text.trim();
    final email = _accountEmailCtrl.text.trim();
    final pass = _accountPassCtrl.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Email cannot be empty')));
      return;
    }

    try {
      final res = await AdminService.updateProfile(
        adminId: widget.user['_id'],
        name: name,
        email: email,
        password: pass.isEmpty ? null : pass,
      );

      if (res['success'] == true) {
        setState(() {
          widget.user['name'] = name;
          widget.user['email'] = email;
          _accountPassCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AdminColors.success,
        ));
      } else {
        throw Exception(res['error'] ?? 'Update failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: AdminColors.danger,
      ));
    }
  }

  Widget _subTab(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? AdminColors.primaryIndigo.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AdminColors.primaryIndigo : AdminColors.border),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AdminColors.primaryIndigo : AdminColors.textSub)),
      ),
    );
  }

  Widget _buildPendingList() {
    if (_isPendingLoading) return const Center(child: CircularProgressIndicator());
    if (_pendingVendors.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey.shade300), const SizedBox(height: 16), Text('No pending approvals', style: TextStyle(color: Colors.grey.shade400))]));
    return ListView.separated(
      itemCount: _pendingVendors.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (_, i) {
        final v = _pendingVendors[i];
        final storeName = v['storeName']?.toString() ?? 'Vendor';
        final category = v['category']?.toString() ?? 'General';
        final ownerName = v['ownerName']?.toString() ?? 'Owner';
        return ListTile(
          leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: Text(storeName.isNotEmpty ? storeName[0] : '?', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w900))),
          title: Text(storeName, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
          subtitle: Text('$category • $ownerName', style: const TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
          onTap: () {}, // Detail shown in right pane
        );
      },
    );
  }

  Widget _buildPendingApprovalsPane() {
    return Container(
      color: AdminColors.background,
      child: _pendingVendors.isEmpty 
        ? Center(child: Text('All pending applications processed.', style: GoogleFonts.outfit(color: Colors.grey.shade400)))
        : ListView.builder(
            padding: const EdgeInsets.all(32),
            itemCount: _pendingVendors.length,
            itemBuilder: (_, i) => _buildPendingCard(_pendingVendors[i]),
          ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> v) {
    final storeName = v['storeName']?.toString() ?? 'Vendor';
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 60, height: 60, decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Center(child: Text(storeName.isNotEmpty ? storeName[0] : '?', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AdminColors.primaryIndigo)))),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(storeName, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: AdminColors.textHeading)),
            Text('Owner: ${v['ownerName'] ?? 'Owner'}  •  Phone: ${v['phone'] ?? 'N/A'}', style: TextStyle(color: AdminColors.textSub, fontSize: 13)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)), child: Text('PENDING REVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.orange.shade700))),
        ]),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        Row(children: [
          _pendingInfoItem('Category', v['category'], Icons.category_rounded),
          _pendingInfoItem('GST Number', v['gstNumber'], Icons.receipt_long_rounded),
          _pendingInfoItem('PAN Number', v['panNumber'], Icons.card_membership_rounded),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _pendingInfoItem('Business Email', v['businessEmail'], Icons.email_rounded),
          _pendingInfoItem('Delivery Radius', '${v['deliveryRadiusKm'] ?? 20} KM', Icons.track_changes_rounded),
          _pendingInfoItem('Application Date', v['createdAt'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(v['createdAt'])) : 'Today', Icons.calendar_today_rounded),
        ]),
        const SizedBox(height: 16),
        _pendingInfoItem('Business Address', '${v['address'] ?? 'N/A'}, ${v['city'] ?? 'Chennai'} - ${v['pincode'] ?? 'N/A'}', Icons.location_on_rounded),
        const SizedBox(height: 32),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _approveVendor(v['_id']),
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            label: Text('Approve & Activate Store', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          )),
          const SizedBox(width: 16),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _rejectVendor(v['_id'], 'Incomplete documentation.'),
            icon: const Icon(Icons.cancel_rounded, size: 20),
            label: Text('Reject Application', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade600, side: BorderSide(color: Colors.red.shade200), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          )),
        ]),
      ]),
    );
  }

  Widget _pendingInfoItem(String label, String? value, IconData icon) {
    final safeValue = value?.toString() ?? 'N/A';
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 14, color: Colors.grey.shade400), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600))]),
      const SizedBox(height: 4),
      Text(safeValue, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: AdminColors.textHeading)),
    ]));
  }

  Widget _buildVendorDetailPane(Map<String, dynamic> v, int i) {
    final revenue = double.tryParse(v['revenue']?.toString() ?? '0') ?? 0.0;
    final orders = int.tryParse(v['orders']?.toString() ?? '0') ?? 0;
    final status = v['status'] ?? v['approvalStatus'] ?? 'pending';
    final isActive = status == 'Active' || status == 'approved';
    final accentColor = isActive ? AdminColors.primaryIndigo : Colors.grey.shade500;
    final displayName = v['storeName'] ?? v['name'] ?? 'Vendor';

    return Container(
      color: AdminColors.background,
      child: ListView(padding: const EdgeInsets.all(32), children: [
        // PRO HEADER
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: isActive ? AdminColors.primaryGradient : [Colors.grey.shade400, Colors.grey.shade500]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Center(child: Text(displayName.isNotEmpty ? displayName[0] : '?', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 36, color: Colors.white))),
          ),
          const SizedBox(width: 24),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(displayName, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 28, color: AdminColors.textHeading)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: isActive ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: isActive ? Colors.green.shade200 : Colors.red.shade200)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: isActive ? Colors.green.shade600 : Colors.red.shade600, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isActive ? Colors.green.shade700 : Colors.red.shade700)),
                ]),
              ),
            ]),
            const SizedBox(height: 6),
            Text('📦 ${v['category'] ?? 'General'}  •  📅 Joined ${v['joined'] ?? DateFormat('MMM dd, yyyy').format(DateTime.now())}', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            // Actions
            Row(children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _vendors[i]['status'] = isActive ? 'Suspended' : 'Active'),
                icon: Icon(isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16),
                label: Text(isActive ? 'Suspend Operations' : 'Activate Vendor', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: isActive ? Colors.orange.shade50 : Colors.green.shade50, foregroundColor: isActive ? Colors.orange.shade700 : Colors.green.shade700, elevation: 0),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showVendorAccessDialog(v),
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: Text('Manage Access', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1), foregroundColor: AdminColors.primaryIndigo, elevation: 0),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _vendors.removeAt(i));
                  _selectedVendorIdx = 0; 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vendor removed'), backgroundColor: Colors.red));
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: Text('Remove Vendor', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade600, side: BorderSide(color: Colors.red.shade200)),
              ),
            ]),
          ])),
        ]),
        const SizedBox(height: 48),

        // ANALYTICS GRID
        Text('Performance Analytics', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: AdminColors.textHeading)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 2.2,
          children: [
            _metricCard('Total Revenue', '₹${NumberFormat('#,##,###').format(revenue)}', Icons.payments_rounded, AdminColors.primaryIndigo, '+8.4% this month'),
            _metricCard('Total Orders', '$orders', Icons.receipt_long_rounded, const Color(0xFF059669), 'Operational ✨'),
            _metricCard('Customer Rating', '⭐ ${v['rating']?.toString() ?? '4.8'}', Icons.star_rounded, const Color(0xFFD97706), 'from all reviews'),
          ],
        ),
        const SizedBox(height: 40),

        // FULL DETAILS SECTIONS
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Identity & Reach
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  _buildDetailCard(
                    'Business Identity',
                    Icons.badge_rounded,
                    [
                      _detailRow('Owner Name', v['ownerName'] ?? v['user']?['name'] ?? 'N/A'),
                      _detailRow('Store Category', v['category'] ?? 'General'),
                      _detailRow('Business Email', v['businessEmail'] ?? v['user']?['email'] ?? 'No Email'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailCard(
                    'Legal & Tax Credentials',
                    Icons.gavel_rounded,
                    [
                      _detailRow('GST Number', v['gstNumber'] ?? 'NOT REGISTERED', isCopyable: true),
                      _detailRow('PAN Number', v['panNumber'] ?? 'N/A', isCopyable: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right Column: Contact & Location
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  _buildDetailCard(
                    'Contact Information',
                    Icons.contact_phone_rounded,
                    [
                      _detailRow('Phone Number', v['phone'] ?? v['user']?['phone'] ?? 'N/A', isBold: true),
                      _detailRow('Operational Status', v['isOpen'] == true ? 'OPEN NOW' : 'CLOSED', color: v['isOpen'] == true ? Colors.green : Colors.red),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailCard(
                    'Service Area & Logistics',
                    Icons.map_rounded,
                    [
                      _detailRow('Address', v['address'] ?? 'N/A'),
                      _detailRow('City & Pincode', '${v['city'] ?? 'Chennai'} - ${v['pincode'] ?? 'N/A'}'),
                      _detailRow('Delivery Radius', '${v['deliveryRadiusKm'] ?? 20} KM'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _buildDetailCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AdminColors.primaryIndigo),
            const SizedBox(width: 12),
            Text(title.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: AdminColors.textHeading, letterSpacing: 1)),
          ]),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isCopyable = false, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value, 
                    style: GoogleFonts.outfit(
                      fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, 
                      fontSize: 14, 
                      color: color ?? AdminColors.textHeading
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCopyable && value != 'N/A' && value != 'NOT REGISTERED')
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14, color: AdminColors.primaryIndigo),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied to clipboard'), behavior: SnackBarBehavior.floating));
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _miniStat(String label, String value, IconData icon) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, size: 14, color: AdminColors.primaryIndigo),
        const SizedBox(width: 4),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.primaryIndigo)),
          Text(label, style: TextStyle(fontSize: 9, color: AdminColors.textSub)),
        ])),
      ]),
    ));
  }

  void _showAddVendorSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    String cat = 'Grocery';
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Add New Vendor', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _inputField(nameCtrl, 'Store Name', Icons.store_rounded),
          const SizedBox(height: 12),
          _inputField(cityCtrl, 'City', Icons.location_city_rounded),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: cat,
            items: ['Grocery', 'Bakery', 'Medicine', 'Food'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setS(() => cat = v!),
            decoration: InputDecoration(
              labelText: 'Category', prefixIcon: const Icon(Icons.category_rounded, size: 20, color: AdminColors.primaryIndigo),
              filled: true, fillColor: AdminColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() => _vendors.insert(0, {
                    'name': nameCtrl.text, 'city': cityCtrl.text.isEmpty ? 'Chennai' : cityCtrl.text,
                    'category': cat, 'orders': 0, 'revenue': 0.0, 'status': 'Active',
                    'joined': DateFormat('MMM yyyy').format(DateTime.now()),
                  }));
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: Text('Add Vendor', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ]),
      )),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false, TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint, prefixIcon: Icon(icon, size: 20, color: AdminColors.primaryIndigo),
        filled: true, fillColor: AdminColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.primaryIndigo, width: 1.5)),
      ),
    );
  }

  Widget _permissionToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: value ? AdminColors.primaryIndigo.withOpacity(0.3) : Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value ? AdminColors.primaryIndigo.withOpacity(0.1) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: value ? AdminColors.primaryIndigo : Colors.grey, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13, color: AdminColors.textHeading)),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AdminColors.primaryIndigo,
          ),
        ],
      ),
    );
  }

  // ── ADMINS (SPLIT PANE LAYOUT) ─────────────────────────────────────────
  Widget _buildAdmins() {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: AdminColors.textHeading, elevation: 0.5,
        title: Text('Admin Control Center', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _isAdminsLoading ? AdminColors.primaryIndigo : AdminColors.textSub, size: 20),
            onPressed: _isAdminsLoading ? null : _fetchAllAdmins,
            tooltip: 'Refresh Directory',
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showAddAdminSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Provision Admin', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.sidebarBg, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(children: [
        // LEFT PANE: Directory List
        Container(
          width: 350,
          decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.grey.shade200))),
          child: _isAdminsLoading && _admins.isEmpty
            ? Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo))
            : _admins.isEmpty
              ? Center(child: Text('No admins found', style: TextStyle(color: Colors.grey.shade400)))
              : ListView.separated(
                itemCount: _admins.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) {
                  final a = _admins[i];
                  final isSelected = _selectedAdminIdx == i;
                  final isActive = a['isActive'] == true;
                  return InkWell(
                    onTap: () => setState(() => _selectedAdminIdx = i),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AdminColors.background : Colors.transparent,
                        border: isSelected ? const Border(left: BorderSide(color: Color(0xFF4F46E5), width: 4)) : const Border(left: BorderSide(color: Colors.transparent, width: 4)),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor: isActive ? AdminColors.primaryIndigo.withOpacity(0.1) : Colors.grey.shade200, 
                          foregroundColor: isActive ? AdminColors.primaryIndigo : Colors.grey.shade600, 
                          child: Text(a['name'] != null && a['name'].toString().isNotEmpty ? a['name'].toString()[0].toUpperCase() : '?', 
                          style: const TextStyle(fontWeight: FontWeight.w900))
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a['name']?.toString() ?? a['phone']?.toString() ?? 'Unnamed Admin', 
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                          Text(a['email']?.toString() ?? a['phone']?.toString() ?? 'No Contact', 
                              style: TextStyle(color: AdminColors.textSub, fontSize: 11)),
                        ])),
                        if (widget.user['role'] == 'superadmin')
                          IconButton(
                            icon: const Icon(Icons.admin_panel_settings_rounded, size: 20, color: AdminColors.primaryIndigo),
                            tooltip: 'Manage Privileges',
                            onPressed: () => _showAdminPrivilegesSheet(a),
                          ),
                        const SizedBox(width: 4),
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: isActive ? AdminColors.success : AdminColors.danger, shape: BoxShape.circle)),
                      ]),
                    ),
                  );
                },
              ),
        ),
        // RIGHT PANE: Deep Details
        Expanded(
          child: _selectedAdminIdx < _admins.length
              ? _buildAdminDetailPane(_admins[_selectedAdminIdx], _selectedAdminIdx)
              : Center(child: Text('Select an admin to view details', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 16))),
        ),
      ]),
    );
  }

  Widget _buildAdminDetailPane(Map<String, dynamic> a, int i) {
    final isActive = a['isActive'] == true;
    final accentColor = isActive ? AdminColors.primaryIndigo : Colors.grey.shade500;

    return Container(
      color: AdminColors.background,
      child: ListView(padding: const EdgeInsets.all(32), children: [
        // PRO HEADER
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: isActive ? AdminColors.primaryGradient : [Colors.grey.shade400, Colors.grey.shade500]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Center(child: Text(a['name'] != null && a['name'].toString().isNotEmpty ? a['name'].toString()[0] : '?', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 36, color: Colors.white))),
          ),
          const SizedBox(width: 24),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(a['name']?.toString() ?? 'Admin', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 28, color: AdminColors.textHeading)),
              const SizedBox(width: 12),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: a['role'] == 'superadmin' ? Colors.amber.shade700 : AdminColors.sidebarBg, borderRadius: BorderRadius.circular(6)), child: Text((a['role']?.toString().toUpperCase() ?? 'ADMIN'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1))),
            ]),
            const SizedBox(height: 6),
            Text('✉️ ${a['email'] ?? 'N/A'}  •  📍 ${a['city'] ?? 'N/A'}', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            Row(children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _admins[i]['isActive'] = !isActive),
                icon: Icon(isActive ? Icons.block_rounded : Icons.how_to_reg_rounded, size: 16),
                label: Text(isActive ? 'Revoke Access' : 'Restore Access', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: isActive ? Colors.red.shade50 : Colors.green.shade50, foregroundColor: isActive ? Colors.red.shade700 : Colors.green.shade700, elevation: 0),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showResetPasswordDialog(a['_id'], a['name'] ?? 'Admin'),
                icon: const Icon(Icons.key_rounded, size: 16),
                label: Text('Reset Credentials', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(foregroundColor: AdminColors.primaryIndigo, side: const BorderSide(color: Color(0xFF4F46E5))),
              ),
              if (widget.user['role'] == 'superadmin' && a['_id'] != widget.user['_id']) ...[
                 const SizedBox(width: 12),
                 OutlinedButton.icon(
                   onPressed: () => _toggleAdminRole(a),
                   icon: Icon(a['role'] == 'superadmin' ? Icons.arrow_downward_rounded : Icons.star_rounded, size: 16),
                   label: Text(a['role'] == 'superadmin' ? 'Demote to Admin' : 'Promote to Super', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                   style: OutlinedButton.styleFrom(foregroundColor: a['role'] == 'superadmin' ? Colors.orange.shade700 : AdminColors.success, side: BorderSide(color: a['role'] == 'superadmin' ? Colors.orange.shade700 : AdminColors.success)),
                 ),
              ],
            ]),
          ])),
        ]),
        const SizedBox(height: 48),

        // ANALYTICS GRID
        Text('Administrative Activity', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: AdminColors.textHeading)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 2.2,
          children: [
            _metricCard('Managed Vendors', '${a['vendors'] ?? 0}', Icons.storefront_rounded, AdminColors.primaryIndigo, 'Active Directory'),
            _metricCard('Actions Taken', '124', Icons.rule_rounded, const Color(0xFF059669), 'Last 30 days'),
            _metricCard('Last Login', a['lastLogin']?.toString() ?? 'Never', Icons.history_rounded, const Color(0xFFD97706), 'Chennai IP'),
          ],
        ),
        const SizedBox(height: 24),

        // DEEP DIVE PANEL
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🔐 Access & Privileges', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.user['role'] == 'superadmin') ...[
                  ...['Overview', 'Vendors', 'Admins', 'Drivers', 'Verification', 'Dispatch Hub', 'Broadcasts', 'Support Hub', 'Intelligence', 'Security Audit', 'Report Center', 'Settings'].map((label) {
                    final currentPerms = Map<String, dynamic>.from(a['permissions'] ?? _adminPermissions);
                    final isAllowed = currentPerms[label] ?? false;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(label, style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                        Switch.adaptive(
                          value: isAllowed,
                          activeColor: AdminColors.primaryIndigo,
                          onChanged: (val) {
                            final newPerms = Map<String, bool>.from(currentPerms.map((k, v) => MapEntry(k, v == true)));
                            newPerms[label] = val;
                            _updateAdminPerms(a['_id'], newPerms);
                          },
                        ),
                      ]),
                    );
                  }).toList(),
                ] else ...[
                  _infoRow('Account Access', 'Restricted Mode', color: AdminColors.primaryIndigo),
                  const SizedBox(height: 12),
                  Text('Contact Super Admin to modify privileges.', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                ],
              ])),
              Container(width: 1, height: 60, color: Colors.grey.shade200),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _infoRow('Account Status', isActive ? 'Unrestricted' : 'Suspended', color: isActive ? Colors.green.shade700 : Colors.red.shade700),
                  const SizedBox(height: 12),
                  _infoRow('Security Level', 'Standard Admin'),
                ]),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }


  void _showAdminPrivilegesSheet(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1),
                      child: Text(a['name']?.toString()[0].toUpperCase() ?? '?', style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Manage Privileges', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
                          Text(a['name']?.toString() ?? 'Admin', style: TextStyle(color: AdminColors.textSub, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    Text('Module Access Control', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: AdminColors.textHeading)),
                    const SizedBox(height: 16),
                    ...['Overview', 'Vendors', 'Admins', 'Drivers', 'Verification', 'Dispatch Hub', 'Broadcasts', 'Support Hub', 'Intelligence', 'Security Audit', 'Report Center', 'Settings'].map((label) {
                      final currentPerms = Map<String, dynamic>.from(a['permissions'] ?? _adminPermissions);
                      final isAllowed = currentPerms[label] ?? false;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AdminColors.background.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminColors.border.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isAllowed ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                                  size: 18,
                                  color: isAllowed ? AdminColors.success : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(label, style: GoogleFonts.outfit(color: AdminColors.textHeading, fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Switch.adaptive(
                              value: isAllowed,
                              activeColor: AdminColors.primaryIndigo,
                              onChanged: (val) {
                                final newPerms = Map<String, bool>.from(currentPerms.map((k, v) => MapEntry(k, v == true)));
                                newPerms[label] = val;
                                
                                // Direct sync
                                _updateAdminPerms(a['_id'], newPerms);
                                
                                // Update local state for immediate UI feedback in sheet
                                setS(() {
                                  a['permissions'] = newPerms;
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _updateAdminPerms(String adminId, Map<String, bool> permissions) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/admins/$adminId/permissions'),
        headers: _headers,
        body: jsonEncode({'permissions': permissions}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _fetchAllAdmins(); // Refresh lists
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions updated effectively.'), backgroundColor: Color(0xFF10B981)),
        );
      } else {
        throw data['error'] ?? 'Sync failed';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddAdminSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Provision New Admin', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _inputField(nameCtrl, 'Admin Name', Icons.person_rounded),
          const SizedBox(height: 12),
          _inputField(phoneCtrl, 'Phone Number (10 digits)', Icons.phone_rounded),
          const SizedBox(height: 12),
          _inputField(emailCtrl, 'Email Address', Icons.email_rounded),
          const SizedBox(height: 12),
          _inputField(passCtrl, 'Admin Password', Icons.lock_rounded, obscure: true),
          const SizedBox(height: 12),
          _inputField(cityCtrl, 'City', Icons.location_city_rounded),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && phoneCtrl.text.length == 10 && passCtrl.text.isNotEmpty) {
                  _provisionAdmin({
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'password': passCtrl.text.trim(),
                    'city': cityCtrl.text.trim().isEmpty ? 'Chennai' : cityCtrl.text.trim(),
                  });
                  Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill Name, Phone (10 digits) and Password')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: Text('Create Admin', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── SETTINGS (ENTERPRISE SPLIT PANE) ─────────────────────────────────
  Widget _buildSettings() {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: AdminColors.textHeading, elevation: 0.5,
        title: Text('Platform Configuration', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
      ),
      body: Row(children: [
        // LEFT PANE: Settings Categories
        Container(
          width: 280, color: Colors.white,
          child: Column(children: [
            _settingsTab('Global Parameters', Icons.public_rounded, 0),
            _settingsTab('Financial Model', Icons.account_balance_wallet_rounded, 1),
            _settingsTab('Logistics Rules', Icons.local_shipping_rounded, 2),
            if (widget.user['role'] == 'superadmin') _settingsTab('Admin Access Control', Icons.admin_panel_settings_rounded, 4),
            _settingsTab('My Account', Icons.person_outline_rounded, 5),
            _settingsTab('Danger Zone', Icons.warning_rounded, 3, isDanger: true),
            const Spacer(),
            Container(height: 1, color: Colors.grey.shade100),
            InkWell(
              onTap: widget.onLogout,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: Row(children: [
                  const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Text('End Session', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.red, fontSize: 14)),
                ]),
              ),
            ),
          ]),
        ),
        Container(width: 1, color: Colors.grey.shade200),
        // RIGHT PANE: Settings Form
        Expanded(
          child: Container(
            color: AdminColors.background,
            child: ListView(padding: const EdgeInsets.all(40), children: [
              if (_settingsTabIdx == 0) _buildGlobalSettings()
              else if (_settingsTabIdx == 1) _buildFinancialSettings()
              else if (_settingsTabIdx == 2) _buildLogisticsSettings()
              else if (_settingsTabIdx == 3) _buildDangerSettings()
              else if (_settingsTabIdx == 4) _buildAdminAccessSettings()
              else if (_settingsTabIdx == 5) _buildAccountSettings(),
            ]),
          ),
        ),
      ]),
    );
  }

  void _showResetPasswordDialog(String adminId, String name) {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Reset Password ($name)', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter a new password for this administrator.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            _inputField(passCtrl, 'New Password', Icons.lock_reset_rounded, obscure: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (passCtrl.text.length >= 6) {
                Navigator.pop(ctx);
                _resetAdminPassword(adminId, passCtrl.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Reset Password', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _settingsTab(String label, IconData icon, int idx, {bool isDanger = false}) {
    final isSel = _settingsTabIdx == idx;
    final color = isDanger ? Colors.red.shade600 : (isSel ? AdminColors.primaryIndigo : Colors.grey.shade600);
    return InkWell(
      onTap: () => setState(() => _settingsTabIdx = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: isSel ? color.withOpacity(0.08) : Colors.transparent,
          border: isSel ? Border(left: BorderSide(color: color, width: 4)) : const Border(left: BorderSide(color: Colors.transparent, width: 4)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Text(label, style: GoogleFonts.outfit(fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, color: color, fontSize: 14)),
        ]),
      ),
    );
  }


  Widget _buildAdminAccessSettings() {
    final permissions = {
      'Overview': 'overview',
      'Vendors': 'vendors',
      'Admins': 'admins',
      'Drivers': 'drivers',
      'Verification': 'verification',
      'Dispatch Hub': 'dispatch',
      'Broadcasts': 'broadcasts',
      'Support Hub': 'support',
      'Intelligence': 'intelligence',
      'Security Audit': 'security',
      'Report Center': 'reports',
      'Settings': 'settings',
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Admin Access Control'),
      Text('Toggle which features are visible to regular administrators.', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 32),
      _settingsGroup(
        permissions.entries.map((e) {
          final label = e.key;
          final apiKey = e.value;
          return _toggleTile(
            label,
            'Allow access to $label module',
            Icons.check_circle_outline_rounded,
            AdminColors.primaryIndigo,
            _adminPermissions[label] ?? false,
            (val) {
              setState(() => _adminPermissions[label] = val);
              // Prepare the nested object for update
              final Map<String, dynamic> update = {'adminPermissions': {}};
              _adminPermissions.forEach((k, v) {
                final key = permissions[k];
                if (key != null) update['adminPermissions'][key] = v;
              });
              _updateSettings(update);
            },
          );
        }).toList(),
      ),
    ]);
  }

  Widget _buildGlobalSettings() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Global Parameters', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
      const SizedBox(height: 8),
      Text('Control platform-wide behavioral flags and configurations that affect all users.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      const SizedBox(height: 32),
      _settingsGroup([
        _toggleTile('Vendor Onboarding', 'Allow new vendors to register via the Vendor App.', Icons.how_to_reg_rounded, const Color(0xFF059669), _regEnabled, (v) => _updateSettings({'regEnabled': v})),
        Container(height: 1, color: Colors.grey.shade100),
        _toggleTile('System Maintenance Mode', 'Disable app access for all users except Super Admins.', Icons.build_rounded, Colors.red, _maintenanceMode, (v) => _updateSettings({'maintenanceMode': v})),
        Container(height: 1, color: Colors.grey.shade100),
        _toggleTile('Automated Dispatch', 'Automatically assign delivery partners using spatial algorithms.', Icons.auto_mode_rounded, AdminColors.primaryIndigo, _autoAssign, (v) => _updateSettings({'autoAssign': v})),
      ]),
      const SizedBox(height: 32),
      Text('Partner Program Benefits', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
      const SizedBox(height: 8),
      Text('Control which benefits and perks are visible and available to delivery partners.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const SizedBox(height: 16),
      _settingsGroup([
        _toggleTile('Insurance Protection', 'Provide accidental and health coverage details to riders.', Icons.shield_rounded, Colors.blue, _partnerInsuranceEnabled, (v) => _updateSettings({'partnerInsuranceEnabled': v})),
        Container(height: 1, color: Colors.grey.shade100),
        _toggleTile('Flexible Shifts', 'Show shift flexibility and login freedom options.', Icons.timer_rounded, Colors.orange, _partnerFlexibilityEnabled, (v) => _updateSettings({'partnerFlexibilityEnabled': v})),
        Container(height: 1, color: Colors.grey.shade100),
        _toggleTile('Growth Incentives', 'Display peak hour bonuses and referral reward programs.', Icons.trending_up_rounded, Colors.green, _partnerIncentivesEnabled, (v) => _updateSettings({'partnerIncentivesEnabled': v})),
        Container(height: 1, color: Colors.grey.shade100),
        _toggleTile('Social Welfare', 'Show initiatives like period leave and pension support.', Icons.favorite_rounded, Colors.pink, _partnerWelfareEnabled, (v) => _updateSettings({'partnerWelfareEnabled': v})),
      ]),
    ]);
  }

  Widget _buildFinancialSettings() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Financial Model', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
      const SizedBox(height: 8),
      Text('Tune the economic engine. Changes apply immediately to new transactions.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      const SizedBox(height: 32),
      _settingsGroup([
        _inputSettingTile('Platform Commission', 'Percentage platform takes per sale.', '5%', Icons.percent_rounded, AdminColors.primaryIndigo, () => _editSetting(context, 'Commission %', '5')),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Base Delivery Charge', 'Standard fee charged to customers.', '₹30', Icons.delivery_dining_rounded, AdminColors.primaryIndigo, () => _editSetting(context, 'Delivery Charge', '30')),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Minimum Order Value', 'Orders below this face rejection or surge fees.', '₹100', Icons.shopping_bag_rounded, const Color(0xFF059669), () => _editSetting(context, 'Min Order Value', '100')),
      ]),
    ]);
  }

  Widget _buildLogisticsSettings() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Logistics Rules', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
      const SizedBox(height: 8),
      Text('Define operational constraints and delivery radii definitions.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      const SizedBox(height: 32),
      _settingsGroup([
        _inputSettingTile('Platform Commission', 'Percentage platform takes per sale.', '${_commissionPct.toStringAsFixed(1)}%', Icons.percent_rounded, AdminColors.primaryIndigo, () => _editSetting(context, 'platformCommissionPct', _commissionPct.toString())),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Max Delivery Radius', 'Absolute maximum allowable delivery distance.', '$_deliveryRadius km', Icons.radar_rounded, const Color(0xFFD97706), () => _editSetting(context, 'maxDispatchRadiusKm', _deliveryRadius.toString())),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Service Center Lat', 'Center point of service area (Latitude).', _serviceCenterLat.toStringAsFixed(4), Icons.location_on_rounded, Colors.teal, () => _editSetting(context, 'serviceCenterLat', _serviceCenterLat.toString())),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Service Center Lng', 'Center point of service area (Longitude).', _serviceCenterLng.toStringAsFixed(4), Icons.location_on_rounded, Colors.teal, () => _editSetting(context, 'serviceCenterLng', _serviceCenterLng.toString())),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Max Service Radius', 'Restricts ALL platform orders to this radius.', '$_serviceRadius km', Icons.language_rounded, Colors.indigoAccent, () => _editSetting(context, 'maxServiceRadiusKm', _serviceRadius.toString())),
      ]),
      const SizedBox(height: 48),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Active Service Zones', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
            Text('Orders allowed only within these defined geographic areas.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ]),
          ElevatedButton.icon(
            onPressed: () => _showAddZoneSheet(context),
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: Text('Add New Zone', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (_serviceZones.isEmpty)
        _buildEmptyStateMini('No Custom Zones', 'Using global default center point.')
      else
        Column(
          children: _serviceZones.map((z) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.map_rounded, color: AdminColors.primaryIndigo)),
                const SizedBox(width: 20),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(z['name'] ?? 'Unnamed Zone', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text('Center: ${z['lat']}, ${z['lng']} • Radius: ${z['radiusKm']}km', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                )),
                Switch.adaptive(value: z['isActive'] ?? true, activeColor: Colors.green, onChanged: (v) => _toggleZoneStatus(z['_id'], v)),
                const SizedBox(width: 8),
                IconButton(onPressed: () => _deleteServiceZone(z['_id']), icon: const Icon(Icons.delete_outline_rounded, color: Colors.red)),
              ],
            ),
          )).toList(),
        ),
    ]);
  }

  void _showAddZoneSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final radCtrl = TextEditingController(text: '10');
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Define New Service Zone', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _inputField(nameCtrl, 'Zone Name (e.g. Perundurai Town)', Icons.label_rounded),
          const SizedBox(height: 12),
          _inputField(latCtrl, 'Center Latitude', Icons.location_on_rounded, type: TextInputType.number),
          const SizedBox(height: 12),
          _inputField(lngCtrl, 'Center Longitude', Icons.location_on_rounded, type: TextInputType.number),
          const SizedBox(height: 12),
          _inputField(radCtrl, 'Service Radius (KM)', Icons.radar_rounded, type: TextInputType.number),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && latCtrl.text.isNotEmpty && lngCtrl.text.isNotEmpty) {
                  _addServiceZone({
                    'name': nameCtrl.text.trim(),
                    'lat': double.tryParse(latCtrl.text.trim()) ?? 0.0,
                    'lng': double.tryParse(lngCtrl.text.trim()) ?? 0.0,
                    'radiusKm': double.tryParse(radCtrl.text.trim()) ?? 10.0,
                  });
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: Text('Create Service Zone', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDangerSettings() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Danger Zone', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.red.shade700)),
      const SizedBox(height: 8),
      Text('Irreversible administrative actions. Select specific domains to wipe or perform a full system reset.', style: TextStyle(color: Colors.red.shade400, fontSize: 14)),
      const SizedBox(height: 32),
      
      _dangerTile(
        'Wipe Delivery Partners', 
        'Deletes all registered delivery agents and their data.', 
        Icons.delivery_dining_rounded, 
        () => _showResetConfirmation('delivery', 'Wipe Delivery Partners?'),
      ),
      const SizedBox(height: 12),
      _dangerTile(
        'Wipe Customers', 
        'Permanently removes all customer profiles and history.', 
        Icons.people_alt_rounded, 
        () => _showResetConfirmation('customers', 'Wipe All Customers?'),
      ),
      const SizedBox(height: 12),
      _dangerTile(
        'Wipe Vendors', 
        'Deletes all registered shops and their product listings.', 
        Icons.storefront_rounded, 
        () => _showResetConfirmation('vendors', 'Wipe All Vendors?'),
      ),
      const SizedBox(height: 12),
      _dangerTile(
        'Wipe All Orders', 
        'Clears the complete order history and local sync file.', 
        Icons.receipt_long_rounded, 
        () => _showResetConfirmation('orders', 'Wipe Order History?'),
      ),
      const SizedBox(height: 12),
      _dangerTile(
        'Wipe Administrator Accounts', 
        'Deletes all admin users. WARNING: You will be locked out immediately.', 
        Icons.admin_panel_settings_rounded, 
        () => _showResetConfirmation('admins', 'Wipe Admin Accounts?'),
        isCritical: true,
      ),
      const SizedBox(height: 32),
      
      Container(
        padding: const EdgeInsets.all(24), 
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Full System Wipeout', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.red.shade900)),
            const SizedBox(height: 4),
            Text('Wipes everything except administrators. Used for major environment resets.', style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ])),
          ElevatedButton.icon(
            onPressed: () => _showResetConfirmation('full', 'Execute Full System Wipe?'),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Execute Full Wipeout'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
          ),
        ]),
      ),
    ]);
  }

  Widget _dangerTile(String title, String subtitle, IconData icon, VoidCallback onTap, {bool isCritical = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isCritical ? Colors.red.shade300 : Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: (isCritical ? Colors.red : Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: isCritical ? Colors.red : Colors.grey.shade700, size: 24),
        ),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: isCritical ? Colors.red.shade900 : AdminColors.textHeading)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        trailing: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: isCritical ? Colors.red : Colors.grey.shade700,
            side: BorderSide(color: isCritical ? Colors.red : Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Wipe', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _settingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: children),
    );
  }

  Widget _inputSettingTile(String title, String subtitle, String value, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: AdminColors.textHeading)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AdminColors.background, borderRadius: BorderRadius.circular(8)),
            child: Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.edit_rounded, color: Colors.grey, size: 16),
        ]),
      ),
    );
  }

  Widget _toggleTile(String title, String subtitle, IconData icon, Color color, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: AdminColors.textHeading)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ])),
        Switch.adaptive(value: value, onChanged: onChanged, activeColor: color),
      ]),
    );
  }

  void _editSetting(BuildContext context, String field, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Edit $field', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
      content: TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: field, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { 
            Navigator.pop(context); 
            double? val = double.tryParse(ctrl.text);
            if (val != null) {
              _updateSettings({field: val});
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo, foregroundColor: Colors.white),
          child: const Text('Save'),
        ),
      ],
    ));
  }

  // ── Helpers ──────────────────────────────────────────────────────────
  Widget _statCard(String label, String value, IconData icon, Color color, {String sub = ''}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
          const Spacer(),
          if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        Text(value.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        Text(label.toString(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _metricCard(String label, String? value, IconData icon, Color color, String? trend) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          const Spacer(),
          Text(trend ?? '', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
        ]),
        const Spacer(),
        Text(value ?? 'N/A', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _infoRow(String label, String? value, {Color? color}) {
    return Row(children: [
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value ?? 'N/A', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: color ?? AdminColors.textHeading)),
    ]);
  }

  Widget _sectionHeader(String title) =>
      Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900));

  void _showResetConfirmation(String target, String title) {
    final isAdmins = target == 'admins';
    final isFull = target == 'full';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: isAdmins ? Colors.red.shade900 : Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: isAdmins ? Colors.red.shade900 : Colors.red.shade700))),
        ]),
        content: Text(
          isAdmins 
            ? '🚀 WARNING: This will delete ALL administrator accounts. You will be logged out and LOCKED OUT of the system immediately. Are you absolutely sure?'
            : isFull 
              ? 'This will permanently delete all Vendors, Customers, Delivery Partners, and Orders. Admin accounts will be preserved.'
              : 'This will permanently delete all ${target.toUpperCase()} data. This action cannot be undone.',
          style: GoogleFonts.outfit(fontSize: 14, color: isAdmins ? Colors.red.shade900 : Colors.grey.shade700, fontWeight: isAdmins ? FontWeight.bold : FontWeight.normal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetDatabase(target);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAdmins ? Colors.black : Colors.red.shade700, 
              foregroundColor: Colors.white, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isAdmins ? 'YES, DELETE ADMINS' : 'Confirm Wipe', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetDatabase(String target) async {
    final endpoint = target == 'full' ? 'reset-database' : 'reset/$target';
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Wiping $target data...'), duration: const Duration(seconds: 1)),
    );

    try {
      final response = await http.delete(Uri.parse('$_baseUrl/admin/$endpoint'), headers: _headers);
      
      if (response.headers['content-type']?.contains('html') == true) {
        throw 'Server returned an HTML error (404/500). Please check if the backend is running.';
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Refresh relevant UI
        _fetchPendingVendors();
        _fetchAllVendors();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Data wiped successfully!'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (target == 'admins') {
          // If admins wiped, we must log out using the provided callback
          Future.delayed(const Duration(seconds: 2), () {
            widget.onLogout();
          });
        }
      } else {
        throw Exception(data['error'] ?? 'Wipe failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── SUPPORT HUB (INCIDENT ORCHESTRATION) ─────────────────────────────
  Widget _buildSupportHub() {
    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('SUPPORT & INCIDENTS', 'Active Resolution Desk'),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(40),
              itemCount: _supportTickets.length,
              itemBuilder: (context, i) {
                final t = _supportTickets[i];
                final color = t['status'] == 'Resolved' ? Colors.green : (t['priority'] == 'Critical' ? Colors.red : Colors.orange);
                return _eliteTicketCard(t, color);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _eliteTicketCard(Map<String, dynamic> t, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        leading: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.confirmation_num_rounded, color: color, size: 28),
        ),
        title: Row(
          children: [
            Text(t['id'], style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(t['status'].toUpperCase(), style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(t['issue'], style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AdminColors.textHeading)),
            const SizedBox(height: 4),
            Text('${t['user']} • ${t['time']}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
        trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16)),
      ),
    );
  }

  // ── MARKET INTELLIGENCE (GEOGRAPHIC INSIGHTS) ─────────────────────────
  Widget _buildMarketIntelligence() {
    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('MARKET INTELLIGENCE', 'Geographic Predictive Insights'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                   _buildHeatmapView(),
                   const SizedBox(height: 32),
                   Row(
                    children: [
                      Expanded(child: _marketPredictCard('HIGH GROWTH', 'Chennai North', '+24% Surge', Colors.orange)),
                      const SizedBox(width: 32),
                      Expanded(child: _marketPredictCard('IDLE ZONES', 'Old Mahabalipuram', '5 Drivers Wait', Colors.blue)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapView() {
    return Container(
      height: 500, width: double.infinity,
      decoration: BoxDecoration(
        color: AdminColors.sidebarBg,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: AdminColors.primaryIndigo.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _heatmapOrderPoints.isNotEmpty ? _heatmapOrderPoints.first : LatLng(13.0827, 80.2707),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.namba.admin',
              ),
              // Orders Heatmap (Red Circles)
              CircleLayer(
                circles: _heatmapOrderPoints.map<CircleMarker>((p) => CircleMarker(
                  point: p,
                  radius: 100,
                  useRadiusInMeter: true,
                  color: Colors.red.withOpacity(0.3),
                  borderColor: Colors.red,
                  borderStrokeWidth: 1,
                )).toList(),
              ),
              // Riders (Yellow Markers)
              MarkerLayer(
                markers: _heatmapRiders.map<Marker>((r) => Marker(
                  point: LatLng((r['lat'] as num?)?.toDouble() ?? 0.0, (r['lng'] as num?)?.toDouble() ?? 0.0),
                  width: 40, height: 40,
                  child: Column(
                    children: [
                      const Icon(Icons.delivery_dining_rounded, color: Colors.yellow, size: 20),
                      Text(r['name'].toString().split(' ').first, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ),
          // Legend Overlay
          Positioned(
            top: 24, right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heatmapLegendItem('ORDER DENSITY', Colors.red),
                  const SizedBox(height: 8),
                  _heatmapLegendItem('ACTIVE RIDERS', Colors.yellow),
                ],
              ),
            ),
          ),
          if (_isHeatmapLoading) const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
          Positioned(
            bottom: 24, left: 24,
            child: FloatingActionButton.small(
              onPressed: _fetchHeatmapData,
              backgroundColor: AdminColors.primaryIndigo,
              child: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heatmapLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  Widget _marketPredictCard(String tag, String area, String detail, Color color) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(tag, style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 16),
          Text(area, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(detail, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showPlanDialog({AdminSubscriptionPlan? plan}) {
    final nameCtrl = TextEditingController(text: plan?.name ?? '');
    final priceCtrl = TextEditingController(text: plan?.price.toInt().toString() ?? '');
    final featureCtrl = TextEditingController();
    List<String> features = plan != null ? List.from(plan.features) : [];
    bool isPopular = plan?.isPopular ?? false;
    String selectedColor = plan?.color ?? '#6366F1';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(plan == null ? 'Create New Plan' : 'Edit Plan', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: 'Plan Name', hintText: 'e.g., Business Pro', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceCtrl,
                    decoration: InputDecoration(labelText: 'Price (₹)', hintText: 'e.g., 999', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  Text('FEATURES', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: featureCtrl,
                          decoration: InputDecoration(hintText: 'Add a feature...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          if (featureCtrl.text.isNotEmpty) {
                            setModalState(() {
                              features.add(featureCtrl.text);
                              featureCtrl.clear();
                            });
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AdminColors.primaryIndigo),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: features.map((f) => Chip(
                      label: Text(f, style: const TextStyle(fontSize: 11)),
                      onDeleted: () => setModalState(() => features.remove(f)),
                      deleteIcon: const Icon(Icons.cancel, size: 14),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text('Mark as Popular'),
                      const Spacer(),
                      Switch(
                        value: isPopular,
                        onChanged: (v) => setModalState(() => isPopular = v),
                        activeColor: AdminColors.primaryIndigo,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newPlan = AdminSubscriptionPlan(
                  id: plan?.id ?? '',
                  name: nameCtrl.text,
                  price: double.tryParse(priceCtrl.text) ?? 0,
                  period: 'month',
                  features: features,
                  icon: 'star',
                  color: selectedColor,
                  isPopular: isPopular,
                );

                bool success;
                if (plan == null) {
                  success = await SubscriptionService.createPlan(newPlan);
                } else {
                  success = await SubscriptionService.updatePlan(plan.id, newPlan.toJson());
                }

                if (success) {
                  Navigator.pop(context);
                  _fetchSubscriptionPlans();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(plan == null ? 'Create Plan' : 'Save Changes', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── SECURITY AUDIT (SYSTEM OVERSIGHT) ──────────────────────────────────
  // ── SUBSCRIPTION PLANS MANAGEMENT ─────────────────────────────────────
  Widget _buildPlansTab() {
    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('SUBSCRIPTION PLANS', 'Manage packages and pricing'),
          Expanded(
            child: _isPlansLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(40),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ACTIVE PLANS', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
                        ElevatedButton.icon(
                          onPressed: () => _showPlanDialog(),
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          label: Text('CREATE NEW PLAN', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminColors.primaryIndigo,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _subscriptionPlans.length,
                      itemBuilder: (context, i) {
                        final plan = _subscriptionPlans[i];
                        final hexColor = plan.color.replaceAll('#', '');
                        final color = Color(int.parse('FF$hexColor', radix: 16));
                        
                        return Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))],
                            border: plan.isPopular ? Border.all(color: color, width: 2) : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                                    child: Icon(Icons.star_rounded, color: color, size: 24),
                                  ),
                                  if (plan.isPopular)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                                      child: Text('POPULAR', style: GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(plan.name, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${plan.price.toInt()}', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900)),
                                  Text('/${plan.period}', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 16),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: plan.features.length,
                                  itemBuilder: (ctx, idx) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 14),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(plan.features[idx], style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600))),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _showPlanDialog(plan: plan),
                                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      child: const Text('Edit'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _confirmDeletePlan(plan),
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                    style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1)),
                                  ),
                                ],
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
    );
  }

  void _confirmDeletePlan(AdminSubscriptionPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Plan?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to delete ${plan.name}? This may affect vendors currently on this plan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await SubscriptionService.deletePlan(plan.id);
              if (success) {
                _fetchSubscriptionPlans();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityAudit() {
    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('SECURITY AUDIT', 'Platform Integrity Logs'),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(40),
              itemCount: _adminAuditLogs.length,
              itemBuilder: (context, i) {
                final log = _adminAuditLogs[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    children: [
                      Container(width: 48, height: 48, decoration: BoxDecoration(color: AdminColors.background, shape: BoxShape.circle), child: const Icon(Icons.security_rounded, size: 20, color: Color(0xFF1E293B))),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log['detail'], style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15)),
                            Text('Actor: ${log['user']} • ${log['time']}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(log['action'], style: GoogleFonts.outfit(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 10)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markVendorPaid(String orderId) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final response = await http.put(Uri.parse('$_baseUrl/orders/$orderId/admin-pay-vendor'), headers: _headers);
      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context); // Close loading
        _fetchCustomerOrders();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment marked as Completed!'), backgroundColor: Colors.green));
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update payment status.'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildVendorPaymentsTab() {
    final pendingPayments = _customerOrders.where((o) => o['vendorPaymentDetailsUploadedByDriver'] == true && o['vendorPaymentStatus'] == 'Pending').toList();

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(40, 48, 40, 32),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FINANCE', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('Vendor Payments', style: GoogleFonts.outfit(color: AdminColors.textHeading, fontWeight: FontWeight.w900, fontSize: 32)),
                ]),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(pendingPayments.length.toString(), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.orange)),
                  Text('PENDING REQUESTS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1)),
                ]),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: _fetchCustomerOrders,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7C3AED)),
                  style: IconButton.styleFrom(backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1), padding: const EdgeInsets.all(12)),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: pendingPayments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No Pending Vendor Payments', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Text('All requests will appear here when drivers upload vendor payment details.', style: GoogleFonts.outfit(color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(40),
                    itemCount: pendingPayments.length,
                    itemBuilder: (context, index) {
                      final order = pendingPayments[index];
                      final displayId = order['displayId'] ?? order['_id']?.substring(0, 6) ?? '';
                      final vendorName = order['vendor']?['storeName'] ?? order['customStoreName'] ?? 'Vendor';
                      final amount = order['totalAmount']?.toString() ?? '0';
                      final upiNumber = order['vendorUpiNumber'];
                      final qrPath = order['vendorUpiQrPath'];
                      final isNetworkQr = qrPath != null;
                      final qrUrl = isNetworkQr ? '${_baseUrl.split('/api').first}$qrPath' : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon/Indicator
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.receipt_long_rounded, color: Colors.orange, size: 28),
                            ),
                            const SizedBox(width: 24),
                            
                            // Info Column
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text('ORDER #$displayId', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                      child: Text('ACTION REQUIRED', style: GoogleFonts.outfit(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900)),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text(vendorName, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Text('Amount to Pay: ₹$amount', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green)),
                                  const SizedBox(height: 24),
                                  
                                  if (upiNumber != null) ...[
                                    Text('Vendor UPI Number', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(upiNumber, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: upiNumber));
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI Number coped to clipboard!'), duration: Duration(seconds: 1)));
                                          },
                                          icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ] else if (qrUrl != null) ...[
                                    Text('Vendor QR Code Image', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(qrUrl, height: 250, fit: BoxFit.cover),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            
                            // Action Column
                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      minimumSize: const Size(double.infinity, 60),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    onPressed: () => _markVendorPaid(order['_id']),
                                    child: const Text('MARK AS PAID ✓', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                  ),
                                  const SizedBox(height: 16),
                                  Text('Once marked as paid, the delivery partner will be notified to proceed with picking up the items.',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11), textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerPaymentsTab() {
    // Combine current and history orders that are paid
    final allPaid = [
      ..._customerOrders.where((o) => o['paymentStatus'] == 'Completed' || o['customerPaid'] == true),
      ..._customerOrderHistory.where((o) => o['paymentStatus'] == 'Completed' || o['customerPaid'] == true),
    ];

    // Filter into two categories
    final vendorPayments = allPaid.where((o) => o['isCustomStore'] != true).toList();
    final anyShopPayments = allPaid.where((o) => o['isCustomStore'] == true).toList();

    return DefaultTabController(
      length: 2,
      child: Container(
        color: AdminColors.background,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(40, 48, 40, 0),
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
              child: Column(
                children: [
                  Row(
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('FINANCE', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text('Customer Payments', style: GoogleFonts.outfit(color: AdminColors.textHeading, fontWeight: FontWeight.w900, fontSize: 32)),
                      ]),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(allPaid.length.toString(), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF059669))),
                        Text('TOTAL SUCCESSFUL PAYMENTS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1)),
                      ]),
                      const SizedBox(width: 24),
                      IconButton(
                        onPressed: () {
                          _fetchCustomerOrders();
                          _fetchCustomerOrderHistory();
                        },
                        icon: const Icon(Icons.refresh_rounded, color: AdminColors.primaryIndigo),
                        style: IconButton.styleFrom(backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1), padding: const EdgeInsets.all(12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AdminColors.primaryIndigo,
                    unselectedLabelColor: Colors.grey.shade400,
                    indicatorColor: AdminColors.primaryIndigo,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
                    unselectedLabelStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: 'Shop Payments (${vendorPayments.length})'),
                      Tab(text: 'Any Shop Payments (${anyShopPayments.length})'),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: TabBarView(
                children: [
                  _buildPaymentList(vendorPayments, 'No Shop Payments Yet'),
                  _buildPaymentList(anyShopPayments, 'No Any Shop Payments Yet'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentList(List<dynamic> payments, String emptyMsg) {
    if (payments.isEmpty && (_isCustomerOrdersLoading || _isCustomerHistoryLoading)) {
      return const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo));
    }
    
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_rounded, size: 80, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text(emptyMsg, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(40),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final order = payments[index];
        final displayId = order['displayId'] ?? order['_id']?.substring(0, 6) ?? '';
        final customerName = order['customer']?['name'] ?? 'Guest Customer';
        final amount = order['totalAmount']?.toString() ?? '0';
        final method = order['paymentMethod']?.toString().toUpperCase() ?? 'UPI';
        final isCustom = order['isCustomStore'] == true;
        final storeName = isCustom 
            ? (order['customStoreName'] ?? 'Any Shop')
            : (order['vendor']?['storeName'] ?? 'Vendor');
        
        final date = order['updatedAt'] != null 
            ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order['updatedAt']))
            : 'Recent';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: () => _showOrderDetails(order),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isCustom ? Colors.orange : const Color(0xFF059669)).withOpacity(0.1), 
                        shape: BoxShape.circle
                      ),
                      child: Icon(
                        isCustom ? Icons.auto_awesome_rounded : Icons.check_circle_rounded, 
                        color: isCustom ? Colors.orange : const Color(0xFF059669), 
                        size: 24
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('ORDER #$displayId', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                              const SizedBox(width: 12),
                              Text(date, style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(customerName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AdminColors.textHeading)),
                          Row(
                            children: [
                              Text('To $storeName', style: TextStyle(color: AdminColors.primaryIndigo.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Text('•', style: TextStyle(color: Colors.grey.shade300)),
                              const SizedBox(width: 8),
                              Text('Payment via $method', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹$amount', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF059669))),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text('VIEW ORDER DETAILS', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── ORDER BILLS HUB ──────────────────────────────────────────────────
  Widget _buildOrderBillsTab() {
    try {
      // USE PRE-PROCESSED DATA EXCLUSIVELY
      final billOrders = _processedBillOrders;
      final isLoading = _isCustomerOrdersLoading || _isCustomerHistoryLoading;

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(40, 48, 40, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BILL VERIFICATION', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text('Order Bills Hub', style: GoogleFonts.outfit(color: AdminColors.textHeading, fontWeight: FontWeight.w900, fontSize: 32)),
                  ],
                ),
                const Spacer(),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                _statCard('TOTAL BILLS', billOrders.length.toString(), Icons.receipt_long_rounded, AdminColors.primaryIndigo),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: () { _fetchCustomerOrders(); _fetchCustomerOrderHistory(); },
                  icon: const Icon(Icons.refresh_rounded, color: AdminColors.primaryIndigo),
                  style: IconButton.styleFrom(backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1), padding: const EdgeInsets.all(12)),
                ),
              ],
            ),
          ),

          Expanded(
            child: (billOrders.isEmpty && !isLoading)
                ? _buildEmptyBillsState()
                : (billOrders.isEmpty && isLoading)
                  ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo))
                  : GridView.builder(
                    padding: const EdgeInsets.all(40),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: billOrders.length,
                    itemBuilder: (context, index) => _buildBillCard(billOrders[index]),
                  ),
          ),
        ],
      ),
    );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Something went wrong loading bills.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(e.toString(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () { _fetchCustomerOrders(); _fetchCustomerOrderHistory(); },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildEmptyBillsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          Text('No Bills Uploaded Yet', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          Text('Uploaded bill photos from delivery partners will appear here.', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> order) {
    final rawPath = order['billPhotoPath']?.toString() ?? '';
    final isLocal = !rawPath.contains('http') && !rawPath.startsWith('/public');
    final billUrl = isLocal ? rawPath : (rawPath.startsWith('http') ? rawPath : '${_baseUrl.split('/api').first}$rawPath');
    final driver = order['driver'] != null ? order['driver'] : null;
    final driverName = driver != null ? (driver is Map ? driver['name']?.toString() : 'Unknown') ?? 'Unknown' : 'Unknown Driver';
    
    DateTime? uploadDate;
    if (order['billUploadedAt'] != null) {
      final rawDate = order['billUploadedAt'];
      if (rawDate is String) {
        uploadDate = DateTime.tryParse(rawDate);
      } else if (rawDate is num) {
        uploadDate = DateTime.fromMillisecondsSinceEpoch(rawDate.toInt());
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bill Image Preview
          Expanded(
            child: Stack(
               children: [
                Positioned.fill(
                  child: isLocal
                    ? Image.file(File(billUrl), fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade100, child: const Icon(Icons.broken_image_outlined, color: Colors.grey)))
                    : CachedNetworkImage(
                        imageUrl: billUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 500,
                        placeholder: (context, url) => Container(color: Colors.grey.shade50, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        errorWidget: (context, url, error) => Container(color: Colors.grey.shade100, child: const Icon(Icons.broken_image_outlined, color: Colors.grey)),
                      ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showImagePreviewDialog(billUrl, 'Order Bill - ${order['displayId']}'),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: Text(order['displayId']?.toString() ?? '#---', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          
          // Info Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.person_outline_rounded, color: AdminColors.primaryIndigo, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('UPLOADED BY', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 0.5)),
                          Text(driverName, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AdminColors.textHeading)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.grey, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      uploadDate != null 
                        ? '${uploadDate.day} ${_getMonth(uploadDate.month)}, ${uploadDate.hour.toString().padLeft(2, '0')}:${uploadDate.minute.toString().padLeft(2, '0')} ${uploadDate.hour >= 12 ? 'PM' : 'AM'}'
                        : 'Unknown Time',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                InkWell(
                  onTap: () => _showOrderDetails(order),
                  child: Row(
                    children: [
                      Text('VIEW ORDER DETAILS', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AdminColors.primaryIndigo, size: 12),
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

  void _showImagePreviewDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16), // Smaller inset for larger view
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AdminColors.textHeading)),
                leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
                elevation: 0,
                centerTitle: true,
              ),
            ),
            Flexible(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9), // Subtle light background for the viewer
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: imageUrl.contains(':\\') || (imageUrl.isNotEmpty && !imageUrl.startsWith('http'))
                      ? Image.file(
                          File(imageUrl),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey)),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo)),
                          errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey)),
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: Text(
                'Pinch to Zoom • Drag to Pan',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // ── FINANCIAL INTELLIGENCE METHODS ─────────────────────────────────────
  Future<void> _fetchFinancialStats({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isFinancialLoading = true);
    try {
      final res = await http.get(Uri.parse('$_baseUrl/admin/financial-analytics'), headers: _headers);
      final data = jsonDecode(res.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _financialSummary = data['data']['summary'];
          _financialTrends = data['data']['trends'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching finance stats: $e');
    } finally {
      if (mounted && !silent) setState(() => _isFinancialLoading = false);
    }
  }

  Future<void> _fetchPerformanceAnalytics({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isPerformanceLoading = true);
    try {
      final res = await http.get(Uri.parse('$_baseUrl/admin/performance-analytics'), headers: _headers);
      final data = jsonDecode(res.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _topVendors = List<Map<String, dynamic>>.from(data['data']['topVendors']);
          _driverPerformance = List<Map<String, dynamic>>.from(data['data']['driverPerformance']);
        });
      }
    } catch (e) {
      debugPrint('Error fetching performance stats: $e');
    } finally {
      if (mounted && !silent) setState(() => _isPerformanceLoading = false);
    }
  }

  Widget _buildFinancialIntelligence() {
    final summary = _financialSummary ?? {
      'totalRevenue': 0.0,
      'totalDeliveryCharges': 0.0,
      'totalVendorFees': 0.0,
      'totalCustomerPlatformFees': 0.0,
      'orderCount': 0,
    };

    final fmt = (dynamic v) => NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN').format(v ?? 0);

    return Container(
      color: AdminColors.background,
      child: RefreshIndicator(
        onRefresh: _fetchFinancialStats,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(40, 48, 40, 40),
          children: [
            // HEADER
            Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FINANCIAL INTELLIGENCE', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text('Platform Revenue Analysis', style: GoogleFonts.outfit(color: AdminColors.textHeading, fontWeight: FontWeight.w900, fontSize: 32)),
                ]),
                const Spacer(),
                
                // INLINE REPLACEMENT FOR MISSING _buildHeaderStats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9))),
                  child: Row(children: [
                    const Icon(Icons.shopping_bag_rounded, color: AdminColors.primaryIndigo, size: 20),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Orders', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
                      Text('${summary['orderCount'] ?? 0}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
                    ]),
                  ]),
                ),

                const SizedBox(width: 16),

                // INLINE REPLACEMENT FOR MISSING _actionBtn
                InkWell(
                  onTap: _fetchFinancialStats,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: AdminColors.primaryIndigo, borderRadius: BorderRadius.circular(12)),
                    child: _isFinancialLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(children: [
                          const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('Refresh Data', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // SUMMARY CARDS
            Row(
              children: [
                _financialCard('TOTAL REVENUE', fmt(summary['totalRevenue']), [const Color(0xFF6366F1), const Color(0xFF8B5CF6)], Icons.account_balance_rounded),
                const SizedBox(width: 24),
                _financialCard('DELIVERY INCOME', fmt(summary['totalDeliveryCharges']), [const Color(0xFF10B981), const Color(0xFF059669)], Icons.local_shipping_rounded),
                const SizedBox(width: 24),
                _financialCard('VENDOR CHARGES', fmt(summary['totalVendorFees']), [const Color(0xFFF59E0B), const Color(0xFFD97706)], Icons.store_rounded),
                const SizedBox(width: 24),
                _financialCard('PLATFORM FEES', fmt(summary['totalCustomerPlatformFees']), [const Color(0xFFEC4899), const Color(0xFFDB2777)], Icons.app_registration_rounded),
              ],
            ),

            const SizedBox(height: 48),

            // CHARTS SECTION
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _chartContainer(
                    title: 'Revenue Source Comparison',
                    subtitle: 'Relative breakdown of delivery vs vendor vs customer fees',
                    child: SizedBox(height: 350, child: _buildComparisonBarChart(summary)),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _chartContainer(
                    title: 'Growth Trends',
                    subtitle: 'Revenue performance over the last 7 days',
                    child: SizedBox(height: 350, child: _buildTrendsLineChart()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            _chartContainer(
              title: 'Recent Transactions',
              subtitle: 'Latest financial movements across the platform',
              child: _buildTransactionTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _financialCard(String label, String value, List<Color> colors, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(label, style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              Icon(icon, color: Colors.white.withOpacity(0.4), size: 18),
            ]),
            const SizedBox(height: 16),
            Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ],
        ),
      ),
    );
  }

  Widget _chartContainer({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(color: AdminColors.textHeading, fontSize: 18, fontWeight: FontWeight.w900)),
          Text(subtitle, style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 40),
          child,
        ],
      ),
    );
  }

  Widget _buildComparisonBarChart(Map<String, dynamic> summary) {
    final d = (summary['totalDeliveryCharges'] ?? 0.0).toDouble();
    final v = (summary['totalVendorFees'] ?? 0.0).toDouble();
    final p = (summary['totalCustomerPlatformFees'] ?? 0.0).toDouble();
    final maxVal = [d, v, p].reduce((a, b) => a > b ? a : b) * 1.4;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal == 0 ? 100 : maxVal,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12);
                switch (val.toInt()) {
                  case 0: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('DELIVERY', style: style));
                  case 1: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('VENDOR', style: style));
                  case 2: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('PLATFORM', style: style));
                  default: return const Text('');
                }
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: d, color: const Color(0xFF10B981), width: 40, borderRadius: BorderRadius.circular(6))]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: v, color: const Color(0xFFF59E0B), width: 40, borderRadius: BorderRadius.circular(6))]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: p, color: const Color(0xFFEC4899), width: 40, borderRadius: BorderRadius.circular(6))]),
        ],
      ),
    );
  }

  Widget _buildTrendsLineChart() {
    if (_financialTrends.isEmpty) return const Center(child: Text('Not enough data', style: TextStyle(color: Colors.grey)));
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _financialTrends.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['delivery'] + e.value['vendor'] + e.value['platform']).toDouble())).toList(),
            isCurved: true, color: AdminColors.primaryIndigo, barWidth: 4, dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AdminColors.primaryIndigo.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTable() {
    // Sort and take top 10 recent orders for the mini dashboard table
    final recentOrders = [..._customerOrders, ..._customerOrderHistory];
    
    if (recentOrders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text('No transactions yet', style: GoogleFonts.outfit(color: Colors.grey))),
      );
    }

    return Table(
      children: [
        TableRow(
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
          children: [_financeTableHead('DATE'), _financeTableHead('DESC'), _financeTableHead('STREAM'), _financeTableHead('AMOUNT'), _financeTableHead('STATUS')],
        ),
        ...recentOrders.take(10).map((order) {
          final displayId = order['displayId']?.toString() ?? '---';
          final total = order['totalAmount']?.toString() ?? '0';
          final status = order['status']?.toString() ?? 'Pending';
          
          String dateStr = 'Today';
          try {
            final rawDate = order['createdAt'];
            if (rawDate != null) {
              final dt = DateTime.parse(rawDate.toString());
              dateStr = DateFormat('dd MMM').format(dt);
            }
          } catch (_) {}

          final isRevenue = status == 'Completed' || status == 'Delivered';
          
          return TableRow(
            children: [
              _financeTableCell(dateStr), 
              _financeTableCell('Order #$displayId', isBold: true), 
              _financeTableCell(order['isCustomOrder'] == true ? 'Custom Delivery' : 'Standard Order'),
              _financeTableCell('₹$total', color: isRevenue ? Colors.green : Colors.blue), 
              _financeTableCell(status, isBadge: true),
            ],
          );
        }),
      ],
    );
  }

  Widget _financeTableHead(String text) => Padding(padding: const EdgeInsets.all(16), child: Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade600)));
  Widget _financeTableCell(String text, {bool isBold = false, Color? color, bool isBadge = false}) {
    return Padding(padding: const EdgeInsets.all(16),
      child: isBadge ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (text == 'Settled' ? Colors.green : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(text, style: TextStyle(color: text == 'Settled' ? Colors.green : Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
          ) : Text(text, style: GoogleFonts.outfit(fontSize: 13, fontWeight: isBold ? FontWeight.w800 : FontWeight.w500, color: color ?? AdminColors.textHeading)),
    );
  }
}



class _RadarNode extends StatelessWidget {
  final String name;
  final String status;
  const _RadarNode({required this.name, required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Marker UI
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AdminColors.primaryIndigo.withOpacity(0.2), blurRadius: 15, spreadRadius: 5)],
            border: Border.all(color: AdminColors.primaryIndigo, width: 2),
          ),
          child: const Icon(Icons.directions_bike_rounded, color: AdminColors.primaryIndigo, size: 20),
        ),
        const SizedBox(height: 8),
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AdminColors.sidebarBg.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(name.toUpperCase(), 
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({super.key});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: Colors.green.shade400,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.green.shade400.withOpacity(1 - _controller.value), blurRadius: 8 * _controller.value, spreadRadius: 4 * _controller.value),
            ],
          ),
        );
      },
    );
  }
}

// ── ISOLATED BILLS HUB VIEW ───────────────────────────────────────────
class OrderBillsHubView extends StatelessWidget {
  final List<Map<String, dynamic>> processedBills;
  final bool isLoading;
  final VoidCallback onRefresh;
  final Function(Map<String, dynamic>) onViewOrder;
  final Function(String, String) onPreviewImage;
  final String baseUrl;

  const OrderBillsHubView({
    super.key,
    required this.processedBills,
    required this.isLoading,
    required this.onRefresh,
    required this.onViewOrder,
    required this.onPreviewImage,
    required this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(40, 48, 40, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BILL VERIFICATION', style: GoogleFonts.outfit(color: const Color(0xFF6366F1), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text('Order Bills Hub', style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontWeight: FontWeight.w900, fontSize: 32)),
                  ],
                ),
                const Spacer(),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 24),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                  ),
                _simpleStat('TOTAL BILLS', processedBills.length.toString()),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6366F1)),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF6366F1).withOpacity(0.1), padding: const EdgeInsets.all(12)),
                ),
              ],
            ),
          ),

          Expanded(
            child: (processedBills.isEmpty && !isLoading)
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(40),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: processedBills.length,
                    itemBuilder: (context, index) {
                      try {
                        return _SafeBillCard(
                          order: processedBills[index],
                          baseUrl: baseUrl,
                          onViewDetails: onViewOrder,
                          onPreviewImage: onPreviewImage,
                        );
                      } catch (e) {
                        return const SizedBox.shrink();
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _simpleStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
          Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 24),
          Text('No bills found yet', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          Text('Uploaded bill photos will appear here automatically.', style: TextStyle(color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

class _SafeBillCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String baseUrl;
  final Function(Map<String, dynamic>) onViewDetails;
  final Function(String, String) onPreviewImage;

  const _SafeBillCard({
    required this.order,
    required this.baseUrl,
    required this.onViewDetails,
    required this.onPreviewImage,
  });

  @override
  Widget build(BuildContext context) {
    final billPath = order['billPhotoPath']?.toString() ?? '';
    final isLocal = billPath.startsWith('C:') || billPath.startsWith('/') || billPath.contains('\\');
    final billUrl = isLocal ? billPath : '${baseUrl.split('/api').first}$billPath';
    final displayId = order['displayId']?.toString() ?? '#---';
    
    // Driver Safe Access
    String driverName = 'Unknown Driver';
    final driverData = order['driver'];
    if (driverData != null && driverData is Map) {
      driverName = driverData['name']?.toString() ?? 'Unknown Driver';
    }

    // Date Safe Access
    String dateStr = 'Unknown Time';
    final rawDate = order['billUploadedAt'];
    if (rawDate != null) {
      try {
        DateTime? dt;
        if (rawDate is String) dt = DateTime.tryParse(rawDate);
        else if (rawDate is num) dt = DateTime.fromMillisecondsSinceEpoch(rawDate.toInt());
        
        if (dt != null) {
          dateStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
        }
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onPreviewImage(billUrl, 'Order Bill - $displayId'),
                      child: isLocal 
                        ? Image.file(
                            File(billPath),
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
                            ),
                          )
                        : Image.network(
                            billUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
                            ),
                          ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: Text(displayId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UPLOADED BY', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 0.5)),
                Text(driverName, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                InkWell(
                  onTap: () => onViewDetails(order),
                  child: Row(
                    children: [
                      Text('VIEW DETAILS', style: GoogleFonts.outfit(color: const Color(0xFF6366F1), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF6366F1), size: 12),
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
}
