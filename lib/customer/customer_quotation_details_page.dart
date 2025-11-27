import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quotation_model.dart';
import '../services/quotation_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/price_formatter.dart';
import '../customer/order_tracking_landing_page.dart';
import '../dialogs/delivery_address_dialog.dart';

/// Customer Quotation Details Page
/// 
/// Displays quotation details for customer:
/// - All quotation details
/// - If estimatedPrice == null → show "Waiting for staff to process"
/// - If estimatedPrice != null → show price + "Proceed to Order" button
class CustomerQuotationDetailsPage extends StatefulWidget {
  final String quotationId;

  const CustomerQuotationDetailsPage({
    super.key,
    required this.quotationId,
  });

  @override
  State<CustomerQuotationDetailsPage> createState() => _CustomerQuotationDetailsPageState();
}

class _CustomerQuotationDetailsPageState extends State<CustomerQuotationDetailsPage> {
  final QuotationService _quotationService = QuotationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  bool _isConverting = false;
  Quotation? _quotation;

  @override
  void initState() {
    super.initState();
    _loadQuotation();
  }

  Future<void> _loadQuotation() async {
    setState(() => _isLoading = true);
    try {
      final quotation = await _quotationService.getQuotationById(widget.quotationId);
      if (quotation != null) {
        // Verify this quotation belongs to the current user
        final user = _auth.currentUser;
        if (user != null && quotation.customerId != user.uid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You do not have permission to view this quotation'),
                backgroundColor: AppColors.error,
              ),
            );
            Navigator.pop(context);
          }
          return;
        }
        setState(() => _quotation = quotation);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quotation not found'),
              backgroundColor: AppColors.error,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading quotation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _convertToOrder() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check if quotation is quoted and has a price
    if (_quotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quotation data is not available'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    if (_quotation!.status.toLowerCase() != 'quoted') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This quotation is ${_quotation!.status}. Only quoted quotations can be converted to orders.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    // Check if quotation has a price (check all possible price fields)
    final hasPrice = _quotation!.adminTotalPrice != null || 
                     _quotation!.estimatedPrice != null ||
                     (_quotation as dynamic).price != null;
    if (!hasPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quotation price is not available yet'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Confirm conversion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proceed to Buy'),
        content: const Text(
          'Are you sure you want to proceed with this purchase? This will create an order from your quotation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show delivery address form
    final deliveryAddress = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DeliveryAddressDialog(),
    );

    if (deliveryAddress == null) {
      return; // User cancelled
    }

    setState(() => _isConverting = true);

    try {
      await _quotationService.convertQuotationToOrder(
        widget.quotationId,
        fullName: deliveryAddress['fullName'] as String,
        phoneNumber: (deliveryAddress['phoneNumber'] ?? '').toString(),
        completeAddress: deliveryAddress['completeAddress'] as String,
        landmark: deliveryAddress['landmark'] as String?,
        mapLink: deliveryAddress['mapLink'] as String?,
      );
      
      if (mounted) {
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
      if (mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating order: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConverting = false);
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.pending;
      case 'quoted':
        return AppColors.success;
      case 'completed':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.pending;
    }
  }
  
  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'quoted':
        return 'Quoted';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return status.split('_').map((word) => 
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _quotation == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quotation Details'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.mainGradient,
            ),
          ),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_quotation == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quotation Details'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.mainGradient,
            ),
          ),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            'Quotation not found',
            style: AppTextStyles.heading3(),
          ),
        ),
      );
    }

    // Check if quotation has a price (check all possible price fields)
    final hasPrice = _quotation!.adminTotalPrice != null || 
                     _quotation!.estimatedPrice != null ||
                     ((_quotation as dynamic).price as num?)?.toDouble() != null;
    final status = _quotation!.status.toLowerCase();
    final canProceedToBuy = status == 'quoted' && hasPrice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quotation Details'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.mainGradient,
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(_quotation!.status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatStatus(_quotation!.status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Quotation Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quotation Information',
                      style: AppTextStyles.heading2(),
                    ),
                    const Divider(),
                    if (_quotation!.productName != null)
                      _buildDetailRow('Product', _quotation!.productName!),
                    if (_quotation!.productId != null)
                      _buildDetailRow('Product ID', _quotation!.productId!),
                    if (_quotation!.length != null || _quotation!.width != null)
                      _buildDetailRow(
                        'Size',
                        '${_quotation!.length ?? 0}" × ${_quotation!.width ?? 0}"',
                      ),
                    if (_quotation!.glassType != null)
                      _buildDetailRow('Glass Type', _quotation!.glassType!),
                    if (_quotation!.aluminumType != null)
                      _buildDetailRow('Aluminum Type', _quotation!.aluminumType!),
                    if (_quotation!.notes != null && _quotation!.notes!.isNotEmpty)
                      _buildDetailRow('Notes', _quotation!.notes!),
                    _buildDetailRow('Created', _formatDate(_quotation!.createdAt)),
                    if (_quotation!.updatedAt != null)
                      _buildDetailRow('Last Updated', _formatDate(_quotation!.updatedAt)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Price Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pricing',
                      style: AppTextStyles.heading2(),
                    ),
                    const Divider(),
                    if (!hasPrice) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.hourglass_empty,
                            color: AppColors.pending,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Waiting for staff to process',
                                  style: AppTextStyles.heading3(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Our team is reviewing your quotation request. You will be notified once the price is ready.',
                                  style: AppTextStyles.bodyMedium(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Price',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            PriceFormatter.formatPrice(
                              _quotation!.adminTotalPrice ?? 
                              _quotation!.estimatedPrice ?? 
                              ((_quotation as dynamic).price as num?)?.toDouble() ?? 0.0,
                            ),
                            style: AppTextStyles.heading2(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (_quotation!.priceNote != null && _quotation!.priceNote!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Price Note',
                          style: AppTextStyles.caption(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _quotation!.priceNote!,
                          style: AppTextStyles.bodyMedium(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            
            // Proceed to Buy Button (only if status is "quoted" and price is available)
            if (canProceedToBuy) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isConverting ? null : _convertToOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isConverting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_cart),
                            const SizedBox(width: 8),
                            Text(
                              'Proceed to Buy',
                              style: AppTextStyles.buttonLarge(),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.caption(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium(),
            ),
          ),
        ],
      ),
    );
  }
}

