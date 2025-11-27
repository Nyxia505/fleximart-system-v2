import 'package:flutter/material.dart';
import '../services/image_storage_service.dart';
import '../widgets/image_display_widget.dart';

/// Demo screen showing image picking, storing, and displaying functionality
/// 
/// Features:
/// - Pick image from gallery
/// - Convert to Base64 and store in Firestore
/// - Display stored images
/// - Show upload status and errors
class ImageDemoScreen extends StatefulWidget {
  const ImageDemoScreen({super.key});

  @override
  State<ImageDemoScreen> createState() => _ImageDemoScreenState();
}

class _ImageDemoScreenState extends State<ImageDemoScreen> {
  // Instance of the image storage service
  final ImageStorageService _imageService = ImageStorageService();
  
  // Upload state
  bool _isUploading = false;
  String? _uploadStatus;
  Color _statusColor = Colors.blue;

  // Key to refresh the image display widget
  final GlobalKey<State> _imageDisplayKey = GlobalKey();

  /// Handle image picking and upload
  Future<void> _pickAndUploadImage() async {
    // Set uploading state
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Picking image...';
      _statusColor = Colors.blue;
    });

    try {
      // Call the service to pick and store the image
      final String? documentId = await _imageService.pickAndStoreImage();

      // Check if upload was successful
      if (documentId != null) {
        // Success!
        setState(() {
          _isUploading = false;
          _uploadStatus = 'Image uploaded successfully! ID: $documentId';
          _statusColor = Colors.green;
        });

        // Show success snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image stored in Firestore! Document ID: $documentId'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  // Scroll to the display widget or refresh it
                  setState(() {
                    // This will rebuild and reload the image display widget
                  });
                },
              ),
            ),
          );
        }

        // Refresh the image display widget after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            // Rebuild to show the new image
          });
        }
      } else {
        // Upload failed or was cancelled
        setState(() {
          _isUploading = false;
          _uploadStatus = 'Upload cancelled or failed';
          _statusColor = Colors.orange;
        });
      }
    } catch (e) {
      // Handle unexpected errors
      debugPrint('❌ Error in upload handler: $e');
      setState(() {
        _isUploading = false;
        _uploadStatus = 'Error: ${e.toString()}';
        _statusColor = Colors.red;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Storage Demo'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to Use:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep('1', 'Tap the "Pick & Upload Image" button below'),
                    _buildInstructionStep('2', 'Select an image from your gallery'),
                    _buildInstructionStep('3', 'Image will be converted to Base64'),
                    _buildInstructionStep('4', 'Base64 string stored in Firestore'),
                    _buildInstructionStep('5', 'Image displayed below after upload'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Upload Button
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadImage,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add_photo_alternate),
              label: Text(
                _isUploading ? 'Uploading...' : 'Pick & Upload Image',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Upload Status
            if (_uploadStatus != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _statusColor, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusColor == Colors.green
                          ? Icons.check_circle
                          : _statusColor == Colors.red
                              ? Icons.error
                              : Icons.info,
                      color: _statusColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _uploadStatus!,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Divider
            const Divider(thickness: 2),
            
            const SizedBox(height: 16),

            // Title for display section
            const Text(
              'Latest Stored Image:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Image Display Widget
            ImageDisplayWidget(key: _imageDisplayKey),

            const SizedBox(height: 24),

            // Technical Info Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Technical Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTechDetail('Package', 'image_picker ^1.0.0'),
                    _buildTechDetail('Encoding', 'base64Encode (dart:convert)'),
                    _buildTechDetail('Storage', 'Cloud Firestore'),
                    _buildTechDetail('Collection', 'images'),
                    _buildTechDetail('Display', 'Image.memory() with base64Decode'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build instruction step widget
  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Build technical detail row
  Widget _buildTechDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

