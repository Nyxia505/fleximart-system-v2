import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Service for sending OTP via push notifications
/// 
/// This service sends OTP codes via Firebase Cloud Messaging push notifications
/// so users don't need to check their email.
class OtpPushNotificationService {
  OtpPushNotificationService._();
  static final OtpPushNotificationService instance = OtpPushNotificationService._();

  /// Send OTP via push notification
  /// 
  /// Tries to send OTP to the user's device via push notification.
  /// Falls back silently if FCM token is not available.
  /// 
  /// Parameters:
  /// - [email]: User's email address
  /// - [otpCode]: The OTP code to send
  /// - [displayName]: Optional user display name
  /// - [userId]: Optional user ID if user is already authenticated
  static Future<void> sendOtpPushNotification({
    required String email,
    required String otpCode,
    String? displayName,
    String? userId,
  }) async {
    try {
      String? fcmToken;

      // Try to get FCM token from authenticated user's Firestore document
      if (userId != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data();
            fcmToken = userData?['fcmToken'] as String?;
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not get FCM token from Firestore: $e');
          }
        }
      }

      // If no token from Firestore, try to get it from the device
      // This works even if user is not logged in yet (during signup)
      if (fcmToken == null || fcmToken.isEmpty) {
        try {
          final messaging = FirebaseMessaging.instance;
          fcmToken = await messaging.getToken();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not get FCM token from device: $e');
          }
        }
      }

      // If still no token, silently fail (user will receive OTP via email)
      if (fcmToken == null || fcmToken.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No FCM token available, skipping push notification. OTP sent via email only.');
        }
        return;
      }

      // Send push notification via Cloud Function
      await _sendOtpViaCloudFunction(
        fcmToken: fcmToken,
        otpCode: otpCode,
        email: email,
        displayName: displayName,
      );

      if (kDebugMode) {
        print('✅ OTP push notification sent successfully');
      }
    } catch (e) {
      // Silently fail - email is still sent as fallback
      if (kDebugMode) {
        print('⚠️ Failed to send OTP push notification: $e');
      }
    }
  }

  /// Call Cloud Function to send OTP notification
  static Future<void> _sendOtpViaCloudFunction({
    required String fcmToken,
    required String otpCode,
    required String email,
    String? displayName,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendOtpNotification');
      
      final result = await callable.call({
        'fcmToken': fcmToken,
        'otpCode': otpCode,
        'email': email,
        'displayName': displayName,
      }).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('✅ OTP notification sent via Cloud Function: ${result.data}');
      }
    } catch (e) {
      // If Cloud Function doesn't exist or fails, that's okay
      // Email is still sent as fallback
      if (kDebugMode) {
        print('⚠️ Cloud Function call failed (this is okay, email is still sent): $e');
      }
      rethrow;
    }
  }
}

