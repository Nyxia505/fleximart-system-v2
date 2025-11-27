import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

/// Cloudinary Service for uploading images
/// 
/// Requirements:
/// - Cloudinary account with cloud name
/// - Unsigned upload preset: 'flutter_upload'
class CloudinaryService {
  final String cloudName;
  final String uploadPreset;
  
  /// Cloudinary upload API URL
  String get uploadUrl => 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  CloudinaryService({
    required this.cloudName,
    this.uploadPreset = 'flutter_upload',
  });

  /// Upload an image to Cloudinary
  /// 
  /// Parameters:
  /// - [file]: Image file (File or XFile)
  /// - [folder]: Optional folder path (e.g., 'products')
  /// 
  /// Returns:
  /// - Secure URL of the uploaded image
  /// 
  /// Throws:
  /// - Exception if upload fails
  Future<String> uploadImage(
    dynamic file, {
    String? folder,
  }) async {
    try {
      // Convert file to bytes
      Uint8List imageBytes;
      if (file is File) {
        imageBytes = await file.readAsBytes();
      } else if (file is XFile) {
        imageBytes = await file.readAsBytes();
      } else {
        throw Exception('Invalid file type. Expected File or XFile.');
      }

      if (imageBytes.isEmpty) {
        throw Exception('Image file is empty');
      }

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      
      // Add required upload preset
      request.fields['upload_preset'] = uploadPreset;
      
      // Add optional folder
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      // Add image file
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'image.jpg',
        ),
      );

      if (kDebugMode) {
        print('☁️ Uploading to Cloudinary...');
        print('   Cloud Name: $cloudName');
        print('   Upload Preset: $uploadPreset');
        print('   Folder: ${folder ?? 'root'}');
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
          'Upload failed: ${response.statusCode} - ${response.body}',
        );
      }

      // Parse response
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (responseData.containsKey('error')) {
        throw Exception('Cloudinary error: ${responseData['error']['message']}');
      }

      // Get secure URL
      final secureUrl = responseData['secure_url'] as String?;

      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception('No secure_url returned from Cloudinary');
      }

      if (kDebugMode) {
        print('✅ Upload successful!');
        print('   URL: $secureUrl');
      }

      return secureUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Cloudinary upload error: $e');
      }
      rethrow;
    }
  }
}
