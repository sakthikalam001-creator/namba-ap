
import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

class CustomerApiService {
  static final CustomerApiService _instance = CustomerApiService._internal();
  factory CustomerApiService() => _instance;
  CustomerApiService._internal();

  static String get _baseUrl {
    try {
      return dotenv.isInitialized ? (dotenv.env['API_BASE_URL'] ?? 'http://100.53.131.76:5000/api/v1') : 'http://100.53.131.76:5000/api/v1';
    } catch (_) {
      return 'http://100.53.131.76:5000/api/v1';
    }
  }

  static String get _socketUrl {
    try {
      return dotenv.isInitialized ? (dotenv.env['SOCKET_URL'] ?? 'http://100.53.131.76:5000') : 'http://100.53.131.76:5000';
    } catch (_) {
      return 'http://100.53.131.76:5000';
    }
  }

  String? customerId;
  String? customerName;
  String? customerPhone;
  String? authToken;
  io.Socket? socket;
  final Set<String> _pendingRooms = {};

  void setAuthToken(String token) {
    authToken = token;
    print('✅ Auth Token set in API Service');
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  void setCustomerInfo({required String id, String? name, String? phone}) {
    customerId = id;
    if (name != null) customerName = name;
    if (phone != null) customerPhone = phone;
    print('👤 Customer Info updated: $id, $name, $phone');
    joinOrderRoom('customer_$id');
    if (phone != null && phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length >= 10) {
        joinOrderRoom('customer_${cleanPhone.substring(cleanPhone.length - 10)}');
      }
    }
  }

  void setCustomerId(String id) {
    setCustomerInfo(id: id);
  }

  void joinOrderRoom(String? orderId) {
    if (orderId == null) return;
    final room = orderId.startsWith('order_') || orderId.startsWith('customer_') 
        ? orderId : 'order_$orderId';

    if (socket != null && socket!.connected) {
      print('📦 Joining Room Now: $room');
      socket!.emit('join_room', room);
    } else {
      print('⏳ Socket not connected. Queueing room join: $room');
      _pendingRooms.add(room);
    }
  }

  final StreamController<dynamic> _eventController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get socketEvents => _eventController.stream;

  StreamSubscription<dynamic> initSocket(Function(dynamic) onStatusUpdate, {Function()? onWipeOut}) {
    // If socket already exists, just add the listener
    if (socket != null) {
      final sub = socketEvents.listen(onStatusUpdate);
      if (socket!.connected) _processPendingRooms();
      return sub;
    }

    print('🌐 Initializing Socket Connection to $_socketUrl');
    socket = io.io(_socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
    });

    socket!.onConnect((_) {
      print('✅ Namba Customer Socket Connected! ID: ${socket!.id}');
      _processPendingRooms();
    });

    socket!.onConnectError((err) => print('❌ Socket Connect Error: $err'));
    socket!.onDisconnect((_) => print('🔌 Socket Disconnected'));

    socket!.on('orders_wiped', (_) {
      print('🚨 URGENT: Global orders wipeout received');
      _eventController.add({'type': 'wipeout'});
      if (onWipeOut != null) onWipeOut();
    });

    socket!.on('order_status_update', (data) {
      print('🔥 [Socket] order_status_update received: $data');
      _eventController.add(data);
    });
    
    socket!.on('order_price_updated', (data) {
      print('💰 [Socket] order_price_updated received: $data');
      _eventController.add(data);
    });

    socket!.on('vendor_status_update', (data) {
      print('🏪 [Socket] vendor_status_update received: $data');
      _eventController.add({'type': 'vendor_status', ...data});
    });

    socket!.on('vendor_new_live', (data) {
      _eventController.add({'type': 'vendor_new_live', ...data});
    });

    socket!.on('vendor_updated', (data) {
      _eventController.add({'type': 'vendor_updated', ...data});
    });

    socket!.on('inventory_updated', (data) {
      print('📦 LIVE INVENTORY UPDATE: $data');
      _eventController.add({'type': 'inventory_update', ...data});
    });

    return socketEvents.listen(onStatusUpdate);
  }

  void _processPendingRooms() {
    if (socket == null || !socket!.connected) return;
    
    if (customerId != null) {
      _pendingRooms.add('customer_$customerId');
    }
    
    if (customerPhone != null && customerPhone!.isNotEmpty) {
      // Clean phone to 10 digits to match backend
      final cleanPhone = customerPhone!.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length >= 10) {
        final phoneSuffix = cleanPhone.substring(cleanPhone.length - 10);
        _pendingRooms.add('customer_$phoneSuffix');
      }
    }

    if (_pendingRooms.isNotEmpty) {
      print('🔄 Processing ${_pendingRooms.length} pending room joins...');
      for (final room in _pendingRooms) {
        print('➡️ Joining Room: $room');
        socket!.emit('join_room', room);
      }
      _pendingRooms.clear();
    }
  }

  Future<List<dynamic>> getNearbyVendors(double lat, double lng, {int radius = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/vendors/nearby?lat=$lat&lng=$lng&radius=$radius'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      }
    } catch (e) {
      print('GeoNear API Error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> customerOtpLogin(String phone) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/customer-login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone}),
      );
      if (res.statusCode == 200 || res.statusCode == 404) {
        final decoded = json.decode(res.body);
        if (res.statusCode == 404) {
          return {
            ...decoded,
            'isNewUser': true,
          };
        }
        return decoded;
      }
      return null;
    } catch (e) {
      print('Error checking customer login: $e');
      return null;
    }
  }

  Future<dynamic> placeOrder({
    required String vendorId,
    List<Map<String, dynamic>>? items,
    required double totalAmount,
    required double deliveryCharge,
    required String paymentMethod,
    Map<String, double>? deliveryCoordinates,
    bool isCustomStore = false,
    String? customStoreName,
    String? customStoreAddress,
    String? orderType,
    String? textContent,
    String? photoUrl,
    String? customerNameOverride,
    String? customerPhoneOverride,
  }) async {
    try {
      final finalName = customerNameOverride ?? customerName;
      final finalPhone = customerPhoneOverride ?? customerPhone;
      
      print('🚀 PLACING ORDER: $vendorId for $customerId ($finalName)');

      final response = await http.post(
        Uri.parse('$_baseUrl/orders'),
        headers: _headers,
        body: jsonEncode({
          'customer': customerId,
          'customerName': finalName,
          'customerPhone': finalPhone,
          'vendor': vendorId,
          'items': items ?? [],
          'totalAmount': totalAmount,
          'deliveryCharge': deliveryCharge,
          'paymentMethod': paymentMethod,
          'orderType': orderType ?? 'Cart',
          'textContent': textContent,
          'photoUrl': photoUrl,
          'deliveryCoordinates': deliveryCoordinates,
          'isCustomStore': isCustomStore,
          'customStoreName': customStoreName,
          'customStoreAddress': customStoreAddress,
        }),
      );
      
      final resData = jsonDecode(response.body);
      if (response.statusCode == 201) {
        final order = resData['data'];
        final String? id = order['_id'] ?? order['id'];
        
        // Update our customerId to the real ObjectId from server if it changed
        if (order['customer'] != null) {
          final sId = order['customer'].toString();
          if (sId != customerId) {
            print('🔄 Updating CustomerID to real ObjectId: $sId');
            setCustomerId(sId);
          }
        }

        print('✅ Order placed successfully: $id');
        if (id != null) joinOrderRoom(id);
        return order;
      } else {
        throw Exception(resData['error'] ?? 'Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Place Order Error: $e');
      throw Exception(e.toString());
    }
  }

  Future<String?> uploadImage(String filePath) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/orders/upload'));
      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }
      request.files.add(await http.MultipartFile.fromPath('photo', filePath));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['url'];
      }
    } catch (e) {
      print('Upload Error: $e');
    }
    return null;
  }

  // Fetch products for a vendor from backend
  Future<List<dynamic>> getVendorProducts(String vendorId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/products/vendor/$vendorId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      }
    } catch (e) {
      print('Fetch Products Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getCustomerOrders() async {
    try {
      String searchId = customerId ?? '';
      
      // IDENTITY FALLBACK: If we have a mock ID but also have a phone number,
      // use the phone number to fetch orders. The backend will resolve the phone
      // to the real User ObjectId, and our provider will sync it back.
      if (searchId.startsWith('mock_') && customerPhone != null && customerPhone!.isNotEmpty) {
        final cleanPhone = customerPhone!.replaceAll(RegExp(r'\D'), '');
        if (cleanPhone.length >= 10) {
          searchId = cleanPhone.substring(cleanPhone.length - 10);
          print('🔍 Identity Fallback: Fetching history by phone ($searchId) instead of mock ID');
        }
      }

      if (searchId.isEmpty) {
        print('⚠️ Cannot fetch history: No ID or phone available');
        return [];
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/orders/customer/$searchId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Fetch Customer Orders Error: $e');
      throw Exception('Network or Server Error');
    }
  }

  Future<bool> updateOrder(String orderId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/orders/$orderId/status'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update Order Error: $e');
      return false;
    }
  }

  Future<List<dynamic>> getOffers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/offers'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      }
    } catch (e) {
      print('Fetch Offers Error: $e');
    }
    return [];
  }
}
