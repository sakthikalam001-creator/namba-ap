import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../services/delivery_auth_service.dart';
import '../models/delivery_order.dart';
import '../services/location_service.dart';
import '../services/delivery_background_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryProvider extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final LocationTrackingService _locationService = LocationTrackingService();
  io.Socket? _socket;
  AudioPlayer? _alarmPlayer;

  Timer? _notificationReminderTimer;

  Future<void> _playLoudAlarmSound() async {
    try {
      if (_alarmPlayer == null) {
        _alarmPlayer = AudioPlayer();
      }
      await _alarmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer!.setVolume(1.0);
      await _alarmPlayer!.play(AssetSource('sounds/new_order_alert.wav'));
      debugPrint('🔔 ALARM: Continuous looping order alert started.');

      // Start periodic reminder notification if not already running
      _startNotificationReminder();
    } catch (e) {
      debugPrint('Error playing alarm sound: $e');
    }
  }

  void _startNotificationReminder() {
    _notificationReminderTimer?.cancel();
    _notificationReminderTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (!_isOnline || (_incomingRequests.isEmpty && _pendingAssignment == null)) {
        timer.cancel();
        _notificationReminderTimer = null;
        return;
      }
      
      // Re-trigger notification alert
      if (_pendingAssignment != null) {
        _showNotificationFromSocket(_pendingAssignment!);
      } else if (_incomingRequests.isNotEmpty) {
        _showNotification(_incomingRequests.first);
      }
    });
  }

  void stopAlarmSound() {
    try {
      _notificationReminderTimer?.cancel();
      _notificationReminderTimer = null;
      _alarmPlayer?.stop();
      _alarmPlayer = null;
      debugPrint('🔔 ALARM: Stopped alarm sound and reminder notifications.');
    } catch (e) {
      debugPrint('Error stopping alarm sound: $e');
    }
  }

  List<DeliveryOrder> _activeOrders = [];
  List<DeliveryOrder> _incomingRequests = [];
  List<DeliveryOrder> _orderHistory = [];
  List<String> _declinedOrderIds = [];
  final Set<String> _notifiedOrderIds = {};
  Map<String, dynamic> _documents = {};
  String _approvalStatus = 'approved';
  String _rejectionReason = '';
  bool _isOnline = false;
  bool _isHotZonesEnabled = false;
  bool get isHotZonesEnabled => _isHotZonesEnabled;
  String _lastSyncState = '';
  bool _isAuthenticated = true;
  bool get isAuthenticated => _isAuthenticated;
  int _syncLoopCount = 0;

  // ── New Assignment Pending State ──────────────────────────────────────────
  Map<String, dynamic>? _pendingAssignment; // raw data from socket
  Function(Map<String, dynamic>)? onNewAssignment; // UI registers this callback

  Map<String, dynamic>? get pendingAssignment => _pendingAssignment;

  DeliveryProvider({bool initialIsLoggedIn = false, String initialApprovalStatus = 'approved'}) {
    _isAuthenticated = initialIsLoggedIn;
    _approvalStatus = initialApprovalStatus.isNotEmpty ? initialApprovalStatus : 'approved';
    debugPrint('⚙️ PROVIDER: Initializing DeliveryProvider (isAuth: $_isAuthenticated, status: $_approvalStatus)...');
    _initNotifications();
    _startSyncPoller();
    checkInitialAuth();
    _loadSavedOnlineStatus();
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

  Future<void> _loadSavedOnlineStatus() async {
    final savedOnline = await DeliveryAuthService.getIsOnline();
    _isOnline = savedOnline;
    notifyListeners();
    final driverId = await DeliveryAuthService.getDriverId();
    if (driverId.isNotEmpty) {
      _updateLocationTrackingState(driverId);
    }
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
  bool _isNetworkConnected = true;
  bool get isNetworkConnected => _isNetworkConnected;

  Future<void> handleForceLogoutAction(String message) async {
    debugPrint('🚨 TRIGGER FORCE LOGOUT: $message');
    await DeliveryAuthService.logout();
    _isAuthenticated = false;
    _isOnline = false;
    _activeOrders.clear();
    _incomingRequests.clear();
    _orderHistory.clear();
    _pendingAssignment = null;
    notifyListeners();
    onForceLogout?.call(message);
  }

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

    _socket = io.io(socketBase, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 3000,
      'reconnectionAttempts': 999999,
    });

    _socket!.onConnect((_) {
      debugPrint('🔌 Driver Socket Connected - Joining Room driver_$driverId');
      _socket!.emit('join_room', 'driver_$driverId');

      if (_isOnline) {
        DeliveryAuthService.setDriverStatus(driverId, true);
      }
    });

    _socket!.onReconnect((_) {
      debugPrint('🔌 Driver Socket Reconnected - Rejoining Room driver_$driverId');
      _socket!.emit('join_room', 'driver_$driverId');
      if (_isOnline) {
        DeliveryAuthService.setDriverStatus(driverId, true);
      }
    });


      // Single Device Lock & Admin Force Logout Listener
      _socket!.on('force_device_logout', (data) {
        debugPrint('🚨 FORCE DEVICE LOGOUT: Account logged in on another device or terminated by Super Admin.');
        String msg = 'This account was logged in on another device or session terminated by Super Admin.';
        if (data is Map && data['message'] != null) {
          msg = data['message'].toString();
        }
        handleForceLogoutAction(msg);
      });

      _socket!.on('driver_status_update', (data) {
        if (data is Map) {
          final String targetId = (data['driverId'] ?? '').toString();
          if (targetId == driverId) {
            final isForced = data['action'] == 'FORCE_LOGOUT' || data['forceLogout'] == true;
            if (isForced) {
              handleForceLogoutAction(data['message']?.toString() ?? 'Super Admin terminated your session.');
            }
          }
        }
      });

      _socket!.on('driver_logged_out', (_) {
        handleForceLogoutAction('Your session has been logged out.');
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
      _approvalStatus = 'approved';
      DeliveryAuthService.updateApprovalStatus('approved');
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

    // Real-time Document & Re-upload updates from Admin
    _socket!.on('document_update', (data) {
      debugPrint('📄 DOCUMENT UPDATE SOCKET: $data');
      if (data != null && data is Map) {
        final docType = data['docType']?.toString() ?? 'Document';
        final status = data['status']?.toString() ?? '';
        final reason = data['rejectionReason']?.toString() ?? '';

        if (status == 'rejected') {
          _showSimpleNotification(
            '⚠️ Re-Upload Requested ($docType)',
            reason.isNotEmpty ? 'Admin Request: $reason' : 'Please re-upload your $docType with a clear photo.',
          );
        } else if (status == 'verified') {
          _showSimpleNotification(
            '✅ Document Approved ($docType)',
            '$docType has been verified by Admin!',
          );
        }

        if (data['approvalStatus'] != null) {
          _approvalStatus = data['approvalStatus'].toString();
          DeliveryAuthService.updateApprovalStatus(_approvalStatus);
        }
        if (data['documents'] is Map) {
          _documents = Map<String, dynamic>.from(data['documents'] as Map);
        }
        fetchDocumentStatuses();
        notifyListeners();
      }
    });

    // Real-time Partner Approval Status update
    _socket!.on('approval_status_update', (data) {
      debugPrint('🛡️ APPROVAL STATUS UPDATE: $data');
      if (data != null && data is Map) {
        if (data['status'] != null) {
          _approvalStatus = data['status'].toString();
          DeliveryAuthService.updateApprovalStatus(_approvalStatus);
        }
        if (data['rejectionReason'] != null) {
          _rejectionReason = data['rejectionReason'].toString();
        }
        if (data['documents'] is Map) {
          _documents = Map<String, dynamic>.from(data['documents'] as Map);
        }
        fetchDocumentStatuses();
        notifyListeners();
      }
    });

    // Real-time Platform Broadcasts from Admin
    _socket!.on('platform_broadcast', (data) {
      debugPrint('📢 PLATFORM BROADCAST RECEIVED: $data');
      if (data != null && data is Map) {
        final title = data['title']?.toString() ?? 'Platform Announcement';
        final message = data['message']?.toString() ?? '';
        final category = data['category']?.toString() ?? 'announcement';

        if (data['action'] == 'FORCE_LOGOUT' && (data['driverId'] == driverId || data['target'] == 'driver_$driverId')) {
          handleForceLogoutAction(message.isNotEmpty ? message : 'Super Admin terminated this mobile device session.');
          return;
        }

        String iconPrefix = '📢';
        if (category == 'emergency') iconPrefix = '🚨';
        if (category == 'surge_incentive') iconPrefix = '🌧️';
        if (category == 'maintenance') iconPrefix = '🛠️';
        if (category == 'promotional') iconPrefix = '🎁';

        _showSimpleNotification('$iconPrefix $title', message);
      }
    });
  }

  List<DeliveryOrder> get activeOrders => _activeOrders;
  List<DeliveryOrder> get incomingRequests => _incomingRequests;
  List<DeliveryOrder> get orderHistory => _orderHistory;
  List<String> get declinedOrderIds => _declinedOrderIds;
  Map<String, dynamic> get documents => _documents;
  String get approvalStatus => _approvalStatus;
  String get rejectionReason => _rejectionReason;
  bool get isOnline => _isOnline;

  bool get isVerifiedPartner {
    final status = _approvalStatus.toLowerCase();
    if (status != 'approved') return false;

    bool isDocOk(String key) {
      final d = _documents[key];
      if (d is! Map) return false;
      final front = (d['front'] ?? '').toString().trim();
      final st = (d['status'] ?? '').toString().toLowerCase();
      return front.isNotEmpty && (st == 'verified' || st == 'approved');
    }

    bool isDocRejected(String key) {
      final d = _documents[key];
      if (d is! Map) return false;
      final st = (d['status'] ?? '').toString().toLowerCase();
      return st == 'rejected';
    }

    bool isBankOk() {
      final d = _documents['bankDetails'] ?? _documents['bankStatement'];
      if (d is! Map) return false;
      final st = (d['status'] ?? '').toString().toLowerCase();
      final hasAcc = (d['accountNumber'] ?? '').toString().trim().isNotEmpty;
      final hasUpi = (d['upiId'] ?? d['upiNumber'] ?? '').toString().trim().isNotEmpty;
      final hasFront = (d['front'] ?? '').toString().trim().isNotEmpty;
      return (hasAcc || hasUpi || hasFront) && (st == 'verified' || st == 'approved');
    }

    final bool aadharOk = isDocOk('aadhar') || isDocOk('aadhaar');
    final bool licenseOk = isDocOk('license');
    final bool selfieOk = isDocOk('selfie');
    final bool bankOk = isBankOk();

    final bool hasRejection = isDocRejected('aadhar') ||
        isDocRejected('aadhaar') ||
        isDocRejected('license') ||
        isDocRejected('selfie') ||
        isDocRejected('rc') ||
        isDocRejected('pan') ||
        isDocRejected('bankStatement') ||
        isDocRejected('bankDetails') ||
        status == 'rejected';

    if (hasRejection) return false;
    return aadharOk && licenseOk && selfieOk && bankOk;
  }

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
            stopAlarmSound();
            notifyListeners();
            onNewAssignment?.call(_pendingAssignment!);
          } catch (e) {
            debugPrint('Notification Payload Error: $e');
          }
        }
      },
    );

    // Redundant cold start check removed to prevent double-navigation to order details page.

    // ── Create high-priority notification channel (Android 8+) ──────────
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'namba_delivery_order_alerts_v22', // channel id v22
          'New Delivery Order Alerts',        // channel name
          description: 'Urgent alerts when a new delivery order is assigned.',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('new_order_alert'),
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFF00C853),
          showBadge: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
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
              
              if (backendStatus == 'Pending' || backendStatus == 'Assigned' || backendStatus == 'Confirmed') {
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
      final String activeState = jsonEncode(apiActive.map((o) => '${o.id}_${o.rawStatus}_${o.vendorPaymentStatus}_${o.subTotal}_${o.billPhotoPath}').toList());
      final String incomingState = jsonEncode(apiIncoming.map((o) => '${o.id}_${o.rawStatus}_${o.vendorPaymentStatus}_${o.subTotal}_${o.billPhotoPath}').toList());
      final String combinedState = activeState + incomingState;
      
      bool hasChanged = combinedState != _lastSyncState;
      
      // Atomic update
      _activeOrders = apiActive;
      _incomingRequests = apiIncoming;
      _lastSyncState = combinedState;
      
      _updateLocationTrackingState(driverId);

      // Periodic session & online status verification (Every 2 sync cycles = 4 seconds)
      _syncLoopCount++;
      if (_syncLoopCount % 2 == 0) {
        try {
          final docRes = await DeliveryAuthService.getDriverDocuments(driverId);
          if (docRes['success'] == true) {
            final serverIsOnline = docRes['isOnline'] == true;
            final serverStatus = (docRes['status'] ?? '').toString().toLowerCase();

            if (!serverIsOnline && _isOnline) {
              debugPrint('🚨 DETECTED SERVER OFFLINE / FORCE LOGOUT FROM ADMIN. Logging out mobile.');
              handleForceLogoutAction('Super Admin terminated this mobile device session.');
              return;
            }
          }
        } catch (_) {}
      }
      
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

  Future<void> syncOrdersSilently() async {
    await _fullSync();
  }

  DeliveryOrder _mapJsonToDeliveryOrder(dynamic json) {
    final vendor = json['vendor'] ?? {};
    final customer = json['customer'] ?? {};
    final backendStatus = json['status']?.toString() ?? 'Pending';
    
    final double finalDestLat = _parseCoordinateSilently(json['deliveryCoordinates'], 1, _parseDoubleSilently(json['destLat'], 11.3410));
    final double finalDestLng = _parseCoordinateSilently(json['deliveryCoordinates'], 0, _parseDoubleSilently(json['destLng'], 77.7172));

    double finalStoreLat = finalDestLat;
    double finalStoreLng = finalDestLng;

    if (json['pinnedLat'] != null && json['pinnedLng'] != null) {
      finalStoreLat = _parseDoubleSilently(json['pinnedLat'], finalDestLat);
      finalStoreLng = _parseDoubleSilently(json['pinnedLng'], finalDestLng);
    } else if (vendor['location'] != null) {
      finalStoreLat = _parseCoordinateSilently(vendor['location'], 1, finalDestLat);
      finalStoreLng = _parseCoordinateSilently(vendor['location'], 0, finalDestLng);
    } else if (json['storeLat'] != null) {
      finalStoreLat = _parseDoubleSilently(json['storeLat'], finalDestLat);
      finalStoreLng = _parseDoubleSilently(json['storeLng'], finalDestLng);
    }

    String sName = 'Vendor';
    if (json['customStoreName'] != null && json['customStoreName'].toString().trim().isNotEmpty) {
      sName = json['customStoreName'].toString();
    } else if (vendor['storeName'] != null && vendor['storeName'].toString().trim().isNotEmpty) {
      sName = vendor['storeName'].toString();
    }

    String sAddress = '';
    if (json['customStoreAddress'] != null && json['customStoreAddress'].toString().trim().isNotEmpty) {
      sAddress = json['customStoreAddress'].toString();
    } else if (vendor['address'] != null && vendor['address'].toString().trim().isNotEmpty) {
      sAddress = vendor['address'].toString();
    }

    return DeliveryOrder(
      id: json['_id'] ?? '',
      storeName: sName,
      storeAddress: sAddress,
      customerName: customer['name']?.toString() ?? 'Customer',
      customerAddress: json['deliveryAddressFormatted']?.toString() ?? 'Check app',
      customerPhone: customer['phone']?.toString() ?? 'N/A',
      storePhone: vendor['phone']?.toString() ?? 'N/A',
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      subTotal: (json['subTotal'] ?? 0).toDouble(),
      deliveryFee: (json['deliveryCharge'] ?? 0).toDouble(),
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
      distanceKmBackend: (json['distanceKm'] != null) ? (json['distanceKm'] as num).toDouble() : null,
      driverEarningsBackend: (json['driverEarnings'] != null) ? (json['driverEarnings'] as num).toDouble() : null,
      customerRating: (json['driverRating'] != null || json['customerRating'] != null || json['rating'] != null)
          ? ((json['driverRating'] ?? json['customerRating'] ?? json['rating']) as num).toDouble()
          : null,
      vendorQrCodeUrl: json['vendorQrCodeUrl']?.toString() ?? vendor['qrCodeUrl']?.toString(),
      vendorGpayNumber: json['vendorGpayNumber']?.toString() ?? json['vendorUpiNumber']?.toString() ?? vendor['gpayNumber']?.toString(),
      vendorGpayName: json['vendorGpayName']?.toString() ?? vendor['gpayName']?.toString(),
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
          subTotal: (json['subTotal'] ?? 0).toDouble(),
          deliveryFee: (json['deliveryCharge'] ?? 0).toDouble(),
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
          distanceKmBackend: (json['distanceKm'] != null) ? (json['distanceKm'] as num).toDouble() : null,
          driverEarningsBackend: (json['driverEarnings'] != null) ? (json['driverEarnings'] as num).toDouble() : null,
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
    'namba_delivery_order_alerts_v22',
    'New Order Alerts',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('new_order_alert'),
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
    enableLights: true,
    ledColor: const Color(0xFF00C853),
    ledOnMs: 500,
    ledOffMs: 500,
    ticker: 'New Namba delivery order!',
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.call,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  Future<void> _showNotification(DeliveryOrder order) async {
    final payment = order.paymentMethod == 'COD' ? '💸 Cash On Delivery' : '💳 Online Paid';
    final earningsStr = '₹${order.computedDriverEarnings.toStringAsFixed(0)}';
    final distStr = order.formattedDistance;
    final orderNum = order.displayId.isNotEmpty ? '#${order.displayId}' : '';

    try {
      await _playLoudAlarmSound();
    } catch (e) {
      debugPrint('Error playing alarm sound override: $e');
    }

    final bigTextStyle = BigTextStyleInformation(
      '🏬 <b>Store:</b> ${order.storeName}<br>'
      '💰 <b>Earnings:</b> <font color="#00C853">$earningsStr</font> (₹7/KM Base Rate)<br>'
      '📍 <b>Trip Distance:</b> $distStr<br>'
      '💳 <b>Payment:</b> $payment<br>'
      '👉 <b>Tap to Open & Accept Order</b>',
      htmlFormatBigText: true,
      contentTitle: '🛵 <b>NEW ORDER • $earningsStr</b> $orderNum ($distStr)',
      htmlFormatContentTitle: true,
      summaryText: '🔥 $distStr Trip • ₹7/KM Base Calculation',
      htmlFormatSummaryText: true,
    );

    final androidDetails = AndroidNotificationDetails(
      'namba_delivery_order_alerts_v22',
      'New Order Alerts',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('new_order_alert'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      enableLights: true,
      ledColor: const Color(0xFF00C853),
      ledOnMs: 500,
      ledOffMs: 500,
      ticker: 'New Namba Delivery Order Available!',
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.call,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      styleInformation: bigTextStyle,
      color: const Color(0xFF4F46E5),
    );

    await _notificationsPlugin.show(
      order.id.hashCode,
      '🛵 NEW ORDER: $earningsStr ($distStr)',
      '[$payment] ${order.storeName} • Pay: $earningsStr • Total Trip: $distStr',
      NotificationDetails(android: androidDetails),
      payload: jsonEncode({
        'orderId': order.id,
        'displayId': order.displayId,
        'vendorName': order.storeName,
        'amount': order.computedDriverEarnings.toString(),
        'paymentMethod': order.paymentMethod,
      }),
    );
  }

  Future<void> _showNotificationFromSocket(Map<String, dynamic> data) async {
    final id = data['orderId']?.toString() ?? '';
    final store = data['vendorName']?.toString() ?? 'Store';
    final payment = data['paymentMethod'] == 'COD' ? '💸 Cash On Delivery' : '💳 Online Paid';
    final did = data['displayId']?.toString() ?? '';

    final rawPay = data['driverEarnings']?.toString() ?? data['amount']?.toString();
    final rawDist = data['distanceKm']?.toString();
    double distKm = (rawDist != null && double.tryParse(rawDist) != null) ? double.parse(rawDist) : 0.0;
    double payValNum = (rawPay != null && double.tryParse(rawPay) != null && double.parse(rawPay) > 0)
        ? double.parse(rawPay)
        : (distKm > 0 ? (distKm <= 50 ? distKm * 7.0 : (50 * 7.0) + ((distKm - 50) * 9.0)) : 14.0);
    if (payValNum < 10) payValNum = 10;

    final earningsStr = '₹${payValNum.toStringAsFixed(0)}';
    final distStr = distKm > 0 ? '${distKm.toStringAsFixed(1)} KM' : '1.9 KM';
    final orderNum = did.isNotEmpty ? '#$did' : '';

    try {
      await _playLoudAlarmSound();
    } catch (e) {
      debugPrint('Error playing alarm sound override from socket: $e');
    }

    final bigTextStyle = BigTextStyleInformation(
      '🏬 <b>Store:</b> $store<br>'
      '💰 <b>Earnings:</b> <font color="#00C853">$earningsStr</font> (₹7/KM Base Rate)<br>'
      '📍 <b>Trip Distance:</b> $distStr<br>'
      '💳 <b>Payment:</b> $payment<br>'
      '👉 <b>Tap to Open & Accept Order</b>',
      htmlFormatBigText: true,
      contentTitle: '🛵 <b>NEW ORDER • $earningsStr</b> $orderNum ($distStr)',
      htmlFormatContentTitle: true,
      summaryText: '🔥 $distStr Trip • ₹7/KM Base Calculation',
      htmlFormatSummaryText: true,
    );

    final androidDetails = AndroidNotificationDetails(
      'namba_delivery_order_alerts_v22',
      'New Order Alerts',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('new_order_alert'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      enableLights: true,
      ledColor: const Color(0xFF00C853),
      ledOnMs: 500,
      ledOffMs: 500,
      ticker: 'New Namba Delivery Order Available!',
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.call,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      styleInformation: bigTextStyle,
      color: const Color(0xFF4F46E5),
    );

    await _notificationsPlugin.show(
      id.isNotEmpty ? id.hashCode : DateTime.now().millisecondsSinceEpoch,
      '🛵 NEW ORDER: $earningsStr ($distStr)',
      '[$payment] ${did.isNotEmpty ? 'Order #$did • ' : ''}$store • Pay: $earningsStr • Total Trip: $distStr',
      NotificationDetails(android: androidDetails),
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
    stopAlarmSound();
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
        totalAmount: double.tryParse(_pendingAssignment!['orderTotal']?.toString() ?? _pendingAssignment!['amount']?.toString() ?? '0') ?? 0,
        items: [],
        status: DeliveryStatus.pickingUp,
        timestamp: DateTime.now(),
        displayId: _pendingAssignment!['displayId'] ?? '',
        rawStatus: 'Assigned',
        paymentMethod: _pendingAssignment!['paymentMethod'] ?? 'ONLINE',
        driverEarningsBackend: double.tryParse(_pendingAssignment!['driverEarnings']?.toString() ?? _pendingAssignment!['amount']?.toString() ?? '0'),
        distanceKmBackend: double.tryParse(_pendingAssignment!['distanceKm']?.toString() ?? '0'),
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
    stopAlarmSound();
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
      
      double? lat;
      double? lng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final Map<String, dynamic> bodyPayload = {
        'status': backendStatus,
        'driverId': driverId,
      };
      if (lat != null && lng != null) {
        bodyPayload['lat'] = lat;
        bodyPayload['lng'] = lng;
        bodyPayload['pickupLat'] = lat;
        bodyPayload['pickupLng'] = lng;
        bodyPayload['actualPickupLat'] = lat;
        bodyPayload['actualPickupLng'] = lng;
      }

      final response = await http.put(
        Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/status'),
        headers: await DeliveryAuthService.getHeaders(),
        body: jsonEncode(bodyPayload),
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
    final socketUrl = DeliveryAuthService.baseUrl.split('/api/').first;
    
    if (_activeOrders.isNotEmpty) {
      final activeOrder = _activeOrders.first;
      _locationService.startTracking(activeOrder.id, driverId, name);
      DeliveryBackgroundService.startService(driverId: driverId, socketUrl: socketUrl);
    } else if (_isOnline) {
      _locationService.startTracking("online", driverId, name);
      DeliveryBackgroundService.startService(driverId: driverId, socketUrl: socketUrl);
    } else {
      _locationService.stopTracking();
      DeliveryBackgroundService.stopService();
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

  Future<void> checkLocationService() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (_isLocationServiceEnabled != enabled) {
        _isLocationServiceEnabled = enabled;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> checkNetworkConnectivity() async {
    try {
      final response = await http.get(Uri.parse('${DeliveryAuthService.baseUrl}/admin/settings/public')).timeout(const Duration(seconds: 4));
      final connected = response.statusCode == 200;
      if (_isNetworkConnected != connected) {
        _isNetworkConnected = connected;
        notifyListeners();
      }
    } catch (_) {
      if (_isNetworkConnected != false) {
        _isNetworkConnected = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchDocumentStatuses() async {
    try {
      final driverId = await DeliveryAuthService.getDriverId();
      if (driverId.isEmpty) return;

      final result = await DeliveryAuthService.getDriverDocuments(driverId);
      if (result['success'] == true) {
        _documents = result['data'] ?? {};
        _approvalStatus = (result['status'] ?? 'pending').toString().toLowerCase();
        _rejectionReason = result['rejectionReason']?.toString() ?? '';
        _isHotZonesEnabled = result['hotZonesEnabled'] == true;
        
        final bool serverIsOnline = result['isOnline'] == true;
        if (!serverIsOnline && _isOnline) {
          debugPrint('🚨 Server returned isOnline: false while local is online. Logging out.');
          handleForceLogoutAction('Super Admin terminated this mobile device session.');
          return;
        }

        _isOnline = serverIsOnline;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('driver_is_online', serverIsOnline);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch Documents Error: $e');
    }
  }

  Future<Map<String, dynamic>> updateOnlineStatus(bool online) async {
    final originalState = _isOnline;
    _isOnline = online;
    notifyListeners();

    final driverId = await DeliveryAuthService.getDriverId();
    if (driverId.isNotEmpty) {
      final res = await DeliveryAuthService.setDriverStatus(driverId, online);
      if (res['success'] == true) {
        // Ensure provider socket is connected
        if (_socket == null || !_socket!.connected) {
          _initSocket();
        }
        _updateLocationTrackingState(driverId);
        notifyListeners();
        return {'success': true};
      } else {
        // Revert status on failure
        _isOnline = originalState;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('driver_is_online', originalState);
        notifyListeners();
        return {
          'success': false,
          'error': res['error'] ?? res['message'] ?? 'Failed to update status on server.'
        };
      }
    }
    
    _isOnline = originalState;
    notifyListeners();
    return {'success': false, 'error': 'Driver ID not found. Please log in again.'};
  }

  void clearPendingAssignment() {
    _pendingAssignment = null;
    stopAlarmSound();
    notifyListeners();
  }

  Future<bool> sendQuote(String orderId, double amount, {String? qrImagePath, String? gpayNumber, String? gpayName, String? billImagePath}) async {
    try {
      final driverId = await DeliveryAuthService.getDriverId();
      String? uploadedQrUrl;
      if (qrImagePath != null && qrImagePath.isNotEmpty) {
        uploadedQrUrl = await uploadImage(qrImagePath);
      }

      if (billImagePath != null && billImagePath.isNotEmpty) {
        await uploadBillPhoto(orderId, billImagePath);
      }

      final Map<String, dynamic> body = {
        'totalAmount': amount,
        'driverId': driverId,
        'status': 'Assigned',
        'vendorPaymentDetailsUploadedByDriver': true,
      };
      if (uploadedQrUrl != null && uploadedQrUrl.isNotEmpty) {
        body['qrCodeUrl'] = uploadedQrUrl;
        body['vendorQrCodeUrl'] = uploadedQrUrl;
      }
      if (gpayNumber != null && gpayNumber.trim().isNotEmpty) {
        body['gpayNumber'] = gpayNumber.trim();
        body['vendorGpayNumber'] = gpayNumber.trim();
      }
      if (gpayName != null && gpayName.trim().isNotEmpty) {
        body['gpayName'] = gpayName.trim();
        body['vendorGpayName'] = gpayName.trim();
      }

      final response = await http.put(
        Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
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

  Future<String?> uploadImage(String filePath) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('${DeliveryAuthService.baseUrl}/orders/upload'));
      final headers = await DeliveryAuthService.getHeaders();
      headers.remove('Content-Type');
      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath('photo', filePath));

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['url'];
      }
    } catch (e) {
      debugPrint('Upload image error: $e');
    }
    return null;
  }

  Future<bool> uploadVendorQrCode(String orderId, String qrImagePath) async {
    try {
      final String? uploadedUrl = await uploadImage(qrImagePath);
      if (uploadedUrl == null || uploadedUrl.isEmpty) return false;

      final url = Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/qr-code');
      final response = await http.post(
        url,
        headers: await DeliveryAuthService.getHeaders(),
        body: jsonEncode({'qrCodeUrl': uploadedUrl}),
      );

      if (response.statusCode == 200) {
        final index = _activeOrders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          _activeOrders[index] = _activeOrders[index].copyWith(vendorQrCodeUrl: uploadedUrl);
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error uploading vendor QR code: $e');
    }
    return false;
  }

  Future<bool> updateVendorGpayNumber(String orderId, String gpayNumber) async {
    try {
      final url = Uri.parse('${DeliveryAuthService.baseUrl}/orders/$orderId/qr-code');
      final response = await http.post(
        url,
        headers: await DeliveryAuthService.getHeaders(),
        body: jsonEncode({'gpayNumber': gpayNumber}),
      );

      if (response.statusCode == 200) {
        final index = _activeOrders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          _activeOrders[index] = _activeOrders[index].copyWith(vendorGpayNumber: gpayNumber);
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error updating vendor GPay number: $e');
    }
    return false;
  }
}
