import 'dart:convert';
import 'package:flutter/material.dart';
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

  Color get planColor {
    try {
      final clean = color.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF4F46E5);
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
  static String get baseUrl => '${(dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null) ?? 'http://54.204.9.126:5000/api/v1'}/subscriptions';

  static Future<Map<String, String>> _getHeaders([Map<String, String>? customHeaders]) async {
    if (customHeaders != null && customHeaders.isNotEmpty) {
      return customHeaders;
    }
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('admin_user');
    String? token;
    if (userStr != null) {
      try {
        final user = jsonDecode(userStr);
        token = user['token'];
      } catch (_) {}
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<AdminSubscriptionPlan>> getAllPlans([Map<String, String>? headers]) async {
    try {
      final reqHeaders = await _getHeaders(headers);
      final res = await http.get(Uri.parse('$baseUrl/admin'), headers: reqHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => AdminSubscriptionPlan.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> createPlan(AdminSubscriptionPlan plan, [Map<String, String>? headers]) async {
    try {
      final reqHeaders = await _getHeaders(headers);
      final res = await http.post(
        Uri.parse('$baseUrl/admin'),
        headers: reqHeaders,
        body: jsonEncode(plan.toJson()),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updatePlan(String id, Map<String, dynamic> updates, [Map<String, String>? headers]) async {
    try {
      final reqHeaders = await _getHeaders(headers);
      final res = await http.put(
        Uri.parse('$baseUrl/admin/$id'),
        headers: reqHeaders,
        body: jsonEncode(updates),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deletePlan(String id, [Map<String, String>? headers]) async {
    try {
      final reqHeaders = await _getHeaders(headers);
      final res = await http.delete(Uri.parse('$baseUrl/admin/$id'), headers: reqHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
