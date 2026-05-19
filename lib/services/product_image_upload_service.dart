import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:image_picker/image_picker.dart';

import '../config/cloudinary_config.dart';
import 'cloudinary_service.dart';
import 'firebase_storage_service.dart';

/// Uploads product photos: Firebase Storage first, Cloudinary if configured as fallback.
class ProductImageUploadService {
  ProductImageUploadService._();

  static Future<String> uploadProductImage(XFile file) async {
    try {
      return await _uploadToFirebaseStorage(file);
    } catch (firebaseError) {
      if (kDebugMode) {
        debugPrint('⚠️ Firebase product image upload failed: $firebaseError');
      }

      await CloudinaryConfig.ensureLoaded();
      if (CloudinaryConfig.isConfigured) {
        if (kDebugMode) {
          debugPrint('☁️ Trying Cloudinary fallback for product image...');
        }
        final cloudinary = CloudinaryService(
          cloudName: CloudinaryConfig.cloudName,
          uploadPreset: CloudinaryConfig.uploadPreset,
        );
        return cloudinary.uploadImage(
          file,
          folder: CloudinaryConfig.defaultFolder,
        );
      }

      throw Exception(
        'Could not upload product image. Check your connection and try again, '
        'paste an Image URL, or configure Cloudinary in assets/config/cloudinary.json.',
      );
    }
  }

  static Future<String> _uploadToFirebaseStorage(XFile file) async {
    final bytes = await file.readAsBytes();
    final ext = _extensionFromName(file.name);
    final storagePath =
        'product_images/product_${DateTime.now().millisecondsSinceEpoch}.$ext';

    return FirebaseStorageService.uploadImageBytes(
      imageBytes: bytes,
      storagePath: storagePath,
      contentType: _contentTypeForExtension(ext),
    );
  }

  static String _extensionFromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot >= name.length - 1) return 'jpg';
    final ext = name.substring(dot + 1).toLowerCase();
    if (ext == 'jpeg' || ext == 'jpg' || ext == 'png' || ext == 'webp') {
      return ext == 'jpeg' ? 'jpg' : ext;
    }
    return 'jpg';
  }

  static String _contentTypeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
