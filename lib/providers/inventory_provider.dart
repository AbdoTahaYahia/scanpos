import 'dart:async';

import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/product_service.dart';

class InventoryProvider extends ChangeNotifier {
  final ProductService _productService = ProductService();

  List<Product> _allProducts = []; // Holds the full catalog for global search
  List<Product> _products = []; // Currently displayed paginated slice
  List<Product> _filteredProducts = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';

  // Pagination State
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPageSize = 20;
  String? _currentStoreId;

  List<Product> get allProducts => _allProducts;
  List<Product> get products => _filteredProducts;
  List<String> get categories => _categories;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isFetchingMore => _isFetchingMore;
  bool get hasMore => _hasMore;

  /// Fetch all products from server and reset local pagination
  Future<void> fetchInitialPage(String storeId) async {
    _currentStoreId = storeId;
    _isLoading = true;
    _isFetchingMore = false;
    _currentPageSize = 20;
    _allProducts = [];
    _products = [];
    notifyListeners();

    try {
      _allProducts = await _productService.getAllProducts(storeId);
      // Sort alphabetically by default
      _allProducts.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      _updateLocalPagination();
    } catch (e) {
      debugPrint('Error fetching products: $e');
    } finally {
      _isLoading = false;
      _updateCategories();
      _applyFilters();
      notifyListeners();
    }
  }

  /// Locally paginates the data
  void _updateLocalPagination() {
    if (_allProducts.length <= _currentPageSize) {
      _products = List.from(_allProducts);
      _hasMore = false;
    } else {
      _products = _allProducts.take(_currentPageSize).toList();
      _hasMore = true;
    }
  }

  /// Reveal next page of products locally (triggered on scroll)
  Future<void> fetchNextPage() async {
    if (_isFetchingMore || !_hasMore) return;

    _isFetchingMore = true;
    notifyListeners();

    // Artificial delay to show loading spinner as requested by user
    await Future.delayed(const Duration(milliseconds: 400));

    _currentPageSize += 20;
    _updateLocalPagination();

    _isFetchingMore = false;
    _updateCategories();
    _applyFilters();
    notifyListeners();
  }

  /// Refresh products manually
  Future<void> refreshProducts() async {
    if (_currentStoreId != null) {
      await fetchInitialPage(_currentStoreId!);
    }
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
    _categories = _allProducts.map((p) => p.category).toSet().toList()..sort();
  }

  void _applyFilters() {
    // If filtering, we should probably filter against ALL products, not just the paginated slice
    // so the user can find any product when they search.
    List<Product> sourceList =
        (_searchQuery.isNotEmpty || _selectedCategory != null)
        ? _allProducts
        : _products;

    _filteredProducts = sourceList.where((product) {
      // Category filter
      if (_selectedCategory != null && product.category != _selectedCategory) {
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
}
