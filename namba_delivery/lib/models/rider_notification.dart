enum NotificationCategory {
  all,
  order,
  payout,
  kyc,
  support,
  system,
}

class RiderNotification {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime timestamp;
  bool isRead;
  final Map<String, dynamic>? data;

  RiderNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category.name,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'data': data,
  };

  factory RiderNotification.fromJson(Map<String, dynamic> json) {
    NotificationCategory cat = NotificationCategory.system;
    try {
      cat = NotificationCategory.values.firstWhere(
        (c) => c.name == (json['category'] ?? 'system'),
        orElse: () => NotificationCategory.system,
      );
    } catch (_) {}

    return RiderNotification(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      category: cat,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] == true,
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : null,
    );
  }
}
