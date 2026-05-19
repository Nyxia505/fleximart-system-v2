import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Shared gradient + bubble background for auth screens.
class AuthScreenShell extends StatelessWidget {
  final Widget child;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  const AuthScreenShell({
    super.key,
    required this.child,
    this.scrollable = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPad = keyboard > 0 ? keyboard + 24.0 : 32.0;
    final body = scrollable
        ? SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad),
            child: child,
          )
        : Padding(padding: padding, child: child);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.accent,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          CustomPaint(painter: _AuthBubblePainter(), size: Size.infinite),
          SafeArea(child: Center(child: body)),
        ],
      ),
    );
  }
}

/// White card used on auth forms.
class AuthFormCard extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AuthFormCard({
    super.key,
    required this.child,
    this.maxWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _AuthBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42);
    for (var i = 0; i < 18; i++) {
      final radius = 20.0 + random.nextDouble() * 80;
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      paint.color = Colors.white.withValues(alpha: 0.04 + random.nextDouble() * 0.06);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
