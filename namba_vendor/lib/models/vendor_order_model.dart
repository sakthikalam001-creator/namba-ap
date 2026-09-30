class VendorOrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;

  VendorOrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });
}

enum VendorOrderStatus { pending, accepted, preparing, ready, handedOver, rejected }
enum VendorOrderType { standard, text, photo }

class VendorOrderModel {
  final String id;
  final String displayId;
  final String customerName;
  final String customerPhone;
  final List<VendorOrderItem> items;
  double totalAmount;
  double subTotal;   // Vendor-quoted actual price
  double discount;   // Vendor-given discount
  VendorOrderStatus status;
  final VendorOrderType orderType;
  final String? textContent;
  final String? photoPath;
  final String? photoUrl;
  final DateTime timestamp;
  final String paymentMethod;
  bool customerPaid;
  String? vendorPaymentStatus; // 'Pending', 'Completed', 'Failed'
  bool isNotified;
  final double? storeLat;
  final double? storeLng;
  final double? destLat;
  final double? destLng;
  String? cancelledBy;
  String? cancellationReason;
  DateTime? acceptedAt;
  DateTime? prepStartedAt;
  DateTime? readyAt;
  DateTime? handedOverAt;
  int prepTimeMinutes;
  int packingDurationSeconds;
  bool isOfficeDelivery;
  String? deliveryAddressLabel;

  VendorOrderModel({
    required this.id,
    required this.displayId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.totalAmount,
    this.subTotal = 0.0,
    this.discount = 0.0,
    this.status = VendorOrderStatus.pending,
    this.orderType = VendorOrderType.standard,
    this.textContent,
    this.photoPath,
    this.photoUrl,
    required this.timestamp,
    this.paymentMethod = 'COD',
    this.customerPaid = false,
    this.vendorPaymentStatus = 'Pending',
    this.isNotified = false,
    this.storeLat,
    this.storeLng,
    this.destLat,
    this.destLng,
    this.cancelledBy,
    this.cancellationReason,
    this.acceptedAt,
    this.prepStartedAt,
    this.readyAt,
    this.handedOverAt,
    this.prepTimeMinutes = 10,
    this.packingDurationSeconds = 0,
    this.isOfficeDelivery = false,
    this.deliveryAddressLabel,
  });

  VendorOrderModel copyWith({
    VendorOrderStatus? status,
    double? totalAmount,
    bool? customerPaid,
    String? paymentMethod,
    String? vendorPaymentStatus,
    bool? isNotified,
    DateTime? acceptedAt,
    DateTime? prepStartedAt,
    DateTime? readyAt,
    DateTime? handedOverAt,
    int? prepTimeMinutes,
    int? packingDurationSeconds,
    bool? isOfficeDelivery,
    String? deliveryAddressLabel,
  }) {
    return VendorOrderModel(
      id: id,
      displayId: displayId,
      customerName: customerName,
      customerPhone: customerPhone,
      items: items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      orderType: orderType,
      textContent: textContent,
      photoPath: photoPath,
      photoUrl: photoUrl,
      timestamp: timestamp,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerPaid: customerPaid ?? this.customerPaid,
      vendorPaymentStatus: vendorPaymentStatus ?? this.vendorPaymentStatus,
      isNotified: isNotified ?? this.isNotified,
      storeLat: storeLat,
      storeLng: storeLng,
      destLat: destLat,
      destLng: destLng,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      prepStartedAt: prepStartedAt ?? this.prepStartedAt,
      readyAt: readyAt ?? this.readyAt,
      handedOverAt: handedOverAt ?? this.handedOverAt,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      packingDurationSeconds: packingDurationSeconds ?? this.packingDurationSeconds,
      isOfficeDelivery: isOfficeDelivery ?? this.isOfficeDelivery,
      deliveryAddressLabel: deliveryAddressLabel ?? this.deliveryAddressLabel,
    );
  }

  String get shortDisplayId {
    if (displayId.isNotEmpty && displayId.length <= 15) {
      return displayId.startsWith('#') ? displayId : '#$displayId';
    }
    if (id.length >= 5) {
      return '#NM-${id.substring(id.length - 5).toUpperCase()}';
    }
    return '#$id';
  }

  String get formattedPrice {
    if (totalAmount <= 0) return '₹0';
    if (totalAmount % 1 == 0) {
      return '₹${totalAmount.toInt()}';
    }
    return '₹${totalAmount.round()}';
  }

  int get remainingPrepSeconds {
    if (status == VendorOrderStatus.ready || status == VendorOrderStatus.handedOver || status == VendorOrderStatus.rejected || status == VendorOrderStatus.pending) {
      return 0;
    }
    // Countdown starts right from when the order is accepted!
    final start = acceptedAt ?? prepStartedAt ?? timestamp;
    final limitMinutes = prepTimeMinutes > 0 ? prepTimeMinutes : 10;
    final deadline = start.add(Duration(minutes: limitMinutes));
    final diff = deadline.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  String get remainingPrepFormatted {
    final secs = remainingPrepSeconds;
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get packedTimeFormatted {
    int secs = packingDurationSeconds;
    if (secs <= 0) {
      final start = acceptedAt ?? prepStartedAt;
      if (start != null) {
        final end = readyAt ?? handedOverAt ?? DateTime.now();
        secs = end.difference(start).inSeconds;
      }
    }
    if (secs <= 0) return 'Packed';
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  bool get isPrepUrgent {
    if (status != VendorOrderStatus.accepted && status != VendorOrderStatus.preparing) return false;
    final secs = remainingPrepSeconds;
    return secs > 0 && secs <= 60; // Last 1 minute!
  }

  bool get isPrepOverdue {
    if (status != VendorOrderStatus.accepted && status != VendorOrderStatus.preparing) return false;
    return remainingPrepSeconds == 0;
  }
}

