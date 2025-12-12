import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
}

