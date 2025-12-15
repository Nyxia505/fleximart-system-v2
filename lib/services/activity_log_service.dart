import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for logging user activities to Firestore
class ActivityLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log a user activity
  /// 
  /// Parameters:
  /// - [userId]: The user's UID
  /// - [userName]: The user's name
  /// - [actionType]: Type of action (e.g., 'Login', 'Logout', 'Register')
  /// - [description]: Description of the activity
  /// - [metadata]: Optional additional data
  Future<void> logActivity({
    required String userId,
    required String userName,
    required String actionType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('activity_logs').add({
        'userId': userId,
        'userName': userName,
        'actionType': actionType,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        if (metadata != null) 'metadata': metadata,
      });

      if (kDebugMode) {
        debugPrint('✅ Activity logged: $actionType - $userName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error logging activity: $e');
      }
      // Don't throw - activity logging should not break the main flow
    }
  }

  /// Log a login activity
  Future<void> logLogin(String userId, String userName) async {
    await logActivity(
      userId: userId,
      userName: userName,
      actionType: 'Login',
      description: 'User logged in',
      metadata: {
        'loginTime': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log a logout activity
  Future<void> logLogout(String userId, String userName) async {
    await logActivity(
      userId: userId,
      userName: userName,
      actionType: 'Logout',
      description: 'User logged out',
      metadata: {
        'logoutTime': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log a product update activity
  Future<void> logProductUpdate({
    required String userId,
    required String userName,
    required String productId,
    required String productName,
    String? fieldChanged,
    String? oldValue,
    String? newValue,
  }) async {
    String description = 'Updated product: $productName';
    if (fieldChanged != null) {
      description = 'Updated $productName - $fieldChanged';
      if (oldValue != null && newValue != null) {
        description = 'Updated $productName - $fieldChanged: $oldValue → $newValue';
      }
    }
    
    await logActivity(
      userId: userId,
      userName: userName,
      actionType: 'Product Update',
      description: description,
      metadata: {
        'productId': productId,
        'productName': productName,
        if (fieldChanged != null) 'fieldChanged': fieldChanged,
        if (oldValue != null) 'oldValue': oldValue,
        if (newValue != null) 'newValue': newValue,
      },
    );
  }

  /// Log a product creation activity
  Future<void> logProductCreate({
    required String userId,
    required String userName,
    required String productId,
    required String productName,
  }) async {
    await logActivity(
      userId: userId,
      userName: userName,
      actionType: 'Product Create',
      description: 'Created new product: $productName',
      metadata: {
        'productId': productId,
        'productName': productName,
      },
    );
  }

  /// Log a product deletion activity
  Future<void> logProductDelete({
    required String userId,
    required String userName,
    required String productId,
    required String productName,
  }) async {
    await logActivity(
      userId: userId,
      userName: userName,
      actionType: 'Product Delete',
      description: 'Deleted product: $productName',
      metadata: {
        'productId': productId,
        'productName': productName,
      },
    );
  }

  /// Log a user modification activity
  Future<void> logUserUpdate({
    required String userId,
    required String userName,
    required String targetUserId,
    required String targetUserName,
    String? fieldChanged,
    String? oldValue,
    String? newValue,
  }) async {
    String description = 'Updated user: $targetUserName';
    if (fieldChanged != null) {
      description = 'Updated $targetUserName - $fieldChanged';
      if (oldValue != null && newValue != null) {
        description = 'Updated $targetUserName - $fieldChanged: $oldValue → $newValue';
      }
    }
    
    await logActivity(
      userId: userId,
      userName: userName,
      actionType: 'User Update',
      description: description,
      metadata: {
        'targetUserId': targetUserId,
        'targetUserName': targetUserName,
        if (fieldChanged != null) 'fieldChanged': fieldChanged,
        if (oldValue != null) 'oldValue': oldValue,
        if (newValue != null) 'newValue': newValue,
      },
    );
  }

  /// Log an order status change activity
  Future<void> logOrderStatusChange({
    required String userId,
    required String userName,
    required String orderId,
    required String oldStatus,
    required String newStatus,
    String? customerName,
  }) async {
    await logActivity(
      userId: userId,
      userName: userName,
      actionType: 'Order Status Change',
      description: 'Order status changed: $oldStatus → $newStatus${customerName != null ? ' (Customer: $customerName)' : ''}',
      metadata: {
        'orderId': orderId,
        'oldStatus': oldStatus,
        'newStatus': newStatus,
        if (customerName != null) 'customerName': customerName,
      },
    );
  }
}

