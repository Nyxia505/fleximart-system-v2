import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider();

  User? _firebaseUser;
  String? _displayName;
  String? _role; // admin | staff | customer
  bool _loading = false;

  User? get user => _firebaseUser;
  String? get displayName => _displayName;
  String? get role => _role;
  bool get isLoading => _loading;

  void initialize() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      _firebaseUser = user;
      if (user == null) {
        _displayName = null;
        _role = null;
        notifyListeners();
        return;
      }
      await _loadProfile(user.uid);
    });
  }

  Future<void> _loadProfile(String uid) async {
    _loading = true;
    notifyListeners();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _loading = false;
        notifyListeners();
        return;
      }

      // Reload user to get fresh emailVerified status
      try {
        await user.reload();
        _firebaseUser = FirebaseAuth.instance.currentUser;
      } catch (e) {
        debugPrint('⚠️ Error reloading user: $e');
        // Continue with current user if reload fails
      }

      // Get role from Firestore /users/{uid} document
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        
        if (snap.exists) {
          final data = snap.data() ?? const {};
          
          // Read role from Firestore
          _role = data['role'] as String?;
          
          // Load display name from Firestore
          _displayName =
              (data['name'] as String?) ??
              (data['fullName'] as String?) ??
              (data['customerName'] as String?) ??
              user.email;
        } else {
          // User document doesn't exist
          _role = null;
          _displayName = user.email;
          debugPrint('⚠️ User document not found in Firestore');
        }
      } catch (e) {
        debugPrint('⚠️ Error loading profile from Firestore: $e');
        _role = null;
        _displayName = user.email;
      }
      
      debugPrint('✅ Profile loaded - Role: $_role, Name: $_displayName');
      
      if (_role == null) {
        debugPrint('ℹ️ INFO: User role is null in Firestore');
      }
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _loadProfile(user.uid);
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
