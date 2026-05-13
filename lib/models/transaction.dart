import 'package:cloud_firestore/cloud_firestore.dart';

class SaleTransaction {
  final String id;
  final String storeId;
  final String cashierId;
  final String cashierName;
  final List<TransactionItem> items;
  final double totalAmount;
  final DateTime timestamp;

  SaleTransaction({
    required this.id,
    required this.storeId,
    required this.cashierId,
    required this.cashierName,
    required this.items,
    required this.totalAmount,
    required this.timestamp,
  });

  int get itemCount => items.fold(0, (total, item) => total + item.quantity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  SaleTransaction copyWith({
    String? id,
    String? storeId,
    String? cashierId,
    String? cashierName,
    List<TransactionItem>? items,
    double? totalAmount,
    DateTime? timestamp,
  }) {
    return SaleTransaction(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  factory SaleTransaction.fromMap(Map<String, dynamic> map) {
    return SaleTransaction(
      id: map['id'] as String,
      storeId: map['storeId'] as String,
      cashierId: map['cashierId'] as String,
      cashierName: map['cashierName'] as String,
      items: (map['items'] as List<dynamic>)
          .map((item) => TransactionItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}

class TransactionItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double subtotal;

  TransactionItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }
}
