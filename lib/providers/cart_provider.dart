import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/app_user.dart';
import '../services/transaction_service.dart';

class CartProvider extends ChangeNotifier {
  final TransactionService _transactionService = TransactionService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<CartItem> _items = [];
  bool _isProcessing = false;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isProcessing => _isProcessing;
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.fold<double>(0, (sum, item) => sum + item.subtotal);

  /// Add a product to cart. If it already exists, increment quantity.
  void addItem(Product product) {
    final existingIndex =
        _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    
    // Use the most standard system vibration
    HapticFeedback.vibrate();
    
    // Play custom internal sound for Cashier
    _audioPlayer.play(AssetSource('sounds/beep.ogg'));
    
    notifyListeners();
  }

  /// Remove an item from cart entirely
  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  /// Increment quantity for a specific product
  void incrementQuantity(String productId) {
    final index =
        _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  /// Decrement quantity for a specific product (removes if qty = 0)
  void decrementQuantity(String productId) {
    final index =
        _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  /// Clear all items from cart
  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  /// Process checkout: create transaction + decrement stock
  Future<bool> checkout(AppUser user) async {
    if (_items.isEmpty || _isProcessing) return false;

    try {
      _isProcessing = true;
      notifyListeners();

      await _transactionService.createTransaction(
        storeId: user.storeId!,
        cashierId: user.uid,
        cashierName: user.displayName,
        cartItems: _items,
      );

      _items.clear();
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }
}
