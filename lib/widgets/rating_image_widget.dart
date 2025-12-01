import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../constants/app_colors.dart';

/// Widget to handle rating image loading with retry logic and URL regeneration
/// for expired Firebase Storage tokens
class RatingImageWidget extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? primaryColor;
  final bool showLoadingIndicator;
  final bool updateFirestoreOnRegenerate;
  final String? orderId; // Optional: if provided, will update Firestore with new URL

  const RatingImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.backgroundColor,
    this.primaryColor,
    this.showLoadingIndicator = true,
    this.updateFirestoreOnRegenerate = true,
    this.orderId,
  });

  @override
  State<RatingImageWidget> createState() => _RatingImageWidgetState();
}

class _RatingImageWidgetState extends State<RatingImageWidget> {
  int _retryCount = 0;
  static const int _maxRetries = 2;
  bool _hasError = false;
  String? _currentImageUrl;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = null;
  }

  Future<String?> _regenerateDownloadUrl(String oldUrl) async {
    try {
      setState(() {
        _isRegenerating = true;
      });

      // Extract storage path from URL
      // Format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?alt=media&token=...
      final uri = Uri.parse(oldUrl);
      final pathMatch = RegExp(r'/o/(.+)\?').firstMatch(uri.path);
      if (pathMatch == null) {
        if (kDebugMode) {
          debugPrint('❌ Could not extract path from URL: $oldUrl');
        }
        setState(() {
          _isRegenerating = false;
        });
        return null;
      }

      final encodedPath = pathMatch.group(1)!;
      final decodedPath = Uri.decodeComponent(encodedPath);
      if (kDebugMode) {
        debugPrint('🔄 Extracted storage path: $decodedPath');
      }

      // Get reference to the file
      final storageRef = FirebaseStorage.instance.ref().child(decodedPath);

      // Regenerate download URL
      final newUrl = await storageRef.getDownloadURL();
      if (kDebugMode) {
        debugPrint('✅ Regenerated URL: $newUrl');
      }

      setState(() {
        _isRegenerating = false;
      });

      return newUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to regenerate URL: $e');
      }
      setState(() {
        _isRegenerating = false;
      });
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.height ?? 200.0;
    final width = widget.width;
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(8);
    final backgroundColor = widget.backgroundColor ?? Colors.grey[200];
    final primaryColor = widget.primaryColor ?? AppColors.primary;

    if (_hasError && _retryCount >= _maxRetries) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
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
              'Image unavailable',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_isRegenerating) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: primaryColor,
              strokeWidth: 2,
            ),
            const SizedBox(height: 8),
            Text(
              'Regenerating URL...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        _currentImageUrl ?? widget.imageUrl,
        width: width,
        height: height,
        fit: widget.fit,
        headers: const {
          'Cache-Control': 'no-cache',
        },
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            debugPrint('❌ Rating image load error (attempt ${_retryCount + 1}): $error');
            debugPrint('❌ Image URL that failed: ${_currentImageUrl ?? widget.imageUrl}');
          }

          // On first error, try to regenerate the URL
          if (_retryCount == 0 && _currentImageUrl == null) {
            _regenerateDownloadUrl(widget.imageUrl).then((newUrl) {
              if (newUrl != null && mounted) {
                // Update Firestore if orderId is provided
                if (widget.updateFirestoreOnRegenerate && widget.orderId != null) {
                  FirebaseFirestore.instance
                      .collection('orders')
                      .doc(widget.orderId)
                      .update({'ratingImageUrl': newUrl})
                      .then((_) {
                    if (kDebugMode) {
                      debugPrint('✅ Firestore updated with new URL');
                    }
                  }).catchError((e) {
                    if (kDebugMode) {
                      debugPrint('⚠️ Failed to update Firestore: $e');
                    }
                  });
                } else if (widget.updateFirestoreOnRegenerate) {
                  // Try to extract orderId from URL path
                  final pathMatch = RegExp(r'order_ratings/([^/]+)/').firstMatch(widget.imageUrl);
                  if (pathMatch != null) {
                    final orderId = pathMatch.group(1);
                    if (orderId != null) {
                      FirebaseFirestore.instance
                          .collection('orders')
                          .doc(orderId)
                          .update({'ratingImageUrl': newUrl})
                          .then((_) {
                        if (kDebugMode) {
                          debugPrint('✅ Firestore updated with new URL');
                        }
                      }).catchError((e) {
                        if (kDebugMode) {
                          debugPrint('⚠️ Failed to update Firestore: $e');
                        }
                      });
                    }
                  }
                }

                // Update state with new URL and retry
                setState(() {
                  _currentImageUrl = newUrl;
                  _retryCount = 0; // Reset retry count
                  _hasError = false;
                });
                return;
              } else if (mounted) {
                // URL regeneration failed, proceed with retry logic
                setState(() {
                  _isRegenerating = false;
                });
              }
            });
          }

          // Check error type
          final errorString = error.toString().toLowerCase();
          final isNotFound = errorString.contains('404') ||
              errorString.contains('not found');
          final isPermissionDenied = errorString.contains('403') ||
              errorString.contains('permission');
          final isNetworkError = errorString.contains('statuscode: 0') ||
              errorString.contains('network') ||
              errorString.contains('failed');

          // Retry if we haven't exceeded max retries and it's not a permanent error
          if (_retryCount < _maxRetries && !isNotFound && !isPermissionDenied) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(Duration(milliseconds: 500 * (_retryCount + 1)), () {
                if (mounted) {
                  setState(() {
                    _retryCount++;
                    _hasError = false;
                  });
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

          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_retryCount < _maxRetries && !isNotFound && !isPermissionDenied) ...[
                  if (widget.showLoadingIndicator) ...[
                    CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    isNetworkError ? 'Regenerating URL...' : 'Retrying...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isNotFound
                        ? 'Image file not found'
                        : isPermissionDenied
                            ? 'Image access denied'
                            : 'Image unavailable',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
            ),
            child: widget.showLoadingIndicator
                ? Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: primaryColor,
                    ),
                  )
                : child,
          );
        },
      ),
    );
  }
}

