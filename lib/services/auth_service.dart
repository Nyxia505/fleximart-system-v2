import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/auth_user_profile.dart';
import 'activity_log_service.dart';

/// Firebase Authentication + Firestore profile + Gmail verification helpers.
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// User-friendly messages for Firebase Auth errors.
  static String messageForAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Please sign in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters with mixed case and numbers.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Contact support.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  /// Creates Firebase account, saves Firestore profile, sends verification email.
  static Future<UserCredential> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Account creation failed.',
      );
    }

    try {
      await user.updateDisplayName(fullName.trim());
    } catch (e) {
      if (kDebugMode) debugPrint('updateDisplayName: $e');
    }

    final profile = AuthUserProfile(
      uid: user.uid,
      fullName: fullName.trim(),
      email: normalizedEmail,
      role: 'customer',
      emailVerified: false,
    );

    await _firestore.collection('users').doc(user.uid).set({
      ...profile.toFirestoreMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await ActivityLogService().logRegister(
      userId: user.uid,
      userName: fullName.trim(),
      email: normalizedEmail,
      role: 'customer',
    );

    await sendVerificationEmail(user);
    return credential;
  }

  /// Signs in with email/password. Caller should check [isEmailVerified] for customers.
  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  /// Sends Firebase verification link to the user's Gmail inbox.
  static Future<void> sendVerificationEmail([User? user]) async {
    final target = user ?? _auth.currentUser;
    if (target == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'You must be signed in to send a verification email.',
      );
    }
    await target.sendEmailVerification();
  }

  /// Reloads the Firebase user and returns whether email is verified.
  static Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    await user.reload();
    final refreshed = _auth.currentUser;
    final verified = refreshed?.emailVerified ?? false;

    if (verified && refreshed != null) {
      await markEmailVerifiedInFirestore(refreshed.uid);
    }
    return verified;
  }

  static Future<bool> isEmailVerified() async {
    return reloadAndCheckEmailVerified();
  }

  static Future<void> markEmailVerifiedInFirestore(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'emailVerified': true,
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('markEmailVerifiedInFirestore: $e');
    }
  }

  /// Reads role from Firestore `/users/{uid}`.
  static Future<String?> getUserRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final role = doc.data()?['role'];
    return role?.toString().toLowerCase().trim();
  }

  static Future<AuthUserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AuthUserProfile.fromFirestore(uid, doc.data()!);
  }

  static Future<void> signOut() => _auth.signOut();
}
