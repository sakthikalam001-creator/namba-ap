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

  // Feature Permissions
  final bool allowAutoAccept;
  final bool allowSurgeBoost;
  final bool allowExtraWait;

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
  });

  factory VendorProfileModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final perms = data['permissions'] ?? {};
    return VendorProfileModel(
      id: data['_id'] ?? '',
      storeName: data['storeName'] ?? 'Unnamed Store',
      ownerName: data['ownerName'] ?? 'Owner',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      pincode: data['pincode'] ?? '',
      category: data['category'] ?? 'General',
      approvalStatus: data['approvalStatus'] ?? 'pending',
      isOpen: data['isOpen'] ?? true,
      subscriptionPlan: data['subscriptionPlan'] ?? 'None',
      subscriptionExpiry: data['subscriptionExpiry'] != null ? DateTime.parse(data['subscriptionExpiry']) : null,
      isSubscribed: data['isSubscribed'] ?? false,
      trialExpiry: data['trialExpiry'] != null ? DateTime.parse(data['trialExpiry']) : null,
      isLocked: data['isLocked'] ?? false,
      lockReason: data['lockReason'],
      showSubscriptionBadge: data['showSubscriptionBadge'] ?? true,
      allowAutoAccept: perms['allowAutoAccept'] ?? false,
      allowSurgeBoost: perms['allowSurgeBoost'] ?? false,
      allowExtraWait: perms['allowExtraWait'] ?? false,
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
      'permissions': {
        'allowAutoAccept': allowAutoAccept,
        'allowSurgeBoost': allowSurgeBoost,
        'allowExtraWait': allowExtraWait,
      }
    };
  }
}
