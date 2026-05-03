class Product {
  final String id;
  final String name;
  final double price;
  final int quantityInStock;
  final String barcode;
  final String category;
  final String? imageUrl;
  final String storeId;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.quantityInStock,
    required this.barcode,
    required this.category,
    this.imageUrl,
    required this.storeId,
  });

  Product copyWith({
    String? id,
    String? name,
    double? price,
    int? quantityInStock,
    String? barcode,
    String? category,
    String? imageUrl,
    String? storeId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantityInStock: quantityInStock ?? this.quantityInStock,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      storeId: storeId ?? this.storeId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantityInStock': quantityInStock,
      'barcode': barcode,
      'category': category,
      'imageUrl': imageUrl,
      'storeId': storeId,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      quantityInStock: map['quantityInStock'] as int,
      barcode: map['barcode'] as String,
      category: map['category'] as String,
      imageUrl: map['imageUrl'] as String?,
      storeId: map['storeId'] as String,
    );
  }
}
