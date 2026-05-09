import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/product_service.dart';

class InventoryProvider extends ChangeNotifier {
  final ProductService _productService = ProductService();

  List<Product> _products = [];
  List<Product> _allProductsForSearch = [];
  List<Product> _filteredProducts = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  
  // Pagination State
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  String? _currentStoreId;

  List<Product> get products => _filteredProducts;
  List<Product> get allProductsForSearch => _allProductsForSearch;
  List<String> get categories => _categories;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isFetchingMore => _isFetchingMore;
  bool get hasMore => _hasMore;

  /// Fetch initial page of products
  Future<void> fetchInitialPage(String storeId) async {
    _currentStoreId = storeId;
    _isLoading = true;
    _isFetchingMore = false;
    _hasMore = true;
    _lastDoc = null;
    _products = [];
    notifyListeners();

    try {
      final result = await _productService.getProductsPaginated(
        storeId: storeId,
        limit: 10,
      );
      _products = result.products;
      _lastDoc = result.lastDoc;
      _hasMore = result.hasMore;
    } catch (e) {
      debugPrint('Error fetching products: $e');
    } finally {
      _isLoading = false;
      _updateCategories();
      _applyFilters();
      _loadAllProductsForSearch();
      notifyListeners();
    }
  }

  Future<void> _loadAllProductsForSearch() async {
    if (_currentStoreId == null) return;
    try {
      _allProductsForSearch = await _productService.getAllProducts(storeId: _currentStoreId!);
    } catch (e) {
      debugPrint('Error loading all products for search: $e');
    }
  }

  /// Fetch next page of products (triggered on scroll)
  Future<void> fetchNextPage() async {
    if (_isFetchingMore || !_hasMore || _currentStoreId == null) return;

    _isFetchingMore = true;
    notifyListeners();

    try {
      final result = await _productService.getProductsPaginated(
        storeId: _currentStoreId!,
        lastDoc: _lastDoc,
        limit: 10,
      );
      
      if (result.products.isNotEmpty) {
        _products.addAll(result.products);
        _lastDoc = result.lastDoc;
      }
      _hasMore = result.hasMore;
    } catch (e) {
      debugPrint('Error fetching more products: $e');
    } finally {
      _isFetchingMore = false;
      _updateCategories();
      _applyFilters();
      notifyListeners();
    }
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

}
