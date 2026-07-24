import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../services/delivery_auth_service.dart';
import '../models/delivery_order.dart';
import '../services/location_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:geolocator/geolocator.dart';

class DeliveryProvider extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final LocationTrackingService _locationService = LocationTrackingService();
  io.Socket? _socket;

  List<DeliveryOrder> _activeOrders = [];
  List<DeliveryOrder> _incomingRequests = [];
  List<DeliveryOrder> _orderHistory = [];
  List<String> _declinedOrderIds = [];
  final Set<String> _notifiedOrderIds = {};
  Map<String, dynamic> _documents = {};
  String _approvalStatus = 'pending';
  bool _isOnline = false;
  String _lastSyncState = '';
  bool _isAuthenticated = true; // default to true to avoid flashing login on start
  bool get isAuthenticated => _isAuthenticated;

  // ── New Assignment Pending State ──────────────────────────────────────────
  Map<String, dynamic>? _pendingAssignment; // raw data from socket
  Function(Map<String, dynamic>)? onNewAssignment; // UI registers this callback

  Map<String, dynamic>? get pendingAssignment => _pendingAssignment;

  DeliveryProvider() {
    debugPrint('⚙️ PROVIDER: Initializing DeliveryProvider...');
    _initNotifications();
    _startSyncPoller();
    checkInitialAuth();
    // Dynamically derive socket base: replace '/api/v1' or similar with empty string
    final apiBase = DeliveryAuthService.baseUrl;
    final socketBase = apiBase.split('/api/').first;
    
    _locationService.initialize(socketBase);
    _requestPermissionOnStartup();
    _initSocket();
    _fetchHistoryFromApi();
    fetchDocumentStatuses();
    debugPrint('⚙️ PROVIDER: Initialization Triggered');
  }

  Future<void> checkInitialAuth() async {
    final loggedIn = await DeliveryAuthService.isLoggedIn();
    _isAuthenticated = loggedIn;
    notifyListeners();
  }

  void setAuthenticated(bool val) {
    _isAuthenticated = val;
    if (val) {
      _initSocket();
    }
    notifyListeners();
  }

  Function(String)? onForceLogout;
  bool _isLocationServiceEnabled = true;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;

  void handleUnauthorized() async {
    // Do NOT wipe SharedPreferences on background network 401 errors.
    // Preserves persistent auto-login session across app updates.
    debugPrint('⚠️ Network 401 Warning: Temporary auth sync issue, keeping session active.');
    _isAuthenticated = true;
    notifyListeners();
  }

  double _parseDoubleSilently(dynamic val, double fallback) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  double _parseCoordinateSilently(dynamic coords, int idx, double fallback) {
    if (coords != null && coords['coordinates'] is List && (coords['coordinates'] as List).length > idx) {
      return _parseDoubleSilently(coords['coordinates'][idx], fallback);
    }
    return fallback;
  }

  void _initSocket() async {
    final driverId = await DeliveryAuthService.getDriverId();
    if (driverId.isEmpty) return;

    if (_socket != null) {
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    final apiBase = DeliveryAuthService.baseUrl;
    final socketBase = apiBase.split('/api/').first;

    _socket = io.io(socketBase, io.OptionBuilder()
        .setTransports(['websocket'])
        .enableForceNew()
        .enableAutoConnect()
        .build());

      _socket!.onConnect((_) {
        debugPrint('🔌 Driver Socket Connected - Joining Room driver_$driverId');
        _socket!.emit('join_room', 'driver_$driverId');

        // Auto re-sync online status when socket reconnects
        if (_isOnline) {
          DeliveryAuthService.setDriverStatus(driverId, true);
        }
      });

      // Single Device Lock Listener
      _socket!.on('force_device_logout', (data) async {
        debugPrint('🚨 FORCE DEVICE LOGOUT: Account logged in on another device.');
        await DeliveryAuthService.logout();
        _isAuthenticated = false;
        _activeOrders.clear();
        _incomingRequests.clear();
        _orderHistory.clear();
        _pendingAssignment = null;
        notifyListeners();
        onForceLogout?.call(data['message'] ?? 'This account was logged in on another device.');
      });

    _socket!.on('orders_wiped', (_) {
      debugPrint('🚨 GLOBAL ORDERS WIPED: Clearing delivery lists');
      _activeOrders.clear();
      _incomingRequests.clear();
      _orderHistory.clear();
      notifyListeners();
    });

    // New assignment from admin dispatch
    _socket!.on('new_assignment', (data) {
      debugPrint('🚨 NEW ASSIGNMENT SOCKET: $data');
      final newOrderId = (data as Map)['orderId']?.toString();
      final isAlreadyActive = _activeOrders.any((o) => o.id == newOrderId);
      final isAlreadyPending = _incomingRequests.any((o) => o.id == newOrderId);

      if (!_isOnline) {
        debugPrint('🚫 Ignoring assignment alert because driver is OFFLINE');
        return;
      }

      if (isAlreadyActive || isAlreadyPending) {
        debugPrint('🛡️ Ignoring redundant assignment alert for order: $newOrderId');
        return;
      }
      _pendingAssignment = Map<String, dynamic>.from(data as Map);
      notifyListeners();
      // Show system notification immediately
      _showNotificationFromSocket(_pendingAssignment!);
      // Trigger UI callback if registered
      onNewAssignment?.call(_pendingAssignment!);
      _fullSync();
    });

    // Order status updates (vendor ready, cancellation, etc.)
    _socket!.on('order_status_update', (data) {
      debugPrint('📦 ORDER STATUS UPDATE: $data');
      if (data != null && (data['status'] == 'Cancelled' || data['status'] == 'Rejected')) {
        final did = data['displayId']?.toString() ?? '';
        final msg = data['message']?.toString() ?? 'Order has been cancelled.';
        _showSimpleNotification(
          '❌ Order Cancelled',
          did.isNotEmpty ? 'Order #$did: $msg' : msg,
        );
      }
      _fullSync();
    });

    _socket!.on('vendor_payment_completed', (data) {
      debugPrint('💳 VENDOR PAYMENT COMPLETED: $data');
      _fullSync();
      _showSimpleNotification('Admin paid the vendor!', 'You can now proceed with the delivery.');
    });
  }

  List<DeliveryOrder> get activeOrders => _activeOrders;
  List<DeliveryOrder> get incomingRequests => _incomingRequests;
  List<DeliveryOrder> get orderHistory => _orderHistory;
  List<String> get declinedOrderIds => _declinedOrderIds;
  Map<String, dynamic> get documents => _documents;
  String get approvalStatus => _approvalStatus;
  bool get isOnline => _isOnline;

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            _pendingAssignment = Map<String, dynamic>.from(data);
            notifyListeners();
            onNewAssignment?.call(_pendingAssignment!);
          } catch (e) {
            debugPrint('Notification Payload Error: $e');
          }
        }
      },
    );

    // ── Create high-priority notification channel (Android 8+) ──────────
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'namba_order_alerts',          // channel id
          'New Order Alerts',            // channel name
          description: 'Urgent alerts when a new delivery order is assigned.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFF00C853),
          showBadge: true,
        ),
      );
      // Request POST_NOTIFICATIONS permission (Android 13 / API 33+)
      await androidPlugin.requestNotificationsPermission();
    }
  }

  void _startSyncPoller() {
    _fullSync(); // Initial sync
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _fullSync();
    });
  }

  Future<void> _fullSync() async {
    try {
      final driverId = await DeliveryAuthService.getDriverId();
      if (driverId.isEmpty) return;

      // 1. Fetch from API
      List<DeliveryOrder> apiActive = [];
      List<DeliveryOrder> apiIncoming = [];
      
      try {
        final url = Uri.parse('${DeliveryAuthService.baseUrl}/orders/driver/$driverId');
        final response = await http.get(url, headers: await DeliveryAuthService.getHeaders());
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data['success'] == true) {
            final List<dynamic> ordersJson = data['data'];
            for (var json in ordersJson) {
              final backendStatus = json['status']?.toString() ?? 'Pending';
              final dOrder = _mapJsonToDeliveryOrder(json);
              
              if (backendStatus == 'Pending') {
                apiIncoming.add(dOrder);
              } else if (backendStatus != 'Delivered' && backendStatus != 'Cancelled') {
                apiActive.add(dOrder);
              }
            }
          }
        } else if (response.statusCode == 401) {
          handleUnauthorized();
          return;
        }
      } catch (e) {
        debugPrint('API Sync Error: $e');
      }

      // Check for actual changes in both lists before notifying
      final String activeState = jsonEncode(apiActive.map((o) => o.id + o.rawStatus).toList());
      final String incomingState = jsonEncode(apiIncoming.map((o) => o.id + o.rawStatus).toList());
      final String combinedState = activeState + incomingState;
      
      bool hasChanged = combinedState != _lastSyncState;
      
      // Atomic update
      _activeOrders = apiActive;
      _incomingRequests = apiIncoming;
      _lastSyncState = combinedState;
      
      _updateLocationTrackingState(driverId);
      
      if (hasChanged) {
        notifyListeners();
      }
      for (var req in _incomingRequests) {
        if (!_notifiedOrderIds.contains(req.id)) {
          _notifiedOrderIds.add(req.id);
          _showNotification(req);
        }
      }
    } catch (e) {
      debugPrint('Full Sync Error: $e');
    }
  }

  DeliveryOrder _mapJsonToDeliveryOrder(dynamic json) {
    final vendor = json['vendor'] ?? {};
    final customer = json['customer'] ?? {};
    final backendStatus = json['status']?.toString() ?? 'Pending';
    
    final double finalDestLat = _parseCoordinateSilently(json['deliveryCoordinates'], 1, _parseDoubleSilently(json['destLat'], 11.3410));
    final double finalDestLng = _parseCoordinateSilently(json['deliveryCoordinates'], 0, _parseDoubleSilently(json['destLng'], 77.7172));

    double finalStoreLat = finalDestLat;
    double finalStoreLng = finalDestLng;

    if (vendor['location'] != null) {
      finalStoreLat = _parseCoordinateSilently(vendor['location'], 1, finalDestLat);
      finalStoreLng = _parseCoordinateSilently(vendor['location'], 0, finalDestLng);
    } else if (json['storeLat'] != null) {
      finalStoreLat = _parseDoubleSilently(json['storeLat'], finalDestLat);
      finalStoreLng = _parseDoubleSilently(json['storeLng'], finalDestLng);
    }

    return DeliveryOrder(
      id: json['_id'] ?? '',
      storeName: vendor['storeName'] ?? 'Vendor',
      storeAddress: vendor['address']?.toString() ?? '',
      customerName: customer['name']?.toString() ?? 'Customer',
      customerAddress: json['deliveryAddressFormatted']?.toString() ?? 'Check app',
      customerPhone: customer['phone']?.toString() ?? 'N/A',
      storePhone: vendor['phone']?.toString() ?? 'N/A',
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      items: (json['items'] as List? ?? []).map((i) => i['productName']?.toString() ?? 'Item').toList(),
      status: _mapBackendStatusToDelivery(backendStatus),
      timestamp: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      displayId: json['displayId'] ?? '',
      rawStatus: backendStatus,
      paymentMethod: json['paymentMethod'] ?? 'COD',
      isCustomStore: json['isCustomStore'] == true,
      orderType: json['orderType']?.toString() ?? 'Cart',
      textContent: json['textContent']?.toString(),
      billPhotoPath: json['billPhotoPath']?.toString(),
      storeLat: finalStoreLat,
      storeLng: finalStoreLng,
      destLat: finalDestLat,
      destLng: finalDestLng,
      vendorPaymentDetailsUploadedByDriver: json['vendorPaymentDetailsUploadedByDriver'] == true,
      vendorPaymentStatus: json['vendorPaymentStatus']?.toString() ?? 'Pending',
      paymentStatus: json['paymentStatus']?.toString() ?? 'Pending',
    );
  }

  Future<void> _fetchHistoryFromApi() async {
    try {
      final driverId = await DeliveryAuthService.getDriverId();
      if (driverId.isEmpty) return;

      final url = Uri.parse('${DeliveryAuthService.baseUrl}/orders/driver/$driverId/history');
      final response = await http.get(url, headers: await DeliveryAuthService.getHeaders());

      if (response.statusCode == 401) {
        handleUnauthorized();
        return;
      }
      if (response.statusCode != 200) return;

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['success'] != true) return;

      final List<dynamic> ordersJson = data['data'];

      _orderHistory = ordersJson.map((json) {
        final vendor = json['vendor'] ?? {};
        final customer = json['customer'] ?? {};

        final double finalDestLat = _parseCoordinateSilently(json['deliveryCoordinates'], 1, _parseDoubleSilently(json['destLat'], 11.3410));
        final double finalDestLng = _parseCoordinateSilently(json['deliveryCoordinates'], 0, _parseDoubleSilently(json['destLng'], 77.7172));

        double finalStoreLat = finalDestLat;
        double finalStoreLng = finalDestLng;

        if (vendor['location'] != null) {
          finalStoreLat = _parseCoordinateSilently(vendor['location'], 1, finalDestLat);
          finalStoreLng = _parseCoordinateSilently(vendor['location'], 0, finalDestLng);
        } else if (json['storeLat'] != null) {
          finalStoreLat = _parseDoubleSilently(json['storeLat'], finalDestLat);
          finalStoreLng = _parseDoubleSilently(json['storeLng'], finalDestLng);
        }

        return DeliveryOrder(
          id: json['_id'] ?? '',
          storeName: vendor['storeName'] ?? 'Vendor',
          storeAddress: '',
          customerName: customer['name'] ?? 'Customer',
          customerAddress: json['deliveryAddressFormatted'] ?? 'Delivered',
          customerPhone: customer['phone'] ?? 'N/A',
          storePhone: vendor['phone']?.toString() ?? 'N/A',
          totalAmount: (json['totalAmount'] ?? 0).toDouble(),
          items: (json['items'] as List? ?? []).map((i) => i['productName']?.toString() ?? 'Item').toList(),
          status: _mapBackendStatusToDelivery(json['status']),
          timestamp: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
          displayId: json['displayId'] ?? '',
          rawStatus: json['status'] ?? '',
          paymentMethod: json['paymentMethod'] ?? 'COD',
          storeLat: finalStoreLat,
          storeLng: finalStoreLng,
          destLat: finalDestLat,
          destLng: finalDestLng,
          vendorPaymentDetailsUploadedByDriver: json['vendorPaymentDetailsUploadedByDriver'] == true,
          vendorPaymentStatus: json['vendorPaymentStatus']?.toString() ?? 'Pending',
          paymentStatus: json['paymentStatus']?.toString() ?? 'Pending',
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('History Fetch Error: $e');
    }
  }

  DeliveryStatus _mapBackendStatusToDelivery(String? status) {
    switch (status) {
      case 'Pending':   return DeliveryStatus.allocated;
      case 'Accepted':
      case 'Confirmed':
      case 'Preparing':
      case 'Assigned':
      case 'Ready':     
      case 'HandedOver': return DeliveryStatus.pickingUp;
      case 'PickedUp':
      case 'Picked Up': return DeliveryStatus.pickedUp;
      case 'OutForDelivery':
      case 'On The Way': return DeliveryStatus.onTheWay;
      case 'Delivered': return DeliveryStatus.delivered;
      case 'Cancelled': return DeliveryStatus.cancelled;
      default: return DeliveryStatus.allocated;
    }
  }

  static final _kOrderAlertDetails = AndroidNotificationDetails(
    'namba_order_alerts',
    'New Order Alerts',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
    enableLights: true,
    ledColor: const Color(0xFF00C853),
    ledOnMs: 500,
    ledOffMs: 500,
    ticker: 'New Namba delivery order!',
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.call,
  );

  Future<void> _showNotification(DeliveryOrder order) async {
    final payment = order.paymentMethod == 'COD' ? '💸 COD' : '💳 PAID';
    await _notificationsPlugin.show(
      order.id.hashCode,
      '🚨 New Delivery Request!',
      '[$payment] Order #${order.displayId.isNotEmpty ? order.displayId : order.id.substring(0, 6)} — ${order.storeName}',
      NotificationDetails(android: _kOrderAlertDetails),
      payload: jsonEncode({
        'orderId': order.id,
        'displayId': order.displayId,
        'vendorName': order.storeName,
        'amount': order.totalAmount.toString(),
        'paymentMethod': order.paymentMethod,
      }),
    );
  }

  Future<void> _showNotificationFromSocket(Map<String, dynamic> data) async {
    final id = data['orderId']?.toString() ?? '';
    final store = data['vendorName']?.toString() ?? 'Store';
    final payment = data['paymentMethod'] == 'COD' ? '💸 COD' : '💳 PAID';
    final did = data['displayId']?.toString() ?? '';

    await _notificationsPlugin.show(
      id.isNotEmpty ? id.hashCode : DateTime.now().millisecondsSinceEpoch,
      '🚨 New Order Request',
      '[$payment] ${did.isNotEmpty ? 'Order #$did' : ''} from $store — Tap to Accept',
      NotificationDetails(android: _kOrderAlertDetails),
      payload: jsonEncode(data),
    );
  }

  Future<void> _showSimpleNotification(String title, String body) async {
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: AndroidNotificationDetails('namba_order_alerts', 'New Order Alerts', importance: Importance.max)),
    );
  }

  Future<bool> acceptAssignment(String orderId) async {
    // 1. OPTIMISTIC UPDATE
    int incomingIdx = _incomingRequests.indexWhere((o) => o.id == orderId);
    DeliveryOrder? acceptedOrder;
    
    if (incomingIdx != -1) {
      acceptedOrder = _incomingRequests[incomingIdx];
      _incomingRequests.removeAt(incomingIdx);
      
      final updatedOrder = acceptedOrder.copyWith(
        status: DeliveryStatus.pickingUp,
        rawStatus: 'Assigned',
      );
      if (!_activeOrders.any((o) => o.id == orderId)) {
        _activeOrders.insert(0, updatedOrder);
      }
      _pendingAssignment = null;
      notifyListeners();
    } else if (_pendingAssignment != null && _pendingAssignment!['orderId'] == orderId) {
      acceptedOrder = DeliveryOrder(
        id: orderId,
        storeName: _pendingAssignment!['vendorName'] ?? 'Store',
        storeAddress: '',
        customerName: 'Customer',
        customerAddress: 'Checking address...',
        customerPhone: '',
        totalAmount: double.tryParse(_pendingAssignment!['amount']?.toString() ?? '0') ?? 0,
        items: [],
        status: DeliveryStatus.pickingUp,
        timestamp: DateTime.now(),
        displayId: _pendingAssignment!['displayId'] ?? '',
        rawStatus: 'Assigned',
        paymentMethod: _pendingAssignment!['paymentMethod'] ?? 'ONLINE',
      );
      if (!_activeOrders.any((o) => o.id == orderId)) {
        _activeOrders.insert(0, acceptedOrder);
      }
      _pendingAssignment = null;
      notifyListeners();
    }

    try {
      final driverId = await DeliveryAuthService.getDriverId();
      final response = await http.put(
        Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/status'),
        headers: await DeliveryAuthService.getHeaders(),
        body: jsonEncode({'status': 'Assigned', 'driverId': driverId}),
      );
      if (response.statusCode == 200) {
        _pendingAssignment = null;
        await _fullSync();
        return true;
      } else if (response.statusCode == 401) {
        handleUnauthorized();
        _rollbackAccept(orderId, acceptedOrder, incomingIdx);
        return false;
      } else {
        _rollbackAccept(orderId, acceptedOrder, incomingIdx);
        return false;
      }
    } catch (e) {
      debugPrint('Accept Error: $e');
      _rollbackAccept(orderId, acceptedOrder, incomingIdx);
      return false;
    }
  }

  void _rollbackAccept(String orderId, DeliveryOrder? acceptedOrder, int incomingIdx) {
    _activeOrders.removeWhere((o) => o.id == orderId);
    if (acceptedOrder != null && incomingIdx != -1) {
      _incomingRequests.insert(incomingIdx, acceptedOrder);
    }
    notifyListeners();
  }

  Future<bool> declineAssignment(String orderId) async {
    try {
      final response = await http.put(
        Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/decline'),
        headers: await DeliveryAuthService.getHeaders(),
      );
      if (response.statusCode == 200) {
        if (!_declinedOrderIds.contains(orderId)) {
          _declinedOrderIds.add(orderId);
        }
        _pendingAssignment = null;
        _incomingRequests.removeWhere((o) => o.id == orderId);
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        handleUnauthorized();
        return false;
      }
      return false;
    } catch (e) {
      debugPrint('Decline Error: $e');
      return false;
    }
  }

  Future<void> acceptOrder(DeliveryOrder order) async => acceptAssignment(order.id);
  void declineOrder(String orderId) => declineAssignment(orderId);

  Future<void> updateOrderStatus(String orderId, DeliveryStatus status) async {
    String backendStatus = 'Assigned';
    if (status == DeliveryStatus.pickedUp) backendStatus = 'PickedUp';
    if (status == DeliveryStatus.onTheWay) backendStatus = 'OutForDelivery';
    if (status == DeliveryStatus.delivered) backendStatus = 'Delivered';

    try {
      final driverId = await DeliveryAuthService.getDriverId();

      final response = await http.put(
        Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/status'),
        headers: await DeliveryAuthService.getHeaders(),
        body: jsonEncode({'status': backendStatus, 'driverId': driverId}),
      );
      if (response.statusCode == 401) {
        handleUnauthorized();
        return;
      }
    } catch (e) {
      debugPrint('Update Status Error: $e');
    }

    // Local sync update removed

    if (status == DeliveryStatus.delivered) {
      await _fetchHistoryFromApi();
    }
    await _fullSync();
  }

  void _updateLocationTrackingState(String driverId) async {
    final name = await DeliveryAuthService.getDriverName();
    if (_activeOrders.isNotEmpty) {
      final activeOrder = _activeOrders.first;
      _locationService.startTracking(activeOrder.id, driverId, name);
    } else if (_isOnline) {
      _locationService.startTracking("online", driverId, name);
    } else {
      _locationService.stopTracking();
    }
  }

  Future<void> _requestPermissionOnStartup() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        await Geolocator.requestPermission();
      }
      _isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
        final enabled = (status == ServiceStatus.enabled);
        if (_isLocationServiceEnabled != enabled) {
          _isLocationServiceEnabled = enabled;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('[Permission] Startup error: $e');
    }
  }

  Future<void> fetchDocumentStatuses() async {
    try {
      final driverId = await DeliveryAuthService.getDriverId();
      if (driverId.isEmpty) return;

      final savedOnline = await DeliveryAuthService.getIsOnline();

      final result = await DeliveryAuthService.getDriverDocuments(driverId);
      if (result['success'] == true) {
        _documents = result['data'] ?? {};
        _approvalStatus = result['status'] ?? 'pending';
        
        if (savedOnline || _isOnline) {
          _isOnline = true;
          DeliveryAuthService.setDriverStatus(driverId, true);
        } else if (result['isOnline'] != null) {
          _isOnline = result['isOnline'] == true;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch Documents Error: $e');
    }
  }

  void updateOnlineStatus(bool online) async {
    _isOnline = online;
    notifyListeners();

    final driverId = await DeliveryAuthService.getDriverId();
    if (driverId.isNotEmpty) {
      // Sync online status with backend & SharedPreferences
      await DeliveryAuthService.setDriverStatus(driverId, online);

      // Ensure provider socket is connected
      if (_socket == null || !_socket!.connected) {
        _initSocket();
      }
      _updateLocationTrackingState(driverId);
    }
    notifyListeners();
  }

  void clearPendingAssignment() {
    _pendingAssignment = null;
    notifyListeners();
  }

  Future<bool> sendQuote(String orderId, double amount) async {
    try {
      final driverId = await DeliveryAuthService.getDriverId();
      final response = await http.put(
        Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'totalAmount': amount,
          'driverId': driverId,
          'status': 'Assigned',
        }),
      );
      if (response.statusCode == 200) {
        await _fullSync();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Send Quote Error: $e');
      return false;
    }
  }

  Future<bool> uploadBillPhoto(String orderId, String filePath) async {
    try {
      debugPrint('📸 Starting bill upload for order: $orderId');
      debugPrint('📄 File path: $filePath');

      final token = await DeliveryAuthService.getToken();
      final url = Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/bill');
      debugPrint('🔗 Upload URL: $url');

      final request = http.MultipartRequest('PUT', url);
      
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      final String extension = filePath.split('.').last.toLowerCase();
      final String mimeType = (extension == 'png') ? 'png' : 'jpeg';
      debugPrint('📝 Detected extension: $extension, using mime: image/$mimeType');
      
      request.files.add(await http.MultipartFile.fromPath(
        'bill', 
        filePath,
        contentType: MediaType('image', mimeType),
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📡 Upload Response Code: ${response.statusCode}');
      debugPrint('📡 Upload Response Body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ Bill upload successful on server');
        await _fullSync();
        return true;
      } else {
        debugPrint('❌ Bill upload failed on server with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('🔥 Bill Upload Exception: $e');
      return false;
    }
  }

  Future<bool> submitVendorPaymentDetails(String orderId, {String? filePath, String? upiNumber}) async {
    try {
      final token = await DeliveryAuthService.getToken();
      final uri = Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/vendor-payment-details');
      final request = http.MultipartRequest('PUT', uri);
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      if (filePath != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'qr', 
          filePath,
          contentType: MediaType('image', 'jpeg'),
        ));
      }
      if (upiNumber != null) {
        request.fields['vendorUpiNumber'] = upiNumber;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        await _fullSync();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Submit Vendor Payment Error: $e');
      return false;
    }
  }


}
