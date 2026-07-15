import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/vendor_product_model.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VendorInventoryProvider with ChangeNotifier {
  final List<VendorProductModel> _products = [];
  final _uuid = const Uuid();
  final _apiService = VendorApiService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  List<String> _deletedCategories = [];
  List<String> get deletedCategories => _deletedCategories;
  
  // The linked vendor ID. Initialized as null to prevent fetching default inventory.
  String? _vendorId;

  List<VendorProductModel> get products => _products;

  VendorInventoryProvider() {
    _loadDeletedCategories();
    fetchProducts();
  }

  Future<void> _loadDeletedCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deletedCategories = prefs.getStringList('deleted_categories') ?? [];
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading deleted categories: $e');
    }
  }

  void linkVendor(String vendorId) {
    if (_vendorId == vendorId) return;
    debugPrint('🔗 Inventory Provider: Linking to Vendor ID $vendorId');
    _vendorId = vendorId;
    _products.clear(); // Clear old vendor data immediately
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    if (_vendorId == null) {
      debugPrint('⚠️ Inventory Provider: No vendor ID linked. Skipping fetch.');
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    final data = await _apiService.getProducts(_vendorId!);
    debugPrint('📦 Fetched ${data.length} products for vendor $_vendorId');
    _products.clear();
    _products.addAll(data.map((json) => VendorProductModel.fromJson(json)));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProduct(VendorProductModel product) async {
    if (_vendorId == null) {
      throw Exception('Vendor not linked. Cannot add product.');
    }
    debugPrint('➕ Adding product ${product.name} to vendor $_vendorId');
    final success = await _apiService.createProduct({
      ...product.toJson(),
      'vendor': _vendorId,
    });
    if (success) {
      _apiService.emitInventoryUpdate(_vendorId!); // Notify customers
      await fetchProducts();
    } else {
      throw Exception('Failed to save product to backend. Please check your server connection.');
    }
  }

  Future<void> updateProduct(VendorProductModel updatedProduct) async {
    final success = await _apiService.updateProduct(updatedProduct.id, updatedProduct.toJson());
    if (success) {
      if (_vendorId != null) _apiService.emitInventoryUpdate(_vendorId!); // Notify customers
      final index = _products.indexWhere((p) => p.id == updatedProduct.id);
      if (index != -1) {
        _products[index] = updatedProduct;
        notifyListeners();
      }
    } else {
      throw Exception('Failed to update product on backend. Check server logs.');
    }
  }

  Future<void> toggleAvailability(String productId) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final updated = _products[index].copyWith(isAvailable: !_products[index].isAvailable);
      final success = await _apiService.updateProduct(productId, {'isAvailable': updated.isAvailable});
      if (success) {
        if (_vendorId != null) _apiService.emitInventoryUpdate(_vendorId!); // Notify customers
        _products[index].isAvailable = updated.isAvailable;
        notifyListeners();
      }
    }
  }

  List<VendorProductModel> get lowStockProducts => 
      _products.where((p) => p.stock > 0 && p.stock <= 10).toList();

  List<VendorProductModel> get outOfStockProducts => 
      _products.where((p) => p.stock == 0).toList();

  int get lowStockCount => lowStockProducts.length + outOfStockProducts.length;

  Future<void> deleteProduct(String productId) async {
    final success = await _apiService.deleteProduct(productId);
    if (success) {
      if (_vendorId != null) _apiService.emitInventoryUpdate(_vendorId!); // Notify customers
      _products.removeWhere((p) => p.id == productId);
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String categoryName) async {
    final targetProducts = _products.where((p) => p.category.toLowerCase() == categoryName.toLowerCase()).toList();
    for (final product in targetProducts) {
      final updated = product.copyWith(category: 'Other');
      await updateProduct(updated);
    }
    
    if (!_deletedCategories.map((c) => c.toLowerCase()).contains(categoryName.toLowerCase())) {
      _deletedCategories.add(categoryName);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('deleted_categories', _deletedCategories);
      } catch (e) {
        debugPrint('Error saving deleted categories: $e');
      }
      notifyListeners();
    }
  }
}

