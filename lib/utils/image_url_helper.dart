import 'dart:core';

/// Helper utility for handling image URLs in Flutter Web and Mobile.
/// Ensures URLs are properly URI-encoded for web compatibility.
class ImageUrlHelper {
  /// Encodes a URL to ensure it works correctly on Flutter Web.
  /// 
  /// If the URL is already a valid URI, it will be parsed and re-encoded.
  /// This ensures special characters are properly encoded.
  static String encodeUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    try {
      // Parse the URI to validate and encode it properly
      final uri = Uri.parse(url);
      // Return the encoded URI string
      return uri.toString();
    } catch (e) {
      // If parsing fails, try to encode the full string
      // This handles cases where the URL might have unencoded characters
      try {
        return Uri.encodeFull(url);
      } catch (_) {
        // If all else fails, return the original URL
        return url;
      }
    }
  }

  /// Appends a cache-bust query param without re-encoding the URL path.
  static String withCacheBust(String url, String token) {
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params['_t'] = token;
    return uri.replace(queryParameters: params).toString();
  }

  /// Decodes a Firebase Storage object path (handles double-encoded segments).
  static String decodeFirebaseStoragePath(String pathOrUrl) {
    var path = pathOrUrl.trim();
    if (path.contains('firebasestorage.googleapis.com')) {
      final uri = Uri.parse(path);
      final match = RegExp(r'/o/(.+)$').firstMatch(uri.path);
      if (match != null) {
        path = match.group(1)!;
      }
    }
    for (var i = 0; i < 3; i++) {
      final decoded = Uri.decodeComponent(path);
      if (decoded == path) break;
      path = decoded;
    }
    return path;
  }

  /// True when URL path looks double-encoded (e.g. %252F instead of %2F).
  static bool isDoubleEncodedFirebaseUrl(String url) {
    return url.contains('%252F') || url.contains('%2525');
  }

  /// Checks if a URL is valid and can be used for image loading.
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && 
             (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }
}

