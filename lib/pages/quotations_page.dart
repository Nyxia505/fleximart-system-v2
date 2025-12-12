import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../utils/price_formatter.dart';
import 'quotation_details_page.dart';

class QuotationsPage extends StatelessWidget {
  const QuotationsPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.dashboardBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Please log in to view your quotations',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.dashboardBackground,
      appBar: AppBar(
        title: const Text('Quotations'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('quotations')
                    .where('customerId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final count = snapshot.data!.docs.length;
                    return Text(
                      '$count ${count == 1 ? 'quotation' : 'quotations'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('quotations')
                  .where('customerId', isEqualTo: user.uid)
                  .snapshots(),
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
                            'Error loading quotations',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 2. Check connection state - only show loading when actively waiting
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                // 3. Check if documents are empty (after data is loaded)
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                            'No quotations yet',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              'Your quotations will appear here after you request a quotation.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final quotations = snapshot.data!.docs;

                // Sort quotations manually if orderBy failed
                final quotationsList = List<QueryDocumentSnapshot>.from(quotations);
                
                quotationsList.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aCreated = aData['createdAt'] as Timestamp?;
                  final bCreated = bData['createdAt'] as Timestamp?;
                  
                  if (aCreated == null && bCreated == null) return 0;
                  if (aCreated == null) return 1;
                  if (bCreated == null) return -1;
                  return bCreated.compareTo(aCreated); // Descending
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: quotationsList.length,
                  itemBuilder: (context, index) {
                    final doc = quotationsList[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // Extract correct fields with null checks
                    final customerName = data['customerName'] as String? ?? '';
                    final items = (data['items'] as List?) ?? [];
                    final adminTotalPrice = data['adminTotalPrice'] as num?;
                    final status = (data['status'] as String? ?? 'pending').toLowerCase();
                    final createdAt = data['createdAt'] as Timestamp?;
                    
                    // Parse first item from items array
                    String productName = 'Custom Product';
                    double? length;
                    double? width;
                    int quantity = 1;
                    
                    if (items.isNotEmpty) {
                      final firstItem = items[0] as Map<String, dynamic>?;
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
                        final quantityValue = firstItem['quantity'];
                        if (quantityValue != null) {
                          quantity = (quantityValue is num) ? quantityValue.toInt() : int.tryParse(quantityValue.toString()) ?? 1;
                        }
                      }
                    } else {
                      // Fallback to quotation-level fields if items array is empty
                      productName = data['productName'] as String? ?? 'Custom Product';
                      final lengthValue = data['length'];
                      if (lengthValue != null) {
                        length = (lengthValue is num) ? lengthValue.toDouble() : double.tryParse(lengthValue.toString());
                      }
                      final widthValue = data['width'];
                      if (widthValue != null) {
                        width = (widthValue is num) ? widthValue.toDouble() : double.tryParse(widthValue.toString());
                      }
                      final quantityValue = data['quantity'];
                      if (quantityValue != null) {
                        quantity = (quantityValue is num) ? quantityValue.toInt() : int.tryParse(quantityValue.toString()) ?? 1;
                      }
                    }
                    
                    // Format size string
                    String sizeText = '';
                    if (length != null && width != null) {
                      sizeText = '${length.toStringAsFixed(0)}" × ${width.toStringAsFixed(0)}"';
                    } else if (length != null) {
                      sizeText = '${length.toStringAsFixed(0)}"';
                    } else if (width != null) {
                      sizeText = '${width.toStringAsFixed(0)}"';
                    }
                    
                    // Format status for display
                    String statusDisplay = _formatStatus(status);
                    
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
                                builder: (context) => QuotationDetailsPage(
                                  quotationId: doc.id,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            productName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (customerName.isNotEmpty)
                                            Text(
                                              customerName,
                                              style: TextStyle(
                                                fontSize: 14,
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
                                        color: _getStatusColor(status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _getStatusColor(status),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        statusDisplay,
                                        style: TextStyle(
                                          color: _getStatusColor(status),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (sizeText.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.straighten, size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        sizeText,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (quantity > 1) ...[
                                        const SizedBox(width: 12),
                                        Text(
                                          'Qty: $quantity',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDate(createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      adminTotalPrice != null && adminTotalPrice > 0
                                          ? PriceFormatter.formatPrice(adminTotalPrice.toDouble())
                                          : 'Waiting for price',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: adminTotalPrice != null && adminTotalPrice > 0
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}


