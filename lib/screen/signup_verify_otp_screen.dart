import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/email_verification_service.dart';
import '../constants/app_colors.dart';
import '../services/otp_popup_service.dart';

class SignupVerifyOtpScreen extends StatefulWidget {
  final String email;
  final String fullName;
  final String password;

  const SignupVerifyOtpScreen({
    super.key,
    required this.email,
    required this.fullName,
    required this.password,
  });

  static Route routeFromArgs(Object? args) {
    final map = (args is Map) ? args : <String, dynamic>{};
    return MaterialPageRoute(
      builder: (_) => SignupVerifyOtpScreen(
        email: map['email']?.toString() ?? '',
        fullName: map['fullName']?.toString() ?? '',
        password: map['password']?.toString() ?? '',
      ),
    );
  }

  @override
  State<SignupVerifyOtpScreen> createState() => _SignupVerifyOtpScreenState();
}

class _SignupVerifyOtpScreenState extends State<SignupVerifyOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _resending = false;

  // Color scheme matching the design - Red theme
  static const Color _primaryRed = Color(0xFFCD5656);
  static const Color _inactiveBorder = Color(0xFFE8D0D0);
  static const Color _textColor = Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    // Auto-focus the first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
      // Setup OTP popup listener
      _setupOtpPopup();
    });
  }

  void _setupOtpPopup() {
    // Set callback to auto-fill OTP when received
    OtpPopupService.instance.onOtpReceived = (otpCode) {
      _fillOtpCode(otpCode);
    };

    // Listen for OTP notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (data['type'] == 'otp_verification' && mounted) {
        final otpCode = data['otp'] as String?;
        final email = data['email'] as String? ?? '';
        if (otpCode != null && otpCode.isNotEmpty) {
          OtpPopupService.instance.showOtpPopup(context, otpCode, email);
        }
      }
    });

    // Listen for when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      if (data['type'] == 'otp_verification' && mounted) {
        final otpCode = data['otp'] as String?;
        final email = data['email'] as String? ?? '';
        if (otpCode != null && otpCode.isNotEmpty) {
          OtpPopupService.instance.showOtpPopup(context, otpCode, email);
        }
      }
    });
  }

  void _fillOtpCode(String code) {
    if (code.length != 6) return;
    
    for (int i = 0; i < 6 && i < _controllers.length; i++) {
      _controllers[i].text = code[i];
    }
    
    // Move focus to last field and trigger verification
    _focusNodes[5].requestFocus();
    // Auto-verify after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_loading) {
        _verify();
      }
    });
  }

  @override
  void dispose() {
    // Clear OTP callback
    OtpPopupService.instance.onOtpReceived = null;
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged(int index, String value) {
    if (value.length == 1) {
      // Move to next field
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last field filled, verify automatically (only if not already loading)
        if (!_loading) {
          _focusNodes[index].unfocus();
          _verify();
        }
      }
    } else if (value.isEmpty && index > 0) {
      // Move to previous field on backspace
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _getCode() {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _verify() async {
    // Prevent multiple simultaneous verification attempts
    if (_loading) return;

    final code = _getCode();

    // Frontend validation: Check if code is complete
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit code'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Frontend validation: Check if code contains only digits
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code must contain only numbers'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _clearAllFields();
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // Verify code using EmailVerificationService
      final isValid = await EmailVerificationService.verifyCode(
        email: widget.email,
        code: code,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Verification timeout. Please check your connection and try again.');
        },
      );

      if (!isValid) {
        throw Exception('Verification failed. Please try again.');
      }

      // OTP verified successfully, now create the Firebase account
      if (!mounted) return;

      // Create user account in Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: widget.email,
            password: widget.password,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Account creation timeout. Please try again.');
            },
          );

      final user = credential.user;
      if (user == null) throw Exception('Failed to create user account');

      // Store user data in Firestore with verified status
      final userData = {
        'fullName': widget.fullName,
        'email': widget.email,
        'role': 'customer',
        'emailVerified': true,
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'profileImageUrl': '', // Profile picture feature coming soon
        'phoneNumber': '',
        'address': '',
      };
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(userData).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Failed to save user data. Please try again.');
        },
      );
      
      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully! You can now sign in.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Sign out and navigate to login after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;

      // Extract error message
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (errorMessage.isEmpty) {
        errorMessage = 'Invalid or expired code. Please try again.';
      }

      // Handle Firebase Auth errors
      if (e is FirebaseAuthException) {
        if (e.code == 'email-already-in-use') {
          errorMessage =
              'An account already exists with this email. Please sign in instead.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'The password is too weak';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Invalid email address';
        }
      }

      // Clear all input fields on error
      _clearAllFields();

      // Show error message with proper styling
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Resend',
            textColor: Colors.white,
            onPressed: () {
              _resend();
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearAllFields() {
    for (var controller in _controllers) {
      controller.clear();
    }
    // Focus back on first field
    _focusNodes[0].requestFocus();
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      // Clear current OTP fields
      _clearAllFields();

      // Request new verification code via EmailVerificationService
      await EmailVerificationService.requestEmailVerification(
        email: widget.email,
        displayName: widget.fullName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification code has been sent to your email and push notification.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (errorMessage.isEmpty) {
        errorMessage = 'Failed to resend code. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        title: const Text(
          'Verify Email',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // White card container
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header text - Bold red
                    const Text(
                      'Enter 6-digit verification code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _primaryRed,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Email text - Smaller grey
                    Text(
                      'Sent to ${widget.email}\nAlso check your push notifications',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Six square input fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return _buildCodeField(index);
                      }),
                    ),
                    const SizedBox(height: 32),
                    // Verify button - Large red button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Verify & Create Account'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Resend code link - Red text
                    TextButton(
                      onPressed: _resending ? null : _resend,
                      style: TextButton.styleFrom(
                        foregroundColor: _primaryRed,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: _resending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primaryRed,
                              ),
                            )
                          : const Text(
                              'Resend Code',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeField(int index) {
    final isFocused = _focusNodes[index].hasFocus;
    final hasValue = _controllers[index].text.isNotEmpty;

    return SizedBox(
      width: 52,
      height: 52,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        cursorColor: _primaryRed,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: _textColor,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isFocused || hasValue ? _primaryRed : _inactiveBorder,
              width: isFocused ? 2 : 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: hasValue ? _primaryRed : _inactiveBorder,
              width: hasValue ? 2 : 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _primaryRed, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) => _onCodeChanged(index, value),
        onTap: () {
          // Select all text when tapping on a field
          _controllers[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controllers[index].text.length,
          );
        },
      ),
    );
  }
}
