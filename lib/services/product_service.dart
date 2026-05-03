import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// Collection reference for products in a store
  CollectionReference<Map<String, dynamic>> _productsRef(String storeId) {
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('products');
  }

  /// Stream all products for a store
  Stream<List<Product>> getProducts(String storeId) {
    return _productsRef(storeId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .toList();
    });
  }

  /// Get a single product by barcode
  Future<Product?> getProductByBarcode(String storeId, String barcode) async {
    final query = await _productsRef(storeId)
        .where('barcode', isEqualTo: barcode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return Product.fromMap(query.docs.first.data());
  }

  /// Get a single product by ID
  Future<Product?> getProductById(String storeId, String productId) async {
    final doc = await _productsRef(storeId).doc(productId).get();
    if (!doc.exists) return null;
    return Product.fromMap(doc.data()!);
  }

  /// Add a new product
  Future<Product> addProduct({
    required String storeId,
    required String name,
    required double price,
    required int quantity,
    required String barcode,
    required String category,
    File? imageFile,
  }) async {
    final productId = _uuid.v4();
    String? imageUrl;

    // Upload image if provided
    if (imageFile != null) {
      imageUrl = await _uploadProductImage(storeId, productId, imageFile);
    }

    final product = Product(
      id: productId,
      name: name,
      price: price,
      quantityInStock: quantity,
      barcode: barcode,
      category: category,
      imageUrl: imageUrl,
      storeId: storeId,
    );

    await _productsRef(storeId).doc(productId).set(product.toMap());
    return product;
  }

  /// Update an existing product
  Future<void> updateProduct(Product product, {File? newImageFile}) async {
    String? imageUrl = product.imageUrl;

    if (newImageFile != null) {
      imageUrl = await _uploadProductImage(
        product.storeId,
        product.id,
        newImageFile,
      );
    }

    final updatedProduct = product.copyWith(imageUrl: imageUrl);
    await _productsRef(product.storeId)
        .doc(product.id)
        .update(updatedProduct.toMap());
  }

  /// Delete a product
  Future<void> deleteProduct(String storeId, String productId) async {
    // Delete image from storage if exists
    try {
      await _storage
          .ref('stores/$storeId/products/$productId')
          .delete();
    } catch (_) {
      // Image might not exist, ignore
    }

    await _productsRef(storeId).doc(productId).delete();
  }

  /// Decrement stock atomically
  Future<void> decrementStock(
    String storeId,
    String productId,
    int quantity,
  ) async {
    await _productsRef(storeId).doc(productId).update({
      'quantityInStock': FieldValue.increment(-quantity),
    });
  }

  /// Upload product image to Firebase Storage
  Future<String> _uploadProductImage(
    String storeId,
    String productId,
    File imageFile,
  ) async {
    final ref = _storage.ref('stores/$storeId/products/$productId.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  /// Get all unique categories for a store
  Future<List<String>> getCategories(String storeId) async {
    final snapshot = await _productsRef(storeId).get();
    final categories = snapshot.docs
        .map((doc) => doc.data()['category'] as String)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }
}
