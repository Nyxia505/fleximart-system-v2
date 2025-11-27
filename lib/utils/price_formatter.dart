import 'package:intl/intl.dart';

/// Price Formatter Utility
/// 
/// Provides consistent price formatting across the app
/// Formats prices with commas and two decimal places: ₱1,000.00
class PriceFormatter {
  PriceFormatter._();

  static final NumberFormat _formatter = NumberFormat('#,###.00');

  /// Format price with ₱ symbol, commas, and two decimal places
  /// 
  /// Example:
  /// - formatPrice(1000) returns "₱1,000.00"
  /// - formatPrice(25000) returns "₱25,000.00"
  /// - formatPrice(250000) returns "₱250,000.00"
  static String formatPrice(double price) {
    return '₱${_formatter.format(price)}';
  }

  /// Format price without ₱ symbol (for cases where you want to add it separately)
  /// 
  /// Example:
  /// - formatPriceOnly(1000) returns "1,000.00"
  static String formatPriceOnly(double price) {
    return _formatter.format(price);
  }

  /// Format price with + prefix (for additional charges)
  /// 
  /// Example:
  /// - formatAdditionalPrice(100) returns "+₱100.00"
  static String formatAdditionalPrice(double price) {
    return '+${formatPrice(price)}';
  }
}

