import 'dart:convert';
import 'dart:io';

void main() async {
  final request = await HttpClient().getUrl(Uri.parse('http://100.50.39.221:5000/api/v1/orders/vendor/6a57aefb16962c32adc0341c'));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  
  final data = jsonDecode(body)['data'] as List;

  print('Total orders from JSON: ${data.length}');

  int parsedCount = 0;
  for (var ao in data) {
    try {
      double parseDouble(dynamic val, [double fallback = 0.0]) {
        if (val == null) return fallback;
        if (val is num) return val.toDouble();
        if (val is String) return double.tryParse(val) ?? fallback;
        return fallback;
      }
      
      final dId = ao['displayId'] ?? 'NM-${ao['_id']?.substring(ao['_id']?.length > 5 ? ao['_id']?.length - 5 : 0).toUpperCase() ?? 'Order'}';
      
      // try parsing dates, amounts etc.
      DateTime.parse(ao['createdAt'] ?? DateTime.now().toIso8601String());
      parseDouble(ao['subTotal']);
      
      parsedCount++;
    } catch (e) {
      print('Error parsing order ${ao['_id']}: $e');
    }
  }
  print('Successfully parsed: $parsedCount');
}
