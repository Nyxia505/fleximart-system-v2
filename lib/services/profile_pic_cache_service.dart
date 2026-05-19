import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// Persists profile picture URL (and optional preview bytes) per user on device.
class ProfilePicCacheService {
  ProfilePicCacheService._();

  static String _urlKey(String uid) => 'profile_pic_url_$uid';
  static String _bytesKey(String uid) => 'profile_pic_bytes_$uid';
  static const int _maxCachedBytes = 400 * 1024;

  static Future<void> save({
    required String uid,
    required String downloadUrl,
    Uint8List? previewBytes,
  }) async {
    if (uid.isEmpty || downloadUrl.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_urlKey(uid), downloadUrl);
      if (previewBytes != null &&
          previewBytes.isNotEmpty &&
          previewBytes.length <= _maxCachedBytes) {
        await prefs.setString(_bytesKey(uid), base64Encode(previewBytes));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ProfilePicCacheService.save: $e');
    }
  }

  static Future<String?> getCachedUrl(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_urlKey(uid));
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> getCachedBytes(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_bytesKey(uid));
      if (encoded == null || encoded.isEmpty) return null;
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_urlKey(uid));
      await prefs.remove(_bytesKey(uid));
    } catch (_) {}
  }
}
