// Models
class StoreCategory {
  static const String grocery = 'Grocery';
  static const String bakery = 'Bakery';
  static const String medicine = 'Medicine';
  static const String food = 'Food';

  static List<String> all = [grocery, bakery, medicine, food];
}

class Store {
  final String id;
  final String name;
  final String category;
  final String description;
  final String ownerPhone;
  final double rating;
  final int deliveryTime; // minutes
  final double distanceKm;
  final List<String> photoUrls;
  final List<Product> products;
  final bool isOpen;
  final bool hasItemList;

  Store({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.ownerPhone,
    required this.rating,
    required this.deliveryTime,
    required this.distanceKm,
    required this.photoUrls,
    required this.products,
    required this.isOpen,
    this.hasItemList = false,
  });

  Store copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    String? ownerPhone,
    double? rating,
    int? deliveryTime,
    double? distanceKm,
    List<String>? photoUrls,
    List<Product>? products,
    bool? isOpen,
    bool? hasItemList,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      rating: rating ?? this.rating,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      distanceKm: distanceKm ?? this.distanceKm,
      photoUrls: photoUrls ?? this.photoUrls,
      products: products ?? this.products,
      isOpen: isOpen ?? this.isOpen,
      hasItemList: hasItemList ?? this.hasItemList,
    );
  }
}

class UserAddress {
  final String id;
  final String label; // "Home", "Work", etc.
  final String address;
  final double? lat;
  final double? lng;

  UserAddress({
    required this.id,
    required this.label,
    required this.address,
    this.lat,
    this.lng,
  });
}

class Product {
  final String id;
  final String name;
  final double price;
  final String unit;
  final String? imageUrl;
  final String storeId;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    this.imageUrl,
    required this.storeId,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'price': price, 'unit': unit, 'imageUrl': imageUrl, 'storeId': storeId,
  };

  factory Product.fromMap(Map<dynamic, dynamic> map) {
    double pPrice = 0.0;
    final rawPrice = map['price'] ?? map['cost'] ?? map['amount'] ?? map['unitPrice'];
    if (rawPrice is num) pPrice = rawPrice.toDouble();
    else if (rawPrice is String) pPrice = double.tryParse(rawPrice) ?? 0.0;

    // Aggressive name recovery: If name is missing or 'Unnamed', try other common keys
    String pName = map['name'] ?? 'Unnamed';
    if (pName == 'Unnamed' || pName.isEmpty) {
      pName = map['productName'] ?? map['product_name'] ?? map['itemName'] ?? map['item_name'] ?? 'Unnamed';
    }

    return Product(
      id: map['_id'] ?? map['id'] ?? '', 
      name: pName, 
      price: pPrice, 
      unit: map['unit'] ?? 'pcs', 
      imageUrl: map['imageUrl'] ?? map['image'] ?? '', 
      storeId: map['vendor']?.toString() ?? map['storeId']?.toString() ?? '',
    );
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;

  Map<String, dynamic> toMap() => {
    'product': product.toMap(), 'quantity': quantity,
  };

  factory CartItem.fromMap(Map<dynamic, dynamic> map) {
    int q = 1;
    final rawQ = map['quantity'];
    if (rawQ is num) q = rawQ.toInt();
    else if (rawQ is String) q = int.tryParse(rawQ) ?? 1;

    // Handle both nested {product: {...}} and flat {productName: "...", price: 123} structures
    Product p;
    if (map.containsKey('product')) {
      p = Product.fromMap(map['product'] ?? {});
    } else {
      // It's a flat OrderItem from backend
      p = Product.fromMap(map);
    }

    return CartItem(
      product: p,
      quantity: q,
    );
  }
}

enum OrderStatus { 
  placed,      // Pending
  accepted,    // Accepted
  preparing,   // Preparing
  assigned,    // Assigned
  ready,       // Ready (Rider Reached Shop)
  pickedUp,    // PickedUp (Rider On the Way)
  outForDelivery, // OutForDelivery (Rider On the Way)
  arrived,     // Arrived at location
  delivered,   // Delivered
  rejected     // Cancelled
}
enum OrderType { standard, text, photo }

class DeliveryPartner {
  final String name;
  final String phone;
  final double rating;
  final String vehicleType;
  final String vehicleNumber;

  DeliveryPartner({
    required this.name,
    required this.phone,
    required this.rating,
    required this.vehicleType,
    required this.vehicleNumber,
  });

  Map<String, dynamic> toMap() => {
    'name': name, 'phone': phone, 'rating': rating, 
    'vehicleType': vehicleType, 'vehicleNumber': vehicleNumber,
  };

  factory DeliveryPartner.fromMap(Map<dynamic, dynamic> map) => DeliveryPartner(
    name: map['name'], phone: map['phone'], rating: map['rating'].toDouble(),
    vehicleType: map['vehicleType'], vehicleNumber: map['vehicleNumber'],
  );
}

class DeliveryOrder {
  String id;
  String displayId;
  String storeId;
  String storeName;
  String storeCategory;
  List<CartItem> items;
  OrderStatus status;
  OrderType orderType;
  String? textContent;
  String? photoPath;
  String? billPhotoPath; // Shop's paper bill
  List<String> unavailableItems; // Items not in shop
  double totalAmount;
  DateTime placedAt;
  String deliveryAddress;
  DeliveryPartner? deliveryPartner;
  
  // New fields for ratings and timeline
  double? userRating;
  String? userReview;
  final Map<OrderStatus, DateTime> statusTimestamps;
  bool isPaymentDone;
  final bool isCustomStore;
  final String? customStoreName;
  final String? customStoreAddress;
  bool isDismissedFromHome;
  double distanceKm;
  double platformFee;
  double deliveryFee;
  double subTotal;    // Actual price before discount
  double discount;    // Discount given by vendor

  DeliveryOrder({
    required this.id,
    required this.displayId,
    required this.storeId,
    required this.storeName,
    required this.storeCategory,
    required this.items,
    required this.status,
    this.orderType = OrderType.standard,
    this.textContent,
    this.photoPath,
    this.billPhotoPath,
    List<String>? unavailableItems,
    required this.totalAmount,
    required this.placedAt,
    required this.deliveryAddress,
    this.deliveryPartner,
    this.userRating,
    this.userReview,
    Map<OrderStatus, DateTime>? statusTimestamps,
    this.isPaymentDone = false,
    this.isCustomStore = false,
    this.customStoreName,
    this.customStoreAddress,
    this.isDismissedFromHome = false,
    this.distanceKm = 0.5,
    this.platformFee = 5.0,
    this.deliveryFee = 30.0,
    this.subTotal = 0.0,
    this.discount = 0.0,
  }) : statusTimestamps = statusTimestamps ?? {OrderStatus.placed: placedAt},
       unavailableItems = unavailableItems ?? [];

  Map<String, dynamic> toMap() => {
    'id': id, 'displayId': displayId, 'storeId': storeId, 'storeName': storeName, 'storeCategory': storeCategory,
    'items': items.map((i) => i.toMap()).toList(),
    'status': status.index,
    'orderType': orderType.index,
    'textContent': textContent, 'photoPath': photoPath,
    'billPhotoPath': billPhotoPath, 'unavailableItems': unavailableItems,
    'totalAmount': totalAmount,
    'placedAt': placedAt.millisecondsSinceEpoch,
    'deliveryAddress': deliveryAddress,
    'deliveryPartner': deliveryPartner?.toMap(),
    'userRating': userRating, 'userReview': userReview,
    'isPaymentDone': isPaymentDone,
    'isCustomStore': isCustomStore,
    'customStoreName': customStoreName,
    'customStoreAddress': customStoreAddress,
    'isDismissedFromHome': isDismissedFromHome,
    'distanceKm': distanceKm,
    'platformFee': platformFee,
    'deliveryFee': deliveryFee,
    'statusTimestamps': statusTimestamps.map((k, v) => MapEntry(k.index.toString(), v.millisecondsSinceEpoch)),
  };

  factory DeliveryOrder.fromMap(Map<dynamic, dynamic> map) {
    // Determine Order Status from multiple potential formats (local int vs backend string)
    OrderStatus status = OrderStatus.placed;
    final rawStatus = map['status'];
    if (rawStatus is int) {
      status = OrderStatus.values[rawStatus];
    } else if (rawStatus is String) {
      switch (rawStatus) {
        case 'Pending':   status = OrderStatus.placed; break;
        case 'Accepted':  
        case 'Confirmed': status = OrderStatus.accepted; break; // Vendor accepted quote/order
        case 'Preparing': status = OrderStatus.preparing; break; // Vendor Accepted!
        case 'RiderAssigned': 
        case 'Assigned':  status = OrderStatus.assigned; break;
        case 'Ready':     status = OrderStatus.ready; break;
        case 'PickedUp':  status = OrderStatus.pickedUp; break;
        case 'OutForDelivery': 
        case 'On The Way': status = OrderStatus.outForDelivery; break;
        case 'Arrived':   status = OrderStatus.arrived; break;
        case 'Delivered': status = OrderStatus.delivered; break;
        case 'HandedOver': status = OrderStatus.pickedUp; break;
        case 'Cancelled': 
        case 'Rejected':  status = OrderStatus.rejected; break;
      }
    }

    // Handle Vendor Name/Id (might be nested if populated from backend)
    String storeId = map['storeId'] ?? '';
    String storeName = map['storeName'] ?? '';
    if (storeName.isEmpty) {
      storeName = map['customStoreName'] ?? '';
    }
    if (storeName.isEmpty) {
      storeName = 'Unknown Store';
    }
    String storeCategory = map['storeCategory'] ?? 'General';
    if (map['vendor'] != null) {
      if (map['vendor'] is Map) {
        storeId = map['vendor']['_id'] ?? storeId;
        final vName = map['vendor']['storeName'];
        if (vName != null && vName.toString().trim().isNotEmpty) {
          storeName = vName.toString();
        }
        storeCategory = map['vendor']['category'] ?? storeCategory;
      } else {
        storeId = map['vendor'].toString();
      }
    }

    // Handle Timestamps
    DateTime placedAt = DateTime.now();
    if (map['placedAt'] != null) {
      final p = map['placedAt'];
      if (p is int) placedAt = DateTime.fromMillisecondsSinceEpoch(p);
      else if (p is String) placedAt = DateTime.tryParse(p) ?? DateTime.now();
    } else if (map['createdAt'] != null) {
      placedAt = DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now();
    }

    final timestampsRaw = map['statusTimestamps'];
    Map<OrderStatus, DateTime> timestamps = {OrderStatus.placed: placedAt};
    if (timestampsRaw != null && timestampsRaw is Map) {
      timestampsRaw.forEach((k, v) {
        try {
          final s = OrderStatus.values[int.parse(k.toString())];
          DateTime? d;
          if (v is int) d = DateTime.fromMillisecondsSinceEpoch(v);
          else if (v is String) d = DateTime.tryParse(v);
          
          if (d != null) timestamps[s] = d;
        } catch (_) {}
      });
    }

    final id = map['_id'] ?? map['id'] ?? 'ORD';

    // Parse OrderType safely
    OrderType oType = OrderType.standard;
    final rawType = map['orderType'];
    if (rawType is int) {
      if (rawType >= 0 && rawType < OrderType.values.length) {
        oType = OrderType.values[rawType];
      }
    } else if (rawType is String) {
      if (rawType.toLowerCase() == 'text') oType = OrderType.text;
      else if (rawType.toLowerCase() == 'photo') oType = OrderType.photo;
      else oType = OrderType.standard;
    }

    DeliveryPartner? partner;
    if (map['deliveryPartner'] != null) {
      partner = DeliveryPartner.fromMap(map['deliveryPartner']);
    } else if (map['driver'] != null) {
      if (map['driver'] is Map) {
        final d = map['driver'];
        double rating = 4.8;
        if (d['rating'] != null) {
          if (d['rating'] is num) rating = d['rating'].toDouble();
          else if (d['rating'] is String) rating = double.tryParse(d['rating']) ?? 4.8;
        }
        partner = DeliveryPartner(
          name: d['name'] ?? 'Rider',
          phone: d['phone'] ?? '',
          rating: rating,
          vehicleType: d['vehicleType'] ?? 'Bike',
          vehicleNumber: d['vehicleNumber'] ?? '',
        );
      }
    }

    return DeliveryOrder(
      id: id, 
      displayId: map['displayId'] ?? (id.length > 6 ? '#${id.substring(id.length - 6)}' : id),
      storeId: storeId, 
      storeName: storeName, 
      storeCategory: storeCategory,
      items: (map['items'] as List? ?? []).map((i) => CartItem.fromMap(i)).toList(),
      status: status,
      orderType: oType,
      textContent: map['textContent'], photoPath: map['photoPath'],
      billPhotoPath: map['billPhotoPath'],
      unavailableItems: (map['unavailableItems'] as List?)?.cast<String>(),
      totalAmount: (map['totalAmount'] is num) ? (map['totalAmount'] as num).toDouble() : (double.tryParse(map['totalAmount']?.toString() ?? '0') ?? 0.0),
      placedAt: placedAt,
      deliveryAddress: map['deliveryAddress'] ?? map['deliveryAddressFormatted'] ?? 'No Address',
      deliveryPartner: partner,
      userRating: (map['userRating'] is num) ? (map['userRating'] as num).toDouble() : null,
      userReview: map['userReview'],
      statusTimestamps: timestamps,
      isPaymentDone: map['isPaymentDone'] ?? (map['paymentStatus'] == 'Completed' || map['customerPaid'] == true),
      isCustomStore: map['isCustomStore'] ?? false,
      customStoreName: map['customStoreName'],
      customStoreAddress: map['customStoreAddress'],
      isDismissedFromHome: map['isDismissedFromHome'] ?? false,
      distanceKm: (map['distanceKm'] is num) ? (map['distanceKm'] as num).toDouble() : (double.tryParse(map['distanceKm']?.toString() ?? '0.5') ?? 0.5),
      platformFee: (map['customerPlatformFee'] is num)
          ? (map['customerPlatformFee'] as num).toDouble()
          : (map['platformFee'] is num)
              ? (map['platformFee'] as num).toDouble()
              : (double.tryParse((map['customerPlatformFee'] ?? map['platformFee'])?.toString() ?? '5.0') ?? 5.0),
      deliveryFee: (map['deliveryCharge'] is num)
          ? (map['deliveryCharge'] as num).toDouble()
          : (map['deliveryFee'] is num)
              ? (map['deliveryFee'] as num).toDouble()
              : (double.tryParse((map['deliveryCharge'] ?? map['deliveryFee'])?.toString() ?? '30.0') ?? 30.0),
      subTotal: (map['subTotal'] is num)
          ? (map['subTotal'] as num).toDouble()
          : (double.tryParse(map['subTotal']?.toString() ?? '0') ?? 0.0),
      discount: (map['discount'] is num)
          ? (map['discount'] as num).toDouble()
          : (double.tryParse(map['discount']?.toString() ?? '0') ?? 0.0),
    );
  }
}

class Offer {
  final String id;
  final String vendorId;
  final String vendorName;
  final String vendorCategory;
  final String title;
  final String description;
  final String? imageUrl;
  final String discountType;
  final double discountValue;
  final String? code;
  final bool isActive;
  final DateTime? expiresAt;

  Offer({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.vendorCategory,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.discountType,
    required this.discountValue,
    this.code,
    this.isActive = true,
    this.expiresAt,
  });

  factory Offer.fromMap(Map<dynamic, dynamic> map) {
    String vId = '';
    String vName = 'Store';
    String vCat = 'General';

    if (map['vendor'] != null) {
      if (map['vendor'] is Map) {
        vId = map['vendor']['_id'] ?? '';
        vName = map['vendor']['storeName'] ?? 'Store';
        vCat = map['vendor']['category'] ?? 'General';
      } else {
        vId = map['vendor'].toString();
      }
    }

    return Offer(
      id: map['_id'] ?? map['id'] ?? '',
      vendorId: vId,
      vendorName: vName,
      vendorCategory: vCat,
      title: map['title'] ?? 'Special Offer',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      discountType: map['discountType'] ?? 'Percentage',
      discountValue: (map['discountValue'] ?? 0).toDouble(),
      code: map['code'],
      isActive: map['isActive'] ?? true,
      expiresAt: map['expiresAt'] != null ? DateTime.parse(map['expiresAt']) : null,
    );
  }
}
