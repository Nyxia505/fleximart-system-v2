import 'package:flutter/material.dart';

/// Profile Picture Placeholder Widget
/// 
/// Displays a placeholder for profile pictures matching customer profile design:
/// - Light gray circular container with border
/// - Person icon in center (medium gray)
class ProfilePicturePlaceholder extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;

  const ProfilePicturePlaceholder({
    super.key,
    this.size = 80,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.grey[300];
    final border = borderColor ?? Colors.grey[400]!;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(
          color: border,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: size * 0.5,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}

/// Compact Profile Picture Placeholder for smaller sizes (like in chat list)
/// Matches customer profile design with light gray background
class CompactProfilePicturePlaceholder extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;

  const CompactProfilePicturePlaceholder({
    super.key,
    this.size = 56,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.grey[300];
    final border = borderColor ?? Colors.grey[400]!;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(
          color: border,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: size * 0.5,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}

