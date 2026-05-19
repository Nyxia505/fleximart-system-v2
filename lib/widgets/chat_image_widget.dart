import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../utils/image_url_helper.dart';
import '../utils/storage_image_loader.dart';

/// Chat image from Firebase Storage. On web uses Cloud Function proxy when needed.
class ChatImageWidget extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? loadingColor;
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
  Uint8List? _imageBytes;
  String? _networkUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ChatImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final source = widget.imageUrl.trim();
    if (source.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _imageBytes = null;
        _networkUrl = null;
      });
    }

    try {
      final bytes = await StorageImageLoader.loadChatBytes(source);
      if (bytes != null && bytes.isNotEmpty && mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
          _hasError = false;
        });
        return;
      }

      final url = await StorageImageLoader.freshDownloadUrl(source);
      if (url != null && url.isNotEmpty && mounted) {
        setState(() {
          _networkUrl = url;
          _isLoading = false;
          _hasError = false;
        });
        return;
      }

      throw Exception('Could not load chat image');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ ChatImageWidget: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
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
          Icon(Icons.broken_image, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 6),
          Text(
            'Image unavailable',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          TextButton(
            onPressed: _loadImage,
            child: const Text('Retry', style: TextStyle(fontSize: 11)),
          ),
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

  Widget _buildImageContent() {
    if (_imageBytes != null) {
      return Image.memory(
        _imageBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildErrorWidget(),
      );
    }

    if (_networkUrl != null) {
      final url = ImageUrlHelper.encodeUrl(_networkUrl!);
      return Image.network(
        url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        headers: kIsWeb ? null : const {'Cache-Control': 'max-age=31536000'},
        cacheWidth: kIsWeb
            ? null
            : (widget.width != null
                ? (widget.width! * 2).round().clamp(200, 1200)
                : null),
        cacheHeight: kIsWeb
            ? null
            : (widget.height != null
                ? (widget.height! * 2).round().clamp(200, 1200)
                : null),
        errorBuilder: (_, __, ___) => _buildErrorWidget(),
      );
    }

    return _buildErrorWidget();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    Widget imageWidget = _buildImageContent();

    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    if (widget.onTap != null) {
      imageWidget = GestureDetector(
        onTap: widget.onTap,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
