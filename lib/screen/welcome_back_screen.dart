import 'package:flutter/material.dart';
import 'dart:math' as math;

class WelcomeBackScreen extends StatelessWidget {
  const WelcomeBackScreen({super.key});

  // Exact colors from reference image (for background)
  static const Color deepRed = Color(0xFF7A002F);
  static const Color crimson = Color(0xFFBD003B);
  static const Color magenta = Color(0xFF9B0034);
  static const Color darkPurple = Color(0xFF3E0024);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          CustomPaint(painter: BubblePainter(), size: Size.infinite),
          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // Welcome to text at the top
                  _buildWelcomeTo(),
                  const SizedBox(height: 24),
                  // FlexiMart Logo
                  _buildLogo(),
                  const SizedBox(height: 24),
                  // FlexiMart Branding
                  _buildBranding(),
                  const SizedBox(height: 60),
                  // Buttons (directly on gradient, no white card)
                  _buildButtons(context),
                  const SizedBox(height: 40),
                  // Social Media Section
                  _buildSocialMediaSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/welcome screen logo.png.png',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Center(
                child: Text(
                  'FM',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: crimson,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        const Text(
          'FlexiMart',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Your trusted doors and windows provider",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 0.5,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWelcomeTo() {
    return const Text(
      'Welcome to',
      style: TextStyle(
        fontSize: 35,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.5,
        height: 1.2,
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sign In Button
        _buildSignInButton(context),
        const SizedBox(height: 16),
        // Sign Up Button
        _buildSignUpButton(context),
      ],
    );
  }

  Widget _buildSignInButton(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/login');
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'Sign in',
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

  Widget _buildSignUpButton(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color.fromARGB(255, 85, 13, 13),
            const Color.fromARGB(255, 0, 0, 0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 241, 241, 241).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/signup');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
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

  Widget _buildSocialMediaSection(BuildContext context) {
    return Column(
      children: [
        // "Login with social media" text
        const Text(
          'Login with social media',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        // Social Media Icons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialIcon(context, Icons.g_mobiledata, 'Google'),
            const SizedBox(width: 20),
            _buildSocialIcon(context, Icons.facebook, 'Facebook'),
            const SizedBox(width: 20),
            _buildSocialIcon(context, Icons.apple, 'Apple'),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialIcon(
    BuildContext context,
    IconData icon,
    String platform,
  ) {
    return GestureDetector(
      onTap: () => _showComingSoonDialog(context, platform),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: crimson.withOpacity(0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String platform) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Coming Soon',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Text(
          '$platform login will be available soon!',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: crimson)),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for FM Logo with Rainbow Gradient
class FMLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw white background circle with inner shadow effect
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, whitePaint);

    // Create rainbow gradient (blue -> teal -> green -> yellow -> orange -> red)
    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: -math.pi / 2, // Start from top
      colors: const [
        Color(0xFF1E40AF), // Dark blue (top-left for F)
        Color(0xFF3B82F6), // Blue
        Color(0xFF06B6D4), // Cyan/Teal
        Color(0xFF10B981), // Green
        Color(0xFF84CC16), // Lime green
        Color(0xFFFBBF24), // Yellow (top-right for M)
        Color(0xFFF97316), // Orange
        Color(0xFFEF4444), // Red
        Color(0xFFDC2626), // Dark red
        Color(0xFF7A002F), // Deep red
        Color(0xFF1E40AF), // Back to dark blue
      ],
      stops: const [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.85, 0.95, 1.0],
    );

    final gradientPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    // Draw F shape (left side) - simplified and flowing
    final fPath = Path();
    // Main vertical stroke of F
    fPath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 42, center.dy - 50, 12, 80),
        const Radius.circular(6),
      ),
    );

    // Top horizontal bar
    fPath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 42, center.dy - 50, 40, 12),
        const Radius.circular(6),
      ),
    );

    // Middle horizontal bar (passes over M)
    fPath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 42, center.dy - 20, 35, 12),
        const Radius.circular(6),
      ),
    );

    // Draw M shape (right side) - simplified and flowing
    final mPath = Path();
    // Left vertical stroke
    mPath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 2, center.dy - 50, 12, 80),
        const Radius.circular(6),
      ),
    );

    // Right vertical stroke
    mPath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx + 30, center.dy - 50, 12, 80),
        const Radius.circular(6),
      ),
    );

    // Middle connecting part (forms the M peaks)
    mPath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx + 10, center.dy - 15, 20, 12),
        const Radius.circular(6),
      ),
    );

    // Top connecting part
    mPath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 2, center.dy - 50, 44, 12),
        const Radius.circular(6),
      ),
    );

    // Combine paths - F and M together
    final combinedPath = Path.combine(PathOperation.union, fPath, mPath);

    // Draw with gradient
    canvas.drawPath(combinedPath, gradientPaint);

    // Add subtle highlight for 3D effect
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(combinedPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
