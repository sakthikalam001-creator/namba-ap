import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../services/sync_service.dart';
import '../services/delivery_auth_service.dart';
import '../models/delivery_order.dart';
import '../services/location_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class DeliveryProvider extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final LocationTrackingService _locationService = LocationTrackingService();
  io.Socket? _socket;

  List<DeliveryOrder> _activeOrders = [];
  List<CoreOrder> _incomingRequests = [];
  List<DeliveryOrder> _orderHistory = [];
  List<String> _declinedOrderIds = [];
  final Set<String> _notifiedOrderIds = {};
  Map<String, dynamic> _documents = {};
  String _approvalStatus = 'pending';
  bool _isOnline = false;
  String _lastSyncState = '';

  // ── New Assignment Pending State ──────────────────────────────────────────
  Map<String, dynamic>? _pendingAssignment; // raw data from socket
  Function(Map<String, dynamic>)? onNewAssignment; // UI registers this callback

  Map<String, dynamic>? get pendingAssignment => _pendingAssignment;

  DeliveryProvider() {
    debugPrint('⚙️ PROVIDER: Initializing DeliveryProvider...');
    _initNotifications();
    _startSyncPoller();
    // Dynamically derive socket base: replace '/api/v1' or similar with empty string
    final apiBase = DeliveryAuthService.baseUrl;
    final socketBase = apiBase.split('/api/').first;
    
    _locationService.initialize(socketBase);
    _initSocket();
    _fetchHistoryFromApi();
    fetchDocumentStatuses();
    debugPrint('⚙️ PROVIDER: Initialization Triggered');
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

    final apiBase = DeliveryAuthService.baseUrl;
    final socketBase = apiBase.split('/api/').first;

    _socket = io.io(socketBase, io.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .build());

    _socket!.onConnect((_) {
      debugPrint('✅ Driver Socket Connected - Joining Room driver_$driverId');
      _socket!.emit('join_room', 'driver_$driverId');
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

    // Order status updates (vendor ready, etc.)
    _socket!.on('order_status_update', (data) {
      debugPrint('📦 ORDER STATUS UPDATE: $data');
      _fullSync();
    });

    _socket!.on('vendor_payment_completed', (data) {
      debugPrint('💳 VENDOR PAYMENT COMPLETED: $data');
      _fullSync();
      _showSimpleNotification('Admin paid the vendor!', 'You can now proceed with the delivery.');
    });
  }

  List<DeliveryOrder> get activeOrders => _activeOrders;
  List<CoreOrder> get incomingRequests => _incomingRequests;
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
      List<CoreOrder> apiIncoming = [];
      
      try {
        final url = Uri.parse('${DeliveryAuthService.baseUrl}/orders/driver/$driverId');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data['success'] == true) {
            final List<dynamic> ordersJson = data['data'];
            for (var json in ordersJson) {
              final co = _mapJsonToCoreOrder(json);
              if (co.status == CoreOrderStatus.pending) {
                apiIncoming.add(co);
              } else if (co.status != CoreOrderStatus.delivered && co.status != CoreOrderStatus.cancelled) {
                apiActive.add(_mapCoreToDeliveryOrder(co, json));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('API Sync Error: $e');
      }

      
      // Check for actual changes before notifying
      final String newState = jsonEncode(_activeOrders.map((o) => o.id + o.rawStatus).toList());
      
      if (newState != _lastSyncState) {
        _lastSyncState = newState;
        notifyListeners();
      }
      
      _incomingRequests = apiIncoming;
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

  CoreOrder _mapJsonToCoreOrder(dynamic json) {
    final vendor = json['vendor'] ?? {};
    return CoreOrder(
      id: json['_id'] ?? '',
      store: CoreStore(
        id: vendor['_id'] ?? '',
        name: vendor['storeName'] ?? 'Vendor',
        image: '',
        category: vendor['category'] ?? 'General',
        rating: 0.0,
        reviewCount: 0,
        distance: '0 KM',
        deliveryTime: '0 min',
        deliveryFee: 0,
      ),
      items: (json['items'] as List? ?? []).map((i) => CoreCartItem(
        product: CoreProduct(
          id: '',
          name: i['productName']?.toString() ?? i.toString(),
          description: '',
          price: (i['price'] as num?)?.toDouble() ?? 0,
          image: '',
          category: '',
        ),
        quantity: (i['quantity'] as num?)?.toInt() ?? 1,
      )).toList(),
      status: _mapBackendStatusToCore(json['status']),
      type: (json['isCustomStore'] == true || json['orderType'] == 'Text' || json['orderType'] == 'Photo') ? CoreOrderType.text : CoreOrderType.standard,
      subtotal: (json['totalAmount'] ?? 0).toDouble(),
      deliveryFee: (json['deliveryCharge'] ?? 0).toDouble(),
      taxes: 0,
      total: (json['totalAmount'] ?? 0).toDouble(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      displayId: json['displayId'] ?? '',
      rawStatus: json['status'] ?? 'Pending',
      paymentMethod: json['paymentMethod'] ?? 'COD',
      billPhotoPath: json['billPhotoPath'],
      billUploadedAt: json['billUploadedAt'] != null ? DateTime.parse(json['billUploadedAt']) : null,
      isCustomStore: json['isCustomStore'] == true,
    );
  }

  DeliveryOrder _mapCoreToDeliveryOrder(CoreOrder co, dynamic originalJson) {
    final customer = originalJson['customer'] ?? {};
    final vendor = originalJson['vendor'] ?? {};
    return DeliveryOrder(
      id: co.id,
      storeName: co.store.name,
      storeAddress: vendor['address']?.toString() ?? '',
      customerName: customer['name']?.toString() ?? 'Customer',
      customerAddress: originalJson['deliveryAddressFormatted']?.toString() ?? 'Check app',
      customerPhone: customer['phone']?.toString() ?? 'N/A',
      totalAmount: co.total,
      items: co.items.map((i) => i.product.name).toList(),
      status: _mapStatus(co.status),
      timestamp: co.createdAt,
      displayId: co.displayId,
      rawStatus: co.rawStatus,
      paymentMethod: co.paymentMethod,
      isCustomStore: originalJson['isCustomStore'] == true,
      orderType: originalJson['orderType']?.toString() ?? 'Cart',
      textContent: originalJson['textContent']?.toString(),
      billPhotoPath: originalJson['billPhotoPath']?.toString(),
      storeLat: _parseDoubleSilently(originalJson['storeLat'], 11.0168),
      storeLng: _parseDoubleSilently(originalJson['storeLng'], 76.9558),
      destLat: _parseCoordinateSilently(originalJson['deliveryCoordinates'], 1, _parseDoubleSilently(originalJson['destLat'], 11.0500)),
      destLng: _parseCoordinateSilently(originalJson['deliveryCoordinates'], 0, _parseDoubleSilently(originalJson['destLng'], 76.9800)),
      vendorPaymentDetailsUploadedByDriver: originalJson['vendorPaymentDetailsUploadedByDriver'] == true,
      vendorPaymentStatus: originalJson['vendorPaymentStatus']?.toString() ?? 'Pending',
      paymentStatus: originalJson['paymentStatus']?.toString() ?? 'Pending',
    );
  }

  Future<void> _fetchHistoryFromApi() async {
    try {
      final driverId = await DeliveryAuthService.getDriverId();
      if (driverId.isEmpty) return;

      final url = Uri.parse('${DeliveryAuthService.baseUrl}/orders/driver/$driverId/history');
      final response = await http.get(url);

      if (response.statusCode != 200) return;

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['success'] != true) return;

      final List<dynamic> ordersJson = data['data'];

      _orderHistory = ordersJson.map((json) {
        final vendor = json['vendor'] ?? {};
        final customer = json['customer'] ?? {};

        return DeliveryOrder(
          id: json['_id'] ?? '',
          storeName: vendor['storeName'] ?? 'Vendor',
          storeAddress: '',
          customerName: customer['name'] ?? 'Customer',
          customerAddress: json['deliveryAddressFormatted'] ?? 'Delivered',
          customerPhone: customer['phone'] ?? 'N/A',
          totalAmount: (json['totalAmount'] ?? 0).toDouble(),
          items: (json['items'] as List? ?? []).map((i) => i['productName']?.toString() ?? 'Item').toList(),
          status: _mapStatus(_mapBackendStatusToCore(json['status'])),
          timestamp: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
          displayId: json['displayId'] ?? '',
          rawStatus: json['status'] ?? '',
          paymentMethod: json['paymentMethod'] ?? 'COD',
          storeLat: _parseDoubleSilently(json['storeLat'] ?? 11.0168, 11.0168),
          storeLng: _parseDoubleSilently(json['storeLng'] ?? 76.9558, 76.9558),
          destLat: _parseCoordinateSilently(json['deliveryCoordinates'], 1, _parseDoubleSilently(json['destLat'], 11.0500)),
          destLng: _parseCoordinateSilently(json['deliveryCoordinates'], 0, _parseDoubleSilently(json['destLng'], 76.9800)),
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

  CoreOrderStatus _mapBackendStatusToCore(String? status) {
    switch (status) {
      case 'Pending':   return CoreOrderStatus.pending;
      case 'Accepted':  return CoreOrderStatus.accepted;
      case 'Confirmed': return CoreOrderStatus.confirmed;
      case 'Preparing': return CoreOrderStatus.preparing;
      case 'Assigned':  return CoreOrderStatus.assigned;
      case 'Ready':     return CoreOrderStatus.ready;
      case 'PickedUp':
      case 'Picked Up': return CoreOrderStatus.pickedUp;
      case 'OutForDelivery':
      case 'On The Way': return CoreOrderStatus.onTheWay;
      case 'Delivered': return CoreOrderStatus.delivered;
      case 'Cancelled': return CoreOrderStatus.cancelled;
      default: return CoreOrderStatus.pending;
    }
  }

  DeliveryStatus _mapStatus(CoreOrderStatus status) {
    switch (status) {
      case CoreOrderStatus.pending:   return DeliveryStatus.allocated;
      case CoreOrderStatus.accepted:  return DeliveryStatus.pickingUp;
      case CoreOrderStatus.confirmed: return DeliveryStatus.pickingUp;
      case CoreOrderStatus.preparing: return DeliveryStatus.pickingUp;
      case CoreOrderStatus.assigned:  return DeliveryStatus.pickingUp;
      case CoreOrderStatus.ready:     return DeliveryStatus.pickingUp;
      case CoreOrderStatus.pickedUp:  return DeliveryStatus.pickedUp;
      case CoreOrderStatus.onTheWay:  return DeliveryStatus.onTheWay;
      case CoreOrderStatus.delivered: return DeliveryStatus.delivered;
      case CoreOrderStatus.cancelled: return DeliveryStatus.cancelled;
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

  Future<void> _showNotification(CoreOrder order) async {
    final payment = order.paymentMethod == 'COD' ? '💸 COD' : '💳 PAID';
    await _notificationsPlugin.show(
      order.id.hashCode,
      '🚨 New Delivery Request!',
      '[$payment] Order #${order.displayId.isNotEmpty ? order.displayId : order.id.substring(0, 6)} — ${order.store.name}',
      NotificationDetails(android: _kOrderAlertDetails),
      payload: jsonEncode({
        'orderId': order.id,
        'displayId': order.displayId,
        'vendorName': order.store.name,
        'amount': order.total.toString(),
        'paymentMethod': order.paymentMethod,
      }),
    );
  }

  Future<void> _showNotificationFromSocket(Map<String, dynamic> data) async {
    final id = data['orderId']?.toString() ?? '';
    final store = data['vendorName']?.toString() ?? 'Store';
    final payment = data['paymentMethod'] == 'COD' ? '💸 COD' : '💳 PAID';
    final amount = data['amount']?.toString() ?? '0';
    final did = data['displayId']?.toString() ?? '';

    await _notificationsPlugin.show(
      id.isNotEmpty ? id.hashCode : DateTime.now().millisecondsSinceEpoch,
      '🚨 New Order — ₹$amount',
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
    try {
      final driverId = await DeliveryAuthService.getDriverId();
      final response = await http.put(
        Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'Assigned', 'driverId': driverId}),
      );
      if (response.statusCode == 200) {
        _pendingAssignment = null;
        
        await _fullSync();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Accept Error: $e');
      return false;
    }
  }

  Future<bool> declineAssignment(String orderId) async {
    try {
      final response = await http.put(
        Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/decline'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        if (!_declinedOrderIds.contains(orderId)) {
          _declinedOrderIds.add(orderId);
        }
        _pendingAssignment = null;
        _incomingRequests.removeWhere((o) => o.id == orderId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Decline Error: $e');
      return false;
    }
  }

  Future<void> acceptOrder(CoreOrder order) async => acceptAssignment(order.id);
  void declineOrder(String orderId) => declineAssignment(orderId);

  Future<void> updateOrderStatus(String orderId, DeliveryStatus status) async {
    String backendStatus = 'Assigned';
    if (status == DeliveryStatus.pickedUp) backendStatus = 'PickedUp';
    if (status == DeliveryStatus.onTheWay) backendStatus = 'OutForDelivery';
    if (status == DeliveryStatus.delivered) backendStatus = 'Delivered';

    try {
      final driverId = await DeliveryAuthService.getDriverId();

      await http.put(
        Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': backendStatus, 'driverId': driverId}),
      );

      await _fullSync();
    } catch (e) {
      debugPrint('Update Status Error: $e');
    }
  }

  Future<void> fetchDocumentStatuses() async {
    try {
      final driverId = await DeliveryAuthService.getDriverId();
      if (driverId.isEmpty) return;

      final result = await DeliveryAuthService.getDriverDocuments(driverId);
      if (result['success'] == true) {
        _documents = result['data'] ?? {};
        _approvalStatus = result['status'] ?? 'pending';
        _isOnline = result['isOnline'] ?? false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch Documents Error: $e');
    }
  }

  void updateOnlineStatus(bool online) {
    _isOnline = online;
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

  String _mapCoreStatusToBackend(CoreOrderStatus status) {
    switch (status) {
      case CoreOrderStatus.pending:   return 'Pending';
      case CoreOrderStatus.accepted:  return 'Accepted';
      case CoreOrderStatus.confirmed: return 'Confirmed';
      case CoreOrderStatus.preparing: return 'Preparing';
      case CoreOrderStatus.assigned:  return 'Assigned';
      case CoreOrderStatus.ready:     return 'Ready';
      case CoreOrderStatus.pickedUp:  return 'PickedUp';
      case CoreOrderStatus.onTheWay:  return 'OutForDelivery';
      case CoreOrderStatus.delivered: return 'Delivered';
      case CoreOrderStatus.cancelled: return 'Cancelled';
    }
  }
}
