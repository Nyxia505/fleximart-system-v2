import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:firebase_storage/firebase_storage.dart';
import 'profile_picture_placeholder.dart';
import '../utils/image_url_helper.dart';

/// A responsive profile picture widget that works on both web and mobile.
/// Always uses getDownloadURL() to ensure valid Firebase Storage URLs.
class ProfilePictureWidget extends StatefulWidget {
  /// The Firebase Storage path or download URL
  final String? imageUrl;
  
  /// Size of the profile picture
  final double size;
  
  /// Background color
  final Color? backgroundColor;
  
  /// Whether to show a loading indicator
  final bool showLoadingIndicator;
  
  /// Custom placeholder widget
  final Widget? placeholder;

  const ProfilePictureWidget({
    super.key,
    this.imageUrl,
    this.size = 48,
    this.backgroundColor,
    this.showLoadingIndicator = true,
    this.placeholder,
  });

  @override
  State<ProfilePictureWidget> createState() => _ProfilePictureWidgetState();
}

class _ProfilePictureWidgetState extends State<ProfilePictureWidget> {
  String? _downloadUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ProfilePictureWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Always get fresh download URL using getDownloadURL()
      final downloadUrl = await _getDownloadUrl(widget.imageUrl!);
      
      if (downloadUrl != null && mounted) {
        setState(() {
          _downloadUrl = downloadUrl;
          _isLoading = false;
          _hasError = false;
        });
      } else {
        throw Exception('Failed to get download URL');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ProfilePictureWidget error: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  /// Get download URL from Firebase Storage path or existing URL
  Future<String?> _getDownloadUrl(String pathOrUrl) async {
    try {
      // If it's already a valid HTTP/HTTPS URL (not Firebase Storage), use it
      if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
        // Check if it's a Firebase Storage URL that needs regeneration
        if (pathOrUrl.contains('firebasestorage.googleapis.com')) {
          // Extract storage path and get fresh URL
          return await _regenerateDownloadUrl(pathOrUrl);
        }
        // It's a regular URL, use it directly
        return pathOrUrl;
      }

      // It's a storage path, get download URL
      final storageRef = FirebaseStorage.instance.ref().child(pathOrUrl);
      final downloadUrl = await storageRef.getDownloadURL();
      
      if (kDebugMode) {
        debugPrint('✅ ProfilePictureWidget: Got download URL for path: $pathOrUrl');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ProfilePictureWidget: Failed to get download URL: $e');
      }
      return null;
    }
  }

  /// Regenerate download URL from Firebase Storage URL
  Future<String?> _regenerateDownloadUrl(String url) async {
    try {
      // Extract storage path from URL
      // Format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?alt=media&token=...
      final uri = Uri.parse(url);
      final pathMatch = RegExp(r'/o/(.+)\?').firstMatch(uri.path);
      if (pathMatch == null) {
        // Couldn't extract path, return null to use URL as-is
        return null;
      }

      final encodedPath = pathMatch.group(1)!;
      final storagePath = Uri.decodeComponent(encodedPath);
      
      // Get fresh download URL
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final downloadUrl = await storageRef.getDownloadURL();
      
      if (kDebugMode) {
        debugPrint('✅ ProfilePictureWidget: Regenerated download URL');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ProfilePictureWidget: Failed to regenerate URL: $e');
      }
      return null;
    }
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }
    return CompactProfilePicturePlaceholder(size: widget.size);
  }

  Widget _buildImage() {
    if (_hasError || _downloadUrl == null) {
      return _buildPlaceholder();
    }

    // Use Image.network wrapped in ClipOval for web, CircleAvatar for mobile
    if (kIsWeb) {
      return ClipOval(
        child: Container(
          width: widget.size,
          height: widget.size,
          color: widget.backgroundColor ?? Colors.grey[300],
          child: Image.network(
            ImageUrlHelper.encodeUrl(_downloadUrl!),
            fit: BoxFit.cover,
            width: widget.size,
            height: widget.size,
            headers: const {'Cache-Control': 'no-cache'},
            loadingBuilder: (context, child, loading) {
              if (loading == null) return child;
              return Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stack) {
              return Center(child: Text('Image failed to load'));
            },
          ),
        ),
      );
    } else {
      return CircleAvatar(
        radius: widget.size / 2,
        backgroundColor: widget.backgroundColor ?? Colors.grey[300],
        backgroundImage: NetworkImage(
          ImageUrlHelper.encodeUrl(_downloadUrl!),
        ),
        onBackgroundImageError: (exception, stackTrace) {
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
        },
        child: _isLoading && widget.showLoadingIndicator
            ? CircularProgressIndicator(strokeWidth: 2)
            : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.showLoadingIndicator) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    return _buildImage();
  }
}

