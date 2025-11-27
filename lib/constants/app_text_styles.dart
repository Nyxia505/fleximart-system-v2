import 'package:flutter/material.dart';

/// Typography System for FlexiMart
/// Using Inter/Poppins font family with specified sizes
class AppTextStyles {
  AppTextStyles._(); // Private constructor

  // Font Family
  static const String fontFamily = 'Poppins'; // Fallback to system if not available

  // Headings (18-24px bold)
  static TextStyle heading1({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: color ?? const Color(0xFF212121),
        letterSpacing: -0.5,
      );

  static TextStyle heading2({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: color ?? const Color(0xFF212121),
        letterSpacing: -0.3,
      );

  static TextStyle heading3({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color ?? const Color(0xFF212121),
        letterSpacing: -0.2,
      );

  // Body (14-16px regular)
  static TextStyle bodyLarge({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: color ?? const Color(0xFF212121),
        letterSpacing: 0.1,
      );

  static TextStyle bodyMedium({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: color ?? const Color(0xFF212121),
        letterSpacing: 0.1,
      );

  // Captions (12px)
  static TextStyle caption({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: color ?? const Color(0xFF757575),
        letterSpacing: 0.2,
      );

  // Button Text
  static TextStyle buttonLarge({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color ?? Colors.white,
        letterSpacing: 0.5,
      );

  static TextStyle buttonMedium({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color ?? Colors.white,
        letterSpacing: 0.3,
      );

  // Status Text
  static TextStyle status({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color ?? const Color(0xFF212121),
        letterSpacing: 0.3,
      );
}

