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
  /// Returns a stream of sold count (int) that updates in real-time
  /// Counts orders that are not cancelled (completed, delivered, pending, etc.)
  Stream<int> getSoldCountStream(String productId) {
    // Query all orders and filter out cancelled ones
    // Also check items array for products in multi-item orders
    return _firestore
        .collection('orders')
        .snapshots()
        .map((snapshot) {
      int totalSold = 0;
      
      // Always log in production to help debug
      print('🔍 [Sold Count] Checking for productId: $productId');
      print('   📋 Total orders in database: ${snapshot.docs.length}');
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          // Skip cancelled orders
          final status = (data['status'] as String? ?? '').toLowerCase().trim();
          if (status == 'cancelled') {
            continue;
          }
          
          bool foundInItems = false;
          
          // Check if order has items array (multi-item orders or new format)
          if (data['items'] != null && data['items'] is List) {
            final items = data['items'] as List;
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                final itemProductId = (item['productId'] as String?)?.trim();
                // Use both exact match and case-insensitive comparison
                if (itemProductId != null && 
                    (itemProductId == productId || 
                     itemProductId.toLowerCase() == productId.toLowerCase())) {
                  final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                  if (quantity > 0) {
                    totalSold += quantity;
                    foundInItems = true;
                    print('   ✅ [Order ${doc.id}] Found in items array: quantity=$quantity, total=$totalSold');
                  }
                }
              }
            }
          }
          
          // Also check direct productId field (for legacy orders or when items array doesn't match)
          final orderProductId = (data['productId'] as String?)?.trim();
          if (orderProductId != null && 
              (orderProductId == productId || 
               orderProductId.toLowerCase() == productId.toLowerCase())) {
            // Only count if we didn't already count from items array
            if (!foundInItems) {
              final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
              if (quantity > 0) {
                totalSold += quantity;
                print('   ✅ [Order ${doc.id}] Found in direct field: quantity=$quantity, total=$totalSold');
              }
            }
          }
        } catch (e) {
          // Log error for this specific order but continue processing others
          print('   ⚠️ [Order ${doc.id}] Error processing: $e');
        }
      }
      
      print('📊 [Sold Count] Final result for productId "$productId": $totalSold sold');
      
      return totalSold;
    }).handleError((error, stackTrace) {
      // Log error with stack trace for debugging
      print('❌ [Sold Count] Error in getSoldCountStream for productId "$productId": $error');
      print('   Stack trace: $stackTrace');
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
      // Get all orders (we'll filter cancelled ones manually)
      final snapshot = await _firestore
          .collection('orders')
          .get();
      
      int totalSold = 0;
      
      print('🔍 [Sold Count] One-time fetch for productId: $productId');
      print('   📋 Total orders in database: ${snapshot.docs.length}');
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          // Skip cancelled orders
          final status = (data['status'] as String? ?? '').toLowerCase().trim();
          if (status == 'cancelled') {
            continue;
          }
          
          bool foundInItems = false;
          
          // Check if order has items array (multi-item orders)
          if (data['items'] != null && data['items'] is List) {
            final items = data['items'] as List;
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                final itemProductId = (item['productId'] as String?)?.trim();
                // Use both exact match and case-insensitive comparison
                if (itemProductId != null && 
                    (itemProductId == productId || 
                     itemProductId.toLowerCase() == productId.toLowerCase())) {
                  final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                  if (quantity > 0) {
                    totalSold += quantity;
                    foundInItems = true;
                    print('   ✅ [Order ${doc.id}] Found in items: quantity=$quantity');
                  }
                }
              }
            }
          }
          
          // Also check direct productId field
          final orderProductId = (data['productId'] as String?)?.trim();
          if (orderProductId != null && 
              (orderProductId == productId || 
               orderProductId.toLowerCase() == productId.toLowerCase())) {
            // Only count if we didn't already count from items array
            if (!foundInItems) {
              final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
              if (quantity > 0) {
                totalSold += quantity;
                print('   ✅ [Order ${doc.id}] Found in direct field: quantity=$quantity');
              }
            }
          }
        } catch (e) {
          print('   ⚠️ [Order ${doc.id}] Error processing: $e');
        }
      }
      
      print('📊 [Sold Count] Final result for productId "$productId": $totalSold sold');
      
      return totalSold;
    } catch (e, stackTrace) {
      // Return 0 if there's an error to prevent UI crashes
      print('❌ [Sold Count] Error calculating sold count for "$productId": $e');
      print('   Stack trace: $stackTrace');
      return 0;
    }
  }
}
