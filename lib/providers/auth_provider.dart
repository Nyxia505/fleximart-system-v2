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
    // Log logout activity before signing out
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get user info for logging
        String? userName = _displayName;
        String? userId = user.uid;
        
        // If we don't have display name, try to get it from Firestore
        if (userName == null || userName.isEmpty) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              userName = (userData?['name'] as String?) ??
                  (userData?['fullName'] as String?) ??
                  (userData?['customerName'] as String?) ??
                  (userData?['email'] as String?) ??
                  user.email ??
                  'Unknown User';
            } else {
              userName = user.email ?? 'Unknown User';
            }
          } catch (e) {
            debugPrint('⚠️ Error getting user name for logout log: $e');
            userName = user.email ?? 'Unknown User';
          }
        }
        
        // Log the logout activity
        await FirebaseFirestore.instance.collection('activity_logs').add({
          'userId': userId,
          'userName': userName,
          'actionType': 'Logout',
          'description': 'User logged out',
          'timestamp': FieldValue.serverTimestamp(),
          'metadata': {
            'role': _role ?? 'unknown',
            'logoutTime': DateTime.now().toIso8601String(),
          },
        });
        
        if (kDebugMode) {
          debugPrint('✅ Logout activity logged for: $userName');
        }
      }
    } catch (e) {
      // Don't fail logout if activity logging fails
      if (kDebugMode) {
        debugPrint('⚠️ Error logging logout activity: $e');
      }
    }
    
    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();
  }
}
