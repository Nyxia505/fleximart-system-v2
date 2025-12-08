import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/phone_verification_service.dart';
import '../constants/app_colors.dart';

/// Phone Verification OTP Page
/// 
/// Page 2: User enters the 6-digit OTP code received via SMS
class PhoneVerificationOtpPage extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const PhoneVerificationOtpPage({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<PhoneVerificationOtpPage> createState() =>
      _PhoneVerificationOtpPageState();
}

class _PhoneVerificationOtpPageState extends State<PhoneVerificationOtpPage> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _phoneVerificationService = PhoneVerificationService();
  bool _loading = false;
  bool _resending = false;
  String? _errorMessage;
  late String _currentVerificationId; // Store the current verification ID
  Timer? _resendCooldownTimer; // Timer for resend cooldown
  int _resendCooldownSeconds = 0; // Remaining cooldown seconds
  static const int _cooldownDuration = 60; // 60-second cooldown

  @override
  void initState() {
    super.initState();
    // Store the initial verification ID
    _currentVerificationId = widget.verificationId;
    // Start cooldown timer when page loads
    _startResendCooldown();
    // Auto-focus the first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startResendCooldown() {
    _resendCooldownSeconds = _cooldownDuration;
    _resendCooldownTimer?.cancel();
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCooldownSeconds > 0) {
            _resendCooldownSeconds--;
          } else {
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _onCodeChanged(int index, String value) {
    if (value.length == 1) {
      // Move to next field
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last field filled, verify automatically
        if (!_loading) {
          _focusNodes[index].unfocus();
          _verifyOtp();
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

  Future<void> _verifyOtp() async {
    if (_loading) return;

    final code = _getCode();

    // Validate code
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
        _loading = false;
      });
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _errorMessage = 'Code must contain only numbers';
        _loading = false;
      });
      _clearAllFields();
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Create credential from OTP code using saved verificationId
      final credential = await _phoneVerificationService.verifyOtp(
        smsCode: code,
        verificationId: _currentVerificationId,
      );

      // Step 2: Sign in with credential (or link if user already logged in)
      final currentUser = FirebaseAuth.instance.currentUser;
      final uid = await _phoneVerificationService.verifyAndSignIn(
        credential: credential,
      );

      // Step 3: Save phone verification to Firestore
      await _phoneVerificationService.saveVerifiedPhone(
        uid: uid,
        phoneNumber: widget.phoneNumber,
      );

      if (!mounted) return;

      // Step 4: Stop loading
      setState(() {
        _loading = false;
      });

      // Step 5: Verify the save was successful before navigating
      // Wait a moment to ensure Firestore has updated
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Double-check verification status
      final isVerified = await PhoneVerificationService.isPhoneVerified(uid);
      if (!isVerified) {
        throw Exception('Verification saved but status check failed. Please try again.');
      }

      // Step 6: Show success dialog pop-up
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false, // Prevent dismissing by tapping outside
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Phone Verified!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your phone number has been verified successfully!',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Phone: +63 ${widget.phoneNumber}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    // Then navigate based on user status
                    if (!mounted) return;
                    if (currentUser == null) {
                      // New phone sign-in - navigate to dashboard
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/dashboard',
                        (route) => false,
                      );
                    } else {
                      // Phone verification for existing user - go back with success flag
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Verification failed';
      
      if (e.code == 'invalid-verification-code') {
        errorMessage = 'Invalid verification code. Please check and try again.';
      } else if (e.code == 'session-expired') {
        errorMessage = 'Verification session expired. Please request a new code.';
      } else if (e.code == 'code-expired') {
        errorMessage = 'Verification code has expired. Please request a new code.';
      } else if (e.code == 'invalid-verification-id') {
        errorMessage = 'Invalid verification session. Please request a new OTP.';
      } else {
        errorMessage = e.message ?? 'Verification failed. Please try again.';
      }

      setState(() {
        _errorMessage = errorMessage;
        _loading = false;
      });

      _clearAllFields();
    } catch (e) {
      if (!mounted) return;

      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (errorMessage.isEmpty || errorMessage == 'null') {
        errorMessage = 'Invalid or expired code. Please try again.';
      }

      setState(() {
        _errorMessage = errorMessage;
        _loading = false;
      });

      _clearAllFields();
    }
  }

  void _clearAllFields() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _resendOtp() async {
    if (_resending || _resendCooldownSeconds > 0) return;

    setState(() {
      _resending = true;
      _errorMessage = null;
    });

    try {
      _clearAllFields();

      final success = await _phoneVerificationService.sendOtp(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          // Save the new verification ID
          setState(() {
            _resending = false;
            _currentVerificationId = verificationId;
          });
          // Reset cooldown when new OTP is sent
          _startResendCooldown();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('New OTP sent successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _resending = false;
            _errorMessage = error;
          });
        },
      );

      if (!success && mounted) {
        setState(() {
          _resending = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Verification Code'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Icon
              Icon(
                Icons.sms,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              // Title
              const Text(
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Phone number display
              Text(
                'Code sent to +63 ${widget.phoneNumber}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // OTP Input Fields - Responsive layout
              LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate field width based on available space
                  final availableWidth = constraints.maxWidth;
                  final spacing = 8.0;
                  final totalSpacing = spacing * 5; // 5 gaps between 6 fields
                  final fieldWidth = ((availableWidth - totalSpacing) / 6).clamp(40.0, 50.0);
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: fieldWidth,
                        height: 55,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _focusNodes[index].hasFocus
                                ? AppColors.primary
                                : AppColors.border,
                            width: _focusNodes[index].hasFocus ? 2 : 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) => _onCodeChanged(index, value),
                    ),
                  );
                    }),
                  );
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Verify Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Resend OTP
              TextButton(
                onPressed: (_resending || _resendCooldownSeconds > 0) ? null : _resendOtp,
                child: _resending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _resendCooldownSeconds > 0
                            ? 'Resend OTP (${_resendCooldownSeconds}s)'
                            : 'Resend OTP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _resendCooldownSeconds > 0
                              ? AppColors.textSecondary
                              : AppColors.primary,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              // Change phone number
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Change Phone Number',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

