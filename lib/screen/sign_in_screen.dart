import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../services/email_verification_service.dart';
import 'dart:math' as math;

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool obscure = true;
  bool loading = false;

  // Dark maroon theme colors
  static const Color deepRed = Color(0xFF8B2E2E);
  static const Color crimson = Color(0xFF6B1F1F);
  static const Color magenta = Color(0xFF6B1F1F);
  static const Color darkPurple = Color(0xFF4A1515);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [deepRed, magenta, darkPurple],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Bubble Overlay
          _buildBubbleOverlay(),
          // Main Content
          SafeArea(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: isMobile ? 12 : 24,
                      right: isMobile ? 12 : 24,
                      top: 40,
                      bottom: keyboardHeight > 0 ? keyboardHeight + 20 : 40,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 450,
                        minHeight:
                            constraints.maxHeight -
                            (keyboardHeight > 0 ? keyboardHeight + 60 : 80),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          // Title and Subtitle
                          _buildTitleSection(),
                          const SizedBox(height: 40),
                          // Form Container with White Border
                          _buildFormContainer(isMobile: isMobile),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleOverlay() {
    return CustomPaint(painter: BubblePainter(), size: Size.infinite);
  }

  Widget _buildTitleSection() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: const Text(
        '"Sign in to your account"',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color:
              Colors.white, // White text for better contrast on red background
          letterSpacing: 0.5,
          height: 1.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildFormContainer({bool isMobile = false}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email Field
          _buildTextField(
            controller: emailController,
            label: 'Email',
            hintText: 'Enter your email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            focusNode: _emailFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 24),
          // Password Field
          _buildTextField(
            controller: passwordController,
            label: 'Password',
            hintText: 'Enter your password',
            icon: Icons.lock_outline,
            obscureText: obscure,
            focusNode: _passwordFocus,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitIfReady(),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.black87,
                size: 22,
              ),
              onPressed: () => setState(() => obscure = !obscure),
            ),
          ),
          const SizedBox(height: 32),
          // Sign In Button
          _buildSignInButton(),
          const SizedBox(height: 16),
          // Forgot Password
          Center(
            child: TextButton(
              onPressed: () => _showForgotPasswordDialog(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.center,
              ),
              child: const Text(
                'Forgot Password?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black, // Black text
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Sign Up Link
          _buildSignUpLink(),
        ],
      ),
    );
  }

  void _submitIfReady() {
    if (loading) return;
    FocusScope.of(context).unfocus();
    _handleSignIn();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onFieldSubmitted: onFieldSubmitted,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF1B3B53),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: hintText,
              hintStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(icon, color: Colors.black87, size: 22),
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B2E2E), Color(0xFF4A1515)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.9), // White border
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B2E2E).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : _handleSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Sign in',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text for contrast on red
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontSize: 15,
            color: Colors.black87, // Dark text for better contrast on white
            fontWeight: FontWeight.w500,
          ),
          children: [
            TextSpan(text: "Don't have an account? "),
            TextSpan(
              text: 'Sign Up',
              style: TextStyle(
                color: Color(0xFF8B2E2E), // Dark maroon color for link
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF8B2E2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() => loading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Login failed');

      // STEP 1: Reload user to get fresh emailVerified status
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) throw Exception('User reload failed');

      // STEP 2: Read role from Firestore /users/{uid} BEFORE checking verification
      String? role;
      Map<String, dynamic>? userData;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshedUser.uid)
            .get();

        if (!doc.exists) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _showError(
            'Your account has no assigned role. Please contact admin.',
          );
          return;
        }

        userData = doc.data() ?? {};
        role = userData['role'] as String?;
      } catch (e) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showError('Error reading user profile: $e');
        return;
      }

      // If role is null, show error
      if (role == null) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showError('Your account has no assigned role. Please contact admin.');
        return;
      }

      // STEP 3: Apply login rules based on role
      // Admin and Staff can login immediately without email verification
      if (role == 'admin' || role == 'staff') {
        if (!mounted) return;
        
        // Log login activity
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userName = (userData['name'] as String?) ??
                (userData['fullName'] as String?) ??
                (userData['customerName'] as String?) ??
                (userData['email'] as String?) ??
                'Unknown User';
            
            await FirebaseFirestore.instance.collection('activity_logs').add({
              'userId': refreshedUser.uid,
              'userName': userName,
              'actionType': 'Login',
              'description': 'User logged in',
              'timestamp': FieldValue.serverTimestamp(),
              'metadata': {
                'role': role,
                'loginTime': DateTime.now().toIso8601String(),
              },
            });
          }
        } catch (e) {
          // Don't fail login if activity logging fails
          debugPrint('Error logging login activity: $e');
        }
        
        // Navigate based on role
        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else if (role == 'staff') {
          Navigator.pushReplacementNamed(context, '/staff');
        }
        return;
      }

      // STEP 4: Customers — OTP/Firestore verification only (not Firebase link emailVerified)
      if (role == 'customer') {
        if (!EmailVerificationService.isCustomerVerifiedFromDoc(userData)) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _showError(
            'Account not verified. Complete sign-up with your email OTP code.',
          );
          return;
        }
      }

      if (!mounted) return;

      // Log login activity
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshedUser.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final userName = (userData['name'] as String?) ??
              (userData['fullName'] as String?) ??
              (userData['customerName'] as String?) ??
              (userData['email'] as String?) ??
              'Unknown User';
          
          await FirebaseFirestore.instance.collection('activity_logs').add({
            'userId': refreshedUser.uid,
            'userName': userName,
            'actionType': 'Login',
            'description': 'User logged in',
            'timestamp': FieldValue.serverTimestamp(),
            'metadata': {
              'role': role,
              'loginTime': DateTime.now().toIso8601String(),
            },
          });
        }
      } catch (e) {
        // Don't fail login if activity logging fails
        debugPrint('Error logging login activity: $e');
      }

      // Navigate based on role
      if (role == 'customer') {
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else if (role == 'staff') {
        Navigator.pushReplacementNamed(context, '/staff');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled';
      }
      _showError(message);
    } catch (e) {
      _showError('Login failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ResetPasswordDialog(
        initialEmail: emailController.text.trim(),
        accentColor: crimson,
        onSuccess: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Password reset link sent! Check your inbox and spam folder.',
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  final String initialEmail;
  final Color accentColor;
  final VoidCallback onSuccess;

  const _ResetPasswordDialog({
    required this.initialEmail,
    required this.accentColor,
    required this.onSuccess,
  });

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _emailFocus = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email. Sign up first or check the spelling.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Could not send reset link. Please try again.';
    }
  }

  Future<void> _sendResetLink() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim().toLowerCase();
    setState(() => _sending = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showDialogError(_authErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      _showDialogError('Could not send reset link. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showDialogError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Reset Password',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a password reset link.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              focusNode: _emailFocus,
              autofocus: widget.initialEmail.isEmpty,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              enabled: !_sending,
              autocorrect: false,
              onFieldSubmitted: (_) => _sendResetLink(),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Email is required';
                if (!_isValidEmail(email)) return 'Enter a valid email address';
                return null;
              },
              decoration: InputDecoration(
                hintText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, color: widget.accentColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accentColor, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _sendResetLink,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.accentColor,
            disabledBackgroundColor: widget.accentColor.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _sending
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Send Link'),
        ),
      ],
    );
  }
}

// Custom Painter for Bubble Overlay
class BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);

    // Dark maroon bubble colors
    final bubbleColors = [
      const Color(0xFF8B2E2E).withOpacity(0.3),
      const Color(0xFF6B1F1F).withOpacity(0.25),
      const Color(0xFF4A1515).withOpacity(0.2),
    ];

    // Draw multiple glossy bubbles with soft blue tones
    for (int i = 0; i < 10; i++) {
      final x = size.width * (0.1 + random.nextDouble() * 0.8);
      final y = size.height * (0.1 + random.nextDouble() * 0.8);
      final radius = 50 + random.nextDouble() * 100;

      final paint = Paint()
        ..color = bubbleColors[i % bubbleColors.length]
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
