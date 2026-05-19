import 'dart:convert';

import 'package:emailjs/emailjs.dart' as emailjs;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import '../config/emailjs_config.dart';

class EmailService {
  EmailService._();

  static Map<String, dynamic> emailJsTemplateParams({
    required String toEmail,
    required String displayName,
    required String otpCode,
  }) {
    return {
      'to_email': toEmail,
      'to_name': displayName,
      'otp': otpCode,
      'email': toEmail,
      'name': displayName,
      'user_email': toEmail,
      'user_name': displayName,
      'verification_code': otpCode,
      'passcode': otpCode,
      'code': otpCode,
      'message':
          'Your FlexiMart verification code is $otpCode. It expires in 5 minutes.',
      'subject': 'FlexiMart Verification Code',
      'from_name': 'FlexiMart',
    };
  }

  static String _parseEmailJsError(String body) {
    final lower = body.toLowerCase();
    if (lower.contains('non-browser')) {
      return 'Enable EmailJS "Allow non-browser API requests" in Security settings';
    }
    if (lower.contains('insufficient authentication scopes')) {
      return 'Reconnect Gmail in EmailJS Email Services, or use Gmail App Password (smtpPass)';
    }
    if (lower.contains('invalid') && lower.contains('parameter')) {
      return 'EmailJS template: To Email = {{to_email}}, body includes {{otp}}';
    }
    return body.length > 160 ? '${body.substring(0, 160)}...' : body;
  }

  /// Sends OTP to the user's Gmail inbox.
  static Future<void> sendOtpEmail({
    required String toEmail,
    required String otpCode,
    String? toName,
  }) async {
    EmailJsConfig.invalidateCache();
    await EmailJsConfig.ensureLoaded();
    if (!EmailJsConfig.hasSmtp) {
      await EmailJsConfig.reloadSmtpFromFirestore();
      await EmailJsConfig.forceReload();
    }
    final displayName = toName ?? toEmail.split('@').first;
    final errors = <String>[];

    if (kDebugMode) {
      debugPrint(
        '📧 sendOtpEmail: smtp=${EmailJsConfig.hasSmtp}, web=$kIsWeb',
      );
    }

    if (kIsWeb) {
      // 1) Gmail SMTP via Cloud Function (most reliable when smtpPass is configured)
      if (EmailJsConfig.hasSmtp) {
        try {
          await _sendViaCloudFunction(
            toEmail: toEmail,
            otpCode: otpCode,
            toName: displayName,
          );
          return;
        } catch (e) {
          errors.add('Server SMTP: $e');
        }
      } else {
        errors.add(
          'SMTP not loaded — run: flutter clean && flutter pub get && flutter run -d chrome',
        );
      }

      // 2) Browser EmailJS fallback
      if (EmailJsConfig.canUseEmailJs) {
        for (final tid in EmailJsConfig.allTemplateIds) {
          try {
            await _sendViaEmailJsSdk(
              toEmail: toEmail,
              otpCode: otpCode,
              displayName: displayName,
              templateId: tid,
              browserOnly: true,
            );
            return;
          } catch (e) {
            errors.add('EmailJS browser: $e');
          }
        }
      }

      // 3) EmailJS HTTP with private key
      final sent = await _tryEmailJsPaths(
        toEmail: toEmail,
        otpCode: otpCode,
        displayName: displayName,
        errors: errors,
        webSdkFirst: false,
      );
      if (sent) return;
    } else {
      // Mobile/desktop: server + SMTP + EmailJS
      try {
        await _sendViaCloudFunction(
          toEmail: toEmail,
          otpCode: otpCode,
          toName: displayName,
        );
        return;
      } catch (e) {
        errors.add('Server: $e');
      }

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

      final sent = await _tryEmailJsPaths(
        toEmail: toEmail,
        otpCode: otpCode,
        displayName: displayName,
        errors: errors,
        webSdkFirst: false,
      );
      if (sent) return;
    }

    if (kDebugMode) {
      for (final err in errors) {
        debugPrint('❌ $err');
      }
    }

    final hint = kIsWeb
        ? ' Fix: (1) EmailJS → Account → Security → turn ON "Allow non-browser API requests", '
            'reconnect Gmail under Email Services, OR (2) run scripts/setup_gmail_smtp.ps1 '
            'with your 16-char Gmail App Password, then restart the app.'
        : ' Run scripts/setup_gmail_smtp.ps1 or add smtpPass to assets/config/emailjs.secrets.json.';

    throw Exception('Could not send verification code to $toEmail.$hint');
  }

  static Future<bool> _tryEmailJsPaths({
    required String toEmail,
    required String otpCode,
    required String displayName,
    required List<String> errors,
    required bool webSdkFirst,
  }) async {
    if (!EmailJsConfig.canUseEmailJs) return false;

    for (final tid in EmailJsConfig.allTemplateIds) {
      if (webSdkFirst || kIsWeb) {
        try {
          await _sendViaEmailJsSdk(
            toEmail: toEmail,
            otpCode: otpCode,
            displayName: displayName,
            templateId: tid,
          );
          return true;
        } catch (e) {
          errors.add('EmailJS SDK: $e');
        }
      }

      for (final useKey in [true, false]) {
        try {
          await _sendViaEmailJsHttp(
            toEmail: toEmail,
            otpCode: otpCode,
            displayName: displayName,
            templateId: tid,
            usePrivateKey: useKey,
          );
          return true;
        } catch (e) {
          errors.add('EmailJS HTTP: $e');
        }
      }
    }
    return false;
  }

  static Future<void> sendAccountConfirmedEmail({
    required String toEmail,
    String? toName,
  }) async {
    try {
      await sendOtpEmail(
        toEmail: toEmail,
        otpCode: '000000',
        toName: toName,
      );
    } catch (_) {}
  }

  static Future<void> _sendViaEmailJsHttp({
    required String toEmail,
    required String otpCode,
    required String displayName,
    required String templateId,
    required bool usePrivateKey,
  }) async {
    final payload = <String, dynamic>{
      'service_id': EmailJsConfig.serviceId,
      'template_id': templateId,
      'user_id': EmailJsConfig.publicKey,
      'template_params': emailJsTemplateParams(
        toEmail: toEmail,
        displayName: displayName,
        otpCode: otpCode,
      ),
    };
    if (usePrivateKey) {
      final pk = EmailJsConfig.privateKey;
      if (pk != null && pk.isNotEmpty) payload['accessToken'] = pk;
    }

    final response = await http
        .post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        '[${response.statusCode}] ${_parseEmailJsError(response.body)}',
      );
    }
    if (kDebugMode) debugPrint('✅ OTP email via EmailJS HTTP');
  }

  static emailjs.Options _emailJsOptions() {
    final pk = EmailJsConfig.privateKey;
    return emailjs.Options(
      publicKey: EmailJsConfig.publicKey,
      privateKey: (pk != null && pk.isNotEmpty) ? pk : null,
    );
  }

  static Future<void> _sendViaEmailJsSdk({
    required String toEmail,
    required String otpCode,
    required String displayName,
    required String templateId,
    bool browserOnly = false,
  }) async {
    final opts = browserOnly
        ? emailjs.Options(publicKey: EmailJsConfig.publicKey)
        : _emailJsOptions();
    emailjs.init(opts);

    await emailjs.send(
      EmailJsConfig.serviceId,
      templateId,
      emailJsTemplateParams(
        toEmail: toEmail,
        displayName: displayName,
        otpCode: otpCode,
      ),
      opts,
    );
    if (kDebugMode) debugPrint('✅ OTP email via EmailJS SDK');
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
          '''
<p>Hello $displayName,</p>
<p>Your FlexiMart verification code is: <strong>$otpCode</strong></p>
<p>Expires in 5 minutes. Open Gmail on your phone to read this message.</p>''';

    try {
      await send(message, gmail(user, pass));
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('authentication') ||
          msg.contains('username and password')) {
        throw Exception(
          'Gmail rejected login — use a 16-character App Password '
          '(Google Account → Security → App passwords), not your normal password.',
        );
      }
      rethrow;
    }
    if (kDebugMode) debugPrint('✅ OTP email via Gmail SMTP → $toEmail');
  }

  static Future<void> _sendViaCloudFunction({
    required String toEmail,
    required String otpCode,
    String? toName,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('sendOtpEmail');
    final payload = <String, dynamic>{
      'toEmail': toEmail,
      'otp': otpCode,
      'toName': toName ?? toEmail,
      'serviceId': EmailJsConfig.serviceId,
      'templateId': EmailJsConfig.templateId,
      'publicKey': EmailJsConfig.publicKey,
      if (EmailJsConfig.privateKey != null)
        'privateKey': EmailJsConfig.privateKey,
    };
    if (EmailJsConfig.hasSmtp) {
      payload['smtpUser'] = EmailJsConfig.smtpUser;
      payload['smtpPass'] = EmailJsConfig.smtpPass;
    }

    try {
      final result = await callable.call(payload).timeout(
            const Duration(seconds: 35),
          );

      final data = result.data;
      if (data is! Map || data['success'] != true) {
        throw Exception('Server did not confirm email delivery');
      }
      final method = data['method'] as String? ?? 'unknown';
      if (method == 'mail_queue') {
        throw Exception('Email queued only — configure smtpPass');
      }
      if (kDebugMode) debugPrint('✅ OTP email via Cloud Function ($method)');
    } on FirebaseFunctionsException catch (e) {
      final detail = e.message?.trim();
      if (e.code == 'failed-precondition' &&
          detail != null &&
          detail.isNotEmpty) {
        throw Exception(detail);
      }
      if (e.code == 'internal' &&
          detail != null &&
          detail.toLowerCase().contains('email_setup')) {
        throw Exception(detail);
      }
      throw Exception(
        detail?.isNotEmpty == true
            ? detail!
            : 'Server error (${e.code}). Deploy functions and set smtpPass in Firestore app_config/emailjs.',
      );
    }
  }
}
