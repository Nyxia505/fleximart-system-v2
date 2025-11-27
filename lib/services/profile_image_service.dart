import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Cross-platform profile image service for Web and Mobile.
///
/// - On Web: uses [putData] with bytes
/// - On Mobile: uses [putFile] with a [File]
class ProfileImageService {
  final ImagePicker picker = ImagePicker();
  final User? user = FirebaseAuth.instance.currentUser;

  /// Pick an image (gallery) and upload to Firebase Storage under:
  ///   `profile_pictures/{uid}.jpg`
  ///
  /// Also saves the URL to Firestore at:
  ///   `users/{uid}.profilePic`
  ///
  /// Returns the download URL, or null on failure/cancel.
  Future<String?> pickAndUploadProfileImage() async {
    try {
      if (user == null) {
        throw Exception('User not logged in');
      }

      // 1. Pick image from gallery
      final XFile? file =
          await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return null;

      // 2. Build storage reference (align with existing Storage rules: profile_images/{uid}.jpg)
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user!.uid}.jpg');

      // 3. Upload - different strategy for Web vs Mobile
      if (kIsWeb) {
        // WEB: upload as bytes
        Uint8List bytes = await file.readAsBytes();
        await storageRef.putData(bytes);
      } else {
        // MOBILE: upload from File
        File imageFile = File(file.path);
        await storageRef.putFile(imageFile);
      }

      // 4. Get download URL
      final String downloadUrl = await storageRef.getDownloadURL();

      // 5. Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set(
        {
          'profilePic': downloadUrl,
          // Also keep legacy field in sync for existing code paths
          'profileImageUrl': downloadUrl,
        },
        SetOptions(merge: true),
      );

      return downloadUrl;
    } catch (e) {
      // ignore: avoid_print
      print('Upload error: $e');
      return null;
    }
  }
}

