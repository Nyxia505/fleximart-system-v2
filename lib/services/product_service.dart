import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

/// Product Service
/// 
/// Handles fetching products from Firestore
class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get products stream ordered by creation date (newest first)
  /// 
  /// Returns a stream of QuerySnapshot that emits whenever products change
  /// Handles cases where createdAt field might be missing or index is not available
  Stream<QuerySnapshot> getProductsStream() {
    // Use simple query without orderBy to avoid index requirements
    // We'll sort manually in the UI if needed
    return _firestore
        .collection('products')
        .snapshots()
        .handleError((error) {
      // Log error but don't crash
      print('Error fetching products: $error');
    });
  }

  /// Get products as a one-time fetch
  /// 
  /// Returns a list of Product models
  Future<List<Product>> getProducts() async {
    try {
      QuerySnapshot snapshot;
      try {
        // Try with orderBy first
        snapshot = await _firestore
            .collection('products')
            .orderBy('createdAt', descending: true)
            .get();
      } catch (e) {
        // Fallback to simple query if orderBy fails
        snapshot = await _firestore
            .collection('products')
            .get();
      }

      final products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
      
      // Sort manually if orderBy failed
      products.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return products;
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  /// Get products by category
  /// 
  /// Parameters:
  /// - [categoryId]: The category ID to filter by
  /// 
  /// Returns a stream of products filtered by category
  Stream<QuerySnapshot> getProductsByCategory(String categoryId) {
    try {
      return _firestore
          .collection('products')
          .where('categoryId', isEqualTo: categoryId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } catch (e) {
      // Fallback to simple query if orderBy fails
      return _firestore
          .collection('products')
          .where('categoryId', isEqualTo: categoryId)
          .snapshots();
    }
  }

  /// Get a single product by ID
  /// 
  /// Parameters:
  /// - [productId]: The product document ID
  /// 
  /// Returns the Product model or null if not found
  Future<Product?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      
      if (!doc.exists) {
        return null;
      }
      
      return Product.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch product: $e');
    }
  }

  /// Get sold count for a product
  /// 
  /// Parameters:
  /// - [productId]: The product document ID
  /// 
  /// Returns a stream of sold count from the product document (no orders query).
  Stream<int> getSoldCountStream(String productId) {
    return _firestore.collection('products').doc(productId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return 0;
      final data = snapshot.data();
      if (data == null) return 0;
      final sold =
          data['soldCount'] ?? data['sold'] ?? data['totalSold'] ?? data['sales'];
      return (sold as num?)?.toInt() ?? 0;
    }).handleError((error, stackTrace) {
      print('❌ [Sold Count] Error for productId "$productId": $error');
      return 0;
    });
  }

  /// Get sold count for a product (one-time fetch)
  /// 
  /// Parameters:
  /// - [productId]: The product document ID
  /// 
  /// Returns the total sold count as an integer
  Future<int> getSoldCount(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (!doc.exists) return 0;
      final data = doc.data();
      if (data == null) return 0;
      final sold =
          data['soldCount'] ?? data['sold'] ?? data['totalSold'] ?? data['sales'];
      return (sold as num?)?.toInt() ?? 0;
    } catch (e) {
      print('❌ [Sold Count] getSoldCount error: $e');
      return 0;
    }
  }
}
