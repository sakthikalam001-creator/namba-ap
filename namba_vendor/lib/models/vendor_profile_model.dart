class VendorProfileModel {
  final String id;
  final String storeName;
  final String ownerName;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String pincode;
  final String category;
  final String approvalStatus;
  final bool isOpen;
  final String subscriptionPlan;
  final DateTime? subscriptionExpiry;
  final bool isSubscribed;
  final DateTime? trialExpiry;
  final bool isLocked;
  final String? lockReason;
  final bool showSubscriptionBadge;

  final bool allowAutoAccept;
  final bool allowSurgeBoost;
  final bool allowExtraWait;
  final bool allowBasicInfoEdit;
  final bool allowStorePhotoEdit;
  final bool allowLocationEdit;
  final bool allowPaymentEdit;
  final bool allowGalleryUpload;
  final bool paymentDetailsLocked;

  final List<dynamic>? operatingHours;
  final bool autoSchedulingEnabled;

  final String qrCodeUrl;
  final String gpayNumber;
  final String upiId;
  final String storePhoto;
  final bool canRunAds;
  final double latitude;
  final double longitude;

  VendorProfileModel({
    required this.id,
    required this.storeName,
    required this.ownerName,
    required this.phone,
    required this.email,
    required this.address,
    required this.city,
    required this.pincode,
    required this.category,
    required this.approvalStatus,
    required this.isOpen,
    required this.subscriptionPlan,
    this.subscriptionExpiry,
    required this.isSubscribed,
    this.trialExpiry,
    this.isLocked = false,
    this.lockReason,
    this.showSubscriptionBadge = true,
    this.allowAutoAccept = false,
    this.allowSurgeBoost = false,
    this.allowExtraWait = false,
    this.allowBasicInfoEdit = false,
    this.allowStorePhotoEdit = false,
    this.allowLocationEdit = false,
    this.allowPaymentEdit = true,
    this.allowGalleryUpload = false,
    this.paymentDetailsLocked = false,
    this.operatingHours,
    this.autoSchedulingEnabled = false,
    this.qrCodeUrl = '',
    this.gpayNumber = '',
    this.upiId = '',
    this.storePhoto = '',
    this.canRunAds = false,
    this.latitude = 11.3410,
    this.longitude = 77.7172,
  });

  factory VendorProfileModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'] ?? json;
    final Map<String, dynamic> data = rawData is Map<String, dynamic> ? rawData : (rawData is Map ? Map<String, dynamic>.from(rawData) : {});
    final Map<String, dynamic> perms = data['permissions'] is Map ? Map<String, dynamic>.from(data['permissions']) : {};
    final coords = data['location'] is Map ? data['location']['coordinates'] : null;
    double lat = 11.3410;
    double lng = 77.7172;
    if (coords is List && coords.length >= 2) {
      lng = double.tryParse(coords[0]?.toString() ?? '') ?? 77.7172;
      lat = double.tryParse(coords[1]?.toString() ?? '') ?? 11.3410;
    } else if (data['lat'] != null && data['lng'] != null) {
      lat = double.tryParse(data['lat']?.toString() ?? '') ?? 11.3410;
      lng = double.tryParse(data['lng']?.toString() ?? '') ?? 77.7172;
    }
    return VendorProfileModel(
      id: (data['_id'] ?? data['id'])?.toString() ?? '',
      storeName: data['storeName']?.toString() ?? 'Unnamed Store',
      ownerName: data['ownerName']?.toString() ?? 'Owner',
      phone: data['phone']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      city: (data['location'] is Map ? data['location']['city']?.toString() : null) ?? data['city']?.toString() ?? '',
      pincode: (data['location'] is Map ? data['location']['pincode']?.toString() : null) ?? data['pincode']?.toString() ?? '',
      category: data['category']?.toString() ?? 'General',
      approvalStatus: data['approvalStatus']?.toString() ?? 'pending',
      isOpen: data['isOpen'] == true,
      subscriptionPlan: data['subscriptionPlan']?.toString() ?? 'None',
      qrCodeUrl: data['qrCodeUrl']?.toString() ?? '',
      gpayNumber: data['gpayNumber']?.toString() ?? data['vendorUpiNumber']?.toString() ?? '',
      upiId: data['upiId']?.toString() ?? data['vendorUpiId']?.toString() ?? '',
      storePhoto: data['storePhoto']?.toString() ?? data['storePhotoUrl']?.toString() ?? data['image']?.toString() ?? ((data['storeImages'] is List && (data['storeImages'] as List).isNotEmpty) ? data['storeImages'][0]?.toString() ?? '' : ''),
      canRunAds: data['canRunAds'] == true || perms['canRunAds'] == true,
      allowBasicInfoEdit: data['allowBasicInfoEdit'] == true || perms['allowBasicInfoEdit'] == true,
      allowStorePhotoEdit: data['allowStorePhotoEdit'] == true || perms['allowStorePhotoEdit'] == true,
      subscriptionExpiry: data['subscriptionExpiry'] != null ? DateTime.tryParse(data['subscriptionExpiry'].toString()) : null,
      isSubscribed: data['isSubscribed'] == true,
      trialExpiry: data['trialExpiry'] != null ? DateTime.tryParse(data['trialExpiry'].toString()) : null,
      isLocked: data['isLocked'] == true,
      lockReason: data['lockReason']?.toString(),
      showSubscriptionBadge: data['showSubscriptionBadge'] != false,
      allowAutoAccept: perms['allowAutoAccept'] == true,
      allowSurgeBoost: perms['allowSurgeBoost'] == true,
      allowExtraWait: perms['allowExtraWait'] == true,
      allowLocationEdit: data['allowLocationEdit'] == true || perms['allowLocationEdit'] == true,
      allowPaymentEdit: data['allowPaymentEdit'] == true || perms['allowPaymentEdit'] == true || (data['paymentDetailsLocked'] != true),
      allowGalleryUpload: data['allowGalleryUpload'] == true || perms['allowGalleryUpload'] == true,
      paymentDetailsLocked: data['paymentDetailsLocked'] == true,
      operatingHours: data['operatingHours'] is List ? data['operatingHours'] : null,
      autoSchedulingEnabled: data['autoSchedulingEnabled'] == true,
      latitude: lat,
      longitude: lng,
    );
  }

  VendorProfileModel copyWith({
    String? id,
    String? storeName,
    String? ownerName,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? pincode,
    String? category,
    String? approvalStatus,
    bool? isOpen,
    String? subscriptionPlan,
    DateTime? subscriptionExpiry,
    bool? isSubscribed,
    DateTime? trialExpiry,
    bool? isLocked,
    String? lockReason,
    bool? showSubscriptionBadge,
    bool? allowAutoAccept,
    bool? allowSurgeBoost,
    bool? allowExtraWait,
    bool? allowBasicInfoEdit,
    bool? allowStorePhotoEdit,
    bool? allowLocationEdit,
    bool? allowPaymentEdit,
    bool? allowGalleryUpload,
    bool? paymentDetailsLocked,
    List<dynamic>? operatingHours,
    bool? autoSchedulingEnabled,
    String? qrCodeUrl,
    String? gpayNumber,
    String? upiId,
    String? storePhoto,
    bool? canRunAds,
    double? latitude,
    double? longitude,
  }) {
    return VendorProfileModel(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      category: category ?? this.category,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      isOpen: isOpen ?? this.isOpen,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      trialExpiry: trialExpiry ?? this.trialExpiry,
      isLocked: isLocked ?? this.isLocked,
      lockReason: lockReason ?? this.lockReason,
      showSubscriptionBadge: showSubscriptionBadge ?? this.showSubscriptionBadge,
      allowAutoAccept: allowAutoAccept ?? this.allowAutoAccept,
      allowSurgeBoost: allowSurgeBoost ?? this.allowSurgeBoost,
      allowExtraWait: allowExtraWait ?? this.allowExtraWait,
      allowBasicInfoEdit: allowBasicInfoEdit ?? this.allowBasicInfoEdit,
      allowStorePhotoEdit: allowStorePhotoEdit ?? this.allowStorePhotoEdit,
      allowLocationEdit: allowLocationEdit ?? this.allowLocationEdit,
      allowPaymentEdit: allowPaymentEdit ?? this.allowPaymentEdit,
      allowGalleryUpload: allowGalleryUpload ?? this.allowGalleryUpload,
      paymentDetailsLocked: paymentDetailsLocked ?? this.paymentDetailsLocked,
      operatingHours: operatingHours ?? this.operatingHours,
      autoSchedulingEnabled: autoSchedulingEnabled ?? this.autoSchedulingEnabled,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      gpayNumber: gpayNumber ?? this.gpayNumber,
      upiId: upiId ?? this.upiId,
      storePhoto: storePhoto ?? this.storePhoto,
      canRunAds: canRunAds ?? this.canRunAds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeName': storeName,
      'ownerName': ownerName,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'pincode': pincode,
      'category': category,
      'approvalStatus': approvalStatus,
      'storePhoto': storePhoto,
      'isOpen': isOpen,
      'subscriptionPlan': subscriptionPlan,
      'subscriptionExpiry': subscriptionExpiry?.toIso8601String(),
      'isSubscribed': isSubscribed,
      'trialExpiry': trialExpiry?.toIso8601String(),
      'isLocked': isLocked,
      'lockReason': lockReason,
      'showSubscriptionBadge': showSubscriptionBadge,
      'allowAutoAccept': allowAutoAccept,
      'allowSurgeBoost': allowSurgeBoost,
      'allowExtraWait': allowExtraWait,
      'allowBasicInfoEdit': allowBasicInfoEdit,
      'allowStorePhotoEdit': allowStorePhotoEdit,
      'allowLocationEdit': allowLocationEdit,
      'allowPaymentEdit': allowPaymentEdit,
      'allowGalleryUpload': allowGalleryUpload,
      'paymentDetailsLocked': paymentDetailsLocked,
      'operatingHours': operatingHours,
      'autoSchedulingEnabled': autoSchedulingEnabled,
      'qrCodeUrl': qrCodeUrl,
      'gpayNumber': gpayNumber,
      'upiId': upiId,
      'canRunAds': canRunAds,
      'lat': latitude,
      'lng': longitude,
      'permissions': {
        'allowAutoAccept': allowAutoAccept,
        'allowSurgeBoost': allowSurgeBoost,
        'allowExtraWait': allowExtraWait,
        'allowBasicInfoEdit': allowBasicInfoEdit,
        'allowStorePhotoEdit': allowStorePhotoEdit,
        'allowLocationEdit': allowLocationEdit,
        'allowPaymentEdit': allowPaymentEdit,
        'allowGalleryUpload': allowGalleryUpload,
        'canRunAds': canRunAds,
      }
    };
  }
}
