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
  });

  VendorOrderModel copyWith({
    VendorOrderStatus? status,
    double? totalAmount,
    bool? customerPaid,
    String? paymentMethod,
    String? vendorPaymentStatus,
    bool? isNotified,
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
    );
  }
}

