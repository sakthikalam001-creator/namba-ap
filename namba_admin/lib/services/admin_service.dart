import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminService {
  static String get baseUrl => '${(dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null) ?? 'http://54.204.9.126:5000/api/v1'}/admin';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('admin_user');
    String? token;
    if (userStr != null) {
      final user = jsonDecode(userStr);
      token = user['token'];
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String adminId,
    String? name,
    String? email,
    String? password,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/profile/$adminId'),
        headers: await _getHeaders(),
        body: jsonEncode({
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (password != null) 'password': password,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getExpiringVendors({int days = 14}) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/vendors/expiring-soon?days=$days'),
        headers: await _getHeaders(),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'data': []};
    }
  }

  static Future<Map<String, dynamic>> getVendorOfflineHistory({String? vendorId}) async {
    try {
      final queryParam = vendorId != null ? '?vendorId=$vendorId' : '';
      final res = await http.get(
        Uri.parse('$baseUrl/vendors/offline-history$queryParam'),
        headers: await _getHeaders(),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'data': []};
    }
  }
}
