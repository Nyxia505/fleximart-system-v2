import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Helper class for managing user roles from Firestore
/// Reads role from /users/{uid} document, NOT from custom claims
class RoleHelper {
  RoleHelper._();

  /// Get user role from Firestore /users/{uid} document
  /// Returns null if role is not set or user is not authenticated
  static Future<String?> getUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ No authenticated user');
        return null;
      }

      // Read role from Firestore /users/{uid}
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        debugPrint('⚠️ User document not found in Firestore');
        return null;
      }

      final userData = doc.data();
      final role = userData?['role'] as String?;
      
      debugPrint('✅ User role from Firestore: $role');
      return role;
    } catch (e) {
      debugPrint('❌ Error getting user role from Firestore: $e');
      return null;
    }
  }

  /// Check if user is admin
  static Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }

  /// Check if user is staff
  static Future<bool> isStaff() async {
    final role = await getUserRole();
    return role == 'staff';
  }

  /// Check if user is customer
  static Future<bool> isCustomer() async {
    final role = await getUserRole();
    return role == 'customer' || role == null;
  }

  /// Validate user has required role, throw exception if not
  static Future<void> requireRole(String requiredRole) async {
    final role = await getUserRole();
    if (role != requiredRole) {
      throw Exception(
        'Access denied. Required role: $requiredRole, but user role is: ${role ?? "null"}',
      );
    }
  }
}
