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
  final bool allowLocationEdit;
  final bool allowPaymentEdit;
  final bool allowGalleryUpload;
  final bool paymentDetailsLocked;

  final List<dynamic>? operatingHours;
  final bool autoSchedulingEnabled;

  final String qrCodeUrl;
  final String gpayNumber;
  final String upiId;
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
    this.allowLocationEdit = false,
    this.allowPaymentEdit = true,
    this.allowGalleryUpload = false,
    this.paymentDetailsLocked = false,
    this.operatingHours,
    this.autoSchedulingEnabled = false,
    this.qrCodeUrl = '',
    this.gpayNumber = '',
    this.upiId = '',
    this.canRunAds = false,
    this.latitude = 11.3410,
    this.longitude = 77.7172,
  });

  factory VendorProfileModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final perms = data['permissions'] ?? {};
    final coords = data['location']?['coordinates'];
    double lat = 11.3410;
    double lng = 77.7172;
    if (coords is List && coords.length >= 2) {
      lng = double.tryParse(coords[0].toString()) ?? 77.7172;
      lat = double.tryParse(coords[1].toString()) ?? 11.3410;
    } else if (data['lat'] != null && data['lng'] != null) {
      lat = double.tryParse(data['lat'].toString()) ?? 11.3410;
      lng = double.tryParse(data['lng'].toString()) ?? 77.7172;
    }
    return VendorProfileModel(
      id: (data['_id'] ?? data['id'])?.toString() ?? '',
      storeName: data['storeName'] ?? 'Unnamed Store',
      ownerName: data['ownerName'] ?? 'Owner',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      city: data['location']?['city'] ?? data['city'] ?? '',
      pincode: data['location']?['pincode'] ?? data['pincode'] ?? '',
      category: data['category'] ?? 'General',
      approvalStatus: data['approvalStatus'] ?? 'pending',
      isOpen: data['isOpen'] ?? true,
      subscriptionPlan: data['subscriptionPlan'] ?? 'None',
      qrCodeUrl: data['qrCodeUrl'] ?? '',
      gpayNumber: data['gpayNumber'] ?? data['vendorUpiNumber'] ?? '',
      upiId: data['upiId'] ?? data['vendorUpiId'] ?? '',
      canRunAds: data['canRunAds'] == true || perms['canRunAds'] == true,
      subscriptionExpiry: data['subscriptionExpiry'] != null ? DateTime.parse(data['subscriptionExpiry']) : null,
      isSubscribed: data['isSubscribed'] ?? false,
      trialExpiry: data['trialExpiry'] != null ? DateTime.parse(data['trialExpiry']) : null,
      isLocked: data['isLocked'] ?? false,
      lockReason: data['lockReason'],
      showSubscriptionBadge: data['showSubscriptionBadge'] ?? true,
      allowAutoAccept: perms['allowAutoAccept'] ?? false,
      allowSurgeBoost: perms['allowSurgeBoost'] ?? false,
      allowExtraWait: perms['allowExtraWait'] ?? false,
      allowLocationEdit: data['allowLocationEdit'] == true || perms['allowLocationEdit'] == true,
      allowPaymentEdit: data['allowPaymentEdit'] ?? (perms['allowPaymentEdit'] ?? (data['paymentDetailsLocked'] == true ? false : true)),
      allowGalleryUpload: data['allowGalleryUpload'] == true || perms['allowGalleryUpload'] == true,
      paymentDetailsLocked: data['paymentDetailsLocked'] == true,
      operatingHours: data['operatingHours'],
      autoSchedulingEnabled: data['autoSchedulingEnabled'] ?? false,
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
    bool? allowLocationEdit,
    bool? allowPaymentEdit,
    bool? allowGalleryUpload,
    bool? paymentDetailsLocked,
    List<dynamic>? operatingHours,
    bool? autoSchedulingEnabled,
    String? qrCodeUrl,
    String? gpayNumber,
    String? upiId,
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
      allowLocationEdit: allowLocationEdit ?? this.allowLocationEdit,
      allowPaymentEdit: allowPaymentEdit ?? this.allowPaymentEdit,
      allowGalleryUpload: allowGalleryUpload ?? this.allowGalleryUpload,
      paymentDetailsLocked: paymentDetailsLocked ?? this.paymentDetailsLocked,
      operatingHours: operatingHours ?? this.operatingHours,
      autoSchedulingEnabled: autoSchedulingEnabled ?? this.autoSchedulingEnabled,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      gpayNumber: gpayNumber ?? this.gpayNumber,
      upiId: upiId ?? this.upiId,
      canRunAds: canRunAds ?? this.canRunAds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'storeName': storeName,
      'ownerName': ownerName,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'pincode': pincode,
      'category': category,
      'approvalStatus': approvalStatus,
      'isOpen': isOpen,
      'subscriptionPlan': subscriptionPlan,
      'subscriptionExpiry': subscriptionExpiry?.toIso8601String(),
      'isSubscribed': isSubscribed,
      'trialExpiry': trialExpiry?.toIso8601String(),
      'isLocked': isLocked,
      'lockReason': lockReason,
      'showSubscriptionBadge': showSubscriptionBadge,
      'operatingHours': operatingHours,
      'autoSchedulingEnabled': autoSchedulingEnabled,
      'allowLocationEdit': allowLocationEdit,
      'allowPaymentEdit': allowPaymentEdit,
      'paymentDetailsLocked': paymentDetailsLocked,
      'qrCodeUrl': qrCodeUrl,
      'gpayNumber': gpayNumber,
      'upiId': upiId,
      'canRunAds': canRunAds,
      'permissions': {
        'allowAutoAccept': allowAutoAccept,
        'allowSurgeBoost': allowSurgeBoost,
        'allowExtraWait': allowExtraWait,
        'allowLocationEdit': allowLocationEdit,
        'allowPaymentEdit': allowPaymentEdit,
        'canRunAds': canRunAds,
      }
    };
  }
}
