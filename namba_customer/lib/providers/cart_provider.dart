import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _storeId;
  String? _storeName;

  CartProvider() {
    _loadFromPrefs();
  }

  List<CartItem> get items => _items;
  String? get storeId => _storeId;
  String? get storeName => _storeName;
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => _items.fold(0, (sum, i) => sum + i.total);
  double get deliveryFee => subtotal > 0 ? 30 : 0;
  double get platformFee => subtotal > 0 ? 5 : 0;
  double get total => subtotal + deliveryFee + platformFee;

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('namba_cart_items');
      final savedStoreId = prefs.getString('namba_cart_store_id');
      final savedStoreName = prefs.getString('namba_cart_store_name');

      if (cartJson != null) {
        final List decoded = jsonDecode(cartJson);
        _items.clear();
        _items.addAll(decoded.map((x) => CartItem.fromMap(x)).toList());
        _storeId = savedStoreId;
        _storeName = savedStoreName;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart from SharedPreferences: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_items.isEmpty) {
        await prefs.remove('namba_cart_items');
        await prefs.remove('namba_cart_store_id');
        await prefs.remove('namba_cart_store_name');
      } else {
        final cartJson = jsonEncode(_items.map((i) => i.toMap()).toList());
        await prefs.setString('namba_cart_items', cartJson);
        if (_storeId != null) await prefs.setString('namba_cart_store_id', _storeId!);
        if (_storeName != null) await prefs.setString('namba_cart_store_name', _storeName!);
      }
    } catch (e) {
      debugPrint('Error saving cart to SharedPreferences: $e');
    }
  }

  void addItem(Product product, {String? storeName}) {
    if (_storeId != null && _storeId != product.storeId) {
      // Different store — clear cart first
      _items.clear();
    }
    _storeId = product.storeId;
    _storeName = storeName;

    final idx = _items.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      _items[idx].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    _saveToPrefs();
    notifyListeners();
  }

  void removeItem(Product product) {
    final idx = _items.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      if (_items[idx].quantity > 1) {
        _items[idx].quantity--;
      } else {
        _items.removeAt(idx);
      }
      if (_items.isEmpty) {
        _storeId = null;
        _storeName = null;
      }
      _saveToPrefs();
      notifyListeners();
    }
  }

  int getQuantity(String productId) {
    final idx = _items.indexWhere((i) => i.product.id == productId);
    return idx >= 0 ? _items[idx].quantity : 0;
  }

  void clear() {
    _items.clear();
    _storeId = null;
    _storeName = null;
    _saveToPrefs();
    notifyListeners();
  }
}
