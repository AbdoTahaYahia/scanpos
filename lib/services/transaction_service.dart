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

  /// Create a new transaction with atomic stock decrement (client-side).
  /// Uses Firestore runTransaction for atomicity — no Cloud Function needed.
  Future<SaleTransaction> createTransaction({
    required String storeId,
    required String cashierId,
    required String cashierName,
    required List<CartItem> cartItems,
  }) async {
    final txDocRef = _transactionsRef(storeId).doc();
    final transactionId = txDocRef.id;
    final now = DateTime.now();

    // Build transaction items and validate stock atomically
    final transactionItems = <TransactionItem>[];
    double totalAmount = 0;

    await _firestore.runTransaction((firestoreTx) async {
      // 1. Read all product documents and validate stock
      final productRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      final productSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      for (final cartItem in cartItems) {
        final pid = cartItem.product.id;
        if (!productRefs.containsKey(pid)) {
          productRefs[pid] = _firestore
              .collection('stores')
              .doc(storeId)
              .collection('products')
              .doc(pid);
          productSnaps[pid] = await firestoreTx.get(productRefs[pid]!);
        }
      }

      // 2. Validate stock and build items
      transactionItems.clear();
      totalAmount = 0;

      for (final cartItem in cartItems) {
        final pid = cartItem.product.id;
        final snap = productSnaps[pid]!;

        if (!snap.exists) {
          throw Exception('Product "${cartItem.product.name}" not found.');
        }

        final productData = snap.data()!;
        final currentStock = productData['quantityInStock'] as int? ?? 0;
        final price = (productData['price'] as num).toDouble();

        if (currentStock < cartItem.quantity) {
          throw Exception(
            'Insufficient stock for "${cartItem.product.name}". '
            'Available: $currentStock, requested: ${cartItem.quantity}',
          );
        }

        final subtotal = price * cartItem.quantity;
        totalAmount += subtotal;

        transactionItems.add(TransactionItem(
          productId: pid,
          productName: productData['name'] as String? ?? cartItem.product.name,
          price: price,
          quantity: cartItem.quantity,
          subtotal: subtotal,
        ));
      }

      // 3. Decrement stock for all products
      final qtyByProduct = <String, int>{};
      for (final cartItem in cartItems) {
        qtyByProduct[cartItem.product.id] =
            (qtyByProduct[cartItem.product.id] ?? 0) + cartItem.quantity;
      }

      for (final entry in qtyByProduct.entries) {
        firestoreTx.update(productRefs[entry.key]!, {
          'quantityInStock': FieldValue.increment(-entry.value),
        });
      }

      // 4. Create the transaction document
      final txData = {
        'id': transactionId,
        'storeId': storeId,
        'cashierId': cashierId,
        'cashierName': cashierName,
        'items': transactionItems.map((i) => i.toMap()).toList(),
        'totalAmount': totalAmount,
        'timestamp': Timestamp.fromDate(now),
      };

      firestoreTx.set(txDocRef, txData);
    });

    return SaleTransaction(
      id: transactionId,
      storeId: storeId,
      cashierId: cashierId,
      cashierName: cashierName,
      items: transactionItems,
      totalAmount: totalAmount,
      timestamp: now,
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

  /// Fetch recent transactions for a specific cashier (last 24h)
  Future<List<SaleTransaction>> getCashierRecentTransactions(
    String storeId,
    String cashierId, {
    int limit = 50,
  }) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final snapshot = await _transactionsRef(storeId)
        .where('cashierId', isEqualTo: cashierId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => SaleTransaction.fromMap(doc.data()))
        .toList();
  }

  /// Edit a transaction with atomic stock adjustment (client-side Firestore transaction).
  /// Works without Cloud Functions — uses Firestore runTransaction for atomicity.
  Future<void> editTransaction({
    required String storeId,
    required String transactionId,
    required String cashierId,
    required List<Map<String, dynamic>> updatedItems,
  }) async {
    final txRef = _transactionsRef(storeId).doc(transactionId);

    await _firestore.runTransaction((firestoreTx) async {
      // 1. Read the existing transaction
      final txSnap = await firestoreTx.get(txRef);
      if (!txSnap.exists) {
        throw Exception('Transaction not found.');
      }

      final txData = txSnap.data()!;

      // 2. Verify ownership
      if (txData['cashierId'] != cashierId) {
        throw Exception('You can only edit your own transactions.');
      }

      // 3. Verify within 24 hours
      final timestamp = (txData['timestamp'] as Timestamp).toDate();
      final hoursSince = DateTime.now().difference(timestamp).inHours;
      if (hoursSince > 24) {
        throw Exception('Transactions older than 24 hours cannot be edited.');
      }

      // 4. Build old quantity map
      final oldItems = txData['items'] as List<dynamic>;
      final oldQtyMap = <String, int>{};
      for (final item in oldItems) {
        final pid = item['productId'] as String;
        oldQtyMap[pid] = (oldQtyMap[pid] ?? 0) + (item['quantity'] as int);
      }

      // 5. Build new quantity map
      final newQtyMap = <String, int>{};
      for (final item in updatedItems) {
        final qty = item['quantity'] as int;
        if (qty > 0) {
          final pid = item['productId'] as String;
          newQtyMap[pid] = (newQtyMap[pid] ?? 0) + qty;
        }
      }

      // 6. Calculate diffs and adjust stock
      final allProductIds = {...oldQtyMap.keys, ...newQtyMap.keys};

      for (final pid in allProductIds) {
        final oldQty = oldQtyMap[pid] ?? 0;
        final newQty = newQtyMap[pid] ?? 0;
        final diff = newQty - oldQty; // positive = need more stock, negative = return stock

        if (diff != 0) {
          final productRef = _firestore
              .collection('stores')
              .doc(storeId)
              .collection('products')
              .doc(pid);

          // Validate stock if we need more
          if (diff > 0) {
            final productSnap = await firestoreTx.get(productRef);
            if (productSnap.exists) {
              final currentStock = productSnap.data()?['quantityInStock'] as int? ?? 0;
              if (currentStock < diff) {
                final name = productSnap.data()?['name'] ?? pid;
                throw Exception('Insufficient stock for $name');
              }
            }
          }

          firestoreTx.update(productRef, {
            'quantityInStock': FieldValue.increment(-diff),
          });
        }
      }

      // 7. Update or delete the transaction
      if (updatedItems.isEmpty || updatedItems.every((i) => (i['quantity'] as int) <= 0)) {
        firestoreTx.delete(txRef);
      } else {
        double newTotal = 0;
        for (final item in updatedItems) {
          newTotal += ((item['price'] as num).toDouble()) * (item['quantity'] as int);
        }

        firestoreTx.update(txRef, {
          'items': updatedItems,
          'totalAmount': newTotal,
        });
      }
    });
  }
}
