import '../models/models.dart';

class MockData {
  static final List<Store> stores = [
    Store(
      id: 's1',
      name: 'Fresh Mart',
      category: StoreCategory.grocery,
      description: 'Fresh vegetables, fruits and daily groceries. Best quality products at affordable prices.',
      ownerPhone: '+919876543210',
      rating: 4.5,
      deliveryTime: 30,
      distanceKm: 2.3,
      photoUrls: [
        'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400',
        'https://images.unsplash.com/photo-1506617564039-2f3b650b7010?w=400',
      ],
      products: [
        Product(id: 'p1', name: 'Tomato', price: 30, unit: 'kg', storeId: 's1',
          imageUrl: 'https://images.unsplash.com/photo-1546094096-0df4bcaaa337?w=200'),
        Product(id: 'p2', name: 'Onion', price: 25, unit: 'kg', storeId: 's1',
          imageUrl: 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=200'),
        Product(id: 'p3', name: 'Rice (1kg)', price: 60, unit: 'pack', storeId: 's1',
          imageUrl: 'https://images.unsplash.com/photo-1536304993881-ff86e0c9c8d1?w=200'),
        Product(id: 'p4', name: 'Milk (500ml)', price: 28, unit: 'pack', storeId: 's1',
          imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=200'),
        Product(id: 'p5', name: 'Eggs (6 pcs)', price: 45, unit: 'tray', storeId: 's1',
          imageUrl: 'https://images.unsplash.com/photo-1518569656558-1f25e69d2221?w=200'),
        Product(id: 'p6', name: 'Bread', price: 35, unit: 'loaf', storeId: 's1',
          imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=200'),
      ],
      isOpen: true,
      hasItemList: true,
    ),
    Store(
      id: 's2',
      name: 'Sweet Bakes',
      category: StoreCategory.bakery,
      description: 'Handcrafted cakes, pastries and freshly baked breads. Made fresh every morning.',
      ownerPhone: '+919876543211',
      rating: 4.8,
      deliveryTime: 20,
      distanceKm: 1.1,
      photoUrls: [
        'https://images.unsplash.com/photo-1461009683693-342af2f2d6ce?w=400',
        'https://images.unsplash.com/photo-1486427944299-d1955d23e34d?w=400',
      ],
      products: [
        Product(id: 'p7', name: 'Chocolate Cake', price: 350, unit: 'piece', storeId: 's2',
          imageUrl: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=200'),
        Product(id: 'p8', name: 'Croissant', price: 40, unit: 'piece', storeId: 's2',
          imageUrl: 'https://images.unsplash.com/photo-1614088685112-0a760b71a3c8?w=200'),
        Product(id: 'p9', name: 'Muffin', price: 35, unit: 'piece', storeId: 's2',
          imageUrl: 'https://images.unsplash.com/photo-1486427944299-d1955d23e34d?w=200'),
        Product(id: 'p10', name: 'Cookies (6 pcs)', price: 80, unit: 'box', storeId: 's2',
          imageUrl: 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=200'),
      ],
      isOpen: true,
    ),
    Store(
      id: 's3',
      name: 'Medico Pharmacy',
      category: StoreCategory.medicine,
      description: '24/7 pharmacy with all branded and generic medicines. Doctor consultation available.',
      ownerPhone: '+919876543212',
      rating: 4.6,
      deliveryTime: 25,
      distanceKm: 0.8,
      photoUrls: [
        'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=400',
        'https://images.unsplash.com/photo-1587351021759-3e566b6af7cc?w=400',
      ],
      products: [
        Product(id: 'p11', name: 'Paracetamol 500mg', price: 15, unit: 'strip', storeId: 's3'),
        Product(id: 'p12', name: 'Vitamin C 1000mg', price: 120, unit: 'bottle', storeId: 's3'),
        Product(id: 'p13', name: 'Bandage Roll', price: 45, unit: 'piece', storeId: 's3'),
        Product(id: 'p14', name: 'Hand Sanitizer', price: 60, unit: 'bottle', storeId: 's3'),
      ],
      isOpen: true,
    ),
    Store(
      id: 's4',
      name: 'Spice Garden Hotel',
      category: StoreCategory.food,
      description: 'Authentic Tamil Nadu cuisine — biriyani, parotta, meals and more. Served hot!',
      ownerPhone: '+919876543213',
      rating: 4.3,
      deliveryTime: 40,
      distanceKm: 3.5,
      photoUrls: [
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400',
        'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400',
      ],
      products: [
        Product(id: 'p15', name: 'Chicken Biriyani', price: 180, unit: 'plate', storeId: 's4',
          imageUrl: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=200'),
        Product(id: 'p16', name: 'Veg Meals', price: 100, unit: 'plate', storeId: 's4',
          imageUrl: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=200'),
        Product(id: 'p17', name: 'Parotta (2 pcs)', price: 40, unit: 'plate', storeId: 's4',
          imageUrl: 'https://images.unsplash.com/photo-1604908177453-7462950a6a3b?w=200'),
        Product(id: 'p18', name: 'Chicken Curry', price: 150, unit: 'bowl', storeId: 's4',
          imageUrl: 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=200'),
        Product(id: 'p19', name: 'Filter Coffee', price: 30, unit: 'cup', storeId: 's4',
          imageUrl: 'https://images.unsplash.com/photo-1559496417-e7f25cb247f3?w=200'),
      ],
      isOpen: true,
      hasItemList: true,
    ),
    Store(
      id: 's5',
      name: 'Daily Needs Store',
      category: StoreCategory.grocery,
      description: 'Everything you need for daily household use. Open from 6AM to 10PM.',
      ownerPhone: '+919876543214',
      rating: 4.2,
      deliveryTime: 35,
      distanceKm: 5.0,
      photoUrls: [
        'https://images.unsplash.com/photo-1528323273322-d81458248d40?w=400',
      ],
      products: [
        Product(id: 'p20', name: 'Sugar (1kg)', price: 45, unit: 'pack', storeId: 's5'),
        Product(id: 'p21', name: 'Cooking Oil (1L)', price: 150, unit: 'bottle', storeId: 's5'),
        Product(id: 'p22', name: 'Atta (5kg)', price: 200, unit: 'bag', storeId: 's5'),
        Product(id: 'p23', name: 'Dal (500g)', price: 65, unit: 'pack', storeId: 's5'),
      ],
      isOpen: false,
    ),
  ];

  static List<Store> getByCategory(String category) =>
      stores.where((s) => s.category == category).toList();

  static List<Store> getNearby({double radiusKm = 20}) =>
      stores.where((s) => s.distanceKm <= radiusKm).toList();
}
