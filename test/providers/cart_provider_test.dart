import 'package:flutter_test/flutter_test.dart';
import 'package:scanpos/models/product.dart';
import 'package:scanpos/providers/cart_provider.dart';

void main() {
  group('CartProvider Tests', () {
    late CartProvider cartProvider;

    setUp(() {
      cartProvider = CartProvider(enableFeedback: false);
    });

    test('Initial cart should be empty', () {
      expect(cartProvider.isEmpty, true);
      expect(cartProvider.itemCount, 0);
      expect(cartProvider.totalAmount, 0.0);
    });

    test('Adding a product increases item count and total', () {
      final product = Product(
        id: '1',
        storeId: 'store1',
        name: 'Milk',
        price: 20.0,
        quantityInStock: 5,
        barcode: '123456',
        category: 'Dairy',
      );

      final added = cartProvider.addItem(product);
      expect(added, true);
      expect(cartProvider.isEmpty, false);
      expect(cartProvider.itemCount, 1);
      expect(cartProvider.totalAmount, 20.0);
    });

    test('Cannot add a product with 0 stock', () {
      final product = Product(
        id: '2',
        storeId: 'store1',
        name: 'Empty Product',
        price: 10.0,
        quantityInStock: 0,
        barcode: '654321',
        category: 'Test',
      );

      final added = cartProvider.addItem(product);
      expect(added, false);
      expect(cartProvider.isEmpty, true);
    });

    test('Cannot increment beyond stock limit', () {
      final product = Product(
        id: '3',
        storeId: 'store1',
        name: 'Limited Product',
        price: 15.0,
        quantityInStock: 2,
        barcode: '111222',
        category: 'Test',
      );

      // Add first item
      bool added = cartProvider.addItem(product);
      expect(added, true);
      expect(cartProvider.itemCount, 1);

      // Add second item
      added = cartProvider.addItem(product);
      expect(added, true);
      expect(cartProvider.itemCount, 2);

      // Attempt to add third item (exceeds stock)
      added = cartProvider.addItem(product);
      expect(added, false);
      expect(cartProvider.itemCount, 2); // should not increment
    });
  });
}
