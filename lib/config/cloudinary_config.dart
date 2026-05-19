import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/services.dart' show rootBundle;

/// Cloudinary settings for unsigned product image uploads.
/// Copy [assets/config/cloudinary.example.json] to cloudinary.json and set cloudName.
class CloudinaryConfig {
  CloudinaryConfig._();

  static const String _assetPath = 'assets/config/cloudinary.json';
  static const String _exampleAssetPath = 'assets/config/cloudinary.example.json';

  static const String defaultUploadPreset = 'flutter_upload';
  static const String defaultFolder = 'products';

  static String cloudName = '';
  static String uploadPreset = defaultUploadPreset;

  static bool _loaded = false;

  static bool get isConfigured => cloudName.trim().isNotEmpty;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _loadFromAssets();
    _loaded = true;
  }

  static Future<void> _loadFromAssets() async {
    for (final path in [_assetPath, _exampleAssetPath]) {
      try {
        final raw = await rootBundle.loadString(path);
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _applyMap(map);
        if (isConfigured) {
          if (kDebugMode) {
            debugPrint(
              '☁️ Cloudinary config loaded from $path (cloud: $cloudName)',
            );
          }
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Could not load $path: $e');
        }
      }
    }

    if (kDebugMode && !isConfigured) {
      debugPrint(
        '⚠️ Cloudinary not configured. Copy assets/config/cloudinary.example.json '
        'to assets/config/cloudinary.json and set cloudName.',
      );
    }
  }

  static void _applyMap(Map<String, dynamic> map) {
    final name = map['cloudName'] as String?;
    if (name != null &&
        name.trim().isNotEmpty &&
        !name.contains('YOUR_CLOUDINARY')) {
      cloudName = name.trim();
    }

    final preset = map['uploadPreset'] as String?;
    if (preset != null && preset.trim().isNotEmpty) {
      uploadPreset = preset.trim();
    }
  }
}
