import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../services/profile_pic_cache_service.dart';
import 'profile_picture_placeholder.dart';
import '../utils/image_url_helper.dart';
import '../utils/storage_image_loader.dart';

/// Profile picture from Firebase Storage + local cache (persists across sessions).
class ProfilePictureWidget extends StatefulWidget {
  final String? imageUrl;
  /// Loads `profile_images/{storageUserId}.jpg` from Storage (recommended).
  final String? storageUserId;
  final double size;
  final Color? backgroundColor;
  final bool showLoadingIndicator;
  final Widget? placeholder;
  final Uint8List? initialBytes;

  const ProfilePictureWidget({
    super.key,
    this.imageUrl,
    this.storageUserId,
    this.size = 48,
    this.backgroundColor,
    this.showLoadingIndicator = true,
    this.placeholder,
    this.initialBytes,
  });

  @override
  State<ProfilePictureWidget> createState() => _ProfilePictureWidgetState();
}

class _ProfilePictureWidgetState extends State<ProfilePictureWidget> {
  Uint8List? _imageBytes;
  String? _downloadUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBytes != null && widget.initialBytes!.isNotEmpty) {
      _imageBytes = widget.initialBytes;
      _isLoading = false;
    } else {
      _loadImage();
    }
  }

  @override
  void didUpdateWidget(ProfilePictureWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialBytes != null &&
        widget.initialBytes!.isNotEmpty &&
        widget.initialBytes != oldWidget.initialBytes) {
      setState(() {
        _imageBytes = widget.initialBytes;
        _isLoading = false;
        _hasError = false;
      });
      return;
    }
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.storageUserId != widget.storageUserId) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        if (widget.initialBytes == null) {
          _imageBytes = null;
        }
        _downloadUrl = null;
      });
    }

    try {
      final userId = widget.storageUserId?.trim() ?? '';

      // 1) Device cache (instant, survives app restarts)
      if (userId.isNotEmpty) {
        final cachedBytes = await ProfilePicCacheService.getCachedBytes(userId);
        if (cachedBytes != null && cachedBytes.isNotEmpty && mounted) {
          setState(() {
            _imageBytes = cachedBytes;
            _isLoading = false;
            _hasError = false;
          });
          _refreshFromRemote(userId, updateUi: true);
          return;
        }
        final cachedUrl = await ProfilePicCacheService.getCachedUrl(userId);
        if (cachedUrl != null && cachedUrl.isNotEmpty) {
          _downloadUrl = cachedUrl;
        }
      }

      await _refreshFromRemote(userId, updateUi: false);

      if (mounted &&
          (_imageBytes != null ||
              (_downloadUrl != null && _downloadUrl!.isNotEmpty))) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      } else {
        throw Exception('Profile image not found');
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

  Future<void> _refreshFromRemote(String userId, {required bool updateUi}) async {
    if (userId.isNotEmpty) {
      final bytes = await StorageImageLoader.loadProfileBytes(userId);
      if (bytes != null && bytes.isNotEmpty) {
        final url =
            widget.imageUrl ??
            await StorageImageLoader.freshProfileDownloadUrl(userId);
        if (url != null && url.isNotEmpty) {
          await ProfilePicCacheService.save(
            uid: userId,
            downloadUrl: url,
            previewBytes: bytes,
          );
        }
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
            _hasError = false;
            if (updateUi) _isLoading = false;
          });
        }
        return;
      }
    }

    final source = widget.imageUrl ?? _downloadUrl;
    if (source == null || source.isEmpty) return;

    if (kIsWeb) {
      final bytes = await StorageImageLoader.loadBytes(source);
      if (bytes != null && bytes.isNotEmpty && mounted) {
        setState(() {
          _imageBytes = bytes;
          _hasError = false;
          if (updateUi) _isLoading = false;
        });
        if (userId.isNotEmpty) {
          await ProfilePicCacheService.save(
            uid: userId,
            downloadUrl: source,
            previewBytes: bytes,
          );
        }
        return;
      }
    }

    final url = userId.isNotEmpty
        ? await StorageImageLoader.freshProfileDownloadUrl(userId)
        : await StorageImageLoader.freshDownloadUrl(source);
    if (url != null && mounted) {
      setState(() {
        _downloadUrl = url;
        _hasError = false;
        if (updateUi) _isLoading = false;
      });
      if (userId.isNotEmpty) {
        await ProfilePicCacheService.save(uid: userId, downloadUrl: url);
      }
    }
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }
    return CompactProfilePicturePlaceholder(size: widget.size);
  }

  Widget _buildImage() {
    if (_hasError && _imageBytes == null && _downloadUrl == null) {
      return _buildPlaceholder();
    }

    if (_imageBytes != null) {
      return ClipOval(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Image.memory(
            _imageBytes!,
            fit: BoxFit.cover,
            width: widget.size,
            height: widget.size,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        ),
      );
    }

    if (_downloadUrl == null) {
      return _buildPlaceholder();
    }

    final url = ImageUrlHelper.encodeUrl(_downloadUrl!);

    if (kIsWeb) {
      return ClipOval(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: widget.size,
            height: widget.size,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: widget.size / 2,
      backgroundColor: widget.backgroundColor ?? Colors.grey[300],
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {
        if (mounted) setState(() => _hasError = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.showLoadingIndicator) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return _buildImage();
  }
}
