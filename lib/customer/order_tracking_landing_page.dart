import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/price_formatter.dart';
import 'order_tracking_page.dart';

/// Order Tracking Landing Page
///
/// Lists all active orders for the user and allows tapping to open tracking page
class OrderTrackingLandingPage extends StatelessWidget {
  const OrderTrackingLandingPage({super.key});

  String _getOrderShortId(String orderId) {
    return orderId.length >= 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();
  }

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

  String _formatStatus(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'pending_payment':
        return 'Pending Payment';
      case 'processing':
      case 'preparing':
        return 'Preparing';
      case 'on_the_way':
      case 'on the way':
      case 'shipped':
        return 'On the Way';
      case 'delivered':
      case 'completed':
        return 'Delivered';
      case 'cancelled':
      case 'canceled':
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
        return AppColors.pending;
      case 'processing':
      case 'preparing':
        return AppColors.info;
      case 'on_the_way':
      case 'on the way':
      case 'shipped':
        return AppColors.info;
      case 'delivered':
      case 'completed':
        return AppColors.success;
      case 'cancelled':
      case 'canceled':
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

    final uid = user.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Track Orders'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .handleError((error) {
              if (kDebugMode) {
                print('⚠️ Query failed, trying fallback: $error');
              }
              // Fallback: try without orderBy if createdAt field doesn't exist
              return FirebaseFirestore.instance
                  .collection('orders')
                  .where('customerId', isEqualTo: uid)
                  .snapshots();
            }),
        builder: (context, snapshot) {
          // 1. Check for errors first
          if (snapshot.hasError) {
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
                  ],
                ),
              ),
            );
          }

          // 2. Check if data is not available yet (loading state)
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          // 3. Check if documents are empty
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active orders found',
                      style: AppTextStyles.heading3(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your active orders will appear here',
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data!.docs;

          // Sort orders manually if orderBy failed
          final ordersList = List<QueryDocumentSnapshot>.from(orders);
          ordersList.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCreated = aData['createdAt'] as Timestamp?;
            final bCreated = bData['createdAt'] as Timestamp?;

            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return bCreated.compareTo(aCreated); // Descending
          });

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ordersList.length,
              itemBuilder: (context, index) {
                final doc = ordersList[index];
                final orderData = doc.data() as Map<String, dynamic>;
                final orderId = doc.id;

                // Extract correct fields with null checks
                final items = (orderData['items'] as List?) ?? [];
                final totalPrice = orderData['totalPrice'] as num?;
                final status =
                    (orderData['status'] as String?) ?? 'pending_payment';
                final createdAt = orderData['createdAt'] as Timestamp?;
                final completeAddress =
                    orderData['completeAddress'] as String? ?? '';

                // Parse first item from items array
                String productName = 'Product';
                String productImage = '';

                if (items.isNotEmpty) {
                  final firstItem = items[0] as Map<String, dynamic>?;
                  if (firstItem != null) {
                    productName =
                        firstItem['productName'] as String? ??
                        firstItem['name'] as String? ??
                        'Product';
                    productImage =
                        firstItem['productImage'] as String? ??
                        firstItem['image'] as String? ??
                        '';
                  }
                } else {
                  // Fallback to order-level fields if items array is empty
                  productName =
                      orderData['productName'] as String? ?? 'Product';
                  productImage = orderData['productImage'] as String? ?? '';
                }

                // Calculate total price if not available
                double finalTotalPrice = 0.0;
                if (totalPrice != null) {
                  finalTotalPrice = totalPrice.toDouble();
                } else {
                  // Calculate from items
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
                      int itemQuantity = 1;
                      if (quantityValue is num) {
                        itemQuantity = quantityValue.toInt();
                      } else if (quantityValue is String) {
                        itemQuantity = int.tryParse(quantityValue) ?? 1;
                      }

                      finalTotalPrice += price * itemQuantity;
                    }
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
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrackOrderTimeline(
                              orderId: orderId,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image
                            if (productImage.toString().isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  productImage.toString(),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey[400],
                                      ),
                                    );
                                  },
                                ),
                              )
                            else
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.image_outlined,
                                  color: Colors.grey[400],
                                ),
                              ),
                            const SizedBox(width: 12),
                            // Order Info
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
                                    productName.toString(),
                                    style: AppTextStyles.bodyMedium(
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(
                                            status,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: _getStatusColor(status),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _formatStatus(status),
                                          style: TextStyle(
                                            color: _getStatusColor(status),
                                            fontSize: 12, // Increased for clarity
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (completeAddress.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            completeAddress,
                                            style: AppTextStyles.caption(
                                              color: AppColors.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        PriceFormatter.formatPrice(
                                          finalTotalPrice,
                                        ),
                                        style: AppTextStyles.heading3(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      Text(
                                        _formatDate(createdAt),
                                        style: AppTextStyles.caption(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
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
