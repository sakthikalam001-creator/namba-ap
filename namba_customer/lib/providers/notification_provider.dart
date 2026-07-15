import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/models.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String icon;
  final String orderId;
  final OrderStatus status;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.orderId,
    required this.status,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'icon': icon,
      'orderId': orderId,
      'status': status.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isRead': isRead,
    };
  }

  factory AppNotification.fromMap(Map<dynamic, dynamic> map) {
    return AppNotification(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      icon: map['icon'],
      orderId: map['orderId'],
      status: OrderStatus.values[map['status']],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      isRead: map['isRead'] ?? false,
    );
  }
}

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  static const String _boxName = 'notifications_box';

  NotificationProvider() {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final box = await Hive.openBox(_boxName);
    final List<Map<dynamic, dynamic>> saved = box.get('list', defaultValue: [])?.cast<Map<dynamic, dynamic>>() ?? [];
    _notifications.clear();
    _notifications.addAll(saved.map((m) => AppNotification.fromMap(m)));
    notifyListeners();
  }

  Future<void> _saveToHive() async {
    final box = await Hive.openBox(_boxName);
    await box.put('list', _notifications.map((n) => n.toMap()).toList());
  }

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications.reversed.toList());

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void addNotification({
    required String orderId,
    required OrderStatus status,
    required String storeName,
  }) {
    final (title, body, icon) = _getContent(status, storeName);
    _notifications.add(AppNotification(
      id: '${orderId}_${status.name}',
      title: title,
      body: body,
      icon: icon,
      orderId: orderId,
      status: status,
      createdAt: DateTime.now(),
    ));
    _saveToHive();
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    _saveToHive();
    notifyListeners();
  }

  void markRead(String id) {
    final n = _notifications.where((n) => n.id == id).firstOrNull;
    if (n != null) {
      n.isRead = true;
      _saveToHive();
      notifyListeners();
    }
  }

  (String, String, String) _getContent(OrderStatus status, String storeName) {
    switch (status) {
      case OrderStatus.placed:
        return ('Order Placed!', 'Your order from $storeName is confirmed.', '✅');
      case OrderStatus.accepted:
        return ('Order Confirmed!', 'Your order is confirmed by $storeName.', '🏪');
      case OrderStatus.preparing:
        return ('Preparing Order', '$storeName is preparing your items.', '👨‍🍳');
      case OrderStatus.assigned:
        return ('Rider Assigned', 'A delivery partner is on the way to pick up.', '🚴');
      case OrderStatus.ready:
        return ('Rider Reached Shop', 'Your rider has arrived at $storeName.', '📍');
      case OrderStatus.pickedUp:
        return ('Picked Up', 'Your rider is on the way to your location.', '🚴');
      case OrderStatus.outForDelivery:
        return ('Out for Delivery!', 'Your order is on the way!', '🚴');
      case OrderStatus.arrived:
        return ('Rider Arrived!', 'Your rider is at your location.', '🏠');
      case OrderStatus.delivered:
        return ('Delivered!', 'Enjoy your order from $storeName!', '🎉');
      case OrderStatus.rejected:
        return ('Order Rejected', '$storeName could not accept your order.', '❌');
    }
  }
}
