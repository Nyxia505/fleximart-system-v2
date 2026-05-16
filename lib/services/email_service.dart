import 'package:emailjs/emailjs.dart' as emailjs;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import '../config/emailjs_config.dart';

class EmailService {
  EmailService._();

  /// Sends a 6-digit verification code to the user's email.
  static Future<void> sendOtpEmail({
    required String toEmail,
    required String otpCode,
    String? toName,
  }) async {
    await EmailJsConfig.ensureLoaded();
    final displayName = toName ?? toEmail.split('@').first;
    final errors = <String>[];

    // 1) EmailJS (official SDK + private key for desktop/mobile)
    for (final tid in EmailJsConfig.allTemplateIds) {
      try {
        await _sendViaEmailJsSdk(
          toEmail: toEmail,
          otpCode: otpCode,
          displayName: displayName,
          templateId: tid,
        );
        EmailJsConfig.templateId = tid;
        return;
      } catch (e) {
        errors.add('EmailJS ($tid): $e');
      }
    }

    if (EmailJsConfig.allTemplateIds.isEmpty) {
      errors.add(
        'No templateId configured. Set app_config/emailjs in Firestore or '
        'assets/config/emailjs.json (EmailJS → Contact Us → Settings tab).',
      );
    }

    // 2) Gmail SMTP fallback (same Gmail as EmailJS service)
    if (EmailJsConfig.hasSmtp) {
      try {
        await _sendViaSmtp(
          toEmail: toEmail,
          otpCode: otpCode,
          displayName: displayName,
        );
        return;
      } catch (e) {
        errors.add('SMTP: $e');
      }
    }

    // 3) Cloud Function (if deployed)
    if (!kIsWeb) {
      try {
        await _sendViaCloudFunction(
          toEmail: toEmail,
          otpCode: otpCode,
          toName: displayName,
        );
        return;
      } catch (e) {
        errors.add('Cloud Function: $e');
      }
    }

    if (kDebugMode) {
      for (final err in errors) {
        debugPrint('❌ $err');
      }
    }

    final combined = errors.join(' | ').toLowerCase();
    if (combined.contains('non-browser')) {
      throw Exception(
        'Enable "Allow non-browser API requests" in EmailJS → Account → Security, '
        'or set smtpPass in Firestore app_config/emailjs (Gmail app password).',
      );
    }
    if (combined.contains('template id not found') ||
        EmailJsConfig.allTemplateIds.isEmpty) {
      throw Exception(
        'Email template not set. In Firebase Console, create app_config/emailjs with '
        'templateId from EmailJS → Templates → Contact Us → Settings tab.',
      );
    }

    throw Exception(
      'Could not send verification email. Check EmailJS template ID and Security settings.',
    );
  }

  static Future<void> sendAccountConfirmedEmail({
    required String toEmail,
    String? toName,
  }) async {
    try {
      await sendOtpEmail(
        toEmail: toEmail,
        otpCode: 'CONFIRMED',
        toName: toName,
      );
    } catch (_) {
      // Non-blocking after signup
    }
  }

  static Future<void> _sendViaEmailJsSdk({
    required String toEmail,
    required String otpCode,
    required String displayName,
    required String templateId,
  }) async {
    final options = emailjs.Options(
      publicKey: EmailJsConfig.publicKey,
      privateKey: EmailJsConfig.privateKey,
    );

    await emailjs.send(
      EmailJsConfig.serviceId,
      templateId,
      {
        'to_email': toEmail,
        'to_name': displayName,
        'otp': otpCode,
      },
      options,
    );

    if (kDebugMode) {
      debugPrint('✅ OTP email sent via EmailJS SDK ($templateId)');
    }
  }

  static Future<void> _sendViaSmtp({
    required String toEmail,
    required String otpCode,
    required String displayName,
  }) async {
    final user = EmailJsConfig.smtpUser!;
    final pass = EmailJsConfig.smtpPass!;

    final message = Message()
      ..from = Address(user, 'FlexiMart')
      ..recipients.add(toEmail)
      ..subject = 'Your FlexiMart verification code'
      ..html =
          '<p>Hello $displayName,</p>'
          '<p>Your FlexiMart verification code is: <strong>$otpCode</strong></p>'
          '<p>This code expires in 5 minutes.</p>';

    await send(message, gmail(user, pass));

    if (kDebugMode) {
      debugPrint('✅ OTP email sent via Gmail SMTP');
    }
  }

  static Future<void> _sendViaCloudFunction({
    required String toEmail,
    required String otpCode,
    String? toName,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('sendOtpEmail');
    await callable.call(<String, dynamic>{
      'toEmail': toEmail,
      'otp': otpCode,
      'toName': toName ?? toEmail,
      'serviceId': EmailJsConfig.serviceId,
      'templateId': EmailJsConfig.allTemplateIds.isNotEmpty
          ? EmailJsConfig.allTemplateIds.first
          : '',
    }).timeout(const Duration(seconds: 25));
  }
}
