import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VendorApiService {
  static final VendorApiService _instance = VendorApiService._internal();
  factory VendorApiService() => _instance;
  VendorApiService._internal();

  static String get _baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000/api/v1';
  static String get _socketUrl => dotenv.env['SOCKET_URL'] ?? 'http://localhost:5000';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('vendorToken');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  io.Socket? socket;
  void initSocket(String vendorId, Function(dynamic) onNewOrder, {Function(dynamic)? onAccessUpdate, Function()? onWipeOut, Function(dynamic)? onTrialExpired}) {
    final s = io.io(_socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });
    socket = s;

    s.onConnect((_) {
      print('Vendor Connected to Live Tracking Engine');
      s.emit('join_room', 'vendor_$vendorId');
    });

    s.on('orders_wiped', (_) {
      print('URGENT: Global orders wipeout received');
      if (onWipeOut != null) onWipeOut();
    });

    s.on('new_order_alert', (data) {
      print('URGENT: New Order Alert received => $data');
      onNewOrder(data);
    });

    s.on('access_update', (data) {
      print('SECURITY: Access Update received => $data');
      onAccessUpdate?.call(data);
    });

    s.on('order_status_update', (data) {
      print('ORDER: Status Update received => $data');
      onNewOrder(data);
    });

    s.on('vendor_payment_completed', (data) {
      print('FINANCE: Vendor Payment Completed received => $data');
      onNewOrder(data); 
    });

    // 🔔 Trial Expiry Notification from server
    s.on('trial_expired', (data) {
      print('⚠️ TRIAL EXPIRED: Notification received => $data');
      onTrialExpired?.call(data);
    });

    s.onDisconnect((_) => print('Vendor Disconnected'));
  }

  void emitInventoryUpdate(String vendorId) {
    final s = socket;
    if (s != null && s.connected) {
      debugPrint('📡 [SOCKET] Emitting inventory update for vendor: $vendorId');
      s.emit('inventory_updated', {'vendorId': vendorId});
    }
  }

  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/orders/$orderId'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'];
      }
    } catch (e) {
      print('Fetch Order Detail Error: $e');
    }
    return null;
  }

  Future<void> updateOrderStatus(String orderId, String status, {double? totalAmount, double? discount}) async {
    try {
      final body = <String, dynamic>{'status': status};
      if (totalAmount != null) {
        body['totalAmount'] = totalAmount;
        if (discount != null) {
          body['discount'] = discount;
        }
      }

      debugPrint('⬆️ PUT /orders/$orderId/status - Body: $body');
      final response = await http.put(
        Uri.parse('$_baseUrl/orders/$orderId/status'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update order status');
      }
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> placeOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/orders'),
        headers: await _getHeaders(),
        body: jsonEncode(orderData),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? data;
      }
    } catch (e) {
      print('Place Order Error: $e');
    }
    return null;
  }

  Future<void> updateVendorStoreStatus(String vendorId, bool isOpen) async {
    try {
      final url = '$_baseUrl/vendors/${vendorId.trim()}/status';
      final response = await http.put(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode({'isOpen': isOpen}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update store status');
      }
    } catch (e) {
      print('API Update Store Status Error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getVendorOrders(String vendorId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/orders/vendor/$vendorId'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      }
    } catch (e) {
      print('Fetch Vendor Orders Error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getVendorStatus(String phone) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/admin/vendors/status-by-phone/$phone'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
    } catch (e) {
      print('Fetch Status Error: $e');
    }
    return null;
  }

  Future<List<dynamic>> getProducts(String vendorId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/products/vendor/$vendorId'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'] as List<dynamic>;
      }
    } catch (e) {
      print('Fetch Products Error: $e');
    }
    return [];
  }

  Future<bool> createProduct(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/products'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Create Product Error: $e');
    }
    return false;
  }

  Future<bool> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/products/$productId'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update Product Error: $e');
    }
    return false;
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/products/$productId'), headers: await _getHeaders());
      return response.statusCode == 200;
    } catch (e) {
      print('Delete Product Error: $e');
    }
    return false;
  }

  Future<List<dynamic>> getSubscriptions() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/subscriptions'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'] as List<dynamic>;
      }
    } catch (e) {
      print('Fetch Subscriptions Error: $e');
    }
    return [];
  }
}

