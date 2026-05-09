import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/transaction.dart';
import '../models/cart_item.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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
    final callable = _functions.httpsCallable('checkout');
    final response = await callable.call<Map<String, dynamic>>(
      {
        'storeId': storeId,
        'cartItems': cartItems
            .map((item) => {
                  'productId': item.product.id,
                  'quantity': item.quantity,
                })
            .toList(),
      },
    );

    final data = response.data;
    final rawItems = data['items'] as List<dynamic>? ?? [];

    return SaleTransaction(
      id: data['transactionId'] as String,
      storeId: storeId,
      cashierId: cashierId,
      cashierName: data['cashierName'] as String? ?? cashierName,
      items: rawItems
          .map((item) => TransactionItem.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      totalAmount: (data['totalAmount'] as num).toDouble(),
      timestamp: DateTime.now(),
    );
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
