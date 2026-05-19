import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'email_service.dart';
import 'otp_push_notification_service.dart';

class EmailVerificationService {
  EmailVerificationService._();

  static const String _otpKeyPrefix = 'email_verif:';
  static const String _expKeySuffix = ':exp';
  static const String _verifiedKeySuffix = ':verified';
  static const String _lastSentKeySuffix = ':last_sent';

  static String _otpKey(String email) => '$_otpKeyPrefix$email:otp';
  static String _expKey(String email) => '$_otpKeyPrefix$email$_expKeySuffix';
  static String _verifiedKey(String email) =>
      '$_otpKeyPrefix$email$_verifiedKeySuffix';
  static String _lastSentKey(String email) =>
      '$_otpKeyPrefix$email$_lastSentKeySuffix';

  static String _normalizeEmail(String email) =>
      email.toLowerCase().trim();

  static String generateOtp({int length = 6}) {
    final rand = Random.secure();
    final max = pow(10, length).toInt();
    final min = pow(10, length - 1).toInt();
    final value = min + rand.nextInt(max - min);
    return value.toString().padLeft(length, '0');
  }

  static Future<void> _persistOtpLocally(
    SharedPreferences prefs,
    String email,
    String otp,
    int expiryMs,
    int nowMs,
  ) async {
    await prefs.setString(_otpKey(email), otp);
    await prefs.setInt(_expKey(email), expiryMs);
    await prefs.setInt(_lastSentKey(email), nowMs);
  }

  static Future<String?> _persistOtpFirestore(
    String email,
    String otp,
    int expiryMs, {
    String? displayName,
  }) async {
    try {
      final normalized = _normalizeEmail(email);
      final ref = await FirebaseFirestore.instance
          .collection('otp_verifications')
          .add({
        'userId': normalized,
        'toEmail': normalized,
        'displayName': displayName ?? normalized.split('@').first,
        'otpCode': otp,
        'expiresAt': Timestamp.fromMillisecondsSinceEpoch(expiryMs),
        'used': false,
        'emailSent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Could not save OTP to Firestore: $e');
      }
      return null;
    }
  }

  /// Waits for Cloud Function [onOtpVerificationCreated] to send email via SMTP.
  static Future<bool> _waitForServerEmail(String docId) async {
    final docRef =
        FirebaseFirestore.instance.collection('otp_verifications').doc(docId);
    for (var i = 0; i < 12; i++) {
      await Future.delayed(const Duration(milliseconds: 750));
      final snap = await docRef.get();
      if (!snap.exists) continue;
      final data = snap.data() ?? {};
      if (data['emailSent'] == true) {
        if (kDebugMode) {
          debugPrint('✅ OTP email sent by server (${data['emailMethod']})');
        }
        return true;
      }
      final err = data['emailError'] as String?;
      if (data['emailSent'] == false && err != null && err.isNotEmpty) {
        if (kDebugMode) debugPrint('⚠️ Server email failed: $err');
        return false;
      }
    }
    return false;
  }

  static Future<String> requestEmailVerification({
    required String email,
    String? displayName,
    int length = 6,
    int ttlMinutes = 5,
    int resendCooldownSeconds = 45,
  }) async {
    final normalized = _normalizeEmail(email);
    await clearStaleOtpVerifications(normalized);
    final prefs = await SharedPreferences.getInstance();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastSent = prefs.getInt(_lastSentKey(normalized)) ?? 0;
    if (nowMs - lastSent < resendCooldownSeconds * 1000) {
      final secondsLeft =
          ((resendCooldownSeconds * 1000 - (nowMs - lastSent)) / 1000)
              .ceil();
      throw Exception(
        'Please wait $secondsLeft seconds before requesting a new code.',
      );
    }

    final otp = generateOtp(length: length);
    final expiryMs = nowMs + ttlMinutes * 60 * 1000;

    // Save OTP first so resend/verify can proceed even if email delivery fails
    await _persistOtpLocally(prefs, normalized, otp, expiryMs, nowMs);
    final otpDocId = await _persistOtpFirestore(
      normalized,
      otp,
      expiryMs,
      displayName: displayName,
    );

    if (otpDocId != null && await _waitForServerEmail(otpDocId)) {
      return otp;
    }

    try {
      await EmailService.sendOtpEmail(
        toEmail: normalized,
        otpCode: otp,
        toName: displayName,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Email send failed (OTP saved locally): $e');
      }
      rethrow;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await OtpPushNotificationService.sendOtpPushNotification(
        email: normalized,
        otpCode: otp,
        displayName: displayName,
        userId: currentUser?.uid,
      );
    } catch (_) {}

    return otp;
  }

  static Future<bool> verifyCode({
    required String email,
    required String code,
  }) async {
    final normalized = _normalizeEmail(email);
    final prefs = await SharedPreferences.getInstance();
    final storedOtp = prefs.getString(_otpKey(normalized));
    final expiryMs = prefs.getInt(_expKey(normalized)) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw Exception('Please enter a valid 6-digit code');
    }

    if (storedOtp != null) {
      if (nowMs > expiryMs) {
        await prefs.remove(_otpKey(normalized));
        await prefs.remove(_expKey(normalized));
        throw Exception(
          'Verification code has expired. Please request a new code.',
        );
      }
      if (storedOtp == code) {
        await prefs.setBool(_verifiedKey(normalized), true);
        await prefs.remove(_otpKey(normalized));
        await prefs.remove(_expKey(normalized));
        await _markFirestoreOtpUsed(normalized, code);
        return true;
      }
    }

    // Firestore fallback (e.g. different device or prefs cleared)
    final ok = await _verifyFromFirestore(normalized, code, nowMs);
    if (ok) {
      await prefs.setBool(_verifiedKey(normalized), true);
      return true;
    }

    if (storedOtp == null) {
      throw Exception('No verification code found. Please request a new code.');
    }
    throw Exception('Invalid verification code. Please try again.');
  }

  static Future<bool> _verifyFromFirestore(
    String email,
    String code,
    int nowMs,
  ) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('otp_verifications')
          .where('userId', isEqualTo: email)
          .where('otpCode', isEqualTo: code)
          .where('used', isEqualTo: false)
          .limit(5)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final expiresAt = data['expiresAt'];
        if (expiresAt is Timestamp) {
          if (expiresAt.millisecondsSinceEpoch < nowMs) continue;
        }
        await doc.reference.update({
          'used': true,
          'usedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ΓÜá∩╕Å Firestore OTP verify fallback: $e');
      }
      return false;
    }
  }

  static Future<void> _markFirestoreOtpUsed(String email, String code) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('otp_verifications')
          .where('userId', isEqualTo: email)
          .where('otpCode', isEqualTo: code)
          .where('used', isEqualTo: false)
          .limit(5)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({
          'used': true,
          'usedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  static Future<bool> isVerified(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_verifiedKey(_normalizeEmail(email))) ?? false;
  }

  /// Active signup: only block re-registration when explicitly verified in Firestore.
  static bool isActiveVerifiedSignup(Map<String, dynamic> data) {
    return data['isVerified'] == true || data['emailVerified'] == true;
  }

  /// Clears verification flags on old [users] docs with the same email (keeps [keepUid]).
  /// Requires signed-in owner or admin rules for each doc; failures are ignored.
  static Future<void> clearStaleUserDocsForEmail(
    String email, {
    required String keepUid,
  }) async {
    final normalized = _normalizeEmail(email);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: normalized)
          .get();
      for (final doc in snap.docs) {
        if (doc.id == keepUid) continue;
        try {
          await doc.reference.update({
            'isVerified': false,
            'emailVerified': false,
          });
          if (kDebugMode) {
            debugPrint(
              '🧹 Cleared stale verification flags on users/${doc.id} for $normalized',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              '⚠️ Could not update stale users/${doc.id} (needs admin delete in Console): $e',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('clearStaleUserDocsForEmail: $e');
    }
  }

  /// Returns true if any Firestore [users] doc for this email is a verified account.
  static Future<bool> hasActiveVerifiedAccount(String email) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _normalizeEmail(email))
          .limit(10)
          .get();
      for (final doc in snap.docs) {
        if (isActiveVerifiedSignup(doc.data())) return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('hasActiveVerifiedAccount: $e');
      return false;
    }
  }

  /// Removes old OTP rows before sending a new code (e.g. after user was deleted).
  static Future<void> clearStaleOtpVerifications(String email) async {
    final normalized = _normalizeEmail(email);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('otp_verifications')
          .where('userId', isEqualTo: normalized)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
      if (kDebugMode && snap.docs.isNotEmpty) {
        debugPrint(
          '🧹 Cleared ${snap.docs.length} stale otp_verifications for $normalized',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('clearStaleOtpVerifications: $e');
    }
  }

  static Future<bool> isEmailVerifiedInFirestore(String email) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _normalizeEmail(email))
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return false;

      final userData = querySnapshot.docs.first.data();
      final isVerified = userData['isVerified'] as bool? ?? false;
      final emailVerified = userData['emailVerified'] as bool? ?? false;

      return isVerified || emailVerified;
    } catch (e) {
      return false;
    }
  }

  /// True when OTP signup completed or legacy user (flags absent).
  static bool isCustomerVerifiedFromDoc(Map<String, dynamic> data) {
    if (data['isVerified'] == true || data['emailVerified'] == true) {
      return true;
    }
    // Legacy accounts before OTP flags were stored
    if (!data.containsKey('isVerified') && !data.containsKey('emailVerified')) {
      return true;
    }
    return false;
  }

  static Future<bool> isUserVerifiedInFirestore(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      return isCustomerVerifiedFromDoc(doc.data() ?? {});
    } catch (e) {
      return false;
    }
  }

  static Future<void> clear(String email) async {
    final normalized = _normalizeEmail(email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_verifiedKey(normalized));
    await prefs.remove(_otpKey(normalized));
    await prefs.remove(_expKey(normalized));
    await prefs.remove(_lastSentKey(normalized));
  }
}
