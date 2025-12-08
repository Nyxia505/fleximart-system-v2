import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Profile Picture Placeholder Widget
/// 
/// Displays a "Coming Soon" placeholder for profile pictures matching customer profile design:
/// - Light gray circular container with border
/// - Person icon in center (medium gray)
/// - Camera icon overlay in bottom-right corner (red circle with white camera)
class ProfilePicturePlaceholder extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? cameraIconColor;

  const ProfilePicturePlaceholder({
    super.key,
    this.size = 80,
    this.backgroundColor,
    this.borderColor,
    this.cameraIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.grey[300];
    final border = borderColor ?? Colors.grey[400]!;
    final cameraColor = cameraIconColor ?? AppColors.primary;
    
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
      child: Stack(
        children: [
          // Person icon in center
          Center(
            child: Icon(
              Icons.person,
              size: size * 0.5,
              color: Colors.grey[500],
            ),
          ),
          // Camera icon overlay in bottom-right
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.35,
              height: size * 0.35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cameraColor,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.camera_alt,
                size: size * 0.2,
                color: Colors.white,
              ),
            ),
          ),
        ],
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
  final Color? cameraIconColor;

  const CompactProfilePicturePlaceholder({
    super.key,
    this.size = 56,
    this.backgroundColor,
    this.borderColor,
    this.cameraIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.grey[300];
    final border = borderColor ?? Colors.grey[400]!;
    final cameraColor = cameraIconColor ?? AppColors.primary;
    
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
      child: Stack(
        children: [
          // Person icon in center
          Center(
            child: Icon(
              Icons.person,
              size: size * 0.5,
              color: Colors.grey[500],
            ),
          ),
          // Camera icon overlay in bottom-right
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.35,
              height: size * 0.35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cameraColor,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.camera_alt,
                size: size * 0.2,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

