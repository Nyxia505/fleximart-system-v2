import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../services/phone_verification_service.dart';
import '../screen/phone_verification_otp_page.dart';

/// Delivery Address Dialog
///
/// Collects delivery address information when converting quotation to order
class DeliveryAddressDialog extends StatefulWidget {
  const DeliveryAddressDialog({super.key});

  @override
  State<DeliveryAddressDialog> createState() => _DeliveryAddressDialogState();
}

class _DeliveryAddressDialogState extends State<DeliveryAddressDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _completeAddressController = TextEditingController();
  final _landmarkController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _completeAddressController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        setState(() {
          _fullNameController.text =
              userData['name'] ??
              userData['fullName'] ??
              user.displayName ??
              '';
          _phoneNumberController.text = userData['phoneNumber'] ?? '';
          _completeAddressController.text =
              userData['address'] ?? userData['completeAddress'] ?? '';
          _landmarkController.text = userData['landmark'] ?? '';
          _isLoadingProfile = false;
        });
      } else {
        setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      setState(() => _isLoadingProfile = false);
    }
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (value.trim().length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validateCompleteAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Complete address is required';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      // Show phone verification and wait for result
      final verified = await showPhoneVerification(
        context,
        _phoneNumberController.text.trim(),
      );

      // If phone is verified, return the delivery address data
      if (verified && mounted) {
        Navigator.pop(context, {
          'fullName': _fullNameController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim(),
          'completeAddress': _completeAddressController.text.trim(),
          'landmark': _landmarkController.text.trim(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Delivery Address',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Please provide your delivery address to complete the order',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (_isLoadingProfile)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            hintText: 'Enter your full name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: _validateFullName,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneNumberController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number *',
                            hintText: 'Enter your phone number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: _validatePhoneNumber,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _completeAddressController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Complete Address *',
                            hintText:
                                'Enter your complete address (street, building, area)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          validator: _validateCompleteAddress,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _landmarkController,
                          decoration: const InputDecoration(
                            labelText: 'Landmark (Optional)',
                            hintText: 'Enter nearby landmark',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.place),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Phone Verification Modal
///
/// Shows a modal for verifying phone number with OTP
/// Helper function to show phone verification and return result
Future<bool> showPhoneVerification(
  BuildContext context,
  String phoneNumber,
) async {
  final completer = Completer<bool>();

  // Show modal
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _PhoneVerificationModalWithCompleter(
      phoneNumber: phoneNumber,
      completer: completer,
    ),
  );

  return completer.future;
}

class _PhoneVerificationModalWithCompleter extends StatefulWidget {
  final String phoneNumber;
  final Completer<bool> completer;

  const _PhoneVerificationModalWithCompleter({
    required this.phoneNumber,
    required this.completer,
  });

  @override
  State<_PhoneVerificationModalWithCompleter> createState() =>
      _PhoneVerificationModalWithCompleterState();
}

class _PhoneVerificationModalWithCompleterState
    extends State<_PhoneVerificationModalWithCompleter> {
  final _phoneVerificationService = PhoneVerificationService();
  bool _isSendingOtp = false;
  String? _errorMessage;

  @override
  void dispose() {
    if (!widget.completer.isCompleted) {
      widget.completer.complete(false);
    }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    try {
      await _phoneVerificationService.sendOtp(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (verificationId) {
          // OTP sent successfully, navigate to OTP input screen
          if (mounted) {
            setState(() {
              _isSendingOtp = false;
            });
            // Close the modal first, then navigate to OTP page
            Navigator.pop(context);
            if (mounted) {
              // Navigate to OTP page and wait for verification result
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PhoneVerificationOtpPage(
                    phoneNumber: widget.phoneNumber,
                    verificationId: verificationId,
                  ),
                ),
              ).then((verified) {
                // Complete the completer with verification result
                if (!widget.completer.isCompleted) {
                  widget.completer.complete(verified == true);
                }
              });
            }
          }
        },
        onError: (error) {
          setState(() {
            // Check for blocked/rate limit errors first
            if (error.contains('blocked') ||
                error.contains('unusual activity') ||
                error.contains('Try again later') ||
                error.contains('too-many-requests') ||
                error.contains('TOO_MANY_REQUESTS')) {
              _errorMessage =
                  'Too many verification attempts.\n\n'
                  'Your device has been temporarily blocked due to unusual activity.\n'
                  'Please wait 15-30 minutes before trying again.';
            } else if (error.contains('operation-not-allowed') ||
                error.contains('OPERATION_NOT_ALLOWED')) {
              _errorMessage =
                  'Phone sign-in is disabled. Please contact support.';
            } else if (error.contains('invalid-phone-number') ||
                error.contains('INVALID_PHONE_NUMBER')) {
              _errorMessage =
                  'Invalid phone number format. Please check and try again.';
            } else if (error.contains('quota-exceeded') ||
                error.contains('QUOTA_EXCEEDED')) {
              _errorMessage = 'SMS quota exceeded. Please try again later.';
            } else if (error.contains('reCAPTCHA') ||
                error.contains('application verifier') ||
                error.contains('reCAPTCHA token')) {
              // Check if it's actually a block error
              if (error.contains('blocked') ||
                  error.contains('unusual activity')) {
                _errorMessage =
                    'Too many verification attempts.\n\n'
                    'Please wait 15-30 minutes before trying again.';
              } else {
                _errorMessage =
                    'Security verification required.\n\n'
                    'A browser window may open for security verification.\n'
                    'Please complete the verification and return to the app.';
              }
            } else {
              _errorMessage = error;
            }
            _isSendingOtp = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSendingOtp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Verify Phone Number',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    if (!widget.completer.isCompleted) {
                      widget.completer.complete(false);
                    }
                    Navigator.pop(context);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'We need to verify your phone number to proceed',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // Phone Number Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.phoneNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 13, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),

            if (_errorMessage != null) const SizedBox(height: 16),

            // Send OTP Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSendingOtp ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSendingOtp
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
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
          ],
        ),
      ),
    );
  }
}
