import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Service for managing user roles via Cloud Functions
///
/// **IMPORTANT:** Make sure to run `flutter pub get` to install the `cloud_functions` package.
///
/// This service calls the setUserRole Cloud Function which:
/// 1. Sets custom claims in Firebase Auth
/// 2. Updates the Firestore user document
class RoleService {
  /// Assign a role to a user (admin, staff, or customer)
  ///
  /// This function requires:
  /// - The caller must be authenticated
  /// - The caller must have admin role (checked by Cloud Function)
  ///
  /// Parameters:
  /// - [uid]: The user ID to assign the role to
  /// - [role]: The role to assign ('admin', 'staff', or 'customer')
  ///
  /// Returns:
  /// - Map with 'success' (bool) and 'message' (String)
  ///
  /// Throws:
  /// - FirebaseFunctionsException if authentication/permission fails
  /// - Exception for other errors
  static Future<Map<String, dynamic>> assignUserRole(
    String uid,
    String role,
  ) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('setUserRole');

      final result = await callable.call({'uid': uid, 'role': role});

      if (kDebugMode) {
        print('✅ Role assignment result: ${result.data}');
      }

      return result.data as Map<String, dynamic>;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('❌ Cloud Function error: ${e.code} - ${e.message}');
        print('   Details: ${e.details}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error assigning role: $e');
      }
      throw Exception('Failed to assign role: $e');
    }
  }

  /// Helper method to assign admin role
  static Future<void> assignAdminRole(String uid) async {
    await assignUserRole(uid, 'admin');
  }

  /// Helper method to assign staff role
  static Future<void> assignStaffRole(String uid) async {
    await assignUserRole(uid, 'staff');
  }

  /// Helper method to assign customer role
  static Future<void> assignCustomerRole(String uid) async {
    await assignUserRole(uid, 'customer');
  }
}
