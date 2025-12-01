import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/price_formatter.dart';

/// Filtered Orders Page
///
/// Displays orders filtered by status for the current customer.
/// Supports statuses: pending_payment, for_installation, to_receive, completed
class FilteredOrdersPage extends StatelessWidget {
  final String status;

  const FilteredOrdersPage({
    super.key,
    required this.status,
  });

  /// Get status label for display
  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending_payment':
        return 'To Pay';
      case 'for_installation':
        return 'To Install';
      case 'to_receive':
        return 'To Receive';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  /// Get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_payment':
        return AppColors.warning;
      case 'for_installation':
        return AppColors.info;
      case 'to_receive':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Build Firestore query with proper filtering
  Stream<QuerySnapshot> _buildQuery(String userId) {
    // Query without orderBy to avoid composite index requirements
    // Sort in memory instead
    if (status == 'completed') {
      // Query for completed orders, then filter in memory for rating == null
      return FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .snapshots();
    }
    
    // For other statuses, use direct query
    return FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: userId)
        .where('status', isEqualTo: status)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_getStatusLabel(status)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.mainGradient),
          ),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please log in to view orders'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_getStatusLabel(status)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery(user.uid),
        builder: (context, snapshot) {
          // Handle loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Handle errors
          if (snapshot.hasError) {
            return Center(
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
                    style: AppTextStyles.heading3(),
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
            );
          }

          // Handle empty state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
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
                  const SizedBox(height: 8),
                  Text(
                    'You don\'t have any ${_getStatusLabel(status).toLowerCase()} orders yet.',
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Display orders list
          var allOrders = snapshot.data!.docs;

          // For "To Rate" (completed), filter out orders that already have ratings
          if (status == 'completed') {
            allOrders = allOrders.where((doc) {
              final order = doc.data() as Map<String, dynamic>;
              final rating = order['rating'];
              return rating == null;
            }).toList();
          }
          
          // Sort by createdAt in memory (descending - newest first)
          final orders = List<QueryDocumentSnapshot>.from(allOrders);
          orders.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCreated = aData['createdAt'] as Timestamp?;
            final bCreated = bData['createdAt'] as Timestamp?;
            
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return bCreated.compareTo(aCreated); // Descending
          });

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
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
                  const SizedBox(height: 8),
                  Text(
                    'You don\'t have any ${_getStatusLabel(status).toLowerCase()} orders yet.',
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final orderDoc = orders[index];
              final order = orderDoc.data() as Map<String, dynamic>;

              // Safe access to items array
              final items = order['items'] as List? ?? [];
              
              // Get product details from items[0] safely
              String productName = 'Unknown Product';
              String? productImage;
              int itemCount = 0;
              
              if (items.isNotEmpty) {
                final firstItem = items[0] as Map<String, dynamic>? ?? {};
                productName = firstItem['productName'] as String? ?? 
                              order['productName'] as String? ?? 
                              'Unknown Product';
                productImage = firstItem['productImage'] as String? ?? 
                               order['productImage'] as String?;
                itemCount = items.length;
              } else {
                // Fallback to orderData fields if items array is empty
                productName = order['productName'] as String? ?? 'Unknown Product';
                productImage = order['productImage'] as String?;
                itemCount = 0; // Show "No items" if items array is empty
              }
              
              // Get totalPrice from Firestore, or compute from items if missing
              final totalPriceValue = order['totalPrice'];
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
              
              final finalTotalPrice = totalPrice ?? computedTotal;
              final orderStatus = order['status']?.toString() ?? status;
              final createdAt = order['createdAt'] as Timestamp?;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image (if available)
                      if (productImage != null && productImage.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            productImage,
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 150,
                              color: AppColors.background,
                              child: Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Product Name
                      Text(
                        productName,
                        style: AppTextStyles.heading3(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      
                      // Order Details Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Total Price
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Price',
                                style: AppTextStyles.caption(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                PriceFormatter.formatPrice(finalTotalPrice),
                                style: AppTextStyles.heading3(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          
                          // Number of Items
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Items',
                                style: AppTextStyles.caption(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  itemCount > 0 
                                      ? '$itemCount ${itemCount == 1 ? 'item' : 'items'}'
                                      : 'No items',
                                  style: AppTextStyles.bodyMedium(
                                    color: AppColors.primary,
                                  ).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(orderStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor(orderStatus).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getStatusColor(orderStatus),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getStatusLabel(orderStatus),
                              style: AppTextStyles.bodyMedium(
                                color: _getStatusColor(orderStatus),
                              ).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Order Date (if available)
                      if (createdAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(createdAt.toDate()),
                          style: AppTextStyles.caption(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Navigation helper functions for FilteredOrdersPage
class FilteredOrdersNavigation {
  /// Navigate to "To Pay" orders (pending_payment)
  static void navigateToPay(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FilteredOrdersPage(status: 'pending_payment'),
      ),
    );
  }

  /// Navigate to "To Install" orders (for_installation)
  static void navigateToInstall(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FilteredOrdersPage(status: 'for_installation'),
      ),
    );
  }

  /// Navigate to "To Receive" orders (to_receive)
  static void navigateToReceive(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FilteredOrdersPage(status: 'to_receive'),
      ),
    );
  }

  /// Navigate to "To Rate" orders (completed)
  static void navigateToRate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FilteredOrdersPage(status: 'completed'),
      ),
    );
  }
}

