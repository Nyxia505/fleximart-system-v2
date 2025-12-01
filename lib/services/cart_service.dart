import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Cart Service
/// 
/// Handles cart operations using Firestore subcollection: users/{userId}/cart/{cartId}
class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get cart items stream for current user
  Stream<QuerySnapshot> getCartItemsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .snapshots();
  }

  /// Get cart count stream (returns total number of items in cart)
  Stream<int> getCartCountStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .snapshots()
        .map((snapshot) {
      // Sum up all quantities
      int totalCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
        totalCount += quantity;
      }
      return totalCount;
    });
  }

  /// Add item to cart
  Future<void> addToCart({
    required String productId,
    required String productName,
    required double price,
    required int quantity,
    String? productImage,
    double? length,
    double? width,
    Map<String, dynamic>? sizeData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to add items to cart');
    }

    // Check if item already exists in cart
    final existingItems = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .where('productId', isEqualTo: productId)
        .get();

    if (existingItems.docs.isNotEmpty) {
      // Update quantity of existing item
      final existingDoc = existingItems.docs.first;
      final existingData = existingDoc.data();
      final existingQuantity = (existingData['quantity'] as num?)?.toInt() ?? 0;
      
      await existingDoc.reference.update({
        'quantity': existingQuantity + quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Add new item to cart
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .add({
        'productId': productId,
        'productName': productName,
        'price': price,
        'quantity': quantity,
        if (productImage != null) 'productImage': productImage,
        if (length != null) 'length': length,
        if (width != null) 'width': width,
        if (sizeData != null) 'sizeData': sizeData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Remove item from cart
  Future<void> removeFromCart(String cartItemId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to remove items from cart');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .doc(cartItemId)
        .delete();
  }

  /// Update cart item quantity
  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to update cart');
    }

    if (newQuantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .doc(cartItemId)
        .update({
      'quantity': newQuantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Clear all items from cart
  Future<void> clearCart() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to clear cart');
    }

    final cartItems = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .get();

    final batch = _firestore.batch();
    for (var doc in cartItems.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Get cart items as a one-time fetch
  Future<List<QueryDocumentSnapshot>> getCartItems() async {
    final user = _auth.currentUser;
    if (user == null) {
      return [];
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .get();

    return snapshot.docs;
  }
}

