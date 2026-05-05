import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';

class PaginatedProducts {
  final List<Product> products;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  PaginatedProducts({
    required this.products,
    required this.lastDoc,
    required this.hasMore,
  });
}

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Collection reference for products in a store
  CollectionReference<Map<String, dynamic>> _productsRef(String storeId) {
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('products');
  }

  /// Fetch paginated products for a store
  Future<PaginatedProducts> getProductsPaginated({
    required String storeId,
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _productsRef(storeId)
        .orderBy('name')
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    
    final products = snapshot.docs
        .map((doc) => Product.fromMap(doc.data()))
        .toList();

    return PaginatedProducts(
      products: products,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == limit,
    );
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

  /// Get all products for search/OCR purposes (bypasses pagination)
  Future<List<Product>> getAllProducts(String storeId) async {
    final snapshot = await _productsRef(storeId).get();
    return snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
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
    String? size,
  }) async {
    final productId = _uuid.v4();

    final product = Product(
      id: productId,
      name: name,
      price: price,
      quantityInStock: quantity,
      barcode: barcode,
      category: category,
      storeId: storeId,
      size: size,
    );

    await _productsRef(storeId).doc(productId).set(product.toMap());
    return product;
  }

  /// Update an existing product
  Future<void> updateProduct(Product product) async {
    await _productsRef(product.storeId)
        .doc(product.id)
        .update(product.toMap());
  }

  /// Delete a product
  Future<void> deleteProduct(String storeId, String productId) async {
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
