import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DeliveryAuthService {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://100.53.131.76:5000/api/v1';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('driver_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── Update Driver Status ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> setDriverStatus(String driverId, bool isOnline) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/driver-status'),
        headers: await _getHeaders(),
        body: jsonEncode({'driverId': driverId, 'isOnline': isOnline}),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('driver_is_online', isOnline);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Fetch Platform Settings ───────────────────────────────────────────
  static Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/settings'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Register Driver ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> registerDriver({
    required String name,
    required String phone,
    required String password,
    required String vehicleType,
    required String vehicleNumber,
    required String licenseNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register-driver'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'password': password,
          'vehicleType': vehicleType,
          'vehicleNumber': vehicleNumber,
          'licenseNumber': licenseNumber,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        await _saveSession(data);
      }
      return data;
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: await _getHeaders(),
        body: jsonEncode({'phone': phone, 'password': password}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // Verify it's a driver account
        final role = data['user']?['role'];
        if (role != 'driver') {
          return {'success': false, 'error': 'This account is not a delivery partner account.'};
        }
        await _saveSession(data);
      }
      return data;
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // ── Forgot Password — Send OTP ────────────────────────────────────────
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: await _getHeaders(),
        body: jsonEncode({'phone': phone}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // ── Verify OTP ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: await _getHeaders(),
        body: jsonEncode({'phone': phone, 'otp': otp}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // ── Reset Password ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: await _getHeaders(),
        body: jsonEncode({'phone': phone, 'otp': otp, 'newPassword': newPassword}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // ── Session Management ────────────────────────────────────────────────
  static Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driver_token', data['token'] ?? '');
    await prefs.setString('driver_id', data['user']?['_id'] ?? '');
    await prefs.setString('driver_name', data['user']?['name'] ?? '');
    await prefs.setString('driver_phone', data['user']?['phone'] ?? '');
    await prefs.setString('driver_approval_status', data['user']?['driverApprovalStatus'] ?? 'pending');
    await prefs.setBool('driver_is_online', data['user']?['isOnline'] ?? false);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('driver_token') && (prefs.getString('driver_token') ?? '').isNotEmpty;
  }

  static Future<String> getApprovalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('driver_approval_status') ?? 'pending';
  }

  static Future<String> getDriverName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('driver_name') ?? 'Rider';
  }

  static Future<String> getDriverPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('driver_phone') ?? '';
  }

  static Future<String> getDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('driver_id') ?? '';
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('driver_token');
  }

  static Future<bool> getIsOnline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('driver_is_online') ?? false;
  }

  static Future<void> updateApprovalStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driver_approval_status', status);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('driver_token');
    await prefs.remove('driver_id');
    await prefs.remove('driver_name');
    await prefs.remove('driver_phone');
    await prefs.remove('driver_approval_status');
    await prefs.remove('driver_is_online');
  }

  // ── Document Verification Methods ──────────────────────────────────────
  
  static Future<Map<String, dynamic>> uploadFile(String filePath) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/orders/upload'));
      final headers = await _getHeaders();
      if (headers.containsKey('Authorization')) {
        request.headers['Authorization'] = headers['Authorization']!;
      }
      request.files.add(await http.MultipartFile.fromPath('photo', filePath));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> uploadDocumentSide({
    required String driverId,
    required String docType,
    required String side,
    required String fileUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/upload-document'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'driverId': driverId,
          'docType': docType,
          'side': side,
          'fileUrl': fileUrl,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getDriverDocuments(String driverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/documents/$driverId'),
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
