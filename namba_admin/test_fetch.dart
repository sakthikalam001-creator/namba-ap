import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY5ZDdhMjNkMWNmMDBlNzI0NWVmNjc0OCIsImlhdCI6MTc4MDY0MjA5MywiZXhwIjoxNzgzMjM0MDkzfQ.fJ2iiY3H7zMCvOXyL75X9-TBKXhF9cmJ3ikbv3eFp5g';
  final baseUrl = 'http://192.168.5.16:5000/api/v1';

  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  final endpoints = {
    'vendors': '$baseUrl/admin/vendors',
    'vendors/pending': '$baseUrl/admin/vendors/pending',
    'dispatch/orders': '$baseUrl/admin/dispatch/orders',
    'dispatch/drivers': '$baseUrl/admin/dispatch/drivers',
    'drivers/pending': '$baseUrl/admin/drivers/pending',
    'drivers': '$baseUrl/admin/drivers',
    'admins': '$baseUrl/admin/admins',
    'orders/customer': '$baseUrl/admin/orders/customer',
    'orders/customer/history': '$baseUrl/admin/orders/customer/history',
    'zones': '$baseUrl/admin/zones',
    'financial-analytics': '$baseUrl/admin/financial-analytics',
    'financial-analytics/reports': '$baseUrl/admin/financial-analytics/reports',
  };

  for (var entry in endpoints.entries) {
    final name = entry.key;
    final url = entry.value;
    print('\n========================================');
    print('Testing endpoint: $name ($url)');
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      print('Status code: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('Error response: ${response.body}');
        continue;
      }
      
      final data = jsonDecode(response.body);
      print('Decoded success: ${data['success']}');
      
      if (data['success'] == true) {
        final rawData = data['data'];
        print('Raw data type: ${rawData.runtimeType}');
        
        if (name == 'vendors') {
          final list = List<Map<String, dynamic>>.from(rawData);
          print('Successfully parsed $name list! Length: ${list.length}');
        } else if (name == 'vendors/pending') {
          final list = List<Map<String, dynamic>>.from(rawData);
          print('Successfully parsed $name list! Length: ${list.length}');
        } else if (name == 'zones') {
          final list = List<Map<String, dynamic>>.from(rawData);
          print('Successfully parsed $name list! Length: ${list.length}');
        } else if (name == 'admins') {
          final list = List<Map<String, dynamic>>.from(rawData);
          print('Successfully parsed $name list! Length: ${list.length}');
        } else if (name == 'drivers') {
          final list = List<Map<String, dynamic>>.from(rawData);
          print('Successfully parsed $name list! Length: ${list.length}');
        } else if (name == 'drivers/pending') {
          final list = List<Map<String, dynamic>>.from(rawData);
          print('Successfully parsed $name list! Length: ${list.length}');
        } else if (name == 'orders/customer/history') {
          final list = List<Map<String, dynamic>>.from(rawData);
          print('Successfully parsed $name list! Length: ${list.length}');
        } else if (name == 'financial-analytics') {
          // Check financial-analytics response structure
          print('Keys: ${rawData.keys}');
          final topVendors = List<Map<String, dynamic>>.from(rawData['topVendors'] ?? []);
          final driverPerformance = List<Map<String, dynamic>>.from(rawData['driverPerformance'] ?? []);
          print('Top Vendors: ${topVendors.length}, Driver Perf: ${driverPerformance.length}');
        } else if (name == 'financial-analytics/reports') {
          // Check reports response structure
          print('Keys: ${rawData.keys}');
          final payouts = List<Map<String, dynamic>>.from(rawData['payouts'] ?? []);
          final auditLog = List<Map<String, dynamic>>.from(rawData['auditLog'] ?? []);
          print('Payouts: ${payouts.length}, Audit Log: ${auditLog.length}');
        }
      }
    } catch (e, st) {
      print('EXCEPTION for $name: $e');
      print('Stack trace:\n$st');
    }
  }
}
