import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/image_url_helper.dart';

/// A responsive widget for displaying product images that works on both web and mobile.
/// Uses Image.network with proper loading and error handling.
class ProductImageWidget extends StatelessWidget {
  /// The image URL
  final String? imageUrl;
  
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
  
  /// Custom error widget
  final Widget? errorWidget;

  const ProductImageWidget({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.backgroundColor,
    this.loadingColor,
    this.errorWidget,
  });

  Widget _buildErrorWidget() {
    if (errorWidget != null) {
      return errorWidget!;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.image_not_supported,
        size: (width != null && height != null)
            ? (width! < height! ? width! * 0.3 : height! * 0.3)
            : 48,
        color: Colors.grey[400],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show error widget if no image URL
    if (imageUrl == null || imageUrl!.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ ProductImageWidget: No image URL provided');
      }
      return _buildErrorWidget();
    }

    // Validate URL before attempting to load
    if (!ImageUrlHelper.isValidImageUrl(imageUrl)) {
      if (kDebugMode) {
        debugPrint('⚠️ ProductImageWidget: Invalid image URL: $imageUrl');
      }
      return _buildErrorWidget();
    }

    final encodedUrl = ImageUrlHelper.encodeUrl(imageUrl!);
    
    if (kDebugMode) {
      debugPrint('🖼️ ProductImageWidget: Loading image from: $encodedUrl');
    }
    
    Widget imageWidget = Image.network(
      encodedUrl,
      fit: fit,
      width: width,
      height: height,
      headers: const {'Cache-Control': 'no-cache'},
      loadingBuilder: (context, child, loading) {
        if (loading == null) return child;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.grey[200],
            borderRadius: borderRadius,
          ),
          child: Center(
            child: CircularProgressIndicator(
              color: loadingColor,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) {
        if (kDebugMode) {
          debugPrint('❌ ProductImageWidget: Failed to load image');
          debugPrint('   Original URL: $imageUrl');
          debugPrint('   Encoded URL: $encodedUrl');
          debugPrint('   Error: $error');
          debugPrint('   Stack: $stack');
        }
        return _buildErrorWidget();
      },
    );

    // Apply border radius if specified
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

