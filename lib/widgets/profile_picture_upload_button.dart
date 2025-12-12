import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/profile_picture_service.dart';
import '../utils/image_url_helper.dart';

/// Profile Picture Upload Button Widget
/// 
/// A reusable button widget that allows users to upload/update their profile picture.
/// 
/// Usage:
/// ```dart
/// ProfilePictureUploadButton(
///   onUploadComplete: (url) {
///     print('Profile picture uploaded: $url');
///   },
/// )
/// ```
class ProfilePictureUploadButton extends StatefulWidget {
  final Function(String)? onUploadComplete;
  final double? size;
  final String? currentImageUrl;

  const ProfilePictureUploadButton({
    super.key,
    this.onUploadComplete,
    this.size,
    this.currentImageUrl,
  });

  @override
  State<ProfilePictureUploadButton> createState() =>
      _ProfilePictureUploadButtonState();
}

class _ProfilePictureUploadButtonState
    extends State<ProfilePictureUploadButton> {
  final ProfilePictureService _service = ProfilePictureService();
  bool _uploading = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.currentImageUrl;
  }

  // DISABLED: Profile picture upload - managed by admin
  // ignore: unused_element
  Future<void> _handleUpload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to upload a profile picture'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _uploading = true);

    try {
      final String? downloadUrl = await _service.updateProfilePicture(
        uid: user.uid,
        context: context,
      );

      if (downloadUrl != null) {
        setState(() {
          _imageUrl = downloadUrl;
          _uploading = false;
        });

        if (widget.onUploadComplete != null) {
          widget.onUploadComplete!(downloadUrl);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _uploading = false);
      }
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? 100.0;

    return GestureDetector(
      onTap: null, // Disabled - profile pictures are managed by admin
      child: Stack(
        children: [
          _imageUrl != null && _imageUrl!.isNotEmpty
              ? (kIsWeb
                  ? ClipOval(
                      child: Container(
                        width: size,
                        height: size,
                        color: Colors.grey.shade200,
                        child: Image.network(
                          ImageUrlHelper.encodeUrl(_imageUrl!),
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: size / 2,
                              color: Colors.grey.shade600,
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: size / 2,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: NetworkImage(
                        ImageUrlHelper.encodeUrl(_imageUrl!),
                      ),
                      onBackgroundImageError: (exception, stackTrace) {
                        // Error handled by errorBuilder in web version
                      },
                      child: null,
                    ))
              : CircleAvatar(
                  radius: size / 2,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(
                    Icons.person,
                    size: size / 2,
                    color: Colors.grey.shade600,
                  ),
                ),
          if (_uploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            )
          // Camera icon removed - profile pictures are managed by admin
          // else
          //   Positioned(
          //     bottom: 0,
          //     right: 0,
          //     child: Container(
          //       padding: const EdgeInsets.all(4),
          //       decoration: BoxDecoration(
          //         color: Colors.blue,
          //         shape: BoxShape.circle,
          //         border: Border.all(color: Colors.white, width: 2),
          //       ),
          //       child: const Icon(
          //         Icons.camera_alt,
          //         color: Colors.white,
          //         size: 20,
          //       ),
          //     ),
          //   ),
        ],
      ),
    );
  }
}

