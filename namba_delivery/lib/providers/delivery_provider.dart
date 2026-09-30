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
import '../models/rider_notification.dart';
import '../services/location_service.dart';
import '../services/delivery_background_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../screens/orders/delivery_order_detail_screen.dart';

class DeliveryProvider extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final LocationTrackingService _locationService = LocationTrackingService();
  io.Socket? _socket;
  AudioPlayer? _alarmPlayer;

  Timer? _notificationReminderTimer;

  // ── In-App Notification Center State ─────────────────────────────────────
  final List<RiderNotification> _notifications = [];
  List<RiderNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _loadSavedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('rider_inapp_notifications');
      if (savedStr != null && savedStr.isNotEmpty) {
        final List list = jsonDecode(savedStr);
        _notifications.clear();
        for (var item in list) {
          _notifications.add(RiderNotification.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      
      // If notifications list is completely empty, populate welcome / system alerts
      if (_notifications.isEmpty) {
        _notifications.addAll([
          RiderNotification(
            id: 'welcome_notif',
            title: '🎉 Welcome to Namba Fleet!',
            body: 'Your rider app is synced with real-time dispatch and 24/7 Super Admin support.',
            category: NotificationCategory.system,
            timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            isRead: false,
          ),
          RiderNotification(
            id: 'payout_rule_notif',
            title: '💰 Weekly Settlement Alert',
            body: 'Weekly earnings and tips are automatically settled every Tuesday by 8:00 PM directly to your bank account.',
            category: NotificationCategory.payout,
            timestamp: DateTime.now().subtract(const Duration(hours: 3)),
            isRead: false,
          ),
          RiderNotification(
            id: 'kyc_verified_notif',
            title: '🛡️ Document Verification Desk',
            body: 'Keep your Aadhar, Driving License, Bank Details, and Profile Selfie updated to maintain Verified status.',
            category: NotificationCategory.kyc,
            timestamp: DateTime.now().subtract(const Duration(hours: 5)),
            isRead: true,
          ),
        ]);
        _persistNotifications();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved notifications: $e');
    }
  }

  Future<void> _persistNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _notifications.map((n) => n.toJson()).toList();
      await prefs.setString('rider_inapp_notifications', jsonEncode(list));
    } catch (e) {
      debugPrint('Error persisting notifications: $e');
    }
  }

  void addNotification(RiderNotification notif) {
    // Avoid duplicate notifications with same ID
    _notifications.removeWhere((n) => n.id == notif.id);
    _notifications.insert(0, notif);
    // Keep max 60 notifications in history
    if (_notifications.length > 60) {
      _notifications.removeRange(60, _notifications.length);
    }
    _persistNotifications();
    notifyListeners();
  }

  void markNotificationAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      _persistNotifications();
      notifyListeners();
    }
  }

  void markAllNotificationsAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    _persistNotifications();
    notifyListeners();
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _persistNotifications();
    notifyListeners();
  }

  void clearAllNotifications() {
    _notifications.clear();
    _persistNotifications();
    notifyListeners();
  }

  String _activeAlertSound = 'new_order_alert';

  static String cleanSoundName(String? s) {
    if (s == null || s.trim().isEmpty) return 'new_order_alert';
    String str = s.trim();
    if (str.endsWith('.wav')) str = str.substring(0, str.length - 4);
    if (str.endsWith('.mp3')) str = str.substring(0, str.length - 4);
    if (str.endsWith('.ogg')) str = str.substring(0, str.length - 4);
    const valid = ['new_order_alert', 'bell_ring', 'loud_alarm', 'chime_alert'];
    return valid.contains(str) ? str : 'new_order_alert';
  }

  Future<void> _playLoudAlarmSound([String? soundName]) async {
    try {
      final sound = cleanSoundName(soundName ?? _activeAlertSound);
      _activeAlertSound = sound;
      if (_alarmPlayer == null) {
        _alarmPlayer = AudioPlayer();
      }
      try {
        await _alarmPlayer!.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            stayAwake: true,
            audioFocus: AndroidAudioFocus.gainTransient,
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
            audioMode: AndroidAudioMode.normal,
          ),
        ));
      } catch (_) {}
      await _alarmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer!.setVolume(1.0);
      await _alarmPlayer!.play(AssetSource('sounds/$sound.wav'));
      debugPrint('🔔 ALARM: Continuous looping order alert started with sound "$sound.wav"');

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
  final Set<String> _locallyAcceptedOrderIds = {};
  Set<String> get locallyAcceptedOrderIds => _locallyAcceptedOrderIds;
  Map<String, dynamic> _documents = {};
  String _cachedProfilePhoto = '';
  String get cachedProfilePhoto => _cachedProfilePhoto;
  String _approvalStatus = 'approved';
  String _rejectionReason = '';
  bool _isOnline = false;
  bool _isHotZonesEnabled = false;
  bool get isHotZonesEnabled => _isHotZonesEnabled;
  bool _allowGalleryUpload = false;
  bool get allowGalleryUpload => _allowGalleryUpload;
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
    _loadCachedProfileAndDocuments();
    _initNotifications();
    _loadSavedNotifications();
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

  Future<void> _loadCachedProfileAndDocuments() async {
    final photo = await DeliveryAuthService.getDriverProfilePhoto();
    if (photo.isNotEmpty) {
      _cachedProfilePhoto = photo;
    }
    final cachedDocs = await DeliveryAuthService.getCachedDocuments();
    if (cachedDocs.isNotEmpty && _documents.isEmpty) {
      _documents = cachedDocs;
      if (_cachedProfilePhoto.isEmpty && _documents['selfie'] is Map) {
        _cachedProfilePhoto = (_documents['selfie']['front'] ?? '').toString();
      }
    }
    notifyListeners();
  }

  void primeDocuments(Map<String, dynamic> docs, String photoUrl) {
    if (docs.isNotEmpty) {
      _documents = Map<String, dynamic>.from(docs);
    }
    if (photoUrl.trim().isNotEmpty) {
      _cachedProfilePhoto = photoUrl.trim();
      DeliveryAuthService.saveDriverProfilePhoto(_cachedProfilePhoto);
    } else if (_documents['selfie'] is Map) {
      final s = (_documents['selfie']['front'] ?? '').toString().trim();
      if (s.isNotEmpty) {
        _cachedProfilePhoto = s;
        DeliveryAuthService.saveDriverProfilePhoto(s);
      }
    }
    notifyListeners();
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
      if (savedOnline) {
        // Driver was manually online, re-assert online status to server
        DeliveryAuthService.setDriverStatus(driverId, true);
      }
      _updateLocationTrackingState(driverId);
    }
  }

  void setAuthenticated(bool val) {
    _isAuthenticated = val;
    if (val) {
      _loadSavedOnlineStatus();
      _initSocket();
      _fetchHistoryFromApi();
      _fullSync();
      fetchDocumentStatuses();
    }
    notifyListeners();
  }

  Future<void> fetchHistory() => _fetchHistoryFromApi();

  Function(String)? onForceLogout;
  bool _isLocationServiceEnabled = true;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;
  bool _isNetworkConnected = true;
  bool get isNetworkConnected => _isNetworkConnected;

  double? _realDriverRating;
  int _realRatingCount = 0;
  Map<String, dynamic> _ratingCounts = {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0};
  Map<String, dynamic> _ratingTags = {};
  List<dynamic> _driverReviewsList = [];
  double _totalTipsEarned = 0.0;

  double? get realDriverRating => _realDriverRating;
  int get realRatingCount => _realRatingCount;
  Map<String, dynamic> get ratingCounts => _ratingCounts;
  Map<String, dynamic> get ratingTags => _ratingTags;
  List<dynamic> get driverReviewsList => _driverReviewsList;
  double get totalTipsEarned => _totalTipsEarned;

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
    if (coords == null) return fallback;
    // Format 1: GeoJSON { type: 'Point', coordinates: [lng, lat] } -> idx 0 = lng, idx 1 = lat
    if (coords is Map && coords['coordinates'] is List && (coords['coordinates'] as List).length > idx) {
      return _parseDoubleSilently(coords['coordinates'][idx], fallback);
    }
    // Format 2: Direct List [lng, lat]
    if (coords is List && coords.length > idx) {
      return _parseDoubleSilently(coords[idx], fallback);
    }
    // Format 3: Map with lat/lng keys
    if (coords is Map) {
      if (idx == 1) { // latitude
        final latVal = coords['lat'] ?? coords['latitude'] ?? coords['dropLat'] ?? coords['destLat'];
        if (latVal != null) return _parseDoubleSilently(latVal, fallback);
      } else if (idx == 0) { // longitude
        final lngVal = coords['lng'] ?? coords['longitude'] ?? coords['dropLng'] ?? coords['destLng'];
        if (lngVal != null) return _parseDoubleSilently(lngVal, fallback);
      }
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
      _socket!.emit('join_driver_room', {'driverId': driverId});

      if (_isOnline) {
        DeliveryAuthService.setDriverStatus(driverId, true);
      }
    });

    _socket!.onReconnect((_) {
      debugPrint('🔌 Driver Socket Reconnected - Rejoining Room driver_$driverId');
      _socket!.emit('join_room', 'driver_$driverId');
      _socket!.emit('join_driver_room', {'driverId': driverId});
      if (_isOnline) {
        DeliveryAuthService.setDriverStatus(driverId, true);
      }
    });


      // Single Device Lock & Admin Force Logout Listener
      _socket!.on('force_device_logout', (data) {
        debugPrint('🚨 FORCE DEVICE LOGOUT event received: $data');
        String msg = 'This account was logged in on another device.';
        if (data is Map) {
          final target = (data['driverId'] ?? data['target'] ?? '').toString();
          if (target.isNotEmpty && target != driverId && target != 'driver_$driverId') {
            return;
          }
          if (data['message'] != null) {
            msg = data['message'].toString();
          }
        }
        handleForceLogoutAction(msg);
      });

      _socket!.on('feature_toggle', (data) {
        debugPrint('🔔 DRIVER FEATURE TOGGLE: $data');
        if (data is Map) {
          if (data['allowGalleryUpload'] != null) {
            _allowGalleryUpload = data['allowGalleryUpload'] == true;
          }
          if (data['hotZonesEnabled'] != null) {
            _isHotZonesEnabled = data['hotZonesEnabled'] == true;
          }
          notifyListeners();
        }
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

      _socket!.on('driver_logged_out', (data) {
        if (data is Map) {
          final target = (data['driverId'] ?? '').toString();
          if (target.isNotEmpty && target == driverId) {
            handleForceLogoutAction('Your session has been logged out.');
          }
        }
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
      if (data == null || data is! Map) return;
      final mapData = Map<String, dynamic>.from(data);
      final newOrderId = mapData['orderId']?.toString() ?? mapData['_id']?.toString() ?? '';

      // Auto-assert online duty so driver never misses admin dispatched delivery
      if (!_isOnline) {
        _isOnline = true;
        DeliveryAuthService.getDriverId().then((id) {
          if (id.isNotEmpty) DeliveryAuthService.setDriverStatus(id, true);
        });
      }

      _pendingAssignment = mapData;
      _approvalStatus = 'approved';
      DeliveryAuthService.updateApprovalStatus('approved');

      // Trigger continuous loud alarm sound
      final soundName = cleanSoundName(mapData['alertSound']?.toString() ?? _activeAlertSound);
      _activeAlertSound = soundName;
      _playLoudAlarmSound(soundName);

      // Show system heads-up notification immediately
      _showNotificationFromSocket(mapData);

      notifyListeners();
      // Trigger UI callback if registered
      onNewAssignment?.call(mapData);
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

    _socket!.on('driver_approval_update', (data) {
      debugPrint('🛡️ DRIVER APPROVAL UPDATE: $data');
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

    _socket!.on('driver_rating_sync', (data) {
      if (data != null && data['driverId'] == driverId) {
        debugPrint('⭐ REAL-TIME DRIVER RATING SYNC EVENT RECEIVED');
        fetchRealDriverRatings();
      }
    });

    _socket!.on('driver_rating_updated_$driverId', (data) {
      debugPrint('⭐ REAL-TIME DRIVER RATING UPDATED FOR THIS RIDER: $data');
      fetchRealDriverRatings();
      _showSimpleNotification('⭐ New Customer Rating Received!', 'A customer just rated your delivery service.');
    });

    _socket!.on('driver_payout_settled', (data) {
      debugPrint('💰 REAL-TIME DRIVER PAYOUT SETTLED EVENT: $data');
      _fetchHistoryFromApi();

      double amount = 0.0;
      String ref = '';
      int count = 1;
      if (data != null && data is Map) {
        amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        ref = data['transactionRef']?.toString() ?? '';
        count = (data['settledCount'] as num?)?.toInt() ?? 1;
      }

      final amountText = amount > 0 ? '₹${amount.toStringAsFixed(2)}' : 'earnings';
      final refText = ref.isNotEmpty ? ' • Ref: $ref' : '';

      _showSimpleNotification(
        '💰 Payout Settled & Transferred!',
        'Admin transferred $amountText for $count delivery trip(s) to your UPI / Bank account$refText.',
        category: NotificationCategory.payout,
      );
    });
  }

  List<DeliveryOrder> get activeOrders => _activeOrders;
  List<DeliveryOrder> get incomingRequests => _incomingRequests;
  List<DeliveryOrder> get orderHistory => _orderHistory;
  List<DeliveryOrder> get deliveredOrders =>
      _orderHistory.where((o) => o.status == DeliveryStatus.delivered).toList();
  List<DeliveryOrder> get pendingSettlementOrders =>
      deliveredOrders.where((o) => o.isDriverPending).toList();
  List<DeliveryOrder> get settledOrders =>
      deliveredOrders.where((o) => o.isDriverSettled).toList();

  double get totalDeliveredEarnings {
    double sum = 0.0;
    for (final o in deliveredOrders) {
      final earn = o.computedDriverEarnings > 0 ? o.computedDriverEarnings : (o.driverEarningsBackend ?? 10.0);
      sum += earn;
    }
    return sum;
  }

  double get pendingPayoutEarnings {
    double sum = 0.0;
    for (final o in pendingSettlementOrders) {
      final earn = o.computedDriverEarnings > 0 ? o.computedDriverEarnings : (o.driverEarningsBackend ?? 10.0);
      sum += earn;
    }
    return sum;
  }

  double get settledPayoutEarnings {
    double sum = 0.0;
    for (final o in settledOrders) {
      final earn = o.computedDriverEarnings > 0 ? o.computedDriverEarnings : (o.driverEarningsBackend ?? 10.0);
      sum += earn;
    }
    return sum;
  }
  List<String> get declinedOrderIds => _declinedOrderIds;
  Map<String, dynamic> get documents => _documents;
  String get approvalStatus => _approvalStatus;
  String get rejectionReason => _rejectionReason;
  bool get isOnline => _isOnline;

  bool get isVerifiedPartner {
    final status = _approvalStatus.toLowerCase();
    if (status != 'approved') return false;

    final bool hasRejection = _approvalStatus.toLowerCase() == 'rejected' ||
        _documents.values.any((d) => d is Map && (d['status'] ?? '').toString().toLowerCase() == 'rejected');

    if (hasRejection) return false;
    return true;
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
            final orderId = _pendingAssignment?['orderId']?.toString() ?? _pendingAssignment?['_id']?.toString() ?? '';

            if (response.actionId == 'accept_action') {
              stopAlarmSound();
              if (orderId.isNotEmpty) {
                acceptAssignment(orderId);
              }
            } else {
              // NOTE: Sound continues until rider explicitly accepts or declines
            }
            notifyListeners();
            onNewAssignment?.call(_pendingAssignment!);

            // Requirement: Tapping notification opens order details immediately
            if (orderId.isNotEmpty) {
              NambaDeliveryApp.navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: orderId)),
              );
            }
          } catch (e) {
            debugPrint('Notification Payload Error: $e');
          }
        }
      },
    );

    // Requirement: Check cold start launch from notification
    try {
      final launchDetails = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp && launchDetails.notificationResponse != null) {
        final payload = launchDetails.notificationResponse!.payload;
        if (payload != null && payload.isNotEmpty) {
          final data = jsonDecode(payload);
          _pendingAssignment = Map<String, dynamic>.from(data);
          final orderId = _pendingAssignment?['orderId']?.toString() ?? _pendingAssignment?['_id']?.toString() ?? '';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (orderId.isNotEmpty) {
              NambaDeliveryApp.navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: orderId)),
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Launch Details Error: $e');
    }

    // ── Create high-priority notification channel (Android 8+) ──────────
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const sounds = ['new_order_alert', 'bell_ring', 'loud_alarm', 'chime_alert'];
      for (final s in sounds) {
        await androidPlugin.createNotificationChannel(
          AndroidNotificationChannel(
            'namba_delivery_order_alerts_v22_$s',
            'New Delivery Order Alerts ($s)',
            description: 'Urgent call-style alerts when a new delivery order is assigned.',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(s),
            enableVibration: true,
            enableLights: true,
            ledColor: const Color(0xFF00C853),
            showBadge: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );
      }
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'namba_delivery_order_alerts_v22',
          'New Delivery Order Alerts',
          description: 'Urgent alerts when a new delivery order is assigned.',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('new_order_alert'),
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
      // Request POST_NOTIFICATIONS permission (Android 13 / API 33+)
      await androidPlugin.requestNotificationsPermission();
    }
  }

  void _startSyncPoller() {
    checkLocationService();
    checkNetworkConnectivity();
    _fullSync(); // Initial sync
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      await checkLocationService();
      await checkNetworkConnectivity();
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
              
              if (backendStatus == 'Delivered' || backendStatus == 'Cancelled' || backendStatus == 'Rejected') {
                continue;
              }

              final bool isAlreadyPickedUp = backendStatus == 'PickedUp' || backendStatus == 'Picked Up' ||
                  backendStatus == 'OutForDelivery' || backendStatus == 'On The Way';
              final bool hasLocallyAccepted = _locallyAcceptedOrderIds.contains(dOrder.id);

              if (!isAlreadyPickedUp && !hasLocallyAccepted) {
                // Not yet accepted or picked up by driver -> Categorize as incoming assignment
                apiIncoming.add(dOrder);
              } else {
                // In-progress active delivery
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
            if (docRes['data'] is Map && (docRes['data'] as Map).isNotEmpty) {
              _documents = Map<String, dynamic>.from(docRes['data']);
            }
            final selfie = (_documents['selfie'] is Map ? _documents['selfie']['front'] ?? '' : '').toString().trim();
            final photo = selfie.isNotEmpty ? selfie : (docRes['profilePhoto'] ?? '').toString().trim();
            if (photo.isNotEmpty && photo != _cachedProfilePhoto) {
              _cachedProfilePhoto = photo;
              DeliveryAuthService.saveDriverProfilePhoto(photo);
            }
            final serverIsOnline = docRes['isOnline'] == true;
            final savedOnline = await DeliveryAuthService.getIsOnline();
            if (savedOnline && !serverIsOnline) {
              // Rider manually turned online on device; keep driver online & re-sync to server
              _isOnline = true;
              DeliveryAuthService.setDriverStatus(driverId, true);
            } else if (!savedOnline && serverIsOnline) {
              // Rider manually turned offline on device; keep driver offline & sync to server
              _isOnline = false;
              DeliveryAuthService.setDriverStatus(driverId, false);
            } else if (_isOnline != serverIsOnline) {
              _isOnline = serverIsOnline;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('driver_is_online', serverIsOnline);
            }
            notifyListeners();
          }
        } catch (_) {}
      }

      // Automatically refresh history if empty or periodically (every 10s)
      if (_orderHistory.isEmpty || _syncLoopCount % 5 == 0) {
        _fetchHistoryFromApi();
      }
      
      if (hasChanged) {
        notifyListeners();
      }

      if (_incomingRequests.isNotEmpty && !_isOnline) {
        _isOnline = true;
        DeliveryAuthService.setDriverStatus(driverId, true);
      }

      if (_incomingRequests.length >= 2) {
        bool hasNew = _incomingRequests.any((req) => !_notifiedOrderIds.contains(req.id));
        if (hasNew) {
          for (var req in _incomingRequests) {
            _notifiedOrderIds.add(req.id);
          }
          _showBatchNotification(_incomingRequests);
        }
      } else {
        for (var req in _incomingRequests) {
          if (!_notifiedOrderIds.contains(req.id)) {
            _notifiedOrderIds.add(req.id);
            _showNotification(req);
          }
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
    
    final double finalDestLat = _parseCoordinateSilently(
      json['deliveryCoordinates'] ?? json['dropLocation'] ?? json['deliveryPoint'], 
      1, 
      _parseDoubleSilently(json['destLat'] ?? json['dropLat'] ?? json['deliveryLat'] ?? json['customerLat'], 11.3410)
    );
    final double finalDestLng = _parseCoordinateSilently(
      json['deliveryCoordinates'] ?? json['dropLocation'] ?? json['deliveryPoint'], 
      0, 
      _parseDoubleSilently(json['destLng'] ?? json['dropLng'] ?? json['deliveryLng'] ?? json['customerLng'], 77.7172)
    );

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
      isOfficeDelivery: json['isOfficeDelivery'] == true ||
          (json['deliveryAddressLabel']?.toString().toLowerCase() == 'office') ||
          (json['deliveryAddressFormatted']?.toString().toLowerCase().contains('office') ?? false),
      deliveryAddressLabel: json['deliveryAddressLabel']?.toString(),
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

        final double finalDestLat = _parseCoordinateSilently(
          json['deliveryCoordinates'] ?? json['dropLocation'] ?? json['deliveryPoint'], 
          1, 
          _parseDoubleSilently(json['destLat'] ?? json['dropLat'] ?? json['deliveryLat'] ?? json['customerLat'], 11.3410)
        );
        final double finalDestLng = _parseCoordinateSilently(
          json['deliveryCoordinates'] ?? json['dropLocation'] ?? json['deliveryPoint'], 
          0, 
          _parseDoubleSilently(json['destLng'] ?? json['dropLng'] ?? json['deliveryLng'] ?? json['customerLng'], 77.7172)
        );

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
          storeName: json['isCustomStore'] == true 
              ? (json['customStoreName'] ?? '📍 Custom Store') 
              : (vendor['storeName'] ?? json['customStoreName'] ?? 'Vendor'),
          storeAddress: json['isCustomStore'] == true 
              ? (json['customStoreAddress'] ?? '') 
              : (vendor['address'] ?? ''),
          customerName: customer['name'] ?? 'Customer',
          customerAddress: json['deliveryAddressFormatted'] ?? 'Delivered',
          customerPhone: customer['phone'] ?? 'N/A',
          storePhone: vendor['phone']?.toString() ?? 'N/A',
          totalAmount: (json['totalAmount'] ?? 0).toDouble(),
          subTotal: (json['subTotal'] ?? 0).toDouble(),
          deliveryFee: (json['deliveryCharge'] ?? 0).toDouble(),
          items: (json['items'] as List? ?? []).map((i) => i['productName']?.toString() ?? 'Item').toList(),
          status: _mapBackendStatusToDelivery(json['status']),
          timestamp: (json['deliveredAt'] != null
              ? DateTime.tryParse(json['deliveredAt'].toString())?.toLocal()
              : (json['updatedAt'] != null
                  ? DateTime.tryParse(json['updatedAt'].toString())?.toLocal()
                  : (json['createdAt'] != null
                      ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
                      : DateTime.now()))) ?? DateTime.now(),
          displayId: json['displayId'] ?? '',
          rawStatus: json['status'] ?? '',
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
          driverPaymentStatus: (json['driverPaymentStatus'] ?? 'Pending').toString(),
          driverPaidAt: json['driverPaidAt'] != null
              ? DateTime.tryParse(json['driverPaidAt'].toString())?.toLocal()
              : null,
          driverPaymentRef: json['driverPaymentRef']?.toString(),
          driverPaymentMethod: json['driverPaymentMethod']?.toString() ?? 'UPI',
          isOfficeDelivery: json['isOfficeDelivery'] == true ||
              (json['deliveryAddressLabel']?.toString().toLowerCase() == 'office') ||
              (json['deliveryAddressFormatted']?.toString().toLowerCase().contains('office') ?? false),
          deliveryAddressLabel: json['deliveryAddressLabel']?.toString(),
        );
      }).toList();

      await fetchRealDriverRatings();
      notifyListeners();
    } catch (e) {
      debugPrint('History Fetch Error: $e');
    }
  }

  Future<void> fetchRealDriverRatings() async {
    try {
      final driverId = await DeliveryAuthService.getDriverId();
      if (driverId.isEmpty) return;

      final url = Uri.parse('${DeliveryAuthService.baseUrl}/reviews/driver/$driverId');
      final response = await http.get(url, headers: await DeliveryAuthService.getHeaders());
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final resData = data['data'];
          if (resData['averageRating'] != null) {
            _realDriverRating = (resData['averageRating'] as num).toDouble();
          }
          _realRatingCount = (resData['totalCount'] ?? 0) as int;
          if (resData['counts'] != null) {
            _ratingCounts = Map<String, dynamic>.from(resData['counts']);
          }
          if (resData['tags'] != null) {
            _ratingTags = Map<String, dynamic>.from(resData['tags']);
          }
          if (resData['reviews'] != null) {
            _driverReviewsList = List<dynamic>.from(resData['reviews']);
          }
          if (resData['totalTips'] != null) {
            _totalTipsEarned = (resData['totalTips'] as num).toDouble();
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Real Driver Rating Fetch Error: $e');
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


  Future<void> _showNotification(DeliveryOrder order) async {
    final payment = order.paymentMethod == 'COD' ? '💸 Cash On Delivery' : '💳 Online Paid';
    final earningsStr = '₹${order.computedDriverEarnings.toStringAsFixed(0)}';
    final distStr = order.formattedDistance;
    final orderNum = order.displayId.isNotEmpty ? '#${order.displayId}' : '';

    try {
      await _playLoudAlarmSound(_activeAlertSound);
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

    final prefs = await SharedPreferences.getInstance();
    final langStr = (prefs.getString('driver_language') ?? prefs.getString('app_language') ?? 'english').toLowerCase();
    String acceptActionText = 'ACCEPT ORDER';
    if (langStr == 'tamil') {
      acceptActionText = 'ஏற்கவும்';
    } else if (langStr == 'tanglish') {
      acceptActionText = 'ACCEPT ORDER';
    }

    final androidDetails = AndroidNotificationDetails(
      'namba_delivery_order_alerts_v22_$_activeAlertSound',
      'New Order Alerts',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(_activeAlertSound),
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
      actions: [
        AndroidNotificationAction(
          'accept_action',
          acceptActionText,
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
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

    // Save into In-App Notification Center
    addNotification(
      RiderNotification(
        id: 'order_${order.id}',
        title: '🛵 New Delivery Order: $earningsStr',
        body: '${order.storeName} • Pay: $earningsStr • Total Trip: $distStr ($payment)',
        category: NotificationCategory.order,
        timestamp: DateTime.now(),
        isRead: false,
        data: {
          'orderId': order.id,
          'displayId': order.displayId,
          'vendorName': order.storeName,
        },
      ),
    );
  }

  Future<void> _showBatchNotification(List<DeliveryOrder> orders) async {
    if (orders.length < 2) return;
    double totalEarnings = 0;
    double totalDistance = 0;
    for (var o in orders) {
      totalEarnings += o.computedDriverEarnings;
      totalDistance += o.distanceInKm;
    }
    final earningsStr = '₹${totalEarnings.toStringAsFixed(0)}';
    final distStr = '${totalDistance.toStringAsFixed(1)} KM';
    final stores = orders.map((o) => o.storeName).join(' + ');

    try {
      await _playLoudAlarmSound(_activeAlertSound);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final langStr = (prefs.getString('driver_language') ?? prefs.getString('app_language') ?? 'english').toLowerCase();
    String title = '⚡ BATCH ASSIGNMENT • ${orders.length} ORDERS ($earningsStr)';
    String body = 'Combined Route: $stores • Pay: $earningsStr • Total: $distStr';
    String acceptActionText = 'ACCEPT BATCH';
    if (langStr == 'tamil') {
      title = '⚡ 2 புதிய ஆர்டர்கள் ஒதுக்கப்பட்டுள்ளன ($earningsStr)';
      body = 'தொகுப்பு டெலிவரி: $stores • வருமானம்: $earningsStr • $distStr';
      acceptActionText = '2 ஆர்டர்களையும் ஏற்கவும்';
    } else if (langStr == 'tanglish') {
      title = '⚡ 2 Orders Assign Pannapattullathu ($earningsStr)';
      body = 'Batch Route: $stores • Pay: $earningsStr • $distStr';
      acceptActionText = 'ACCEPT BATCH';
    }

    final bigTextStyle = BigTextStyleInformation(
      '📦 <b>Batch Orders:</b> ${orders.length} Deliveries<br>'
      '🏬 <b>Stores:</b> $stores<br>'
      '💰 <b>Combined Payout:</b> <font color="#00C853">$earningsStr</font><br>'
      '📍 <b>Total Route:</b> $distStr<br>'
      '👉 <b>Tap to Open & Accept Both Orders</b>',
      htmlFormatBigText: true,
      contentTitle: '⚡ <b>$title</b>',
      htmlFormatContentTitle: true,
      summaryText: '🔥 Multi-Drop Route • $earningsStr Total',
      htmlFormatSummaryText: true,
    );

    final androidDetails = AndroidNotificationDetails(
      'namba_delivery_order_alerts_v22_$_activeAlertSound',
      'New Order Alerts',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(_activeAlertSound),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      enableLights: true,
      ledColor: const Color(0xFF00C853),
      ledOnMs: 500,
      ledOffMs: 500,
      ticker: title,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.call,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      styleInformation: bigTextStyle,
      color: const Color(0xFFF97316),
      actions: [
        AndroidNotificationAction(
          'accept_batch_action',
          acceptActionText,
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    await _notificationsPlugin.show(
      'batch_assignment'.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode({
        'isBatch': true,
        'orderIds': orders.map((o) => o.id).toList(),
      }),
    );

    addNotification(
      RiderNotification(
        id: 'batch_${orders.first.id}_${orders.last.id}',
        title: title,
        body: body,
        category: NotificationCategory.order,
        timestamp: DateTime.now(),
        isRead: false,
        data: {
          'isBatch': true,
          'orderIds': orders.map((o) => o.id).toList(),
        },
      ),
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

    final soundName = cleanSoundName(data['alertSound']?.toString() ?? _activeAlertSound);
    _activeAlertSound = soundName;

    try {
      await _playLoudAlarmSound(soundName);
    } catch (e) {
      debugPrint('Error playing alarm sound override from socket: $e');
    }

    final bool isOffice = data['isOfficeDelivery'] == true ||
        data['isOfficeDelivery'] == 'true' ||
        (data['deliveryAddressLabel']?.toString().toLowerCase() == 'office');

    final bigTextStyle = BigTextStyleInformation(
      '${isOffice ? "🏢 <b>DELIVERY: OFFICE / WORKPLACE</b><br>" : ""}'
      '🏬 <b>Store:</b> $store<br>'
      '💰 <b>Earnings:</b> <font color="#00C853">$earningsStr</font> (₹7/KM Base Rate)<br>'
      '📍 <b>Trip Distance:</b> $distStr<br>'
      '💳 <b>Payment:</b> $payment<br>'
      '👉 <b>Tap to Open & Accept Order</b>',
      htmlFormatBigText: true,
      contentTitle: '${isOffice ? "🏢 <b>OFFICE ORDER • " : "🛵 <b>NEW ORDER • "}$earningsStr</b> $orderNum ($distStr)',
      htmlFormatContentTitle: true,
      summaryText: '${isOffice ? "🏢 Office Delivery • " : ""}🔥 $distStr Trip',
      htmlFormatSummaryText: true,
    );

    final prefs = await SharedPreferences.getInstance();
    final langStr = (prefs.getString('driver_language') ?? prefs.getString('app_language') ?? 'english').toLowerCase();
    String acceptActionText = 'ACCEPT ORDER';
    if (langStr == 'tamil') {
      acceptActionText = 'ஏற்கவும்';
    } else if (langStr == 'tanglish') {
      acceptActionText = 'ACCEPT ORDER';
    }

    final androidDetails = AndroidNotificationDetails(
      'namba_delivery_order_alerts_v22_$soundName',
      'New Order Alerts',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundName),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      enableLights: true,
      ledColor: const Color(0xFF00C853),
      ledOnMs: 500,
      ledOffMs: 500,
      ticker: isOffice ? '🏢 Office Delivery Order Available!' : 'New Namba Delivery Order Available!',
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.call,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      styleInformation: bigTextStyle,
      color: const Color(0xFF4F46E5),
      actions: [
        AndroidNotificationAction(
          'accept_action',
          acceptActionText,
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    await _notificationsPlugin.show(
      id.isNotEmpty ? id.hashCode : DateTime.now().millisecondsSinceEpoch,
      '${isOffice ? "🏢 OFFICE ORDER: " : "🛵 NEW ORDER: "}$earningsStr ($distStr)',
      '${isOffice ? "[🏢 Office/Workplace] " : ""}[$payment] ${did.isNotEmpty ? 'Order #$did • ' : ''}$store • Pay: $earningsStr • Total Trip: $distStr',
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(data),
    );

    // Save into In-App Notification Center
    addNotification(
      RiderNotification(
        id: id.isNotEmpty ? 'order_$id' : 'socket_${DateTime.now().millisecondsSinceEpoch}',
        title: '${isOffice ? "🏢 Office Order " : "🛵 New Order "}$orderNum: $earningsStr',
        body: '${isOffice ? "🏢 Office Delivery • " : ""}$store • Trip: $distStr • $payment',
        category: NotificationCategory.order,
        timestamp: DateTime.now(),
        isRead: false,
        data: data,
      ),
    );
  }

  Future<void> _showSimpleNotification(String title, String body, {NotificationCategory category = NotificationCategory.system}) async {
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: AndroidNotificationDetails('namba_order_alerts', 'New Order Alerts', importance: Importance.max)),
    );

    addNotification(
      RiderNotification(
        id: 'system_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        category: category,
        timestamp: DateTime.now(),
        isRead: false,
      ),
    );
  }

  Future<bool> acceptAssignment(String orderId) async {
    stopAlarmSound();
    _locallyAcceptedOrderIds.add(orderId);
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
    _locallyAcceptedOrderIds.remove(orderId);
    _activeOrders.removeWhere((o) => o.id == orderId);
    if (acceptedOrder != null && incomingIdx != -1) {
      _incomingRequests.insert(incomingIdx, acceptedOrder);
    }
    notifyListeners();
  }

  Future<bool> declineAssignment(String orderId) async {
    stopAlarmSound();
    _locallyAcceptedOrderIds.remove(orderId);
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

  Future<bool> acceptBatchAssignments(List<String> orderIds) async {
    stopAlarmSound();
    bool allSuccess = true;
    for (final id in orderIds) {
      final ok = await acceptAssignment(id);
      if (!ok) allSuccess = false;
    }
    await _fullSync();
    return allSuccess;
  }

  Future<bool> declineBatchAssignments(List<String> orderIds) async {
    stopAlarmSound();
    bool allSuccess = true;
    for (final id in orderIds) {
      final ok = await declineAssignment(id);
      if (!ok) allSuccess = false;
    }
    return allSuccess;
  }

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
        final wasDisconnected = _isNetworkConnected == false;
        _isNetworkConnected = connected;
        notifyListeners();

        // 🔄 AUTO ONLINE RECOVERY: When internet is restored after being disconnected
        if (connected && wasDisconnected) {
          final savedOnline = await DeliveryAuthService.getIsOnline();
          if (_isOnline || savedOnline) {
            _isOnline = true;
            final driverId = await DeliveryAuthService.getDriverId();
            if (driverId.isNotEmpty) {
              await DeliveryAuthService.setDriverStatus(driverId, true);
              if (_socket == null || !_socket!.connected) {
                _initSocket();
              }
              _updateLocationTrackingState(driverId);
              notifyListeners();
            }
          }
        }
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
        if (result['data'] is Map) {
          _documents = Map<String, dynamic>.from(result['data']);
          final selfie = (_documents['selfie'] is Map ? _documents['selfie']['front'] ?? '' : '').toString().trim();
          final photo = selfie.isNotEmpty ? selfie : (result['profilePhoto'] ?? '').toString().trim();
          if (photo.isNotEmpty) {
            _cachedProfilePhoto = photo;
            DeliveryAuthService.saveDriverProfilePhoto(photo);
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('driver_documents_cache', jsonEncode(_documents));
        }
        _approvalStatus = (result['status'] ?? 'pending').toString().toLowerCase();
        _rejectionReason = result['rejectionReason']?.toString() ?? '';
        _isHotZonesEnabled = result['hotZonesEnabled'] == true;
        _allowGalleryUpload = result['allowGalleryUpload'] == true;
        
        final bool serverIsOnline = result['isOnline'] == true;
        final savedOnline = await DeliveryAuthService.getIsOnline();
        if (savedOnline && !serverIsOnline) {
          // Rider manually turned online on device; keep driver online & re-sync to server
          _isOnline = true;
          DeliveryAuthService.setDriverStatus(driverId, true);
        } else if (!savedOnline && serverIsOnline) {
          // Rider manually turned offline on device; keep driver offline & sync to server
          _isOnline = false;
          DeliveryAuthService.setDriverStatus(driverId, false);
        } else {
          _isOnline = serverIsOnline;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('driver_is_online', serverIsOnline);
        }
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

  Future<bool> sendQuote(
    String orderId,
    double amount, {
    double? deliveryFee,
    double? customerTotal,
    String? qrImagePath,
    String? gpayNumber,
    String? gpayName,
    String? billImagePath,
  }) async {
    try {
      final driverId = await DeliveryAuthService.getDriverId();
      String? uploadedQrUrl;
      if (qrImagePath != null && qrImagePath.isNotEmpty) {
        uploadedQrUrl = await uploadImage(qrImagePath);
      }

      if (billImagePath != null && billImagePath.isNotEmpty) {
        await uploadBillPhoto(orderId, billImagePath);
      }

      final double fee = deliveryFee ?? 30.0;
      final double total = customerTotal ?? (amount + fee);

      final Map<String, dynamic> body = {
        'totalAmount': amount, // Sent as totalAmount for backend subTotal calculation
        'subTotal': amount,
        'billAmount': amount,
        'deliveryCharge': fee,
        'deliveryFee': fee,
        'customerTotal': total,
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
