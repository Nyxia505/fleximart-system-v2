import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, debugPrint, kIsWeb;
import 'package:http/http.dart' as http;

import '../config/storage_proxy_config.dart';

import 'image_url_helper.dart';

/// Loads Firebase Storage image bytes (works on web without CORS issues).
class StorageImageLoader {
  static const int maxProfileBytes = 5 * 1024 * 1024;
  static const int maxChatBytes = 10 * 1024 * 1024;
  static const int maxProductBytes = 8 * 1024 * 1024;

  static Reference profileImageRef(String userId) {
    return FirebaseStorage.instance.ref('profile_images/$userId.jpg');
  }

  /// Resolves a download URL or storage path to a Storage object path.
  static String? storagePathFrom(String pathOrUrl) {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('firebasestorage.googleapis.com')) {
      return ImageUrlHelper.decodeFirebaseStoragePath(trimmed);
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return null;
    }
    return trimmed;
  }

  /// Load profile image bytes by user id (most reliable).
  static Future<Uint8List?> loadProfileBytes(String userId) async {
    if (userId.isEmpty) return null;
    if (kIsWeb) {
      final viaProxy = await loadBytesViaProxy(
        'profile_images/$userId.jpg',
        maxBytes: maxProfileBytes,
      );
      if (viaProxy != null && viaProxy.isNotEmpty) return viaProxy;
    }
    try {
      return await profileImageRef(userId).getData(maxProfileBytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ StorageImageLoader profile $userId: $e');
      }
      return null;
    }
  }

  static Future<Uint8List?> loadBytes(
    String pathOrUrl, {
    int maxBytes = maxProfileBytes,
  }) async {
    final storagePath = storagePathFrom(pathOrUrl);
    if (storagePath == null || storagePath.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref(storagePath).getData(maxBytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ StorageImageLoader: $e (path: $storagePath)');
      }
      return null;
    }
  }

  /// Loads bytes via Cloud Function on web (Storage CORS not required).
  static Future<Uint8List?> loadBytesViaProxy(
    String pathOrUrl, {
    int maxBytes = maxProfileBytes,
  }) async {
    final storagePath = storagePathFrom(pathOrUrl);
    if (storagePath == null || storagePath.isEmpty) return null;
    try {
      final url = StorageProxyConfig.imageUrl(storagePath);
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        if (bytes.length > maxBytes) {
          if (kDebugMode) {
            debugPrint(
              '❌ StorageImageLoader proxy: file too large (${bytes.length})',
            );
          }
          return null;
        }
        return bytes;
      }
      if (kDebugMode) {
        debugPrint(
          '❌ StorageImageLoader proxy HTTP ${response.statusCode} ($storagePath)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ StorageImageLoader proxy: $e (path: $storagePath)');
      }
    }
    return null;
  }

  static Future<Uint8List?> loadProductBytes(String pathOrUrl) async {
    if (kIsWeb) {
      final viaProxy = await loadBytesViaProxy(
        pathOrUrl,
        maxBytes: maxProductBytes,
      );
      if (viaProxy != null && viaProxy.isNotEmpty) return viaProxy;
    }
    return loadBytes(pathOrUrl, maxBytes: maxProductBytes);
  }

  static Future<Uint8List?> loadChatBytes(String pathOrUrl) async {
    if (kIsWeb) {
      final viaProxy = await loadBytesViaProxy(
        pathOrUrl,
        maxBytes: maxChatBytes,
      );
      if (viaProxy != null && viaProxy.isNotEmpty) return viaProxy;
    }
    return loadBytes(pathOrUrl, maxBytes: maxChatBytes);
  }

  static Future<String?> freshDownloadUrl(String pathOrUrl) async {
    final storagePath = storagePathFrom(pathOrUrl);
    if (storagePath == null || storagePath.isEmpty) {
      if (pathOrUrl.startsWith('http')) return pathOrUrl;
      return null;
    }
    try {
      return await FirebaseStorage.instance.ref(storagePath).getDownloadURL();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ StorageImageLoader URL: $e');
      return null;
    }
  }

  static Future<String?> freshProfileDownloadUrl(String userId) async {
    if (userId.isEmpty) return null;
    try {
      return await profileImageRef(userId).getDownloadURL();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ StorageImageLoader profile URL: $e');
      return null;
    }
  }
}
