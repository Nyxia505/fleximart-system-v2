import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/image_storage_service.dart';

/// Widget that displays Base64 images from Firestore
///
/// Features:
/// - Fetches the first stored image from Firestore
/// - Decodes Base64 string to bytes
/// - Displays image using Image.memory()
/// - Shows loading and error states
/// - Includes retry functionality
class ImageDisplayWidget extends StatefulWidget {
  const ImageDisplayWidget({super.key});

  @override
  State<ImageDisplayWidget> createState() => _ImageDisplayWidgetState();
}

class _ImageDisplayWidgetState extends State<ImageDisplayWidget> {
  // Instance of the image storage service
  final ImageStorageService _imageService = ImageStorageService();

  // Loading state
  bool _isLoading = false;

  // Decoded image bytes (ready to display)
  Uint8List? _imageBytes;

  // Image metadata
  String? _fileName;
  String? _uploadedAt;
  String? _documentId;

  // Error message
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Load image when widget is first created
    _loadImage();
  }

  /// Load the first stored image from Firestore and decode it
  Future<void> _loadImage() async {
    // Set loading state
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _imageBytes = null;
    });

    try {
      debugPrint('🔄 Starting image load process...');

      // Step 1: Fetch image data from Firestore
      final Map<String, dynamic>? imageData = await _imageService
          .getFirstStoredImage();

      // Step 2: Check if image data was retrieved
      if (imageData == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No images found in Firestore';
        });
        return;
      }

      // Step 3: Extract Base64 string from the data
      final String? base64String = imageData['base64String'] as String?;

      if (base64String == null || base64String.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid image data: Base64 string is missing';
        });
        return;
      }

      debugPrint('✅ Base64 string retrieved. Length: ${base64String.length}');

      // Step 4: Decode Base64 string to bytes
      debugPrint('🔄 Decoding Base64 to bytes...');
      final Uint8List decodedBytes = base64Decode(base64String);
      debugPrint('✅ Decoded ${decodedBytes.length} bytes');

      // Step 5: Extract metadata
      final String fileName = imageData['fileName'] ?? 'Unknown';
      final String uploadedAt = imageData['uploadedAt'] ?? 'Unknown';
      final String documentId = imageData['documentId'] ?? 'Unknown';

      // Step 6: Update state with decoded image and metadata
      setState(() {
        _imageBytes = decodedBytes;
        _fileName = fileName;
        _uploadedAt = uploadedAt;
        _documentId = documentId;
        _isLoading = false;
        _errorMessage = null;
      });

      debugPrint('✅ Image loaded and ready to display!');
    } catch (e) {
      // Handle any errors during loading/decoding
      debugPrint('❌ Error loading image: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load image: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Text(
              'Stored Image from Firestore',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Content: Loading, Error, or Image
            if (_isLoading)
              // Show loading indicator
              _buildLoadingState()
            else if (_errorMessage != null)
              // Show error message
              _buildErrorState()
            else if (_imageBytes != null)
              // Show decoded image
              _buildImageState()
            else
              // Show empty state
              _buildEmptyState(),

            // Metadata (if available)
            if (_fileName != null && !_isLoading && _errorMessage == null) ...[
              const SizedBox(height: 16),
              _buildMetadata(),
            ],

            // Retry button
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadImage,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload Image'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build loading state widget
  Widget _buildLoadingState() {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          'Loading image from Firestore...',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  /// Build error state widget
  Widget _buildErrorState() {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'Unknown error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ],
    );
  }

  /// Build image display widget
  Widget _buildImageState() {
    return Column(
      children: [
        // Display the decoded image using Image.memory()
        // Image.memory() takes Uint8List bytes and displays them as an image
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _imageBytes!, // The decoded bytes from Base64
            fit: BoxFit.contain,
            width: double.infinity,
            height: 300,
            errorBuilder: (context, error, stackTrace) {
              // Handle image display errors
              debugPrint('❌ Error displaying image: $error');
              return Container(
                height: 300,
                color: Colors.grey[200],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Failed to display image'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '✓ Image loaded successfully',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  /// Build empty state widget
  Widget _buildEmptyState() {
    return Column(
      children: [
        Icon(Icons.image_not_supported, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('No image to display', style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  /// Build metadata display widget
  Widget _buildMetadata() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Image Details:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildMetadataRow('File Name', _fileName ?? 'N/A'),
          _buildMetadataRow('Uploaded At', _uploadedAt ?? 'N/A'),
          _buildMetadataRow('Document ID', _documentId ?? 'N/A'),
          _buildMetadataRow('Size', '${_imageBytes!.length} bytes'),
        ],
      ),
    );
  }

  /// Build a single metadata row
  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
