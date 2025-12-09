import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../utils/image_url_helper.dart';

/// Service to migrate old Firebase Storage URLs from appspot.com to firebasestorage.app
/// and regenerate download URLs using getDownloadURL()
class ImageUrlMigrationService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if a URL contains the old appspot.com bucket
  bool isOldBucketUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('appspot.com') ||
        url.contains('fleximart-system.appspot.com');
  }

  /// Extract storage path from a Firebase Storage URL
  /// Handles both old (appspot.com) and new (firebasestorage.app) URLs
  String? extractStoragePath(String url) {
    try {
      if (!url.contains('firebasestorage.googleapis.com')) {
        return null;
      }

      final uri = Uri.parse(url);
      final pathMatch = RegExp(r'/o/(.+)\?').firstMatch(uri.path);
      if (pathMatch == null) {
        return null;
      }

      final encodedPath = pathMatch.group(1)!;
      return Uri.decodeComponent(encodedPath);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to extract storage path from URL: $url - $e');
      }
      return null;
    }
  }

  /// Get a fresh download URL from a storage path or old URL
  /// Always uses getDownloadURL() to ensure valid URL with new bucket
  Future<String?> getFreshDownloadUrl(String pathOrUrl) async {
    try {
      String? storagePath;

      // Check if it's a URL (old or new)
      if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
        // Extract path from URL
        storagePath = extractStoragePath(pathOrUrl);
        if (storagePath == null) {
          // Not a Firebase Storage URL, return as-is
          return pathOrUrl;
        }
      } else {
        // It's already a storage path
        storagePath = pathOrUrl;
      }

      // Get fresh download URL using getDownloadURL()
      final storageRef = _storage.ref().child(storagePath);
      final downloadUrl = await storageRef.getDownloadURL();

      // Encode the URL for web compatibility
      return ImageUrlHelper.encodeUrl(downloadUrl);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to get fresh download URL: $e');
      }
      return null;
    }
  }

  /// Migrate a single image URL from old bucket to new bucket
  /// Returns the new download URL or null if migration fails
  Future<String?> migrateImageUrl(String oldUrl) async {
    try {
      // Check if it's an old bucket URL
      if (!isOldBucketUrl(oldUrl)) {
        // Not an old URL, just get fresh download URL
        return await getFreshDownloadUrl(oldUrl);
      }

      // Extract storage path from old URL
      final storagePath = extractStoragePath(oldUrl);
      if (storagePath == null) {
        if (kDebugMode) {
          debugPrint('❌ Could not extract storage path from old URL: $oldUrl');
        }
        return null;
      }

      // Get fresh download URL using new bucket
      final newUrl = await getFreshDownloadUrl(storagePath);

      if (kDebugMode && newUrl != null) {
        debugPrint('✅ Migrated URL: $oldUrl -> $newUrl');
      }

      return newUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error migrating image URL: $e');
      }
      return null;
    }
  }

  /// Migrate all image URLs in a Firestore document
  /// Updates fields that contain image URLs
  Future<bool> migrateDocumentUrls(
    String collection,
    String documentId,
    List<String> imageFields,
  ) async {
    try {
      final docRef = _firestore.collection(collection).doc(documentId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      final updates = <String, dynamic>{};
      bool hasUpdates = false;

      for (final field in imageFields) {
        final url = data[field] as String?;
        if (url != null && isOldBucketUrl(url)) {
          final newUrl = await migrateImageUrl(url);
          if (newUrl != null && newUrl != url) {
            updates[field] = newUrl;
            hasUpdates = true;
          }
        }
      }

      if (hasUpdates) {
        await docRef.update(updates);
        if (kDebugMode) {
          debugPrint('✅ Migrated document: $collection/$documentId');
        }
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error migrating document URLs: $e');
      }
      return false;
    }
  }

  /// Migrate all image URLs in a collection
  /// Useful for bulk migration of orders, products, etc.
  Future<int> migrateCollectionUrls(
    String collection,
    List<String> imageFields, {
    int? limit,
  }) async {
    try {
      Query query = _firestore.collection(collection);
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      int migratedCount = 0;

      for (final doc in snapshot.docs) {
        final success = await migrateDocumentUrls(
          collection,
          doc.id,
          imageFields,
        );
        if (success) {
          migratedCount++;
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Migrated $migratedCount documents in $collection');
      }

      return migratedCount;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error migrating collection URLs: $e');
      }
      return 0;
    }
  }
}
