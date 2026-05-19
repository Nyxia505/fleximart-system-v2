import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

/// Product Service
///
/// Handles fetching products from Firestore
class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<Map<String, int>>? _orderSoldCountsStream;
  static Map<String, int> _latestOrderSoldCounts = {};

  static const _excludedOrderStatuses = {
    'cancelled',
    'canceled',
    'rejected',
    'refunded',
  };

  /// Field names used for sold count on product documents (manual / legacy).
  static const _soldFieldKeys = [
    'soldCount',
    'sold',
    'solds',
    'totalSold',
    'sales',
    'qtySold',
    'unitsSold',
    'quantitySold',
    'numberSold',
  ];

  /// Parses sold count from a product map (handles numbers and strings).
  static int parseSoldCountFromMap(Map<String, dynamic>? data) {
    if (data == null) return 0;

    for (final key in _soldFieldKeys) {
      if (!data.containsKey(key)) continue;
      final parsed = _parseIntValue(data[key]);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  static int _parseIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) return value.toInt().clamp(0, 1 << 30);
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return 0;
      return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt() ?? 0;
    }
    return 0;
  }

  static int _resolvedSoldCount(int fromProductDoc, int fromOrders) {
    if (fromProductDoc > 0 && fromOrders > 0) {
      return fromProductDoc > fromOrders ? fromProductDoc : fromOrders;
    }
    if (fromProductDoc > 0) return fromProductDoc;
    return fromOrders;
  }

  /// Aggregates quantities sold per product from all non-cancelled orders.
  static Map<String, int> computeSoldCountsFromOrders(
    Iterable<QueryDocumentSnapshot> orders,
  ) {
    final counts = <String, int>{};

    for (final doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isQuotation'] == true) continue;

      final status = (data['status'] as String? ?? '').toLowerCase();
      if (_excludedOrderStatuses.contains(status)) continue;

      final items = data['items'];
      if (items is List && items.isNotEmpty) {
        for (final entry in items) {
          if (entry is! Map) continue;
          final map = Map<String, dynamic>.from(entry);
          final productId = (map['productId'] ?? map['product_id']) as String?;
          if (productId == null || productId.isEmpty) continue;
          final qty = _parseIntValue(map['quantity'] ?? map['qty'] ?? 1);
          if (qty <= 0) continue;
          counts[productId] = (counts[productId] ?? 0) + qty;
        }
        continue;
      }

      final productId = (data['productId'] ?? data['product_id']) as String?;
      if (productId == null || productId.isEmpty) continue;
      final qty = _parseIntValue(data['quantity'] ?? data['qty'] ?? 1);
      if (qty <= 0) continue;
      counts[productId] = (counts[productId] ?? 0) + qty;
    }

    return counts;
  }

  static Stream<Map<String, int>> _watchOrderSoldCounts() {
    _orderSoldCountsStream ??= () {
      final controller = StreamController<Map<String, int>>.broadcast();

      FirebaseFirestore.instance.collection('orders').snapshots().listen(
        (snapshot) {
          _latestOrderSoldCounts = computeSoldCountsFromOrders(snapshot.docs);
          if (!controller.isClosed) {
            controller.add(Map<String, int>.from(_latestOrderSoldCounts));
          }
        },
        onError: (error) {
          print('❌ [Sold Count] Orders stream error: $error');
          if (!controller.isClosed) {
            controller.add(Map<String, int>.from(_latestOrderSoldCounts));
          }
        },
      );

      return controller.stream;
    }();

    return _orderSoldCountsStream!;
  }

  /// Get products stream ordered by creation date (newest first)
  ///
  /// Returns a stream of QuerySnapshot that emits whenever products change
  /// Handles cases where createdAt field might be missing or index is not available
  Stream<QuerySnapshot> getProductsStream() {
    // Use simple query without orderBy to avoid index requirements
    // We'll sort manually in the UI if needed
    return _firestore.collection('products').snapshots().handleError((error) {
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
        snapshot = await _firestore.collection('products').get();
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

  /// Live sold count: product document fields + quantities from orders.
  Stream<int> getSoldCountStream(String productId) {
    final controller = StreamController<int>();
    var docSold = 0;
    var orderSold = _latestOrderSoldCounts[productId] ?? 0;

    void emit() {
      if (!controller.isClosed) {
        controller.add(_resolvedSoldCount(docSold, orderSold));
      }
    }

    final productSub = _firestore
        .collection('products')
        .doc(productId)
        .snapshots()
        .listen(
          (snapshot) {
            docSold = snapshot.exists
                ? parseSoldCountFromMap(snapshot.data())
                : 0;
            emit();
          },
          onError: (error) {
            print('❌ [Sold Count] Product stream error "$productId": $error');
            docSold = 0;
            emit();
          },
        );

    final ordersSub = _watchOrderSoldCounts().listen(
      (counts) {
        orderSold = counts[productId] ?? 0;
        emit();
      },
      onError: (error) {
        print('❌ [Sold Count] Orders map error "$productId": $error');
        orderSold = _latestOrderSoldCounts[productId] ?? 0;
        emit();
      },
    );

    emit();

    controller.onCancel = () {
      productSub.cancel();
      ordersSub.cancel();
    };

    return controller.stream;
  }

  /// One-time sold count fetch.
  Future<int> getSoldCount(String productId) async {
    try {
      var docSold = 0;
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        docSold = parseSoldCountFromMap(doc.data());
      }

      final ordersSnap = await _firestore.collection('orders').get();
      final orderSold =
          computeSoldCountsFromOrders(ordersSnap.docs)[productId] ?? 0;

      return _resolvedSoldCount(docSold, orderSold);
    } catch (e) {
      print('❌ [Sold Count] getSoldCount error: $e');
      return 0;
    }
  }
}
