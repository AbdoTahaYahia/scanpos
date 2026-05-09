import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/cart_item.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Collection reference for transactions in a store
  CollectionReference<Map<String, dynamic>> _transactionsRef(String storeId) {
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('transactions');
  }

  /// Create a new transaction with atomic stock decrement
  Future<SaleTransaction> createTransaction({
    required String storeId,
    required String cashierId,
    required String cashierName,
    required List<CartItem> cartItems,
  }) async {
    final transactionId = _uuid.v4();
    final now = DateTime.now();

    // Convert cart items to transaction items
    final transactionItems = cartItems
        .map((item) => TransactionItem(
              productId: item.product.id,
              productName: item.product.name,
              price: item.product.price,
              quantity: item.quantity,
              subtotal: item.subtotal,
            ))
        .toList();

    final totalAmount =
        cartItems.fold<double>(0, (total, item) => total + item.subtotal);

    final transaction = SaleTransaction(
      id: transactionId,
      storeId: storeId,
      cashierId: cashierId,
      cashierName: cashierName,
      items: transactionItems,
      totalAmount: totalAmount,
      timestamp: now,
    );

    // Use a Firestore transaction to atomically:
    // 1. Verify stock is sufficient
    // 2. Create the transaction record
    // 3. Decrement stock for each product
    await _firestore.runTransaction((tx) async {
      final productRefs = cartItems.map((item) {
        return _firestore
            .collection('stores')
            .doc(storeId)
            .collection('products')
            .doc(item.product.id);
      }).toList();

      // Read all products first
      final snapshots = await Future.wait(productRefs.map((ref) => tx.get(ref)));

      // Verify stock
      for (int i = 0; i < cartItems.length; i++) {
        final snap = snapshots[i];
        if (!snap.exists) {
          throw Exception('Product ${cartItems[i].product.name} not found');
        }
        final currentStock = snap.data()?['quantityInStock'] as int? ?? 0;
        if (currentStock < cartItems[i].quantity) {
          throw Exception('Insufficient stock for ${cartItems[i].product.name}. Available: $currentStock');
        }
      }

      // Write transaction
      tx.set(
        _transactionsRef(storeId).doc(transactionId),
        transaction.toMap(),
      );

      // Decrement stock
      for (int i = 0; i < cartItems.length; i++) {
        tx.update(productRefs[i], {
          'quantityInStock': FieldValue.increment(-cartItems[i].quantity),
        });
      }
    });

    return transaction;
  }

  /// Stream all transactions for a store (reverse chronological)
  Stream<List<SaleTransaction>> getTransactions(String storeId) {
    return _transactionsRef(storeId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SaleTransaction.fromMap(doc.data()))
          .toList();
    });
  }

  /// Fetch a page of transactions (cursor-based pagination).
  /// Returns the raw QuerySnapshot so the caller can use the last
  /// document as a cursor for the next page.
  Future<QuerySnapshot<Map<String, dynamic>>> getTransactionsPaginated(
    String storeId, {
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _transactionsRef(storeId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.get();
  }

  /// Get a single transaction by ID
  Future<SaleTransaction?> getTransaction(
    String storeId,
    String transactionId,
  ) async {
    final doc =
        await _transactionsRef(storeId).doc(transactionId).get();
    if (!doc.exists) return null;
    return SaleTransaction.fromMap(doc.data()!);
  }
}
