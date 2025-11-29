import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Phone Verification Service
///
/// Handles Firebase Phone Authentication OTP verification
class PhoneVerificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _verificationId;

  /// Send OTP to phone number
  ///
  /// Returns true if OTP was sent successfully
  /// Throws exception on error
  ///
  /// Note: For Android, if Play Integrity fails, Firebase will automatically
  /// fall back to reCAPTCHA which may open a browser. This is expected behavior.
  /// The user needs to complete the reCAPTCHA in the browser and return to the app.
  Future<bool> sendOtp({
    required String phoneNumber,
    Function(String verificationId)? onCodeSent,
    Function(String error)? onError,
  }) async {
    try {
      // Format phone number (ensure it starts with +)
      String formattedPhone = phoneNumber.trim();
      if (!formattedPhone.startsWith('+')) {
        // Assume Philippines (+63) if no country code
        if (formattedPhone.startsWith('0')) {
          formattedPhone = '+63${formattedPhone.substring(1)}';
        } else {
          formattedPhone = '+63$formattedPhone';
        }
      }

      // Validate phone number format
      if (formattedPhone.length < 10 ||
          !RegExp(r'^\+\d{10,15}$').hasMatch(formattedPhone)) {
        final errorMsg =
            'Invalid phone number format. Please enter a valid phone number.';
        onError?.call(errorMsg);
        return false;
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        // For Android: Firebase will try SMS Retriever API first (automatic verification)
        // If that fails (Play Integrity issue), it falls back to reCAPTCHA
        // For web: Firebase automatically handles reCAPTCHA verification
        // Make sure reCAPTCHA is enabled in Firebase Console for your domain
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-verification completed (Android only)
          // This happens when SMS Retriever API successfully verifies the code
        },
        verificationFailed: (FirebaseAuthException e) {
          String errorMessage = 'Failed to send OTP';
          final errorMsg = e.message ?? '';
          final errorCode = e.code;

          // Check for blocked/rate limit errors first
          if (errorMsg.contains('blocked') ||
              errorMsg.contains('unusual activity') ||
              errorMsg.contains('Try again later') ||
              errorCode == 'too-many-requests') {
            errorMessage =
                'Too many verification attempts.\n\n'
                'Your device has been temporarily blocked due to unusual activity.\n'
                'Please wait 15-30 minutes before trying again.\n\n'
                'If this persists, try:\n'
                '• Restarting the app\n'
                '• Using a different network connection\n'
                '• Contacting support if the issue continues';
          } else if (e.code == 'invalid-phone-number') {
            errorMessage =
                'Invalid phone number format. Please check and try again.';
          } else if (e.code == 'quota-exceeded') {
            errorMessage = 'SMS quota exceeded. Please try again later.';
          } else if (e.code == 'missing-phone-number') {
            errorMessage = 'Phone number is required.';
          } else if (e.code == 'invalid-verification-code') {
            errorMessage = 'Invalid verification code.';
          } else if (e.code == 'session-expired') {
            errorMessage =
                'Verification session expired. Please request a new code.';
          } else if (e.code == 'missing-app-credential' ||
              e.code == 'invalid-app-credential' ||
              e.code == '17010' || // reCAPTCHA error code
              errorMsg.contains('reCAPTCHA') ||
              errorMsg.contains('Recaptcha') ||
              errorMsg.contains('RecaptchaEnterprise') ||
              errorMsg.contains('siteKey') ||
              errorMsg.contains('application verifier') ||
              errorMsg.contains('reCAPTCHA token') ||
              errorMsg.contains('PlayIntegrity') ||
              errorMsg.contains('Play Store') ||
              errorMsg.contains('not Recognized')) {
            // reCAPTCHA or Play Integrity related errors
            // Check if it's actually a block error disguised as reCAPTCHA
            if (errorMsg.contains('blocked') ||
                errorMsg.contains('unusual activity')) {
              errorMessage =
                  'Too many verification attempts.\n\n'
                  'Please wait 15-30 minutes before trying again.';
            } else if (kIsWeb) {
              errorMessage =
                  'reCAPTCHA verification failed. Please ensure:\n'
                  '1. Your domain is authorized in Firebase Console\n'
                  '2. Phone authentication is enabled\n'
                  '3. Refresh the page and try again';
            } else {
              // For Android: Play Integrity failed, Firebase will use reCAPTCHA
              // The browser will open for reCAPTCHA - this is normal
              // User needs to complete reCAPTCHA and return to app
              errorMessage =
                  'Security verification required.\n\n'
                  'A browser window will open for security verification.\n'
                  'Please complete the verification and return to the app.\n\n'
                  'If no browser opens, please try again.';
            }
          } else {
            errorMessage = errorMsg.isNotEmpty
                ? errorMsg
                : 'Failed to send OTP. Please try again.';
          }

          onError?.call(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          // resendToken can be used for resending OTP in the future
          onCodeSent?.call(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );

      return true;
    } catch (e) {
      String errorMsg = 'An error occurred while sending OTP.';
      if (e is FirebaseAuthException) {
        final errorMessage = e.message ?? '';

        // Check for blocked/rate limit errors
        if (e.code == 'too-many-requests' ||
            errorMessage.contains('blocked') ||
            errorMessage.contains('unusual activity') ||
            errorMessage.contains('Try again later')) {
          errorMsg =
              'Too many verification attempts.\n\n'
              'Please wait 15-30 minutes before trying again.';
        } else if (e.code == 'invalid-phone-number') {
          errorMsg = 'Invalid phone number format.';
        } else if (e.code == '17010' ||
            errorMessage.contains('reCAPTCHA') ||
            errorMessage.contains('RecaptchaEnterprise') ||
            errorMessage.contains('PlayIntegrity')) {
          // Check if it's actually a block error
          if (errorMessage.contains('blocked') ||
              errorMessage.contains('unusual activity')) {
            errorMsg =
                'Too many verification attempts.\n\n'
                'Please wait 15-30 minutes before trying again.';
          } else {
            errorMsg =
                'Security verification required. '
                'A browser may open for verification. Please complete it and return to the app.';
          }
        } else {
          errorMsg = errorMessage.isNotEmpty ? errorMessage : errorMsg;
        }
      } else {
        errorMsg = e.toString();
      }

      onError?.call(errorMsg);
      return false;
    }
  }

  /// Verify OTP code
  ///
  /// Returns PhoneAuthCredential if verification is successful
  /// Throws exception on error
  Future<PhoneAuthCredential> verifyOtp({
    required String smsCode,
    String? verificationId,
  }) async {
    try {
      // Validate OTP code format
      final code = smsCode.trim();
      if (code.isEmpty) {
        throw Exception('Please enter the verification code.');
      }
      if (code.length != 6) {
        throw Exception('Verification code must be 6 digits.');
      }
      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
        throw Exception('Verification code must contain only numbers.');
      }

      final vId = verificationId ?? _verificationId;
      if (vId == null || vId.isEmpty) {
        throw Exception('No verification ID found. Please request a new OTP.');
      }

      // Create credential - this will be verified when we use it
      final credential = PhoneAuthProvider.credential(
        verificationId: vId,
        smsCode: code,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Verification failed';

      if (e.code == 'invalid-verification-code') {
        errorMessage = 'Invalid verification code. Please check and try again.';
      } else if (e.code == 'session-expired') {
        errorMessage =
            'Verification session expired. Please request a new code.';
      } else if (e.code == 'invalid-verification-id') {
        errorMessage =
            'Invalid verification session. Please request a new OTP.';
      } else if (e.code == 'code-expired') {
        errorMessage =
            'Verification code has expired. Please request a new code.';
      } else {
        errorMessage = e.message ?? 'Verification failed. Please try again.';
      }

      throw Exception(errorMessage);
    } catch (e) {
      // Re-throw if it's already our formatted exception
      if (e.toString().contains('Please enter') ||
          e.toString().contains('must be') ||
          e.toString().contains('No verification ID')) {
        rethrow;
      }
      throw Exception('Verification failed: ${e.toString()}');
    }
  }

  /// Verify and sign in with phone credential
  ///
  /// This should be called after verifyOtp() succeeds
  /// Uses signInWithCredential for phone authentication sign-in
  /// If user is already logged in, links the credential instead
  /// Returns the user's UID after successful verification
  Future<String> verifyAndSignIn({
    required PhoneAuthCredential credential,
  }) async {
    try {
      final currentUser = _auth.currentUser;

      // If user is already logged in, link the credential
      if (currentUser != null) {
        try {
          await currentUser.linkWithCredential(credential);
          return currentUser.uid;
        } on FirebaseAuthException catch (e) {
          String errorMessage = 'Failed to verify phone number';

          if (e.code == 'invalid-verification-code') {
            errorMessage = 'Invalid verification code. Please try again.';
          } else if (e.code == 'credential-already-in-use') {
            errorMessage = 'This phone number is already in use.';
          } else if (e.code == 'provider-already-linked') {
            // Phone provider already linked - this is fine, continue
            return currentUser.uid;
          } else if (e.code == 'session-expired') {
            errorMessage =
                'Verification session expired. Please request a new code.';
          } else {
            errorMessage = e.message ?? 'Failed to verify phone number.';
          }

          if (e.code != 'provider-already-linked') {
            throw Exception(errorMessage);
          }
          return currentUser.uid;
        }
      } else {
        // No user logged in - sign in with phone credential
        final userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user == null) {
          throw Exception('Sign-in failed. Please try again.');
        }
        return user.uid;
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Verification failed';

      if (e.code == 'invalid-verification-code') {
        errorMessage = 'Invalid verification code. Please check and try again.';
      } else if (e.code == 'session-expired') {
        errorMessage =
            'Verification session expired. Please request a new code.';
      } else if (e.code == 'code-expired') {
        errorMessage =
            'Verification code has expired. Please request a new code.';
      } else if (e.code == 'invalid-verification-id') {
        errorMessage =
            'Invalid verification session. Please request a new OTP.';
      } else {
        errorMessage = e.message ?? 'Verification failed. Please try again.';
      }

      throw Exception(errorMessage);
    }
  }

  /// Save verified phone number to Firestore
  ///
  /// This should be called after signInWithPhoneCredential() succeeds
  Future<void> saveVerifiedPhone({
    required String uid,
    required String phoneNumber,
  }) async {
    // Format phone number for storage
    String formattedPhone = phoneNumber.trim();
    if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '+63${formattedPhone.substring(1)}';
      } else {
        formattedPhone = '+63$formattedPhone';
      }
    }

    try {
      // Save to Firestore with phoneNumber field name (as specified by user)
      await _firestore.collection('users').doc(uid).update({
        'phoneNumber': formattedPhone,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // If it's a Firestore error, re-throw with better message
      if (e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('permission')) {
        throw Exception(
          'Permission denied. Please check your Firestore security rules.',
        );
      }
      throw Exception('Failed to save phone verification: ${e.toString()}');
    }
  }

  /// Check if user's phone is verified
  static Future<bool> isPhoneVerified(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      return (data?['phoneVerified'] as bool?) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get user's verified phone number
  static Future<String?> getVerifiedPhone(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      // Support both 'phoneNumber' and 'phone' for backward compatibility
      return data?['phoneNumber'] as String? ?? data?['phone'] as String?;
    } catch (e) {
      return null;
    }
  }
}
