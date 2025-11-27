import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to check if user profile is complete before allowing orders
class ProfileCompletenessService {
  /// Check if user profile has all required information
  /// Returns a map with 'isComplete' boolean and 'missingFields' list
  static Future<Map<String, dynamic>> checkProfileCompleteness(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return {
          'isComplete': false,
          'missingFields': ['Profile not found'],
        };
      }

      final userData = userDoc.data() ?? {};
      final List<String> missingFields = [];

      // Check required fields
      final fullName = userData['fullName'] as String?;
      if (fullName == null || fullName.trim().isEmpty) {
        missingFields.add('Full Name');
      }

      final phone = userData['phone'] as String?;
      if (phone == null || phone.trim().isEmpty) {
        missingFields.add('Phone Number');
      }

      // Check if user has at least one address
      final addressesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .limit(1)
          .get();

      if (addressesSnapshot.docs.isEmpty) {
        missingFields.add('Address');
      }

      return {
        'isComplete': missingFields.isEmpty,
        'missingFields': missingFields,
      };
    } catch (e) {
      return {
        'isComplete': false,
        'missingFields': ['Error checking profile: $e'],
      };
    }
  }

  /// Get user profile data
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return null;
      }

      return userDoc.data();
    } catch (e) {
      return null;
    }
  }
}

