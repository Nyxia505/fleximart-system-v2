import 'package:flutter/material.dart';

/// FlexiMart Brand Color System
/// Modern E-commerce Installation Service App - Soft Green Theme
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // 🎨 Primary Color System - Red-Purple Theme (Matching Sign In/Sign Up)
  /// Primary: Crimson Red #D90747 (Main brand color - for primary actions, status success)
  static const Color primary = Color(0xFFD90747);

  /// Secondary: Deep Berry Red #8B0030 (for secondary elements)
  static const Color secondary = Color(0xFF8B0030);

  /// Accent: Dark Wine Purple #4D0020
  static const Color accent = Color(0xFF4D0020);
  
  // 🎨 Red-Purple Theme Colors
  /// Crimson Red: #D90747
  static const Color redCrimson = Color(0xFFD90747);
  
  /// Berry Red: #8B0030
  static const Color berryRed = Color(0xFF8B0030);
  
  /// Dark Wine: #4D0020
  static const Color darkWine = Color(0xFF4D0020);
  
  /// Bubble Colors
  static const Color bubble1 = Color(0xFFA80038);
  static const Color bubble2 = Color(0xFF660026);
  static const Color bubble3 = Color(0xFF2B0013);

  // 🎨 Status Colors
  /// Pending: Yellow #FFCE43
  static const Color pending = Color(0xFFFFCE43);

  /// To Install: Orange #FF8A39
  static const Color toInstall = Color(0xFFFF8A39);

  /// Cancelled: Red #EF4444
  static const Color cancelled = Color(0xFFEF4444);

  /// Info: Blue #3B82F6
  static const Color info = Color(0xFF3B82F6);

  // 🎨 Neutral Colors
  /// Background: #F6F6F6
  static const Color background = Color(0xFFF6F6F6);

  /// White: #FFFFFF (for cards)
  static const Color white = Color(0xFFFFFFFF);

  /// Dashboard Background: #F6F6F6
  static const Color dashboardBackground = Color(0xFFF6F6F6);

  /// Dashboard Card: Pure white
  static const Color dashboardCard = Color(0xFFFFFFFF);

  /// Surface: White for cards and containers
  static const Color surface = Color(0xFFFFFFFF);

  /// Border: Light gray for dividers
  static const Color border = Color(0xFFE0E0E0);

  // 🎨 Text Colors
  /// Text Primary: #212121
  static const Color textPrimary = Color(0xFF212121);

  /// Text Secondary: #757575
  static const Color textSecondary = Color(0xFF757575);

  /// Light text for hints and placeholders
  static const Color textHint = Color(0xFF9E9E9E);

  // 🎨 Legacy/Compatibility Colors (mapped to new system)
  /// Error/Alert: Red for errors (using cancelled color)
  static const Color error = Color(0xFFEF4444);

  /// Success: Red-Purple for success messages (using primary)
  static const Color success = Color(0xFFD90747);

  /// Warning: Orange for warnings (using toInstall)
  static const Color warning = Color(0xFFFF8A39);

  /// Customer Primary: Crimson Red
  static const Color customerPrimary = Color(0xFFD90747);

  /// Customer Secondary: Deep Berry Red
  static const Color customerSecondary = Color(0xFF8B0030);

  /// Cart Background: Light Red-Purple Tint
  static const Color cartBackground = Color(0xFFF8F1F4);

  /// Checkout Background: Crimson Red
  static const Color checkoutBackground = Color(0xFFD90747);

  // 🛒 Feature-Based Gradients (Red-Purple Theme - Matching Sign In/Sign Up)
  /// Main Gradient: Crimson Red → Deep Berry Red → Dark Wine Purple
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD90747), Color(0xFF8B0030), Color(0xFF4D0020)],
    stops: [0.0, 0.5, 1.0],
  );
  
  /// Button Gradient: #D80F49 → #42001D
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFFD80F49), Color(0xFF42001D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Welcome Screen → Red-Purple Gradient
  static const LinearGradient welcomeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD90747), Color(0xFF8B0030), Color(0xFF4D0020)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Home Page → Red-Purple Gradient
  static const LinearGradient homeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD90747), Color(0xFF8B0030), Color(0xFF4D0020)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Profile Page → Red-Purple Gradient
  static const LinearGradient profileGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD90747), Color(0xFF8B0030), Color(0xFF4D0020)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Shop Page → Red-Purple Gradient
  static const LinearGradient shopGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD90747), Color(0xFF8B0030), Color(0xFF4D0020)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Promo/Sale Banner → Red-Purple Gradient
  static const LinearGradient promoGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD90747), Color(0xFF8B0030), Color(0xFF4D0020)],
    stops: [0.0, 0.5, 1.0],
  );

  // Price colors
  static const Color priceOriginal = Color(0xFF9E9E9E);
  static const Color priceSale = Color(0xFFD90747);
  static const Color priceHighlight = Color(0xFFD90747);

  // Login/Signup colors
  /// Login/Signup background - Clean white
  static const Color loginBackground = Color(0xFFFFFFFF);

  /// Login/Signup red-purple highlight
  static const Color loginBlue = Color(0xFFD90747);
}
