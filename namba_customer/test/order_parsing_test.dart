import 'package:flutter_test/flutter_test.dart';
import 'package:namaba_customer/models/models.dart';

void main() {
  group('DeliveryOrder.fromMap status mapping tests', () {
    test('Should map "Assigned" status to OrderStatus.assigned', () {
      final map = {
        'id': '123',
        'status': 'Assigned',
        'storeName': 'OM Muruga Mess',
      };
      final order = DeliveryOrder.fromMap(map);
      expect(order.status, OrderStatus.assigned);
    });

    test('Should map "On The Way" status to OrderStatus.outForDelivery', () {
      final map = {
        'id': '123',
        'status': 'On The Way',
        'storeName': 'OM Muruga Mess',
      };
      final order = DeliveryOrder.fromMap(map);
      expect(order.status, OrderStatus.outForDelivery);
    });

    test('Should fallback storeName to customStoreName if storeName is empty', () {
      final map = {
        'id': '123',
        'status': 'Pending',
        'storeName': '',
        'customStoreName': 'Custom Shop Name',
      };
      final order = DeliveryOrder.fromMap(map);
      expect(order.storeName, 'Custom Shop Name');
    });

    test('Should fallback storeName to "Unknown Store" if both are empty', () {
      final map = {
        'id': '123',
        'status': 'Pending',
        'storeName': '',
        'customStoreName': '',
      };
      final order = DeliveryOrder.fromMap(map);
      expect(order.storeName, 'Unknown Store');
    });

    test('Should parse vendor name from nested vendor Map', () {
      final map = {
        'id': '123',
        'status': 'Pending',
        'vendor': {
          '_id': 'vendor_123',
          'storeName': 'OM Muruga Mess',
          'category': 'Food',
        }
      };
      final order = DeliveryOrder.fromMap(map);
      expect(order.storeId, 'vendor_123');
      expect(order.storeName, 'OM Muruga Mess');
      expect(order.storeCategory, 'Food');
    });

    test('Should parse delivery partner details from driver Map', () {
      final map = {
        'id': '123',
        'status': 'Pending',
        'storeName': 'OM Muruga Mess',
        'driver': {
          '_id': '69d5efb4581e5e14b3605920',
          'name': 'arun',
          'phone': '9442733602',
          'vehicleType': 'bike',
          'vehicleNumber': 'TN33AX7022',
          'rating': 4.9,
        }
      };
      final order = DeliveryOrder.fromMap(map);
      expect(order.deliveryPartner, isNotNull);
      expect(order.deliveryPartner!.name, 'arun');
      expect(order.deliveryPartner!.phone, '9442733602');
      expect(order.deliveryPartner!.vehicleType, 'bike');
      expect(order.deliveryPartner!.vehicleNumber, 'TN33AX7022');
      expect(order.deliveryPartner!.rating, 4.9);
    });

    test('Should parse platformFee and deliveryCharge correctly from map', () {
      final map = {
        'id': '123',
        'status': 'Pending',
        'storeName': 'OM Muruga Mess',
        'customerPlatformFee': 5,
        'deliveryCharge': 30,
      };
      final order = DeliveryOrder.fromMap(map);
      expect(order.platformFee, 5.0);
      expect(order.deliveryFee, 30.0);
    });
  });
}
