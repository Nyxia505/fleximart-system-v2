import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../constants/app_colors.dart';
import '../services/email_verification_service.dart';
import '../services/otp_popup_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String? fullName;
  const VerifyEmailScreen({
    super.key,
    required this.uid,
    required this.email,
    this.fullName,
  });

  static Route routeFromArgs(Object? args) {
    final map = (args is Map) ? args : <String, dynamic>{};
    return MaterialPageRoute(
      builder: (_) => VerifyEmailScreen(
        uid: map['uid']?.toString() ?? '',
        email: map['email']?.toString() ?? '',
        fullName: map['fullName']?.toString(),
      ),
    );
  }

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );
  bool _loading = false;
  bool _resending = false;

  // Verification code color scheme matching the design
  static const Color _primaryBlue = Color(0xFF3366FF);
  static const Color _inactiveBorder = Color(0xFFD9E0FF);
  static const Color _textColor = Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    // Auto-focus the first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
      // Check authentication status
      _checkAuthStatus();
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
      _verify();
    });
  }
  
  void _checkAuthStatus() {
    final currentUser = FirebaseAuth.instance.currentUser;
    debugPrint('=== Verification Screen Auth Status ===');
    debugPrint('Current User: ${currentUser?.uid}');
    debugPrint('Expected UID: ${widget.uid}');
    debugPrint('User Email: ${currentUser?.email}');
    debugPrint('Is Authenticated: ${currentUser != null}');
    debugPrint('UID Match: ${currentUser?.uid == widget.uid}');
    debugPrint('=====================================');
    
    if (currentUser == null) {
      // Show warning that user is not authenticated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warning: Not authenticated. Verification may fail.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }
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
        // Last field filled, verify automatically
        _focusNodes[index].unfocus();
        _verify();
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

    setState(() => _loading = true);
    try {
      // Verify code using EmailVerificationService (backend validation)
      final isValid = await EmailVerificationService.verifyCode(
        email: widget.email,
        code: code,
      );

      if (!isValid) {
        throw Exception('Verification failed. Please try again.');
      }

      // CRITICAL: Update Firestore to mark email as verified in database
      // This is the source of truth for login verification checks
      bool dbUpdateSuccess = false;
      
      // IMPORTANT: Check if user is authenticated
      // Firestore rules require authentication to update user document
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != widget.uid) {
        debugPrint('User not authenticated or UID mismatch. Current: ${currentUser?.uid}, Expected: ${widget.uid}');
        throw Exception('Authentication required. Please sign in again and verify your email.');
      }
      
      try {
        // First, check if document exists
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid);
        
        final docSnapshot = await docRef.get();
        
        if (!docSnapshot.exists) {
          // Document doesn't exist - create it with verification status
          await docRef.set({
            'email': widget.email,
            'emailVerified': true,
            'isVerified': true,
            'verifiedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          dbUpdateSuccess = true;
        } else {
          // Document exists - update it
          // Use set with merge to avoid 400 errors if document structure is different
          try {
            await docRef.set({
              'emailVerified': true,
              'isVerified': true,
              'verifiedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            dbUpdateSuccess = true;
          } catch (e) {
            // If set with merge fails, try update
            try {
              await docRef.update({
                'emailVerified': true,
                'isVerified': true,
                'verifiedAt': FieldValue.serverTimestamp(),
              });
              dbUpdateSuccess = true;
            } catch (e2) {
              // If update also fails, try without verifiedAt
              try {
                await docRef.set({
                  'emailVerified': true,
                  'isVerified': true,
                }, SetOptions(merge: true));
                dbUpdateSuccess = true;
              } catch (e3) {
                // Last resort: try update without verifiedAt
                await docRef.update({
                  'emailVerified': true,
                  'isVerified': true,
                });
                dbUpdateSuccess = true;
              }
            }
          }
        }
      } on FirebaseException catch (e) {
        // Handle specific Firestore errors
        debugPrint('Firestore error during verification update: ${e.code} - ${e.message}');
        debugPrint('Error details: ${e.toString()}');
        debugPrint('Current Auth User: ${FirebaseAuth.instance.currentUser?.uid}');
        debugPrint('Target UID: ${widget.uid}');
        
        if (e.code == 'permission-denied') {
          // Permission denied - check authentication
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            throw Exception('You are not signed in. Please sign in and try again.');
          } else if (user.uid != widget.uid) {
            throw Exception('Authentication mismatch. Please sign out and sign up again.');
          } else {
            // User is authenticated but still getting permission denied
            // This means Firestore rules need to be deployed
            throw Exception('Permission denied. Please ensure Firestore security rules are properly deployed.');
          }
        } else if (e.code == 'not-found') {
          // Document doesn't exist - create it
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.uid)
                .set({
                  'email': widget.email,
                  'emailVerified': true,
                  'isVerified': true,
                }, SetOptions(merge: true));
            dbUpdateSuccess = true;
          } catch (e2) {
            debugPrint('Failed to create user document: ${e2.toString()}');
            throw Exception('Failed to create user document. Please contact support.');
          }
        } else if (e.code == 'invalid-argument' || e.code == 'failed-precondition' || e.code == 'aborted') {
          // 400 error - invalid request format or precondition failed
          // Try simpler update without serverTimestamp
          debugPrint('400 error detected, trying simpler update without serverTimestamp');
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.uid)
                .set({
                  'emailVerified': true,
                  'isVerified': true,
                }, SetOptions(merge: true));
            dbUpdateSuccess = true;
            debugPrint('Successfully updated with simpler format');
          } catch (e2) {
            debugPrint('Simpler update also failed: ${e2.toString()}');
            // Last attempt: try update method
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.uid)
                  .update({
                    'emailVerified': true,
                    'isVerified': true,
                  });
              dbUpdateSuccess = true;
              debugPrint('Successfully updated using update method');
            } catch (e3) {
              debugPrint('All update methods failed: ${e3.toString()}');
              throw Exception('Database update failed. Please try again or contact support.');
            }
          }
        } else {
          // Other Firestore errors - log and throw
          debugPrint('Other Firestore error: ${e.code} - ${e.message}');
          throw Exception('Database error: ${e.message ?? 'Failed to update verification status'}');
        }
      } catch (e) {
        // If database update fails completely, don't proceed
        // User must have verification status in database for login to work
        debugPrint('Unexpected error during verification update: $e');
        debugPrint('Error type: ${e.runtimeType}');
        if (e is! Exception) {
          throw Exception('Failed to save verification status: ${e.toString()}');
        }
        rethrow;
      }

      // Ensure database update succeeded before proceeding
      if (!dbUpdateSuccess) {
        throw Exception('Verification status was not saved. Please try again.');
      }

      // Note: The verifyCode method already sets the verified flag in SharedPreferences
      // So the local cache is already updated

      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified successfully! You can now sign in.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Navigate to login after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      
      // Extract error message
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (errorMessage.isEmpty) {
        errorMessage = 'Invalid or expired code. Please try again.';
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
        title: const Text('Verify Email'),
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
                    // Header text - Bold blue
                    const Text(
                      'Enter 6-digit verification code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _primaryBlue,
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
                    // Verify button - Large blue button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
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
                            : const Text('Verify'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Resend code link - Blue text
                    TextButton(
                      onPressed: _resending ? null : _resend,
                      style: TextButton.styleFrom(
                        foregroundColor: _primaryBlue,
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
                                color: _primaryBlue,
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
        cursorColor: _primaryBlue,
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
              color: isFocused || hasValue ? _primaryBlue : _inactiveBorder,
              width: isFocused ? 2 : 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: hasValue ? _primaryBlue : _inactiveBorder,
              width: hasValue ? 2 : 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: _primaryBlue,
              width: 2,
            ),
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
