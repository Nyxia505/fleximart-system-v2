import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;

/// Registers the device FCM token before signup so OTP push can be delivered.
class FcmSignupService {
  FcmSignupService._();

  static String _normalizeEmail(String email) => email.toLowerCase().trim();

  /// Request notification permission and save token to Firestore for this email.
  /// Call before sending the verification OTP.
  static Future<String?> prepareForSignup(String email) async {
    if (kIsWeb) {
      if (kDebugMode) {
        debugPrint('ℹ️ FCM signup prep skipped on web');
      }
      return null;
    }

    final normalized = _normalizeEmail(email);
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!allowed && kDebugMode) {
        debugPrint('⚠️ Notification permission not granted for signup OTP');
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ No FCM token available during signup prep');
        }
        return null;
      }

      await FirebaseFirestore.instance
          .collection('pending_signup')
          .doc(normalized)
          .set({
        'email': normalized,
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('✅ FCM token saved for signup: $normalized');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ FcmSignupService.prepareForSignup failed: $e');
      }
      return null;
    }
  }

  /// Loads token saved during signup prep (if device token fetch fails later).
  static Future<String?> loadTokenForEmail(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('pending_signup')
          .doc(_normalizeEmail(email))
          .get();
      if (!doc.exists) return null;
      final token = doc.data()?['fcmToken'] as String?;
      return (token != null && token.isNotEmpty) ? token : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Could not load pending_signup token: $e');
      }
      return null;
    }
  }
}
