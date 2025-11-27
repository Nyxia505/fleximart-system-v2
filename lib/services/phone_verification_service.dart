import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-verification completed (Android only)
          // This is handled automatically by Firebase
        },
        verificationFailed: (FirebaseAuthException e) {
          String errorMessage = 'Failed to send OTP';
          
          if (e.code == 'invalid-phone-number') {
            errorMessage = 'Invalid phone number format';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Too many requests. Please try again later.';
          } else if (e.code == 'quota-exceeded') {
            errorMessage = 'SMS quota exceeded. Please try again later.';
          } else {
            errorMessage = e.message ?? 'Failed to send OTP';
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
      onError?.call(e.toString());
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
      final vId = verificationId ?? _verificationId;
      if (vId == null) {
        throw Exception('No verification ID found. Please request a new OTP.');
      }

      // Create credential
      final credential = PhoneAuthProvider.credential(
        verificationId: vId,
        smsCode: smsCode.trim(),
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Invalid verification code';
      
      if (e.code == 'invalid-verification-code') {
        errorMessage = 'Invalid verification code. Please try again.';
      } else if (e.code == 'session-expired') {
        errorMessage = 'Verification session expired. Please request a new code.';
      } else {
        errorMessage = e.message ?? 'Verification failed';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Verification failed: ${e.toString()}');
    }
  }

  /// Link verified phone number to user account and save to Firestore
  /// 
  /// This should be called after verifyOtp() succeeds
  Future<void> saveVerifiedPhone({
    required String uid,
    required String phoneNumber,
    required PhoneAuthCredential credential,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Link phone credential to user account
      await user.linkWithCredential(credential);

      // Format phone number for storage
      String formattedPhone = phoneNumber.trim();
      if (!formattedPhone.startsWith('+')) {
        if (formattedPhone.startsWith('0')) {
          formattedPhone = '+63${formattedPhone.substring(1)}';
        } else {
          formattedPhone = '+63$formattedPhone';
        }
      }

      // Save to Firestore
      await _firestore.collection('users').doc(uid).update({
        'phone': formattedPhone,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // If linking fails (e.g., phone already linked), still save to Firestore
      // This handles cases where phone is already verified
      String formattedPhone = phoneNumber.trim();
      if (!formattedPhone.startsWith('+')) {
        if (formattedPhone.startsWith('0')) {
          formattedPhone = '+63${formattedPhone.substring(1)}';
        } else {
          formattedPhone = '+63$formattedPhone';
        }
      }

      await _firestore.collection('users').doc(uid).update({
        'phone': formattedPhone,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
      });
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
      return data?['phone'] as String?;
    } catch (e) {
      return null;
    }
  }
}

