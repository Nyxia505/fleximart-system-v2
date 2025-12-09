import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/image_url_helper.dart';

/// A responsive widget for loading Firebase Storage images that works on both web and mobile.
/// 
/// Features:
/// - Always uses getDownloadURL() to ensure valid URLs
/// - Web-compatible (no cacheWidth on web)
/// - Responsive sizing for mobile and web
/// - Error handling with placeholder
/// - Loading states
/// - Retry functionality
class FirebaseImageWidget extends StatefulWidget {
  /// The Firebase Storage path (e.g., 'chat_images/chat123/image.jpg')
  /// OR a Firebase Storage download URL
  final String? imagePathOrUrl;
  
  /// Optional placeholder widget to show when image is loading or fails
  final Widget? placeholder;
  
  /// Optional error widget to show when image fails to load
  final Widget? errorWidget;
  
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
  
  /// Whether to show loading indicator
  final bool showLoadingIndicator;
  
  /// Maximum number of retry attempts
  final int maxRetries;
  
  /// Whether to automatically regenerate URL on error
  final bool autoRegenerateUrl;

  const FirebaseImageWidget({
    super.key,
    this.imagePathOrUrl,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.backgroundColor,
    this.loadingColor,
    this.showLoadingIndicator = true,
    this.maxRetries = 2,
    this.autoRegenerateUrl = true,
  });

  @override
  State<FirebaseImageWidget> createState() => _FirebaseImageWidgetState();
}

class _FirebaseImageWidgetState extends State<FirebaseImageWidget> {
  String? _downloadUrl;
  bool _isLoading = true;
  bool _hasError = false;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(FirebaseImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePathOrUrl != widget.imagePathOrUrl) {
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
    if (widget.imagePathOrUrl == null || widget.imagePathOrUrl!.isEmpty) {
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

      String? downloadUrl;

      // Check if it's already a download URL or a storage path
      if (widget.imagePathOrUrl!.startsWith('http://') ||
          widget.imagePathOrUrl!.startsWith('https://')) {
        // It's already a URL - check if it's a Firebase Storage URL that needs regeneration
        if (widget.imagePathOrUrl!.contains('firebasestorage.googleapis.com')) {
          // Try to extract path and regenerate URL
          downloadUrl = await _getDownloadUrlFromPath(widget.imagePathOrUrl!);
          if (downloadUrl == null) {
            // If extraction fails, use the URL as-is (might be a valid download URL)
            downloadUrl = widget.imagePathOrUrl;
          }
        } else {
          // It's a regular HTTP/HTTPS URL, use it directly
          downloadUrl = widget.imagePathOrUrl;
        }
      } else {
        // It's a storage path, get download URL
        downloadUrl = await _getDownloadUrlFromPath(widget.imagePathOrUrl!);
      }

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
        debugPrint('❌ FirebaseImageWidget error: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  /// Extract storage path from URL and get fresh download URL
  Future<String?> _getDownloadUrlFromPath(String pathOrUrl) async {
    try {
      String storagePath;

      // Check if it's a Firebase Storage URL
      if (pathOrUrl.contains('firebasestorage.googleapis.com')) {
        // Extract path from URL
        // Format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?alt=media&token=...
        final uri = Uri.parse(pathOrUrl);
        final pathMatch = RegExp(r'/o/(.+)\?').firstMatch(uri.path);
        if (pathMatch == null) {
          // Couldn't extract path, return null to use URL as-is
          return null;
        }

        final encodedPath = pathMatch.group(1)!;
        storagePath = Uri.decodeComponent(encodedPath);
      } else {
        // It's already a storage path
        storagePath = pathOrUrl;
      }

      // Get reference and download URL
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final downloadUrl = await storageRef.getDownloadURL();
      
      if (kDebugMode) {
        debugPrint('✅ FirebaseImageWidget: Got download URL for path: $storagePath');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ FirebaseImageWidget: Failed to get download URL: $e');
      }
      return null;
    }
  }

  Future<void> _retry() async {
    if (_retryCount < widget.maxRetries) {
      setState(() {
        _retryCount++;
        _hasError = false;
      });
      await _loadImage();
    }
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[200],
        borderRadius: widget.borderRadius,
      ),
      child: Icon(
        Icons.image,
        size: (widget.width != null && widget.height != null)
            ? (widget.width! < widget.height! ? widget.width! * 0.4 : widget.height! * 0.4)
            : 48,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

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
            size: (widget.width != null && widget.height != null)
                ? (widget.width! < widget.height! ? widget.width! * 0.4 : widget.height! * 0.4)
                : 48,
            color: Colors.grey[400],
          ),
          if (widget.maxRetries > 0 && _retryCount < widget.maxRetries) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _retry,
              child: const Text('Retry'),
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
      child: widget.showLoadingIndicator
          ? Center(
              child: CircularProgressIndicator(
                color: widget.loadingColor,
                strokeWidth: 2,
              ),
            )
          : _buildPlaceholder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show placeholder if no image path provided
    if (widget.imagePathOrUrl == null || widget.imagePathOrUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    // Show error widget if error occurred
    if (_hasError && _retryCount >= widget.maxRetries) {
      return _buildErrorWidget();
    }

    // Show loading widget while loading
    if (_isLoading || _downloadUrl == null) {
      return _buildLoadingWidget();
    }

    // Build responsive image
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // Calculate responsive dimensions
    double? imageWidth = widget.width;
    double? imageHeight = widget.height;
    
    // If width/height not specified, use responsive defaults
    if (imageWidth == null && imageHeight == null) {
      if (isMobile) {
        imageWidth = screenWidth * 0.8;
        imageHeight = imageWidth * 0.75;
      } else {
        imageWidth = 400;
        imageHeight = 300;
      }
    }

    Widget imageWidget = Image.network(
      ImageUrlHelper.encodeUrl(_downloadUrl!),
      fit: BoxFit.cover,
      width: imageWidth,
      height: imageHeight,
      headers: const {'Cache-Control': 'no-cache'},
      loadingBuilder: (context, child, loading) {
        if (loading == null) return child;
        return Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stack) {
        if (kDebugMode) {
          debugPrint('❌ FirebaseImageWidget image load error: $error');
          debugPrint('📸 Image URL: $_downloadUrl');
        }

        // Auto-regenerate URL if enabled and retries available
        if (widget.autoRegenerateUrl &&
            _retryCount < widget.maxRetries &&
            _downloadUrl != null &&
            _downloadUrl!.contains('firebasestorage.googleapis.com')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _getDownloadUrlFromPath(widget.imagePathOrUrl!).then((newUrl) {
              if (newUrl != null && mounted && newUrl != _downloadUrl) {
                setState(() {
                  _downloadUrl = newUrl;
                  _retryCount++;
                });
              } else if (mounted) {
                setState(() {
                  _hasError = true;
                  _retryCount++;
                });
              }
            });
          });
        } else if (_retryCount < widget.maxRetries) {
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

        return Center(child: Text('Image failed to load'));
      },
    );

    // Apply border radius if specified
    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

