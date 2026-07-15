import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final String period;
  final List<String> features;
  final String icon;
  final String color;
  final bool isPopular;
  final bool isActive;

  AdminSubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    required this.icon,
    required this.color,
    required this.isPopular,
    this.isActive = true,
  });

  factory AdminSubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionPlan(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      period: json['period'] ?? 'month',
      features: List<String>.from(json['features'] ?? []),
      icon: json['icon'] ?? 'flash_circle',
      color: json['color'] ?? '#00BFA5',
      isPopular: json['isPopular'] ?? false,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'period': period,
      'features': features,
      'icon': icon,
      'color': color,
      'isPopular': isPopular,
      'isActive': isActive,
    };
  }
}

class SubscriptionService {
  static String get baseUrl => '${dotenv.env['API_BASE_URL'] ?? 'http://100.53.131.76:5000/api/v1'}/subscriptions';

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

  static Future<List<AdminSubscriptionPlan>> getAllPlans() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/admin'), headers: await _getHeaders());
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((item) => AdminSubscriptionPlan.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> createPlan(AdminSubscriptionPlan plan) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin'),
        headers: await _getHeaders(),
        body: jsonEncode(plan.toJson()),
      );
      return jsonDecode(res.body)['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updatePlan(String id, Map<String, dynamic> updates) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/admin/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(updates),
      );
      return jsonDecode(res.body)['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deletePlan(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/admin/$id'), headers: await _getHeaders());
      return jsonDecode(res.body)['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
