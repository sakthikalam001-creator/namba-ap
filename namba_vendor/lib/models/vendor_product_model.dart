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
      'stock': stock,
      'category': category,
      'isAvailable': isAvailable,
      'image': imageUrl,
    };
  }
}

