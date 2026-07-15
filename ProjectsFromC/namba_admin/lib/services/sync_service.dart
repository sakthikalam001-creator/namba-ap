import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum CoreOrderStatus {
  pending,
  accepted,
  confirmed,
  preparing,
  assigned,
  ready,
  pickedUp,
  onTheWay,
  delivered,
  cancelled,
}
enum CoreOrderType { standard, text, photo }

class CoreProduct {
  final String id; final String name; final String description; final double price; final String image; final String category;
  CoreProduct({required this.id, required this.name, required this.description, required this.price, required this.image, required this.category});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'description': description, 'price': price, 'image': image, 'category': category};
  factory CoreProduct.fromMap(Map<dynamic, dynamic> m) => CoreProduct(id: m['id'] ?? '', name: m['name'] ?? '', description: m['description'] ?? '', price: (m['price'] ?? 0).toDouble(), image: m['image'] ?? '', category: m['category'] ?? '');
}

class CoreCartItem {
  final CoreProduct product; final int quantity;
  CoreCartItem({required this.product, required this.quantity});
  Map<String, dynamic> toMap() => {'product': product.toMap(), 'quantity': quantity};
  factory CoreCartItem.fromMap(Map<dynamic, dynamic> m) => CoreCartItem(product: CoreProduct.fromMap(m['product']), quantity: m['quantity'] ?? 1);
}

class CoreStore {
  final String id; final String name; final String image; final String category; final double rating; final int reviewCount; final String distance; final String deliveryTime; final double deliveryFee;
  CoreStore({required this.id, required this.name, required this.image, required this.category, required this.rating, required this.reviewCount, required this.distance, required this.deliveryTime, required this.deliveryFee});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'image': image, 'category': category, 'rating': rating, 'reviewCount': reviewCount, 'distance': distance, 'deliveryTime': deliveryTime, 'deliveryFee': deliveryFee};
  factory CoreStore.fromMap(Map<dynamic, dynamic> m) => CoreStore(id: m['id'] ?? '', name: m['name'] ?? '', image: m['image'] ?? '', category: m['category'] ?? '', rating: (m['rating'] ?? 4.5).toDouble(), reviewCount: m['reviewCount'] ?? 0, distance: m['distance'] ?? '', deliveryTime: m['deliveryTime'] ?? '', deliveryFee: (m['deliveryFee'] ?? 0).toDouble());
}

class CoreOrder {
  final String id;
  final CoreStore store;
  final List<CoreCartItem> items;
  CoreOrderStatus status;
  final CoreOrderType type;
  final String? textContent;
  final String? photoPath;
  final double subtotal;
  final double deliveryFee;
  final double taxes;
  double total;
  final DateTime createdAt;
  bool customerPaid;
  final String displayId;
  final String rawStatus;
  final String paymentMethod;
  final String? billPhotoPath;
  final DateTime? billUploadedAt;
  final bool isCustomStore;
  final Map<String, dynamic>? driver;
  final double platformFee;
  final double distanceKm;
  final String? customerName;
  final String? customerPhone;

  CoreOrder({required this.id, required this.store, required this.items, required this.status, required this.type, this.textContent, this.photoPath, required this.subtotal, required this.deliveryFee, required this.taxes, required this.total, required this.createdAt, this.customerPaid = false, this.displayId = '', this.rawStatus = '', this.paymentMethod = 'COD', this.billPhotoPath, this.billUploadedAt, this.isCustomStore = false, this.driver, this.platformFee = 0.0, this.distanceKm = 0.0, this.customerName, this.customerPhone});

  Map<String, dynamic> toMap() => {'id': id, 'store': store.toMap(), 'items': items.map((i) => i.toMap()).toList(), 'status': status.index, 'type': type.index, 'textContent': textContent, 'photoPath': photoPath, 'subtotal': subtotal, 'deliveryFee': deliveryFee, 'taxes': taxes, 'total': total, 'createdAt': createdAt.millisecondsSinceEpoch, 'customerPaid': customerPaid, 'displayId': displayId, 'rawStatus': rawStatus, 'paymentMethod': paymentMethod, 'billPhotoPath': billPhotoPath, 'billUploadedAt': billUploadedAt?.millisecondsSinceEpoch, 'isCustomStore': isCustomStore, 'driver': driver, 'platformFee': platformFee, 'distanceKm': distanceKm, 'customerName': customerName, 'customerPhone': customerPhone};

  factory CoreOrder.fromMap(Map<dynamic, dynamic> m) => CoreOrder(
    id: m['id'] ?? '', 
    store: CoreStore.fromMap(m['store']), 
    items: (m['items'] as List? ?? []).map((i) => CoreCartItem.fromMap(i)).toList(), 
    status: CoreOrderStatus.values[m['status'] ?? 0], 
    type: CoreOrderType.values[m['type'] ?? 0], 
    textContent: m['textContent'], 
    photoPath: m['photoPath'], 
    subtotal: (m['subtotal'] ?? 0).toDouble(), 
    deliveryFee: (m['deliveryFee'] ?? 0).toDouble(), 
    taxes: (m['taxes'] ?? 0).toDouble(), 
    total: (m['total'] ?? 0).toDouble(), 
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] ?? 0), 
    customerPaid: m['customerPaid'] ?? false,
    displayId: m['displayId'] ?? '',
    rawStatus: m['rawStatus'] ?? '',
    paymentMethod: m['paymentMethod'] ?? 'COD',
    billPhotoPath: m['billPhotoPath'],
    billUploadedAt: m['billUploadedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(m['billUploadedAt']) : null,
    isCustomStore: m['isCustomStore'] ?? false,
    driver: m['driver'] != null ? Map<String, dynamic>.from(m['driver']) : null,
    platformFee: (m['platformFee'] ?? 0).toDouble(),
    distanceKm: (m['distanceKm'] ?? 0).toDouble(),
    customerName: m['customerName'],
    customerPhone: m['customerPhone'],
  );

  String get statusText {
    switch (status) {
      case CoreOrderStatus.pending: return 'Pending';
      case CoreOrderStatus.accepted: return 'Accepted';
      case CoreOrderStatus.confirmed: return 'Confirmed';
      case CoreOrderStatus.preparing: return 'Preparing';
      case CoreOrderStatus.assigned: return 'Rider Assigned';
      case CoreOrderStatus.ready: return 'Ready for Handover';
      case CoreOrderStatus.pickedUp: return 'Picked Up';
      case CoreOrderStatus.onTheWay: return 'On the Way';
      case CoreOrderStatus.delivered: return 'Delivered';
      case CoreOrderStatus.cancelled: return 'Cancelled';
    }
  }
}

class LocalSyncService {
  static final String _filePath = '${Directory.systemTemp.path}/namba_shared_db.json';

  // Only enable local JSON sync in debug/profile mode (for development testing)
  // Globally disabled for Live DB testing
  static bool get isEnabled => kDebugMode || kProfileMode;

  static Future<List<CoreOrder>> getAllOrders() async {
    if (!isEnabled) return [];
    try {
      final file = File(_filePath);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final List list = jsonDecode(content);
      return list.map((m) => CoreOrder.fromMap(m)).toList();
    } catch (_) { return []; }
  }

  static Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    if (!isEnabled) return;
    try {
      final orders = await getAllOrders();
      final idx = orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        final existing = orders[idx];
        final map = existing.toMap();
        map.addAll(data);
        orders[idx] = CoreOrder.fromMap(map);
        await File(_filePath).writeAsString(jsonEncode(orders.map((o) => o.toMap()).toList()));
      }
    } catch (_) {}
  }

  static Future<void> updateOrderStatus(String orderId, CoreOrderStatus status, {String? rawStatus, double? newTotal, double? newSubtotal, double? newDeliveryFee, double? newPlatformFee}) async {
    await updateOrder(orderId, {
      'status': status.index,
      if (rawStatus != null) 'rawStatus': rawStatus,
      if (newTotal != null) 'total': newTotal,
      if (newSubtotal != null) 'subtotal': newSubtotal,
      if (newDeliveryFee != null) 'deliveryFee': newDeliveryFee,
      if (newPlatformFee != null) 'platformFee': newPlatformFee,
    });
  }

  static Future<void> markCustomerPaid(String orderId, {double total = 0}) async {
    await updateOrder(orderId, {
      'customerPaid': true,
      if (total > 0) 'total': total,
    });
  }

  static Future<void> assignDriver(String orderId, Map<String, dynamic> driver) async {
    await updateOrder(orderId, {
      'status': CoreOrderStatus.assigned.index,
      'rawStatus': 'Assigned',
      'driver': driver,
    });
  }

  static Future<void> saveOrder(CoreOrder order) async {
    if (!isEnabled) return;
    try {
      final orders = await getAllOrders();
      final idx = orders.indexWhere((o) => o.id == order.id);
      if (idx != -1) orders[idx] = order;
      else orders.add(order);
      await File(_filePath).writeAsString(jsonEncode(orders.map((o) => o.toMap()).toList()));
    } catch (_) {}
  }
}
