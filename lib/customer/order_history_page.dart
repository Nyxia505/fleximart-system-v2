import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../pages/order_detail_page.dart';
import '../utils/price_formatter.dart';

class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({super.key});

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    return 'Unknown';
  }

  String _getOrderShortId(String orderId) {
    return orderId.length >= 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();
  }

  double _getTotalPriceFromOrder(Map<String, dynamic> orderData) {
    // Get totalPrice from Firestore, or compute from items if missing
    final totalPriceValue = orderData['totalPrice'];
    double? totalPrice;
    if (totalPriceValue is num) {
      totalPrice = totalPriceValue.toDouble();
    } else if (totalPriceValue is String) {
      totalPrice = double.tryParse(totalPriceValue);
    }

    // Compute from items if totalPrice doesn't exist
    if (totalPrice == null) {
      final items = (orderData['items'] as List?) ?? [];
      double computedTotal = 0.0;
      if (items.isNotEmpty) {
        for (var item in items) {
          if (item is Map<String, dynamic>) {
            final priceValue = item['price'];
            double price = 0.0;
            if (priceValue is num) {
              price = priceValue.toDouble();
            } else if (priceValue is String) {
              price = double.tryParse(priceValue) ?? 0.0;
            }

            final quantityValue = item['quantity'];
            int quantity = 1;
            if (quantityValue is num) {
              quantity = quantityValue.toInt();
            } else if (quantityValue is String) {
              quantity = int.tryParse(quantityValue) ?? 1;
            }

            computedTotal += price * quantity;
          }
        }
      }
      totalPrice = computedTotal;
    }

    return totalPrice;
  }

  int _getItemCount(Map<String, dynamic> orderData) {
    final items = (orderData['items'] as List?) ?? [];
    if (items.isEmpty) {
      // Fallback to quantity field if items array is empty
      final quantity = orderData['quantity'];
      if (quantity is num) {
        return quantity.toInt();
      } else if (quantity is String) {
        return int.tryParse(quantity) ?? 1;
      }
      return 1;
    }
    return items.length;
  }

  String _formatStatus(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'pending_payment':
        return 'Pending Payment';
      case 'paid':
        return 'Paid';
      case 'for_installation':
        return 'For Installation';
      case 'to_receive':
        return 'To Receive';
      case 'awaiting_installation':
      case 'awaiting installation':
        return 'Awaiting Installation';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) =>
                  word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
            )
            .join(' ');
    }
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'pending_payment':
      case 'to_pay':
        return AppColors.pending;
      case 'paid':
        return AppColors.info;
      case 'awaiting_installation':
      case 'awaiting installation':
      case 'for_installation':
        return AppColors.toInstall;
      case 'shipped':
      case 'to_receive':
        return AppColors.info;
      case 'delivered':
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.cancelled;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text('Please log in', style: AppTextStyles.heading3()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order History'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Handle connection state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          // Handle errors
          if (snapshot.hasError) {
            if (kDebugMode) {
              debugPrint('❌ Order History Error: ${snapshot.error}');
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading orders',
                      style: AppTextStyles.heading3(color: AppColors.error),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Force rebuild by navigating away and back
                        Navigator.of(context).pop();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const OrderHistoryPage(),
                            ),
                          );
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Check if we have data
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          // Filter orders to only show received/completed orders
          final allOrders = List<QueryDocumentSnapshot>.from(
            snapshot.data!.docs,
          );

          if (kDebugMode) {
            debugPrint(
              '📦 Order History: Found ${allOrders.length} total orders for user',
            );
            for (var doc in allOrders) {
              final orderData = doc.data() as Map<String, dynamic>;
              final status = orderData['status'] as String? ?? 'unknown';
              debugPrint(
                '   - Order ${doc.id.substring(0, 8)}: status = "$status"',
              );
            }
          }

          final receivedOrders = allOrders.where((doc) {
            final orderData = doc.data() as Map<String, dynamic>;
            final status = (orderData['status'] as String? ?? '').toLowerCase();
            // Show orders that have been received: completed, awaiting_installation, or delivered
            final isReceived =
                status == 'completed' ||
                status == 'awaiting_installation' ||
                status == 'delivered';

            if (kDebugMode && !isReceived) {
              debugPrint(
                '   ⚠️ Order ${doc.id.substring(0, 8)} filtered out (status: "$status")',
              );
            }

            return isReceived;
          }).toList();

          if (kDebugMode) {
            debugPrint(
              '✅ Order History: Showing ${receivedOrders.length} received/completed orders',
            );
          }

          // Sort by date (most recent first) - in case query orderBy didn't work
          receivedOrders.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            // Prioritize createdAt over date field
            final aDate = aData['createdAt'] ?? aData['date'];
            final bDate = bData['createdAt'] ?? bData['date'];
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;

            // Handle both Timestamp and DateTime objects
            DateTime? aDateTime;
            DateTime? bDateTime;

            if (aDate is Timestamp) {
              aDateTime = aDate.toDate();
            } else if (aDate is DateTime) {
              aDateTime = aDate;
            }

            if (bDate is Timestamp) {
              bDateTime = bDate.toDate();
            } else if (bDate is DateTime) {
              bDateTime = bDate;
            }

            if (aDateTime == null && bDateTime == null) return 0;
            if (aDateTime == null) return 1;
            if (bDateTime == null) return -1;
            return bDateTime.compareTo(aDateTime); // Descending - newest first
          });

          if (receivedOrders.isEmpty) {
            if (kDebugMode) {
              debugPrint(
                'ℹ️ Order History: No received orders found. User needs to confirm receipt of orders first.',
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No order history yet',
                      style: AppTextStyles.heading3(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'Orders will appear here after you confirm receipt in "My Purchases" → "To Receive" tab.',
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh is handled by StreamBuilder automatically
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: receivedOrders.length,
              itemBuilder: (context, index) {
                final doc = receivedOrders[index];
                final orderData = doc.data() as Map<String, dynamic>;
                final orderId = doc.id;
                final status = orderData['status'] as String? ?? 'completed';
                final totalPrice = _getTotalPriceFromOrder(orderData);
                final itemCount = _getItemCount(orderData);
                final date = orderData['date'] ?? orderData['createdAt'];
                final customerName =
                    orderData['customerName'] as String? ??
                    orderData['customer_name'] as String? ??
                    'Customer';
                // Get rating data
                final rating = (orderData['rating'] as num?)?.toInt() ?? 0;
                final review = orderData['review'] as String? ?? '';
                String? ratingImageUrl =
                    (orderData['ratingImageUrl'] as String?) ??
                    (orderData['rating_image_url'] as String?) ??
                    (orderData['imageUrl'] as String?) ??
                    (orderData['image_url'] as String?);
                
                // Clean and validate the URL
                if (ratingImageUrl != null) {
                  ratingImageUrl = ratingImageUrl.trim();
                  if (ratingImageUrl.isEmpty) {
                    ratingImageUrl = null;
                  } else if (!ratingImageUrl.startsWith('http://') && 
                             !ratingImageUrl.startsWith('https://')) {
                    // Invalid URL format
                    if (kDebugMode) {
                      debugPrint('⚠️ Invalid rating image URL format: $ratingImageUrl');
                    }
                    ratingImageUrl = null;
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${_getOrderShortId(orderId)}',
                                    style: AppTextStyles.heading3(),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Customer: $customerName',
                                    style: AppTextStyles.bodyMedium(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(date),
                                    style: AppTextStyles.caption(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(status),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                _formatStatus(status),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Amount',
                                      style: AppTextStyles.caption(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      PriceFormatter.formatPrice(totalPrice),
                                      style: AppTextStyles.heading3(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                                      style: AppTextStyles.caption(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OrderDetailPage(
                                          orderId: orderId,
                                          orderRef: FirebaseFirestore.instance
                                              .collection('orders')
                                              .doc(orderId),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.visibility, size: 18),
                                  label: const Text('View Details'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Rating Section
                            if (rating > 0) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Your Rating',
                                    style: AppTextStyles.bodyMedium().copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Star rating display
                                  Row(
                                    children: List.generate(5, (index) {
                                      return Icon(
                                        index < rating
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: AppColors.primary,
                                        size: 18,
                                      );
                                    }),
                                  ),
                                ],
                              ),
                              if (review.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.format_quote,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          review,
                                          style: AppTextStyles.bodyMedium(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (ratingImageUrl != null && ratingImageUrl.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _RatingImageWidget(
                                    imageUrl: ratingImageUrl.trim(),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Widget to handle rating image loading with retry logic
class _RatingImageWidget extends StatefulWidget {
  final String imageUrl;
  
  const _RatingImageWidget({required this.imageUrl});
  
  @override
  State<_RatingImageWidget> createState() => _RatingImageWidgetState();
}

class _RatingImageWidgetState extends State<_RatingImageWidget> {
  int _retryCount = 0;
  static const int _maxRetries = 2;
  bool _hasError = false;
  String? _currentImageUrl;
  
  @override
  void initState() {
    super.initState();
    _currentImageUrl = null;
  }
  
  Future<String?> _regenerateDownloadUrl(String oldUrl) async {
    try {
      // Extract storage path from URL
      // Format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?alt=media&token=...
      final uri = Uri.parse(oldUrl);
      final pathMatch = RegExp(r'/o/(.+)\?').firstMatch(uri.path);
      if (pathMatch == null) {
        debugPrint('❌ Could not extract path from URL: $oldUrl');
        return null;
      }
      
      final encodedPath = pathMatch.group(1)!;
      final decodedPath = Uri.decodeComponent(encodedPath);
      debugPrint('🔄 Extracted storage path: $decodedPath');
      
      // Get reference to the file
      final storageRef = FirebaseStorage.instance.ref().child(decodedPath);
      
      // Regenerate download URL
      final newUrl = await storageRef.getDownloadURL();
      debugPrint('✅ Regenerated URL: $newUrl');
      return newUrl;
    } catch (e) {
      debugPrint('❌ Failed to regenerate URL: $e');
      return null;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_hasError && _retryCount >= _maxRetries) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
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
    
    return Image.network(
      _currentImageUrl ?? widget.imageUrl,
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
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
              // Extract orderId from path to update Firestore
              final pathMatch = RegExp(r'order_ratings/([^/]+)/').firstMatch(widget.imageUrl);
              if (pathMatch != null) {
                final orderId = pathMatch.group(1);
                if (orderId != null) {
                  // Update Firestore with new URL
                  FirebaseFirestore.instance
                      .collection('orders')
                      .doc(orderId)
                      .update({'ratingImageUrl': newUrl})
                      .then((_) {
                    debugPrint('✅ Firestore updated with new URL');
                  }).catchError((e) {
                    debugPrint('⚠️ Failed to update Firestore: $e');
                  });
                }
              }
              
              // Update state with new URL and retry
              setState(() {
                _currentImageUrl = newUrl;
                _retryCount = 0; // Reset retry count
                _hasError = false;
              });
              return;
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
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_retryCount < _maxRetries && !isNotFound && !isPermissionDenied) ...[
                CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
                const SizedBox(height: 8),
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
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: AppColors.primary,
            ),
          ),
        );
      },
    );
  }
}
