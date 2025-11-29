import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Dashboard Theme matching Sign In screen
class DashboardTheme {
  DashboardTheme._();

  // New theme gradient colors
  static const Color gradientStart = Color(0xFFCD5656);
  static const Color gradientMiddle = Color(0xFFAF3E3E);
  static const Color gradientEnd = Color(0xFF8B2E2E);

  // Gradient for headers and top bars
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientMiddle, gradientEnd],
    stops: [0.0, 0.5, 1.0],
  );

  // Button text style
  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: Colors.white,
  );

  // Title text style (high contrast white)
  static const TextStyle titleTextStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  // Label text style
  static const TextStyle labelTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  // Build bubble overlay widget
  static Widget buildBubbleOverlay() {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth.isInfinite || constraints.maxHeight.isInfinite) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            painter: _BubblePainter(),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          );
        },
      ),
    );
  }
  
  // Build bubble overlay for Stack contexts (use Positioned.fill)
  static Widget buildBubbleOverlayForStack() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _BubblePainter(),
        ),
      ),
    );
  }
}

// Custom Painter for Bubble Overlay
class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    
    // Theme bubble colors
    final bubbleColors = [
      const Color(0xFFCD5656).withOpacity(0.3),
      const Color(0xFFAF3E3E).withOpacity(0.25),
      const Color(0xFF8B2E2E).withOpacity(0.2),
    ];

    // Draw multiple glossy bubbles with soft blue tones
    for (int i = 0; i < 10; i++) {
      final x = size.width * (0.1 + random.nextDouble() * 0.8);
      final y = size.height * (0.1 + random.nextDouble() * 0.8);
      final radius = 50 + random.nextDouble() * 100;
      
      final paint = Paint()
        ..color = bubbleColors[i % bubbleColors.length]
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

