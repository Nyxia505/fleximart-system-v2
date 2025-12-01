import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/phone_verification_service.dart';
import '../constants/app_colors.dart';
import 'phone_verification_otp_page.dart';

/// Phone Verification Input Page
/// 
/// Page 1: User enters their phone number to receive OTP
class PhoneVerificationInputPage extends StatefulWidget {
  const PhoneVerificationInputPage({super.key});

  @override
  State<PhoneVerificationInputPage> createState() =>
      _PhoneVerificationInputPageState();
}

class _PhoneVerificationInputPageState
    extends State<PhoneVerificationInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _phoneVerificationService = PhoneVerificationService();
  bool _loading = false;
  String? _errorMessage;
  bool _isBlocked = false; // Track if user is blocked

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    // Remove all non-digits
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // If starts with 0, remove it (Philippines format)
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    
    return digits;
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final phoneNumber = _formatPhoneNumber(_phoneController.text.trim());
      
      if (phoneNumber.isEmpty || phoneNumber.length < 10) {
        throw Exception('Please enter a valid phone number');
      }

      // Check if phone is already verified before sending OTP
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final isAlreadyVerified = await PhoneVerificationService.isPhoneVerified(user.uid);
        if (isAlreadyVerified) {
          if (!mounted) return;
          setState(() {
            _loading = false;
          });
          // Phone already verified, return success
          Navigator.pop(context, true);
          return;
        }
      }

      // Send OTP
      final success = await _phoneVerificationService.sendOtp(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) async {
          if (!mounted) return;
          
          // Navigate to OTP verification page and wait for result
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => PhoneVerificationOtpPage(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
              ),
            ),
          );
          
          // Pass the result back to the caller
          if (mounted && result == true) {
            Navigator.pop(context, true);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _isBlocked = false;
            
            // Check for blocked/rate limit errors
            if (error.contains('blocked') ||
                error.contains('unusual activity') ||
                error.contains('Try again later') ||
                error.contains('too-many-requests')) {
              _isBlocked = true;
              _errorMessage = error;
            } else if (error.contains('reCAPTCHA') ||
                error.contains('Security verification') ||
                error.isEmpty) {
              // reCAPTCHA is handled automatically by Firebase
              // Don't show this as an error
              _errorMessage = null;
            } else if (error.isNotEmpty) {
              _errorMessage = error;
            } else {
              _errorMessage = null;
            }
          });
        },
      );

      if (!success && mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone Number'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Icon
                Icon(
                  Icons.phone_android,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                // Title
                const Text(
                  'Verify Your Phone Number',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Subtitle
                Text(
                  'We\'ll send you a 6-digit verification code via SMS',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Phone Input
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '09123456789',
                    prefixIcon: const Icon(Icons.phone),
                    prefixText: '+63 ',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                    if (digits.length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isBlocked 
                          ? Colors.red.shade50 
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isBlocked 
                            ? Colors.red.shade200 
                            : Colors.red.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isBlocked ? Icons.block : Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Send OTP Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_loading || _isBlocked) ? null : _sendOtp,
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
                            'Send OTP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                // Info text
                Text(
                  'By continuing, you agree to receive SMS messages. Message and data rates may apply.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

