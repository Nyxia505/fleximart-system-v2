import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/order_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/price_formatter.dart';

class StaffOrdersTheme {
  StaffOrdersTheme._();
  static const Color primaryGradientStart = Color(0xFF9B0060);
  static const Color primaryGradientEnd = Color(0xFF75004A);
  static const Color accent = Color(0xFFC80075);
  static const Color headerStart = Color(0xFFC80075);
  static const Color headerEnd = Color(0xFF75004A);
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [headerStart, headerEnd],
  );
}

class StaffOrdersPage extends StatelessWidget {
  const StaffOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Please log in',
            style: AppTextStyles.heading3(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('All Orders'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: StaffOrdersTheme.headerGradient,
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots()
            .handleError((error) {
          if (kDebugMode) {
            print('⚠️ OrderBy failed, using simple query: $error');
          }
          return FirebaseFirestore.instance
              .collection('orders')
              .snapshots();
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: StaffOrdersTheme.accent,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No orders found',
                      style: AppTextStyles.heading3(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final ordersList = List<QueryDocumentSnapshot>.from(
            snapshot.data!.docs,
          );
          
          // Sort manually if orderBy failed
          ordersList.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCreated = aData['createdAt'] as Timestamp?;
            final bCreated = bData['createdAt'] as Timestamp?;
            
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return bCreated.compareTo(aCreated);
          });

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh handled by StreamBuilder
            },
            color: StaffOrdersTheme.accent,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ordersList.length,
              itemBuilder: (context, index) {
                final doc = ordersList[index];
                final data = doc.data() as Map<String, dynamic>;
                return _OrderCard(
                  orderId: doc.id,
                  orderData: data,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const _OrderCard({
    required this.orderId,
    required this.orderData,
  });

  /// Safely get order ID substring
  String _getOrderShortId(String orderId) {
    if (orderId.length >= 8) {
      return orderId.substring(0, 8).toUpperCase();
    }
    return orderId.toUpperCase();
  }

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

  String _formatStatus(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'pending_payment':
        return 'Pending Payment';
      case 'to_pay':
        return 'To Pay';
      case 'paid':
        return 'Paid';
      case 'shipped':
        return 'Shipped';
      case 'awaiting_installation':
      case 'awaiting installation':
        return 'Awaiting Installation';
      case 'delivered':
        return 'Delivered';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ').split(' ').map((word) =>
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }

  /// Compute total amount from items array if totalAmount doesn't exist
  double _computeTotalFromItems(List? items) {
    if (items == null || items.isEmpty) return 0.0;
    
    double total = 0.0;
    for (var item in items) {
      if (item is Map<String, dynamic>) {
        // Handle both string and num types for price
        final priceValue = item['price'];
        double price = 0.0;
        if (priceValue is num) {
          price = priceValue.toDouble();
        } else if (priceValue is String) {
          price = double.tryParse(priceValue) ?? 0.0;
        }
        
        // Handle both string and num types for quantity
        final quantityValue = item['quantity'];
        int quantity = 1;
        if (quantityValue is num) {
          quantity = quantityValue.toInt();
        } else if (quantityValue is String) {
          quantity = int.tryParse(quantityValue) ?? 1;
        }
        
        total += price * quantity;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    // Safe access to items array
    final items = orderData['items'] as List? ?? [];
    
    // Get product details from items[0] safely
    String productName = 'Unknown Product';
    String? productImage;
    int itemCount = 0;
    
    if (items.isNotEmpty) {
      final firstItem = items[0] as Map<String, dynamic>? ?? {};
      productName = firstItem['productName'] as String? ?? 
                    orderData['productName'] as String? ?? 
                    'Unknown Product';
      productImage = firstItem['productImage'] as String? ?? 
                     orderData['productImage'] as String?;
      itemCount = items.length;
    } else {
      // Fallback to orderData fields if items array is empty
      productName = orderData['productName'] as String? ?? 'Unknown Product';
      productImage = orderData['productImage'] as String?;
      itemCount = (orderData['quantity'] as num?)?.toInt() ?? 0;
    }
    
    // Read totalPrice from Firestore (correct field name)
    // Priority: totalPrice > price > compute from items
    double price = (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
    
    // Fallback to 'price' field if totalPrice is 0 or missing
    if (price == 0.0) {
      price = (orderData['price'] as num?)?.toDouble() ?? 0.0;
    }
    
    // If still 0, compute from items array as last resort
    double computedTotal = 0.0;
    if (price == 0.0 && items.isNotEmpty) {
      computedTotal = _computeTotalFromItems(items);
    }
    
    // Use the calculated price (totalPrice/price field takes priority over computed)
    final finalTotal = price > 0.0 ? price : computedTotal;
    
    // Debug: Log price calculation (remove in production if needed)
    if (finalTotal == 0.0) {
      debugPrint('⚠️ Order $orderId: finalTotal is 0. totalPrice=${orderData['totalPrice']}, price=${orderData['price']}, items=${items.length}');
    }
    
    final customerName = orderData['customerName'] as String? ?? 'Customer';
    final customerEmail = orderData['customerEmail'] as String?;
    final createdAt = orderData['createdAt'] ?? orderData['date'];
    final status = (orderData['status'] as String?) ?? 'pending_payment';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      constraints: const BoxConstraints(minHeight: 180),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppColors.mainGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${_getOrderShortId(orderId)}',
                  style: AppTextStyles.heading3(color: Colors.white),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    _formatStatus(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: productImage != null && productImage.isNotEmpty
                      ? Image.network(
                          productImage,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholderImage(),
                        )
                      : _buildPlaceholderImage(),
                ),
                const SizedBox(width: 12),
                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        productName,
                        style: AppTextStyles.heading3(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customerName,
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (customerEmail != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                customerEmail,
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatDate(createdAt),
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
                  ),
                ),
              ],
            ),
          ),
          // Order Summary Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quantity',
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        itemCount > 0 
                            ? '$itemCount item${itemCount != 1 ? 's' : ''}'
                            : 'No items',
                        style: AppTextStyles.bodyMedium(),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Total Price',
                        style: AppTextStyles.heading3(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        PriceFormatter.formatPrice(finalTotal),
                        style: AppTextStyles.heading2(
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.start,
              children: _buildActionButtons(context, status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: AppColors.textSecondary,
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, String currentStatus) {
    final statusLower = currentStatus.toLowerCase();
    final buttons = <Widget>[];

    // Mark as Paid
    if (statusLower == 'pending_payment' || statusLower == 'to_pay') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _handleStatusUpdate(
            context,
            'paid',
            'paidAt',
          ),
          icon: const Icon(Icons.payment, size: 18),
          label: const Text('Mark as Paid'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    // Mark as Shipped
    if (statusLower == 'paid') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _handleStatusUpdate(
            context,
            'shipped',
            'shippedAt',
          ),
          icon: const Icon(Icons.local_shipping, size: 18),
          label: const Text('Mark as Shipped'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    // Mark as Received
    if (statusLower == 'shipped') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _handleStatusUpdate(
            context,
            'awaiting_installation',
            'deliveredAt',
          ),
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Mark as Received'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    // Mark as Completed (out for delivery)
    if (statusLower == 'awaiting_installation') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _handleStatusUpdate(
            context,
            'completed',
            null,
          ),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Mark as Completed'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    // Mark as Delivered
    if (statusLower == 'completed') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _handleStatusUpdate(
            context,
            'delivered',
            null,
          ),
          icon: const Icon(Icons.home_filled, size: 18),
          label: const Text('Mark as Delivered'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    // If no buttons match, show a message
    if (buttons.isEmpty) {
      buttons.add(
        Text(
          'No actions available for this status',
          style: AppTextStyles.caption(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return buttons;
  }

  Future<void> _handleStatusUpdate(
    BuildContext context,
    String newStatus,
    String? timestampField,
  ) async {
    final orderService = OrderService();

    try {
      await orderService.updateOrderStatus(
        orderId: orderId,
        newStatus: newStatus,
        updateTimestamp: timestampField,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to ${_formatStatus(newStatus)}'),
            backgroundColor: StaffOrdersTheme.accent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

