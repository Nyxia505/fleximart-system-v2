import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../utils/fcm_utils.dart';
import '../widgets/auth_screen_shell.dart';

/// Shown after signup or when an unverified customer signs in.
/// Polls Firebase until [User.emailVerified] is true, then opens the dashboard.
class EmailVerificationScreen extends StatefulWidget {
  final String? email;
  final String? fullName;

  const EmailVerificationScreen({
    super.key,
    this.email,
    this.fullName,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checking = false;
  bool _resending = false;
  int _resendCooldown = 0;
  String? _message;
  bool _isSuccessMessage = false;
  Timer? _pollTimer;
  Timer? _cooldownTimer;

  User? get _user => FirebaseAuth.instance.currentUser;

  String get _displayEmail =>
      widget.email ?? _user?.email ?? 'your email address';

  @override
  void initState() {
    super.initState();
    _startPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVerified(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_checking && mounted) {
        _checkVerified(silent: true);
      }
    });
  }

  void _startResendCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        setState(() => _resendCooldown = 0);
        t.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _checkVerified({bool silent = false}) async {
    if (_user == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    if (!silent) setState(() => _checking = true);

    try {
      final verified = await AuthService.reloadAndCheckEmailVerified();
      if (!mounted) return;

      if (verified) {
        _pollTimer?.cancel();
        await saveFcmToken();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/dashboard',
          (_) => false,
        );
        return;
      }

      if (!silent) {
        setState(() {
          _message =
              'Email not verified yet. Open Gmail, tap the link, then tap Refresh.';
          _isSuccessMessage = false;
        });
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() {
          _message = 'Could not check status. Try again.';
          _isSuccessMessage = false;
        });
      }
    } finally {
      if (mounted && !silent) setState(() => _checking = false);
    }
  }

  Future<void> _resendEmail() async {
    if (_resending || _resendCooldown > 0) return;

    setState(() {
      _resending = true;
      _message = null;
    });

    try {
      await AuthService.sendVerificationEmail();
      if (!mounted) return;
      setState(() {
        _message =
            'Verification email sent to $_displayEmail. Check inbox and spam.';
        _isSuccessMessage = true;
      });
      _startResendCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = AuthService.messageForAuthException(e);
        _isSuccessMessage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Failed to resend email. Please try again.';
        _isSuccessMessage = false;
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.fullName?.trim();
    final greeting = (name != null && name.isNotEmpty) ? 'Hi $name' : 'Almost there';

    return AuthScreenShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 72,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            greeting,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Verify your Gmail to continue',
            style: TextStyle(fontSize: 15, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'We sent a verification link to:',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _displayEmail,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                _buildStep(Icons.mail_outline, 'Open Gmail (inbox & spam)'),
                const SizedBox(height: 10),
                _buildStep(Icons.link, 'Tap the verification link'),
                const SizedBox(height: 10),
                _buildStep(Icons.refresh, 'Return here and tap Refresh'),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_isSuccessMessage ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _isSuccessMessage
                            ? const Color(0xFF166534)
                            : AppColors.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : () => _checkVerified(),
                    icon: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(_checking ? 'Checking…' : 'Refresh verification'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: (_resending || _resendCooldown > 0)
                        ? null
                        : _resendEmail,
                    icon: _resending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _resendCooldown > 0
                          ? 'Resend in ${_resendCooldown}s'
                          : 'Resend verification email',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _signOut,
                  child: const Text(
                    'Sign out and use another account',
                    style: TextStyle(color: AppColors.secondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}
