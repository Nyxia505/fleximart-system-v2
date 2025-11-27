import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/price_formatter.dart';
import '../customer/order_tracking_landing_page.dart';
import '../services/quotation_service.dart';
import '../dialogs/delivery_address_dialog.dart';

/// Quotation Details Page
///
/// Displays detailed information about a quotation and allows conversion to order
class QuotationDetailsPage extends StatelessWidget {
  final String quotationId;

  const QuotationDetailsPage({
    super.key,
    required this.quotationId,
  });

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
      return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Unknown';
  }

  String _formatStatus(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'pending':
        return 'Pending';
      case 'quoted':
        return 'Quoted';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
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
      case 'pending':
        return AppColors.pending;
      case 'quoted':
        return AppColors.success;
      case 'completed':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _proceedToOrder(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to proceed'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      // Read quotation document to verify status
      final quotationDoc = await FirebaseFirestore.instance
          .collection('quotations')
          .doc(quotationId)
          .get();

      if (!quotationDoc.exists) {
        if (context.mounted) {
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
      final status = (quotationData['status'] as String? ?? '').toLowerCase();

      // Safety check: Prevent double conversion
      if (status == 'converted' || status == 'accepted') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This quotation has already been converted to an order'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Safety check: Ensure status is 'quoted'
      if (status != 'quoted') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quotation is not ready for conversion. Please wait for admin to quote the price.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Safety check: Ensure adminTotalPrice is set
      final adminTotalPrice = quotationData['adminTotalPrice'] as num?;
      if (adminTotalPrice == null || adminTotalPrice <= 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quotation price is not set. Please wait for admin to set the price.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Show delivery address form
      final deliveryAddress = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const DeliveryAddressDialog(),
      );

      if (deliveryAddress == null) {
        return; // User cancelled
      }

      // Show loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Convert quotation to order using quotation service
      try {
        final quotationService = QuotationService();
        await quotationService.convertQuotationToOrder(
          quotationId,
          fullName: deliveryAddress['fullName'] as String,
          phoneNumber: (deliveryAddress['phoneNumber'] ?? '').toString(),
          completeAddress: deliveryAddress['completeAddress'] as String,
          landmark: deliveryAddress['landmark'] as String?,
          mapLink: deliveryAddress['mapLink'] as String?,
        );

        if (context.mounted) {
          Navigator.pop(context); // Close loading
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
      } on FirebaseException catch (e) {
        // Handle Firestore-specific errors
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          String errorMessage = 'Error creating order: ';
          if (e.code == 'permission-denied') {
            errorMessage = 'Permission denied. Please ensure you are logged in and have permission to create orders.';
          } else if (e.code == 'unavailable') {
            errorMessage = 'Service temporarily unavailable. Please check your internet connection and try again.';
          } else {
            errorMessage = 'Error creating order: ${e.message ?? e.code}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        // Handle other errors
        if (context.mounted) {
          Navigator.pop(context); // Close loading if still open
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating order: ${e.toString()}'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quotation Details'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quotations')
            .doc(quotationId)
            .snapshots(),
        builder: (context, snapshot) {
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
                      'Error loading quotation',
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

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = (data['status'] as String? ?? 'pending').toLowerCase();
          final adminTotalPrice = data['adminTotalPrice'] as num?;
          final items = (data['items'] as List?) ?? [];
          final createdAt = data['createdAt'] as Timestamp?;
          final canProceed = status == 'quoted' && 
                           adminTotalPrice != null && 
                           adminTotalPrice > 0;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Status Card
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
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
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getStatusColor(status),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _formatStatus(status),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Created At',
                            style: AppTextStyles.caption(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(createdAt),
                            style: AppTextStyles.bodyMedium(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Uploaded Reference Image
                if (data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
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
                        Text(
                          'Reference Image',
                          style: AppTextStyles.heading3(),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            data['imageUrl'] as String,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey[400],
                                      size: 48,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Failed to load image',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                width: double.infinity,
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
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Product Items
                Container(
                  padding: const EdgeInsets.all(16),
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
                      Text(
                        'Product Items',
                        style: AppTextStyles.heading3(),
                      ),
                      const SizedBox(height: 12),
                      if (items.isNotEmpty)
                        ...items.map((item) {
                          final itemMap = item as Map<String, dynamic>;
                          final productName = itemMap['productName'] ?? 
                                            itemMap['name'] ?? 
                                            'Product';
                          final quantity = itemMap['quantity'] ?? 1;
                          final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;
                          final productImage = itemMap['productImage'] ?? 
                                             itemMap['image'] ?? 
                                             '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                if (productImage.toString().isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      productImage.toString(),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey[400],
                                            size: 24,
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                else
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: Colors.grey[400],
                                      size: 24,
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        productName.toString(),
                                        style: AppTextStyles.bodyMedium().copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Quantity: $quantity',
                                        style: AppTextStyles.caption(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  PriceFormatter.formatPrice(price),
                                  style: AppTextStyles.heading3(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList()
                      else
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            data['productName'] ?? 'Product',
                            style: AppTextStyles.bodyMedium(),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Total Price
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Price',
                        style: AppTextStyles.heading3(),
                      ),
                      Text(
                        adminTotalPrice != null && adminTotalPrice > 0
                            ? PriceFormatter.formatPrice(adminTotalPrice.toDouble())
                            : 'Not set',
                        style: AppTextStyles.heading3(
                          color: adminTotalPrice != null && adminTotalPrice > 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Proceed to Order Button (only if status == 'quoted' and price is set)
                if (status == 'quoted')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canProceed ? () => _proceedToOrder(context) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.3),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            canProceed
                                ? 'Proceed to Order'
                                : 'Waiting for Price',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (status == 'accepted')
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This quotation has been accepted and converted to an order.',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.success,
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
  }

}

