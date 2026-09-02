import 'package:flutter/material.dart';

class AppCategories {
  static const List<String> defaultCategories = [
    'Fruits',
    'Vegetables',
    'Dairy',
    'Bakery',
    'Meat',
    'Beverages',
    'Snacks',
    'Household',
    'Other'
  ];
}

class VendorProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final double mrp;
  final int discount;
  final String offerBadge;
  final String unit;
  final String foodType; // 'veg', 'non_veg', 'egg'
  final String prepTime;
  final int stock;
  final String category;
  bool isAvailable;
  final String? imageUrl;
  final IconData? icon; // For mock/placeholder icons

  VendorProductModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.mrp = 0,
    this.discount = 0,
    this.offerBadge = '',
    this.unit = '1 pc',
    this.foodType = 'veg',
    this.prepTime = '15 mins',
    required this.stock,
    required this.category,
    this.isAvailable = true,
    this.imageUrl,
    this.icon,
  });

  VendorProductModel copyWith({
    String? name,
    String? description,
    double? price,
    double? mrp,
    int? discount,
    String? offerBadge,
    String? unit,
    String? foodType,
    String? prepTime,
    int? stock,
    String? category,
    bool? isAvailable,
    String? imageUrl,
    IconData? icon,
  }) {
    return VendorProductModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      mrp: mrp ?? this.mrp,
      discount: discount ?? this.discount,
      offerBadge: offerBadge ?? this.offerBadge,
      unit: unit ?? this.unit,
      foodType: foodType ?? this.foodType,
      prepTime: prepTime ?? this.prepTime,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon ?? this.icon,
    );
  }

  factory VendorProductModel.fromJson(Map<String, dynamic> json) {
    return VendorProductModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      mrp: (json['mrp'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0) is int ? (json['discount'] ?? 0) : ((json['discount'] ?? 0) as num).toInt(),
      offerBadge: json['offerBadge'] ?? '',
      unit: json['unit'] ?? '1 pc',
      foodType: json['foodType'] ?? 'veg',
      prepTime: json['prepTime'] ?? '15 mins',
      stock: json['stock'] ?? 0,
      category: json['category'] ?? 'Other',
      isAvailable: json['isAvailable'] ?? true,
      imageUrl: json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'mrp': mrp,
      'discount': discount,
      'offerBadge': offerBadge,
      'unit': unit,
      'foodType': foodType,
      'prepTime': prepTime,
      'stock': stock,
      'category': category,
      'isAvailable': isAvailable,
      'image': imageUrl,
    };
  }
}

