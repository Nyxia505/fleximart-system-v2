import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'phone_verification_service.dart';

/// Order Service
/// 
/// Handles order operations with Firestore using the specified schema
class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService.instance;

  /// Create a new order in Firestore
  /// 
  /// Parameters match the exact Firestore schema:
  /// - [customerId]: The customer's user ID (required)
  /// - [customerName]: Customer's full name (required)
  /// - [customerEmail]: Customer's email address (required)
  /// - [productId]: Product identifier (required)
  /// - [productName]: Product name (required)
  /// - [productImage]: Product image URL (optional)
  /// - [quantity]: Order quantity (required)
  /// - [price]: Unit price (required)
  /// - [totalPrice]: Total order price (required)
  /// - [paymentMethod]: Payment method (optional, defaults to null)
  /// - [installationRequired]: Whether installation is required (required)
  /// - [address]: Delivery/installation address (optional)
  /// - [selectedWidth]: Selected product width in inches (optional)
  /// - [selectedHeight]: Selected product height in inches (optional)
  /// - [addedPrice]: Additional price for selected size (optional)
  /// - [customLength]: Custom length in cm (optional)
  /// - [customWidth]: Custom width in cm (optional)
  /// - [productLength]: Product length in cm from product document (optional)
  /// - [productWidth]: Product width in cm from product document (optional)
  /// 
  /// Returns the created order document ID
  /// 
  /// Throws exception if phone is not verified
  Future<String> createOrder({
    required String customerId,
    required String customerName,
    required String customerEmail,
    required String productId,
    required String productName,
    String? productImage,
    required int quantity,
    required double price,
    required double totalPrice,
    String? paymentMethod,
    required bool installationRequired,
    String? address, // Legacy field, use delivery address fields instead
    // Delivery address fields (required)
    required String fullName,
    required String phoneNumber,
    required String completeAddress,
    String? landmark,
    String? mapLink,
    double? latitude,
    double? longitude,
    double? selectedWidth,
    double? selectedHeight,
    double? addedPrice,
    double? customLength,
    double? customWidth,
    double? productLength,
    double? productWidth,
  }) async {
    try {
      // Check if phone is verified
      final isPhoneVerified = await PhoneVerificationService.isPhoneVerified(customerId);
      if (!isPhoneVerified) {
        throw Exception('PHONE_NOT_VERIFIED: Please verify your phone number before placing an order.');
      }

      // Deduct stock from product using transaction for atomicity
      try {
        if (kDebugMode) {
          print('🔄 Starting stock deduction for product: $productId, quantity: $quantity');
        }
        
        await _firestore.runTransaction((transaction) async {
          final productRef = _firestore.collection('products').doc(productId);
          final productDoc = await transaction.get(productRef);
          
          if (!productDoc.exists) {
            throw Exception('Product not found: $productId');
          }
          
          final productData = productDoc.data() as Map<String, dynamic>;
          final currentStock = (productData['stock'] as num?)?.toInt() ?? 0;
          
          if (kDebugMode) {
            print('📊 Current stock: $currentStock, Requested quantity: $quantity');
          }
          
          // Check if there's enough stock
          if (currentStock < quantity) {
            throw Exception('INSUFFICIENT_STOCK: Only $currentStock items available. Requested: $quantity');
          }
          
          // Calculate new stock
          final newStock = currentStock - quantity;
          
          if (kDebugMode) {
            print('💾 Updating stock: $currentStock -> $newStock');
          }
          
          // Update product stock within transaction
          transaction.update(productRef, {
            'stock': newStock,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          return newStock;
        });
        
        if (kDebugMode) {
          print('✅ Stock deducted successfully: $productId (quantity: $quantity)');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error deducting stock: $e');
          print('   Product ID: $productId');
          print('   Quantity: $quantity');
        }
        // Re-throw the error so order creation fails if stock deduction fails
        throw Exception('Failed to deduct stock: $e');
      }

      // Create items array with product details
      final item = <String, dynamic>{
        'productId': productId,
        'productName': productName,
        if (productImage != null) 'productImage': productImage,
        'quantity': quantity,
        'price': price,
      };
      
      // Add length and width to item (use productLength/productWidth if available, otherwise use customLength/customWidth)
      if (productLength != null) {
        item['length'] = productLength;
      } else if (customLength != null) {
        item['length'] = customLength;
      }
      
      if (productWidth != null) {
        item['width'] = productWidth;
      } else if (customWidth != null) {
        item['width'] = customWidth;
      }
      
      final orderRef = await _firestore.collection('orders').add({
        'customerId': customerId,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'productId': productId,
        'productName': productName,
        if (productImage != null) 'productImage': productImage,
        'quantity': quantity,
        'price': price,
        'totalPrice': totalPrice,
        'status': 'pending_payment',
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
        'items': [item], // Add items array
        'paidAt': null,
        'shippedAt': null,
        'deliveredAt': null,
        'installationRequired': installationRequired,
        'installationScheduledAt': null,
        'rating': null,
        'review': null,
        // Delivery address fields (required)
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'completeAddress': completeAddress,
        if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
        if (mapLink != null && mapLink.isNotEmpty) 'mapLink': mapLink,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        // Legacy address field (for backward compatibility)
        if (address != null) 'address': address,
        if (selectedWidth != null) 'selectedWidth': selectedWidth,
        if (selectedHeight != null) 'selectedHeight': selectedHeight,
        if (addedPrice != null) 'addedPrice': addedPrice,
        if (customLength != null) 'customLength': customLength,
        if (customWidth != null) 'customWidth': customWidth,
      });

      if (kDebugMode) {
        print('✅ Order created successfully: ${orderRef.id}');
      }

      // Create notifications for staff/admin
      try {
        final orderData = {
          'customerId': customerId,
          'customerName': customerName,
          'customerEmail': customerEmail,
          'productId': productId,
          'productName': productName,
          'totalPrice': totalPrice,
          'totalAmount': totalPrice,
        };
        
        await _notificationService.notifyNewOrder(
          orderId: orderRef.id,
          orderData: orderData,
        );
      } catch (e) {
        // Don't fail order creation if notification fails
        if (kDebugMode) {
          print('⚠️ Error creating new order notifications: $e');
        }
      }

      return orderRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating order: $e');
      }
      throw Exception('Failed to create order: $e');
    }
  }

  /// Update order status
  /// 
  /// Parameters:
  /// - [orderId]: The order document ID
  /// - [newStatus]: The new status (e.g., 'paid', 'shipped', 'awaiting_installation', 'completed', 'delivered')
  /// - [updateTimestamp]: Optional field to update timestamp (e.g., 'paidAt', 'shippedAt', 'deliveredAt')
  /// - [createNotification]: Whether to create a notification for the customer (default: true)
  /// 
  /// Returns the updated order document reference
  Future<DocumentReference> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? updateTimestamp, // 'paidAt', 'shippedAt', 'deliveredAt', etc.
    bool createNotification = true,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
      };

      // Update the appropriate timestamp field if provided
      if (updateTimestamp != null) {
        updateData[updateTimestamp] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('orders').doc(orderId).update(updateData);

      // Create notification for customer if enabled
      if (createNotification) {
        try {
          final orderDoc = await _firestore.collection('orders').doc(orderId).get();
          if (orderDoc.exists) {
            final orderData = orderDoc.data() as Map<String, dynamic>;
            final customerId = orderData['customerId'] as String?;
            
            if (customerId != null) {
              await _notificationService.notifyOrderStatusChange(
                customerId: customerId,
                orderId: orderId,
                orderData: orderData,
                newStatus: newStatus,
              );
            }
          }
        } catch (e) {
          // Don't fail the order update if notification fails
          if (kDebugMode) {
            print('⚠️ Error creating notification: $e');
          }
        }
      }

      if (kDebugMode) {
        print('✅ Order status updated: $orderId -> $newStatus');
      }

      return _firestore.collection('orders').doc(orderId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating order status: $e');
      }
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Get customer orders
  /// 
  /// Parameters:
  /// - [customerId]: The customer's user ID
  /// - [status]: Optional status filter (e.g., 'pending_payment', 'paid', 'shipped', etc.)
  /// 
  /// Returns a Stream of QuerySnapshot for real-time updates
  Stream<QuerySnapshot> getCustomerOrders({
    required String customerId,
    String? status,
  }) {
    Query query = _firestore
        .collection('orders')
        .where('customerId', isEqualTo: customerId);

    // Apply status filter if provided
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    // Note: Sorting by createdAt should be done in memory to avoid composite index requirements
    // when combining where('customerId') with orderBy('createdAt')
    return query.snapshots();
  }

  /// Get customer orders as a one-time fetch (non-streaming)
  /// 
  /// Parameters:
  /// - [customerId]: The customer's user ID
  /// - [status]: Optional status filter
  /// 
  /// Returns a Future with List of order documents
  Future<List<QueryDocumentSnapshot>> getCustomerOrdersOnce({
    required String customerId,
    String? status,
  }) async {
    try {
      Query query = _firestore
          .collection('orders')
          .where('customerId', isEqualTo: customerId);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      // Query without orderBy to avoid composite index requirements
      // Sort in memory instead
      final snapshot = await query.get();
      final docs = List<QueryDocumentSnapshot>.from(snapshot.docs);
      // Sort manually by createdAt (descending - newest first)
      docs.sort((a, b) {
        final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Descending
      });
      return docs;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching customer orders: $e');
      }
      throw Exception('Failed to fetch customer orders: $e');
    }
  }

  /// Update order rating and review
  /// 
  /// Parameters:
  /// - [orderId]: The order document ID
  /// - [rating]: Rating value (1-5)
  /// - [review]: Review text (optional)
  /// 
  /// Stores rating in subcollection: orders/{orderId}/rating/{ratingId}
  /// Also updates status to 'completed' if not already
  Future<void> updateOrderRating({
    required String orderId,
    required int rating,
    String? review,
  }) async {
    try {
      // Store rating in subcollection
      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('rating')
          .add({
        'stars': rating,
        'comment': review?.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Also update order document with rating for quick access
      await _firestore.collection('orders').doc(orderId).update({
        'rating': rating,
        'review': review?.trim(),
        'hasRating': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Order rating updated: $orderId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating order rating: $e');
      }
      throw Exception('Failed to update order rating: $e');
    }
  }

  /// Delete order rating and review
  /// 
  /// Parameters:
  /// - [orderId]: The order document ID
  /// 
  /// Deletes all rating documents from subcollection: orders/{orderId}/rating
  /// Also removes rating fields from the main order document
  Future<void> deleteOrderRating({
    required String orderId,
  }) async {
    try {
      // Delete all rating documents from subcollection
      final ratingSnapshot = await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('rating')
          .get();

      final batch = _firestore.batch();
      for (var doc in ratingSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Remove rating fields from main order document
      await _firestore.collection('orders').doc(orderId).update({
        'rating': FieldValue.delete(),
        'review': FieldValue.delete(),
        'hasRating': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Order rating deleted: $orderId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting order rating: $e');
      }
      throw Exception('Failed to delete order rating: $e');
    }
  }

  /// Update installation scheduled date
  /// 
  /// Parameters:
  /// - [orderId]: The order document ID
  /// - [scheduledAt]: Scheduled installation date/time
  Future<void> updateInstallationSchedule({
    required String orderId,
    required DateTime scheduledAt,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'installationScheduledAt': Timestamp.fromDate(scheduledAt),
      });

      if (kDebugMode) {
        print('✅ Installation scheduled: $orderId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error scheduling installation: $e');
      }
      throw Exception('Failed to schedule installation: $e');
    }
  }

  /// Get all orders (for staff/admin)
  /// 
  /// Orders by createdAt descending for real-time updates
  /// 
  /// Returns a Stream of QuerySnapshot for real-time updates
  Stream<QuerySnapshot> getAllOrders() {
    try {
      return _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } catch (e) {
      // Fallback if orderBy fails (e.g., missing index)
      if (kDebugMode) {
        print('⚠️ OrderBy failed, using simple query: $e');
      }
      return _firestore.collection('orders').snapshots();
    }
  }

  /// Get a single order by ID
  /// 
  /// Parameters:
  /// - [orderId]: The order document ID
  /// 
  /// Returns the order document snapshot or null if not found
  Future<DocumentSnapshot?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      
      if (!doc.exists) {
        return null;
      }
      
      return doc;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching order: $e');
      }
      throw Exception('Failed to fetch order: $e');
    }
  }
}
