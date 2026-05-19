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
import 'services/email_verification_service.dart';

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
  State<_CheckVerificationStatus> createState() =>
      _CheckVerificationStatusState();
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
            _errorMessage =
                'Your account has no assigned role. Please contact admin.';
          });
        }
        return;
      }

      final userData = doc.data() ?? {};
      final rawRole = userData['role'] as String?;
      _actualRole = rawRole?.toLowerCase().trim();
      if (_actualRole != null && _actualRole!.isEmpty) _actualRole = null;

      // If role is null, show error
      if (_actualRole == null) {
        if (mounted) {
          setState(() {
            _isCheckingVerification = false;
            _errorMessage =
                'Your account has no assigned role. Please contact admin.';
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

      // STEP 3: Customers — use Firestore OTP verification flags (not Firebase link emailVerified)
      if (_actualRole == 'customer') {
        final otpVerified =
            await EmailVerificationService.isUserVerifiedInFirestore(uid);
        if (!otpVerified) {
          if (mounted) {
            setState(() {
              _isCheckingVerification = false;
              _errorMessage =
                  'Your account is not verified yet. Complete sign-up with the OTP sent to your email, or contact support.';
            });
          }
          return;
        }
        if (mounted) {
          setState(() {
            _isCheckingVerification = false;
          });
        }
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
                const SizedBox(height: 8),
                Text(
                  'If an admin just assigned you a role, tap Retry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        setState(() {
                          _isCheckingVerification = true;
                          _errorMessage = null;
                          _actualRole = null;
                        });
                        await _checkRoleAndVerification();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(width: 16),
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
              ],
            ),
          ),
        ),
      );
    }

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
