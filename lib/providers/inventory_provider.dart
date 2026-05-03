import 'dart:async';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/product_service.dart';

class InventoryProvider extends ChangeNotifier {
  final ProductService _productService = ProductService();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = true;
  StreamSubscription? _subscription;

  List<Product> get products => _filteredProducts;
  List<String> get categories => _categories;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  /// Start listening to products for a store
  void listenToProducts(String storeId) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _productService.getProducts(storeId).listen((products) {
      _products = products;
      _updateCategories();
      _applyFilters();
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// Set category filter
  void setCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _applyFilters();
    notifyListeners();
  }

  void _updateCategories() {
    _categories = _products
        .map((p) => p.category)
        .toSet()
        .toList()
      ..sort();
  }

  void _applyFilters() {
    _filteredProducts = _products.where((product) {
      // Category filter
      if (_selectedCategory != null &&
          product.category != _selectedCategory) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return product.name.toLowerCase().contains(query) ||
            product.barcode.toLowerCase().contains(query);
      }

      return true;
    }).toList();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
