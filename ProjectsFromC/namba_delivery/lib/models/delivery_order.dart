
enum DeliveryStatus {
  allocated,
  pickingUp,
  pickedUp,
  onTheWay,
  delivered,
  cancelled
}

class DeliveryOrder {
  final String id;
  final String storeName;
  final String storeAddress;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final double totalAmount;
  final List<String> items;
  final DeliveryStatus status;
  final DateTime timestamp;
  final String displayId;
  final String rawStatus;
  final String paymentMethod;
  final bool isCustomStore;
  final String orderType; // 'Cart', 'Text', 'Photo'
  final String? textContent;
  final String? billPhotoPath;
  final double? storeLat;
  final double? storeLng;
  final double? destLat;
  final double? destLng;
  final bool vendorPaymentDetailsUploadedByDriver;
  final String vendorPaymentStatus;
  final String paymentStatus;

  DeliveryOrder({
    required this.id,
    required this.storeName,
    required this.storeAddress,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.totalAmount,
    required this.items,
    required this.status,
    required this.timestamp,
    this.displayId = '',
    this.rawStatus = '',
    this.paymentMethod = 'COD',
    this.isCustomStore = false,
    this.orderType = 'Cart',
    this.textContent,
    this.billPhotoPath,
    this.storeLat,
    this.storeLng,
    this.destLat,
    this.destLng,
    this.vendorPaymentDetailsUploadedByDriver = false,
    this.vendorPaymentStatus = 'Pending',
    this.paymentStatus = 'Pending',
  });

  DeliveryOrder copyWith({
    DeliveryStatus? status,
    String? rawStatus,
    double? totalAmount,
    String? billPhotoPath,
    double? storeLat,
    double? storeLng,
    double? destLat,
    double? destLng,
    bool? vendorPaymentDetailsUploadedByDriver,
    String? vendorPaymentStatus,
    String? paymentStatus,
  }) {
    return DeliveryOrder(
      id: id,
      storeName: storeName,
      storeAddress: storeAddress,
      customerName: customerName,
      customerAddress: customerAddress,
      customerPhone: customerPhone,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items,
      status: status ?? this.status,
      timestamp: timestamp,
      displayId: displayId,
      rawStatus: rawStatus ?? this.rawStatus,
      paymentMethod: paymentMethod,
      isCustomStore: isCustomStore,
      orderType: orderType,
      textContent: textContent,
      billPhotoPath: billPhotoPath ?? this.billPhotoPath,
      storeLat: storeLat ?? this.storeLat,
      storeLng: storeLng ?? this.storeLng,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
      vendorPaymentDetailsUploadedByDriver: vendorPaymentDetailsUploadedByDriver ?? this.vendorPaymentDetailsUploadedByDriver,
      vendorPaymentStatus: vendorPaymentStatus ?? this.vendorPaymentStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }
}
