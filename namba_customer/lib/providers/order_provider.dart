import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';
import '../services/notification_service.dart';
import 'cart_provider.dart';

import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  final List<DeliveryOrder> _orders = [];
  NotificationProvider? _notificationProvider;
  AuthProvider? _authProvider;
  static const String _boxName = 'orders_box';

  Timer? _syncTimer;
  StreamSubscription<dynamic>? _socketSubscription;
  final CustomerApiService _apiService = CustomerApiService();
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get customerId => _apiService.customerId;
  String? _lastError;
  bool _retryScheduled = false; // Prevent multiple retry timers
  String? get lastError => _lastError;

  OrderProvider() {
    _socketSubscription = _apiService.initSocket(_handleSocketUpdate, onWipeOut: () {
      print('🧹 Customer Orders Wiped! Clearing local database.');
      clearAllOrders();
    });
    _loadOrders();
    _startSync();
  }

  void _handleSocketUpdate(dynamic data) {
    print('📡 [Socket] Data Received: $data');
    if (data == null) {
      print('⚠️ [Socket] Received null data');
      return;
    }

    if (data['type'] == 'wipeout') {
      print('🧹 Customer Orders Wiped! Clearing local database.');
      clearAllOrders();
      return;
    }

    if (data['orderId'] == null) {
      print('⚠️ [Socket] Received data without orderId: $data');
      return;
    }

    // Real-time identity resolution from socket
    if (data['customer'] != null) {
      final sId = data['customer'].toString();
      if (sId != _apiService.customerId && sId.length == 24) {
        print('🔄 Identity Sync (Socket): Updating to backend ObjectId: $sId');
        setCustomerId(sId);
      }
    }

    final orderId = data['orderId'];
    print('🔍 [Socket] Processing update for order: $orderId');
    final statusString = data['status'];
    final totalAmount = data['totalAmount'];
    final customerPlatformFee = data['customerPlatformFee'];
    final deliveryCharge = data['deliveryCharge'];
    final rawSubTotal = data['subTotal'];
    final rawDiscount = data['discount'];
    
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      double? amount;
      if (totalAmount != null) {
        if (totalAmount is num) amount = totalAmount.toDouble();
        else if (totalAmount is String) amount = double.tryParse(totalAmount);
      }

      double? pFee;
      if (customerPlatformFee != null) {
        if (customerPlatformFee is num) pFee = customerPlatformFee.toDouble();
        else if (customerPlatformFee is String) pFee = double.tryParse(customerPlatformFee);
      }

      double? dFee;
      if (deliveryCharge != null) {
        if (deliveryCharge is num) dFee = deliveryCharge.toDouble();
        else if (deliveryCharge is String) dFee = double.tryParse(deliveryCharge);
      }

      double? subTotal;
      if (rawSubTotal != null) {
        if (rawSubTotal is num) subTotal = rawSubTotal.toDouble();
        else if (rawSubTotal is String) subTotal = double.tryParse(rawSubTotal);
      }

      double? discount;
      if (rawDiscount != null) {
        if (rawDiscount is num) discount = rawDiscount.toDouble();
        else if (rawDiscount is String) discount = double.tryParse(rawDiscount);
      }

      // Check for quote BEFORE any updates to totalAmount
      bool justQuoted = false;
      if (amount != null && _orders[idx].totalAmount == 0 && amount > 0 && _orders[idx].orderType != OrderType.standard) {
        justQuoted = true;
      }

      // Apply subTotal and discount immediately when quote arrives
      if (subTotal != null && subTotal > 0) _orders[idx].subTotal = subTotal;
      if (discount != null) _orders[idx].discount = discount;

      if (statusString != null) {
        OrderStatus newStatus = OrderStatus.placed;
        switch (statusString) {
          case 'Pending':   newStatus = OrderStatus.placed; break;
          case 'Accepted':  
          case 'Confirmed': newStatus = OrderStatus.accepted; break; 
          case 'Preparing': newStatus = OrderStatus.preparing; break; // Vendor Accepted
          case 'Assigned':  newStatus = OrderStatus.assigned; break;  // Admin Assigned
          case 'Ready':     newStatus = OrderStatus.ready; break;
          case 'PickedUp':  newStatus = OrderStatus.pickedUp; break;
          case 'HandedOver': newStatus = OrderStatus.pickedUp; break;
          case 'OutForDelivery': 
          case 'On The Way': newStatus = OrderStatus.outForDelivery; break;
          case 'Arrived':   newStatus = OrderStatus.arrived; break;
          case 'Delivered': newStatus = OrderStatus.delivered; break;
          case 'Cancelled': 
          case 'Rejected':  newStatus = OrderStatus.rejected; break;
        }
        updateOrderStatus(orderId, newStatus, newTotal: amount, newPlatformFee: pFee, newDeliveryFee: dFee);
      } else {
        // Just price/fee update
        bool changed = false;
        if (amount != null && _orders[idx].totalAmount != amount) {
          _orders[idx].totalAmount = amount;
          changed = true;
        }
        if (pFee != null && _orders[idx].platformFee != pFee) {
          _orders[idx].platformFee = pFee;
          changed = true;
        }
        if (dFee != null && _orders[idx].deliveryFee != dFee) {
          _orders[idx].deliveryFee = dFee;
          changed = true;
        }
        if (changed) {
          _saveToHive();
          notifyListeners();
        }
      }

      if (justQuoted) {
        NotificationService().showQuoteNotification(
          orderId: _orders[idx].id,
          storeName: _orders[idx].storeName,
          amount: amount!,
          textContent: _orders[idx].textContent,
        );
      }
    }
  }

  void _startSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // Fetch if we have a valid customerId (even if auth hasn't fully propagated)
      if (_apiService.customerId != null && _apiService.customerId!.isNotEmpty) {
        fetchOrderHistory();
      }
    });
  }



  @override
  void dispose() {
    _syncTimer?.cancel();
    _socketSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final box = await Hive.openBox(_boxName);
    final List<Map<dynamic, dynamic>> saved = box.get('list', defaultValue: [])?.cast<Map<dynamic, dynamic>>() ?? [];
    _orders.clear();
    _orders.addAll(saved.map((m) => DeliveryOrder.fromMap(m)));

    // Cleanup: Remove any existing mock orders from local storage
    if (_orders.any((o) => o.id.startsWith('mock_'))) {
      _orders.removeWhere((o) => o.id.startsWith('mock_'));
      _saveToHive();
    }
    
    notifyListeners();
    // Legacy reconciliation call removed
  }

  Future<void> _saveToHive() async {
    final box = await Hive.openBox(_boxName);
    await box.put('list', _orders.map((o) => o.toMap()).toList());
  }

  List<DeliveryOrder> get orders => _orders;
  
  String? _lastUid;
  void setProviders(NotificationProvider n, AuthProvider a) {
    _notificationProvider = n;
    _authProvider = a;
    
    if (a.uid == null) {
      if (_orders.isNotEmpty || _lastUid != null) {
        print('🆔 OrderProvider Identity cleared. Clearing local orders.');
        clearAllOrders();
        _lastUid = null;
      }
      return;
    }
    
    final bool isNewUid = a.uid != _lastUid;
    final bool isApiMismatch = _apiService.customerId != a.uid;
    
    if (isNewUid || isApiMismatch) {
      if (isNewUid && _lastUid != null) {
        print('🆔 OrderProvider Identity switched from $_lastUid to ${a.uid}. Clearing old orders.');
        clearAllOrders();
      }
      _lastUid = a.uid;
      print('🆔 OrderProvider Identity Set/Updated: ${a.uid} (isNewUid=$isNewUid, isApiMismatch=$isApiMismatch)');
      _apiService.setCustomerInfo(id: a.uid!, name: a.name, phone: a.phone);
      
      // Fetch order history whenever we get or update the identity
      Future.delayed(const Duration(milliseconds: 300), () {
        fetchOrderHistory();
      });
    }
  }

  void setCustomerId(String id) {
    _apiService.setCustomerId(id);
    _authProvider?.updateUid(id);
    _lastUid = id;
    // After customer ID is resolved, fetch order history
    Future.delayed(const Duration(milliseconds: 300), () {
      fetchOrderHistory();
    });
  }

  void joinOrderRoom(String orderId) {
    _apiService.joinOrderRoom(orderId);
  }

  List<DeliveryOrder> get activeOrders => _orders
      .where((o) =>
          !o.isDismissedFromHome &&
          o.status != OrderStatus.delivered &&
          o.status != OrderStatus.rejected && 
          o.placedAt.isAfter(DateTime.now().subtract(const Duration(hours: 24))))
      .toList();

  Future<void> dismissActiveOrders() async {
    final active = activeOrders;
    for (var o in active) {
      o.isDismissedFromHome = true;
    }
    await _saveToHive();
    notifyListeners();
  }

  Future<void> clearAllOrders() async {
    final box = await Hive.openBox(_boxName);
    await box.delete('list');
    _orders.clear();
    notifyListeners();
  }

  Future<void> fetchOrderHistory() async {
    if (_isLoadingHistory) return;
    
    final cid = _apiService.customerId;
    if (cid == null || cid.isEmpty) {
      print('⚠️ Cannot fetch history: customerId is null/empty');
      return;
    }

    _isLoadingHistory = true;
    _lastError = null;
    notifyListeners();
    print('🔄 Fetching Order History for Customer: $cid...');
    
    try {
      final List<dynamic> apiOrders = await _apiService.getCustomerOrders();
      print('📦 Received ${apiOrders.length} orders from server.');
      
      // Server returned 0 orders.
      // IMPORTANT: Do NOT clear local state just because server returns 0.
      // The backend may have been wiped, or this may be a transient issue.
      // Only trust the server when it returns actual orders.
      if (apiOrders.isEmpty) {
        _lastError = '0 orders found on server';
        print('ℹ️ Server returned 0 orders for $cid. Keeping local data intact.');
        // If customerId looks like a temp ID, schedule a retry to check again
        final isRealId = cid.length == 24;
        if (!isRealId && !_retryScheduled) {
          _retryScheduled = true;
          Future.delayed(const Duration(seconds: 5), () {
            print('🔁 Retrying fetchOrderHistory for temporary ID $cid');
            _retryScheduled = false;
            fetchOrderHistory();
          });
        }
        return;
      }

      bool changed = false;
      for (var ao in apiOrders) {
        // Real-time identity resolution: If backend returns a real ObjectId for customer, sync it locally
        if (ao['customer'] != null) {
          final sId = ao['customer'].toString();
          if (sId != _apiService.customerId && sId.length == 24) { // Typical MongoDB ObjectId length
            print('🔄 Identity Sync: Updating temporary ID to backend ObjectId: $sId');
            setCustomerId(sId);
          }
        }

        final orderId = ao['_id'] ?? ao['id'];
        final idx = _orders.indexWhere((o) => o.id == orderId);
        
        if (idx == -1) {
          // New order from server found!
          final newOrder = DeliveryOrder.fromMap(ao);
          _orders.add(newOrder);
          
          // Join socket room for live updates
          if (newOrder.status != OrderStatus.delivered && newOrder.status != OrderStatus.rejected) {
            _apiService.joinOrderRoom(newOrder.id);
          }
          changed = true;
        } else {
          // Existing order - check for status/price updates from server
          final serverOrder = DeliveryOrder.fromMap(ao);
          final localOrder = _orders[idx];

          // Ensure we are in the socket room for active orders
          if (serverOrder.status != OrderStatus.delivered && serverOrder.status != OrderStatus.rejected) {
            _apiService.joinOrderRoom(serverOrder.id);
          }
          
          // Sync all critical fields from server
          if (localOrder.status != serverOrder.status ||
              localOrder.totalAmount != serverOrder.totalAmount ||
              localOrder.subTotal != serverOrder.subTotal ||
              localOrder.discount != serverOrder.discount ||
              localOrder.isPaymentDone != serverOrder.isPaymentDone ||
              localOrder.storeName != serverOrder.storeName ||
              localOrder.deliveryPartner?.name != serverOrder.deliveryPartner?.name ||
              localOrder.deliveryPartner?.phone != serverOrder.deliveryPartner?.phone ||
              localOrder.items.any((item) => item.product.name == 'Unnamed') ||
              localOrder.platformFee != serverOrder.platformFee ||
              localOrder.deliveryFee != serverOrder.deliveryFee) {
            
            _orders[idx].status = serverOrder.status;
            _orders[idx].totalAmount = serverOrder.totalAmount;
            _orders[idx].isPaymentDone = serverOrder.isPaymentDone;
            _orders[idx].storeName = serverOrder.storeName;
            _orders[idx].storeCategory = serverOrder.storeCategory;
            _orders[idx].deliveryPartner = serverOrder.deliveryPartner;
            _orders[idx].items = serverOrder.items; // RE-SYNC ITEMS to fix 'Unnamed' issues
            _orders[idx].deliveryAddress = serverOrder.deliveryAddress;
            _orders[idx].platformFee = serverOrder.platformFee;
            _orders[idx].deliveryFee = serverOrder.deliveryFee;
            // Sync vendor quote fields
            if (serverOrder.subTotal > 0) _orders[idx].subTotal = serverOrder.subTotal;
            if (serverOrder.discount > 0) _orders[idx].discount = serverOrder.discount;
            changed = true;
          }
        }
      }

      if (changed) {
        // Sort by date (newest first)
        _orders.sort((a, b) => b.placedAt.compareTo(a.placedAt));
        print('✨ Merged ${apiOrders.length} orders. Notifying UI.');
      }
      _saveToHive();
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = 'Fetch Error: $e';
      debugPrint('❌ Error fetching order history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  void setNotificationProvider(NotificationProvider provider) {
    _notificationProvider = provider;
  }

  void _notify(DeliveryOrder order, OrderStatus status) {
    String? title;
    String? body;
    if (status == OrderStatus.rejected) {
      title = '❌ Order Cancelled';
      body = 'Order #${order.displayId.isNotEmpty ? order.displayId : order.id} from ${order.storeName} has been cancelled.';
    }

    NotificationService().showOrderNotification(
      orderId: order.id,
      status: status,
      storeName: order.storeName,
      customTitle: title,
      customBody: body,
    );
    _notificationProvider?.addNotification(
      orderId: order.id,
      status: status,
      storeName: order.storeName,
    );
  }

  void updateOrderStatus(String orderId, OrderStatus status, {double? newTotal, double? newPlatformFee, double? newDeliveryFee}) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final currentOrder = _orders[idx];
      
      bool changed = false;
      if (newTotal != null && currentOrder.totalAmount != newTotal) {
        currentOrder.totalAmount = newTotal;
        changed = true;
      }
      if (newPlatformFee != null && currentOrder.platformFee != newPlatformFee) {
        currentOrder.platformFee = newPlatformFee;
        changed = true;
      }
      if (newDeliveryFee != null && currentOrder.deliveryFee != newDeliveryFee) {
        currentOrder.deliveryFee = newDeliveryFee;
        changed = true;
      }

      // If status changed, update it via _updateStatus
      if (status != currentOrder.status) {
        // Prevent status downgrades
        if (currentOrder.status == OrderStatus.delivered || currentOrder.status == OrderStatus.rejected) {
          if (changed) {
            _saveToHive();
            notifyListeners();
          }
          return;
        }
        if (status.index < currentOrder.status.index) {
          if (changed) {
            _saveToHive();
            notifyListeners();
          }
          return;
        }

        if (status == OrderStatus.accepted && currentOrder.deliveryPartner == null) {
          _orders[idx].deliveryPartner = DeliveryPartner(
            name: 'Rajan Kumar',
            phone: '+919876543299',
            rating: 4.7,
            vehicleType: 'Bike',
            vehicleNumber: 'TN 01 AB 1234',
          );
        }
        _updateStatus(_orders[idx], status);
      } else if (changed) {
        _saveToHive();
        notifyListeners();
      }
    }
  }

  Future<bool> markPaymentDone(String orderId, String paymentMethod) async {
    print('💳 Attempting to mark payment done for order: $orderId');
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      print('✅ Order found in local state at index $idx');
      final order = _orders[idx];
      order.isPaymentDone = true;
      
      _saveToHive();
      notifyListeners();

      // 📡 Sync with Live Backend
      Map<String, dynamic> updatePayload = {
        'paymentMethod': paymentMethod,
        'paymentStatus': 'Completed',
      };

      final success = await _apiService.updateOrder(orderId, updatePayload);
      print('🌐 Backend Sync Success: $success');
      return success;
    }
    print('❌ Order NOT found in local state! IDs available: ${_orders.map((o) => o.id).toList()}');
    return false;
  }

  Future<bool> markPaymentFailed(String orderId, String paymentMethod) async {
    print('💳 Attempting to mark payment failed for order: $orderId');
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      print('✅ Order found in local state at index $idx');
      final order = _orders[idx];
      order.isPaymentDone = false;
      
      _saveToHive();
      notifyListeners();

      // 📡 Sync with Live Backend
      Map<String, dynamic> updatePayload = {
        'paymentMethod': paymentMethod,
        'paymentStatus': 'Failed',
      };

      final success = await _apiService.updateOrder(orderId, updatePayload);
      print('🌐 Backend Sync Success (Failed Payment): $success');
      return success;
    }
    return false;
  }

  void _updateStatus(DeliveryOrder order, OrderStatus status) {
    // Prevent redundant notifications
    if (order.status == status) return;
    
    // Prevent status downgrades
    if (order.status == OrderStatus.delivered || order.status == OrderStatus.rejected) return;
    if (status.index < order.status.index) return;

    order.status = status;
    order.statusTimestamps[status] = DateTime.now();
    _notify(order, status);
    
    // Add reward points on delivery
    if (status == OrderStatus.delivered && _authProvider != null) {
      _authProvider!.addPoints(order.totalAmount);
    }
    _saveToHive();
    // NOTE: We do NOT sync back to shared DB here to avoid overwriting vendor's data.
    // The vendor app is the source of truth for order status updates.
    // Only initial order placement syncs to shared DB (see placeSpecialOrder).
    notifyListeners();
  }



  void reorder(String orderId, CartProvider cart) {
    final order = _orders.firstWhere((o) => o.id == orderId);
    
    // Ensure we are in the socket room for this order for live updates
    if (order.status != OrderStatus.delivered && order.status != OrderStatus.rejected) {
      Future.microtask(() => joinOrderRoom(orderId));
    }
    cart.clear(); 
    for (var item in order.items) {
      for (int i = 0; i < item.quantity; i++) {
        cart.addItem(item.product, storeName: order.storeName);
      }
    }
  }

  Future<DeliveryOrder> placeOrder({
    required String storeId,
    required String storeName,
    required String storeCategory,
    required List<CartItem> items,
    required double total,
    required String address,
    double? lat,
    double? lng,
  }) async {
    if (storeId.isEmpty) {
      debugPrint('❌ CRITICAL ERROR: storeId is empty! Cannot place order.');
      throw Exception('Vendor ID is missing. Please try adding items again.');
    }

    // Call Live Backend
    final createdData = await _apiService.placeOrder(
      vendorId: storeId,
      items: items.map((i) => {
        'productName': i.product.name,
        'quantity': i.quantity,
        'price': i.product.price
      }).toList(),
      totalAmount: total,
      deliveryCharge: 30,
      paymentMethod: 'ONLINE',
      deliveryCoordinates: (lat != null && lng != null) ? {'lat': lat, 'lng': lng} : null,
      deliveryAddress: address,
      customerNameOverride: _authProvider?.name,
      customerPhoneOverride: _authProvider?.phone,
    );
     
    if (createdData == null) {
      throw Exception('Server Connection Failed. Please check your internet connection and server IP address.');
    }
    final orderId = createdData['_id'];
    final displayId = createdData != null ? createdData['displayId'] : (orderId.length > 6 ? '#${orderId.substring(orderId.length - 6)}' : orderId);

    final order = DeliveryOrder(
      id: orderId,
      displayId: displayId,
      storeId: storeId,
      storeName: storeName,
      storeCategory: storeCategory,
      items: List.from(items),
      status: OrderStatus.placed,
      totalAmount: total,
      placedAt: DateTime.now(),
      deliveryAddress: address,
      statusTimestamps: {OrderStatus.placed: DateTime.now()},
    );
    _orders.insert(0, order);
    _saveToHive();
    
    // We can still write it locally, but the truth is backend!

    notifyListeners();

    return order;
  }

  Future<DeliveryOrder> placeSpecialOrder({
    required Store store,
    required String address,
    double? lat,
    double? lng,
    OrderType type = OrderType.text,
    String? content,
    String? photoPath,
    String paymentMethod = 'ONLINE',
  }) async {
    String? finalPhotoUrl;
    
    // Upload photo if it's a photo order
    if (type == OrderType.photo && photoPath != null) {
      finalPhotoUrl = await _apiService.uploadImage(photoPath);
    }

    final createdData = await _apiService.placeOrder(
      vendorId: store.id,
      totalAmount: 0, // Quote will come later
      deliveryCharge: 30,
      paymentMethod: paymentMethod,
      orderType: type == OrderType.text ? 'Text' : 'Photo',
      textContent: content,
      photoUrl: finalPhotoUrl,
      deliveryCoordinates: (lat != null && lng != null) ? {'lat': lat, 'lng': lng} : null,
      deliveryAddress: address,
      customerNameOverride: _authProvider?.name,
      customerPhoneOverride: _authProvider?.phone,
    );

    if (createdData == null) {
      throw Exception('Server Connection Failed. Please check your internet connection and server IP address.');
    }
    final orderId = createdData['_id'];
    final displayId = createdData != null ? createdData['displayId'] : (orderId.length > 6 ? '#${orderId.substring(orderId.length - 6)}' : orderId);

    final order = DeliveryOrder(
      id: orderId,
      displayId: displayId,
      storeId: store.id,
      storeName: store.name,
      storeCategory: store.category,
      items: [],
      status: OrderStatus.placed,
      orderType: type,
      textContent: content,
      photoPath: photoPath,
      totalAmount: 0,
      placedAt: DateTime.now(),
      deliveryAddress: address,
    );

    _orders.insert(0, order);
    _apiService.joinOrderRoom(order.id);
    _saveToHive();

    notifyListeners();
    return order;
  }

  void submitRating(String orderId, double rating, String review) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      _orders[idx].userRating = rating;
      _orders[idx].userReview = review;
      _saveToHive();
      notifyListeners();
    }
  }

  Future<DeliveryOrder> placeCustomOrder({
    required String customStoreName,
    required String customStoreAddress,
    required String userAddress,
    double? lat,
    double? lng,
    OrderType type = OrderType.text,
    String? content,
    String? photoPath,
    String paymentMethod = 'ONLINE',
  }) async {
    String? finalPhotoUrl;
    
    // Upload photo if it's a photo order
    if (type == OrderType.photo && photoPath != null) {
      finalPhotoUrl = await _apiService.uploadImage(photoPath);
    }

    // Call Live Backend with special "Custom" type
    final createdData = await _apiService.placeOrder(
      vendorId: 'CUSTOM_SHOP',
      totalAmount: 0,
      deliveryCharge: 30,
      paymentMethod: paymentMethod,
      orderType: type == OrderType.text ? 'Text' : 'Photo',
      textContent: '[ANY SHOP ORDER] $customStoreName @ $customStoreAddress\n\n$content',
      photoUrl: finalPhotoUrl,
      deliveryCoordinates: (lat != null && lng != null) ? {'lat': lat, 'lng': lng} : null,
      deliveryAddress: userAddress,
      isCustomStore: true,
      customStoreName: customStoreName,
      customStoreAddress: customStoreAddress,
      customerNameOverride: _authProvider?.name,
      customerPhoneOverride: _authProvider?.phone,
    );

    if (createdData == null) {
      throw Exception('Server Connection Failed. Please check your internet connection and server IP address.');
    }
    final orderId = createdData['_id'];
    final displayId = createdData != null ? createdData['displayId'] : (orderId.length > 6 ? '#${orderId.substring(orderId.length - 6)}' : orderId);

    final order = DeliveryOrder(
      id: orderId,
      displayId: displayId,
      storeId: 'CUSTOM_SHOP',
      storeName: customStoreName,
      storeCategory: 'Any Shop',
      items: [],
      status: OrderStatus.placed,
      orderType: type,
      textContent: content,
      photoPath: photoPath,
      totalAmount: 0,
      placedAt: DateTime.now(),
      deliveryAddress: userAddress,
      isCustomStore: true,
      customStoreName: customStoreName,
      customStoreAddress: customStoreAddress,
    );

    _orders.insert(0, order);
    _saveToHive();

    notifyListeners();
    return order;
  }
}
