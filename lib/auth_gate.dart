import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'providers/auth_provider.dart' as app_auth;
import 'utils/fcm_utils.dart';
import 'screen/welcome_back_screen.dart';
import 'admin/admin_dashboard.dart';
import 'staff/staff_dashboard.dart';
import 'customer/customer_dashboard.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();

    // Show loading while auth is loading
    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If user is logged in, check verification status before allowing dashboard access
    if (auth.user != null) {
      return _CheckVerificationStatus(
        key: const ValueKey('check_verification'),
        user: auth.user!,
        role: auth.role ?? 'customer',
      );
    }

    // If user is not logged in, show Welcome Back screen first
    return const WelcomeBackScreen();
  }
}

class _CheckVerificationStatus extends StatefulWidget {
  final dynamic user;
  final String role;

  const _CheckVerificationStatus({
    super.key,
    required this.user,
    required this.role,
  });

  @override
  State<_CheckVerificationStatus> createState() => _CheckVerificationStatusState();
}

class _CheckVerificationStatusState extends State<_CheckVerificationStatus> {
  bool _isCheckingVerification = true;
  String? _actualRole; // Role from Firestore /users/{uid}
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkRoleAndVerification();
  }

  Future<void> _checkRoleAndVerification() async {
    try {
      // STEP 1: Read role from Firestore /users/{uid} FIRST
      final uid = widget.user.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        if (mounted) {
          setState(() {
            _isCheckingVerification = false;
            _errorMessage = 'Your account has no assigned role. Please contact admin.';
          });
        }
        return;
      }

      final userData = doc.data() ?? {};
      _actualRole = userData['role'] as String?;

      // If role is null, show error
      if (_actualRole == null) {
        if (mounted) {
          setState(() {
            _isCheckingVerification = false;
            _errorMessage = 'Your account has no assigned role. Please contact admin.';
          });
        }
        return;
      }

      // STEP 2: Admin and Staff can access immediately
      if (_actualRole == 'admin' || _actualRole == 'staff') {
        if (mounted) {
          setState(() {
            _isCheckingVerification = false;
          });
        }
        // Save/update FCM token on successful login
        await saveFcmToken();
        return;
      }

      // STEP 3: For customers, if user exists in Firestore, allow access directly
      // Email verification is only required during sign-up, not during login
      if (_actualRole == 'customer') {
        // User exists in Firestore (Gmail is saved) - allow access directly
        if (mounted) {
          setState(() {
            _isCheckingVerification = false;
          });
        }
        // Save/update FCM token on successful login
        await saveFcmToken();
        return;
      }

      // Unknown role
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking role and verification: $e');
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
          _errorMessage = 'Error checking permissions: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingVerification) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Get effective role (null = customer)
    final effectiveRole = _actualRole ?? 'customer';

    // Show error ONLY if trying to access admin/staff dashboard without proper role
    // This should not happen here since dashboards check roles themselves, but keep as safety
    if (_errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
                  child: const Text('Return to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Email verification is only required during sign-up, not during login
    // If user exists in Firestore, they can log in directly
    // No need to check verification status for existing users

    // Route based on effective role (null = customer)
    if (effectiveRole == 'admin') {
      return const AdminDashboard();
    }
    if (effectiveRole == 'staff') {
      return const StaffDashboard();
    }
    // Default to customer dashboard (including null role)
    return const CustomerDashboard();
  }
}
