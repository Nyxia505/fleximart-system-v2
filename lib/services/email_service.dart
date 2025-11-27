import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  EmailService._();

  static const String _serviceId = 'service_e76lq6a';
  static const String _templateId = 'template_9lir44r';
  static const String _publicKey = 'o78K4QpwRKGID0HiA';

  // FlexiMart branding for email sender
  static const String _senderName = 'FlexiMart';
  static const String _senderEmail = 'fleximart.app@gmail.com';
  static const String _replyTo = 'no-reply@fleximart.com';

  static Future<void> sendOtpEmail({
    required String toEmail,
    required String otpCode,
    String? toName,
  }) async {
    final uri = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final payload = <String, dynamic>{
      // EmailJS REST v1 expects these exact keys
      'service_id': _serviceId,
      'template_id': _templateId,
      'user_id': _publicKey,
      'template_params': {
        // Recipient information
        'to_email': toEmail,
        'to_name': toName ?? toEmail,
        'otp': otpCode,
        // Sender branding - FlexiMart
        'from_name': _senderName,
        'from_email': _senderEmail,
        'reply_to': _replyTo,
        // Additional branding
        'company_name': _senderName,
        'app_name': _senderName,
      },
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to send OTP email: ${response.statusCode} ${response.body}',
      );
    }
  }
}
