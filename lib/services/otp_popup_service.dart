import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../constants/app_colors.dart';

/// Service to handle OTP popup dialogs when OTP notifications are received
class OtpPopupService {
  OtpPopupService._();
  static final OtpPopupService instance = OtpPopupService._();

  // Callback function to handle when user wants to use the OTP code
  Function(String)? onOtpReceived;

  /// Initialize the service to listen for OTP notifications
  void initialize(BuildContext? context) {
    if (context == null) return;

    // Listen for foreground messages (when app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleOtpNotification(message, context);
    });

    // Listen for background messages that open the app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleOtpNotification(message, context);
    });
  }

  /// Handle OTP notification and show popup
  void _handleOtpNotification(RemoteMessage message, BuildContext context) {
    // Check if this is an OTP notification
    final data = message.data;
    if (data['type'] != 'otp_verification') {
      return; // Not an OTP notification, ignore
    }

    final otpCode = data['otp'] as String?;
    final email = data['email'] as String? ?? '';

    if (otpCode == null || otpCode.isEmpty) {
      if (kDebugMode) {
        print('⚠️ OTP notification received but no OTP code found');
      }
      return;
    }

    // Show popup dialog with OTP code
    _showOtpPopup(context, otpCode, email);
  }

  /// Show OTP popup dialog
  void _showOtpPopup(BuildContext context, String otpCode, String email) {
    // Only show if context is still mounted
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false, // Prevent back button from closing
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.verified_user,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Verification Code',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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
                  'Your verification code has been sent via push notification.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your Code',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        otpCode,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'For: $email',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Copy OTP code to clipboard
                  await Clipboard.setData(ClipboardData(text: otpCode));
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                  Navigator.of(dialogContext).pop();
                },
                child: const Text(
                  'Copy Code',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Call the callback to auto-fill the OTP
                  if (onOtpReceived != null) {
                    onOtpReceived!(otpCode);
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
                  'Use This Code',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show OTP popup manually (for testing or direct calls)
  void showOtpPopup(BuildContext context, String otpCode, String email) {
    _showOtpPopup(context, otpCode, email);
  }
}

