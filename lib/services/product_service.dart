import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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
      
      if (kDebugMode) {
        print('🔍 Checking sold count for productId: $productId');
        print('   Total orders found: ${snapshot.docs.length}');
      }
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Skip cancelled orders
        final status = data['status'] as String? ?? '';
        if (status.toLowerCase() == 'cancelled') {
          if (kDebugMode) {
            print('   ⏭️ Skipping cancelled order: ${doc.id}');
          }
          continue;
        }
        
        bool foundInItems = false;
        
        // Check if order has items array (multi-item orders or new format)
        if (data['items'] != null && data['items'] is List) {
          final items = data['items'] as List;
          if (kDebugMode) {
            print('   📦 Order ${doc.id} has ${items.length} items');
          }
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              final itemProductId = item['productId'] as String?;
              if (kDebugMode && itemProductId != null) {
                print('     - Item productId: $itemProductId (looking for: $productId)');
              }
              if (itemProductId == productId) {
                final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                totalSold += quantity;
                foundInItems = true;
                if (kDebugMode) {
                  print('     ✅ Found match! Adding quantity: $quantity (total now: $totalSold)');
                }
              }
            }
          }
        }
        
        // Only check direct productId field if not found in items array (legacy format)
        if (!foundInItems) {
          final orderProductId = data['productId'] as String?;
          if (kDebugMode && orderProductId != null) {
            print('   🔍 Order ${doc.id} direct productId: $orderProductId (looking for: $productId)');
          }
          if (orderProductId == productId) {
            final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
            totalSold += quantity;
            if (kDebugMode) {
              print('     ✅ Found match in direct field! Adding quantity: $quantity (total now: $totalSold)');
            }
          }
        }
      }
      
      if (kDebugMode) {
        print('📊 Final sold count for productId $productId: $totalSold');
      }
      
      return totalSold;
    }).handleError((error) {
      // Log error but don't crash
      print('❌ Error in getSoldCountStream: $error');
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
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Skip cancelled orders
        final status = data['status'] as String? ?? '';
        if (status.toLowerCase() == 'cancelled') {
          continue;
        }
        
        bool foundInItems = false;
        
        // Check if order has items array (multi-item orders or new format)
        if (data['items'] != null && data['items'] is List) {
          final items = data['items'] as List;
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              final itemProductId = item['productId'] as String?;
              if (itemProductId == productId) {
                final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                totalSold += quantity;
                foundInItems = true;
              }
            }
          }
        }
        
        // Only check direct productId field if not found in items array (legacy format)
        if (!foundInItems) {
          final orderProductId = data['productId'] as String?;
          if (orderProductId == productId) {
            final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
            totalSold += quantity;
          }
        }
      }
      
      if (kDebugMode) {
        print('📊 Sold count for product $productId: $totalSold');
      }
      
      return totalSold;
    } catch (e) {
      // Return 0 if there's an error to prevent UI crashes
      print('Error calculating sold count: $e');
      return 0;
    }
  }
}
