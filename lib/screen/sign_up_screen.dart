import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/email_verification_service.dart';
import 'signup_verify_otp_screen.dart';
import 'dart:math' as math;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool obscure = true;
  bool obscureConfirmPassword = true;
  bool loading = false;

  // Exact colors from reference image
  static const Color deepRed = Color(0xFF7A002F);
  static const Color crimson = Color(0xFFBD003B);
  static const Color magenta = Color(0xFF9B0034);
  static const Color darkPurple = Color(0xFF3E0024);

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 40,
                bottom: keyboardHeight > 0 ? keyboardHeight + 20 : 40,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Title and Subtitle
                  _buildTitleSection(),
                  const SizedBox(height: 40),
                  // Form Container with White Border
                  _buildFormContainer(),
                ],
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
    return Column(
      children: [
        const Text(
          'Create Your',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Account',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.3,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildFormContainer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Full Name Field
          _buildTextField(
            controller: fullNameController,
            label: 'Full Name',
            hintText: 'Enter your full name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 24),
          // Email Field
          _buildTextField(
            controller: emailController,
            label: 'Email',
            hintText: 'Enter your email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          // Password Field
          _buildTextField(
            controller: passwordController,
            label: 'Password',
            hintText: 'Enter your password',
            icon: Icons.lock_outline,
            obscureText: obscure,
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.black87,
                size: 22,
              ),
              onPressed: () => setState(() => obscure = !obscure),
            ),
          ),
          const SizedBox(height: 24),
          // Confirm Password Field
          _buildTextField(
            controller: confirmPasswordController,
            label: 'Confirm Password',
            hintText: 'Confirm your password',
            icon: Icons.lock_outline,
            obscureText: obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: Colors.black87,
                size: 22,
              ),
              onPressed: () => setState(
                () => obscureConfirmPassword = !obscureConfirmPassword,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Sign Up Button
          _buildSignUpButton(),
          const SizedBox(height: 24),
          // Sign In Link
          _buildSignInLink(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
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
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
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
                borderSide: const BorderSide(
                  color: Colors.transparent,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.transparent,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.pinkAccent,
                  width: 1.5,
                ),
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

  Widget _buildSignUpButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [crimson, darkPurple]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: crimson.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : _handleSignUp,
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
                'Sign up',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }

  Widget _buildSignInLink() {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, '/login'),
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontSize: 15,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          children: [
            TextSpan(text: 'Already have an account? '),
            TextSpan(
              text: 'Sign In',
              style: TextStyle(
                color: Color(0xFFFFB6D1),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFFFFB6D1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    // Validation
    if (fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    if (!mounted) return;
    setState(() => loading = true);

    try {
      // Send email OTP
      await EmailVerificationService.requestEmailVerification(
        email: email,
        displayName: fullName,
      );

      if (!mounted) return;
      setState(() => loading = false);

      // Navigate to OTP verification screen
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SignupVerifyOtpScreen(
            email: email,
            fullName: fullName,
            password: password,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Failed to send verification code';
      String errorString = e.toString();

      if (errorString.contains('wait')) {
        errorMessage = errorString.replaceFirst('Exception: ', '');
      } else if (errorString.contains('email')) {
        errorMessage =
            'Failed to send verification code. Please check your email address.';
      } else if (errorString.contains('network') ||
          errorString.contains('timeout')) {
        errorMessage =
            'Network error. Please check your internet connection and try again.';
      } else if (errorString.contains('already') ||
          errorString.contains('exists')) {
        errorMessage =
            'An account with this email already exists. Please sign in instead.';
      } else {
        errorMessage = 'Something went wrong. Please try again.';
      }

      _showError(errorMessage);
      setState(() => loading = false);
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
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
}

// Custom Painter for Bubble Overlay
class BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);

    // Draw multiple glossy bubbles
    for (int i = 0; i < 10; i++) {
      final x = size.width * (0.1 + random.nextDouble() * 0.8);
      final y = size.height * (0.1 + random.nextDouble() * 0.8);
      final radius = 50 + random.nextDouble() * 100;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
