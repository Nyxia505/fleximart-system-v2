import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/price_formatter.dart';
import '../utils/image_url_helper.dart';

class OrderActionButton {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  OrderActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
}

class OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final List<OrderActionButton> actionButtons;

  const OrderCard({
    super.key,
    required this.orderId,
    required this.orderData,
    this.actionButtons = const [],
  });

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        final hours = difference.inHours;
        if (hours == 0) {
          final minutes = difference.inMinutes;
          return '$minutes min ago';
        }
        return '$hours hour${hours > 1 ? 's' : ''} ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
    return 'Unknown';
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
        return AppColors.toInstall;
      case 'shipped':
        return AppColors.info;
      case 'completed':
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.cancelled;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatStatus(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'pending_payment':
        return 'To Pay';
      case 'paid':
        return 'Paid';
      case 'awaiting_installation':
      case 'awaiting installation':
        return 'To Install';
      case 'shipped':
        return 'To Receive';
      case 'completed':
        return 'Completed';
      case 'delivered':
        return 'Delivered';
      default:
        return status.replaceAll('_', ' ').split(' ').map((word) =>
            word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (orderData['status'] as String?) ?? 'pending_payment';
    final items = (orderData['items'] as List?) ?? [];
    final firstItem = items.isNotEmpty ? items[0] as Map<String, dynamic> : null;
    final productName = firstItem?['name'] ?? firstItem?['productName'] ?? 'Product';
    final productImage = firstItem?['productImage'] ?? firstItem?['image'] ?? '';
    // Get totalPrice from Firestore, or compute from items if missing
    final totalPriceValue = orderData['totalPrice'];
    double? totalPrice;
    if (totalPriceValue is num) {
      totalPrice = totalPriceValue.toDouble();
    } else if (totalPriceValue is String) {
      totalPrice = double.tryParse(totalPriceValue);
    }
    
    // Compute from items if totalPrice doesn't exist
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
    
    final totalAmount = totalPrice ?? computedTotal;
    final createdAt = orderData['createdAt'];
    final completeAddress = orderData['completeAddress'] as String? ?? '';

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
                Text(
                  'Order #${orderId.substring(0, 8).toUpperCase()}',
                  style: AppTextStyles.heading3(),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(status), width: 1.5),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (productImage.toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      ImageUrlHelper.encodeUrl(productImage.toString()),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      cacheWidth: kIsWeb ? null : 200,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.image_outlined, color: Colors.grey[400]),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName.toString(),
                        style: AppTextStyles.heading3(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        PriceFormatter.formatPrice(totalAmount),
                        style: AppTextStyles.heading3(color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(createdAt),
                            style: AppTextStyles.caption(color: AppColors.textHint),
                          ),
                        ],
                      ),
                      if (completeAddress.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, size: 14, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                completeAddress,
                                style: AppTextStyles.caption(color: AppColors.textHint),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (actionButtons.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actionButtons.map((button) {
                  return ElevatedButton.icon(
                    onPressed: button.onPressed,
                    icon: Icon(button.icon, size: 18),
                    label: Text(button.label),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: button.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

