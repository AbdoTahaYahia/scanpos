class Product {
  final String id;
  final String name;
  final double price;
  final int quantityInStock;
  final int initialQuantity;
  final String barcode;
  final String category;
  final String storeId;
  final String? size;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.quantityInStock,
    int? initialQuantity,
    required this.barcode,
    required this.category,
    required this.storeId,
    this.size,
  }) : initialQuantity = initialQuantity ?? quantityInStock;

  Product copyWith({
    String? id,
    String? name,
    double? price,
    int? quantityInStock,
    int? initialQuantity,
    String? barcode,
    String? category,
    String? storeId,
    String? size,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantityInStock: quantityInStock ?? this.quantityInStock,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      storeId: storeId ?? this.storeId,
      size: size ?? this.size,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantityInStock': quantityInStock,
      'initialQuantity': initialQuantity,
      'barcode': barcode,
      'category': category,
      'storeId': storeId,
      'size': size,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    final qty = map['quantityInStock'] as int;
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      quantityInStock: qty,
      initialQuantity: map['initialQuantity'] as int? ?? qty,
      barcode: map['barcode'] as String,
      category: map['category'] as String,
      storeId: map['storeId'] as String,
      size: map['size'] as String?,
    );
  }
}
