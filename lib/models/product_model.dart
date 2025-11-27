import 'package:cloud_firestore/cloud_firestore.dart';

/// Product Model
/// 
/// Maps Firestore document data to a Product object
class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String categoryId;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    this.createdAt,
  });

  /// Create Product from Firestore document
  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Product(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Product',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert Product to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  /// Create a copy of Product with updated fields
  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    String? categoryId,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
