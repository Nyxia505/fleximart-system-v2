import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'email_service.dart';
import 'otp_push_notification_service.dart';

class EmailVerificationService {
  EmailVerificationService._();

  static const String _otpKeyPrefix = 'email_verif:'; // <email>:otp
  static const String _expKeySuffix = ':exp';
  static const String _verifiedKeySuffix = ':verified';
  static const String _lastSentKeySuffix = ':last_sent';

  static String _otpKey(String email) => '$_otpKeyPrefix$email:otp';
  static String _expKey(String email) => '$_otpKeyPrefix$email$_expKeySuffix';
  static String _verifiedKey(String email) => '$_otpKeyPrefix$email$_verifiedKeySuffix';
  static String _lastSentKey(String email) => '$_otpKeyPrefix$email$_lastSentKeySuffix';

  /// Generate a numeric OTP of [length] digits.
  static String generateOtp({int length = 6}) {
    final rand = Random.secure();
    final max = pow(10, length).toInt();
    final min = pow(10, length - 1).toInt();
    final value = min + rand.nextInt(max - min);
    return value.toString().padLeft(length, '0');
  }

  /// Request a verification code to be sent to [email]. Returns the OTP for debug/testing only.
  /// - [displayName] is optional and used in the email template if provided.
  /// - [ttlMinutes] sets how long the OTP is valid for (default: 5 minutes to match email template).
  /// - [resendCooldownSeconds] prevents rapid re-sends.
  static Future<String> requestEmailVerification({
    required String email,
    String? displayName,
    int length = 6,
    int ttlMinutes = 5,
    int resendCooldownSeconds = 45,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastSent = prefs.getInt(_lastSentKey(email)) ?? 0;
    if (nowMs - lastSent < resendCooldownSeconds * 1000) {
      final secondsLeft = ((resendCooldownSeconds * 1000 - (nowMs - lastSent)) / 1000).ceil();
      throw Exception('Please wait $secondsLeft seconds before requesting a new code.');
    }

    final otp = generateOtp(length: length);
    final expiryMs = nowMs + ttlMinutes * 60 * 1000;

    await prefs.setString(_otpKey(email), otp);
    await prefs.setInt(_expKey(email), expiryMs);
    await prefs.setInt(_lastSentKey(email), nowMs);

    // Send OTP via email
    await EmailService.sendOtpEmail(
      toEmail: email,
      otpCode: otp,
      toName: displayName,
    );

    // Also send OTP via push notification (falls back silently if FCM token unavailable)
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await OtpPushNotificationService.sendOtpPushNotification(
        email: email,
        otpCode: otp,
        displayName: displayName,
        userId: currentUser?.uid,
      );
    } catch (e) {
      // Silently fail - email is already sent as primary method
      // Push notification is just a convenience feature
    }

    return otp; // Useful for QA; avoid exposing in production UIs/logs.
  }

  /// Verify the [code] received via email. Returns true if accepted.
  /// Throws an exception with a descriptive message if verification fails.
  static Future<bool> verifyCode({
    required String email,
    required String code,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storedOtp = prefs.getString(_otpKey(email));
    final expiryMs = prefs.getInt(_expKey(email)) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Validate code format
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw Exception('Please enter a valid 6-digit code');
    }

    // Check if OTP exists
    if (storedOtp == null) {
      throw Exception('No verification code found. Please request a new code.');
    }

    // Check if OTP has expired
    if (nowMs > expiryMs) {
      // Clear expired OTP
      await prefs.remove(_otpKey(email));
      await prefs.remove(_expKey(email));
      throw Exception('Verification code has expired. Please request a new code.');
    }

    // Check if code matches
    if (storedOtp != code) {
      throw Exception('Invalid verification code. Please try again.');
    }

    // Code is valid, mark as verified
    await prefs.setBool(_verifiedKey(email), true);
    // Clear OTP after success
    await prefs.remove(_otpKey(email));
    await prefs.remove(_expKey(email));
    return true;
  }

  /// Check if the given email has already been verified on this device (local cache).
  static Future<bool> isVerified(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_verifiedKey(email)) ?? false;
  }

  /// Check if the email is verified in Firestore (source of truth).
  /// This checks the users collection for the email and returns true if isVerified or emailVerified is true.
  static Future<bool> isEmailVerifiedInFirestore(String email) async {
    try {
      // Query Firestore for user with this email
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return false; // User doesn't exist yet
      }

      final userData = querySnapshot.docs.first.data();
      final isVerified = userData['isVerified'] as bool? ?? false;
      final emailVerified = userData['emailVerified'] as bool? ?? false;
      
      return isVerified || emailVerified;
    } catch (e) {
      // If there's an error, assume not verified to be safe
      return false;
    }
  }

  /// Check if a user by UID is verified in Firestore.
  static Future<bool> isUserVerifiedInFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        return false;
      }

      final userData = doc.data() ?? {};
      final isVerified = userData['isVerified'] as bool? ?? false;
      final emailVerified = userData['emailVerified'] as bool? ?? false;
      
      return isVerified || emailVerified;
    } catch (e) {
      return false;
    }
  }

  /// Clear verification state for an email (e.g., logout or change email).
  static Future<void> clear(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_verifiedKey(email));
    await prefs.remove(_otpKey(email));
    await prefs.remove(_expKey(email));
    await prefs.remove(_lastSentKey(email));
  }
}


