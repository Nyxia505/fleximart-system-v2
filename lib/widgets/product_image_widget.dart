import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../utils/image_url_helper.dart';
import '../utils/product_image_utils.dart';
import '../utils/storage_image_loader.dart';
import 'product_base64_image.dart';

/// Displays product images from network, Firebase Storage (web-safe), or base64.
class ProductImageWidget extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? loadingColor;
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

  @override
  State<ProductImageWidget> createState() => _ProductImageWidgetState();
}

class _ProductImageWidgetState extends State<ProductImageWidget> {
  Uint8List? _memoryBytes;
  bool _useNetwork = false;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProductImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _memoryBytes = null;
      _useNetwork = false;
      _loading = true;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.imageUrl?.trim() ?? '';
    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
      return;
    }

    if (!isNetworkProductImage(url)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _useNetwork = false;
          _failed = false;
        });
      }
      return;
    }

    if (kIsWeb && url.contains('firebasestorage.googleapis.com')) {
      final bytes = await StorageImageLoader.loadProductBytes(url);
      if (!mounted) return;
      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          _memoryBytes = bytes;
          _loading = false;
          _failed = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _useNetwork = true;
        _loading = false;
        _failed = false;
      });
    }
  }

  Widget _wrap(Widget child) {
    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) return widget.errorWidget!;
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor ?? Colors.grey[200],
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported,
        size: 40,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor ?? Colors.grey[200],
      alignment: Alignment.center,
      child: CircularProgressIndicator(color: widget.loadingColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl?.trim() ?? '';

    if (_loading) {
      return _wrap(_buildLoading());
    }

    if (url.isEmpty || _failed) {
      return _wrap(_buildErrorWidget());
    }

    if (!isNetworkProductImage(url)) {
      return _wrap(
        ProductBase64Image(
          base64String: url,
          width: widget.width ?? double.infinity,
          height: widget.height ?? double.infinity,
        ),
      );
    }

    if (_memoryBytes != null) {
      return _wrap(
        Image.memory(
          _memoryBytes!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _buildErrorWidget(),
        ),
      );
    }

    if (_useNetwork) {
      final encodedUrl = ImageUrlHelper.encodeUrl(url);
      return _wrap(
        Image.network(
          encodedUrl,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          headers: kIsWeb ? null : const {'Cache-Control': 'no-cache'},
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _buildLoading();
          },
          errorBuilder: (_, __, ___) {
            if (kDebugMode) {
              debugPrint('❌ ProductImageWidget network failed: $url');
            }
            return _buildErrorWidget();
          },
        ),
      );
    }

    return _wrap(_buildErrorWidget());
  }
}
