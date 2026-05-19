import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'fcm_signup_service.dart';
import 'notification_service.dart';
import 'otp_popup_service.dart';

/// Sends OTP via FCM push and/or local device notification.
class OtpPushNotificationService {
  OtpPushNotificationService._();

  static Future<bool> _ensurePermission() async {
    if (kIsWeb) return true;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ FCM permission request failed: $e');
      }
      return false;
    }
  }

  static Future<bool> _showLocalOtp(String otpCode, String email) async {
    if (kIsWeb) return false;
    try {
      await NotificationService.instance.init();
      await NotificationService.instance.showOtpVerificationNotification(
        otpCode: otpCode,
        email: email,
      );
      OtpPopupService.instance.onOtpReceived?.call(otpCode);
      if (kDebugMode) {
        debugPrint('✅ OTP local notification shown');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Local OTP notification failed: $e');
      }
      return false;
    }
  }

  /// Returns true if OTP reached the device (FCM and/or notification tray).
  static Future<bool> sendOtpPushNotification({
    required String email,
    required String otpCode,
    String? displayName,
    String? userId,
    String? fcmToken,
  }) async {
    var delivered = false;

    try {
      if (!kIsWeb) {
        await _ensurePermission();
        // Always show in notification tray first so user gets the code on device
        delivered = await _showLocalOtp(otpCode, email);
      }

      var token = fcmToken;

      if (userId != null && (token == null || token.isEmpty)) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            token = userDoc.data()?['fcmToken'] as String?;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Could not get FCM token from users doc: $e');
          }
        }
      }

      if (token == null || token.isEmpty) {
        token = await FcmSignupService.loadTokenForEmail(email);
      }

      if (token == null || token.isEmpty) {
        try {
          token = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Could not get FCM token: $e');
          }
        }
      }

      if (token != null && token.isNotEmpty) {
        try {
          await _sendOtpViaCloudFunction(
            fcmToken: token,
            otpCode: otpCode,
            email: email,
            displayName: displayName,
          );
          if (kDebugMode) {
            debugPrint('✅ OTP push sent via Cloud Function');
          }
          delivered = true;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Cloud Function push failed (local may still work): $e');
          }
        }
      }

      return delivered;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ sendOtpPushNotification: $e');
      }
      return delivered;
    }
  }

  static Future<void> _sendOtpViaCloudFunction({
    required String fcmToken,
    required String otpCode,
    required String email,
    String? displayName,
  }) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('sendOtpNotification');

    await callable.call({
      'fcmToken': fcmToken,
      'otpCode': otpCode,
      'email': email,
      'displayName': displayName,
    }).timeout(const Duration(seconds: 15));
  }
}
