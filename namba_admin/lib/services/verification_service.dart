import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerificationService {
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

  static Future<Map<String, dynamic>> getPendingVerifications() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/documents/pending'), headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> verifyDocument({
    required String driverId,
    required String docType,
    required String status,
    String? reason,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/documents/$driverId/verify'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'docType': docType,
          'status': status,
          'reason': reason,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getAllDrivers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/drivers'), headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> approveDriver(String driverId) async {
    try {
      final response = await http.put(Uri.parse('$baseUrl/drivers/$driverId/approve'), headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> rejectDriver(String driverId, String reason) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/drivers/$driverId/reject'),
        headers: await _getHeaders(),
        body: jsonEncode({'reason': reason}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getDriverById(String driverId) async {
    try {
      final baseUrlRoot = baseUrl.replaceAll('/admin', '');
      final response = await http.get(Uri.parse('$baseUrlRoot/auth/documents/$driverId'), headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
