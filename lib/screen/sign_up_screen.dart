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

  // Password strength tracking
  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;

  // Dark maroon theme colors
  static const Color deepRed = Color(0xFF8B2E2E);
  static const Color magenta = Color(0xFF6B1F1F);
  static const Color darkPurple = Color(0xFF4A1515);

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
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: isMobile ? 12 : 24,
                      right: isMobile ? 12 : 24,
                      top: 20,
                      bottom: keyboardHeight > 0 ? keyboardHeight + 20 : 40,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 450,
                        minHeight:
                            constraints.maxHeight -
                            (keyboardHeight > 0 ? keyboardHeight + 40 : 60),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8),
                          // Title and Subtitle
                          _buildTitleSection(),
                          const SizedBox(height: 20),
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
    return const Text(
      '"Create your account"',
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Colors.white, // White text for better contrast on red background
        letterSpacing: 0.5,
        height: 1.2,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
          _buildPasswordField(),
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
            color: Colors.black87,
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

  Widget _buildSignUpButton() {
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
                  color: Colors.white, // White text for contrast on red
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
            color: Colors.black87, // Dark text for better contrast on white
            fontWeight: FontWeight.w500,
          ),
          children: [
            TextSpan(text: 'Already have an account? '),
            TextSpan(
              text: 'Sign In',
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

    // Strong password validation
    final passwordValidation = _validateStrongPassword(password);
    if (!passwordValidation['isValid']) {
      _showError(passwordValidation['message'] as String);
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

  void _checkPasswordStrength(String password) {
    setState(() {
      hasMinLength = password.length >= 8;
      hasUppercase = password.contains(RegExp(r'[A-Z]'));
      hasLowercase = password.contains(RegExp(r'[a-z]'));
      hasNumber = password.contains(RegExp(r'[0-9]'));
      hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  Map<String, dynamic> _validateStrongPassword(String password) {
    if (password.length < 8) {
      return {
        'isValid': false,
        'message': 'Password must be at least 8 characters long',
      };
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      return {
        'isValid': false,
        'message': 'Password must contain at least one uppercase letter',
      };
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      return {
        'isValid': false,
        'message': 'Password must contain at least one lowercase letter',
      };
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      return {
        'isValid': false,
        'message': 'Password must contain at least one number',
      };
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return {
        'isValid': false,
        'message':
            'Password must contain at least one special character (!@#\$%^&*(),.?":{}|<>)',
      };
    }

    return {'isValid': true, 'message': ''};
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Password',
          style: TextStyle(
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
            controller: passwordController,
            obscureText: obscure,
            onChanged: (value) {
              _checkPasswordStrength(value);
            },
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Enter your password',
              hintStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: Colors.black87,
                size: 22,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.black87,
                  size: 22,
                ),
                onPressed: () => setState(() => obscure = !obscure),
              ),
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
        // Password Requirements
        if (passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password must contain:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRequirementItem('At least 8 characters', hasMinLength),
                _buildRequirementItem(
                  'One uppercase letter (A-Z)',
                  hasUppercase,
                ),
                _buildRequirementItem(
                  'One lowercase letter (a-z)',
                  hasLowercase,
                ),
                _buildRequirementItem('One number (0-9)', hasNumber),
                _buildRequirementItem(
                  'One special character (!@#\$%...)',
                  hasSpecialChar,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRequirementItem(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isValid ? Colors.green : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isValid ? Colors.green[700] : Colors.grey[600],
                fontWeight: isValid ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
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
