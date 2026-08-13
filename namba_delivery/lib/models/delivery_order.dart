
import 'package:geolocator/geolocator.dart';

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
  final String storePhone;
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
  final double? distanceKmBackend;
  final double? driverEarningsBackend;

  DeliveryOrder({
    required this.id,
    required this.storeName,
    required this.storeAddress,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    this.storePhone = 'N/A',
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
    this.distanceKmBackend,
    this.driverEarningsBackend,
  });

  double get distanceInKm {
    if (distanceKmBackend != null && distanceKmBackend! > 0) return distanceKmBackend!;
    if (storeLat == null || storeLng == null || destLat == null || destLng == null) return 0.0;
    if (storeLat == 0 || destLat == 0) return 0.0;
    try {
      final meters = Geolocator.distanceBetween(storeLat!, storeLng!, destLat!, destLng!);
      // Accurate two-wheeler city road distance (straight line x 1.15)
      return (meters * 1.15) / 1000.0;
    } catch (_) {
      return 0.0;
    }
  }

  double calculateTotalTripDistance(double? driverLat, double? driverLng) {
    double pickupKm = 0.0;
    if (driverLat != null && driverLng != null && driverLat != 0 && storeLat != null && storeLng != null && storeLat != 0) {
      try {
        final meters = Geolocator.distanceBetween(driverLat, driverLng, storeLat!, storeLng!);
        pickupKm = meters / 1000.0;
      } catch (_) {}
    }
    double dropKm = distanceInKm;
    return pickupKm + dropKm;
  }

  double computeDriverEarningsWithDriverLoc(double? driverLat, double? driverLng) {
    final totalKm = calculateTotalTripDistance(driverLat, driverLng);
    if (totalKm <= 0) {
      if (driverEarningsBackend != null && driverEarningsBackend! > 0) {
        return driverEarningsBackend!;
      }
      return 10.0;
    }
    double earnings = totalKm * 7.0;
    if (totalKm > 50) {
      earnings = (50 * 7.0) + ((totalKm - 50) * 9.0);
    }
    return earnings < 10.0 ? 10.0 : earnings.roundToDouble();
  }

  double get computedDriverEarnings => computeDriverEarningsWithDriverLoc(null, null);

  String get formattedDistance {
    final km = distanceInKm;
    if (km <= 0) return 'Map Route';
    return '${km.toStringAsFixed(1)} KM';
  }

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
      storePhone: storePhone,
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
