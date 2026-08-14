import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'main.dart';

import 'employee_roster_screen.dart';
import 'attendance_hub_screen.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'driver_verification_screen.dart';
import 'services/admin_service.dart';
import 'services/subscription_service.dart';

import 'theme/admin_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'live_tracking_screen.dart';

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
  int _vendorSubTab = 0; // 0: Directory, 1: Block List, 2: Approvals
  bool _codEnabled = true;
  bool _regEnabled = true;
  bool _maintenanceMode = false;
  bool _autoAssign = true;
  String _vendorAlertSound = 'new_order_alert';
  bool _vendorCommissionEnabled = true;
  double _commissionPct = 5.0;
  bool _customerPlatformFeeEnabled = true;
  double _customerPlatformFeeAmount = 5.0;
  int _deliveryRadius = 20;
  double _serviceCenterLat = 11.3410;
  double _serviceCenterLng = 77.7172;
  int _serviceRadius = 20;

  // Delivery Partner Kilometer Pay Settings
  bool _includeRiderPickupDistance = true;
  double _driverBaseRatePerKm = 7.0;
  double _driverLongDistanceThresholdKm = 50.0;
  double _driverLongDistanceBonusPerKm = 2.0;
  double _driverMinEarningsPerOrder = 25.0;

  // Admin Permissions Map
  Map<String, bool> _adminPermissions = {
    'Overview': true,
    'Vendors': true,
    'Admins': false,
    'Drivers': true,
    'Verification': false,
    'Dispatch Hub': true,
    'Live Tracking': false,
    'Customer Orders': true,
    'Customers': true,
    'Broadcasts': false,
    'Support Hub': false,
    'Intelligence': false,
    'Security Audit': false,
    'Report Center': false,
    'Settings': false,
    'Subscription Plans': false,
    'Vendor Payments': false,
    'Customer Payments': false,
    'Order Bills': false,
    'Financial IQ': false,
    'Failed Payments': false,
    'Employee Roster': false,
    'Attendance Hub': false,
    'Cancelled Orders': false,
  };

  // Partner Program Toggles
  bool _partnerInsuranceEnabled = true;
  bool _partnerFlexibilityEnabled = true;
  bool _partnerIncentivesEnabled = true;
  bool _partnerWelfareEnabled = true;

  // ₹a V3 Full Management Suite State ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
  bool _aiSurgeEnabled = false;
  double _surgeMultiplier = 1.0;

  // Account Settings Controllers
  late TextEditingController _accountNameCtrl;
  late TextEditingController _accountEmailCtrl;
  final TextEditingController _accountPassCtrl = TextEditingController();

  List<Map<String, dynamic>> _supportTickets = [];
  bool _isSupportTicketsLoading = false;
  List<Map<String, dynamic>> _adminAuditLogs = [
    {'action': 'SETTING_UPDATE', 'detail': 'Commission changed to 6.5%', 'user': 'SuperAdmin', 'time': '2m ago'},
    {'action': 'VENDOR_APPROVE', 'detail': 'Approved Fresh Mart', 'user': 'Admin_Karthik', 'time': '15m ago'},
    {'action': 'BROADCAST_SENT', 'detail': 'System maintenance alert', 'user': 'SuperAdmin', 'time': '45m ago'},
  ];
  String _broadcastTarget = 'All'; // 'All', 'Vendors', 'Drivers'

  // ₹a API State ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
  List<Map<String, dynamic>> _pendingVendors = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _dispatchOrders = [];
  final ValueNotifier<List<Map<String, dynamic>>> _liveDispatchOrdersNotifier = ValueNotifier([]);
  List<Map<String, dynamic>> _onlineDrivers = [];
  List<Map<String, dynamic>> _pendingDrivers = [];
  List<Map<String, dynamic>> _allDrivers = [];
  List<Map<String, dynamic>> _customerOrders = [];
  List<Map<String, dynamic>> _customerOrderHistory = [];
  List<Map<String, dynamic>> _processedBillOrders = [];
  List<Map<String, dynamic>> _serviceZones = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isCustomersLoading = false;
  String _customerSearch = '';
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
  bool _hasInitialCenteredLiveTracking = false;

  // Heatmap State
  List<LatLng> _heatmapOrderPoints = [];
  List<Map<String, dynamic>> _heatmapRiders = [];
  bool _isHeatmapLoading = false;
  final MapController _mapController = MapController();
  final MapController _liveTrackingMapController = MapController();
  String _currentMapStyleUrl = 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}';
  Timer? _refreshTimer;
  Map<String, dynamic>? _financialSummary;
  List<dynamic> _financialTrends = [];
  String _selectedDateFilter = 'all_time';
  DateTimeRange? _selectedDateRange;
  List<dynamic> _dateWiseBreakdown = [];
  bool _isFinancialLoading = false;
  String? _lastNotifiedOrderId;
  List<Map<String, dynamic>> _topVendors = [];
  List<Map<String, dynamic>> _fullVendorPerformance = [];
  Map<String, dynamic>? _topByOrdersVendor;
  Map<String, dynamic>? _topByIncomeVendor;
  Map<String, dynamic>? _lowestIncomeVendor;
  String _vendorSortOption = 'income_desc';
  List<Map<String, dynamic>> _driverPerformance = [];
  bool _isPerformanceLoading = false;
  List<Map<String, dynamic>> _payouts = [];
  List<Map<String, dynamic>> _driverPayouts = [];
  bool _isReportsLoading = false;

  static String get _baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://54.204.9.126:5000/api/v1';

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
    _fetchAllCustomers();
    _fetchHeatmapData();
    _fetchServiceZones();
    _fetchFailedPayments();
    _fetchSupportTickets();
    _fetchSubscriptionPlans();
    _fetchFinancialStats();
    _fetchPerformanceAnalytics();
    _fetchReportData();
    _fetchAdminReviews();
    _initSocket();
    
    // AUTOMATIC BACKGROUND REFRESH - Every 30 seconds (WebSockets handle real-time updates)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
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
        _fetchAllCustomers(silent: true);
        _fetchServiceZones(silent: true);
        _fetchSubscriptionPlans(silent: true);
        _fetchFinancialStats(silent: true);
        _fetchReportData(silent: true);
        _fetchAdminReviews(silent: true);
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

      _socket!.onConnect((_) {
        debugPrint(' Admin Socket Connected');
        _socket!.emit('join_room', 'admin');
      });

      _socket!.on('orders_wiped', (_) {
        debugPrint('&& GLOBAL ORDERS WIPED: Clearing admin lists');
        // Legacy local sync cleared (No longer used)
        if (mounted) {
          setState(() {
            _customerOrders.clear();
            _customerOrderHistory.clear();
            _dispatchOrders.clear();
          });
        }
      });

      _socket!.on('update_rider_location', (data) {
        debugPrint('& RIDER LOCATION UPDATE: $data');
        if (mounted && data != null && data is Map) {
          final rid = data['riderId']?.toString();
          if (rid != null && rid.isNotEmpty) {
            setState(() {
              final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
              final lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
              _liveRiders[rid] = {
                'lat': lat,
                'lng': lng,
                'lastUpdate': DateTime.now(),
                'name': data['riderName'] ?? 'Driver #$rid',
                'status': data['status'] ?? 'Active',
              };
              if (_tab == 6 && !_hasInitialCenteredLiveTracking && lat != 0.0 && lng != 0.0) {
                _hasInitialCenteredLiveTracking = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    _liveTrackingMapController.move(LatLng(lat, lng), 15.5);
                  } catch (e) {
                    debugPrint('Live tracking map move error: $e');
                  }
                });
              }
            });
          }
        }
      });

      _socket!.on('vendor_status_update', (data) {
        debugPrint('& LIVE VENDOR STATUS UPDATE: $data');
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
        debugPrint('& NEW CUSTOMER ORDER: $data');
        if (mounted) {
          _fetchCustomerOrders();
          _fetchDispatchOrders(silent: true);
          
          final orderId = data['orderId']?.toString();
          final notifyKey = 'NEW_$orderId';
          if (notifyKey == _lastNotifiedOrderId) return; 
          _lastNotifiedOrderId = notifyKey;

          final customerName = data['customerName']?.toString() ?? 'A Customer';
          final displayId = data['displayId'] != null ? ' #${data['displayId']}' : '';
          
          final isCustom = data['isCustomOrder'] == true || (data['orderType'] != null && data['orderType'] != 'Cart');
          
          safeShowSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.shopping_basket_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                isCustom 
                  ? 'New Any Shop Order$displayId from $customerName a Please Dispatch'
                  : 'New Customer Order$displayId from $customerName a Waiting for Vendor', 
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
        debugPrint('& NEW VENDOR PAYMENT REQUEST: $data');
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
        debugPrint('& CUSTOMER PAYMENT RECEIVED: $data');
        if (mounted) {
          _fetchCustomerOrders(); // Always refresh order lists to get updated payment status
          _fetchDispatchOrders(silent: true);
          
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
            action: SnackBarAction(label: 'VIEW', textColor: Colors.white, onPressed: () => setState(() => _tab = 17)), // Index 17 is Customer Payments
          ));
        }
      });

      _socket!.on('new_dispatch_request', (data) {
        debugPrint('&&& NEW DISPATCH REQUEST: $data');
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
              ? 'Order Accepted by $storeName a Please Assign Rider'
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

      _socket!.on('order_status_update', (data) {
        if (mounted) {
          _handleLiveSocketOrderUpdate(data);
          _fetchDispatchOrders(silent: true);
          _fetchCustomerOrders(silent: true);
        }
      });

      _socket!.on('dispatch_update', (data) {
        if (mounted) {
          _handleLiveSocketOrderUpdate(data);
          // Always use silent refresh to avoid loading indicator flash
          _fetchDispatchOrders(silent: true);
          _fetchCustomerOrders(silent: true);

          // Show notification for specific events
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
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ));
          } else if (msg.contains('Bill Uploaded')) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Bill photo uploaded by delivery partner', style: TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
              backgroundColor: const Color(0xFF6366F1),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ));
          }
        }
      });
      
      _socket!.on('order_update_alert', (data) {
        debugPrint('& LIVE ORDER STATUS UPDATE: $data');
        if (mounted) {
          _handleLiveSocketOrderUpdate(data);
          _fetchCustomerOrders(silent: true);
          _fetchDispatchOrders(silent: true);
        }
      });

      _socket!.on('driver_status_update', (data) {
        debugPrint('&& LIVE DRIVER STATUS UPDATE: $data');
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
        debugPrint('& NEW DRIVER REGISTERED: $data');
        if (mounted) {
          _fetchPendingDrivers();
          _fetchAllDrivers();
        }
      });

      _socket!.on('new_customer_registered', (data) {
        debugPrint('& NEW CUSTOMER REGISTERED: $data');
        if (mounted) {
          _fetchAllCustomers(silent: true);
        }
      });

      _socket!.on('permission_update', (data) {
        debugPrint('& LIVE PERMISSION UPDATE: $data');
        if (mounted && data['adminId'] == widget.user['_id']) {
          setState(() {
            final perms = Map<String, dynamic>.from(data['permissions']);
            perms.forEach((key, value) {
              if (_adminPermissions.containsKey(key)) {
                _adminPermissions[key] = value == true;
              }
            });

            // Redirect to Overview if current tab is revoked
            final labels = ['Overview', 'Vendors', 'Admins', 'Drivers', 'Verification', 'Dispatch Hub', 'Broadcasts', 'Support Hub', 'Intelligence', 'Security Audit', 'Report Center', 'Settings', '', '', 'Subscription Plans', 'Vendor Payments', 'Customer Payments', 'Order Bills', 'Financial IQ', 'Failed Payments', 'Employee Roster', 'Attendance Hub'];
            if (_tab < labels.length) {
              final currentLabel = labels[_tab];
              if (currentLabel.isNotEmpty && _adminPermissions[currentLabel] == false) {
                _tab = 0;
              }
            }
          });
        }
      });

      _socket!.on('settings_update', (data) {
        debugPrint('&~ LIVE SETTINGS UPDATE: $data');
        if (mounted) {
          final s = data['settings'];
          setState(() {
            _regEnabled = s['registrationEnabled'] ?? true;
            _autoAssign = s['autoAssign'] ?? true;
            _vendorCommissionEnabled = s['vendorCommissionEnabled'] ?? true;
            _commissionPct = (s['platformCommissionPct'] ?? 5.0).toDouble();
            _customerPlatformFeeEnabled = s['customerPlatformFeeEnabled'] ?? true;
            _customerPlatformFeeAmount = (s['customerPlatformFeeAmount'] ?? 5.0).toDouble();
            _deliveryRadius = (s['maxDispatchRadiusKm'] ?? 10).toInt();
            _partnerInsuranceEnabled = s['partnerInsuranceEnabled'] ?? true;
            _partnerFlexibilityEnabled = s['partnerFlexibilityEnabled'] ?? true;
            _partnerIncentivesEnabled = s['partnerIncentivesEnabled'] ?? true;
            _partnerWelfareEnabled = s['partnerWelfareEnabled'] ?? true;
            _includeRiderPickupDistance = s['includeRiderPickupDistance'] ?? true;
            _driverBaseRatePerKm = (s['driverBaseRatePerKm'] ?? 7.0).toDouble();
            _driverLongDistanceThresholdKm = (s['driverLongDistanceThresholdKm'] ?? 50.0).toDouble();
            _driverLongDistanceBonusPerKm = (s['driverLongDistanceBonusPerKm'] ?? 2.0).toDouble();
            _driverMinEarningsPerOrder = (s['driverMinEarningsPerOrder'] ?? 25.0).toDouble();

            // Map global permissions to local state
            if (s['adminPermissions'] != null) {
              final p = s['adminPermissions'];
              final Map<String, String> keyMap = {
                'overview': 'Overview', 'vendors': 'Vendors', 'admins': 'Admins',
                'drivers': 'Drivers', 'verification': 'Verification', 'dispatch': 'Dispatch Hub',
                'broadcasts': 'Broadcasts', 'support': 'Support Hub', 'intelligence': 'Intelligence',
                'security': 'Security Audit', 'reports': 'Report Center', 'settings': 'Settings',
                'customers': 'Customers'
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

  void _handleLiveSocketOrderUpdate(dynamic data) {
    if (data == null) return;
    final orderId = (data['orderId'] ?? data['_id'])?.toString();
    if (orderId == null || orderId.isEmpty) return;

    if (!mounted) return;

    setState(() {
      final newStatus = data['status'];

      // 1. Update in _dispatchOrders instantly
      if (newStatus == 'Cancelled' || newStatus == 'Delivered' || newStatus == 'Rejected') {
        _dispatchOrders.removeWhere((o) =>
            o['_id']?.toString() == orderId ||
            o['id']?.toString() == orderId ||
            (data['displayId'] != null && o['displayId']?.toString() == data['displayId']?.toString()));
      } else {
        final dIdx = _dispatchOrders.indexWhere((o) =>
            o['_id']?.toString() == orderId ||
            o['id']?.toString() == orderId ||
            (data['displayId'] != null && o['displayId']?.toString() == data['displayId']?.toString()));
        if (dIdx != -1) {
          final updated = Map<String, dynamic>.from(_dispatchOrders[dIdx]);
          if (newStatus != null) updated['status'] = newStatus;
          if (data['totalAmount'] != null) updated['totalAmount'] = data['totalAmount'];
          if (data['subTotal'] != null) updated['subTotal'] = data['subTotal'];
          if (data['discount'] != null) updated['discount'] = data['discount'];
          if (data['deliveryCharge'] != null) updated['deliveryCharge'] = data['deliveryCharge'];
          if (data['customerPlatformFee'] != null) updated['customerPlatformFee'] = data['customerPlatformFee'];
          if (data['vendorPaymentStatus'] != null) updated['vendorPaymentStatus'] = data['vendorPaymentStatus'];
          if (data['customerPaid'] != null) updated['customerPaid'] = data['customerPaid'];
          if (data['paymentStatus'] != null) updated['paymentStatus'] = data['paymentStatus'];
          _dispatchOrders[dIdx] = updated;
        }
      }

      // 2. Update in _customerOrders instantly
      final cIdx = _customerOrders.indexWhere((o) =>
          o['_id']?.toString() == orderId ||
          o['id']?.toString() == orderId ||
          (data['displayId'] != null && o['displayId']?.toString() == data['displayId']?.toString()));
      if (cIdx != -1) {
        final updated = Map<String, dynamic>.from(_customerOrders[cIdx]);
        if (newStatus != null) updated['status'] = newStatus;
        if (data['totalAmount'] != null) updated['totalAmount'] = data['totalAmount'];
        if (data['subTotal'] != null) updated['subTotal'] = data['subTotal'];
        if (data['discount'] != null) updated['discount'] = data['discount'];
        if (data['deliveryCharge'] != null) updated['deliveryCharge'] = data['deliveryCharge'];
        if (data['customerPlatformFee'] != null) updated['customerPlatformFee'] = data['customerPlatformFee'];
        if (data['vendorPaymentStatus'] != null) updated['vendorPaymentStatus'] = data['vendorPaymentStatus'];
        if (data['customerPaid'] != null) updated['customerPaid'] = data['customerPaid'];
        if (data['paymentStatus'] != null) updated['paymentStatus'] = data['paymentStatus'];
        _customerOrders[cIdx] = updated;
      }

      // 3. Update in _liveDispatchOrdersNotifier instantly
      final currentList = List<Map<String, dynamic>>.from(_liveDispatchOrdersNotifier.value);
      final idx = currentList.indexWhere((o) =>
          o['_id']?.toString() == orderId ||
          o['id']?.toString() == orderId ||
          (data['displayId'] != null && o['displayId']?.toString() == data['displayId']?.toString()));
      
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(currentList[idx]);
        if (newStatus != null) updated['status'] = newStatus;
        if (data['totalAmount'] != null) updated['totalAmount'] = data['totalAmount'];
        if (data['subTotal'] != null) updated['subTotal'] = data['subTotal'];
        if (data['discount'] != null) updated['discount'] = data['discount'];
        if (data['deliveryCharge'] != null) updated['deliveryCharge'] = data['deliveryCharge'];
        if (data['customerPlatformFee'] != null) updated['customerPlatformFee'] = data['customerPlatformFee'];
        if (data['vendorPaymentStatus'] != null) updated['vendorPaymentStatus'] = data['vendorPaymentStatus'];
        if (data['customerPaid'] != null) updated['customerPaid'] = data['customerPaid'];
        if (data['paymentStatus'] != null) updated['paymentStatus'] = data['paymentStatus'];
        currentList[idx] = updated;
      } else {
        Map<String, dynamic> newEntry = {
          '_id': orderId,
          'id': orderId,
          'status': newStatus ?? 'Pending',
          if (data['displayId'] != null) 'displayId': data['displayId'],
          if (data['totalAmount'] != null) 'totalAmount': data['totalAmount'],
          if (data['paymentStatus'] != null) 'paymentStatus': data['paymentStatus'],
          if (data['customerPaid'] != null) 'customerPaid': data['customerPaid'],
        };
        currentList.insert(0, newEntry);
      }
      _liveDispatchOrdersNotifier.value = List.from(currentList);
      debugPrint('⚡ [SOCKET INSTANT] Updated in-memory order $orderId to status: $newStatus');
    });
  }

  void _trackOrderLive(Map<String, dynamic> order) {
    final driver = order['driver'];
    
    if (driver == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No delivery partner assigned yet for this order.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveTrackingScreen(order: order),
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AdminColors.primaryIndigo),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text(value.toUpperCase(), style: GoogleFonts.outfit(color: AdminColors.textHeading, fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }



  Future<void> _fetchAllVendors({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isVendorsLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/vendors'), headers: _headers);
      if (response.statusCode == 401) {
        if (mounted && !silent) widget.onLogout();
        return;
      }
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
        safeShowSnackBar(SnackBar(
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
      if (response.statusCode == 401) {
        if (mounted && !silent) widget.onLogout();
        return;
      }
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
        safeShowSnackBar(SnackBar(
          content: Text('Failed to load pending vendors: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted && !silent) setState(() => _isPendingLoading = false);
    }
  }

  Future<void> _fetchSupportTickets({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isSupportTicketsLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/tickets/admin'), headers: _headers);
      if (response.statusCode == 401) {
        if (mounted && !silent) widget.onLogout();
        return;
      }
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _supportTickets = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching support tickets: $e');
      if (mounted && !silent) {
        safeShowSnackBar(SnackBar(
          content: Text('Failed to load support tickets: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted && !silent) setState(() => _isSupportTicketsLoading = false);
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
            _codEnabled = s['codEnabled'] ?? true;
            _autoAssign = s['autoAssign'] ?? true;
            _vendorAlertSound = s['vendorAlertSound'] ?? 'new_order_alert';
            _vendorCommissionEnabled = s['vendorCommissionEnabled'] ?? true;
            _commissionPct = (s['platformCommissionPct'] ?? 5.0).toDouble();
            _customerPlatformFeeEnabled = s['customerPlatformFeeEnabled'] ?? true;
            _customerPlatformFeeAmount = (s['customerPlatformFeeAmount'] ?? 5.0).toDouble();
            _deliveryRadius = (s['maxDispatchRadiusKm'] ?? 10).toInt();
            _partnerInsuranceEnabled = s['partnerInsuranceEnabled'] ?? true;
            _partnerFlexibilityEnabled = s['partnerFlexibilityEnabled'] ?? true;
            _partnerIncentivesEnabled = s['partnerIncentivesEnabled'] ?? true;
            _partnerWelfareEnabled = s['partnerWelfareEnabled'] ?? true;
            _serviceCenterLat = (s['serviceCenterLat'] ?? 11.3410).toDouble();
            _serviceCenterLng = (s['serviceCenterLng'] ?? 77.7172).toDouble();
            _serviceRadius = (s['maxServiceRadiusKm'] ?? 20).toInt();
            _driverBaseRatePerKm = (s['driverBaseRatePerKm'] ?? 7.0).toDouble();
            _driverLongDistanceThresholdKm = (s['driverLongDistanceThresholdKm'] ?? 50.0).toDouble();
            _driverLongDistanceBonusPerKm = (s['driverLongDistanceBonusPerKm'] ?? 2.0).toDouble();
            _driverMinEarningsPerOrder = (s['driverMinEarningsPerOrder'] ?? 25.0).toDouble();
            
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
                'Live Tracking': p['live_tracking'] ?? false,
                'Customer Orders': p['customer_orders'] ?? true,
                'Customers': p['customers'] ?? true,
                'Broadcasts': p['broadcasts'] ?? false,
                'Support Hub': p['support'] ?? false,
                'Intelligence': p['intelligence'] ?? false,
                'Security Audit': p['security'] ?? false,
                'Report Center': p['reports'] ?? false,
                'Settings': p['settings'] ?? false,
                'Subscription Plans': p['subscription_plans'] ?? false,
                'Vendor Payments': p['vendor_payments'] ?? false,
                'Customer Payments': p['customer_payments'] ?? false,
                'Order Bills': p['order_bills'] ?? false,
                'Financial IQ': p['financial_iq'] ?? false,
                'Failed Payments': p['failed_payments'] ?? false,
                'Employee Roster': p['employee_roster'] ?? false,
                'Attendance Hub': p['attendance_hub'] ?? false,
                'Cancelled Orders': p['cancelled_orders'] ?? false,
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
    _fetchFailedPayments();
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
    _fetchFailedPayments();
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
    _fetchFailedPayments();
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

  Future<void> _deleteVendor(String vendorId, String storeName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Vendor / கடையை நீக்கு', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
        content: Text(
          'Are you sure you want to permanently delete "$storeName"?\n\n"$storeName" கடையை நிரந்தரமாக நீக்க விரும்புகிறீர்களா? இந்நடவடிக்கையை மீட்டெடுக்க முடியாது.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel (ரத்து)', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete Permanently (நீக்கு)', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await http.delete(
          Uri.parse('$_baseUrl/admin/vendors/$vendorId'),
          headers: _headers,
        );
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('✅ Vendor "$storeName" deleted successfully!'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ));
          }
          setState(() {
            _selectedVendorIdx = 0;
          });
          _fetchPendingVendors();
          _fetchAllVendors();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed: ${data['error']}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      } catch (e) {
        debugPrint('Error deleting vendor: $e');
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

      if (mounted) {
        setState(() {
          _dispatchOrders = apiOrders;
        });
        _liveDispatchOrdersNotifier.value = apiOrders;
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

      if (mounted) {
        _sortOrdersByDateDesc(apiOrders);
        setState(() {
          _customerOrders = apiOrders;
          _updateProcessedBills();
        });
      }
    } catch (e) {
      debugPrint('Error fetching customer orders: $e');
    } finally {
      if (mounted && !silent) setState(() => _isCustomerOrdersLoading = false);
    }
  }

  void _sortOrdersByDateDesc(List<Map<String, dynamic>> orders) {
    orders.sort((a, b) {
      DateTime dateA;
      DateTime dateB;
      try {
        dateA = DateTime.parse(a['createdAt']?.toString() ?? a['timestamp']?.toString() ?? '');
      } catch (_) {
        dateA = DateTime.fromMillisecondsSinceEpoch(0);
      }
      try {
        dateB = DateTime.parse(b['createdAt']?.toString() ?? b['timestamp']?.toString() ?? '');
      } catch (_) {
        dateB = DateTime.fromMillisecondsSinceEpoch(0);
      }
      return dateB.compareTo(dateA); // Newest / Latest Date & Time FIRST
    });
  }

  Future<void> _fetchAllCustomers({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isCustomersLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/customers'), headers: _headers);
      if (response.statusCode == 401) {
        if (mounted && !silent) widget.onLogout();
        return;
      }
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _customers = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    } finally {
      if (mounted && !silent) setState(() => _isCustomersLoading = false);
    }
  }

  Future<void> _fetchCustomerOrderHistory({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isCustomerHistoryLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/orders/customer/history'), headers: _headers);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          final historyList = List<Map<String, dynamic>>.from(data['data']);
          _sortOrdersByDateDesc(historyList);
          setState(() {
            _customerOrderHistory = historyList;
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
    final active = List<Map<String, dynamic>>.from(_customerOrders);
    final history = List<Map<String, dynamic>>.from(_customerOrderHistory);
    final all = [...active, ...history];
    
    final bills = all.where((o) => 
      o != null && 
      o is Map &&
      o['billPhotoPath'] != null && 
      o['billPhotoPath'].toString().isNotEmpty
    ).toList();
    _sortOrdersByDateDesc(bills);

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
            
            // Rebuild and seed _liveRiders map
            _liveRiders.clear();
            for (var d in _onlineDrivers) {
              final rid = d['_id'];
              if (rid != null) {
                final locCoords = d['lastLocation']?['coordinates'];
                if (locCoords is List && locCoords.length >= 2) {
                  _liveRiders[rid] = {
                    'lat': (locCoords[1] as num).toDouble(),
                    'lng': (locCoords[0] as num).toDouble(),
                    'lastUpdate': DateTime.now(),
                    'name': d['name'] ?? 'Driver',
                    'status': 'Online',
                  };
                }
              }
            }
            if (_tab == 6 && !_hasInitialCenteredLiveTracking && _liveRiders.isNotEmpty) {
              _hasInitialCenteredLiveTracking = true;
              final firstRider = _liveRiders.values.first;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  _liveTrackingMapController.move(LatLng(firstRider['lat'], firstRider['lng']), 15.5);
                } catch (e) {
                  debugPrint('Live tracking map move error: $e');
                }
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching available drivers: $e');
    } finally {
      if (mounted && !silent) setState(() => _isDriversLoading = false);
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // math.pi / 180
    final a = 0.5 - math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) *
        (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  Future<void> _assignDriver(String orderId, String driverId) async {
    try {
      var driver = _allDrivers.firstWhere((d) => d['_id'] == driverId, orElse: () => {});
      if (driver.isEmpty) {
        driver = _onlineDrivers.firstWhere((d) => d['_id'] == driverId, orElse: () => {});
      }
      
      final order = _dispatchOrders.firstWhere((o) => o['id'] == orderId || o['_id'] == orderId, orElse: () => {});
      
      if (order['isLocal'] == true) {
        // Local Sync dispatch removed
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
    final String? selectedTarget = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text('Order Cancellation Options',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select which party to cancel this order for:',
                style: GoogleFonts.outfit(fontSize: 13, color: AdminColors.textSub)),
            const SizedBox(height: 16),
            _cancelOptionTile(
              ctx: ctx,
              title: 'Delivery Partner Only',
              subtitle: 'Unassigns delivery partner and re-opens driver assignment pool',
              icon: Icons.two_wheeler_rounded,
              color: Colors.orange,
              target: 'driver',
            ),
            const SizedBox(height: 10),
            _cancelOptionTile(
              ctx: ctx,
              title: 'Vendor Only',
              subtitle: 'Cancels order for vendor and sends cancellation alert to store',
              icon: Icons.storefront_rounded,
              color: Colors.purple,
              target: 'vendor',
            ),
            const SizedBox(height: 10),
            _cancelOptionTile(
              ctx: ctx,
              title: 'Customer Only',
              subtitle: 'Cancels order on customer side and updates customer order status',
              icon: Icons.person_rounded,
              color: Colors.blue,
              target: 'customer',
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            _cancelOptionTile(
              ctx: ctx,
              title: 'CANCEL FOR ALL 3 AT ONCE',
              subtitle: 'Instantly cancels order for Customer, Vendor & Delivery Partner',
              icon: Icons.cancel_presentation_rounded,
              color: Colors.red.shade700,
              target: 'all',
              isAll: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Close', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AdminColors.textSub)),
          ),
        ],
      ),
    );

    if (selectedTarget == null) return;

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/orders/$orderId/cancel'),
        headers: _headers,
        body: jsonEncode({'target': selectedTarget}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _handleLiveSocketOrderUpdate({'orderId': orderId, 'status': 'Cancelled'});
        _fetchCustomerOrders();
        _fetchDispatchOrders();
        final label = selectedTarget == 'driver'
            ? 'Cancelled for Delivery Partner!'
            : selectedTarget == 'vendor'
                ? 'Cancelled for Vendor!'
                : selectedTarget == 'customer'
                    ? 'Cancelled for Customer!'
                    : 'Order Cancelled for All 3 Parties!';

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(label),
          backgroundColor: Colors.red.shade700,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error cancelling order: $e');
    }
  }

  Widget _cancelOptionTile({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String target,
    bool isAll = false,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, target),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(isAll ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(isAll ? 0.5 : 0.25), width: isAll ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: isAll ? Colors.red.shade900 : AdminColors.textHeading)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 11, color: AdminColors.textSub)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  // ₹a DRIVER MANAGEMENT ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
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
          content: Text(' Driver Approved! They will be notified instantly.'),
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
          content: Text('&S Driver forced to Offline.'),
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
    bool? canRunAds,
    Map<String, bool>? permissions,
    bool? commissionEnabled,
    double? commissionRate,
  }) async {
    try {
      final body = {
        if (isLocked != null) 'isLocked': isLocked,
        if (lockReason != null) 'lockReason': lockReason,
        if (trialExpiry != null) 'trialExpiry': trialExpiry.toIso8601String(),
        if (subscriptionExpiry != null) 'subscriptionExpiry': subscriptionExpiry.toIso8601String(),
        if (isSubscribed != null) 'isSubscribed': isSubscribed,
        if (showSubscriptionBadge != null) 'showSubscriptionBadge': showSubscriptionBadge,
        if (canRunAds != null) 'canRunAds': canRunAds,
        if (permissions != null) 'permissions': permissions,
        if (commissionEnabled != null) 'commissionEnabled': commissionEnabled,
        if (commissionRate != null) 'commissionRate': commissionRate,
      };

      final response = await http.put(
        Uri.parse('$_baseUrl/admin/vendors/$vendorId/access'),
        headers: _headers,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // Refresh vendors list, then switch to correct sub-tab
        await _fetchAllVendors();
        if (mounted && isLocked != null) {
          setState(() {
            if (isLocked == false) {
              // Vendor was UNLOCKED  switch to Directory tab
              _vendorSubTab = 0;
              _selectedVendorIdx = _vendors.indexWhere((v) => v['_id'] == vendorId);
              if (_selectedVendorIdx == -1) {
                _selectedVendorIdx = _vendors.indexWhere((v) => v['isLocked'] != true);
              }
            } else {
              // Vendor was LOCKED  switch to Blocked tab
              _vendorSubTab = 1;
              _selectedVendorIdx = _vendors.indexWhere((v) => v['_id'] == vendorId);
              if (_selectedVendorIdx == -1) {
                _selectedVendorIdx = _vendors.indexWhere((v) => v['isLocked'] == true);
              }
            }
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(' Vendor access updated successfully!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        throw Exception(data['error'] ?? 'Update failed');
      }
    } catch (e) {
      debugPrint('Error updating vendor access: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('&" Error: ${e.toString()}'),
        backgroundColor: AdminColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _updateVendorDetails({
    required String vendorId,
    required String storeName,
    required String ownerName,
    required String phone,
    required String category,
    required String address,
    required String businessEmail,
    required String gstNumber,
    required String panNumber,
    required double deliveryRadiusKm,
    required double latitude,
    required double longitude,
    required String city,
    required String pincode,
  }) async {
    try {
      final body = {
        'storeName': storeName,
        'ownerName': ownerName,
        'phone': phone,
        'category': category,
        'address': address,
        'businessEmail': businessEmail,
        'gstNumber': gstNumber,
        'panNumber': panNumber,
        'deliveryRadiusKm': deliveryRadiusKm,
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'pincode': pincode,
      };

      final response = await http.put(
        Uri.parse('$_baseUrl/admin/vendors/$vendorId/details'),
        headers: _headers,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // Refresh vendors list
        await _fetchAllVendors();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('🎉 Vendor details updated successfully!'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        throw Exception(data['error'] ?? 'Update failed');
      }
    } catch (e) {
      debugPrint('Error updating vendor details: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⚠️ Error: ${e.toString()}'),
        backgroundColor: AdminColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showEditVendorDialog(Map<String, dynamic> v) {
    final storeNameCtrl = TextEditingController(text: v['storeName'] ?? '');
    final ownerNameCtrl = TextEditingController(text: v['ownerName'] ?? '');
    final phoneCtrl = TextEditingController(text: v['phone'] ?? '');
    final emailCtrl = TextEditingController(text: v['businessEmail'] ?? v['user']?['email'] ?? '');
    final gstCtrl = TextEditingController(text: v['gstNumber'] ?? '');
    final panCtrl = TextEditingController(text: v['panNumber'] ?? '');
    final addressCtrl = TextEditingController(text: v['address'] ?? '');

    // Parse city from address if null/empty
    String parsedCity = v['location']?['city'] ?? v['city'] ?? '';
    if (parsedCity.isEmpty) {
      final String addrLower = (v['address'] ?? '').toString().toLowerCase();
      if (addrLower.contains('chennai')) parsedCity = 'Chennai';
      else if (addrLower.contains('erode')) parsedCity = 'Erode';
      else if (addrLower.contains('coimbatore')) parsedCity = 'Coimbatore';
      else if (addrLower.contains('salem')) parsedCity = 'Salem';
    }
    final cityCtrl = TextEditingController(text: parsedCity);

    // Parse pincode from address if null/empty
    String parsedPincode = v['location']?['pincode'] ?? v['pincode'] ?? '';
    if (parsedPincode.isEmpty) {
      final regExp = RegExp(r'\b\d{6}\b');
      final match = regExp.firstMatch(v['address'] ?? '');
      if (match != null) {
        parsedPincode = match.group(0) ?? '';
      }
    }
    final pincodeCtrl = TextEditingController(text: parsedPincode);

    double localRadius = (v['deliveryRadiusKm'] ?? 15.0).toDouble();
    final radiusCtrl = TextEditingController(text: localRadius.toString());

    final loc = v['location'] ?? {};
    final coords = loc['coordinates'] as List?;
    double currentLng = coords != null && coords.isNotEmpty ? (double.tryParse(coords[0].toString()) ?? 77.7172) : 77.7172;
    double currentLat = coords != null && coords.length > 1 ? (double.tryParse(coords[1].toString()) ?? 11.3410) : 11.3410;

    final latCtrl = TextEditingController(text: currentLat.toString());
    final lngCtrl = TextEditingController(text: currentLng.toString());
    final mapSearchCtrl = TextEditingController();
    final mapController = MapController();

    String selectedCategory = v['category'] ?? 'Food';
    final categories = ['Grocery', 'Bakery', 'Medicine', 'Food', 'Fruits & Vegetables'];

    Timer? debounceTimer;

    Future<void> reverseGeocode(double lat, double lon, StateSetter setModalState) async {
      if (debounceTimer != null && debounceTimer!.isActive) {
        debounceTimer!.cancel();
      }
      debounceTimer = Timer(const Duration(milliseconds: 600), () async {
        try {
          final url = 'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1';
          final response = await http.get(Uri.parse(url), headers: {
            'User-Agent': 'NambaAdminApp/1.0',
          });
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data is Map && data.isNotEmpty) {
              final String dispName = data['display_name'] ?? '';
              final addressObj = data['address'] ?? {};
              final String foundCity = addressObj['city'] ?? addressObj['town'] ?? addressObj['village'] ?? addressObj['suburb'] ?? addressObj['city_district'] ?? '';
              final String foundPincode = addressObj['postcode'] ?? '';
              
              setModalState(() {
                if (dispName.isNotEmpty) {
                  addressCtrl.text = dispName;
                }
                if (foundCity.isNotEmpty) {
                  cityCtrl.text = foundCity;
                }
                if (foundPincode.isNotEmpty) {
                  pincodeCtrl.text = foundPincode;
                }
              });
            }
          } else {
            debugPrint('Reverse geocoding failed: status ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Reverse geocoding error: $e');
        }
      });
    }

    Future<void> searchAddress(String query, StateSetter setModalState) async {
      if (query.trim().isEmpty) return;
      try {
        final encodedQuery = Uri.encodeComponent(query);
        final url = 'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1&addressdetails=1';
        final response = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'NambaAdminApp/1.0',
        });
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List && data.isNotEmpty) {
            final double lat = double.parse(data[0]['lat'].toString());
            final double lon = double.parse(data[0]['lon'].toString());
            
            final addressObj = data[0]['address'] ?? {};
            final String foundCity = addressObj['city'] ?? addressObj['town'] ?? addressObj['village'] ?? addressObj['suburb'] ?? addressObj['city_district'] ?? '';
            final String foundPincode = addressObj['postcode'] ?? '';

            setModalState(() {
              currentLat = lat;
              currentLng = lon;
              latCtrl.text = lat.toString();
              lngCtrl.text = lon.toString();
              if (foundCity.isNotEmpty) {
                cityCtrl.text = foundCity;
              }
              if (foundPincode.isNotEmpty) {
                pincodeCtrl.text = foundPincode;
              }
            });
            mapController.move(LatLng(lat, lon), 16.0);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No matching address location found.'), backgroundColor: Colors.orange),
            );
          }
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Address search error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    bool isSatellite = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Row(
            children: [
              const Icon(Icons.edit_location_alt_rounded, color: AdminColors.primaryIndigo),
              const SizedBox(width: 12),
              Text('Edit Vendor & Shop Location', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: (MediaQuery.of(context).size.width * 0.85).clamp(950.0, 1250.0),
            height: (MediaQuery.of(context).size.height * 0.82).clamp(600.0, 800.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── LEFT COLUMN: VENDOR FORM & DETAILS (Width 450px) ──────────────────
                SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(right: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Update store details, contact info, and map coordinates.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        const SizedBox(height: 20),
                        
                        Text('STORE IDENTITY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: AdminColors.primaryIndigo, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _inputField(storeNameCtrl, 'Store Name', Icons.store_rounded)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: categories.contains(selectedCategory) ? selectedCategory : 'Food',
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => selectedCategory = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _inputField(ownerNameCtrl, 'Owner Name', Icons.person_rounded)),
                            const SizedBox(width: 12),
                            Expanded(child: _inputField(phoneCtrl, 'Phone Number', Icons.phone_rounded)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _inputField(emailCtrl, 'Business Email', Icons.email_rounded),
                        
                        const SizedBox(height: 24),
                        Text('SHOP LOCATION & LOGISTICS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: AdminColors.primaryIndigo, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        _inputField(addressCtrl, 'Shop Address', Icons.location_on_rounded),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _inputField(cityCtrl, 'City', Icons.location_city_rounded)),
                            const SizedBox(width: 12),
                            Expanded(child: _inputField(pincodeCtrl, 'Pincode', Icons.pin_drop_rounded)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _inputField(
                          radiusCtrl,
                          'Delivery Radius (KM)',
                          Icons.radar_rounded,
                          type: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                            final double? rad = double.tryParse(val);
                            setModalState(() {
                              localRadius = rad ?? 0.0;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _inputField(
                                latCtrl,
                                'Latitude',
                                Icons.map_rounded,
                                type: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (val) {
                                  final double? lat = double.tryParse(val);
                                  final double? lng = double.tryParse(lngCtrl.text);
                                  if (lat != null && lng != null) {
                                    setModalState(() {
                                      currentLat = lat;
                                      currentLng = lng;
                                    });
                                    mapController.move(LatLng(lat, lng), mapController.camera.zoom);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _inputField(
                                lngCtrl,
                                'Longitude',
                                Icons.map_rounded,
                                type: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (val) {
                                  final double? lat = double.tryParse(latCtrl.text);
                                  final double? lng = double.tryParse(val);
                                  if (lat != null && lng != null) {
                                    setModalState(() {
                                      currentLat = lat;
                                      currentLng = lng;
                                    });
                                    mapController.move(LatLng(lat, lng), mapController.camera.zoom);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: AdminColors.primaryIndigo),
                              tooltip: 'Sync Map',
                              onPressed: () {
                                final double? lat = double.tryParse(latCtrl.text);
                                final double? lng = double.tryParse(lngCtrl.text);
                                if (lat != null && lng != null) {
                                  setModalState(() {
                                    currentLat = lat;
                                    currentLng = lng;
                                  });
                                  mapController.move(LatLng(lat, lng), 16.0);
                                }
                              },
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        Text('LEGAL & TAX INFO', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: AdminColors.primaryIndigo, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _inputField(gstCtrl, 'GST Number', Icons.receipt_rounded)),
                            const SizedBox(width: 12),
                            Expanded(child: _inputField(panCtrl, 'PAN Number', Icons.credit_card_rounded)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const VerticalDivider(width: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(width: 20),

                // ── RIGHT COLUMN: FULL LARGE INTERACTIVE MAP (Google Traffic & Satellite) ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ACCURATE MAP POSITIONING', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: AdminColors.primaryIndigo, letterSpacing: 1)),
                          TextButton.icon(
                            icon: const Icon(Icons.home_work_rounded, size: 16, color: AdminColors.primaryIndigo),
                            label: Text('Use Shop Address', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AdminColors.primaryIndigo)),
                            onPressed: () {
                              final query = '${addressCtrl.text} ${cityCtrl.text}'.trim();
                              if (query.isNotEmpty) {
                                mapSearchCtrl.text = query;
                                searchAddress(query, setModalState);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: mapSearchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Search place or address (e.g. T Nagar, Chennai)...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onSubmitted: (val) => searchAddress(val, setModalState),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => searchAddress(mapSearchCtrl.text, setModalState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminColors.primaryIndigo,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Search', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Large Interactive Map Canvas
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: mapController,
                                options: MapOptions(
                                  initialCenter: LatLng(currentLat, currentLng),
                                  initialZoom: 16.0,
                                  maxZoom: 20.0,
                                  onPositionChanged: (camera, hasGesture) {
                                    if (hasGesture) {
                                      setModalState(() {
                                        currentLat = camera.center.latitude;
                                        currentLng = camera.center.longitude;
                                        latCtrl.text = currentLat.toString();
                                        lngCtrl.text = currentLng.toString();
                                      });
                                      reverseGeocode(currentLat, currentLng, setModalState);
                                    }
                                  },
                                  onTap: (tapPosition, point) {
                                    setModalState(() {
                                      currentLat = point.latitude;
                                      currentLng = point.longitude;
                                      latCtrl.text = currentLat.toString();
                                      lngCtrl.text = currentLng.toString();
                                    });
                                    mapController.move(point, mapController.camera.zoom);
                                    reverseGeocode(point.latitude, point.longitude, setModalState);
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: isSatellite
                                        ? 'https://mt{s}.google.com/vt/lyrs=y,traffic&x={x}&y={y}&z={z}'
                                        : 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}',
                                    subdomains: const ['0', '1', '2', '3'],
                                    userAgentPackageName: 'com.namba.admin',
                                    maxZoom: 20,
                                    maxNativeZoom: 19,
                                  ),
                                  CircleLayer(
                                    circles: [
                                      CircleMarker(
                                        point: LatLng(currentLat, currentLng),
                                        radius: localRadius * 1000.0,
                                        useRadiusInMeter: true,
                                        color: Colors.blue.withOpacity(0.15),
                                        borderColor: Colors.blue.shade600,
                                        borderStrokeWidth: 2.5,
                                      ),
                                    ],
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(currentLat, currentLng),
                                        width: 90,
                                        height: 90,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.85),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'STORE PIN',
                                                style: GoogleFonts.outfit(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                            const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 44),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Map Controls Overlay (Satellite + Zoom In/Out)
                              Positioned(
                                top: 14,
                                right: 14,
                                child: Column(
                                  children: [
                                    FloatingActionButton.small(
                                      heroTag: 'edit_satellite_toggle',
                                      backgroundColor: Colors.white,
                                      elevation: 4,
                                      onPressed: () {
                                        setModalState(() => isSatellite = !isSatellite);
                                      },
                                      child: Icon(
                                        isSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
                                        color: AdminColors.primaryIndigo,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    FloatingActionButton.small(
                                      heroTag: 'edit_zoom_in',
                                      backgroundColor: Colors.white,
                                      elevation: 4,
                                      onPressed: () {
                                        mapController.move(LatLng(currentLat, currentLng), (mapController.camera.zoom + 1.0).clamp(1.0, 22.0));
                                      },
                                      child: const Icon(Icons.add_rounded, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 6),
                                    FloatingActionButton.small(
                                      heroTag: 'edit_zoom_out',
                                      backgroundColor: Colors.white,
                                      elevation: 4,
                                      onPressed: () {
                                        mapController.move(LatLng(currentLat, currentLng), (mapController.camera.zoom - 1.0).clamp(1.0, 22.0));
                                      },
                                      child: const Icon(Icons.remove_rounded, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),

                              // Live Coordinate Badge Overlay
                              Positioned(
                                bottom: 14,
                                left: 14,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.my_location_rounded, color: Colors.amberAccent, size: 14),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Lat: ${currentLat.toStringAsFixed(6)} • Lng: ${currentLng.toStringAsFixed(6)}',
                                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final double? lat = double.tryParse(latCtrl.text);
                final double? lng = double.tryParse(lngCtrl.text);

                if (lat == null || lng == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid latitude and longitude coordinates'), backgroundColor: Colors.red),
                  );
                  return;
                }

                Navigator.pop(context);
                
                _updateVendorDetails(
                  vendorId: v['_id'],
                  storeName: storeNameCtrl.text,
                  ownerName: ownerNameCtrl.text,
                  phone: phoneCtrl.text,
                  category: selectedCategory,
                  address: addressCtrl.text,
                  businessEmail: emailCtrl.text,
                  gstNumber: gstCtrl.text,
                  panNumber: panCtrl.text,
                  deliveryRadiusKm: localRadius,
                  latitude: lat,
                  longitude: lng,
                  city: cityCtrl.text,
                  pincode: pincodeCtrl.text,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Save Details', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showVendorAccessDialog(Map<String, dynamic> vendor) {
    bool isLocked = vendor['isLocked'] ?? false;
    final reasonCtrl = TextEditingController(text: vendor['lockReason'] ?? '');
    DateTime? trialExp = vendor['trialExpiry'] != null ? DateTime.parse(vendor['trialExpiry']) : null;
    DateTime? subExp = vendor['subscriptionExpiry'] != null ? DateTime.parse(vendor['subscriptionExpiry']) : null;
    bool showBadge = vendor['showSubscriptionBadge'] ?? true;

    // Commission Settings
    bool commissionEnabled = vendor['commissionEnabled'] ?? true;
    final double initialRatePct = (vendor['commissionRate'] ?? 0.05) * 100.0;
    final commRateCtrl = TextEditingController(text: initialRatePct.toStringAsFixed(1));

    // Feature Permissions
    Map<String, dynamic> perms = vendor['permissions'] ?? {};
    bool allowAutoAccept = perms['allowAutoAccept'] ?? false;
    bool allowSurgeBoost = perms['allowSurgeBoost'] ?? false;
    bool allowExtraWait = perms['allowExtraWait'] ?? false;
    bool canRunAds = vendor['canRunAds'] ?? false;

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
                const SizedBox(height: 12),

                // In-App Ad Campaign Permission
                _permissionToggle(
                  title: 'In-App Ad Campaigns (Customer Ads)',
                  subtitle: 'Allow vendor to create and publish banner ads in Customer App',
                  icon: Icons.campaign_rounded,
                  value: canRunAds,
                  onChanged: (v) => setModalState(() => canRunAds = v),
                ),
                const SizedBox(height: 32),

                // Commission Settings
                Text('COMMISSION SETTINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: AdminColors.primaryIndigo, letterSpacing: 1)),
                const SizedBox(height: 16),
                _permissionToggle(
                  title: 'Commission Enabled',
                  subtitle: 'Enable or disable commission on vendor sales',
                  icon: Icons.percent_rounded,
                  value: commissionEnabled,
                  onChanged: (v) => setModalState(() => commissionEnabled = v),
                ),
                if (commissionEnabled) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: commRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Commission Rate (%)',
                      hintText: 'e.g., 5.0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.money_rounded),
                    ),
                  ),
                ],

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
                double? commissionRateVal;
                if (commissionEnabled) {
                  final enteredRate = double.tryParse(commRateCtrl.text);
                  if (enteredRate != null) {
                    commissionRateVal = enteredRate / 100.0;
                  }
                }
                _updateVendorAccess(
                  vendorId: vendor['_id'],
                  isLocked: isLocked,
                  lockReason: reasonCtrl.text,
                  trialExpiry: trialExp,
                  subscriptionExpiry: subExp,
                  showSubscriptionBadge: showBadge,
                  canRunAds: canRunAds,
                  permissions: {
                    'allowAutoAccept': allowAutoAccept,
                    'allowSurgeBoost': allowSurgeBoost,
                    'allowExtraWait': allowExtraWait,
                  },
                  commissionEnabled: commissionEnabled,
                  commissionRate: commissionRateVal,
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
              _payouts = List<Map<String, dynamic>>.from(body['data']['vendorPayouts'] ?? body['data']['payouts'] ?? []);
              _driverPayouts = List<Map<String, dynamic>>.from(body['data']['driverPayouts'] ?? []);
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

  Future<void> _payDriverSalary(String driverId) async {
    try {
      final res = await http.put(Uri.parse('$_baseUrl/admin/drivers/$driverId/pay'), headers: _headers);
      final body = json.decode(res.body);
      if (body['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salary paid successfully', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
          _fetchReportData();
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${body['error']}', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
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
      case 8: return _buildCustomersTab();
      case 9: return _buildBroadcastCenter();
      case 10: return _buildSupportHub();
      case 11: return _buildMarketIntelligence();
      case 12: return _buildSecurityAudit();
      case 13: return _buildReports();
      case 14: return _buildSettings();
      case 15: return _buildPlansTab();
      case 16: return _buildVendorPaymentsTab();
      case 17: return _buildCustomerPaymentsTab();
      case 18: return OrderBillsHubView(
                processedBills: _processedBillOrders,
                isLoading: _isCustomerOrdersLoading || _isCustomerHistoryLoading,
                onRefresh: () { _fetchCustomerOrders(); _fetchCustomerOrderHistory(); },
                onViewOrder: (order) => _showOrderDetails(order),
                onPreviewImage: (url, title) => _showImagePreviewDialog(url, title),
                baseUrl: _baseUrl,
              );
      case 19: return _buildFinancialIntelligence();
      case 20: return _buildFailedPayments();
      case 21: return EmployeeRosterScreen(headers: _headers);
      case 22: return AttendanceHubScreen(headers: _headers);
      case 23: return _buildCancelledOrdersTab();
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
      {'icon': Icons.people_rounded, 'label': 'Customers'},
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
      {'icon': Icons.money_off_rounded, 'label': 'Failed Payments'},
      {'icon': Icons.badge_rounded, 'label': 'Employee Roster'},
      {'icon': Icons.event_available_rounded, 'label': 'Attendance Hub'},
      {'icon': Icons.cancel_presentation_rounded, 'label': 'Cancelled Orders'},
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
                
                // ROLE BASED FILTERING - hide if not superadmin and permission is not explicitly true
                if (widget.user['role'] != 'superadmin') {
                  final allowed = _adminPermissions[label];
                  if (allowed != true) return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: InkWell(
                  onTap: () {
                    setState(() {
                      _tab = i;
                      if (label == 'Vendors' || i == 1) {
                        _vendorSubTab = 0;
                        final firstDirIdx = _vendors.indexWhere((v) => v['isLocked'] != true);
                        _selectedVendorIdx = firstDirIdx != -1 ? firstDirIdx : 0;
                      }
                      if (i == 6) {
                        _hasInitialCenteredLiveTracking = true;
                        _centerLiveTrackingMapOnFirstRider();
                      }
                    });
                    // EXPLICIT TRIGGER - Only if not already loading
                    if ((label == 'Order Bills' || label == 'Cancelled Orders' || label == 'Customer Orders') && !_isCustomerOrdersLoading) {
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

  // ₹a DRIVERS MANAGEMENT TAB ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
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
                  // ₹a PENDING APPLICATIONS ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
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

                  // ₹a ALL DRIVERS ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
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
    final vehicleIcons = {'bike': '&', 'scooter': '&', 'bicycle': '&&', 'car': '&&', 'auto': '&'};
    final vehicleEmoji = vehicleIcons[driver['vehicleType'] ?? 'bike'] ?? '&';
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
                Text('&& ${driver['phone'] ?? 'N/A'}', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Text('$vehicleEmoji ${(driver['vehicleType'] as String? ?? 'bike').toUpperCase()} a ${driver['vehicleNumber'] ?? 'N/A'} a License: ${driver['licenseNumber'] ?? 'N/A'}',
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
            Expanded(flex: 2, child: Text('ONLINE / DUTY TIME', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
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
            final dutyTime = d['onlineDutyTime'] ?? (isOnline ? 'Active' : '0m');
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
                  Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? Colors.green : Colors.grey.shade300)),
                      const SizedBox(width: 6),
                      Text(isOnline ? 'Online' : 'Offline', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: isOnline ? Colors.green : Colors.grey.shade400)),
                      if (isOnline) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _forceOfflineDriver(d['_id']),
                          child: Icon(Icons.power_settings_new_rounded, size: 14, color: Colors.redAccent.withOpacity(0.7)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(' $dutyTime', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.indigo.shade700)),
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


  // ₹a DISPATCH (TACTICAL COMMAND HUB) ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
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

    final now = DateTime.now();
    final dispatchHistory = dispatchHistoryMap.values.where((o) {
      final createdAtStr = o['createdAt']?.toString();
      if (createdAtStr == null) return true;
      try {
        final date = DateTime.parse(createdAtStr).toLocal();
        return date.year == now.year && date.month == now.month && date.day == now.day;
      } catch (e) {
        return false;
      }
    }).toList();

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

  void _centerLiveTrackingMapOnFirstRider() {
    if (_liveRiders.isNotEmpty) {
      final firstRider = _liveRiders.values.first;
      final lat = (firstRider['lat'] as num?)?.toDouble();
      final lng = (firstRider['lng'] as num?)?.toDouble();
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _liveTrackingMapController.move(LatLng(lat, lng), 15.5);
          } catch (e) {
            debugPrint('Live tracking map move error: $e');
          }
        });
      }
    }
  }

  Widget _buildLiveTrackingTab() {
    LatLng initialCenter = const LatLng(11.3410, 77.7172); // Default: Erode / Central Hub
    if (_liveRiders.isNotEmpty) {
      final firstRider = _liveRiders.values.first;
      final lat = (firstRider['lat'] as num?)?.toDouble();
      final lng = (firstRider['lng'] as num?)?.toDouble();
      if (lat != null && lng != null && lat != 0 && lng != 0) {
        initialCenter = LatLng(lat, lng);
      }
    }

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('LIVE TRACKING', 'Global Delivery Pulse'),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _liveTrackingMapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 15.0,
                    minZoom: 3.0,
                    maxZoom: 20.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _currentMapStyleUrl,
                      subdomains: _currentMapStyleUrl.contains('google.com') ? const ['0', '1', '2', '3'] : const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.namba.admin',
                      maxZoom: 20,
                      maxNativeZoom: 19,
                      tileProvider: NetworkTileProvider(),
                      errorTileCallback: (tile, error, stackTrace) {
                        debugPrint('Map Tile error: $error');
                      },
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
                  child: PopupMenuButton<String>(
                    tooltip: 'Change Map Style',
                    onSelected: (style) {
                      setState(() {
                        _currentMapStyleUrl = style;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', child: Text('OpenStreetMap (Standard)')),
                      const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}', child: Text('Google Maps (Traffic)')),
                      const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', child: Text('Google Satellite Hybrid')),
                      const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}', child: Text('Google Maps (Standard)')),
                      const PopupMenuItem(value: 'https://mt{s}.google.com/vt/lyrs=p,traffic&x={x}&y={y}&z={z}', child: Text('Google Terrain')),
                      const PopupMenuItem(value: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', child: Text('Voyager Style')),
                      const PopupMenuItem(value: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', child: Text('Dark Style')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.layers_outlined, color: AdminColors.primaryIndigo, size: 24),
                    ),
                  ),
                ),
                
                // Map Controls (Zoom / Recenter)
                Positioned(
                  bottom: 32, right: 32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.my_location_rounded, color: AdminColors.primaryIndigo),
                              tooltip: 'Recenter Map',
                              onPressed: () {
                                final targetLat = _liveRiders.isNotEmpty ? (_liveRiders.values.first['lat'] as num?)?.toDouble() ?? 13.0827 : 13.0827;
                                final targetLng = _liveRiders.isNotEmpty ? (_liveRiders.values.first['lng'] as num?)?.toDouble() ?? 80.2707 : 80.2707;
                                try {
                                  _liveTrackingMapController.move(LatLng(targetLat, targetLng), 13);
                                } catch (e) {
                                  debugPrint('Map recenter error: $e');
                                }
                              },
                            ),
                            Container(height: 1, width: 32, color: Colors.grey.shade200),
                            IconButton(
                              icon: const Icon(Icons.add, color: AdminColors.textHeading),
                              tooltip: 'Zoom In',
                              onPressed: () {
                                try {
                                  _liveTrackingMapController.move(_liveTrackingMapController.camera.center, _liveTrackingMapController.camera.zoom + 1);
                                } catch (e) {
                                  debugPrint('Map zoom error: $e');
                                }
                              },
                            ),
                            Container(height: 1, width: 32, color: Colors.grey.shade200),
                            IconButton(
                              icon: const Icon(Icons.remove, color: AdminColors.textHeading),
                              tooltip: 'Zoom Out',
                              onPressed: () {
                                try {
                                  _liveTrackingMapController.move(_liveTrackingMapController.camera.center, _liveTrackingMapController.camera.zoom - 1);
                                } catch (e) {
                                  debugPrint('Map zoom error: $e');
                                }
                              },
                            ),
                          ],
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
            Text('Dispatch Queue  ', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey.shade400)),
            Text(' & & 9 .', style: TextStyle(color: Colors.grey.shade300, fontSize: 14)),
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
          // Auto Assign Toggle Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _autoAssign ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _autoAssign ? Colors.green.shade200 : Colors.orange.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _autoAssign ? Icons.auto_mode_rounded : Icons.pause_circle_rounded,
                          size: 14,
                          color: _autoAssign ? Colors.green.shade700 : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _autoAssign ? 'AUTO ASSIGN ON' : 'AUTO ASSIGN OFF',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: _autoAssign ? Colors.green.shade700 : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _autoAssign ? 'Auto assigns nearest drivers' : 'Manual dispatch mode',
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _autoAssign,
                  activeColor: Colors.green,
                  activeTrackColor: Colors.green.shade100,
                  inactiveThumbColor: Colors.orange,
                  inactiveTrackColor: Colors.orange.shade100,
                  onChanged: (val) {
                    setState(() => _autoAssign = val);
                    _updateSettings({'autoAssign': val});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          _statusCounter(
            'AWAITING', 
            _dispatchOrders.where((o) {
              final st = o['status']?.toString().toLowerCase() ?? '';
              return st != 'delivered' && st != 'cancelled' && st != 'rejected';
            }).length.toString(), 
            Colors.orange
          ),
          const SizedBox(width: 24),
          _statusCounter('ACTIVE DRIVERS', _onlineDrivers.length.toString(), Colors.green),
          const SizedBox(width: 24),
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
    final isCancelled = status == 'Cancelled';
    final cancelledBy = (order['cancelledBy'] ?? 'Unknown').toString();
    final cancellationReason = (order['cancellationReason'] ?? '').toString();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isCancelled ? const Color(0xFFFFF5F5) : Colors.white, 
        borderRadius: BorderRadius.circular(32), 
        border: Border.all(
          color: isCancelled ? const Color(0xFFFCA5A5) : Colors.grey.shade100,
          width: isCancelled ? 2 : 1,
        ), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 12, color: isCancelled ? const Color(0xFFEF4444) : (isAssigned ? const Color(0xFF10B981) : AdminColors.primaryIndigo)),
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
                          if (isCancelled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF87171))),
                              child: Text('ORDER CANCELLED', style: GoogleFonts.outfit(color: const Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                            )
                          else
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
                          Text(status.toUpperCase(), style: GoogleFonts.outfit(color: isCancelled ? const Color(0xFFDC2626) : AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 10)),
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
                      if (isCancelled) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CANCELLED BY: ${cancelledBy.toUpperCase()}',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: const Color(0xFFDC2626), letterSpacing: 0.5),
                                    ),
                                    if (cancellationReason.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Reason: $cancellationReason',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.red.shade900),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
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
                              Text(order['createdAt'] != null ? DateFormat('hh:mm a').format(DateTime.parse(order['createdAt']).toLocal().toLocal()) : 'Ongoing', 
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
                          Text('~  click for details ~', style: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 10)),
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
              padding: const EdgeInsets.all(24),
              color: isCancelled ? const Color(0xFFFEF2F2) : AdminColors.background,
              child: isCancelled 
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
                        child: const Icon(Icons.cancel_outlined, size: 28, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'CANCELLED',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFDC2626), letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By ${cancelledBy.toUpperCase()}',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.red.shade800),
                        textAlign: TextAlign.center,
                      ),
                      if (cancellationReason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          cancellationReason,
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  )
                : (isAssigned 
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('PARTNER CALL', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          Text(driver['phone'] ?? 'N/A', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.sidebarBg)),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () => _trackOrderLive(order),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text('LIVE TRACKING', style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 10)),
                            ),
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
                      )),
            ),
          ],
        ),
      ),
    );
  }

  String _formatItemsSummary(Map<String, dynamic> order) {
    final type = order['orderType'] ?? 'Cart';
    if (type == 'Text') return '& manual list: ${order['textContent'] ?? 'No text provided'}';
    if (type == 'Photo') return '&S Photo Order (check details)';
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
        return '$name x $qty';
      }
      return item.toString();
    }).join(', ') + (list.length > 3 ? ' +${list.length - 3} more' : '');
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = DateTime.parse(timestamp.toString()).toLocal();
      return DateFormat('MMM dd, hh:mm a').format(date);
    } catch (e) {
      return timestamp.toString();
    }
  }

  void _showOrderDetailSheet(Map<String, dynamic> initialOrder) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) => ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: _liveDispatchOrdersNotifier,
        builder: (context, orders, child) {
          final order = orders.firstWhere((o) => o['_id'] == initialOrder['_id'], orElse: () => initialOrder);
          return _FullScreenOrderDetail(
            order: order,
            onAssignDriver: () { Navigator.pop(ctx); _showAssignDriverSheet(order); },
            onUnassignDriver: () { Navigator.pop(ctx); _unassignDriver(order['_id']); },
            onCancelOrder: () { _cancelOrder(order['_id']); },
            onTrackLive: () { Navigator.pop(ctx); _trackOrderLive(order); },
            onShowImagePreview: (url, title) => _showImagePreviewDialog(url, title),
            onPayVendor: () { _payVendorForOrder(order); },
            onOpenPayoutHub: () {
              Navigator.of(ctx, rootNavigator: true).pop();
              setState(() {
                _tab = 16; // Vendor Payments Hub Tab
              });
            },
          );
        },
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
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
                  Text('&9   & &9   ', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
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
                : '&& & 9 ', 
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
    final totalAmount = ((order['totalAmount'] ?? 0.0) as num).toDouble();
    final delivery = ((order['deliveryCharge'] ?? 0.0) as num).toDouble();
    final customerPlatformFee = ((order['customerPlatformFee'] ?? 5.0) as num).toDouble();
    final subtotal = totalAmount > 0 ? (totalAmount - customerPlatformFee) : 0.0;
    final platformFee = ((order['platformFee'] ?? (subtotal * 0.05)) as num).toDouble();

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
            _driverInfoRow(Icons.payments_rounded, 'Order Total', '₹${(subtotal + delivery + customerPlatformFee).toStringAsFixed(2)}', color: Colors.green.shade700),
            const Divider(height: 24),
            _driverInfoRow(Icons.store_rounded, 'Vendor Value (Items)', '₹${subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _driverInfoRow(Icons.delivery_dining_rounded, 'Delivery Charge', '₹${delivery.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _driverInfoRow(Icons.account_balance_wallet_rounded, 'Platform Fee', '₹${customerPlatformFee.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _driverInfoRow(Icons.percent_rounded, 'Vendor Commission (5%)', '₹${platformFee.toStringAsFixed(2)}'),
            const Divider(height: 24),
            Row(
              children: [
                Text('VENDOR NET EARNINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.grey.shade600)),
                const Spacer(),
                Text('₹${(subtotal - platformFee).toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
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
    final isCod = m == 'COD' || m == 'CASH';
    final displayLabel = isCod ? 'Cash on Delivery' : 'Online Payment';
    final displayCode = m.isEmpty ? '' : ' ($m)';
    final color = isCod ? Colors.orange.shade800 : AdminColors.primaryIndigo;
    final icon = isCod ? Icons.money_rounded : Icons.language_rounded;
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

    final historyOrders = allOrdersMap.values.where((o) {
      final s = o['status']?.toString() ?? '';
      return s == 'Delivered' || s == 'Cancelled' || s == 'Rejected';
    }).toList();
    
    // Local history sync removed

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('ORDER HISTORY', 'Customer Orders Hub'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(40),
              children: [
                // ₹a HISTORY SECTION ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
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
                  child: (_isCustomerHistoryLoading && historyOrders.isEmpty)
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

  Widget _buildCancelledOrdersTab() {
    final Map<String, Map<String, dynamic>> cancelledMap = {};
    for (var o in _customerOrders) {
      final s = o['status']?.toString().toLowerCase() ?? '';
      if (s == 'cancelled' || s == 'rejected') {
        final id = o['_id']?.toString() ?? o['displayId']?.toString() ?? '';
        if (id.isNotEmpty) cancelledMap[id] = o;
      }
    }
    for (var o in _customerOrderHistory) {
      final s = o['status']?.toString().toLowerCase() ?? '';
      if (s == 'cancelled' || s == 'rejected') {
        final id = o['_id']?.toString() ?? o['displayId']?.toString() ?? '';
        if (id.isNotEmpty) cancelledMap[id] = o;
      }
    }

    final cancelledOrders = cancelledMap.values.toList();
    cancelledOrders.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

    final byCustomer = cancelledOrders.where((o) => (o['cancelledBy'] ?? '').toString().toLowerCase().contains('customer')).length;
    final byVendor = cancelledOrders.where((o) => (o['cancelledBy'] ?? '').toString().toLowerCase().contains('vendor')).length;
    final byDriver = cancelledOrders.where((o) => (o['cancelledBy'] ?? '').toString().toLowerCase().contains('delivery') || (o['cancelledBy'] ?? '').toString().toLowerCase().contains('driver')).length;

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('CANCELLED ORDERS LOGS', 'Real-time Cancellation Intelligence'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(40),
              children: [
                // Top Metrics Cards
                Row(
                  children: [
                    Expanded(child: _statCard('TOTAL CANCELLED', cancelledOrders.length.toString(), Icons.cancel_rounded, const Color(0xFFEF4444))),
                    const SizedBox(width: 20),
                    Expanded(child: _statCard('BY CUSTOMER', byCustomer.toString(), Icons.person_rounded, const Color(0xFFF59E0B))),
                    const SizedBox(width: 20),
                    Expanded(child: _statCard('BY VENDOR', byVendor.toString(), Icons.storefront_rounded, const Color(0xFF6366F1))),
                    const SizedBox(width: 20),
                    Expanded(child: _statCard('BY DELIVERY PARTNER', byDriver.toString(), Icons.two_wheeler_rounded, const Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 32),

                // Table Section
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.cancel_presentation_rounded, color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 6),
                          Text('CANCELLED ORDERS LIST (${cancelledOrders.length})', style: GoogleFonts.outfit(color: const Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () { _fetchCustomerOrders(); _fetchCustomerOrderHistory(); },
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: AdminColors.primaryIndigo),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if ((_isCustomerOrdersLoading || _isCustomerHistoryLoading) && cancelledOrders.isEmpty)
                  const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo))
                else if (cancelledOrders.isEmpty)
                  _buildEmptyStateMini('No Cancelled Orders', 'Orders cancelled by customers, vendors, or drivers will appear here.')
                else
                  _buildCancelledOrdersTable(cancelledOrders),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledOrdersTable(List<Map<String, dynamic>> orders) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('ORDER ID & TIME', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 1))),
                Expanded(flex: 2, child: Text('CUSTOMER', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 1))),
                Expanded(flex: 2, child: Text('VENDOR / SHOP', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 1))),
                Expanded(flex: 2, child: Text('CANCELLED BY', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 1))),
                Expanded(flex: 3, child: Text('CANCELLATION REASON', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 1))),
                Expanded(flex: 1, child: Text('AMOUNT', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 1))),
                const SizedBox(width: 80),
              ],
            ),
          ),
          ...orders.map((o) {
            final displayId = o['displayId'] ?? o['_id']?.substring(o['_id'].length > 5 ? o['_id'].length - 5 : 0) ?? 'N/A';
            final customerName = o['customer']?['name'] ?? 'Guest';
            final vendorName = o['vendor']?['storeName'] ?? o['customStoreName'] ?? 'Store';
            final cancelledBy = o['cancelledBy'] ?? 'System / Vendor';
            final reason = (o['cancellationReason'] != null && o['cancellationReason'].toString().isNotEmpty)
                ? o['cancellationReason'].toString()
                : 'No reason provided';
            final amount = o['totalAmount']?.toString() ?? '0';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#$displayId', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: AdminColors.textHeading)),
                        Text(_formatTimestamp(o['createdAt']), style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(customerName, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AdminColors.textHeading)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(vendorName, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AdminColors.textHeading)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        cancelledBy.toUpperCase(),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.red.shade800),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      reason,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text('₹$amount', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: AdminColors.textHeading)),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextButton(
                      onPressed: () => _showOrderDetails(o),
                      child: Text('VIEW', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: AdminColors.primaryIndigo)),
                    ),
                  ),
                ],
              ),
            );
          }),
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
    final sortedOrders = List<Map<String, dynamic>>.from(orders);
    sortedOrders.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

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
          ...sortedOrders.map((o) => TableRow(
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
              _interactiveCell(o, Text(o['updatedAt'] != null ? DateFormat('MMM dd, hh:mm').format(DateTime.parse(o['updatedAt']).toLocal().toLocal()) : 'N/A', style: TextStyle(color: Colors.grey.shade500, fontSize: 11))),
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
          Flexible(
            child: Text(
              status.toUpperCase(), 
              style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
                Text(order['createdAt'] != null ? DateFormat('MMM dd, hh:mm a').format(DateTime.parse(order['createdAt'].toString()).toLocal()) : 'Recently', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
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
    List<dynamic>? dutyLogs;
    bool initialLoadTriggered = false;

    Future<List<dynamic>> fetchDutyLogs(String driverId) async {
      try {
        final res = await http.get(
          Uri.parse('$_baseUrl/admin/drivers/$driverId/duty-logs'),
          headers: _headers,
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true) {
            return data['data'] ?? [];
          }
        }
      } catch (e) {
        debugPrint('Error fetching duty logs: $e');
      }
      return [];
    }

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

        return StatefulBuilder(
          builder: (context, setLocalState) {
            if (!initialLoadTriggered) {
              initialLoadTriggered = true;
              final driverId = (driver['_id'] ?? driver['id'] ?? '').toString();
              fetchDutyLogs(driverId).then((val) {
                setLocalState(() {
                  dutyLogs = val;
                });
              });
            }

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
                                          _driverMiniStat('RATING', ' ${driver['rating']?.toString() ?? '4.8'}', Colors.orange),
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
                              const SizedBox(height: 32),
                              // Duty Logs Section
                              _detailSectionCard('Duty Log History (Day-by-Day)', Icons.schedule_rounded, [
                                if (dutyLogs == null)
                                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                                else if (dutyLogs!.isEmpty)
                                  Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No duty logs recorded yet.', style: GoogleFonts.outfit(color: Colors.grey))))
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: dutyLogs!.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (context, idx) {
                                      final day = dutyLogs![idx];
                                      final dateStr = _formatDateOnlyStr(day['date'] ?? '');
                                      final totalHours = day['totalDurationStr'] ?? '0m';
                                      final rawSessions = day['sessions'] as List<dynamic>? ?? [];

                                      // Deduplicate by onlineTime and offlineTime
                                      final seenKeys = <String>{};
                                      final sessionsList = <dynamic>[];
                                      for (final s in rawSessions) {
                                        final key = '${s['onlineTime']}_${s['offlineTime']}';
                                        if (!seenKeys.contains(key)) {
                                          seenKeys.add(key);
                                          sessionsList.add(s);
                                        }
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.calendar_today_rounded, size: 14, color: AdminColors.primaryIndigo),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    dateStr,
                                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: AdminColors.textHeading),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 5,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: sessionsList.map<Widget>((session) {
                                                  final inTime = _formatDateTimeStr(session['onlineTime']);
                                                  final outTime = session['offlineTime'] != null 
                                                    ? _formatDateTimeStr(session['offlineTime'])
                                                    : 'ACTIVE';
                                                  final isActive = outTime == 'ACTIVE';

                                                  return Container(
                                                    margin: const EdgeInsets.only(bottom: 6),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: isActive ? Colors.blue.shade50.withOpacity(0.5) : Colors.grey.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: isActive ? Colors.blue.shade200 : Colors.grey.shade200),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.login_rounded, size: 13, color: Colors.green.shade700),
                                                        const SizedBox(width: 4),
                                                        Text(inTime, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                                                        const SizedBox(width: 8),
                                                        Icon(Icons.east_rounded, size: 12, color: Colors.grey.shade400),
                                                        const SizedBox(width: 8),
                                                        if (isActive) ...[
                                                          Container(
                                                            width: 7,
                                                            height: 7,
                                                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent),
                                                          ),
                                                          const SizedBox(width: 5),
                                                          Text('ACTIVE DUTY', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blue.shade700, letterSpacing: 0.5)),
                                                        ] else ...[
                                                          Icon(Icons.logout_rounded, size: 13, color: Colors.redAccent),
                                                          const SizedBox(width: 4),
                                                          Text(outTime, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                                                        ],
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: AdminColors.primaryIndigo.withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AdminColors.primaryIndigo.withOpacity(0.15)),
                                                  ),
                                                  child: Text(
                                                    '$totalHours Total',
                                                    style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
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
      },
    );
  }

  String _formatDateTimeStr(String? isoStr) {
    if (isoStr == null) return '--:--';
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '--:--';
    }
  }

  String _formatDateOnlyStr(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
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

  Widget _buildResponsiveImage(String? rawPath, {double maxHeight = 280}) {
    if (rawPath == null || rawPath.toString().trim().isEmpty) {
      return Container(
        height: 160,
        width: double.infinity,
        color: Colors.grey.shade100,
        child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
      );
    }

    final String strPath = rawPath.toString().trim();
    final String cleanPath = strPath.replaceAll('\\', '/');

    // Check if path is absolute local disk path
    final bool isLocalDiskFile = strPath.contains(':\\') || (strPath.startsWith('/') && File(strPath).existsSync());
    if (isLocalDiskFile && File(strPath).existsSync()) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Image.file(
          File(strPath),
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
        ),
      );
    }

    final String host = _baseUrl.split('/api').first;
    final String fullUrl = (cleanPath.startsWith('http://') || cleanPath.startsWith('https://'))
        ? cleanPath
        : '$host${cleanPath.startsWith('/') ? '' : '/'}$cleanPath';

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Image.network(
        fullUrl,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) {
          // Fallback: Check local namba_backend folder
          final String localBackendPath = 'D:/New folder (2)/namba_backend/$cleanPath';
          if (File(localBackendPath).existsSync()) {
            return Image.file(File(localBackendPath), width: double.infinity, fit: BoxFit.contain);
          }
          return Container(
            height: 160,
            width: double.infinity,
            color: Colors.grey.shade100,
            child: const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 36),
                SizedBox(height: 8),
                Text('Image unreachable', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            )),
          );
        },
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

  Future<void> _markCustomerPaymentPaid(Map<String, dynamic> order) async {
    final orderId = (order['_id'] ?? order['id'])?.toString();
    if (orderId == null || orderId.isEmpty) return;

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/orders/$orderId'),
        headers: _headers,
        body: jsonEncode({
          'paymentStatus': 'Paid',
          'customerPaid': true,
        }),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || data['success'] == true) {
        setState(() {
          order['paymentStatus'] = 'Paid';
          order['customerPaid'] = true;
        });

        _handleLiveSocketOrderUpdate({
          'orderId': orderId,
          'paymentStatus': 'Paid',
          'customerPaid': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Customer Payment marked as PAID / DONE!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        setState(() {
          order['paymentStatus'] = 'Paid';
          order['customerPaid'] = true;
        });
        _handleLiveSocketOrderUpdate({
          'orderId': orderId,
          'paymentStatus': 'Paid',
          'customerPaid': true,
        });
      }
    } catch (e) {
      debugPrint('Error marking customer payment: $e');
      setState(() {
        order['paymentStatus'] = 'Paid';
        order['customerPaid'] = true;
      });
      _handleLiveSocketOrderUpdate({
        'orderId': orderId,
        'paymentStatus': 'Paid',
        'customerPaid': true,
      });
    }
  }

  Future<void> _payVendorForOrder(Map<String, dynamic> order) async {
    final orderId = (order['_id'] ?? order['id'])?.toString();
    if (orderId == null || orderId.isEmpty) return;

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/orders/$orderId/admin-pay-vendor'),
        headers: _headers,
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || data['success'] == true) {
        setState(() {
          order['vendorPaymentStatus'] = 'Paid';
          order['vendorPaid'] = true;
        });

        _handleLiveSocketOrderUpdate({
          'orderId': orderId,
          'vendorPaymentStatus': 'Paid',
          'vendorPaid': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Vendor Payment marked as PAID successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        setState(() {
          order['vendorPaymentStatus'] = 'Paid';
          order['vendorPaid'] = true;
        });
        _handleLiveSocketOrderUpdate({
          'orderId': orderId,
          'vendorPaymentStatus': 'Paid',
          'vendorPaid': true,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Vendor Payment updated to PAID!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error paying vendor: $e');
      setState(() {
        order['vendorPaymentStatus'] = 'Paid';
        order['vendorPaid'] = true;
      });
      _handleLiveSocketOrderUpdate({
        'orderId': orderId,
        'vendorPaymentStatus': 'Paid',
        'vendorPaid': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vendor Payment updated to PAID!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showOrderDetails(Map<String, dynamic> initialOrder) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: _liveDispatchOrdersNotifier,
        builder: (context, liveOrders, child) {
          final order = liveOrders.firstWhere(
            (o) => o['_id'] == initialOrder['_id'] || o['id'] == initialOrder['_id'] || o['displayId'] == initialOrder['displayId'],
            orElse: () => initialOrder,
          );

          return Center(
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
                if (order['status']?.toString().toLowerCase() == 'cancelled' || order['status']?.toString().toLowerCase() == 'rejected')
                  Container(
                    margin: const EdgeInsets.fromLTRB(40, 20, 40, 0),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ORDER CANCELLED BY: ${order['cancelledBy']?.toString().toUpperCase() ?? "VENDOR / CUSTOMER"}',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF991B1B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Reason: ${order['cancellationReason'] != null && order['cancellationReason'].toString().isNotEmpty ? order['cancellationReason'] : "No specific reason provided"}',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFFB91C1C)),
                              ),
                            ],
                          ),
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
                              Builder(builder: (_) {
                                final rawAddr = (order['deliveryAddress'] ?? order['deliveryAddressFormatted'])?.toString() ?? '';
                                final cleanAddr = (rawAddr.isEmpty || rawAddr.toLowerCase().contains('fetching address'))
                                    ? 'Location Pinned (Erode)'
                                    : rawAddr;
                                final dCoords = order['deliveryCoordinates']?['coordinates'];
                                final gpsStr = (dCoords is List && dCoords.length >= 2)
                                    ? '\nGPS Pin: ${dCoords[1]}, ${dCoords[0]}'
                                    : '';
                                return _detailSectionCard('Customer Details', Icons.person_rounded, [
                                  _detailRow('Name', order['customer']?['name'] ?? 'Guest'),
                                  _detailRow('Phone', order['customer']?['phone'] ?? 'N/A'),
                                  _detailRow('Address', '$cleanAddr$gpsStr'),
                                ]);
                              }),
                              const SizedBox(height: 24),
                              _detailSectionCard('Vendor Details', Icons.storefront_rounded, [
                                _detailRow('Store Name', order['isCustomStore'] == true ? (order['customStoreName'] ?? 'Any Store') : (order['vendor']?['storeName'] ?? 'Unknown')),
                                _detailRow('Category', order['isCustomStore'] == true ? 'Personal Assistant' : (order['vendor']?['category'] ?? 'N/A')),
                                _detailRow('Contact', order['isCustomStore'] == true ? 'N/A (Custom Shop)' : (order['vendor']?['contact'] ?? 'N/A')),
                              ]),
                              const SizedBox(height: 24),
                              // ₹a PAYMENT METHOD CARD ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
                              Builder(builder: (_) {
                                final rawMethod = (order['paymentMethod'] ?? order['payment_method'] ?? '').toString().toUpperCase().trim();
                                final isCod        = rawMethod == 'COD' || rawMethod == 'CASH';
                                final isUpi        = rawMethod == 'UPI' || rawMethod == 'GPAY' || rawMethod == 'PHONEPE' || rawMethod == 'PAYTM';
                                final isCard       = rawMethod == 'CARD' || rawMethod == 'CREDIT_CARD' || rawMethod == 'DEBIT_CARD' || rawMethod == 'CREDIT CARD' || rawMethod == 'DEBIT CARD';
                                final isNetBanking = rawMethod == 'NETBANKING' || rawMethod == 'NET_BANKING' || rawMethod == 'NET BANKING';

                                final isPaid = (order['paymentStatus'] ?? order['payment_status'] ?? '').toString().toUpperCase() == 'PAID' ||
                                               (order['paymentStatus'] ?? order['payment_status'] ?? '').toString().toUpperCase() == 'COMPLETED' ||
                                               order['customerPaid'] == true;
                                final paymentStatus = (order['paymentStatus'] ?? order['payment_status'] ?? 'Pending').toString();

                                IconData payIcon;
                                Color payColor;
                                Color payBg;
                                String payLabel;
                                String paySubLabel;

                                if (isCod) {
                                  payIcon     = Icons.money_rounded;
                                  payColor    = const Color(0xFFD97706);
                                  payBg       = const Color(0xFFFFFBEB);
                                  payLabel    = 'Cash on Delivery';
                                  paySubLabel = 'Payment collected at doorstep';
                                } else if (!isPaid) {
                                  payIcon     = Icons.hourglass_top_rounded;
                                  payColor    = const Color(0xFFD97706);
                                  payBg       = const Color(0xFFFFFBEB);
                                  payLabel    = 'Customer Payment Pending';
                                  paySubLabel = 'Awaiting online payment from customer';
                                } else if (isUpi) {
                                  payIcon     = Icons.account_balance_wallet_rounded;
                                  payColor    = const Color(0xFF7C3AED);
                                  payBg       = const Color(0xFFF5F3FF);
                                  payLabel    = 'UPI Payment';
                                  paySubLabel = 'Paid via UPI / PhonePe / GPay';
                                } else if (isCard) {
                                  payIcon     = Icons.credit_card_rounded;
                                  payColor    = const Color(0xFF0EA5E9);
                                  payBg       = const Color(0xFFF0F9FF);
                                  payLabel    = 'Card Payment';
                                  paySubLabel = 'Credit / Debit card transaction';
                                } else if (isNetBanking) {
                                  payIcon     = Icons.account_balance_rounded;
                                  payColor    = const Color(0xFF059669);
                                  payBg       = const Color(0xFFF0FDF4);
                                  payLabel    = 'Net Banking';
                                  paySubLabel = 'Direct bank transfer';
                                } else {
                                  payIcon     = Icons.payment_rounded;
                                  payColor    = const Color(0xFF059669);
                                  payBg       = const Color(0xFFF0FDF4);
                                  payLabel    = rawMethod.isEmpty ? 'Online Payment' : rawMethod;
                                  paySubLabel = 'Online payment completed';
                                }

                                return Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.grey.shade100),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        const Icon(Icons.payments_rounded, size: 20, color: AdminColors.primaryIndigo),
                                        const SizedBox(width: 12),
                                        Text('Payment Details', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
                                      ]),
                                      const SizedBox(height: 20),
                                      // Payment method chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(color: payBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: payColor.withOpacity(0.3))),
                                        child: Row(children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(color: payColor.withOpacity(0.12), shape: BoxShape.circle),
                                            child: Icon(payIcon, color: payColor, size: 22),
                                          ),
                                          const SizedBox(width: 14),
                                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(payLabel, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: payColor)),
                                            Text(paySubLabel, style: GoogleFonts.outfit(fontSize: 11, color: payColor.withOpacity(0.7))),
                                          ]),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: isPaid ? Colors.green.shade200 : Colors.orange.shade200),
                                            ),
                                            child: Text(
                                              isPaid ? ' PAID' : paymentStatus.toUpperCase(),
                                              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: isPaid ? Colors.green.shade700 : Colors.orange.shade700),
                                            ),
                                          ),
                                        ]),
                                      ),
                                      // Quick reference chips
                                      const SizedBox(height: 16),
                                      Wrap(spacing: 8, children: [
                                        _payMethodChip('COD', Icons.money_rounded, isCod, const Color(0xFFD97706)),
                                        _payMethodChip('UPI', Icons.account_balance_wallet_rounded, isUpi, const Color(0xFF7C3AED)),
                                        _payMethodChip('Card', Icons.credit_card_rounded, isCard, const Color(0xFF0EA5E9)),
                                        _payMethodChip('Net Banking', Icons.account_balance_rounded, isNetBanking, const Color(0xFF059669)),
                                      ]),
                                    ],
                                  ),
                                );
                              }),
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

                                // 1b. Customer Uploaded Photo (for Photo orders)
                                Builder(builder: (_) {
                                  final String? rawPhoto = order['photoUrl'] ?? order['customItemsPhoto'];
                                  if (rawPhoto == null || rawPhoto.isEmpty) return const SizedBox.shrink();
                                  
                                  final String photoUrl = (rawPhoto.startsWith('http://') || rawPhoto.startsWith('https://'))
                                      ? rawPhoto
                                      : '${_SuperAdminDashboardState._baseUrl.split('/api').first}${rawPhoto.startsWith('/') ? '' : '/'}$rawPhoto';
                                      
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF7ED),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.orange.shade300, width: 1.5),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.photo_library_rounded, color: Colors.orange, size: 22),
                                                const SizedBox(width: 10),
                                                Text('CUSTOMER PHOTO ORDER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.orange.shade900)),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            InkWell(
                                              onTap: () {
                                                final String cleanRaw = rawPhoto.replaceAll('\\', '/');
                                                final String photoUrl = (cleanRaw.startsWith('http://') || cleanRaw.startsWith('https://'))
                                                    ? cleanRaw
                                                    : '${_SuperAdminDashboardState._baseUrl.split('/api').first}${cleanRaw.startsWith('/') ? '' : '/'}$cleanRaw';
                                                _showImagePreviewDialog(photoUrl, 'Customer Photo Order');
                                              },
                                              child: MouseRegion(
                                                cursor: SystemMouseCursors.zoomIn,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: _buildResponsiveImage(rawPhoto, maxHeight: 280),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  );
                                }),

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
                                Builder(builder: (_) {
                                  double itemsSum = 0.0;
                                  if (order['items'] != null && (order['items'] as List).isNotEmpty) {
                                    for (var it in (order['items'] as List)) {
                                      if (it is Map) {
                                        double p = ((it['price'] ?? 0) as num).toDouble();
                                        int q = ((it['quantity'] ?? 1) as num).toInt();
                                        itemsSum += (p * q);
                                      }
                                    }
                                  }
                                  final double tot = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
                                  final double del = (order['deliveryCharge'] as num?)?.toDouble() ?? 0.0;
                                  final double plt = (order['customerPlatformFee'] as num?)?.toDouble() ?? 0.0;
                                  final double sub = itemsSum > 0 ? itemsSum : ((order['subTotal'] as num?)?.toDouble() ?? (tot > 0 ? (tot - del - plt) : 0.0));

                                  return _priceRow('Subtotal', '₹${sub.toStringAsFixed(0)}', isBold: false);
                                }),
                                if (order['discount'] != null && (order['discount'] as num) > 0) ...[
                                  _priceRow('Discount', '-₹${order['discount']}', isBold: false, color: Colors.green),
                                  Builder(builder: (_) {
                                    final double sub = (order['subTotal'] as num?)?.toDouble() ?? (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
                                    final double disc = (order['discount'] as num?)?.toDouble() ?? 0.0;
                                    final double itemPrice = (sub - disc) > 0 ? (sub - disc) : 0.0;
                                    return _priceRow('Price (After Discount)', '₹${itemPrice.toStringAsFixed(0)}', isBold: true, color: const Color(0xFF1E40AF));
                                  }),
                                ],
                                _priceRow('Delivery Fee', '₹${order['deliveryCharge'] ?? '0'}', isBold: false),
                                _priceRow('Platform Fee', '₹${order['customerPlatformFee'] ?? '0'}', isBold: false),
                                const SizedBox(height: 16),
                                Builder(builder: (_) {
                                  double itemsSum = 0.0;
                                  if (order['items'] != null && (order['items'] as List).isNotEmpty) {
                                    for (var it in (order['items'] as List)) {
                                      if (it is Map) {
                                        double p = ((it['price'] ?? 0) as num).toDouble();
                                        int q = ((it['quantity'] ?? 1) as num).toInt();
                                        itemsSum += (p * q);
                                      }
                                    }
                                  }
                                  final double del = (order['deliveryCharge'] as num?)?.toDouble() ?? 0.0;
                                  final double plt = (order['customerPlatformFee'] as num?)?.toDouble() ?? 0.0;
                                  final double disc = (order['discount'] as num?)?.toDouble() ?? 0.0;
                                  final double sub = itemsSum > 0 ? itemsSum : ((order['subTotal'] as num?)?.toDouble() ?? 0.0);
                                  final double calcTotal = sub > 0 ? (sub - disc + del + plt) : ((order['totalAmount'] as num?)?.toDouble() ?? 0.0);

                                  return _priceRow('TOTAL AMOUNT', '₹${calcTotal.toStringAsFixed(0)}', isBold: true, color: AdminColors.primaryIndigo);
                                }),
                                const Divider(height: 24),
                                Builder(builder: (_) {
                                  double itemsSum = 0.0;
                                  if (order['items'] != null && (order['items'] as List).isNotEmpty) {
                                    for (var it in (order['items'] as List)) {
                                      if (it is Map) {
                                        double p = ((it['price'] ?? 0) as num).toDouble();
                                        int q = ((it['quantity'] ?? 1) as num).toInt();
                                        itemsSum += (p * q);
                                      }
                                    }
                                  }
                                  final double del = (order['deliveryCharge'] as num?)?.toDouble() ?? 0.0;
                                  final double plt = (order['customerPlatformFee'] as num?)?.toDouble() ?? 0.0;
                                  final double disc = (order['discount'] as num?)?.toDouble() ?? 0.0;
                                  final double sub = itemsSum > 0 ? itemsSum : ((order['subTotal'] as num?)?.toDouble() ?? 0.0);
                                  final double calcTotal = sub > 0 ? (sub - disc + del + plt) : ((order['totalAmount'] as num?)?.toDouble() ?? 0.0);

                                  final double vendorPayout = sub > 0 ? (sub - disc) : (calcTotal - del - plt);
                                  final displayPayout = vendorPayout < 0 ? 0.0 : vendorPayout;

                                  final bool isVendorPaid = (order['vendorPaymentStatus'] ?? '').toString().toLowerCase() == 'paid' ||
                                                            (order['vendorPaymentStatus'] ?? '').toString().toLowerCase() == 'completed' ||
                                                            order['vendorPaid'] == true;

                                  final bool isCustomerPaid = (order['paymentStatus'] ?? '').toString().toLowerCase() == 'paid' ||
                                                              (order['paymentStatus'] ?? '').toString().toLowerCase() == 'completed' ||
                                                              order['customerPaid'] == true;

                                  final String payMethod = (order['paymentMethod'] ?? '').toString().toUpperCase();

                                  return Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: isVendorPaid ? Colors.green.shade50 : Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isVendorPaid ? Colors.green.shade200 : Colors.amber.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Customer Payment Status Line
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isCustomerPaid ? Colors.green.shade100.withOpacity(0.5) : Colors.orange.shade100.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: isCustomerPaid ? Colors.green.shade300 : Colors.orange.shade300),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(isCustomerPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                                size: 18, color: isCustomerPaid ? Colors.green.shade800 : Colors.orange.shade900),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  isCustomerPaid 
                                                    ? 'CUSTOMER PAID: ₹${calcTotal.toStringAsFixed(0)} ${payMethod.isNotEmpty ? "($payMethod)" : ""}' 
                                                    : 'CUSTOMER PAYMENT PENDING (₹${calcTotal.toStringAsFixed(0)})',
                                                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, 
                                                    color: isCustomerPaid ? Colors.green.shade900 : Colors.orange.shade900),
                                                ),
                                              ),
                                              if (!isCustomerPaid) ...[
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  onPressed: () => _markCustomerPaymentPaid(order),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF10B981),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    elevation: 0,
                                                  ),
                                                  child: Text('MARK AS PAID', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Vendor Net Payout Line + Pay Vendor Button
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('NET VENDOR PAYOUT', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade700)),
                                                const SizedBox(height: 2),
                                                Text('₹${displayPayout.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                                              ],
                                            ),
                                            if (isVendorPaid)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade400)),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.verified_rounded, size: 16, color: Colors.green),
                                                    const SizedBox(width: 6),
                                                    Text('VENDOR PAID', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green.shade900)),
                                                  ],
                                                ),
                                              )
                                            else
                                              ElevatedButton.icon(
                                                onPressed: () => _payVendorForOrder(order),
                                                icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                                                label: Text('PAY VENDOR ₹${displayPayout.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF10B981),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  elevation: 2,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text('(Total Customer Paid ₹${calcTotal.toStringAsFixed(0)} - Delivery Fee ₹${del.toStringAsFixed(0)} - Platform Fee ₹${plt.toStringAsFixed(0)})',
                                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                // & 3. Proof of Purchase (Bill) - Shown at the bottom (Hidden for Customer Orders Tab)
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
                                                DateFormat('hh:mm a').format(DateTime.parse(order['billUploadedAt'].toString()).toLocal()),
                                                style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                         Builder(builder: (context) {
                                           final rawPath = order['billPhotoPath']?.toString() ?? '';
                                           final cleanRaw = rawPath.replaceAll('\\', '/');
                                           final billUrl = (cleanRaw.startsWith('http') || cleanRaw.contains(':\\'))
                                               ? cleanRaw
                                               : '${_SuperAdminDashboardState._baseUrl.split('/api').first}${cleanRaw.startsWith('/') ? '' : '/'}$cleanRaw';
                                           return GestureDetector(
                                             onTap: () => _showImagePreviewDialog(billUrl, 'OFFICIAL RECEIPT'),
                                             child: MouseRegion(
                                               cursor: SystemMouseCursors.zoomIn,
                                               child: ClipRRect(
                                                 borderRadius: BorderRadius.circular(12),
                                                 child: _buildResponsiveImage(rawPath, maxHeight: 350),
                                               ),
                                             ),
                                           );
                                         }),
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
      );
      },
    ),
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(opacity: anim1, child: ScaleTransition(scale: anim1.drive(Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack))), child: child));
    },
  );
  }

  Widget _payMethodChip(String label, IconData icon, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? color.withOpacity(0.4) : Colors.grey.shade200, width: isActive ? 1.5 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: isActive ? color : Colors.grey.shade400),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: isActive ? FontWeight.w800 : FontWeight.w500, color: isActive ? color : Colors.grey.shade400)),
        if (isActive) ...[ const SizedBox(width: 4), Icon(Icons.check_circle_rounded, size: 11, color: color) ],
      ]),
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

          // Initial fetch a deferred to post-frame to avoid setState during build
          if (_onlineDrivers.isEmpty && !_isDriversLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) refresh();
            });
          }

          // Retrieve vendor / pickup coordinates
          final vCoords = order['vendor']?['location']?['coordinates'];
          final double? vendorLat = (vCoords is List && vCoords.length >= 2) ? (vCoords[1] as num).toDouble() : null;
          final double? vendorLng = (vCoords is List && vCoords.length >= 2) ? (vCoords[0] as num).toDouble() : null;

          // Retrieve customer / delivery coordinates
          final dCoords = order['deliveryCoordinates']?['coordinates'];
          final double? customerLat = (dCoords is List && dCoords.length >= 2) ? (dCoords[1] as num).toDouble() : null;
          final double? customerLng = (dCoords is List && dCoords.length >= 2) ? (dCoords[0] as num).toDouble() : null;

          // Prepare list with calculated distances
          final List<Map<String, dynamic>> sortedDrivers = _onlineDrivers.map((driver) {
            final Map<String, dynamic> copy = Map<String, dynamic>.from(driver);
            final locCoords = driver['lastLocation']?['coordinates'];
            final double? driverLat = (locCoords is List && locCoords.length >= 2) ? (locCoords[1] as num).toDouble() : null;
            final double? driverLng = (locCoords is List && locCoords.length >= 2) ? (locCoords[0] as num).toDouble() : null;

            double? distVendor;
            double? distCustomer;

            if (driverLat != null && driverLng != null) {
              if (vendorLat != null && vendorLng != null) {
                distVendor = _calculateDistance(vendorLat, vendorLng, driverLat, driverLng);
              }
              if (customerLat != null && customerLng != null) {
                distCustomer = _calculateDistance(customerLat, customerLng, driverLat, driverLng);
              }
            }

            copy['distVendor'] = distVendor;
            copy['distCustomer'] = distCustomer;
            copy['calculatedDistance'] = distVendor ?? distCustomer;
            return copy;
          }).toList();

          // Sort drivers with calculatedDistance (closest first)
          sortedDrivers.sort((a, b) {
            final distA = a['calculatedDistance'] as double? ?? 999999.0;
            final distB = b['calculatedDistance'] as double? ?? 999999.0;
            return distA.compareTo(distB);
          });

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Assign Delivery Partner', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 24)),
                    Text('Sorted by nearest pickup distance for Order #${order['displayId']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ]),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: () => refresh()),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Expanded(
                child: _isDriversLoading
                  ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo))
                  : sortedDrivers.isEmpty
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
                        itemCount: sortedDrivers.length,
                        itemBuilder: (ctx, idx) {
                          final driver = sortedDrivers[idx];
                          final double? distVendor = driver['distVendor'];
                          final double? distCustomer = driver['distCustomer'];
                          final bool isNearest = idx == 0 && (distVendor != null || distCustomer != null);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isNearest ? Colors.green.shade400 : Colors.grey.shade200, width: isNearest ? 1.5 : 1.0),
                              color: isNearest ? Colors.green.shade50.withOpacity(0.4) : Colors.white,
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: isNearest ? Colors.green.shade100 : AdminColors.primaryIndigo.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.delivery_dining_rounded,
                                  color: isNearest ? Colors.green.shade700 : AdminColors.primaryIndigo,
                                  size: 24,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(driver['name'] ?? 'Partner', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15)),
                                  if (isNearest) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade600,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '⚡ NEAREST (RECOMMENDED)',
                                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(driver['phone'] ?? 'N/A', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (distVendor != null) ...[
                                        Icon(Icons.storefront_rounded, size: 12, color: Colors.green.shade700),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${distVendor.toStringAsFixed(2)} km from store',
                                          style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      if (distCustomer != null) ...[
                                        Icon(Icons.location_on_rounded, size: 12, color: Colors.blue.shade700),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${distCustomer.toStringAsFixed(2)} km to customer',
                                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () { Navigator.pop(ctx); _assignDriver(order['_id'], driver['_id']); },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isNearest ? Colors.green.shade600 : AdminColors.primaryIndigo,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                Text('Target: ${b['target']} a ${b['time']}', style: TextStyle(color: Colors.grey, fontSize: 11)),
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(40),
              children: [
                _buildEliteHeader(),
                const SizedBox(height: 32),
                _buildProfessionalStatsGrid(),
                const SizedBox(height: 48),
                _buildDateWiseIncomeBreakdownTable(),
                const SizedBox(height: 48),
                _buildShopPerformanceSection(),
                const SizedBox(height: 48),
                _buildAdminReviewManagementSection(),
                const SizedBox(height: 48),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTopVendorsElite()),
                    const SizedBox(width: 40),
                    Expanded(child: _buildDriverPerformanceElite()),
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
          else ...list.map((v) {
            if (v is! Map) return const SizedBox.shrink();
            final storeName = v['storeName']?.toString() ?? 'Vendor';
            final firstChar = storeName.isNotEmpty ? storeName[0] : 'V';
            final orderCount = v['orderCount'] ?? v['orders'] ?? 0;
            final category = v['category']?.toString() ?? 'Retail';
            final sales = v['totalSales'] ?? v['revenue'] ?? 0;

            return GestureDetector(
              onTap: () {
                int idx = _vendors.indexWhere((vendor) => vendor['_id'] == v['_id']);
                if (idx != -1) {
                  setState(() {
                    _tab = 1;
                    _selectedVendorIdx = idx;
                    _vendorSubTab = _vendors[idx]['isLocked'] == true ? 1 : 0;
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
                        decoration: BoxDecoration(color: AdminColors.background, borderRadius: BorderRadius.circular(16)), 
                        child: Center(child: Text(firstChar, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF7C3AED))))
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(storeName, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('$orderCount Orders • $category', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(fmt(sales), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
                        Text('Earnings', style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
                      ]),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
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
          else ...list.map((d) {
            if (d is! Map) return const SizedBox.shrink();
            final name = d['name']?.toString() ?? 'Driver';
            final daysWorked = d['daysWorked'] ?? 0;
            final vehicleType = d['vehicleType']?.toString().toUpperCase() ?? 'BIKE';
            final deliveryCount = d['deliveryCount'] ?? 0;
            final isOnline = d['isOnline'] == true;

            return GestureDetector(
              onTap: () {
                int idx = _allDrivers.indexWhere((driver) => driver['_id'] == d['_id']);
                if (idx != -1) {
                  setState(() {
                    _tab = 3;
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
                          color: isOnline ? Colors.green.withOpacity(0.1) : AdminColors.background, 
                          borderRadius: BorderRadius.circular(16)
                        ), 
                        child: Center(child: Icon(Icons.person_rounded, color: isOnline ? Colors.green : Colors.grey, size: 24))
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('$daysWorked Days Active • $vehicleType', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('$deliveryCount', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo)),
                        Text('Deliveries', style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
                      ]),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }



  Widget _buildEliteHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
            Wrap(
              spacing: 8, runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _dateFilterPill('All Time', 'all_time'),
                _dateFilterPill('Today', 'today'),
                _dateFilterPill('Yesterday', 'yesterday'),
                _dateFilterPill('Last 7 Days', 'this_week'),
                _dateFilterPill('This Month', 'this_month'),
                InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                      initialDateRange: _selectedDateRange ?? DateTimeRange(
                        start: DateTime.now().subtract(const Duration(days: 7)),
                        end: DateTime.now(),
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDateRange = picked;
                        _selectedDateFilter = 'custom';
                      });
                      _fetchFinancialStats();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedDateFilter == 'custom' ? AdminColors.primaryIndigo : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _selectedDateFilter == 'custom' ? AdminColors.primaryIndigo : Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 14, color: _selectedDateFilter == 'custom' ? Colors.white : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          _selectedDateRange != null
                              ? '${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}'
                              : 'Custom Range',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            color: _selectedDateFilter == 'custom' ? Colors.white : AdminColors.textHeading,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _dateFilterPill(String label, String key) {
    final isSelected = _selectedDateFilter == key && _selectedDateRange == null;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDateFilter = key;
          _selectedDateRange = null;
        });
        _fetchFinancialStats();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AdminColors.primaryIndigo : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AdminColors.primaryIndigo : Colors.grey.shade200),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? Colors.white : AdminColors.textHeading,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDateWiseIncomeBreakdownTable() {
    final fmt = (num val) => NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN').format(val);

    num totalGross = 0;
    num totalDelivery = 0;
    num totalVendor = 0;
    num totalPlatform = 0;
    num totalNetProfit = 0;
    int totalDeliveredOrders = 0;

    for (var item in _dateWiseBreakdown) {
      if (item is Map) {
        totalGross += (item['totalRevenue'] as num?) ?? 0;
        totalDelivery += (item['delivery'] as num?) ?? 0;
        totalVendor += (item['vendor'] as num?) ?? 0;
        totalPlatform += (item['platform'] as num?) ?? 0;
        totalNetProfit += ((item['vendor'] as num?) ?? 0) + ((item['platform'] as num?) ?? 0);
        totalDeliveredOrders += (item['orderCount'] as int?) ?? 0;
      }
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.date_range_rounded, color: AdminColors.primaryIndigo, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DATE-WISE INCOME BREAKDOWN', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
                  Text('Detailed revenue & platform net profit for each date', style: GoogleFonts.outfit(fontSize: 12, color: AdminColors.textMuted, fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              if (_isFinancialLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.primaryIndigo)),
            ],
          ),
          const SizedBox(height: 28),
          if (_dateWiseBreakdown.isEmpty)
            _buildEmptyStateMini('No Date-Wise Income Data', 'No delivered order income records found for the selected date filter.')
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade100)),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AdminColors.background),
                  dataRowMaxHeight: 56,
                  horizontalMargin: 20,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('DELIVERED ORDERS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('DELIVERY FEES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('VENDOR COMM.', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('PLATFORM FEES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('GROSS REVENUE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('NET PROFIT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                  ],
                  rows: [
                    ..._dateWiseBreakdown.map((item) {
                      final rawDate = item['_id']?.toString() ?? 'N/A';
                      DateTime? parsed;
                      try { parsed = DateTime.parse(rawDate); } catch (_) {}
                      final displayDate = parsed != null ? DateFormat('dd MMM yyyy (EEE)').format(parsed) : rawDate;

                      final orderCount = (item['orderCount'] as num?) ?? 0;
                      final delivery = (item['delivery'] as num?) ?? 0;
                      final vendor = (item['vendor'] as num?) ?? 0;
                      final platform = (item['platform'] as num?) ?? 0;
                      final gross = (item['totalRevenue'] as num?) ?? 0;
                      final netProfit = vendor + platform;

                      return DataRow(cells: [
                        DataCell(Text(displayDate, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AdminColors.textHeading, fontSize: 13))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                          child: Text('$orderCount orders', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.blue, fontSize: 12)),
                        )),
                        DataCell(Text(fmt(delivery), style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AdminColors.textHeading, fontSize: 13))),
                        DataCell(Text(fmt(vendor), style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.orange.shade800, fontSize: 13))),
                        DataCell(Text(fmt(platform), style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.purple.shade800, fontSize: 13))),
                        DataCell(Text(fmt(gross), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo, fontSize: 13))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AdminColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text(fmt(netProfit), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.success, fontSize: 13)),
                        )),
                      ]);
                    }),
                    // SUMMARY TOTAL ROW
                    DataRow(
                      color: WidgetStateProperty.all(AdminColors.primaryIndigo.withOpacity(0.04)),
                      cells: [
                        DataCell(Text('TOTAL SUM', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo, fontSize: 13))),
                        DataCell(Text('$totalDeliveredOrders orders', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo, fontSize: 13))),
                        DataCell(Text(fmt(totalDelivery), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.textHeading, fontSize: 13))),
                        DataCell(Text(fmt(totalVendor), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.orange.shade900, fontSize: 13))),
                        DataCell(Text(fmt(totalPlatform), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.purple.shade900, fontSize: 13))),
                        DataCell(Text(fmt(totalGross), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo, fontSize: 14))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AdminColors.success, borderRadius: BorderRadius.circular(20)),
                          child: Text(fmt(totalNetProfit), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13)),
                        )),
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

  Widget _buildShopPerformanceSection() {
    final fmt = (num val) => NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN').format(val);

    final topOrderStore = _topByOrdersVendor ?? {};
    final topIncomeStore = _topByIncomeVendor ?? {};
    final lowestIncomeStore = _lowestIncomeVendor ?? {};

    List<Map<String, dynamic>> sortedVendors = List.from(_fullVendorPerformance);
    if (_vendorSortOption == 'income_desc') {
      sortedVendors.sort((a, b) => ((b['totalSales'] as num?) ?? 0).compareTo((a['totalSales'] as num?) ?? 0));
    } else if (_vendorSortOption == 'orders_desc') {
      sortedVendors.sort((a, b) => ((b['orderCount'] as num?) ?? 0).compareTo((a['orderCount'] as num?) ?? 0));
    } else if (_vendorSortOption == 'income_asc') {
      sortedVendors.sort((a, b) => ((a['totalSales'] as num?) ?? 0).compareTo((b['totalSales'] as num?) ?? 0));
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.storefront_rounded, color: Colors.orange, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SHOP PERFORMANCE & INCOME ANALYTICS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
                  Text('Stores receiving most orders, highest revenue & lowest performing shops', style: GoogleFonts.outfit(fontSize: 12, color: AdminColors.textMuted, fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              if (_isPerformanceLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.primaryIndigo)),
            ],
          ),
          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: _buildVendorHighlightCard(
                  title: 'MOST ORDERED SHOP',
                  storeName: topOrderStore['storeName']?.toString() ?? 'No Data',
                  category: topOrderStore['category']?.toString() ?? 'General',
                  mainValue: '${topOrderStore['orderCount'] ?? 0} Orders Delivered',
                  subValue: 'Total Sales: ${fmt((topOrderStore['totalSales'] as num?) ?? 0)}',
                  icon: Icons.shopping_bag_rounded,
                  color: AdminColors.primaryIndigo,
                  badgeLabel: 'HIGH VOLUME',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildVendorHighlightCard(
                  title: 'HIGHEST INCOME SHOP',
                  storeName: topIncomeStore['storeName']?.toString() ?? 'No Data',
                  category: topIncomeStore['category']?.toString() ?? 'General',
                  mainValue: fmt((topIncomeStore['totalSales'] as num?) ?? 0),
                  subValue: 'Platform Comm.: ${fmt((topIncomeStore['vendorCommission'] as num?) ?? 0)}',
                  icon: Icons.monetization_on_rounded,
                  color: AdminColors.success,
                  badgeLabel: 'TOP REVENUE',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildVendorHighlightCard(
                  title: 'LOWEST INCOME SHOP',
                  storeName: lowestIncomeStore['storeName']?.toString() ?? 'No Data',
                  category: lowestIncomeStore['category']?.toString() ?? 'General',
                  mainValue: fmt((lowestIncomeStore['totalSales'] as num?) ?? 0),
                  subValue: 'Delivered: ${lowestIncomeStore['orderCount'] ?? 0} Orders',
                  icon: Icons.trending_down_rounded,
                  color: Colors.orange.shade800,
                  badgeLabel: 'NEEDS ATTENTION',
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),

          Row(
            children: [
              Text('STORE-BY-STORE PERFORMANCE BREAKDOWN', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: AdminColors.textHeading)),
              const Spacer(),
              Wrap(
                spacing: 8,
                children: [
                  _vendorSortPill('Highest Income', 'income_desc'),
                  _vendorSortPill('Most Orders', 'orders_desc'),
                  _vendorSortPill('Lowest Income', 'income_asc'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (sortedVendors.isEmpty)
            _buildEmptyStateMini('No Store Performance Data', 'Store analytics will appear here after orders are delivered.')
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade100)),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AdminColors.background),
                  dataRowMaxHeight: 60,
                  horizontalMargin: 20,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('STORE NAME', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('DELIVERED ORDERS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('TOTAL SALES GENERATED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('AVG ORDER VALUE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('VENDOR COMM.', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                    DataColumn(label: Text('PERFORMANCE STATUS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AdminColors.textMuted))),
                  ],
                  rows: sortedVendors.map((v) {
                    final storeName = v['storeName']?.toString() ?? 'Store';
                    final category = v['category']?.toString() ?? 'General';
                    final orderCount = (v['orderCount'] as num?) ?? 0;
                    final totalSales = (v['totalSales'] as num?) ?? 0;
                    final avgValue = (v['avgOrderValue'] as num?) ?? 0;
                    final vendorComm = (v['vendorCommission'] as num?) ?? 0;

                    String perfTag = 'Active Store';
                    Color perfColor = Colors.blue;
                    if (topIncomeStore['_id'] != null && v['_id'] == topIncomeStore['_id'] && totalSales > 0) {
                      perfTag = '🏆 Top Revenue';
                      perfColor = AdminColors.success;
                    } else if (topOrderStore['_id'] != null && v['_id'] == topOrderStore['_id'] && orderCount > 0) {
                      perfTag = '⭐ High Volume';
                      perfColor = AdminColors.primaryIndigo;
                    } else if ((lowestIncomeStore['_id'] != null && v['_id'] == lowestIncomeStore['_id']) || totalSales == 0) {
                      perfTag = totalSales == 0 ? '⚠️ Inactive / 0 Sales' : '📉 Low Revenue';
                      perfColor = Colors.orange.shade900;
                    }

                    return DataRow(cells: [
                      DataCell(Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1),
                            child: Text(storeName.isNotEmpty ? storeName[0].toUpperCase() : 'S', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo, fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(storeName, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AdminColors.textHeading, fontSize: 13)),
                              Text(v['ownerName']?.toString() ?? '', style: GoogleFonts.outfit(fontSize: 11, color: AdminColors.textMuted)),
                            ],
                          ),
                        ],
                      )),
                      DataCell(Text(category, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AdminColors.textMuted, fontSize: 12))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                        child: Text('$orderCount orders', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.blue, fontSize: 12)),
                      )),
                      DataCell(Text(fmt(totalSales), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo, fontSize: 13))),
                      DataCell(Text(fmt(avgValue), style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AdminColors.textHeading, fontSize: 13))),
                      DataCell(Text(fmt(vendorComm), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.purple.shade800, fontSize: 13))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: perfColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(perfTag, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: perfColor, fontSize: 11)),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVendorHighlightCard({
    required String title,
    required String storeName,
    required String category,
    required String mainValue,
    required String subValue,
    required IconData icon,
    required Color color,
    required String badgeLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(badgeLabel, style: GoogleFonts.outfit(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: GoogleFonts.outfit(fontSize: 10, color: AdminColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(storeName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.textHeading), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(category, style: GoogleFonts.outfit(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          const Divider(height: 20),
          Text(mainValue, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
          const SizedBox(height: 2),
          Text(subValue, style: GoogleFonts.outfit(fontSize: 11, color: AdminColors.textMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _vendorSortPill(String label, String key) {
    final isSelected = _vendorSortOption == key;
    return InkWell(
      onTap: () {
        setState(() {
          _vendorSortOption = key;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AdminColors.primaryIndigo : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AdminColors.primaryIndigo : Colors.grey.shade200),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? Colors.white : AdminColors.textHeading,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _adminReviewsList = [];
  bool _isAdminReviewsLoading = false;

  Future<void> _fetchAdminReviews({bool silent = false}) async {
    if (mounted && !silent) setState(() => _isAdminReviewsLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/reviews'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _adminReviewsList = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isAdminReviewsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin reviews: $e');
    } finally {
      if (mounted && !silent) setState(() => _isAdminReviewsLoading = false);
    }
  }

  Future<void> _addAdminReview(String vendorId, String customerName, double rating, String comment) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/reviews'),
        headers: _headers,
        body: jsonEncode({
          'vendorId': vendorId,
          'customerName': customerName,
          'rating': rating,
          'comment': comment,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⭐ Review Added & Vendor Rating Updated!'), backgroundColor: Colors.green),
        );
        _fetchAdminReviews();
        _fetchPerformanceAnalytics(silent: true);
        _fetchAllVendors(silent: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to add review'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Error adding admin review: $e');
    }
  }

  Future<void> _deleteAdminReview(String reviewId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/admin/reviews/$reviewId'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Review Deleted Successfully'), backgroundColor: Colors.orange),
        );
        _fetchAdminReviews();
        _fetchPerformanceAnalytics(silent: true);
        _fetchAllVendors(silent: true);
      }
    } catch (e) {
      debugPrint('Error deleting admin review: $e');
    }
  }

  void _showAddReviewDialog() {
    String? selectedVendorId;
    final nameCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    double selectedRating = 5.0;

    final vendors = _vendors.where((v) => v['_id'] != null).toList();
    if (vendors.isNotEmpty) {
      selectedVendorId = vendors.first['_id']?.toString();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                  const SizedBox(width: 10),
                  Text('Add Store Review & Rating', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SELECT STORE / VENDOR', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedVendorId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: vendors.map((v) {
                        return DropdownMenuItem<String>(
                          value: v['_id']?.toString(),
                          child: Text('${v['storeName'] ?? "Store"} (${v['category'] ?? "General"})', style: GoogleFonts.outfit(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) => setDlgState(() => selectedVendorId = val),
                    ),
                    const SizedBox(height: 16),
                    Text('CUSTOMER NAME', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Suresh K / Verified Customer',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('RATING STARS', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(5, (index) {
                        final starVal = (index + 1).toDouble();
                        return IconButton(
                          icon: Icon(
                            index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () => setDlgState(() => selectedRating = starVal),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Text('REVIEW COMMENT / FEEDBACK', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: commentCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Type review comment e.g. Excellent service and fresh products!',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  label: Text('Post Review', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white)),
                  onPressed: () {
                    if (selectedVendorId == null || nameCtrl.text.trim().isEmpty || commentCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields!'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _addAdminReview(selectedVendorId!, nameCtrl.text.trim(), selectedRating, commentCtrl.text.trim());
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAdminReviewManagementSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STORE REVIEWS & RATINGS MANAGEMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
                  Text('Add, manage, and moderate customer reviews and ratings for all vendor stores', style: GoogleFonts.outfit(fontSize: 12, color: AdminColors.textMuted, fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: Text('+ Add Admin Review', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                onPressed: _showAddReviewDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isAdminReviewsLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Colors.amber)))
          else if (_adminReviewsList.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text('No store reviews added yet. Click "+ Add Admin Review" to post a review for any store.', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13)),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2.0),
                1: FlexColumnWidth(1.8),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(3.0),
                4: FlexColumnWidth(1.0),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                  children: [
                    Padding(padding: const EdgeInsets.all(14), child: Text('STORE NAME', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade600))),
                    Padding(padding: const EdgeInsets.all(14), child: Text('CUSTOMER NAME', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade600))),
                    Padding(padding: const EdgeInsets.all(14), child: Text('RATING', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade600))),
                    Padding(padding: const EdgeInsets.all(14), child: Text('REVIEW COMMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade600))),
                    Padding(padding: const EdgeInsets.all(14), child: Text('ACTION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade600))),
                  ],
                ),
                ..._adminReviewsList.map((review) {
                  final vendorName = review['vendor'] != null ? (review['vendor']['storeName'] ?? 'Store') : 'Store';
                  final customerName = review['customerName'] ?? 'Customer';
                  final rating = (review['rating'] as num?)?.toDouble() ?? 5.0;
                  final comment = review['comment'] ?? '';
                  final reviewId = review['_id']?.toString() ?? '';

                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(14), child: Text(vendorName, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13, color: AdminColors.textHeading))),
                      Padding(padding: const EdgeInsets.all(14), child: Text(customerName, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13))),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(rating.toStringAsFixed(1), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.amber.shade900)),
                          ],
                        ),
                      ),
                      Padding(padding: const EdgeInsets.all(14), child: Text(comment, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade800), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: IconButton(
                          icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                          tooltip: 'Delete Review',
                          onPressed: () => _deleteAdminReview(reviewId),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProfessionalStatsGrid() {
    final summary = _financialSummary ?? {};
    final realTotalRevenue = summary['totalRevenue'] ?? _totalRevenue;
    final realNetProfit = (summary['totalCustomerPlatformFees'] ?? 0.0) + (summary['totalVendorFees'] ?? 0.0);
    final deliveryFees = summary['totalDeliveryCharges'] ?? 0.0;
    final platformFees = summary['totalCustomerPlatformFees'] ?? 0.0;
    final vendorFees = summary['totalVendorFees'] ?? 0.0;
    
    return GridView.count(
      crossAxisCount: 4, mainAxisSpacing: 24, crossAxisSpacing: 24,
      childAspectRatio: 1.4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      children: [
        _proStatCard('TOTAL GROSS REVENUE', '₹${NumberFormat('#,##,###').format(realTotalRevenue)}', Icons.payments_rounded, AdminColors.primaryIndigo, 'S 12.4%'),
        _proStatCard('PLATFORM NET PROFIT', '₹${NumberFormat('#,##,###').format(realNetProfit)}', Icons.account_balance_rounded, AdminColors.success, 'STABLE'),
        _proStatCard('DELIVERY FEES', '₹${NumberFormat('#,##,###').format(deliveryFees)}', Icons.local_shipping_rounded, Colors.blue, 'Live'),
        _proStatCard('PLATFORM FEES', '₹${NumberFormat('#,##,###').format(platformFees)}', Icons.devices_rounded, Colors.purple, 'Live'),
        _proStatCard('VENDOR FEES', '₹${NumberFormat('#,##,###').format(vendorFees)}', Icons.storefront_rounded, Colors.orange, 'Live'),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 18)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Text(trend, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AdminColors.textHeading), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.outfit(fontSize: 9, color: AdminColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
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

  // ₹a REPORTS (FINANCIAL AUDIT CENTRE) ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
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
                  Text('SHOP TRANSACTION LEDGER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 24),
                  _buildPayoutTable(),
                  const SizedBox(height: 48),
                  Text('DELIVERY PARTNER EARNINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 24),
                  _buildDriverPayoutTable(),
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

  Widget _buildDriverPayoutTable() {
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
          DataColumn(label: Text('TOTAL EARNINGS')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('ACTION')),
        ],
        rows: _driverPayouts.map((p) => DataRow(cells: [
          DataCell(Text(p['driverName'] ?? 'Driver', style: const TextStyle(fontWeight: FontWeight.w900))),
          DataCell(Text(p['date'] ?? '-', style: TextStyle(color: AdminColors.textMuted))),
          DataCell(Text('₹${NumberFormat('#,###').format(p['amount'] ?? 0)}', style: const TextStyle(color: AdminColors.primaryIndigo))),
          DataCell(_payoutStatusBadge(p['status'] ?? 'Paid')),
          DataCell(
            p['status'] == 'Pending' 
            ? TextButton(
                onPressed: () => _payDriverSalary(p['driverId']),
                style: TextButton.styleFrom(backgroundColor: Colors.green.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Text('PAY', style: GoogleFonts.outfit(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            : const SizedBox.shrink()
          ),
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
    final icons = {'Grocery': '🛒', 'Bakery': '🥐', 'Medicine': '💊', 'Food': '🍔', 'Fruits & Vegetables': '🍎'};
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
      child: Column(children: cats.entries.map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(icons[e.key] ?? '&', style: const TextStyle(fontSize: 18)),
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

  // ₹a VENDORS (SPLIT PANE LAYOUT) ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
  Widget _buildVendors() {
    final search = _vendorSearch.toLowerCase();
    final filtered = _vendors.where((v) {
      if (_vendorSubTab == 0 && v['isLocked'] == true) return false;
      if (_vendorSubTab == 1 && v['isLocked'] != true) return false;
      
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
            
            // Sub-tabs for Directory vs Blocked vs Pending
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Expanded(child: _subTab('Directory', _vendorSubTab == 0, () {
                  final firstDirIdx = _vendors.indexWhere((v) => v['isLocked'] != true);
                  setState(() {
                    _vendorSubTab = 0;
                    _selectedVendorIdx = firstDirIdx;
                  });
                })),
                const SizedBox(width: 6),
                Expanded(child: _subTab('Blocked', _vendorSubTab == 1, () {
                  final firstBlockedIdx = _vendors.indexWhere((v) => v['isLocked'] == true);
                  setState(() {
                    _vendorSubTab = 1;
                    _selectedVendorIdx = firstBlockedIdx;
                  });
                })),
                const SizedBox(width: 6),
                Expanded(child: _subTab('Approvals', _vendorSubTab == 2, () {
                  setState(() {
                    _vendorSubTab = 2;
                    _selectedVendorIdx = -1;
                  });
                }, hasBadge: _pendingVendors.isNotEmpty)),
              ]),
            ),

            Container(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: _vendorSubTab == 2 
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
                        final isLocked = v['isLocked'] == true;
                        
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
                                backgroundColor: isLocked ? Colors.red.shade50 : (isActive ? AdminColors.primaryIndigo.withOpacity(0.1) : Colors.grey.shade200), 
                                foregroundColor: isLocked ? Colors.red : (isActive ? AdminColors.primaryIndigo : Colors.grey.shade600), 
                                child: Text(displayName.isNotEmpty ? displayName[0] : '?', style: const TextStyle(fontWeight: FontWeight.w900))
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(displayName, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                                Text('${v['city'] ?? 'Chennai'}  •  ${v['category'] ?? 'General'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                              ])),
                              isLocked
                                ? const Icon(Icons.lock_rounded, color: Colors.red, size: 14)
                                : Container(width: 8, height: 8, decoration: BoxDecoration(color: isActive ? Colors.green.shade500 : (status == 'pending' ? Colors.orange.shade400 : Colors.red.shade400), shape: BoxShape.circle)),
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
          child: _vendorSubTab == 2
              ? _buildPendingApprovalsPane()
              : _selectedVendorIdx < _vendors.length && _selectedVendorIdx >= 0
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

  Widget _subTab(String label, bool active, VoidCallback onTap, {bool hasBadge = false}) {
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label, 
              textAlign: TextAlign.center, 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: active ? FontWeight.w800 : FontWeight.w600, 
                color: active ? AdminColors.primaryIndigo : AdminColors.textSub
              ),
            ),
            if (hasBadge) ...[
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981), // Bright Green Badge Dot
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    if (_isPendingLoading && _pendingVendors.isEmpty) return const Center(child: CircularProgressIndicator());
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
          subtitle: Text('$category a $ownerName', style: const TextStyle(fontSize: 11)),
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
            Text('Owner: ${v['ownerName'] ?? 'Owner'}  a  Phone: ${v['phone'] ?? 'N/A'}', style: TextStyle(color: AdminColors.textSub, fontSize: 13)),
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
          _pendingInfoItem('Application Date', v['createdAt'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(v['createdAt']).toLocal().toLocal()) : 'Today', Icons.calendar_today_rounded),
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
    final completedOrders = int.tryParse(v['completedOrders']?.toString() ?? '0') ?? 0;
    final cancelledOrders = int.tryParse(v['cancelledOrders']?.toString() ?? '0') ?? 0;
    final status = v['status'] ?? v['approvalStatus'] ?? 'pending';
    final isActive = status == 'Active' || status == 'approved';
    final accentColor = isActive ? AdminColors.primaryIndigo : Colors.grey.shade500;
    final displayName = v['storeName'] ?? v['name'] ?? 'Vendor';

    final trialExpiryStr = v['trialExpiry']?.toString();
    DateTime? trialExpiry;
    bool isTrialExpired = false;
    if (trialExpiryStr != null) {
      trialExpiry = DateTime.tryParse(trialExpiryStr)?.toLocal();
      if (trialExpiry != null && trialExpiry.isBefore(DateTime.now())) {
        isTrialExpired = true;
      }
    }

    final subExpiryStr = v['subscriptionExpiry']?.toString();
    DateTime? subExpiry;
    bool isSubExpired = false;
    if (subExpiryStr != null) {
      subExpiry = DateTime.tryParse(subExpiryStr)?.toLocal();
      if (subExpiry != null && subExpiry.isBefore(DateTime.now())) {
        isSubExpired = true;
      }
    }

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
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(displayName, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 28, color: AdminColors.textHeading)),
                v['isLocked'] == true
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.lock_rounded, color: Colors.red, size: 10),
                        const SizedBox(width: 6),
                        Text('LOCKED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.red.shade700)),
                      ]),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: isActive ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: isActive ? Colors.green.shade200 : Colors.red.shade200)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: isActive ? Colors.green.shade600 : Colors.red.shade600, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isActive ? Colors.green.shade700 : Colors.red.shade700)),
                      ]),
                    ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${v['category'] ?? 'General'}  •  Joined ${v['joined'] ?? DateFormat('MMM dd, yyyy').format(DateTime.now())}', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            // Actions
            Wrap(spacing: 12, runSpacing: 8, children: [
              ElevatedButton.icon(
                onPressed: () async {
                  if (isActive) {
                    // Suspend: Lock the vendor
                    await _updateVendorAccess(
                      vendorId: v['_id'],
                      isLocked: true,
                      lockReason: 'Suspended by Admin',
                    );
                  } else {
                    // Activate: Approve the vendor
                    await _approveVendor(v['_id']);
                  }
                },
                icon: Icon(isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16),
                label: Text(isActive ? 'Suspend Operations' : 'Activate Vendor', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: isActive ? Colors.orange.shade50 : Colors.green.shade50, foregroundColor: isActive ? Colors.orange.shade700 : Colors.green.shade700, elevation: 0),
              ),
              ElevatedButton.icon(
                onPressed: () => _showVendorAccessDialog(v),
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: Text('Manage Access', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1), foregroundColor: AdminColors.primaryIndigo, elevation: 0),
              ),
              ElevatedButton.icon(
                onPressed: () => _showEditVendorDialog(v),
                icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                label: Text('Edit Details & Location', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade700, elevation: 0),
              ),
              OutlinedButton.icon(
                onPressed: () => _deleteVendor(v['_id'].toString(), v['storeName']?.toString() ?? 'Store'),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: Text('Remove Vendor', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade600, side: BorderSide(color: Colors.red.shade200)),
              ),
            ]),
          ])),
        ]),
        const SizedBox(height: 32),
        _buildVendorNotificationAlert(v, isTrialExpired, trialExpiry, isSubExpired, subExpiry),
        const SizedBox(height: 24),

        // ANALYTICS GRID
        Text('Performance Analytics', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: AdminColors.textHeading)),
        const SizedBox(height: 16),
        // Row 1: Revenue + Total Orders
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _metricCard('Total Revenue', '₹${NumberFormat('#,##,###').format(revenue)}', Icons.payments_rounded, AdminColors.primaryIndigo, '+8.4% this month')),
              const SizedBox(width: 16),
              Expanded(child: _metricCard('Total Orders', '$orders', Icons.receipt_long_rounded, const Color(0xFF059669), 'All statuses combined')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Row 2: Delivered + Cancelled
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _metricCard('Delivered', '$completedOrders', Icons.check_circle_rounded, const Color(0xFF0D9488), 'Successfully completed')),
              const SizedBox(width: 16),
              Expanded(child: _metricCard('Cancelled', '$cancelledOrders', Icons.cancel_rounded, const Color(0xFFDC2626), 'Cancelled orders')),
            ],
          ),
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
                  const SizedBox(height: 24),
                  _buildDetailCard(
                    'Commission Configuration',
                    Icons.percent_rounded,
                    [
                      _detailRow(
                        'Commission Status', 
                        (v['commissionEnabled'] ?? true) ? 'ENABLED' : 'DISABLED',
                        color: (v['commissionEnabled'] ?? true) ? Colors.green : Colors.red,
                      ),
                      if (v['commissionEnabled'] ?? true)
                        _detailRow('Commission Rate', '${((v['commissionRate'] ?? 0.05) * 100).toStringAsFixed(1)}%'),
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
                      _detailRow('City & Pincode', '${v['location']?['city'] ?? v['city'] ?? 'Chennai'} - ${v['location']?['pincode'] ?? v['pincode'] ?? 'N/A'}'),
                      _detailRow('Delivery Radius', '${v['deliveryRadiusKm'] ?? 20} KM'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailCard(
                    'Access & Subscription',
                    Icons.card_membership_rounded,
                    [
                      _detailRow(
                        'Access Status', 
                        v['isLocked'] == true 
                            ? 'RESTRICTED (LOCKED)' 
                            : (v['isOpen'] == true ? 'OPEN NOW / ACTIVE' : 'CLOSED / ACTIVE'), 
                        color: v['isLocked'] == true ? Colors.red : Colors.green,
                        isBold: true
                      ),
                      _detailRow(
                        'Trial Status',
                        trialExpiry == null
                            ? 'Not Configured'
                            : (isTrialExpired
                                ? 'EXPIRED (on ${DateFormat('dd MMM, yyyy').format(trialExpiry)})'
                                : 'ACTIVE (expires ${DateFormat('dd MMM, yyyy').format(trialExpiry)})'),
                        color: trialExpiry == null ? Colors.grey : (isTrialExpired ? Colors.red : Colors.green),
                      ),
                      _detailRow('Subscription Plan', v['subscriptionPlan'] ?? 'None'),
                      if (v['subscriptionPlan'] != null && v['subscriptionPlan'] != 'None')
                        _detailRow(
                          'Subscription Status',
                          subExpiry == null
                              ? 'Unlimited'
                              : (isSubExpired
                                  ? 'EXPIRED (on ${DateFormat('dd MMM, yyyy').format(subExpiry)})'
                                  : 'ACTIVE (valid until ${DateFormat('dd MMM, yyyy').format(subExpiry)})'),
                          color: subExpiry == null ? Colors.green : (isSubExpired ? Colors.red : Colors.green),
                        ),
                      _detailRow('Manual Bypass (Admin)', v['isManuallyUnlocked'] == true ? 'ENABLED' : 'DISABLED', color: v['isManuallyUnlocked'] == true ? Colors.green : Colors.grey),
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

  Widget _buildVendorNotificationAlert(
    Map<String, dynamic> v, 
    bool isTrialExpired, 
    DateTime? trialExpiry, 
    bool isSubExpired, 
    DateTime? subExpiry
  ) {
    final isLocked = v['isLocked'] == true;
    final isManuallyUnlocked = v['isManuallyUnlocked'] == true;

    int trialDaysLeft = -1;
    if (trialExpiry != null && !isTrialExpired) {
      trialDaysLeft = trialExpiry.difference(DateTime.now()).inDays;
    }

    int subDaysLeft = -1;
    if (subExpiry != null && !isSubExpired) {
      subDaysLeft = subExpiry.difference(DateTime.now()).inDays;
    }

    final isTrialExpiringSoon = trialExpiry != null && !isTrialExpired && trialDaysLeft >= 0 && trialDaysLeft <= 30;
    final isSubExpiringSoon = subExpiry != null && !isSubExpired && subDaysLeft >= 0 && subDaysLeft <= 30;

    if (!isLocked && !isTrialExpired && !isSubExpired && !isTrialExpiringSoon && !isSubExpiringSoon) {
      return const SizedBox.shrink();
    }

    String title = '';
    String description = '';
    Color cardColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    if (isLocked) {
      title = 'ACCOUNT OPERATIONAL LOCK';
      description = 'This vendor is currently LOCKED. Reason: ${v['lockReason'] ?? 'Suspended by Admin'}. They cannot go online or receive customer orders.';
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      textColor = Colors.red.shade900;
      icon = Icons.lock_rounded;
    } else if (isTrialExpired && (v['subscriptionPlan'] == 'None' || v['subscriptionPlan'] == null) && !isManuallyUnlocked) {
      title = 'FREE TRIAL PERIOD EXPIRED';
      description = 'Trial ended on ${trialExpiry != null ? DateFormat('dd MMM, yyyy').format(trialExpiry) : 'N/A'}. This vendor will not be allowed to go online unless they purchase a subscription plan or receive a manual bypass.';
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      textColor = Colors.red.shade900;
      icon = Icons.warning_amber_rounded;
    } else if (isSubExpired && !isManuallyUnlocked) {
      title = 'SUBSCRIPTION PLAN EXPIRED';
      description = 'Plan (${v['subscriptionPlan'] ?? 'Basic'}) expired on ${subExpiry != null ? DateFormat('dd MMM, yyyy').format(subExpiry) : 'N/A'}. This vendor is restricted from accepting orders until they renew their plan.';
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      textColor = Colors.red.shade900;
      icon = Icons.hourglass_empty_rounded;
    } else if ((isTrialExpired || isSubExpired) && isManuallyUnlocked) {
      title = 'ADMIN EXPIRED BYPASS ACTIVE';
      description = 'The trial or subscription has expired, but this vendor currently has lifetime manual access bypass enabled by Admin.';
      cardColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      textColor = Colors.blue.shade900;
      icon = Icons.check_circle_outline_rounded;
    } else if (isTrialExpiringSoon && (v['subscriptionPlan'] == 'None' || v['subscriptionPlan'] == null) && !isManuallyUnlocked) {
      title = 'FREE TRIAL EXPIRING SOON';
      description = 'Trial period will end in $trialDaysLeft days (on ${DateFormat('dd MMM, yyyy').format(trialExpiry!)}). Remind the vendor to purchase a subscription plan to prevent interruption.';
      cardColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade200;
      textColor = Colors.amber.shade900;
      icon = Icons.timelapse_rounded;
    } else if (isSubExpiringSoon && !isManuallyUnlocked) {
      title = 'SUBSCRIPTION PLAN EXPIRING SOON';
      description = 'Plan (${v['subscriptionPlan'] ?? 'Basic'}) will expire in $subDaysLeft days (on ${DateFormat('dd MMM, yyyy').format(subExpiry!)}). Remind the vendor to renew their subscription to prevent interruption.';
      cardColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade200;
      textColor = Colors.amber.shade900;
      icon = Icons.hourglass_top_rounded;
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: textColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: textColor, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: textColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: textColor.withOpacity(0.8),
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

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false, TextInputType type = TextInputType.text, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      onChanged: onChanged,
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

  // ₹a ADMINS (SPLIT PANE LAYOUT) ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
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
            Text('${a['email'] ?? 'N/A'}  •  ${a['city'] ?? 'N/A'}', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
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
            Text('& Access & Privileges', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.user['role'] == 'superadmin') ...[
                  ...['Overview', 'Vendors', 'Admins', 'Drivers', 'Verification', 'Dispatch Hub', 'Live Tracking', 'Customer Orders', 'Customers', 'Broadcasts', 'Support Hub', 'Intelligence', 'Security Audit', 'Report Center', 'Settings', 'Subscription Plans', 'Vendor Payments', 'Customer Payments', 'Order Bills', 'Financial IQ', 'Failed Payments', 'Employee Roster', 'Attendance Hub', 'Cancelled Orders'].map((label) {
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
                    ...['Overview', 'Vendors', 'Admins', 'Drivers', 'Verification', 'Dispatch Hub', 'Live Tracking', 'Customer Orders', 'Customers', 'Broadcasts', 'Support Hub', 'Intelligence', 'Security Audit', 'Report Center', 'Settings', 'Subscription Plans', 'Vendor Payments', 'Customer Payments', 'Order Bills', 'Financial IQ', 'Failed Payments', 'Employee Roster', 'Attendance Hub', 'Cancelled Orders'].map((label) {
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

  // ₹a SETTINGS (ENTERPRISE SPLIT PANE) ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
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
        _toggleTile('Cash on Delivery (COD)', 'Enable or disable Cash on Delivery payment option for all customers.', Icons.payments_rounded, const Color(0xFFD97706), _codEnabled, (v) => _updateSettings({'codEnabled': v})),
        Container(height: 1, color: Colors.grey.shade100),
        _toggleTile('Vendor Onboarding', 'Allow new vendors to register via the Vendor App.', Icons.how_to_reg_rounded, const Color(0xFF059669), _regEnabled, (v) => _updateSettings({'regEnabled': v})),
        Container(height: 1, color: Colors.grey.shade100),
        _toggleTile('System Maintenance Mode', 'Disable app access for all users except Super Admins.', Icons.build_rounded, Colors.red, _maintenanceMode, (v) => _updateSettings({'maintenanceMode': v})),
        Container(height: 1, color: Colors.grey.shade100),
        _toggleTile('Automated Dispatch', 'Automatically assign delivery partners using spatial algorithms.', Icons.auto_mode_rounded, AdminColors.primaryIndigo, _autoAssign, (v) => _updateSettings({'autoAssign': v})),
      ]),
      const SizedBox(height: 32),
      Text('Vendor Notification Sound', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
      const SizedBox(height: 8),
      Text('Select the alert ringtone that plays on the Vendor App for new order alerts.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const SizedBox(height: 16),
      _settingsGroup([
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.notifications_active_rounded, color: Colors.purple, size: 24),
          ),
          title: Text('Order Alert Ringtone', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Text('Ringtone played on Vendor App even when phone is on silent mode.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          trailing: DropdownButton<String>(
            value: _vendorAlertSound,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'new_order_alert', child: Text('🚨 Loud Siren (Default)')),
              DropdownMenuItem(value: 'bell_ring', child: Text('🔔 Classic Shop Bell')),
              DropdownMenuItem(value: 'loud_alarm', child: Text('⏰ Emergency Loud Alarm')),
              DropdownMenuItem(value: 'chime_alert', child: Text('🎵 Soft Chime')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _vendorAlertSound = val);
                _updateSettings({'vendorAlertSound': val});
              }
            },
          ),
        ),
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
        _toggleTile('Vendor Commission Status', 'Enable or disable commission on vendor sales.', Icons.percent_rounded, AdminColors.primaryIndigo, _vendorCommissionEnabled, (v) => _updateSettings({'vendorCommissionEnabled': v})),
        if (_vendorCommissionEnabled) ...[
          Container(height: 1, color: Colors.grey.shade100),
          _inputSettingTile('Platform Commission %', 'Percentage platform takes per vendor sale.', '${_commissionPct.toStringAsFixed(1)}%', Icons.percent_rounded, AdminColors.primaryIndigo, () => _editSetting(context, 'platformCommissionPct', _commissionPct.toString())),
        ],
        Container(height: 1, color: Colors.grey.shade100),
        _toggleTile('Customer Platform Fee Status', 'Enable or disable platform fee charged to customers.', Icons.receipt_long_rounded, const Color(0xFFEC4899), _customerPlatformFeeEnabled, (v) => _updateSettings({'customerPlatformFeeEnabled': v})),
        if (_customerPlatformFeeEnabled) ...[
          Container(height: 1, color: Colors.grey.shade100),
          _inputSettingTile('Customer Platform Fee Amount', 'Fixed fee charged to customer per order.', '₹${_customerPlatformFeeAmount.toStringAsFixed(0)}', Icons.payments_rounded, const Color(0xFFEC4899), () => _editSetting(context, 'customerPlatformFeeAmount', _customerPlatformFeeAmount.toString())),
        ],
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Base Delivery Charge', 'Standard fee charged to customers.', '₹30', Icons.delivery_dining_rounded, AdminColors.primaryIndigo, () => _editSetting(context, 'Delivery Charge', '30')),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Minimum Order Value', 'Orders below this face rejection or surge fees.', '₹100', Icons.shopping_bag_rounded, const Color(0xFF059669), () => _editSetting(context, 'Min Order Value', '100')),
      ]),
      const SizedBox(height: 32),
      Text('Delivery Partner Pay (Kilometer Engine)', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
      const SizedBox(height: 8),
      Text('Automated GPS distance payout model for delivery partners.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const SizedBox(height: 16),
      _settingsGroup([
        _toggleTile(
          'Include Rider Pickup Distance (Rider → Vendor)',
          'ON: Payout includes Rider → Vendor KM + Vendor → Customer KM.\nOFF: Payout includes ONLY Vendor → Customer KM.',
          Icons.add_location_alt_rounded,
          const Color(0xFF059669),
          _includeRiderPickupDistance,
          (val) {
            setState(() => _includeRiderPickupDistance = val);
            _updateSettings({'includeRiderPickupDistance': val});
          },
        ),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Base Driver Pay / KM', 'Standard rate per kilometer for delivery partners.', '₹${_driverBaseRatePerKm.toStringAsFixed(1)} / KM', Icons.directions_bike_rounded, const Color(0xFF059669), () => _editSetting(context, 'driverBaseRatePerKm', _driverBaseRatePerKm.toString(), displayName: 'Base Driver Pay / KM')),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Long Distance Threshold', 'Distance cutoff before applying bonus kilometer rate.', '${_driverLongDistanceThresholdKm.toStringAsFixed(0)} KM', Icons.add_road_rounded, const Color(0xFFD97706), () => _editSetting(context, 'driverLongDistanceThresholdKm', _driverLongDistanceThresholdKm.toString(), displayName: 'Long Distance Threshold (KM)')),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Bonus Rate (> 50 KM)', 'Extra bonus rate per km added above threshold.', '+₹${_driverLongDistanceBonusPerKm.toStringAsFixed(1)} / KM', Icons.speed_rounded, Colors.purple, () => _editSetting(context, 'driverLongDistanceBonusPerKm', _driverLongDistanceBonusPerKm.toString(), displayName: 'Bonus Rate / KM (> 50 KM)')),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Minimum Earnings / Trip', 'Minimum guaranteed payout per completed delivery.', '₹${_driverMinEarningsPerOrder.toStringAsFixed(0)}', Icons.shield_rounded, AdminColors.primaryIndigo, () => _editSetting(context, 'driverMinEarningsPerOrder', _driverMinEarningsPerOrder.toString(), displayName: 'Minimum Earnings / Trip')),
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
        _inputSettingTile('Platform Commission', 'Percentage platform takes per sale.', _vendorCommissionEnabled ? '${_commissionPct.toStringAsFixed(1)}%' : '0.0% (Disabled)', Icons.percent_rounded, AdminColors.primaryIndigo, () => _editSetting(context, 'platformCommissionPct', _commissionPct.toString())),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Max Delivery Radius', 'Absolute maximum allowable delivery distance.', '$_deliveryRadius km', Icons.radar_rounded, const Color(0xFFD97706), () => _editSetting(context, 'maxDispatchRadiusKm', _deliveryRadius.toString())),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Service Center Lat', 'Center point of service area (Latitude).', _serviceCenterLat.toStringAsFixed(4), Icons.location_on_rounded, Colors.teal, () => _editSetting(context, 'serviceCenterLat', _serviceCenterLat.toString())),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Service Center Lng', 'Center point of service area (Longitude).', _serviceCenterLng.toStringAsFixed(4), Icons.location_on_rounded, Colors.teal, () => _editSetting(context, 'serviceCenterLng', _serviceCenterLng.toString())),
        Container(height: 1, color: Colors.grey.shade100),
        _inputSettingTile('Max Service Radius', 'Restricts ALL platform orders to this radius.', '$_serviceRadius km', Icons.language_rounded, Colors.indigoAccent, () => _editSetting(context, 'maxServiceRadiusKm', _serviceRadius.toString())),
      ]),
      const SizedBox(height: 32),

      // ERODE GEOGRAPHIC DELIVERY RANGE MAP & SLIDER CARD
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AdminColors.primaryIndigo.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: AdminColors.primaryIndigo.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.radar_rounded, color: AdminColors.primaryIndigo, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ERODE DELIVERY RANGE CONTROL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading, letterSpacing: 0.5)),
                      Text('Set maximum delivery distance limit (KM) around Erode. Customers outside this radius cannot place orders.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: AdminColors.primaryIndigo, borderRadius: BorderRadius.circular(16)),
                  child: Text('$_serviceRadius KM RANGE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Map Visualizer with Tap to Move Circle Center
            SizedBox(
              height: 320,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(_serviceCenterLat, _serviceCenterLng),
                        initialZoom: 11.5,
                        maxZoom: 20.0,
                        onPositionChanged: (camera, hasGesture) {
                          if (hasGesture) {
                            setState(() {
                              _serviceCenterLat = camera.center.latitude;
                              _serviceCenterLng = camera.center.longitude;
                            });
                          }
                        },
                        onMapEvent: (event) {
                          if (event is MapEventMoveEnd) {
                            _updateSettings({
                              'serviceCenterLat': _serviceCenterLat,
                              'serviceCenterLng': _serviceCenterLng,
                            });
                          }
                        },
                        onTap: (tapPosition, point) {
                          setState(() {
                            _serviceCenterLat = point.latitude;
                            _serviceCenterLng = point.longitude;
                          });
                          _updateSettings({
                            'serviceCenterLat': point.latitude,
                            'serviceCenterLng': point.longitude,
                          });
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.pin_drop_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Service Center moved to: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            backgroundColor: AdminColors.primaryIndigo,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ));
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}',
                          subdomains: const ['0', '1', '2', '3'],
                          userAgentPackageName: 'com.namba.admin',
                          maxZoom: 20,
                          maxNativeZoom: 19,
                          errorTileCallback: (tile, error, stackTrace) {
                            debugPrint('Google Map Tile error: $error');
                          },
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: LatLng(_serviceCenterLat, _serviceCenterLng),
                              radius: _serviceRadius * 1000.0, // meters
                              useRadiusInMeter: true,
                              color: AdminColors.primaryIndigo.withOpacity(0.18),
                              borderColor: AdminColors.primaryIndigo,
                              borderStrokeWidth: 3,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_serviceCenterLat, _serviceCenterLng),
                              width: 150,
                              height: 65,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)],
                                    ),
                                    child: Text(
                                      'HUB (${_serviceRadius}KM)',
                                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 32),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Help Banner Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_rounded, color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            ' Drag map or tap anywhere to MOVE location pin & radius circle',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Reset Button
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _serviceCenterLat = 11.3410;
                          _serviceCenterLng = 77.7172;
                        });
                        _updateSettings({
                          'serviceCenterLat': 11.3410,
                          'serviceCenterLng': 77.7172,
                        });
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: Text('Reset to Erode Center', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AdminColors.textHeading,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Slider Controls
            Row(
              children: [
                Text('1 KM', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey)),
                Expanded(
                  child: Slider(
                    value: _serviceRadius.toDouble().clamp(1.0, 50.0),
                    min: 1.0,
                    max: 50.0,
                    divisions: 49,
                    activeColor: AdminColors.primaryIndigo,
                    label: '$_serviceRadius KM',
                    onChanged: (val) {
                      setState(() {
                        _serviceRadius = val.round();
                        _deliveryRadius = val.round();
                      });
                    },
                    onChangeEnd: (val) {
                      _updateSettings({
                        'maxServiceRadiusKm': val.round(),
                        'maxDispatchRadiusKm': val.round(),
                      });
                    },
                  ),
                ),
                Text('50 KM', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            // Quick Presets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [5, 10, 15, 20, 25, 30, 40, 50].map((km) {
                final isSelected = _serviceRadius == km;
                return ChoiceChip(
                  label: Text('$km KM', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AdminColors.textHeading)),
                  selected: isSelected,
                  selectedColor: AdminColors.primaryIndigo,
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _serviceRadius = km;
                        _deliveryRadius = km;
                      });
                      _updateSettings({
                        'maxServiceRadiusKm': km,
                        'maxDispatchRadiusKm': km,
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
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
                    Text('Center: ${z['lat']}, ${z['lng']} a Radius: ${z['radiusKm']}km', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
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
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AddZoneMapDialog(
        initialLat: _serviceCenterLat,
        initialLng: _serviceCenterLng,
        onZoneCreated: (name, lat, lng, radiusKm) {
          _addServiceZone({
            'name': name,
            'lat': lat,
            'lng': lng,
            'radiusKm': radiusKm,
          });
        },
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

  void _editSetting(BuildContext context, String field, String current, {String? displayName}) {
    final titleLabel = displayName ?? field;
    final ctrl = TextEditingController(text: current);
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Edit $titleLabel', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
      content: TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: titleLabel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
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

  // ₹a Helpers ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 8),
          Flexible(child: Text(trend ?? '', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis, maxLines: 1)),
        ]),
        const SizedBox(height: 12),
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
            ? '⚠️ WARNING: This will delete ALL administrator accounts. You will be logged out and LOCKED OUT of the system immediately. Are you absolutely sure?'
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

        // Immediately clear order lists for real-time feedback
        if (target == 'orders' || target == 'full' || target == 'vendors' || target == 'customers' || target == 'delivery') {
          // Legacy local sync clear removed
          setState(() {
            _customerOrders.clear();
            _customerOrderHistory.clear();
            _dispatchOrders.clear();
          });
        }
        
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

  // 🛡️ SUPPORT HUB (INCIDENT ORCHESTRATION) 🛡️🛡️🛡️🛡️🛡️🛡️🛡️🛡️🛡️🛡️🛡️🛡️🛡️🛡️
  Widget _buildSupportHub() {
    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildTabHeader('SUPPORT & INCIDENTS', 'Active Resolution Desk')),
              Padding(
                padding: const EdgeInsets.only(right: 40),
                child: IconButton(
                  onPressed: _fetchSupportTickets,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7C3AED)),
                  style: IconButton.styleFrom(backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1), padding: const EdgeInsets.all(12)),
                ),
              ),
            ],
          ),
          Expanded(
            child: (_isSupportTicketsLoading && _supportTickets.isEmpty)
              ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo))
              : _supportTickets.isEmpty
                ? Center(child: Text('No active tickets found', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 18)))
                : ListView.builder(
                    padding: const EdgeInsets.all(40),
                    itemCount: _supportTickets.length,
                    itemBuilder: (context, i) {
                      final t = _supportTickets[i];
                      final status = t['status']?.toString() ?? 'Open';
                      final color = status == 'Resolved' ? Colors.green : (status == 'Open' ? Colors.orange : AdminColors.primaryIndigo);
                      return _eliteTicketCard(t, color);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTicketTimestamp(dynamic createdAt) {
    if (createdAt == null) return 'N/A';
    try {
      final dt = DateTime.parse(createdAt.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return createdAt.toString();
    }
  }

  Widget _eliteTicketCard(Map<String, dynamic> t, Color color) {
    final ticketId = t['ticketId'] ?? 'TK-UNKNOWN';
    final userType = t['userType'] ?? 'User';
    final userName = t['userName'] ?? 'Unknown';
    final issueType = t['issueType'] ?? 'Other';
    final message = t['message'] ?? '';
    final status = (t['status'] ?? 'Open').toString().toUpperCase();
    final timeStr = _formatTicketTimestamp(t['createdAt']);

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
            Text(ticketId, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(status, style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(userType.toUpperCase(), style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(issueType, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AdminColors.textHeading)),
            const SizedBox(height: 4),
            Text('$userName • $timeStr', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontStyle: FontStyle.italic)),
            ]
          ],
        ),
        trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16)),
      ),
    );
  }

  // ₹a MARKET INTELLIGENCE (GEOGRAPHIC INSIGHTS) ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
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
              maxZoom: 22.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.namba.admin',
                maxZoom: 22,
                maxNativeZoom: 18,
                errorTileCallback: (tile, error, stackTrace) {
                  debugPrint('Google Hybrid Tile error: $error');
                },
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
              MarkerLayer(
                markers: _heatmapRiders.map<Marker>((r) => Marker(
                  point: LatLng((r['lat'] as num?)?.toDouble() ?? 0.0, (r['lng'] as num?)?.toDouble() ?? 0.0),
                  width: 70, height: 80,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.5), blurRadius: 10)],
                        ),
                        child: const Icon(Icons.delivery_dining_rounded, color: Colors.black87, size: 18),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(r['name'].toString().split(' ').first,
                          style: const TextStyle(color: Colors.black87, fontSize: 7, fontWeight: FontWeight.w900),
                          overflow: TextOverflow.ellipsis),
                      ),
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

  // ₹a SECURITY AUDIT (SYSTEM OVERSIGHT) ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
  // ₹a SUBSCRIPTION PLANS MANAGEMENT ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
  Widget _buildPlansTab() {
    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          _buildTabHeader('SUBSCRIPTION PLANS', 'Manage packages and pricing'),
          Expanded(
            child: (_isPlansLoading && _subscriptionPlans.isEmpty)
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
                            Text('Actor: ${log['user']} a ${log['time']}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
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
        _fetchCustomerOrderHistory();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vendor Payment marked as Completed!'), backgroundColor: Colors.green));
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
    final allVendorOrders = [..._customerOrders, ..._customerOrderHistory];
    final pendingPayments = allVendorOrders.where((o) {
      final s = (o['status'] ?? '').toString().toLowerCase();
      if (s == 'cancelled' || s == 'rejected') return false;
      if (o['isCustomStore'] == true) return false;

      final double totalAmount = double.tryParse(o['totalAmount']?.toString() ?? '0') ?? 0.0;
      final double deliveryFee = double.tryParse(o['deliveryCharge']?.toString() ?? o['deliveryFee']?.toString() ?? '0') ?? 0.0;
      final double platformFee = double.tryParse(o['customerPlatformFee']?.toString() ?? o['platformFee']?.toString() ?? '0') ?? 0.0;
      double vendorPayout = totalAmount > 0 ? (totalAmount - deliveryFee - platformFee) : (double.tryParse(o['subTotal']?.toString() ?? '0') ?? 0.0);
      if (vendorPayout <= 0) return false;

      final isPaid = o['paymentStatus'] == 'Completed' || 
                     o['paymentStatus'] == 'PAID' || 
                     o['customerPaid'] == true || 
                     o['vendorPaymentDetailsUploadedByDriver'] == true || 
                     s == 'delivered';
      final isNotCompleted = o['vendorPaymentStatus'] != 'Completed' && o['vendorPaymentStatus'] != 'Paid' && o['vendorPaymentStatus'] != 'Not Required';
      return isPaid && isNotCompleted;
    }).toList();
    _sortOrdersByDateDesc(pendingPayments);

    final completedPayments = allVendorOrders.where((o) {
      final s = (o['status'] ?? '').toString().toLowerCase();
      if (s == 'cancelled' || s == 'rejected') return false;
      return o['vendorPaymentStatus'] == 'Completed' || o['vendorPaymentStatus'] == 'Paid';
    }).toList();
    _sortOrdersByDateDesc(completedPayments);

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
                        Text('Vendor Payments', style: GoogleFonts.outfit(color: AdminColors.textHeading, fontWeight: FontWeight.w900, fontSize: 32)),
                      ]),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(pendingPayments.length.toString(), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.orange)),
                        Text('PENDING REQUESTS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1)),
                      ]),
                      const SizedBox(width: 24),
                      IconButton(
                        onPressed: () {
                          _fetchCustomerOrders();
                          _fetchCustomerOrderHistory();
                        },
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7C3AED)),
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
                      Tab(text: 'Pending Payouts (${pendingPayments.length})'),
                      Tab(text: 'Payment History (${completedPayments.length})'),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: TabBarView(
                children: [
                  // TAB 1: PENDING PAYOUTS
                  pendingPayments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('No Pending Vendor Payments', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey.shade600)),
                              const SizedBox(height: 8),
                              Text('All customer payments requiring vendor payout will appear here.', style: GoogleFonts.outfit(color: Colors.grey.shade500)),
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
                            final customerName = order['customer']?['name'] ?? 'Guest Customer';
                            final customerPhone = order['customer']?['phone'] ?? 'N/A';
                            
                            final double totalAmount = double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0.0;
                            final double deliveryFee = double.tryParse(order['deliveryCharge']?.toString() ?? order['deliveryFee']?.toString() ?? '0') ?? 0.0;
                            final double platformFee = double.tryParse(order['customerPlatformFee']?.toString() ?? order['platformFee']?.toString() ?? '0') ?? 0.0;
                            
                            double vendorPayout = totalAmount > 0 ? (totalAmount - deliveryFee - platformFee) : (double.tryParse(order['subTotal']?.toString() ?? '0') ?? 0.0);
                            if (vendorPayout < 0) vendorPayout = 0;
                            final amount = vendorPayout.toStringAsFixed(0);

                            final upiNumber = order['vendorUpiNumber'];
                            final qrPath = order['vendorUpiQrPath'];
                            final isNetworkQr = qrPath != null;
                            final qrUrl = isNetworkQr ? '${_baseUrl.split('/api').first}$qrPath' : null;

                            final orderDate = order['createdAt'] != null || order['updatedAt'] != null
                                ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order['createdAt'] ?? order['updatedAt']).toLocal())
                                : 'Recent';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
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
                                                Text(orderDate, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
                                                const SizedBox(width: 12),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                                  child: Text('ACTION REQUIRED', style: GoogleFonts.outfit(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900)),
                                                ),
                                              ]),
                                              const SizedBox(height: 8),
                                              Text(vendorName, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Row(children: [
                                                const Icon(Icons.person_rounded, size: 15, color: AdminColors.primaryIndigo),
                                                const SizedBox(width: 6),
                                                Text('Customer: $customerName ($customerPhone)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AdminColors.primaryIndigo)),
                                              ]),
                                              const SizedBox(height: 12),
                                              Text('Amount to Pay Vendor: ₹$amount', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green.shade700)),
                                              const SizedBox(height: 4),
                                              Text('(Total Customer Paid ₹${totalAmount.toInt()} - Delivery Fee ₹${deliveryFee.toInt()} - Platform Fee ₹${platformFee.toInt()})',
                                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                              ),
                                              const SizedBox(height: 20),
                                              
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
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI Number copied to clipboard!'), duration: Duration(seconds: 1)));
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
                                                  minimumSize: const Size(double.infinity, 54),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                ),
                                                onPressed: () => _markVendorPaid(order['_id']),
                                                child: const Text('MARK AS PAID ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                              ),
                                              const SizedBox(height: 12),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  minimumSize: const Size(double.infinity, 48),
                                                  side: const BorderSide(color: AdminColors.primaryIndigo),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                ),
                                                onPressed: () => _showOrderDetails(order),
                                                icon: const Icon(Icons.receipt_long_rounded, color: AdminColors.primaryIndigo, size: 16),
                                                label: Text('VIEW ORDER DETAILS', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 11)),
                                              ),
                                              const SizedBox(height: 12),
                                              Text('Once marked as paid, the delivery partner will be notified to proceed with picking up the items.',
                                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11), textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                  // TAB 2: COMPLETED PAYMENT HISTORY
                  completedPayments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('No Vendor Payment History Yet', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey.shade600)),
                              const SizedBox(height: 8),
                              Text('Completed vendor payments will be archived here.', style: GoogleFonts.outfit(color: Colors.grey.shade500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(40),
                          itemCount: completedPayments.length,
                          itemBuilder: (context, index) {
                            final order = completedPayments[index];
                            final displayId = order['displayId'] ?? order['_id']?.substring(0, 6) ?? '';
                            final vendorName = order['vendor']?['storeName'] ?? order['customStoreName'] ?? 'Vendor';
                            final customerName = order['customer']?['name'] ?? 'Guest Customer';
                            final customerPhone = order['customer']?['phone'] ?? 'N/A';
                            
                            final double totalAmount = double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0.0;
                            final double deliveryFee = double.tryParse(order['deliveryCharge']?.toString() ?? order['deliveryFee']?.toString() ?? '0') ?? 0.0;
                            final double platformFee = double.tryParse(order['customerPlatformFee']?.toString() ?? order['platformFee']?.toString() ?? '0') ?? 0.0;
                            
                            double vendorPayout = totalAmount > 0 ? (totalAmount - deliveryFee - platformFee) : (double.tryParse(order['subTotal']?.toString() ?? '0') ?? 0.0);
                            if (vendorPayout < 0) vendorPayout = 0;
                            final amount = vendorPayout.toStringAsFixed(0);

                            final paidAt = order['vendorPaidAt'] != null || order['updatedAt'] != null
                                ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order['vendorPaidAt'] ?? order['updatedAt']).toLocal())
                                : 'Paid Recently';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.grey.shade200),
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
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                                          child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text('ORDER #$displayId', style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                                                  const SizedBox(width: 12),
                                                  Text(paidAt, style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w600)),
                                                  const Spacer(),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                                                    child: Text('PAID ', style: GoogleFonts.outfit(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w900)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(vendorName, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Row(children: [
                                                const Icon(Icons.person_rounded, size: 15, color: AdminColors.primaryIndigo),
                                                const SizedBox(width: 6),
                                                Text('Customer: $customerName ($customerPhone)', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AdminColors.primaryIndigo)),
                                              ]),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Text('Paid to Vendor: ₹$amount', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green.shade700)),
                                                  const SizedBox(width: 12),
                                                  Text('(Total ₹${totalAmount.toInt()} - Delivery ₹${deliveryFee.toInt()} - Platform ₹${platformFee.toInt()})',
                                                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        OutlinedButton.icon(
                                          onPressed: () => _showOrderDetails(order),
                                          icon: const Icon(Icons.receipt_long_rounded, size: 16),
                                          label: const Text('ORDER DETAILS'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AdminColors.primaryIndigo,
                                            side: const BorderSide(color: AdminColors.primaryIndigo),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
    );
  }

  Widget _buildCustomerPaymentsTab() {
    // Combine current and history orders that are paid
    final allPaid = [
      ..._customerOrders.where((o) => o['paymentStatus'] == 'Completed' || o['customerPaid'] == true),
      ..._customerOrderHistory.where((o) => o['paymentStatus'] == 'Completed' || o['customerPaid'] == true),
    ];
    _sortOrdersByDateDesc(allPaid);

    // Filter into two categories
    final vendorPayments = allPaid.where((o) => o['isCustomStore'] != true).toList();
    final anyShopPayments = allPaid.where((o) => o['isCustomStore'] == true).toList();
    _sortOrdersByDateDesc(vendorPayments);
    _sortOrdersByDateDesc(anyShopPayments);

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
            ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order['updatedAt']).toLocal().toLocal())
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
                              Text('a', style: TextStyle(color: Colors.grey.shade300)),
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

  // ₹a ORDER BILLS HUB ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
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
    final isLocal = rawPath.contains(':\\');
    final billUrl = (rawPath.startsWith('http') || isLocal) ? rawPath : '${_baseUrl.split('/api').first}${rawPath.startsWith('/') ? '' : '/'}$rawPath';
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
                'Pinch to Zoom a Drag to Pan',
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

  // ₹a FINANCIAL INTELLIGENCE METHODS ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
  Future<void> _fetchFinancialStats({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isFinancialLoading = true);
    try {
      String query = '?filter=$_selectedDateFilter';
      if (_selectedDateRange != null) {
        final startStr = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
        final endStr = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);
        query = '?startDate=$startStr&endDate=$endStr';
      }
      final res = await http.get(Uri.parse('$_baseUrl/admin/financial-analytics$query'), headers: _headers);
      final data = jsonDecode(res.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _financialSummary = data['data']['summary'];
          _financialTrends = data['data']['trends'] ?? [];
          _dateWiseBreakdown = data['data']['dateWiseBreakdown'] ?? [];
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
        final d = data['data'];
        setState(() {
          _topVendors = List<Map<String, dynamic>>.from(d['topVendors'] ?? []);
          _fullVendorPerformance = List<Map<String, dynamic>>.from(d['fullVendorPerformance'] ?? []);
          _topByOrdersVendor = d['topByOrders'] != null ? Map<String, dynamic>.from(d['topByOrders']) : null;
          _topByIncomeVendor = d['topByIncome'] != null ? Map<String, dynamic>.from(d['topByIncome']) : null;
          _lowestIncomeVendor = d['lowestIncome'] != null ? Map<String, dynamic>.from(d['lowestIncome']) : null;
          _driverPerformance = List<Map<String, dynamic>>.from(d['driverPerformance'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error fetching performance stats: $e');
    } finally {
      if (mounted && !silent) setState(() => _isPerformanceLoading = false);
    }
  }

bool _isFailedPaymentsLoading = false;
  List<dynamic> _failedPayments = [];

  Future<void> _fetchFailedPayments() async {
    setState(() => _isFailedPaymentsLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/orders/failed-payments'), headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _failedPayments = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching failed payments: $e');
    } finally {
      if (mounted) setState(() => _isFailedPaymentsLoading = false);
    }
  }

  Widget _buildFailedPayments() {
    return _BaseTabContainer(
      title: 'Failed Payments',
      icon: Icons.money_off_rounded,
      onRefresh: _fetchFailedPayments,
      child: _isFailedPaymentsLoading
          ? const Center(child: CircularProgressIndicator())
          : _failedPayments.isEmpty
              ? const Center(child: Text('No failed payments found.', style: TextStyle(fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _failedPayments.length,
                  itemBuilder: (context, index) {
                    final order = _failedPayments[index];
                    final customerName = order['customer'] != null ? order['customer']['name'] : 'Unknown';
                    final vendorName = order['vendor'] != null ? order['vendor']['storeName'] : 'Unknown';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.error_outline_rounded, color: Colors.red),
                        ),
                        title: Text('Order: ${order['displayId'] ?? order['_id']} - ₹${order['totalAmount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Customer: $customerName\nVendor: $vendorName', style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(order['paymentMethod'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(order['createdAt'] != null ? order['createdAt'].toString().substring(0, 10) : '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _BaseTabContainer({
    required String title,
    required IconData icon,
    required VoidCallback onRefresh,
    required Widget child,
  }) {
    return Container(
      color: AdminColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(40, 48, 40, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminColors.primaryIndigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AdminColors.primaryIndigo, size: 28),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(), style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text(title, style: GoogleFonts.outfit(color: AdminColors.textHeading, fontWeight: FontWeight.w900, fontSize: 32)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, color: AdminColors.primaryIndigo),
                  style: IconButton.styleFrom(backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1), padding: const EdgeInsets.all(12)),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildCustomersTab() {
    return _BaseTabContainer(
      title: 'Customers',
      icon: Icons.people_rounded,
      onRefresh: _fetchAllCustomers,
      child: _isCustomersLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCustomersContent(),
    );
  }

  Widget _buildCustomersContent() {
    final filteredCustomers = _customers.where((c) {
      final name = (c['name'] as String? ?? '').toLowerCase();
      final phone = (c['phone'] as String? ?? '').toLowerCase();
      final email = (c['email'] as String? ?? '').toLowerCase();
      final search = _customerSearch.toLowerCase();
      return name.contains(search) || phone.contains(search) || email.contains(search);
    }).toList();

    final double totalSpend = _customers.fold<double>(0.0, (sum, c) => sum + (c['totalSpend'] as num? ?? 0.0).toDouble());
    final int totalOrders = _customers.fold<int>(0, (sum, c) => sum + (c['totalOrders'] as int? ?? 0));

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _customerStatCard(
                  'TOTAL CUSTOMERS',
                  _customers.length.toString(),
                  Icons.people_outline_rounded,
                  AdminColors.primaryIndigo,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _customerStatCard(
                  'TOTAL ORDERS',
                  totalOrders.toString(),
                  Icons.shopping_bag_outlined,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _customerStatCard(
                  'TOTAL SPEND',
                  '₹' + NumberFormat.currency(symbol: '', decimalDigits: 0, locale: 'en_IN').format(totalSpend),
                  Icons.payments_outlined,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _customerSearch = val),
                    decoration: InputDecoration(
                      hintText: 'Search customers by name, phone or email...',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: GoogleFonts.outfit(fontSize: 14, color: AdminColors.textHeading),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade100),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    color: AdminColors.background,
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text('CUSTOMER', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
                        Expanded(flex: 2, child: Text('JOINED DATE', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
                        Expanded(flex: 1, child: Text('ORDERS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
                        Expanded(flex: 1, child: Text('SPEND', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
                        Expanded(flex: 2, child: Text('LAST ORDER', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: filteredCustomers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Text('No customers match your search criteria.', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredCustomers.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            itemBuilder: (context, i) {
                              final c = filteredCustomers[i];
                              final joinedDate = c['createdAt'] != null
                                  ? DateTime.parse(c['createdAt'].toString())
                                  : DateTime.now();
                              final formattedJoined = DateFormat('MMM dd, yyyy').format(joinedDate);
                              final lastOrderDateStr = c['lastOrderDate']?.toString();
                              final formattedLastOrder = lastOrderDateStr != null
                                  ? DateFormat('MMM dd, yyyy').format(DateTime.parse(lastOrderDateStr))
                                  : 'Never';

                              return InkWell(
                                onTap: () => _showCustomerProfile(c),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1),
                                              child: Text(
                                                (c['name'] as String? ?? 'C').substring(0, 1).toUpperCase(),
                                                style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(c['name'] ?? 'N/A', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: AdminColors.textHeading)),
                                                  const SizedBox(height: 2),
                                                  Text(c['phone'] ?? 'N/A', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(flex: 2, child: Text(formattedJoined, style: GoogleFonts.outfit(fontSize: 13, color: AdminColors.textHeading))),
                                      Expanded(flex: 1, child: Text(c['totalOrders']?.toString() ?? '0', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo))),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '₹' + (c['totalSpend'] as num? ?? 0).toStringAsFixed(0),
                                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF059669)),
                                        ),
                                      ),
                                      Expanded(flex: 2, child: Text(formattedLastOrder, style: GoogleFonts.outfit(fontSize: 13, color: AdminColors.textHeading))),
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
          ),
        ],
      ),
    );
  }

  Widget _customerStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: AdminStyles.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(color: Colors.grey.shade500, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.outfit(color: AdminColors.textHeading, fontWeight: FontWeight.w900, fontSize: 22)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerProfile(Map<String, dynamic> customer) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        final joinedDate = customer['createdAt'] != null
            ? DateTime.parse(customer['createdAt'].toString())
            : DateTime.now();
        final formattedJoined = DateFormat('MMM dd, yyyy').format(joinedDate);
        final name = customer['name'] ?? 'Unknown Customer';
        final phone = customer['phone'] ?? 'N/A';
        final email = customer['email'] ?? 'N/A';
        final city = customer['city'] ?? 'Chennai';

        final customerActiveOrders = _customerOrders.where((order) {
          final orderCust = order['customer'];
          if (orderCust != null) {
            if (orderCust is Map && orderCust['_id'] == customer['_id']) return true;
            if (orderCust == customer['_id']) return true;
          }
          return order['customerPhone'] == phone;
        }).toList();

        final customerPastOrders = _customerOrderHistory.where((order) {
          final orderCust = order['customer'];
          if (orderCust != null) {
            if (orderCust is Map && orderCust['_id'] == customer['_id']) return true;
            if (orderCust == customer['_id']) return true;
          }
          return order['customerPhone'] == phone;
        }).toList();

        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.55,
            height: MediaQuery.of(context).size.height * 0.8,
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
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AdminColors.primaryIndigo.withOpacity(0.1),
                          child: Text(
                            name.substring(0, 1).toUpperCase(),
                            style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 32),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CUSTOMER', 
                                style: GoogleFonts.outfit(color: AdminColors.primaryIndigo, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                              const SizedBox(height: 8),
                              Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 28, color: AdminColors.textHeading)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone_rounded, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 8),
                                  Text(phone, style: GoogleFonts.outfit(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 24),
                                  Icon(Icons.email_rounded, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 8),
                                  Text(email, style: GoogleFonts.outfit(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
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
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _customerStatCard(
                                  'TOTAL SPEND',
                                  '₹' + (customer['totalSpend'] as num? ?? 0).toStringAsFixed(0),
                                  Icons.payments_rounded,
                                  const Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _customerStatCard(
                                  'DELIVERED ORDERS',
                                  '${customer['deliveredOrders'] ?? 0} / ${customer['totalOrders'] ?? 0}',
                                  Icons.shopping_bag_rounded,
                                  AdminColors.primaryIndigo,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _customerStatCard(
                                  'ACTIVE ORDERS',
                                  (customer['activeOrders'] ?? 0).toString(),
                                  Icons.hourglass_bottom_rounded,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _customerStatCard(
                                  'JOINED DATE',
                                  formattedJoined,
                                  Icons.calendar_month_rounded,
                                  Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Text('CUSTOMER DETAILS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey.shade500, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Column(
                              children: [
                                _customerDetailRow('City / Location', city, Icons.location_on_rounded),
                                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                                _customerDetailRow('User Role', 'Customer', Icons.person_rounded),
                                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                                _customerDetailRow('Account Status', (customer['isActive'] != false) ? 'Active' : 'Disabled', Icons.verified_user_rounded, color: (customer['isActive'] != false) ? Colors.green : Colors.red),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (customerActiveOrders.isNotEmpty) ...[
                            Text('ACTIVE ORDERS (${customerActiveOrders.length})', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey.shade500, letterSpacing: 1)),
                            const SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: customerActiveOrders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, idx) {
                                final order = customerActiveOrders[idx];
                                return _buildCustomerOrderHistoryTile(order);
                              },
                            ),
                            const SizedBox(height: 32),
                          ],
                          Text('RECENT ORDER HISTORY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey.shade500, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          customerPastOrders.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey.shade100),
                                  ),
                                  child: Center(
                                    child: Text('No previous order history found.', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14)),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: customerPastOrders.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, idx) {
                                    final order = customerPastOrders[idx];
                                    return _buildCustomerOrderHistoryTile(order);
                                  },
                                ),
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

  Widget _customerDetailRow(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AdminColors.primaryIndigo),
        const SizedBox(width: 16),
        Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: color ?? AdminColors.textHeading)),
      ],
    );
  }

  Widget _buildCustomerOrderHistoryTile(Map<String, dynamic> order) {
    final status = order['status'] ?? 'Pending';
    final totalAmount = order['totalAmount'] ?? 0;
    final displayId = order['displayId'] ?? order['_id']?.toString().substring(0, 8) ?? 'N/A';
    final vendorName = order['vendor'] != null ? order['vendor']['storeName'] ?? 'Unknown' : 'Unknown';
    final itemsCount = (order['items'] as List?)?.length ?? 0;
    
    Color statusColor;
    switch (status) {
      case 'Delivered':
        statusColor = Colors.green;
        break;
      case 'Cancelled':
        statusColor = Colors.red;
        break;
      case 'OutForDelivery':
      case 'PickedUp':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = AdminColors.primaryIndigo;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Order #$displayId', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: AdminColors.textHeading)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(status.toUpperCase(), style: GoogleFonts.outfit(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Vendor: $vendorName  a  $itemsCount item${itemsCount == 1 ? "" : "s"}', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Text('₹$totalAmount', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () => _showOrderDetails(order),
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            style: IconButton.styleFrom(backgroundColor: AdminColors.background, padding: const EdgeInsets.all(8)),
          ),
        ],
      ),
    );
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
        ...recentOrders.take(10).map((rawOrder) {
          final Map<String, dynamic> order = Map<String, dynamic>.from(rawOrder as Map);
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

// ₹a ISOLATED BILLS HUB VIEW ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
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
    final isLocal = billPath.contains(':\\');
    final billUrl = (billPath.startsWith('http') || isLocal) ? billPath : '${baseUrl.split('/api').first}${billPath.startsWith('/') ? '' : '/'}$billPath';
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

class _MapLabel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool isPulsing;

  const _MapLabel({
    required this.label,
    required this.color,
    required this.icon,
    this.isPulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)],
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ],
    );
  }
}

// 
// FULL-SCREEN ORDER DETAIL  a  Premium Redesign
// 
class _FullScreenOrderDetail extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAssignDriver;
  final VoidCallback onUnassignDriver;
  final VoidCallback onCancelOrder;
  final VoidCallback onTrackLive;
  final void Function(String, String) onShowImagePreview;
  final VoidCallback onPayVendor;
  final VoidCallback? onOpenPayoutHub;

  const _FullScreenOrderDetail({
    required this.order,
    required this.onAssignDriver,
    required this.onUnassignDriver,
    required this.onCancelOrder,
    required this.onTrackLive,
    required this.onShowImagePreview,
    required this.onPayVendor,
    this.onOpenPayoutHub,
  });

  @override
  Widget build(BuildContext context) {
    final driver   = order['driver'];
    final isAssigned = driver != null;
    final status   = order['status']?.toString() ?? 'Pending';
    final items    = (order['items'] as List?) ?? [];
    final vendorName    = order['vendor']?['storeName'] ?? 'Vendor';
    final customerName  = order['customer']?['name'] ?? 'Customer';
    final customerPhone = order['customer']?['phone'] ?? 'N/A';
    final orderType     = order['orderType']?.toString() ?? 'Cart';
    final totalAmount   = (order['totalAmount'] as num?)?.toDouble() ?? 0;
    final deliveryCharge = (order['deliveryCharge'] as num?)?.toDouble() ?? 0;
    final platformFee   = (order['customerPlatformFee'] as num?)?.toDouble() ?? 5.0;
    double fullItemsSum = 0.0;
    if (items.isNotEmpty) {
      for (var it in items) {
        if (it is Map) {
          double p = ((it['price'] ?? 0) as num).toDouble();
          int q = ((it['quantity'] ?? 1) as num).toInt();
          fullItemsSum += (p * q);
        }
      }
    }
    final subTotal = fullItemsSum > 0 ? fullItemsSum : ((order['subTotal'] as num?)?.toDouble() ?? (totalAmount > 0 ? (totalAmount - deliveryCharge - platformFee) : 0.0));
    final discount      = (order['discount'] as num?)?.toDouble() ?? 0;
    final paymentMethod = order['paymentMethod']?.toString() ?? '';
    final displayId     = order['displayId'] ?? 'N/A';

    final normStatus = status.toLowerCase();

    // Status colors / labels
    Color statusColor; String statusLabel; IconData statusIcon;
    switch (normStatus) {
      case 'accepted':
      case 'confirmed':
      case 'assigned':
        statusColor = const Color(0xFF3B82F6); statusLabel = 'ORDER ACCEPTED'; statusIcon = Icons.restaurant_rounded; break;
      case 'preparing':
        statusColor = const Color(0xFF6366F1); statusLabel = 'PREPARING'; statusIcon = Icons.shopping_bag_rounded; break;
      case 'ready':
      case 'handedover':
        statusColor = const Color(0xFF10B981); statusLabel = 'READY FOR PICKUP'; statusIcon = Icons.check_circle_rounded; break;
      case 'pickedup':
      case 'outfordelivery':
      case 'on the way':
        statusColor = const Color(0xFF0EA5E9); statusLabel = 'OUT FOR DELIVERY'; statusIcon = Icons.local_shipping_rounded; break;
      case 'delivered':
        statusColor = const Color(0xFF22C55E); statusLabel = 'DELIVERED'; statusIcon = Icons.verified_rounded; break;
      case 'cancelled':
      case 'rejected':
        statusColor = const Color(0xFFEF4444); statusLabel = 'CANCELLED'; statusIcon = Icons.cancel_rounded; break;
      default:
        statusColor = const Color(0xFFF59E0B); statusLabel = 'AWAITING'; statusIcon = Icons.inbox_rounded;
    }

    final isTextOrPhoto = orderType == 'Text' || orderType == 'Photo';
    final isBillUploaded = order['billPhotoPath'] != null && order['billPhotoPath'].toString().isNotEmpty;

    final List<String> pastPending = ['accepted', 'confirmed', 'assigned', 'preparing', 'ready', 'handedover', 'pickedup', 'outfordelivery', 'on the way', 'delivered'];
    final List<String> pastAccepted = ['preparing', 'ready', 'handedover', 'pickedup', 'outfordelivery', 'on the way', 'delivered'];
    final List<String> pastPreparing = ['ready', 'handedover', 'pickedup', 'outfordelivery', 'on the way', 'delivered'];
    final List<String> pastReady = ['pickedup', 'outfordelivery', 'on the way', 'delivered'];
    final List<String> pastPickedUp = ['pickedup', 'outfordelivery', 'on the way', 'delivered'];

    final isPendingDone = pastPending.contains(normStatus);
    final isPendingActive = normStatus == 'pending' || normStatus == 'paymentpending';

    final isAcceptedDone = pastAccepted.contains(normStatus);
    final isAcceptedActive = normStatus == 'accepted' || normStatus == 'confirmed' || normStatus == 'assigned';

    final isPreparingDone = pastPreparing.contains(normStatus);
    final isPreparingActive = normStatus == 'preparing';

    final isReadyDone = pastReady.contains(normStatus);
    final isReadyActive = normStatus == 'ready' || normStatus == 'handedover';

    final isPickedUpDone = pastPickedUp.contains(normStatus);
    final isPickedUpActive = normStatus == 'pickedup' || normStatus == 'outfordelivery' || normStatus == 'on the way';

    final isBillUploadDone = isBillUploaded;
    final isBillUploadActive = isPickedUpActive && !isBillUploaded;

    final isDeliveredDone = status == 'Delivered';
    final isDeliveredActive = status == 'Delivered';

    final List<Map<String, dynamic>> stepsData = [
      {
        'name': 'Pending',
        'icon': Icons.inbox_rounded,
        'isDone': isPendingDone,
        'isActive': isPendingActive,
      },
      {
        'name': 'Accepted',
        'icon': Icons.restaurant_rounded,
        'isDone': isAcceptedDone,
        'isActive': isAcceptedActive,
      },
      {
        'name': 'Preparing',
        'icon': Icons.shopping_bag_rounded,
        'isDone': isPreparingDone,
        'isActive': isPreparingActive,
      },
      {
        'name': 'Ready',
        'icon': Icons.check_circle_outline_rounded,
        'isDone': isReadyDone,
        'isActive': isReadyActive,
      },
      {
        'name': 'PickedUp',
        'icon': Icons.two_wheeler_rounded,
        'isDone': isPickedUpDone,
        'isActive': isPickedUpActive,
      },
      if (isTextOrPhoto)
        {
          'name': 'BillUpload',
          'icon': Icons.receipt_long_rounded,
          'isDone': isBillUploadDone,
          'isActive': isBillUploadActive,
        },
      {
        'name': 'Delivered',
        'icon': Icons.verified_rounded,
        'isDone': isDeliveredDone,
        'isActive': isDeliveredActive,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: const Color(0xFF0F172A),
        child: Column(
          children: [
            // ₹a TOP HEADER BAR ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
            Container(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0F172A), statusColor.withOpacity(0.9)],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
                border: const Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  // Back button
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Order ID
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ORDER DETAILS', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
                      const SizedBox(height: 3),
                      Text('#$displayId', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    ],
                  ),
                  const Spacer(),
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white30),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Text(statusLabel.toUpperCase(), style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Customer info chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_rounded, color: Colors.white70, size: 18),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(customerName, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                            Text(customerPhone, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Close
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // ₹a PROGRESS TIMELINE ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Row(
                children: stepsData.asMap().entries.map((e) {
                  final idx = e.key;
                  final step = e.value;
                  final stepName = step['name'] as String;
                  final stepIcon = step['icon'] as IconData;
                  final isDone = step['isDone'] as bool;
                  final isActive = step['isActive'] as bool;
                  final isLast = idx == stepsData.length - 1;
                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: isDone
                                    ? const Color(0xFF10B981)
                                    : isActive
                                      ? statusColor
                                      : Colors.white.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isActive ? Colors.white : (isDone ? const Color(0xFF10B981) : Colors.white12),
                                    width: isActive ? 2.5 : 1,
                                  ),
                                  boxShadow: isDone
                                    ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]
                                    : isActive
                                      ? [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                                      : [],
                                ),
                                child: Icon(isDone ? Icons.check_rounded : stepIcon,
                                  color: (isDone || isActive) ? Colors.white : Colors.white38,
                                  size: 20),
                              ),
                              const SizedBox(height: 8),
                              Text(stepName == 'Accepted' ? 'ORDER\nACCEPTED' : stepName.replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), '\n').toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: isActive ? Colors.white : (isDone ? const Color(0xFF10B981) : Colors.white38),
                                  fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                                textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: isDone ? const Color(0xFF10B981) : Colors.white12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // ₹a BODY: 3-COLUMN LAYOUT ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
            Expanded(
              child: Container(
                color: const Color(0xFFF1F5F9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ₹a LEFT COLUMN: Order Items ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fsHeader('ORDER ITEMS', '${items.length} item${items.length == 1 ? '' : 's'}', Icons.shopping_basket_rounded, AdminColors.primaryIndigo),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.all(24),
                                children: [
                                  Builder(builder: (_) {
                                    final String? photoPath = order['photoUrl'] ?? order['customItemsPhoto'];
                                    final bool hasPhoto = (photoPath != null && photoPath.toString().trim().isNotEmpty);
                                    final bool hasText = (order['textContent'] != null && order['textContent'].toString().trim().isNotEmpty);

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (hasText) ...[
                                          _textOrderBox(order['textContent'].toString()),
                                          const SizedBox(height: 16),
                                        ],
                                        if (hasPhoto) ...[
                                          _photoOrderBox(photoPath.toString()),
                                          const SizedBox(height: 16),
                                        ],
                                        if (items.isNotEmpty)
                                          ...items.asMap().entries.map((e) => _fsItemRow(e.key + 1, e.value))
                                        else if (!hasPhoto && !hasText)
                                          Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(32),
                                              child: Text('No items listed', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                                            ),
                                          ),
                                      ],
                                    );
                                  }),

                                  const SizedBox(height: 24),
                                  // Bill summary
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      children: [
                                        _fsPriceRow('Subtotal (Vendor Price)', '₹${subTotal.toStringAsFixed(2)}'),
                                        if (discount > 0) ...[
                                          const SizedBox(height: 8),
                                          _fsPriceRow('Discount', '-₹${discount.toStringAsFixed(2)}', color: Colors.green),
                                        ],
                                        const SizedBox(height: 8),
                                        _fsPriceRow('Delivery Charge', '₹${deliveryCharge.toStringAsFixed(2)}'),
                                        const SizedBox(height: 8),
                                        _fsPriceRow('Platform Fee', '₹${platformFee.toStringAsFixed(2)}'),
                                        const Divider(height: 24),
                                        const SizedBox(height: 12),
                                        Builder(builder: (context) {
                                          final isPaid = (order['paymentStatus']?.toString().toUpperCase() == 'COMPLETED') ||
                                                         (order['paymentStatus']?.toString().toUpperCase() == 'PAID') ||
                                                         (order['customerPaid'] == true);
                                          final isCod = paymentMethod.toUpperCase() == 'COD';

                                          String badgeLabel;
                                          Color badgeBg;
                                          Color badgeBorder;
                                          Color badgeFg;
                                          IconData badgeIcon;

                                          if (isCod) {
                                            badgeLabel = 'CASH ON DELIVERY (COD)';
                                            badgeBg = Colors.orange.shade50;
                                            badgeBorder = Colors.orange.shade200;
                                            badgeFg = Colors.orange.shade800;
                                            badgeIcon = Icons.money_rounded;
                                          } else if (!isPaid) {
                                            badgeLabel = 'CUSTOMER PAYMENT PENDING';
                                            badgeBg = Colors.amber.shade50;
                                            badgeBorder = Colors.amber.shade300;
                                            badgeFg = Colors.amber.shade900;
                                            badgeIcon = Icons.hourglass_top_rounded;
                                          } else {
                                            badgeLabel = paymentMethod.isNotEmpty ? paymentMethod.toUpperCase() : 'PAID (ONLINE)';
                                            badgeBg = Colors.green.shade50;
                                            badgeBorder = Colors.green.shade200;
                                            badgeFg = Colors.green.shade800;
                                            badgeIcon = Icons.check_circle_rounded;
                                          }

                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: badgeBg,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: badgeBorder),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(badgeIcon, size: 14, color: badgeFg),
                                                const SizedBox(width: 8),
                                                Text(badgeLabel, style: GoogleFonts.outfit(
                                                  color: badgeFg,
                                                  fontWeight: FontWeight.w900, fontSize: 12)),
                                              ],
                                            ),
                                          );
                                        }),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('TOTAL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
                                            Text('₹${totalAmount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: AdminColors.primaryIndigo)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),

                    // ₹a MIDDLE COLUMN: Vendor + Store ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹aa
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fsHeader('VENDOR STATUS', vendorName, Icons.storefront_rounded, const Color(0xFF3B82F6)),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.all(24),
                                children: [
                                  // Big status card
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [statusColor.withOpacity(0.08), statusColor.withOpacity(0.02)],
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                                          child: Icon(statusIcon, color: statusColor, size: 28),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('CURRENT STATUS', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                              const SizedBox(height: 4),
                                              Text(_vendorStatusLabel(status), style: GoogleFonts.outfit(color: statusColor, fontWeight: FontWeight.w900, fontSize: 15)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _fsInfoRow(Icons.store_rounded, 'Store', vendorName, Colors.blue.shade700),
                                  const SizedBox(height: 12),
                                  _fsInfoRow(Icons.category_rounded, 'Category', order['vendor']?['category'] ?? 'N/A', Colors.purple.shade600),
                                  const SizedBox(height: 12),
                                  _fsInfoRow(Icons.location_on_rounded, 'Address', order['vendor']?['address'] ?? 'N/A', Colors.red.shade600),
                                  const SizedBox(height: 24),
                                  // Order time
                                  if (order['createdAt'] != null)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 18, color: AdminColors.primaryIndigo),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('ORDER TIME', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                              Text(DateFormat('hh:mm a, dd MMM yyyy').format(DateTime.parse(order['createdAt']).toLocal().toLocal()),
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: AdminColors.textHeading)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 24),
                                  // VENDOR PAYOUT & SETTLEMENT CARD
                                  Builder(builder: (context) {
                                     final isVendorPaid = (order['vendorPaymentStatus']?.toString().toUpperCase() == 'PAID') ||
                                                          (order['vendorPaymentStatus']?.toString().toUpperCase() == 'COMPLETED') ||
                                                          (order['vendorPaid'] == true);

                                    final double sub = (order['subTotal'] as num?)?.toDouble() ?? 
                                                       ((items as List).fold(0.0, (sum, it) => sum + (((it['price'] ?? 0) as num).toDouble() * ((it['quantity'] ?? 1) as num).toInt())));
                                    final double vFee = (order['vendorFee'] as num?)?.toDouble() ?? (order['platformFee'] as num?)?.toDouble() ?? 0.0;
                                    final double disc = (order['discount'] as num?)?.toDouble() ?? 0.0;
                                     final double netPayout = (sub - disc > 0) ? (sub - disc) : ((order['vendorEarnings'] as num?)?.toDouble() ?? 0.0);

                                    return Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: isVendorPaid ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isVendorPaid ? const Color(0xFF86EFAC) : const Color(0xFFBFDBFE),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isVendorPaid ? Colors.green : Colors.blue).withOpacity(0.06),
                                            blurRadius: 16,
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
                                              Row(children: [
                                                Icon(
                                                  isVendorPaid ? Icons.verified_rounded : Icons.account_balance_wallet_rounded,
                                                  color: isVendorPaid ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'NET VENDOR PAYOUT',
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 12,
                                                    color: isVendorPaid ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ]),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isVendorPaid ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  isVendorPaid ? 'PAID / DONE' : 'PENDING',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: isVendorPaid ? const Color(0xFF15803D) : const Color(0xFF1E40AF),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            '₹' + netPayout.toStringAsFixed(0),
                                            style: GoogleFonts.outfit(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: isVendorPaid ? const Color(0xFF15803D) : const Color(0xFF1E3A8A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Builder(builder: (_) {
                                            final double disc = (order['discount'] as num?)?.toDouble() ?? 0.0;
                                            final double effectivePrice = (sub - disc) > 0 ? (sub - disc) : sub;
                                            return Text(
                                              disc > 0
                                                ? '(Subtotal ₹' + sub.toStringAsFixed(0) + ' - Discount ₹' + disc.toStringAsFixed(0) + ' = Price ₹' + effectivePrice.toStringAsFixed(0) + ' | Commission ₹' + vFee.toStringAsFixed(0) + ')'
                                                : '(Subtotal ₹' + sub.toStringAsFixed(0) + ' - Platform Commission ₹' + vFee.toStringAsFixed(0) + ')',
                                              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                            );
                                          }),
                                          const SizedBox(height: 16),
                                          if (isVendorPaid)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF15803D),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'VENDOR PAYMENT SETTLED',
                                                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else ...[
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: onPayVendor,
                                                icon: const Icon(Icons.payments_rounded, size: 18),
                                                label: Text(
                                                  'MARK VENDOR PAID (₹' + netPayout.toStringAsFixed(0) + ')',
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF10B981),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  elevation: 2,
                                                ),
                                              ),
                                            ),
                                            if (onOpenPayoutHub != null) ...[
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton.icon(
                                                  onPressed: onOpenPayoutHub,
                                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                                  label: Text(
                                                    'GO TO VENDOR PAYOUT HUB',
                                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: const Color(0xFF2563EB),
                                                    side: const BorderSide(color: Color(0xFF93C5FD)),
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),

                    // ₹a RIGHT COLUMN: Delivery Partner + Actions ₹a₹a₹a₹a₹a₹a
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: const Color(0xFFFAFBFC),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fsHeader('DELIVERY PARTNER', isAssigned ? (driver['name'] ?? 'Partner') : 'Not Assigned',
                              Icons.delivery_dining_rounded,
                              isAssigned ? const Color(0xFF10B981) : Colors.orange.shade700),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.all(24),
                                children: [
                                  if (isAssigned) ...[
                                    // Partner card
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [const Color(0xFF10B981).withOpacity(0.08), const Color(0xFF10B981).withOpacity(0.02)],
                                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                                      ),
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 28, backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
                                            child: Text((driver['name'] ?? 'P')[0].toUpperCase(),
                                              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(driver['name'] ?? 'Partner', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17, color: AdminColors.textHeading)),
                                          Text(driver['phone'] ?? 'N/A', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13)),
                                          const SizedBox(height: 24),

                                          // ₹a BILL PHOTO SECTION (Text/Photo orders) ₹a
                                          if (isTextOrPhoto && isBillUploaded) ...[
                                            const Divider(),
                                            const SizedBox(height: 16),
                                            Row(children: [
                                              const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF10B981)),
                                              const SizedBox(width: 8),
                                              Text('BILL PHOTO', style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                            ]),
                                            const SizedBox(height: 10),
                                            Builder(builder: (context) {
                                              final rawPath = order['billPhotoPath']?.toString() ?? '';
                                              final isLocalFile = rawPath.contains(':\\');
                                              final billUrl = (rawPath.startsWith('http') || isLocalFile)
                                                  ? rawPath
                                                  : '${_SuperAdminDashboardState._baseUrl.split('/api').first}${rawPath.startsWith('/') ? '' : '/'}$rawPath';
                                              return GestureDetector(
                                                onTap: () => onShowImagePreview(billUrl, 'Bill Photo - #${order['displayId']}'),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: isLocalFile
                                                    ? Image.file(
                                                        File(billUrl),
                                                        height: 140,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => Container(
                                                          height: 80,
                                                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                                                          child: Center(child: Text('Bill photo uploaded', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 11))),
                                                        ),
                                                      )
                                                    : Image.network(
                                                        billUrl,
                                                        height: 140,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => Container(
                                                          height: 80,
                                                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                                                          child: Center(child: Text('Bill photo uploaded', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 11))),
                                                        ),
                                                      ),
                                                ),
                                              );
                                            }),
                                            const SizedBox(height: 4),
                                            Center(child: Text('TAP TO ENLARGE', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1))),
                                            const SizedBox(height: 16),
                                          ] else if (isTextOrPhoto && !isBillUploaded) ...[
                                            const Divider(),
                                            const SizedBox(height: 16),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.orange.shade100),
                                              ),
                                              child: Row(children: [
                                                Icon(Icons.hourglass_empty_rounded, color: Colors.orange.shade400, size: 16),
                                                const SizedBox(width: 10),
                                                Expanded(child: Text('Waiting for bill photo from delivery partner...', style: GoogleFonts.outfit(color: Colors.orange.shade600, fontSize: 11, fontWeight: FontWeight.w600))),
                                              ]),
                                            ),
                                            const SizedBox(height: 16),
                                          ],

                                          const Divider(),
                                          const SizedBox(height: 16),
                                          _fsOutlineButton('CANCEL ORDER', Icons.cancel_rounded, Colors.red.shade600, onCancelOrder),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _fsInfoRow(Icons.two_wheeler_rounded, 'Vehicle', driver['vehicleType'] ?? 'N/A', const Color(0xFF10B981)),
                                    const SizedBox(height: 12),
                                    _fsInfoRow(Icons.badge_rounded, 'Vehicle No.', driver['vehicleNumber'] ?? 'N/A', const Color(0xFF10B981)),
                                    const SizedBox(height: 24),
                                    // Live track button
                                    _fsActionButton('LIVE TRACKING', Icons.my_location_rounded, const Color(0xFF0EA5E9), onTrackLive),
                                    const SizedBox(height: 12),
                                    _fsOutlineButton('UNASSIGN PARTNER', Icons.person_remove_rounded, Colors.orange.shade700, onUnassignDriver),
                                  ] else ...[
                                    // No partner assigned
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.orange.shade100),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.person_search_rounded, size: 56, color: Colors.orange.shade300),
                                          const SizedBox(height: 16),
                                          Text('No Partner Assigned', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.orange.shade700, fontSize: 16)),
                                          const SizedBox(height: 8),
                                          Text('Use Manual Dispatch to assign a rider', style: TextStyle(color: Colors.orange.shade400, fontSize: 12), textAlign: TextAlign.center),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _fsActionButton('ASSIGN PARTNER', Icons.person_add_rounded, AdminColors.primaryIndigo, onAssignDriver),
                                  ],
                                  const SizedBox(height: 24),
                                  const Divider(),
                                  const SizedBox(height: 16),
                                  _fsOutlineButton('CANCEL ORDER', Icons.cancel_rounded, Colors.red.shade600, onCancelOrder),
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
          ],
        ),
      ),
    );
  }

  // ₹a Helper Widgets ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
  Widget _fsHeader(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: color.withOpacity(0.18))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.plusJakartaSans(color: AdminColors.textHeading, fontWeight: FontWeight.w800, fontSize: 15),
                  overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fsItemRow(int idx, dynamic item) {
    String name = 'Item $idx';
    String qty = '1';
    double price = 0;
    if (item is Map) {
      name = item['productName']?.toString() ?? item['name']?.toString() ?? name;
      qty = item['quantity']?.toString() ?? '1';
      price = ((item['price'] ?? 0) as num).toDouble();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text('$idx', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: AdminColors.primaryIndigo, fontSize: 13))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AdminColors.textHeading))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AdminColors.primaryIndigo.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Text('Qty: $qty', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AdminColors.primaryIndigo, fontSize: 12)),
          ),
          const SizedBox(width: 14),
          Text('₹${price.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 15, color: AdminColors.textHeading)),
        ],
      ),
    );
  }

  Widget _fsPriceRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: color ?? const Color(0xFF0F172A))),
      ],
    );
  }

  Widget _fsInfoRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.12))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.plusJakartaSans(color: AdminColors.textHeading, fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fsActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _fsOutlineButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.4), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _textOrderBox(String text) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 20),
            ),
            const SizedBox(width: 10),
            Text('CUSTOMER INSTRUCTIONS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 11, color: const Color(0xFFB45309), letterSpacing: 1.2)),
          ]),
          const SizedBox(height: 14),
          Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 15, height: 1.6, color: const Color(0xFF1E293B), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _photoOrderBox(String rawUrl) {
    if (rawUrl.isEmpty) return const SizedBox.shrink();
    final String cleanRaw = rawUrl.replaceAll('\\', '/');
    final String serverHost = _SuperAdminDashboardState._baseUrl.split('/api').first;
    final String fullUrl = (cleanRaw.startsWith('http://') || cleanRaw.startsWith('https://'))
        ? cleanRaw
        : '$serverHost${cleanRaw.startsWith('/') ? '' : '/'}$cleanRaw';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: Image.network(
          fullUrl,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) {
            final String localBackendPath = 'D:/New folder (2)/namba_backend/$cleanRaw';
            if (File(localBackendPath).existsSync()) {
              return Image.file(File(localBackendPath), width: double.infinity, fit: BoxFit.contain);
            }
            return Container(
              height: 160,
              width: double.infinity,
              color: Colors.grey.shade100,
              child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
            );
          },
        ),
      ),
    );
  }

  String _vendorStatusLabel(String status) {
    switch (status) {
      case 'Pending': return 'Received a Awaiting preparation';
      case 'Accepted': return 'Order accepted a Preparing now &';
      case 'Preparing': return 'Packing / Preparing items';
      case 'Ready': return 'Ready for handover ';
      case 'HandedOver': return 'Handed over to partner ';
      case 'PickedUp': return 'Package picked up ';
      case 'OutForDelivery': return 'Out for delivery';
      case 'Delivered': return 'Delivered successfully ';
      default: return status;
    }
  }



}

// ₹a Add Zone Map Dialog ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
class _AddZoneMapDialog extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final void Function(String name, double lat, double lng, double radiusKm) onZoneCreated;

  const _AddZoneMapDialog({
    required this.initialLat,
    required this.initialLng,
    required this.onZoneCreated,
  });

  @override
  State<_AddZoneMapDialog> createState() => _AddZoneMapDialogState();
}

class _AddZoneMapDialogState extends State<_AddZoneMapDialog> {
  late double _pinLat;
  late double _pinLng;
  double _radiusKm = 10.0;
  bool _pinDropped = false;
  final MapController _mapCtrl = MapController();
  final TextEditingController _nameCtrl = TextEditingController();

  static const List<int> _radiusPresets = [5, 10, 15, 20, 25, 30, 50];

  @override
  void initState() {
    super.initState();
    _pinLat = widget.initialLat;
    _pinLng = widget.initialLng;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPos, LatLng point) {
    setState(() {
      _pinLat = point.latitude;
      _pinLng = point.longitude;
      _pinDropped = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 860,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // ₹a Header ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Define New Service Zone',
                            style: GoogleFonts.outfit(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        Text('Tap anywhere on the map to drop the zone center',
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // ₹a Map Area ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapCtrl,
                    options: MapOptions(
                      initialCenter: LatLng(_pinLat, _pinLng),
                      initialZoom: 11,
                      maxZoom: 22.0,
                      onTap: _onMapTap,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}',
                        subdomains: const ['0', '1', '2', '3'],
                        userAgentPackageName: 'com.namba.admin',
                        maxZoom: 22,
                        maxNativeZoom: 20,
                        errorTileCallback: (tile, error, stackTrace) {
                          debugPrint('Google Map Tile error: $error');
                        },
                      ),
                      // Live radius circle preview
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(_pinLat, _pinLng),
                            radius: _radiusKm * 1000.0,
                            useRadiusInMeter: true,
                            color: const Color(0xFF4F46E5).withOpacity(0.18),
                            borderColor: const Color(0xFF4F46E5),
                            borderStrokeWidth: 2.5,
                          ),
                        ],
                      ),
                      // Pin marker
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_pinLat, _pinLng),
                            width: 160,
                            height: 70,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6)],
                                  ),
                                  child: Text(
                                    '${_radiusKm.toStringAsFixed(0)} KM ZONE',
                                    style: GoogleFonts.outfit(
                                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 34),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ₹a Tap instruction banner ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
                  if (!_pinDropped)
                    Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.76),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.touch_app_rounded, color: Colors.amberAccent, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '&S Tap any district / area to set the zone center',
                                style: GoogleFonts.outfit(
                                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ₹a Coordinates badge (bottom-left) ₹a₹a₹a₹a₹a₹a₹a₹aa
                  if (_pinDropped)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pin_drop_rounded, color: Color(0xFF4F46E5), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${_pinLat.toStringAsFixed(4)}, ${_pinLng.toStringAsFixed(4)}',
                              style: GoogleFonts.outfit(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E1B4B)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ₹a Radius presets (top-right) ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('QUICK RADIUS',
                              style: GoogleFonts.outfit(
                                  fontSize: 9, fontWeight: FontWeight.w900,
                                  color: Colors.grey.shade500, letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _radiusPresets.map((km) {
                              final selected = _radiusKm == km.toDouble();
                              return GestureDetector(
                                onTap: () => setState(() => _radiusKm = km.toDouble()),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: selected ? const Color(0xFF4F46E5) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${km}km',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: selected ? Colors.white : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ₹a Radius Slider ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Text('1 KM', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF4F46E5),
                        inactiveTrackColor: Colors.grey.shade200,
                        thumbColor: const Color(0xFF4F46E5),
                        overlayColor: const Color(0xFF4F46E5).withOpacity(0.1),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _radiusKm,
                        min: 1,
                        max: 50,
                        divisions: 49,
                        onChanged: (v) => setState(() => _radiusKm = v),
                      ),
                    ),
                  ),
                  Text('50 KM', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_radiusKm.toStringAsFixed(0)} KM',
                      style: GoogleFonts.outfit(
                          color: const Color(0xFF4F46E5), fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // ₹a Bottom Panel: Zone Name + Create ₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a₹a
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1.5)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Zone name (e.g. Erode North, Perundurai Town...)',
                        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.label_rounded, color: Color(0xFF4F46E5), size: 20),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                        ),
                      ),
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final name = _nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Please enter a zone name'),
                            backgroundColor: Colors.orange,
                          ));
                          return;
                        }
                        if (!_pinDropped) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Tap the map to set the zone center first'),
                            backgroundColor: Colors.orange,
                          ));
                          return;
                        }
                        Navigator.pop(context);
                        widget.onZoneCreated(name, _pinLat, _pinLng, _radiusKm);
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text('Create Zone',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
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
}
