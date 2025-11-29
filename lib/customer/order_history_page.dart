import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
            .orderBy('createdAt', descending: true)
            .snapshots()
            .handleError((error) {
              // Fallback: return orders without orderBy if createdAt fails
              if (kDebugMode) {
                debugPrint(
                  '⚠️ OrderBy createdAt failed, using simple query: $error',
                );
              }
              return FirebaseFirestore.instance
                  .collection('orders')
                  .where('customerId', isEqualTo: user.uid)
                  .snapshots();
            }),
        builder: (context, snapshot) {
          // Handle connection state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          // Handle errors
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

          if (!snapshot.hasData) {
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
                        child: Row(
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
