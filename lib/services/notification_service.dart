import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/price_formatter.dart';

/// Notification Service
///
/// Handles:
/// - Local notifications via `flutter_local_notifications`
/// - High-importance channel configuration
/// - Firestore-based in-app notifications (existing logic)
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize local notifications and create high importance channel.
  Future<void> init() async {
    if (_initialized || kIsWeb) return; // flutter_local_notifications not needed on web

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await _flutterLocalNotificationsPlugin.initialize(initSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'Important notifications for FlexiMart',
      importance: Importance.high,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Configure Firebase Messaging listeners for foreground notifications.
  Future<void> configureFirebaseMessaging() async {
    if (kIsWeb) {
      // Web relies on browser push; in-app we can still show SnackBars elsewhere if needed.
      return;
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await showRemoteNotification(message);
    });

    // Optionally handle when app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Notification clicked: ${message.messageId}');
      // Navigation can be added here if needed.
    });
  }

  /// Show a local notification for a received RemoteMessage.
  Future<void> showRemoteNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    await init();

    final notification = message.notification;
    final android = notification?.android;

    final title = notification?.title ??
        (message.data['title'] as String? ?? 'FlexiMart');
    final body = notification?.body ??
        (message.data['body'] as String? ?? 'You have a new notification');

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Important notifications for FlexiMart',
      importance: Importance.high,
      priority: Priority.high,
      icon: android?.smallIcon ?? '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      title,
      body,
      details,
      payload: message.data['route'],
    );
  }

  /// Send notification to a specific user
  Future<void> sendNotification({
    required String userId,
    required String? fromUserId,
    required String message,
    required String type,
    String? quotationId,
    String? title,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'fromUserId': fromUserId,
        'message': message,
        'type': type,
        'quotationId': quotationId,
        'read': false,
        'title': title,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Notification sent to user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending notification: $e');
      }
      rethrow;
    }
  }

  /// Notify all staff members
  Future<void> notifyAllStaff({
    required String? fromUserId,
    required String message,
    required String type,
    String? quotationId,
    String? title,
  }) async {
    try {
      final staffSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'staff')
          .get();

      if (staffSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No staff members found');
        }
        return;
      }

      final batch = _firestore.batch();

      for (var staffDoc in staffSnapshot.docs) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': staffDoc.id,
          'fromUserId': fromUserId,
          'message': message,
          'type': type,
          'quotationId': quotationId,
          'read': false,
          'title': title ?? 'New Quotation Request',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (kDebugMode) {
        print('✅ Notifications sent to ${staffSnapshot.docs.length} staff members');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error notifying staff: $e');
      }
      rethrow;
    }
  }

  /// Notify all admin users
  Future<void> notifyAllAdmins({
    required String? fromUserId,
    required String message,
    required String type,
    String? quotationId,
    String? title,
  }) async {
    try {
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      if (adminSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No admin users found');
        }
        return;
      }

      final batch = _firestore.batch();

      for (var adminDoc in adminSnapshot.docs) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': adminDoc.id,
          'fromUserId': fromUserId,
          'message': message,
          'type': type,
          'quotationId': quotationId,
          'read': false,
          'title': title ?? 'New Quotation Request',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (kDebugMode) {
        print('✅ Notifications sent to ${adminSnapshot.docs.length} admins');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error notifying admins: $e');
      }
      rethrow;
    }
  }

  /// Get notifications stream for a specific user
  /// 
  /// Returns real-time stream of notifications
  Stream<QuerySnapshot> getNotificationsForUser(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      // Fallback to simple query if orderBy fails
      if (kDebugMode) {
        print('⚠️ OrderBy failed, using simple query: $error');
      }
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots();
    });
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking notification as read: $e');
      }
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      if (notifications.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking all notifications as read: $e');
      }
    }
  }

  /// Get unread notification count
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Delete a notification
  /// 
  /// Parameters:
  /// - [notificationId]: The notification document ID to delete
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      if (kDebugMode) {
        print('✅ Notification deleted: $notificationId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting notification: $e');
      }
      rethrow;
    }
  }

  /// Delete all notifications for a user
  /// 
  /// Parameters:
  /// - [userId]: The user ID whose notifications should be deleted
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      if (notifications.docs.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No notifications to delete for user: $userId');
        }
        return;
      }

      final batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (kDebugMode) {
        print('✅ Deleted ${notifications.docs.length} notifications for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting all notifications: $e');
      }
      rethrow;
    }
  }

  /// Create order notification
  /// 
  /// Parameters:
  /// - [userId]: Recipient user ID
  /// - [title]: Notification title
  /// - [message]: Notification message
  /// - [type]: Notification type (new_order, order_paid, order_shipped, order_received, order_completed)
  /// - [orderId]: Optional order ID for reference
  Future<void> createOrderNotification({
    required String userId,
    required String title,
    required String message,
    required String type, // new_order, order_paid, order_shipped, order_received, order_completed
    String? orderId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        if (orderId != null) 'orderId': orderId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Order notification created: $type for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating order notification: $e');
      }
      rethrow;
    }
  }

  /// Notify customer when order status changes
  /// 
  /// Parameters:
  /// - [customerId]: Customer user ID
  /// - [orderId]: Order document ID
  /// - [orderData]: Order data map (for extracting customer name, total, etc.)
  /// - [newStatus]: New order status
  Future<void> notifyOrderStatusChange({
    required String customerId,
    required String orderId,
    required Map<String, dynamic> orderData,
    required String newStatus,
  }) async {
    try {
      // Fetch productName from order data
      String? productName;
      if (orderData['productName'] != null) {
        productName = orderData['productName'] as String?;
      } else if (orderData['items'] != null) {
        final items = orderData['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final firstItem = items[0] as Map<String, dynamic>?;
          productName = firstItem?['productName'] as String?;
        }
      }
      // Fallback to a generic name if productName is not found
      final displayProductName = productName ?? 'order';

      String title;
      String message;
      String type;

      // Map status to notification details
      switch (newStatus.toLowerCase()) {
        case 'paid':
        case 'pending_payment':
          title = 'Payment Received';
          message = 'Your order $displayProductName payment has been received. We are preparing your order.';
          type = 'order_paid';
          break;
        case 'shipped':
        case 'for_installation':
          title = 'Order Shipped';
          message = 'Your order $displayProductName has been shipped. Track your delivery.';
          type = 'order_shipped';
          break;
        case 'awaiting_installation':
        case 'awaiting installation':
        case 'to_receive':
          title = 'Order Received';
          message = 'Your order $displayProductName has been received. Installation will be scheduled soon.';
          type = 'order_received';
          break;
        case 'processing':
          title = 'Order Status Updated';
          message = 'Your order $displayProductName is now processing.';
          type = 'order_status';
          break;
        case 'completed':
          title = 'Order Completed';
          message = 'Your order $displayProductName has been completed. Thank you for your purchase!';
          type = 'order_completed';
          break;
        case 'delivered':
          title = 'Order Delivered';
          message = 'Your $displayProductName has been delivered.';
          type = 'order_completed';
          break;
        default:
          // Generic notification for any other status
          title = 'Order Status Updated';
          message = 'Your order $displayProductName is now ${newStatus}.';
          type = 'order_status';
      }

      await createOrderNotification(
        userId: customerId,
        title: title,
        message: message,
        type: type,
        orderId: orderId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error notifying order status change: $e');
      }
    }
  }

  /// Notify staff/admin when new order is created
  /// 
  /// Parameters:
  /// - [orderId]: Order document ID
  /// - [orderData]: Order data map
  /// - [notifyStaff]: Whether to notify staff (default: true)
  /// - [notifyAdmin]: Whether to notify admin (default: true)
  Future<void> notifyNewOrder({
    required String orderId,
    required Map<String, dynamic> orderData,
    bool notifyStaff = true,
    bool notifyAdmin = true,
  }) async {
    try {
      final customerName = orderData['customerName'] as String? ?? 'Customer';
      final totalPrice = (orderData['totalPrice'] as num?)?.toDouble() ??
          (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final orderShortId = orderId.substring(0, 8).toUpperCase();

      final title = 'New Order Received';
      final message = 'Order #$orderShortId from $customerName - ${PriceFormatter.formatPrice(totalPrice)}';
      final type = 'new_order';

      final batch = _firestore.batch();

      if (notifyStaff) {
        final staffSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'staff')
            .get();

        for (var staffDoc in staffSnapshot.docs) {
          final notificationRef = _firestore.collection('notifications').doc();
          batch.set(notificationRef, {
            'userId': staffDoc.id,
            'title': title,
            'message': message,
            'type': type,
            'orderId': orderId,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (notifyAdmin) {
        final adminSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();

        for (var adminDoc in adminSnapshot.docs) {
          final notificationRef = _firestore.collection('notifications').doc();
          batch.set(notificationRef, {
            'userId': adminDoc.id,
            'title': title,
            'message': message,
            'type': type,
            'orderId': orderId,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (kDebugMode) {
        print('✅ New order notifications created for order: $orderId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error notifying new order: $e');
      }
    }
  }
}

