import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Profile Picture Service
/// 
/// Handles picking images, uploading to Firebase Storage, and saving URLs to Firestore.
class ProfilePictureService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Pick an image from gallery or camera
  /// 
  /// Returns the picked XFile, or null if user cancelled.
  Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      return image;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Upload image to Firebase Storage
  /// 
  /// Uploads the image file to `profile_images/{uid}.jpg`
  /// Returns the download URL.
  Future<String> uploadImage({
    required XFile imageFile,
    required String uid,
  }) async {
    try {
      // Build storage reference
      final Reference storageRef = _storage
          .ref()
          .child('profile_images')
          .child('$uid.jpg');

      // Upload based on platform
      if (kIsWeb) {
        // Web: upload as bytes
        final Uint8List imageBytes = await imageFile.readAsBytes();
        await storageRef.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // Mobile: upload from File
        final File file = File(imageFile.path);
        await storageRef.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      // Get download URL
      final String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Save profile picture URL to Firestore
  /// 
  /// Saves the download URL to `users/{uid}/profilePic`
  Future<void> saveProfilePic({
    required String uid,
    required String downloadUrl,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
        'profilePic': downloadUrl,
      });
    } catch (e) {
      throw Exception('Failed to save profile picture URL: $e');
    }
  }

  /// Complete profile picture update flow
  /// 
  /// 1. Shows image source selection dialog (camera or gallery)
  /// 2. Picks the image
  /// 3. Uploads to Firebase Storage
  /// 4. Saves URL to Firestore
  /// 
  /// Returns the download URL on success, null on cancel/failure.
  Future<String?> updateProfilePicture({
    required String uid,
    required BuildContext context,
  }) async {
    try {
      // 1. Show image source selection
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return null;

      // 2. Pick image
      final XFile? imageFile = await pickImage(source: source);
      if (imageFile == null) return null;

      // 3. Show loading indicator
      if (!context.mounted) return null;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 4. Upload image
      final String downloadUrl = await uploadImage(
        imageFile: imageFile,
        uid: uid,
      );

      // 5. Save to Firestore
      await saveProfilePic(
        uid: uid,
        downloadUrl: downloadUrl,
      );

      // 6. Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      return downloadUrl;
    } catch (e) {
      // Close loading dialog if open
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }
}

