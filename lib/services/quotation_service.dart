import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/quotation_model.dart';
import 'notification_service.dart';
import '../utils/price_formatter.dart';

/// Quotation Service
/// 
/// Handles all quotation-related operations
class QuotationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService.instance;

  /// Create a new quotation
  /// 
  /// Automatically creates notifications for all staff
  Future<String> createQuotation({
    required String userId,
    required String message,
    String? customerName,
    String? customerEmail,
    String? productName,
    String? productImage,
    String? productPrice,
    String? glassType,
    String? aluminumType,
    double? length,
    double? width,
    String? notes,
    String? windowImageUrl,
  }) async {
    try {
      // Create quotation document
      final quotationRef = await _firestore.collection('quotations').add({
        'userId': userId,
        'message': message,
        'status': 'pending',
        'customerName': customerName,
        'customerEmail': customerEmail,
        'productName': productName,
        'productImage': productImage,
        'productPrice': productPrice,
        'glassType': glassType,
        'aluminumType': aluminumType,
        'length': length,
        'width': width,
        'notes': notes,
        'windowImageUrl': windowImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final quotationId = quotationRef.id;

      // Notify all staff about new quotation
      await _notificationService.notifyAllStaff(
        fromUserId: userId,
        message: 'New quotation request from ${customerName ?? "Customer"}',
        type: 'quotation',
        quotationId: quotationId,
      );

      // Notify all admins
      await _notificationService.notifyAllAdmins(
        fromUserId: userId,
        message: 'New quotation request from ${customerName ?? "Customer"}',
        type: 'quotation',
        quotationId: quotationId,
      );

      if (kDebugMode) {
        print('✅ Quotation created: $quotationId');
      }

      return quotationId;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating quotation: $e');
      }
      rethrow;
    }
  }

  /// Get quotations stream for staff (pending only)
  /// 
  /// Returns real-time stream of pending quotations
  Stream<QuerySnapshot> getQuotationsForStaff() {
    // Query without orderBy to avoid index requirement
    // Status can be 'Pending' or 'pending' - we'll filter in the UI
    return _firestore
        .collection('quotations')
        .snapshots();
  }

  /// Get all quotations stream for admin
  /// 
  /// Returns real-time stream of all quotations
  Stream<QuerySnapshot> getAllQuotations() {
    return _firestore
        .collection('quotations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      // Fallback to simple query if orderBy fails
      if (kDebugMode) {
        print('⚠️ OrderBy failed, using simple query: $error');
      }
      return _firestore
          .collection('quotations')
          .snapshots();
    });
  }

  /// Update quotation status
  /// 
  /// Notifies admin and customer when staff updates status
  Future<void> updateQuotationStatus({
    required String quotationId,
    required String newStatus,
    required String updatedBy, // staffId or adminId
    required String updatedByRole, // 'staff' or 'admin'
  }) async {
    try {
      final quotationRef = _firestore.collection('quotations').doc(quotationId);
      
      // Get current quotation data
      final quotationDoc = await quotationRef.get();
      if (!quotationDoc.exists) {
        throw Exception('Quotation not found');
      }

      final quotationData = quotationDoc.data() as Map<String, dynamic>;
      final userId = quotationData['userId'] as String? ?? quotationData['customerId'] as String? ?? '';

      // Update quotation
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (updatedByRole == 'staff') {
        updateData['staffId'] = updatedBy;
      } else if (updatedByRole == 'admin') {
        updateData['adminId'] = updatedBy;
      }

      await quotationRef.update(updateData);

      // Notify admin if staff updated
      if (updatedByRole == 'staff') {
        await _notificationService.notifyAllAdmins(
          fromUserId: updatedBy,
          message: 'Staff updated quotation status to $newStatus',
          type: 'quotation-update',
          quotationId: quotationId,
        );
      }

      // Notify customer
      if (userId.isNotEmpty) {
        await _notificationService.sendNotification(
          userId: userId,
          fromUserId: updatedBy,
          message: 'Your quotation status has been updated to $newStatus',
          type: 'quotation-update',
          quotationId: quotationId,
        );
      }

      if (kDebugMode) {
        print('✅ Quotation status updated: $quotationId -> $newStatus');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating quotation status: $e');
      }
      rethrow;
    }
  }

  /// Get quotation by ID
  Future<Quotation?> getQuotationById(String quotationId) async {
    try {
      final doc = await _firestore.collection('quotations').doc(quotationId).get();
      if (!doc.exists) {
        return null;
      }
      return Quotation.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting quotation: $e');
      }
      return null;
    }
  }

  /// Update quotation price and notes
  /// 
  /// Staff/admin can set estimatedPrice, priceNote, and optionally mark as done
  Future<void> updateQuotationPrice({
    required String quotationId,
    double? estimatedPrice,
    String? priceNote,
    bool markAsDone = false,
  }) async {
    try {
      final quotationRef = _firestore.collection('quotations').doc(quotationId);
      
      // Get current quotation data
      final quotationDoc = await quotationRef.get();
      if (!quotationDoc.exists) {
        throw Exception('Quotation not found');
      }

      final quotationData = quotationDoc.data() as Map<String, dynamic>;
      final customerId = quotationData['customerId'] as String? ?? 
                        quotationData['userId'] as String? ?? '';
      final productName = quotationData['productName'] as String? ?? 'your product';

      // Update quotation
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (estimatedPrice != null) {
        updateData['estimatedPrice'] = estimatedPrice;
      }

      if (priceNote != null) {
        updateData['priceNote'] = priceNote;
      }

      if (markAsDone) {
        updateData['status'] = 'done';
      }

      await quotationRef.update(updateData);

      // Send notification to customer if price is set
      if (estimatedPrice != null && customerId.isNotEmpty) {
        await _firestore.collection('notifications').add({
          'userId': customerId,
          'title': 'Quotation Ready',
          'message': 'Your quotation for $productName is ${PriceFormatter.formatPrice(estimatedPrice)}',
          'type': 'quotation_updated',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (kDebugMode) {
        print('✅ Quotation price updated: $quotationId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating quotation price: $e');
      }
      rethrow;
    }
  }

  /// Convert quotation to order
  /// 
  /// Creates a new order document from quotation data
  /// Copies all quotation fields including items array and adminTotalPrice
  /// Delivery address fields must be provided separately
  Future<String> convertQuotationToOrder(
    String quotationId, {
    required String fullName,
    required String phoneNumber,
    required String completeAddress,
    String? landmark,
    String? mapLink,
  }) async {
    try {
      // Get current authenticated user - required for Firestore rules
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to create an order');
      }
      final customerId = currentUser.uid; // Use authenticated user's UID for Firestore rule validation
      
      // Get quotation data
      final quotationDoc = await _firestore.collection('quotations').doc(quotationId).get();
      if (!quotationDoc.exists) {
        throw Exception('Quotation not found');
      }

      final quotationData = quotationDoc.data() as Map<String, dynamic>;
      
      // Verify quotation belongs to current user
      final quotationCustomerId = quotationData['customerId'] as String? ?? 
                                   quotationData['userId'] as String? ?? '';
      if (quotationCustomerId != customerId) {
        throw Exception('This quotation does not belong to you');
      }
      final customerName = quotationData['customerName'] as String? ?? 'Customer';
      final customerEmail = quotationData['customerEmail'] as String? ?? '';
      
      // Get items array from quotation (preferred) or create from quotation-level fields
      List<Map<String, dynamic>> orderItems = [];
      if (quotationData['items'] != null && quotationData['items'] is List) {
        final itemsList = quotationData['items'] as List;
        for (var item in itemsList) {
          if (item is Map<String, dynamic>) {
            orderItems.add({
              'productId': item['productId'] ?? quotationData['productId'] ?? '',
              'productName': item['productName'] ?? quotationData['productName'] ?? 'Product',
              'productImage': item['productImage'] ?? quotationData['productImage'],
              'quantity': item['quantity'] ?? 1,
              'price': (item['price'] as num?)?.toDouble() ?? 
                      (quotationData['adminTotalPrice'] as num?)?.toDouble() ?? 
                      (quotationData['estimatedPrice'] as num?)?.toDouble() ?? 0.0,
              if (item['length'] != null) 'length': item['length'],
              if (item['width'] != null) 'width': item['width'],
            });
          }
        }
      }
      
      // Fallback: create item from quotation-level fields if items array is empty
      if (orderItems.isEmpty) {
        final adminTotalPrice = (quotationData['adminTotalPrice'] as num?)?.toDouble() ?? 
                               (quotationData['estimatedPrice'] as num?)?.toDouble() ?? 0.0;
        orderItems = [
          {
            'productId': quotationData['productId'] ?? '',
            'productName': quotationData['productName'] ?? 'Product',
            'productImage': quotationData['productImage'],
            'quantity': quotationData['quantity'] ?? 1,
            'price': adminTotalPrice,
            if (quotationData['length'] != null) 'length': quotationData['length'],
            if (quotationData['width'] != null) 'width': quotationData['width'],
          },
        ];
      }
      
      // Calculate total price from items or use quotation price fields
      // Priority: price > adminTotalPrice > estimatedPrice
      double totalPrice = 0.0;
      
      // First, try to get price from quotation (the field we set when staff quotes)
      totalPrice = (quotationData['price'] as num?)?.toDouble() ?? 0.0;
      
      // If price field is not set, try adminTotalPrice
      if (totalPrice == 0.0) {
        totalPrice = (quotationData['adminTotalPrice'] as num?)?.toDouble() ?? 0.0;
      }
      
      // If still 0, try estimatedPrice
      if (totalPrice == 0.0) {
        totalPrice = (quotationData['estimatedPrice'] as num?)?.toDouble() ?? 0.0;
      }
      
      // If still 0, calculate from items array
      if (totalPrice == 0.0 && orderItems.isNotEmpty) {
        for (var item in orderItems) {
          final itemPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          totalPrice += itemPrice * quantity;
        }
      }
      
      // Ensure totalPrice is always a valid number > 0 (required by Firestore rules)
      if (totalPrice <= 0.0) {
        if (kDebugMode) {
          print('❌ Order total price is invalid: $totalPrice');
          print('   Quotation data: price=${quotationData['price']}, adminTotalPrice=${quotationData['adminTotalPrice']}, estimatedPrice=${quotationData['estimatedPrice']}');
          print('   Order items: $orderItems');
        }
        throw Exception('Order total price must be greater than zero. Please ensure the quotation has a valid price set by staff.');
      }
      
      if (kDebugMode) {
        print('✅ Order total price calculated: $totalPrice');
      }
      
      // Get other quotation fields
      // Note: Delivery address fields are NOT stored in quotations anymore
      // They will be collected during order creation
      final length = (quotationData['length'] as num?)?.toDouble();
      final width = (quotationData['width'] as num?)?.toDouble();
      final glassType = quotationData['glassType'] as String?;
      final aluminumType = quotationData['aluminumType'] as String?;
      final notes = quotationData['notes'] as String?;
      final priceNote = quotationData['priceNote'] as String?;

      // Create order document with all quotation fields
      // Status should be "pending_delivery" so staff can schedule delivery
      // Ensure totalPrice is explicitly a number (not string) for Firestore rules
      final orderData = <String, dynamic>{
        'customerId': customerId, // MUST match request.auth.uid for Firestore rules
        'customerName': customerName,
        'customerEmail': customerEmail,
        'quotationId': quotationId, // Link order to quotation
        // Product information
        if (quotationData['productId'] != null) 'productId': quotationData['productId'],
        if (quotationData['productName'] != null) 'productName': quotationData['productName'],
        'items': orderItems, // Copy items array
        'quantity': orderItems.fold<int>(0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1)),
        'totalPrice': totalPrice, // MUST be a number > 0 for Firestore rules
        'status': 'pending_delivery', // Changed to pending_delivery for delivery scheduling
        'createdAt': FieldValue.serverTimestamp(),
        // Delivery address fields (collected during order creation)
        'deliveryInfo': {
          'fullName': fullName,
          'phone': phoneNumber.toString().trim(),
          'address': completeAddress,
          if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
          if (mapLink != null && mapLink.isNotEmpty) 'mapLink': mapLink,
        },
        // Also store at top level for backward compatibility
        'fullName': fullName,
        'phoneNumber': phoneNumber.toString().trim(),
        'completeAddress': completeAddress,
        if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
        if (mapLink != null && mapLink.isNotEmpty) 'mapLink': mapLink,
        // Product details (for backward compatibility)
        if (quotationData['productId'] != null) 'productId': quotationData['productId'],
        if (quotationData['productName'] != null) 'productName': quotationData['productName'],
        if (quotationData['productImage'] != null) 'productImage': quotationData['productImage'],
        // Custom size fields
        if (length != null) 'length': length,
        if (width != null) 'width': width,
        if (glassType != null) 'glassType': glassType,
        if (aluminumType != null) 'aluminumType': aluminumType,
        if (notes != null) 'notes': notes,
        if (priceNote != null) 'priceNote': priceNote,
      };
      
      if (kDebugMode) {
        print('📦 Creating order with data:');
        print('   customerId: ${orderData['customerId']}');
        print('   totalPrice: ${orderData['totalPrice']} (type: ${orderData['totalPrice'].runtimeType})');
        print('   status: ${orderData['status']}');
        print('   items count: ${orderItems.length}');
      }
      
      // Create the order document
      final orderRef = await _firestore.collection('orders').add(orderData);

      // Try to update quotation status to "converted"
      // Note: This may fail if customer doesn't have permission to update quotations
      // But the order is already created, so we continue even if this fails
      try {
        await _firestore.collection('quotations').doc(quotationId).update({
          'status': 'converted',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) {
          print('✅ Quotation status updated to "converted"');
        }
      } catch (updateError) {
        // Quotation update failed (likely permission issue), but order was created successfully
        // Log the error but don't fail the entire operation
        if (kDebugMode) {
          print('⚠️ Could not update quotation status (order was created successfully): $updateError');
          print('   This is expected if customer does not have permission to update quotations.');
          print('   Staff/admin can manually update the quotation status later.');
        }
      }

      if (kDebugMode) {
        print('✅ Quotation converted to order: $quotationId -> ${orderRef.id}');
      }

      return orderRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error converting quotation to order: $e');
      }
      rethrow;
    }
  }

  /// Get customer quotations
  /// 
  /// Returns real-time stream of quotations for a specific customer
  Stream<QuerySnapshot> getCustomerQuotations(String customerId) {
    return _firestore
        .collection('quotations')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      // Fallback to simple query if orderBy fails
      if (kDebugMode) {
        print('⚠️ OrderBy failed, using simple query: $error');
      }
      return _firestore
          .collection('quotations')
          .where('customerId', isEqualTo: customerId)
          .snapshots();
    });
  }

  /// Update quotation with admin-set prices
  /// 
  /// Updates items array with prices and sets adminTotalPrice
  /// Sets status to "quoted" and notifies customer
  Future<void> updateQuotationWithAdminPrices({
    required String quotationId,
    required List<Map<String, dynamic>> items, // Items with updated prices
    required double adminTotalPrice,
    String? updatedBy, // adminId or staffId
    String? updatedByRole, // 'admin' or 'staff'
  }) async {
    try {
      final quotationRef = _firestore.collection('quotations').doc(quotationId);
      
      // Get current quotation data
      final quotationDoc = await quotationRef.get();
      if (!quotationDoc.exists) {
        throw Exception('Quotation not found');
      }

      final quotationData = quotationDoc.data() as Map<String, dynamic>;
      final customerId = quotationData['customerId'] as String? ?? 
                        quotationData['userId'] as String? ?? '';
      final productName = quotationData['productName'] as String? ?? 'your product';

      // Update quotation prices only - do NOT change status
      // Status should only be changed via Approve/Reject buttons
      final updateData = <String, dynamic>{
        'items': items,
        'adminTotalPrice': adminTotalPrice,
        'price': adminTotalPrice, // Also set "price" field as specified
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (updatedByRole == 'staff' && updatedBy != null) {
        updateData['staffId'] = updatedBy;
      } else if (updatedByRole == 'admin' && updatedBy != null) {
        updateData['adminId'] = updatedBy;
      }

      await quotationRef.update(updateData);

      // Send notification to customer
      if (customerId.isNotEmpty) {
        await _firestore.collection('notifications').add({
          'userId': customerId,
          'title': 'Your quotation is ready!',
          'message': 'Total amount for $productName: ${PriceFormatter.formatPrice(adminTotalPrice)}',
          'type': 'quotation_ready',
          'quotationId': quotationId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      if (kDebugMode) {
        print('✅ Quotation prices updated: $quotationId -> ${PriceFormatter.formatPrice(adminTotalPrice)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating quotation prices: $e');
      }
      rethrow;
    }
  }
}

