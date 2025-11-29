import 'package:flutter/material.dart';

/// FlexiMart Brand Color System
/// Modern E-commerce Installation Service App - Light Blue Theme
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // 🎨 Primary Color System - New Theme
  /// Primary: #CD5656 (Main brand color - for primary actions, status success)
  static const Color primary = Color(0xFFCD5656);

  /// Secondary: #AF3E3E (for secondary elements)
  static const Color secondary = Color(0xFFAF3E3E);

  /// Accent: Darker shade of secondary for depth
  static const Color accent = Color(0xFF8B2E2E);
  
  // 🎨 Theme Color Variants
  /// Primary Red: #CD5656
  static const Color redCrimson = Color(0xFFCD5656);
  
  /// Secondary Red: #AF3E3E
  static const Color berryRed = Color(0xFFAF3E3E);
  
  /// Darker Red: #8B2E2E
  static const Color darkWine = Color(0xFF8B2E2E);
  
  /// Bubble Colors (Red Tones)
  static const Color bubble1 = Color(0xFFCD5656);
  static const Color bubble2 = Color(0xFFAF3E3E);
  static const Color bubble3 = Color(0xFF8B2E2E);

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
  /// Background: Light Red Tint #FFF0F0
  static const Color background = Color(0xFFFFF0F0);

  /// White: #FFFFFF (for cards)
  static const Color white = Color(0xFFFFFFFF);

  /// Dashboard Background: Light Red Tint #FFF0F0
  static const Color dashboardBackground = Color(0xFFFFF0F0);

  /// Dashboard Card: Pure white
  static const Color dashboardCard = Color(0xFFFFFFFF);

  /// Surface: White for cards and containers
  static const Color surface = Color(0xFFFFFFFF);

  /// Border: Light gray for dividers
  static const Color border = Color(0xFFE0E0E0);

  // 🎨 Text Colors
  /// Text Primary: Dark blue for maximum readability
  static const Color textPrimary = Color(0xFF1D3B53);

  /// Text Secondary: Dark blue with slight opacity for secondary text
  static const Color textSecondary = Color(0xFF1D3B53);

  /// Light text for hints and placeholders - darker for better readability
  static const Color textHint = Color(0xFF4A6B7F);

  // 🎨 Legacy/Compatibility Colors (mapped to new system)
  /// Error/Alert: Red for errors (using cancelled color)
  static const Color error = Color(0xFFEF4444);

  /// Success: Primary color for success messages
  static const Color success = Color(0xFFCD5656);

  /// Warning: Orange for warnings (using toInstall)
  static const Color warning = Color(0xFFFF8A39);

  /// Customer Primary: Primary color
  static const Color customerPrimary = Color(0xFFCD5656);

  /// Customer Secondary: Secondary color
  static const Color customerSecondary = Color(0xFFAF3E3E);

  /// Cart Background: Light Red Tint
  static const Color cartBackground = Color(0xFFFFF0F0);

  /// Checkout Background: Primary color
  static const Color checkoutBackground = Color(0xFFCD5656);

  // 🛒 Feature-Based Gradients (New Theme)
  /// Main Gradient: Primary → Secondary → Darker
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFCD5656), Color(0xFFAF3E3E), Color(0xFF8B2E2E)],
    stops: [0.0, 0.5, 1.0],
  );
  
  /// Button Gradient: Primary → Secondary
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFFCD5656), Color(0xFFAF3E3E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Welcome Screen → Primary Gradient
  static const LinearGradient welcomeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFCD5656), Color(0xFFAF3E3E), Color(0xFF8B2E2E)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Home Page → Primary Gradient
  static const LinearGradient homeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFCD5656), Color(0xFFAF3E3E), Color(0xFF8B2E2E)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Profile Page → Primary Gradient
  static const LinearGradient profileGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFCD5656), Color(0xFFAF3E3E), Color(0xFF8B2E2E)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Shop Page → Primary Gradient
  static const LinearGradient shopGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFCD5656), Color(0xFFAF3E3E), Color(0xFF8B2E2E)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Promo/Sale Banner → Primary Gradient
  static const LinearGradient promoGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFCD5656), Color(0xFFAF3E3E), Color(0xFF8B2E2E)],
    stops: [0.0, 0.5, 1.0],
  );

  // Price colors
  static const Color priceOriginal = Color(0xFF9E9E9E);
  static const Color priceSale = Color(0xFFCD5656);
  static const Color priceHighlight = Color(0xFFCD5656);

  // Login/Signup colors
  /// Login/Signup background - Clean white
  static const Color loginBackground = Color(0xFFFFFFFF);

  /// Login/Signup primary color highlight
  static const Color loginBlue = Color(0xFFCD5656);
}
