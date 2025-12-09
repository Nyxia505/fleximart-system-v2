import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io' show File;

/// Centralized service for Firebase Storage uploads that works on both web and mobile.
/// Always uses getDownloadURL() to ensure valid download URLs.
class FirebaseStorageService {
  /// Upload image bytes to Firebase Storage and return download URL.
  /// Works on both web and mobile.
  /// 
  /// [imageBytes] - The image data as bytes
  /// [storagePath] - The storage path (e.g., 'products/image.jpg' or 'profile_images/user123.jpg')
  /// [contentType] - MIME type (default: 'image/jpeg')
  /// 
  /// Returns the download URL from getDownloadURL()
  /// Throws Exception on error
  static Future<String> uploadImageBytes({
    required Uint8List imageBytes,
    required String storagePath,
    String contentType = 'image/jpeg',
    int timeoutSeconds = 60,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('📤 Uploading image to: $storagePath');
      }

      // Create storage reference
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      // Upload using putData (works on both web and mobile)
      final uploadTask = storageRef.putData(
        imageBytes,
        SettableMetadata(
          contentType: contentType,
          cacheControl: 'public, max-age=31536000',
        ),
      );

      // Wait for upload to complete with timeout
      await uploadTask.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          try {
            uploadTask.cancel();
          } catch (_) {
            // Ignore cancellation errors
          }
          throw Exception(
            'Upload timeout. Please check your internet connection.',
          );
        },
      );

      if (kDebugMode) {
        debugPrint('✅ Upload completed, getting download URL...');
      }

      // Always use getDownloadURL() to get the correct download URL
      final downloadUrl = await storageRef.getDownloadURL().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Failed to get download URL. Please try again.');
        },
      );

      if (downloadUrl.isEmpty) {
        throw Exception('Invalid download URL received');
      }

      if (kDebugMode) {
        debugPrint('✅ Download URL obtained: $downloadUrl');
      }

      return downloadUrl;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      
      // Provide user-friendly error messages
      if (errorStr.contains('timeout') || errorStr.contains('deadline exceeded')) {
        throw Exception(
          'Upload timeout. Please check your internet connection.',
        );
      } else if (errorStr.contains('permission') ||
          errorStr.contains('unauthorized') ||
          errorStr.contains('403')) {
        throw Exception(
          'Permission denied. Please check Firebase Storage rules.',
        );
      } else if (errorStr.contains('network') ||
          errorStr.contains('connection') ||
          errorStr.contains('socket')) {
        throw Exception(
          'Network error. Please check your internet connection.',
        );
      } else if (errorStr.contains('cancel')) {
        throw Exception('Upload cancelled.');
      }
      
      // Re-throw with context
      throw Exception('Upload failed: ${e.toString()}');
    }
  }

  /// Upload image file to Firebase Storage and return download URL.
  /// Works on mobile only (uses File).
  /// 
  /// [imageFile] - The image file
  /// [storagePath] - The storage path (e.g., 'products/image.jpg')
  /// [contentType] - MIME type (default: 'image/jpeg')
  /// 
  /// Returns the download URL from getDownloadURL()
  /// Throws Exception on error
  static Future<String> uploadImageFile({
    required File imageFile,
    required String storagePath,
    String contentType = 'image/jpeg',
    int timeoutSeconds = 60,
  }) async {
    if (kIsWeb) {
      throw Exception(
        'uploadImageFile() is not supported on web. Use uploadImageBytes() instead.',
      );
    }

    try {
      if (kDebugMode) {
        debugPrint('📤 Uploading image file to: $storagePath');
      }

      // Create storage reference
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      // Upload using putFile (mobile only)
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: contentType,
          cacheControl: 'public, max-age=31536000',
        ),
      );

      // Wait for upload to complete with timeout
      await uploadTask.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          try {
            uploadTask.cancel();
          } catch (_) {
            // Ignore cancellation errors
          }
          throw Exception(
            'Upload timeout. Please check your internet connection.',
          );
        },
      );

      if (kDebugMode) {
        debugPrint('✅ Upload completed, getting download URL...');
      }

      // Always use getDownloadURL() to get the correct download URL
      final downloadUrl = await storageRef.getDownloadURL().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Failed to get download URL. Please try again.');
        },
      );

      if (downloadUrl.isEmpty) {
        throw Exception('Invalid download URL received');
      }

      if (kDebugMode) {
        debugPrint('✅ Download URL obtained: $downloadUrl');
      }

      return downloadUrl;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      
      // Provide user-friendly error messages
      if (errorStr.contains('timeout') || errorStr.contains('deadline exceeded')) {
        throw Exception(
          'Upload timeout. Please check your internet connection.',
        );
      } else if (errorStr.contains('permission') ||
          errorStr.contains('unauthorized') ||
          errorStr.contains('403')) {
        throw Exception(
          'Permission denied. Please check Firebase Storage rules.',
        );
      } else if (errorStr.contains('network') ||
          errorStr.contains('connection') ||
          errorStr.contains('socket')) {
        throw Exception(
          'Network error. Please check your internet connection.',
        );
      } else if (errorStr.contains('cancel')) {
        throw Exception('Upload cancelled.');
      }
      
      // Re-throw with context
      throw Exception('Upload failed: ${e.toString()}');
    }
  }
}

