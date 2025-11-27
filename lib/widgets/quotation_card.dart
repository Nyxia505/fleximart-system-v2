import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/quotation_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'status_badge.dart';
import '../utils/price_formatter.dart';
import '../services/notification_service.dart';
import '../customer/order_tracking_landing_page.dart';

/// Quotation Card Widget
///
/// Displays a quotation in a beautiful card format
class QuotationCard extends StatelessWidget {
  final Quotation quotation;
  final VoidCallback? onTap;
  final Function(String)? onStatusUpdate;
  final String? quotationId; // Document ID for order conversion

  const QuotationCard({
    super.key,
    required this.quotation,
    this.onTap,
    this.onStatusUpdate,
    this.quotationId,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';

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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Customer name and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quotation.customerName ?? 'Customer',
                          style: AppTextStyles.heading3(),
                        ),
                        if (quotation.customerEmail != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            quotation.customerEmail!,
                            style: AppTextStyles.caption(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  StatusBadge(status: quotation.status),
                ],
              ),

              const SizedBox(height: 12),

              // Product info - get from items array first, then fallback
              Builder(
                builder: (context) {
                  String productName = 'Custom Product';
                  double? length;
                  double? width;
                  
                  // Try to get from items array first
                  if (quotation.items != null && quotation.items!.isNotEmpty) {
                    final firstItem = quotation.items![0] as Map<String, dynamic>?;
                    if (firstItem != null) {
                      productName = firstItem['productName'] as String? ?? 
                                   firstItem['name'] as String? ?? 
                                   'Custom Product';
                      final lengthValue = firstItem['length'];
                      if (lengthValue != null) {
                        length = (lengthValue is num) ? lengthValue.toDouble() : double.tryParse(lengthValue.toString());
                      }
                      final widthValue = firstItem['width'];
                      if (widthValue != null) {
                        width = (widthValue is num) ? widthValue.toDouble() : double.tryParse(widthValue.toString());
                      }
                    }
                  } else {
                    // Fallback to quotation-level fields
                    productName = quotation.productName ?? 'Custom Product';
                    length = quotation.length;
                    width = quotation.width;
                  }
                  
                  String sizeText = '';
                  if (length != null && width != null) {
                    sizeText = '${length.toStringAsFixed(0)}" × ${width.toStringAsFixed(0)}"';
                  } else if (length != null) {
                    sizeText = '${length.toStringAsFixed(0)}"';
                  } else if (width != null) {
                    sizeText = '${width.toStringAsFixed(0)}"';
                  }
                  
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    style: AppTextStyles.bodyMedium(),
                                  ),
                                  if (sizeText.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      sizeText,
                                      style: AppTextStyles.caption(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),

              // Message/Notes
              if ((quotation.message != null &&
                      quotation.message!.isNotEmpty) ||
                  (quotation.notes != null && quotation.notes!.isNotEmpty)) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.message_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          quotation.notes ?? quotation.message ?? '',
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],


              // Items display
              if (quotation.items != null && quotation.items!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Items:',
                        style: AppTextStyles.caption(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...quotation.items!.take(3).map((item) {
                        final itemMap = item as Map<String, dynamic>? ?? {};
                        final productName = itemMap['productName'] as String? ?? 
                                           itemMap['name'] as String? ?? 
                                           'Product';
                        final lengthValue = itemMap['length'];
                        final widthValue = itemMap['width'];
                        final quantityValue = itemMap['quantity'];
                        
                        double? length;
                        double? width;
                        int quantity = 1;
                        
                        if (lengthValue != null) {
                          length = (lengthValue is num) ? lengthValue.toDouble() : double.tryParse(lengthValue.toString());
                        }
                        if (widthValue != null) {
                          width = (widthValue is num) ? widthValue.toDouble() : double.tryParse(widthValue.toString());
                        }
                        if (quantityValue != null) {
                          quantity = (quantityValue is num) ? quantityValue.toInt() : int.tryParse(quantityValue.toString()) ?? 1;
                        }
                        
                        String sizeText = '';
                        if (length != null && width != null) {
                          sizeText = ' (${length.toStringAsFixed(0)}" × ${width.toStringAsFixed(0)}")';
                        } else if (length != null) {
                          sizeText = ' (${length.toStringAsFixed(0)}")';
                        } else if (width != null) {
                          sizeText = ' (${width.toStringAsFixed(0)}")';
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $productName$sizeText × $quantity',
                            style: AppTextStyles.caption(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }),
                      if (quotation.items!.length > 3)
                        Text(
                          '... and ${quotation.items!.length - 3} more',
                          style: AppTextStyles.caption(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Admin Total Price (priority) or Estimated Price
              if (quotation.adminTotalPrice != null &&
                  quotation.adminTotalPrice! > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_money,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        PriceFormatter.formatPrice(quotation.adminTotalPrice!),
                        style: AppTextStyles.heading3(color: AppColors.primary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(Quoted)',
                        style: AppTextStyles.caption(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (quotation.estimatedPrice != null &&
                  quotation.estimatedPrice! > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_money,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        PriceFormatter.formatPrice(quotation.estimatedPrice!),
                        style: AppTextStyles.heading3(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Proceed to Order button (only if status == 'quoted')
              if (quotation.status.toLowerCase() == 'quoted' &&
                  quotationId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _proceedToOrder(context, quotationId!),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Proceed to Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],

              // Footer: Time and actions
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(quotation.createdAt),
                        style: AppTextStyles.caption(color: AppColors.textHint),
                      ),
                    ],
                  ),
                  if (onStatusUpdate != null && quotation.status == 'pending')
                    Row(
                      children: [
                        _buildActionButton(
                          context,
                          'Approve',
                          AppColors.primary,
                          Icons.check_circle,
                          () => onStatusUpdate!('quoted'),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          context,
                          'Reject',
                          AppColors.cancelled,
                          Icons.cancel,
                          () => onStatusUpdate!('rejected'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption(
                color: color,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  /// Convert quotation to order when customer proceeds
  Future<void> _proceedToOrder(BuildContext context, String quotationId) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to proceed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Get quotation data
      final quotationRef = FirebaseFirestore.instance
          .collection('quotations')
          .doc(quotationId);

      final quotationDoc = await quotationRef.get();
      if (!quotationDoc.exists) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quotation not found'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final quotationData = quotationDoc.data() as Map<String, dynamic>;

      // Get items from quotation
      var items = (quotationData['items'] as List?) ?? [];
      if (items.isEmpty) {
        // If no items array, create one from quotation data
        items = [
          {
            'productId': quotationData['productId'] ?? '',
            'productName': quotationData['productName'] ?? 'Product',
            'productImage': quotationData['productImage'] ?? '',
            'quantity': quotationData['quantity'] ?? 1,
            'price':
                quotationData['adminTotalPrice'] ??
                quotationData['estimatedPrice'] ??
                0,
            'length': quotationData['length'],
            'width': quotationData['width'],
          },
        ];
      }

      // Get total price (adminTotalPrice or estimatedPrice)
      final adminTotalPrice = quotationData['adminTotalPrice'] as num?;
      final estimatedPrice = quotationData['estimatedPrice'] as num?;
      final totalPrice = (adminTotalPrice ?? estimatedPrice ?? 0).toDouble();

      if (totalPrice <= 0) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Quotation price is not set. Please wait for admin to set the price.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Create order document
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      await orderRef.set({
        'customerId': user.uid,
        'customerName':
            quotationData['customerName'] ?? user.displayName ?? 'Customer',
        'customerEmail': quotationData['customerEmail'] ?? user.email ?? '',
        'items': items,
        'totalPrice': totalPrice,
        'status': 'pending_payment',
        'paymentMethod': 'cash_on_delivery',
        'createdAt': FieldValue.serverTimestamp(),
        'date': FieldValue.serverTimestamp(),
        'quotationId': quotationId, // Link to original quotation
      });

      // Update quotation status to 'accepted'
      await quotationRef.update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify all admins
      final notificationService = NotificationService.instance;
      await notificationService.notifyAllAdmins(
        fromUserId: user.uid,
        title: 'New Order From Quotation',
        message: 'Customer accepted the quotation.',
        type: 'order',
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Redirect to Order Tracking page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OrderTrackingLandingPage(),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating order: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
