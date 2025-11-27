import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

/// Service for picking images, converting to Base64, and storing in Firestore
class ImageStorageService {
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Image picker instance
  final ImagePicker _picker = ImagePicker();
  
  // Collection name for storing images
  static const String _imagesCollection = 'images';

  /// Pick an image from gallery, convert to Base64, and store in Firestore
  /// 
  /// Returns: The document ID of the stored image, or null if operation failed
  Future<String?> pickAndStoreImage() async {
    try {
      // Step 1: Pick image from gallery
      debugPrint('📷 Opening image picker...');
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Compress to 85% quality to reduce size
      );

      // Check if user cancelled the picker
      if (pickedFile == null) {
        debugPrint('❌ User cancelled image selection');
        return null;
      }

      debugPrint('✅ Image selected: ${pickedFile.path}');

      // Step 2: Read image file as bytes
      debugPrint('📖 Reading image file...');
      final File imageFile = File(pickedFile.path);
      final List<int> imageBytes = await imageFile.readAsBytes();
      
      // Get file size for logging
      final double fileSizeInMB = imageBytes.length / (1024 * 1024);
      debugPrint('📊 Image size: ${fileSizeInMB.toStringAsFixed(2)} MB');

      // Step 3: Convert bytes to Base64 string
      debugPrint('🔄 Converting image to Base64...');
      final String base64Image = base64Encode(imageBytes);
      debugPrint('✅ Base64 conversion complete. Length: ${base64Image.length} characters');

      // Step 4: Prepare data for Firestore
      final Map<String, dynamic> imageData = {
        'base64String': base64Image, // The Base64 encoded image
        'timestamp': FieldValue.serverTimestamp(), // Server timestamp
        'fileName': pickedFile.name, // Original file name
        'fileSizeBytes': imageBytes.length, // File size in bytes
        'uploadedAt': DateTime.now().toIso8601String(), // Client timestamp
      };

      // Step 5: Store in Firestore
      debugPrint('💾 Storing image in Firestore...');
      final DocumentReference docRef = await _firestore
          .collection(_imagesCollection)
          .add(imageData);

      debugPrint('✅ Image stored successfully! Document ID: ${docRef.id}');
      return docRef.id;

    } on FirebaseException catch (e) {
      // Handle Firestore-specific errors
      debugPrint('❌ Firestore error: ${e.code} - ${e.message}');
      debugPrint('Error details: ${e.toString()}');
      return null;
      
    } on FileSystemException catch (e) {
      // Handle file system errors (e.g., permission issues)
      debugPrint('❌ File system error: ${e.message}');
      debugPrint('Error details: ${e.toString()}');
      return null;
      
    } catch (e) {
      // Handle any other unexpected errors
      debugPrint('❌ Unexpected error while picking/storing image: $e');
      debugPrint('Error type: ${e.runtimeType}');
      return null;
    }
  }

  /// Retrieve the first stored image from Firestore
  /// 
  /// Returns: A map containing the Base64 string and metadata, or null if no images found
  Future<Map<String, dynamic>?> getFirstStoredImage() async {
    try {
      debugPrint('🔍 Fetching first image from Firestore...');
      
      // Query Firestore for the first image document, ordered by timestamp
      final QuerySnapshot snapshot = await _firestore
          .collection(_imagesCollection)
          .orderBy('timestamp', descending: true) // Get most recent first
          .limit(1) // Only get one document
          .get();

      // Check if any documents were found
      if (snapshot.docs.isEmpty) {
        debugPrint('❌ No images found in Firestore');
        return null;
      }

      // Get the first document
      final DocumentSnapshot doc = snapshot.docs.first;
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      debugPrint('✅ Image retrieved! Document ID: ${doc.id}');
      
      // Add document ID to the data
      data['documentId'] = doc.id;
      
      return data;

    } on FirebaseException catch (e) {
      // Handle Firestore-specific errors
      debugPrint('❌ Firestore error while fetching image: ${e.code} - ${e.message}');
      return null;
      
    } catch (e) {
      // Handle any other unexpected errors
      debugPrint('❌ Unexpected error while fetching image: $e');
      return null;
    }
  }

  /// Retrieve all stored images from Firestore
  /// 
  /// Returns: A list of maps containing Base64 strings and metadata
  Future<List<Map<String, dynamic>>> getAllStoredImages() async {
    try {
      debugPrint('🔍 Fetching all images from Firestore...');
      
      // Query Firestore for all image documents
      final QuerySnapshot snapshot = await _firestore
          .collection(_imagesCollection)
          .orderBy('timestamp', descending: true)
          .get();

      // Convert documents to list of maps
      final List<Map<String, dynamic>> images = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['documentId'] = doc.id;
        return data;
      }).toList();

      debugPrint('✅ Retrieved ${images.length} images from Firestore');
      return images;

    } on FirebaseException catch (e) {
      debugPrint('❌ Firestore error while fetching images: ${e.code} - ${e.message}');
      return [];
      
    } catch (e) {
      debugPrint('❌ Unexpected error while fetching images: $e');
      return [];
    }
  }

  /// Delete an image from Firestore by document ID
  /// 
  /// Returns: true if deletion was successful, false otherwise
  Future<bool> deleteImage(String documentId) async {
    try {
      debugPrint('🗑️ Deleting image with ID: $documentId');
      
      await _firestore
          .collection(_imagesCollection)
          .doc(documentId)
          .delete();

      debugPrint('✅ Image deleted successfully!');
      return true;

    } on FirebaseException catch (e) {
      debugPrint('❌ Firestore error while deleting image: ${e.code} - ${e.message}');
      return false;
      
    } catch (e) {
      debugPrint('❌ Unexpected error while deleting image: $e');
      return false;
    }
  }
}

