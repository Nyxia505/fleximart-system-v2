import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:firebase_storage/firebase_storage.dart';

/// Widget for displaying chat images that works on both web and mobile.
/// Always uses getDownloadURL() to ensure valid Firebase Storage URLs.
class ChatImageWidget extends StatefulWidget {
  /// The Firebase Storage path or download URL
  final String imageUrl;
  
  /// Width of the image
  final double? width;
  
  /// Height of the image
  final double? height;
  
  /// How the image should be fitted
  final BoxFit fit;
  
  /// Border radius for the image
  final BorderRadius? borderRadius;
  
  /// Background color while loading
  final Color? backgroundColor;
  
  /// Color for loading indicator
  final Color? loadingColor;
  
  /// Callback when image is tapped
  final VoidCallback? onTap;

  const ChatImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.backgroundColor,
    this.loadingColor,
    this.onTap,
  });

  @override
  State<ChatImageWidget> createState() => _ChatImageWidgetState();
}

class _ChatImageWidgetState extends State<ChatImageWidget> {
  String? _downloadUrl;
  bool _isLoading = true;
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ChatImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resetAndLoad();
    }
  }

  void _resetAndLoad() {
    setState(() {
      _downloadUrl = null;
      _isLoading = true;
      _hasError = false;
      _retryCount = 0;
    });
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
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
      final downloadUrl = await _getDownloadUrl(widget.imageUrl);
      
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
        debugPrint('❌ ChatImageWidget error: $e');
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
        debugPrint('✅ ChatImageWidget: Got download URL for path: $pathOrUrl');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ChatImageWidget: Failed to get download URL: $e');
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
        debugPrint('✅ ChatImageWidget: Regenerated download URL');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ChatImageWidget: Failed to regenerate URL: $e');
      }
      return null;
    }
  }

  Future<void> _retry() async {
    if (_retryCount < _maxRetries) {
      setState(() {
        _retryCount++;
        _hasError = false;
      });
      await _loadImage();
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[200],
        borderRadius: widget.borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load image',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          if (_retryCount < _maxRetries) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: _retry,
              child: Text(
                'Tap to retry',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[200],
        borderRadius: widget.borderRadius,
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: widget.loadingColor,
          strokeWidth: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show error widget if error occurred
    if (_hasError && _retryCount >= _maxRetries) {
      return _buildErrorWidget();
    }

    // Show loading widget while loading
    if (_isLoading || _downloadUrl == null) {
      return _buildLoadingWidget();
    }

    // Build responsive image
    // Encode URL for safe web loading
    final safeUrl = Uri.encodeFull(_downloadUrl!.trim());
    
    Widget imageWidget = Image.network(
      safeUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      headers: kIsWeb ? null : const {
        'Cache-Control': 'max-age=31536000',
      },
      // Only use cacheWidth/cacheHeight on mobile, not on web
      cacheWidth: kIsWeb
          ? null
          : (widget.width != null ? (widget.width! * 2).round().clamp(200, 800) : null),
      cacheHeight: kIsWeb
          ? null
          : (widget.height != null ? (widget.height! * 2).round().clamp(200, 800) : null),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? Colors.grey[200],
            borderRadius: widget.borderRadius,
          ),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: widget.loadingColor,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ ChatImageWidget image load error: $error');
          debugPrint('📸 Image URL: $_downloadUrl');
        }

        // Auto-retry if retries available
        if (_retryCount < _maxRetries) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(Duration(milliseconds: 500 * (_retryCount + 1)), () {
              if (mounted) {
                _retry();
              }
            });
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasError = true;
              });
            }
          });
        }

        return _buildErrorWidget();
      },
    );

    // Apply border radius if specified
    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    // Wrap in GestureDetector if onTap is provided
    if (widget.onTap != null) {
      imageWidget = GestureDetector(
        onTap: widget.onTap,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

