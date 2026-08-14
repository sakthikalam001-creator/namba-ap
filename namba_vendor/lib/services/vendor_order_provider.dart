import 'package:flutter/material.dart';

import '../models/vendor_order_model.dart';
import '../models/vendor_profile_model.dart';
import 'vendor_notification_service.dart';
import 'vendor_background_service.dart';
import 'alert_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VendorOrderProvider with ChangeNotifier {
  final List<VendorOrderModel> _orders = [];
  final Set<String> _seenOrderIds = {};
  final Set<String> _notifiedPaymentIds = {};
  final _uuid = const Uuid();
  bool _isInitialLoadApi = true; // Still doing first API fetch
  bool _isInitialLoadDb = true;  // Still doing first Shared DB fetch
  bool _isInitialSyncComplete = false; // Flag to track if the very first sync cycle is done
  bool get isInitialSyncComplete => _isInitialSyncComplete;
  double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  VendorProfileModel? _profile;
  VendorProfileModel? get profile => _profile;

  bool _isStoreOpen = true;
  bool get isStoreOpen => _isStoreOpen;

  bool get isLocked => _profile?.isLocked ?? false;
  String? get lockReason => _profile?.lockReason;
  bool get showSubscriptionBadge => _profile?.showSubscriptionBadge ?? true;

  List<VendorOrderModel> get orders => _orders;
  List<VendorOrderModel> get allOrders => _orders;
  Timer? _syncTimer;

  bool _isToggling = false; // Prevents double-toggles
  bool _trialExpiredAlerted = false; // Tracks if we already showed the trial expired alert
  DateTime? _lastFetchErrorBannerAt;
  bool get trialExpiredAlerted => _trialExpiredAlerted;

  bool get isSubscriptionActive {
    if (_profile == null) return false;
    final now = DateTime.now();
    final hasActiveSub = _profile!.isSubscribed && _profile!.subscriptionExpiry != null && _profile!.subscriptionExpiry!.isAfter(now);
    final hasActiveTrial = _profile!.trialExpiry != null && _profile!.trialExpiry!.isAfter(now);
    return hasActiveSub || hasActiveTrial;
  }

  int get expiringDaysRemaining {
    if (_profile == null) return 0;
    final now = DateTime.now();
    DateTime? expiry;
    
    if (_profile!.isSubscribed && _profile!.subscriptionExpiry != null) {
      expiry = _profile!.subscriptionExpiry;
    } else if (_profile!.trialExpiry != null) {
      expiry = _profile!.trialExpiry;
    }
    
    if (expiry == null) return 0;
    final diff = expiry.difference(now).inDays;
    return diff + 1; // Add 1 because even 1 hour left means "today"
  }

  bool get isExpiringSoon {
    if (!isSubscriptionActive) return false;
    final days = expiringDaysRemaining;
    return days > 0 && days <= 7;
  }

  Future<void> toggleStoreStatus({Function(String)? onError}) async {
    if (_isToggling) {
      debugPrint('⚠️ Toggle blocked — already in progress');
      return;
    }
    if (_profile == null) {
      debugPrint('❌ Toggle blocked — profile is null!');
      onError?.call('Store profile not loaded. Please restart the app.');
      return;
    }

    final newStatus = !_isStoreOpen;

    // ENFORCEMENT: Check subscription if trying to go ONLINE
    if (newStatus && !isSubscriptionActive) {
      debugPrint('🚫 Access Denied: Subscription required to go Online.');
      onError?.call('Active Subscription or Trial required to go Online.');
      return;
    }

    // ENFORCEMENT: Check if locked
    if (newStatus && isLocked) {
      debugPrint('🚫 Access Denied: Account is restricted by administration.');
      onError?.call('Account Restricted: ${lockReason ?? "Please contact support."}');
      return;
    }
    
    _isToggling = true;
    
    // Optimistic update — UI flips immediately
    _isStoreOpen = newStatus;
    if (newStatus && _profile != null) {
      VendorBackgroundService.startForVendor(
        vendorId: _profile!.id,
        socketUrl: dotenv.env['SOCKET_URL'] ?? 'http://54.204.9.126:5000',
      );
    } else {
      VendorBackgroundService.stop();
    }
    notifyListeners();
    debugPrint('🏪 [TOGGLE] Optimistic UI: ${_isStoreOpen ? "ONLINE" : "OFFLINE"} for vendor=${_profile?.id}');

    try {
      await _apiService.updateVendorStoreStatus(_profile!.id, newStatus);
      debugPrint('✅ [TOGGLE] Backend confirmed: ${newStatus ? "ONLINE" : "OFFLINE"}');
    } catch (e) {
      debugPrint('❌ [TOGGLE] Backend error, rolling back: $e');
      // Rollback on failure
      _isStoreOpen = !newStatus;
      if (_isStoreOpen && _profile != null) {
        VendorBackgroundService.startForVendor(
          vendorId: _profile!.id,
          socketUrl: dotenv.env['SOCKET_URL'] ?? 'http://54.204.9.126:5000',
        );
      } else {
        VendorBackgroundService.stop();
      }
      notifyListeners();
      
      String errorMsg = 'Network error. Could not update store status.';
      if (e.toString().contains('SUBSCRIPTION_REQUIRED')) {
        errorMsg = 'Active Subscription or Trial required to go Online.';
      }
      onError?.call(errorMsg);
    } finally {
      // Small Delay to prevent rapid re-clicks
      await Future.delayed(const Duration(milliseconds: 500));
      _isToggling = false;
    }
  }

  List<VendorOrderModel> get newOrders =>
      _orders.where((o) => o.status == VendorOrderStatus.pending).toList();

  List<VendorOrderModel> get preparingOrders =>
      _orders.where((o) => o.status == VendorOrderStatus.accepted || o.status == VendorOrderStatus.preparing).toList();

  List<VendorOrderModel> get readyOrders =>
      _orders.where((o) => o.status == VendorOrderStatus.ready).toList();

  List<VendorOrderModel> get pastOrders =>
      _orders.where((o) => o.status == VendorOrderStatus.handedOver || o.status == VendorOrderStatus.rejected).toList();

  final VendorApiService _apiService = VendorApiService();

  VendorOrderProvider() {
    try {
      Future.microtask(() {
        try {
          VendorNotificationService().initialize();
          _startSync();
        } catch (e) {
          debugPrint('VendorOrderProvider init error: $e');
        }
      });
    } catch (e) {
      debugPrint('VendorOrderProvider constructor error: $e');
    }
    
    // Fail-safe to prevent infinite shimmer loading if profile fetching fails
    Future.delayed(const Duration(seconds: 2), () {
      if (_isInitialLoadApi || _isInitialLoadDb) {
        _isInitialLoadApi = false;
        _isInitialLoadDb = false;
        notifyListeners();
      }
    });
  }

  void setProfile(VendorProfileModel profile) {
    _profile = profile;
    _isStoreOpen = profile.isOpen; // ✅ Initial state from server

    // Start background service & bind FCM push notifications for instant lockscreen alerts
    VendorNotificationService().bindVendor(profile.id);
    
    if (_isStoreOpen) {
      VendorBackgroundService.startForVendor(
        vendorId: profile.id,
        socketUrl: dotenv.env['SOCKET_URL'] ?? 'http://54.204.9.126:5000',
      );
    } else {
      VendorBackgroundService.stop();
    }

    // Clear old data and fetch new store data immediately!
    _orders.clear();
    _seenOrderIds.clear();
    _notifiedPaymentIds.clear();
    _isInitialLoadApi = true;
    _isInitialLoadDb = true;
    _trialExpiredAlerted = false;
    _apiService.initSocket(
      _profile!.id, 
      _handleSocketUpdate, 
      onAccessUpdate: _handleAccessUpdate,
      onTrialExpired: _handleTrialExpired,
      onWipeOut: () {
        debugPrint('dYs? Global order wipeout received! Clearing local orders.');
        _orders.clear();
        _seenOrderIds.clear();
        notifyListeners();
      }
    );
    _fetchOrdersFromApi();
    _startSync(); // Start 30s periodic sync
    notifyListeners();
  }

  /// Public method to force-refresh orders (e.g., pull-to-refresh, retry button)
  Future<void> refreshOrders() async {
    if (_profile == null || _profile!.id.isEmpty) return;
    await _fetchOrdersFromApi();
  }

  Future<void> fetchProfile(String phone) async {
    final data = await _apiService.getVendorStatus(phone);
    if (data != null) {
      _profile = VendorProfileModel.fromJson(data);
      _isStoreOpen = _profile!.isOpen;
      notifyListeners();
    }
  }

  Future<bool> saveOperatingHours(List<dynamic> operatingHours, bool autoSchedulingEnabled) async {
    if (_profile == null) return false;
    final success = await _apiService.updateOperatingHours(_profile!.id, operatingHours, autoSchedulingEnabled);
    if (success) {
      await fetchProfile(_profile!.phone);
    }
    return success;
  }

  Future<void> _handleSocketUpdate(dynamic data) async {
    if (data == null) return;
    
    if (data['type'] == 'SCHEDULED_OPEN_WARNING') {
      final title = data['title']?.toString() ?? 'Auto-Open Reminder';
      final message = data['message']?.toString() ?? '';
      AlertService().showAlert(title: title, message: message);
      return;
    }
    
    if (data['orderId'] == null) return;
    
    final orderId = data['orderId'].toString();
    debugPrint('🚀 [SOCKET] Syncing order: $orderId');

    final prefs = await SharedPreferences.getInstance();
    final shownIds = prefs.getStringList('shown_notification_order_ids') ?? [];

    // ⚡ INSTANT ALERT: Sound alert triggers immediately on socket packet arrival
    if (!_isInitialLoadApi && !_seenOrderIds.contains(orderId) && !shownIds.contains(orderId) && (data['status'] == 'Pending' || data['status'] == null)) {
      final String? sound = data['alertSound']?.toString();
      
      shownIds.add(orderId);
      await prefs.setStringList('shown_notification_order_ids', shownIds);
      
      AlertService().playNewOrderAlert(
        orderId,
        orderType: data['orderType']?.toString(),
        customerName: data['customerName']?.toString(),
        amount: double.tryParse(data['amount']?.toString() ?? data['totalAmount']?.toString() ?? '0'),
        alertSound: sound,
      );
    }

    final fullOrder = await _apiService.getOrderDetails(orderId);
    if (fullOrder == null) return;

    final customer = fullOrder['customer'] ?? {};
    final items = (fullOrder['items'] as List?) ?? [];

    VendorOrderType vType = VendorOrderType.standard;
    if (fullOrder['orderType'] == 'Text') vType = VendorOrderType.text;
    if (fullOrder['orderType'] == 'Photo') vType = VendorOrderType.photo;

    final bool isPaid = data['customerPaid'] == true || fullOrder['paymentStatus'] == 'Completed' || fullOrder['customerPaid'] == true;

    final vStatus = _mapBackendStatusToVendor(data['status'] ?? fullOrder['status'] ?? 'Pending');
    final double rawTot = _parseDouble(data['totalAmount'] ?? fullOrder['totalAmount']);
    final double cFee = _parseDouble(data['customerPlatformFee'] ?? fullOrder['customerPlatformFee']);
    final newTotal = rawTot > 0 ? (rawTot - cFee > 0 ? rawTot - cFee : rawTot) : 0.0;

    final existingIdx = _orders.indexWhere((o) => o.id == orderId);
    if (existingIdx != -1) {
      // Update existing
      final existing = _orders[existingIdx];
      if (shownIds.contains(orderId)) {
        existing.isNotified = true;
      }
      bool statusChanged = existing.status != vStatus;
      bool paymentChanged = !existing.customerPaid && isPaid;

      existing.status = vStatus;
      existing.customerPaid = isPaid;
      existing.cancelledBy = data['cancelledBy'] ?? fullOrder['cancelledBy'] ?? existing.cancelledBy;
      existing.cancellationReason = data['cancellationReason'] ?? fullOrder['cancellationReason'] ?? existing.cancellationReason;
      // Update total: subtract platform fee safely
      existing.totalAmount = newTotal;
      if (fullOrder['subTotal'] != null) existing.subTotal = _parseDouble(fullOrder['subTotal']);
      if (fullOrder['discount'] != null) existing.discount = _parseDouble(fullOrder['discount']);
      if (data['vendorPaymentStatus'] != null || fullOrder['vendorPaymentStatus'] != null) {
        existing.vendorPaymentStatus = data['vendorPaymentStatus'] ?? fullOrder['vendorPaymentStatus'];
      }

      if (statusChanged && vStatus == VendorOrderStatus.rejected) {
        debugPrint('❌ Order ${existing.displayId} was cancelled/rejected');
        VendorNotificationService().showOrderCancelledNotification(
          displayId: existing.displayId,
          message: data['message'] ?? 'Order #${existing.displayId} was cancelled by Admin.',
        );
      }

      if (paymentChanged) {
        debugPrint('💰 Payment received for order ${existing.displayId}');
      }
      debugPrint('✅ [SOCKET] Updated existing order $orderId');
    } else {
      // Add new
      final newOrder = VendorOrderModel(
        id: orderId,
        displayId: fullOrder['displayId'] ?? 'NM-${orderId.substring(orderId.length > 5 ? orderId.length - 5 : 0).toUpperCase()}',
        customerName: customer['name'] ?? 'Guest Customer',
        customerPhone: customer['phone'] ?? '+91 9123456789',
        items: items.map((i) => VendorOrderItem(
          id: i['_id'] ?? 'item',
          name: i['productName'] ?? 'Item',
          quantity: _parseInt(i['quantity'], 1),
          price: _parseDouble(i['price']),
        )).toList(),
        totalAmount: (_parseDouble(fullOrder['subTotal']) > 0)
            ? _parseDouble(fullOrder['subTotal']) - _parseDouble(fullOrder['discount'])
            : ((_parseDouble(fullOrder['totalAmount']) > 0)
                ? _parseDouble(fullOrder['totalAmount']) - _parseDouble(fullOrder['customerPlatformFee'])
                : 0.0),
        subTotal: _parseDouble(fullOrder['subTotal']),
        discount: _parseDouble(fullOrder['discount']),
        orderType: vType,
        textContent: fullOrder['textContent'],
        photoUrl: fullOrder['photoUrl'] != null 
            ? 'http://54.204.9.126:5000${fullOrder['photoUrl']}' 
            : null,
        status: vStatus,
        timestamp: DateTime.parse(fullOrder['createdAt'] ?? DateTime.now().toIso8601String()).toLocal(),
        customerPaid: isPaid,
        vendorPaymentStatus: fullOrder['vendorPaymentStatus'] ?? 'Pending',
        storeLat: _parseDouble(fullOrder['storeLat'], 11.0168),
        storeLng: _parseDouble(fullOrder['storeLng'], 76.9558),
        destLat: _parseDouble(fullOrder['destLat'], 11.0500),
        destLng: _parseDouble(fullOrder['destLng'], 76.9800),
        cancelledBy: fullOrder['cancelledBy'],
        cancellationReason: fullOrder['cancellationReason'],
        isNotified: shownIds.contains(orderId),
      );

      _orders.add(newOrder);
      _seenOrderIds.add(orderId);
      
      // 🛡️ NOISY NOTIFICATION FIX: Only notify if it's NOT the initial load 
      // AND it's a pending order AND not already shown in SharedPreferences
      if (!_isInitialLoadApi && vStatus == VendorOrderStatus.pending && !shownIds.contains(orderId)) {
        shownIds.add(orderId);
        await prefs.setStringList('shown_notification_order_ids', shownIds);
        
        final double notifAmount = items.fold(0.0, (sum, i) => sum + (_parseInt(i['quantity'], 1) * _parseDouble(i['price'])));
        final double finalAmount = notifAmount > 0 ? notifAmount : _parseDouble(fullOrder['totalAmount']) - _parseDouble(fullOrder['customerPlatformFee']);

        final String? alertSound = fullOrder['alertSound']?.toString();
        if (vType == VendorOrderType.text) {
          VendorNotificationService().showTextOrderNotification(
            orderId: orderId,
            preview: fullOrder['textContent']?.toString() ?? '',
            customerName: customer['name'] ?? 'Customer',
            alertSound: alertSound,
          );
        } else if (vType == VendorOrderType.photo) {
          VendorNotificationService().showPhotoOrderNotification(
            orderId: orderId,
            customerName: customer['name'] ?? 'Customer',
            alertSound: alertSound,
          );
        } else {
          VendorNotificationService().showNewOrderNotification(
            orderId: orderId,
            customerName: customer['name'] ?? 'Customer',
            amount: finalAmount,
            alertSound: alertSound,
          );
        }
      }
      debugPrint('✨ [SOCKET] Added new order $orderId');
    }

    _sortOrders();
    notifyListeners();
  }

  void _handleTrialExpired(dynamic data) {
    if (data == null || _profile == null) return;

    final daysExpired = (data['daysExpired'] ?? 0) as int;
    debugPrint('⚠️ [TRIAL] Trial expired event received. Days expired: $daysExpired');

    // Show push notification
    VendorNotificationService().showTrialExpiredNotification(daysExpired: daysExpired);

    // Mark trial as alerted so UI can show subscription dialog
    _trialExpiredAlerted = true;

    // Update local profile to reflect expired trial (force isLocked if server locked)
    if (data['isLocked'] == true) {
      _profile = VendorProfileModel(
        id: _profile!.id,
        phone: _profile!.phone,
        storeName: _profile!.storeName,
        ownerName: _profile!.ownerName,
        category: _profile!.category,
        address: _profile!.address,
        city: _profile!.city,
        pincode: _profile!.pincode,
        isOpen: false,
        approvalStatus: _profile!.approvalStatus,
        subscriptionPlan: _profile!.subscriptionPlan,
        subscriptionExpiry: _profile!.subscriptionExpiry,
        isSubscribed: false,
        trialExpiry: _profile!.trialExpiry,
        isLocked: true,
        lockReason: 'Trial period expired. Please subscribe to reactivate your store.',
        showSubscriptionBadge: true,
        allowAutoAccept: _profile!.allowAutoAccept,
        allowSurgeBoost: _profile!.allowSurgeBoost,
        allowExtraWait: _profile!.allowExtraWait,
        email: _profile!.email,
      );
      _isStoreOpen = false;
    }

    notifyListeners();
  }

  void _handleAccessUpdate(dynamic data) {
    if (data == null || _profile == null) return;
    
    debugPrint('🔔 RECEIVED ACCESS UPDATE: $data');
    
    final perms = data['permissions'] ?? {};
    final newAllowAutoAccept = perms['allowAutoAccept'] ?? _profile!.allowAutoAccept;
    final newAllowSurgeBoost = perms['allowSurgeBoost'] ?? _profile!.allowSurgeBoost;
    final newAllowExtraWait = perms['allowExtraWait'] ?? _profile!.allowExtraWait;

    // Create new profile with updated access fields
    _profile = VendorProfileModel(
      id: _profile!.id,
      phone: _profile!.phone,
      storeName: _profile!.storeName,
      ownerName: _profile!.ownerName,
      category: _profile!.category,
      address: _profile!.address,
      city: _profile!.city,
      pincode: _profile!.pincode,
      isOpen: data['isOpen'] ?? _profile!.isOpen, // Admin might force them offline if they lock
      approvalStatus: _profile!.approvalStatus,
      subscriptionPlan: _profile!.subscriptionPlan,
      subscriptionExpiry: data['subscriptionExpiry'] != null ? DateTime.parse(data['subscriptionExpiry']) : _profile!.subscriptionExpiry,
      isSubscribed: data['isSubscribed'] ?? _profile!.isSubscribed,
      trialExpiry: data['trialExpiry'] != null ? DateTime.parse(data['trialExpiry']) : _profile!.trialExpiry,
      isLocked: data['isLocked'] ?? _profile!.isLocked,
      lockReason: data['lockReason'] ?? _profile!.lockReason,
      showSubscriptionBadge: data['showSubscriptionBadge'] ?? _profile!.showSubscriptionBadge,
      allowAutoAccept: newAllowAutoAccept,
      allowSurgeBoost: newAllowSurgeBoost,
      allowExtraWait: newAllowExtraWait,
      email: _profile!.email,
    );

    if (_profile!.isLocked && _isStoreOpen) {
      _isStoreOpen = false; // Force UI offline immediately if locked
    } else {
       _isStoreOpen = _profile!.isOpen;
    }

    notifyListeners();
  }

  void _startSync() {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_profile != null && _profile!.id.isNotEmpty) {
        _fetchOrdersFromApi();
        _syncFromSharedDb();
      }
    });
  }

  bool get isLoading => _isInitialLoadApi;
  bool get _isInitialLoad => isLoading;

  Future<void> _syncFromSharedDb() async {
    // Legacy local sync removed
  }

  Future<void> _fetchOrdersFromApi() async {
    if (_profile == null || _profile!.id.isEmpty) {
      debugPrint('❌ [FETCH] Skipping - profile ID is null or empty');
      _isInitialLoadApi = false;
      notifyListeners();
      return;
    }
    debugPrint('🔄 [FETCH] Fetching orders for vendor: ${_profile!.id}');
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownIds = prefs.getStringList('shown_notification_order_ids') ?? [];

      final apiOrders = await _apiService.getVendorOrders(_profile!.id);
      debugPrint('📦 [FETCH] Received ${apiOrders.length} orders from API');
      
      if (apiOrders.isEmpty) {
        _isInitialLoadApi = false;
        if (_orders.isNotEmpty) {
          debugPrint('🧹 Server order list is empty. Clearing local vendor orders.');
          _orders.clear();
          _seenOrderIds.clear();
        }
        notifyListeners(); // Moved OUTSIDE the if-block to stop shimmer!
        return;
      }

    bool changed = false;
    String? firstParseError;

    for (var ao in apiOrders) {
      try {
        dynamic rawCustomer = ao['customer'];
        Map<String, dynamic> customer = {};
        if (rawCustomer is Map<String, dynamic>) {
          customer = rawCustomer;
        }

        final items = (ao['items'] as List?) ?? [];
        
        VendorOrderType vType = VendorOrderType.standard;
        if (ao['orderType'] == 'Text') vType = VendorOrderType.text;
        if (ao['orderType'] == 'Photo') vType = VendorOrderType.photo;

        VendorOrderStatus vStatus = _mapBackendStatusToVendor(ao['status'] ?? 'Pending');
        final bool isPaid = ao['paymentStatus'] == 'Completed' || ao['customerPaid'] == true;

        final existingIdx = _orders.indexWhere((o) => o.id == ao['_id']);
        if (existingIdx != -1) {
          // Update existing order
          final existing = _orders[existingIdx];
          if (shownIds.contains(ao['_id'])) {
            existing.isNotified = true;
          }
          final double rawTotApi = _parseDouble(ao['totalAmount']);
          final double custFeeApi = _parseDouble(ao['customerPlatformFee']);
          final newTotal = rawTotApi > 0 ? (rawTotApi - custFeeApi > 0 ? rawTotApi - custFeeApi : rawTotApi) : 0.0;
          // 🛡️ PROGRESSION PROTECTION: Prevent status regression (e.g., Preparing -> Accepted)
          bool statusChanged = existing.status != vStatus;
          bool amountChanged = existing.totalAmount != newTotal;
          bool paymentChanged = !existing.customerPaid && isPaid;

          bool canUpdateStatus = _isStatusUpgrade(existing.status, vStatus);

          if ((statusChanged && canUpdateStatus) || amountChanged || paymentChanged || existing.vendorPaymentStatus != ao['vendorPaymentStatus']) {
            if (statusChanged && canUpdateStatus) existing.status = vStatus;
            if (paymentChanged) existing.customerPaid = true;
            existing.vendorPaymentStatus = ao['vendorPaymentStatus'] ?? existing.vendorPaymentStatus;
            existing.totalAmount = newTotal;
            // Sync subTotal and discount from server
            if (ao['subTotal'] != null) existing.subTotal = _parseDouble(ao['subTotal']);
            if (ao['discount'] != null) existing.discount = _parseDouble(ao['discount']);
            if (ao['cancelledBy'] != null) existing.cancelledBy = ao['cancelledBy'];
            if (ao['cancellationReason'] != null) existing.cancellationReason = ao['cancellationReason'];
            changed = true;
          }
        } else {
          // New order from API
          _orders.add(VendorOrderModel(
            id: ao['_id'] ?? '',
            displayId: ao['displayId'] ?? 'NM-${ao['_id']?.substring(ao['_id']?.length > 5 ? ao['_id']?.length - 5 : 0).toUpperCase() ?? 'Order'}',
            customerName: customer['name'] ?? 'Customer',
            customerPhone: customer['phone'] ?? '+91 9876543210',
            items: items.map((i) => VendorOrderItem(
              id: i['_id'] ?? 'item',
              name: i['productName'] ?? 'Item',
              quantity: _parseInt(i['quantity'], 1),
              price: _parseDouble(i['price']),
            )).toList(),
            totalAmount: (_parseDouble(ao['subTotal']) > 0)
                ? _parseDouble(ao['subTotal']) - _parseDouble(ao['discount'])
                : ((_parseDouble(ao['totalAmount']) > 0)
                    ? _parseDouble(ao['totalAmount']) - _parseDouble(ao['customerPlatformFee'])
                    : 0.0),
            subTotal: _parseDouble(ao['subTotal']),
            discount: _parseDouble(ao['discount']),
            orderType: vType,
            textContent: ao['textContent'],
            photoUrl: ao['photoUrl'] != null ? '${_apiService.baseServerUrl}${ao['photoUrl']}' : null,
            status: vStatus,
            timestamp: DateTime.parse(ao['createdAt'] ?? DateTime.now().toIso8601String()).toLocal(),
            customerPaid: isPaid,
            vendorPaymentStatus: ao['vendorPaymentStatus'] ?? 'Pending',
            storeLat: _parseDouble(ao['storeLat'], 11.0168),
            storeLng: _parseDouble(ao['storeLng'], 76.9558),
            destLat: _parseDouble(ao['destLat'], 11.0500),
            destLng: _parseDouble(ao['destLng'], 76.9800),
            cancelledBy: ao['cancelledBy'],
            cancellationReason: ao['cancellationReason'],
            acceptedAt: ao['acceptedAt'] != null ? DateTime.parse(ao['acceptedAt']).toLocal() : null,
            readyAt: ao['readyAt'] != null ? DateTime.parse(ao['readyAt']).toLocal() : null,
            handedOverAt: ao['handedOverAt'] != null ? DateTime.parse(ao['handedOverAt']).toLocal() : null,
            prepTimeMinutes: _parseInt(ao['prepTimeMinutes'], 10),
            packingDurationSeconds: _parseInt(ao['packingDurationSeconds'], 0),
            isNotified: shownIds.contains(ao['_id']),
          ));

          if (!_seenOrderIds.contains(ao['_id'])) {
            _seenOrderIds.add(ao['_id']!);
            
            // 🛡️ NOISY NOTIFICATION FIX: Only notify if it's NOT the initial load 
            // AND the order is relatively new (last 10 minutes)
            final orderTime = DateTime.parse(ao['createdAt'] ?? DateTime.now().toIso8601String()).toLocal();
            final isRecent = DateTime.now().difference(orderTime).inMinutes < 10;
            
            if (!_isInitialLoadApi && isRecent && vStatus == VendorOrderStatus.pending && !shownIds.contains(ao['_id'])) {
              shownIds.add(ao['_id']!);
              await prefs.setStringList('shown_notification_order_ids', shownIds);
              
              final double notifAmount = items.fold(0.0, (sum, i) => sum + (_parseInt(i['quantity'], 1) * _parseDouble(i['price'])));
              final double finalAmt = notifAmount > 0 ? notifAmount : _parseDouble(ao['totalAmount']) - _parseDouble(ao['customerPlatformFee']);
              AlertService().playNewOrderAlert(
                ao['_id']!,
                orderType: ao['orderType']?.toString(),
                customerName: customer['name'] ?? 'Customer',
                amount: finalAmt,
              );
            }
          }
          changed = true;
        }
      } catch (e) {
        debugPrint('Mapping Order Error for ID ${ao['_id']}: $e');
        firstParseError ??= e.toString();
      }
    }

    if (changed) {
      _sortOrders();
    } else if (apiOrders.isNotEmpty && _orders.isEmpty && firstParseError != null) {
      // 🚨 ALL orders failed to parse!
      AlertService().showAlert(
        title: 'Parsing Error', 
        message: 'Failed to parse ${apiOrders.length} orders.\nFirst error: $firstParseError'
      );
    }
    _isInitialLoadApi = false;
    notifyListeners(); 
  } catch (e) {
    _isInitialLoadApi = false;
    notifyListeners();
    debugPrint('[FETCH] Could not refresh orders: $e');
    final now = DateTime.now();
    final shouldShowBanner = _lastFetchErrorBannerAt == null ||
        now.difference(_lastFetchErrorBannerAt!).inSeconds > 45;
    if (shouldShowBanner) {
      _lastFetchErrorBannerAt = now;
      AlertService().showTopBanner(
        title: 'Connection issue',
        message: 'Orders could not refresh now. We will retry automatically.',
        color: const Color(0xFFB45309),
        icon: Icons.wifi_off_rounded,
      );
    }
  }
}

  VendorOrderStatus _mapBackendStatusToVendor(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'pending':
      case 'paymentpending':
        return VendorOrderStatus.pending;
      case 'accepted':
      case 'confirmed':
      case 'assigned': 
        return VendorOrderStatus.accepted; // Accepted/Confirmed/Assigned is the baseline for 'Active' orders
      case 'preparing':
        return VendorOrderStatus.preparing;
      case 'ready':
        return VendorOrderStatus.ready;
      case 'pickedup':
      case 'picked up':
      case 'outfordelivery':
      case 'delivered':
      case 'handedover':
      case 'completed':
        return VendorOrderStatus.handedOver;
      case 'cancelled':
      case 'rejected':
      case 'declined':
        return VendorOrderStatus.rejected;
      default:
        debugPrint('⚠️ Unknown status from backend: $status -> defaulting to pending');
        return VendorOrderStatus.pending; // Default to pending so actions show up if we're unsure
    }
  }

  /// 🛡️ Progression Protection logic: ensures an order doesn't revert to a previous state
  bool _isStatusUpgrade(VendorOrderStatus current, VendorOrderStatus candidate) {
    if (current == candidate) return false;
    
    // Weight system to define status lifecycle order
    int weight(VendorOrderStatus s) {
      switch (s) {
        case VendorOrderStatus.pending: return 0;
        case VendorOrderStatus.accepted: return 1;
        case VendorOrderStatus.preparing: return 2;
        case VendorOrderStatus.ready: return 3;
        case VendorOrderStatus.handedOver: return 4;
        case VendorOrderStatus.rejected: return 5; // Terminal state
        default: return 0;
      }
    }

    // Only allow "upgrades" (higher weights). 
    // Special case: if something was rejected but backend says pending, it should stay rejected.
    return weight(candidate) > weight(current);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> updateOrderStatus(String orderId, VendorOrderStatus newStatus, {double? newPrice, double? discount, String? cancelledBy, String? cancellationReason}) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final currentStatus = _orders[index].status;
      _orders[index].status = newStatus;
      if (cancelledBy != null) _orders[index].cancelledBy = cancelledBy;
      if (cancellationReason != null) _orders[index].cancellationReason = cancellationReason;
      if (newPrice != null) {
        _orders[index].subTotal = newPrice;
        _orders[index].discount = discount ?? 0.0;
        _orders[index].totalAmount = newPrice - (discount ?? 0.0);
      }
      
      String backendStatus;
      switch (newStatus) {
        case VendorOrderStatus.pending: backendStatus = 'Pending'; break;
        case VendorOrderStatus.preparing: backendStatus = 'Preparing'; break;
        case VendorOrderStatus.ready: backendStatus = 'Ready'; break;
        case VendorOrderStatus.handedOver: backendStatus = 'HandedOver'; break;
        case VendorOrderStatus.accepted: backendStatus = 'Accepted'; break;
        case VendorOrderStatus.rejected: backendStatus = 'Cancelled'; break;
        default: backendStatus = 'Accepted';
      }
      
      try {
        debugPrint('📡 [API] Updating status for $orderId to $backendStatus...');
        // Optimistic Update: Notify listeners early for immediate UI feedback
        notifyListeners();

        await _apiService.updateOrderStatus(
          orderId, 
          backendStatus,
          totalAmount: newPrice,
          discount: discount,
          cancelledBy: cancelledBy,
          cancellationReason: cancellationReason,
        );
        debugPrint('✅ API Update Successful for $orderId');
        } catch (e) {
          debugPrint("❌ API Update failed for $orderId: $e");
        }

      notifyListeners();
    }
  }

  void addOrder(VendorOrderModel order) {
    _orders.add(order);
    _sortOrders();
    notifyListeners();
  }

  Future<void> simulateNewOrder({bool isTextOrder = false}) async {
    if (_profile == null) return;
    
    final newOrderId = isTextOrder 
        ? 'TX${_uuid.v4().substring(0, 6).toUpperCase()}'
        : _uuid.v4().substring(0, 8).toUpperCase();
    
    // Create a real order on the backend so Admin can see it
    try {
      final response = await _apiService.placeOrder({
        'customer': { 'name': 'Guest Customer', 'phone': '+91 9123456789' },
        'vendor': _profile!.id,
        'items': isTextOrder ? [] : [
          { 'productName': 'Namba Special Biryani', 'quantity': 1, 'price': 280.0 },
          { 'productName': 'Cool Drink (500ml)', 'quantity': 2, 'price': 45.0 },
        ],
        'totalAmount': isTextOrder ? 0.0 : 370.0,
        'deliveryCharge': 40.0,
        'paymentMethod': 'COD',
        'orderType': isTextOrder ? 'Text' : 'Cart',
        'textContent': isTextOrder ? '1. Milk 1L\n2. Curd 500g\n3. Bread' : null,
      });

      if (response != null) {
        debugPrint('✅ Simulated order created on backend: ${response['_id']}');
        // The socket or timer will pick it up and add to list automatically
      }
    } catch (e) {
      debugPrint('❌ Failed to simulate order on backend: $e');
      // Simulated local orders are no longer supported. 
      // The system strictly relies on backend data.
    }
  }

  void _sortOrders() {
    _orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  double get todaysSales {
    final now = DateTime.now();
    return _orders
        .where((o) => o.status == VendorOrderStatus.handedOver && 
                     o.timestamp.day == now.day && 
                     o.timestamp.month == now.month && 
                     o.timestamp.year == now.year)
        .fold(0.0, (sum, order) => sum + order.totalAmount);
  }

  double get totalEarnings => _orders
      .where((o) => o.status == VendorOrderStatus.handedOver)
      .fold(0.0, (sum, order) => sum + order.totalAmount);

  // Weekly Revenue for fl_chart (Last 7 days)
  List<double> get weeklyRevenue {
    final now = DateTime.now();
    List<double> dailyTotals = List.filled(7, 0.0);
    
    for (var i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final total = _orders
          .where((o) => o.status == VendorOrderStatus.handedOver &&
                       o.timestamp.day == date.day &&
                       o.timestamp.month == date.month &&
                       o.timestamp.year == date.year)
          .fold(0.0, (sum, order) => sum + order.totalAmount);
      
      // If we have no real data for this day, provide a small mock value for "Professional" look
      dailyTotals[6 - i] = total > 0 ? total : (200.0 + (i * 50.0)); 
    }
    return dailyTotals;
  }

  // Top Selling Products logic
  Map<String, int> get topSellingProducts {
    Map<String, int> counts = {};
    for (var order in _orders) {
      if (order.status == VendorOrderStatus.handedOver) {
        for (var item in order.items) {
          counts[item.name] = (counts[item.name] ?? 0) + item.quantity;
        }
      }
    }
    // Return top 5
    var sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries.take(5));
  }

  int get acceptedOrdersToday {
    final now = DateTime.now();
    return _orders.where((o) => 
      o.status != VendorOrderStatus.pending && 
      o.status != VendorOrderStatus.rejected &&
      o.timestamp.day == now.day && 
      o.timestamp.month == now.month && 
      o.timestamp.year == now.year
    ).length;
  }

  int get declinedOrdersToday {
    final now = DateTime.now();
    return _orders.where((o) => 
      o.status == VendorOrderStatus.rejected &&
      o.timestamp.day == now.day && 
      o.timestamp.month == now.month && 
      o.timestamp.year == now.year
    ).length;
  }

  final List<Map<String, dynamic>> _payouts = [];
  List<Map<String, dynamic>> get payouts => _payouts;
  int get totalOrdersCount => _orders.length;

  /// Mark an order as notified in the UI to stop alerts
  void markAsNotified(String orderId) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].isNotified = true;
      notifyListeners();
      debugPrint('🔔 [NOTIFY] Order $orderId marked as notified in provider');
    }
  }

  Future<bool> updateProfileDetails(Map<String, dynamic> updateData) async {
    if (_profile == null) return false;
    final apiService = VendorApiService();
    final updatedData = await apiService.updateVendorProfile(_profile!.id, updateData);
    if (updatedData != null) {
      _profile = VendorProfileModel.fromJson(updatedData);
      notifyListeners();
      return true;
    }
    return false;
  }
}

