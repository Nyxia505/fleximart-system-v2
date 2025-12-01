import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../utils/price_formatter.dart';
import 'quotation_details_page.dart';

class QuotationsPage extends StatelessWidget {
  const QuotationsPage({super.key});

  Future<void> _updateQuotationStatus(
    BuildContext context,
    DocumentReference quotationRef,
    String newStatus,
  ) async {
    try {
      // Get current quotation data
      final quotationDoc = await quotationRef.get();
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
      
      final quotationData = quotationDoc.data() as Map<String, dynamic>?;
      final oldStatus = (quotationData?['status'] as String? ?? 'pending').toLowerCase();
      
      // Normalize status values: approved -> quoted, ensure lowercase
      String normalizedStatus = newStatus.toLowerCase();
      if (normalizedStatus == 'approved') {
        normalizedStatus = 'quoted';
      }
      
      // Validate status - only allow: pending, quoted, completed, rejected
      final validStatuses = ['pending', 'quoted', 'completed', 'rejected'];
      if (!validStatuses.contains(normalizedStatus)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid status: $newStatus. Valid statuses are: ${validStatuses.join(", ")}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      
      // Try to get customerId, with fallback to customerEmail lookup
      String? customerId = quotationData?['customerId'] as String?;
      final customerEmail = quotationData?['customerEmail'] as String?;
      final productName = quotationData?['productName'] as String? ?? 'your quotation';
      num? estimatedPrice = quotationData?['estimatedPrice'] as num?;
      
      // If customerId is missing, try to find user by email
      if ((customerId == null || customerId.isEmpty) && customerEmail != null && customerEmail.isNotEmpty) {
        try {
          final userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: customerEmail)
              .limit(1)
              .get();
          if (userQuery.docs.isNotEmpty) {
            customerId = userQuery.docs.first.id;
            debugPrint('🔍 Found customer ID by email: $customerId');
          } else {
            debugPrint('⚠️ No user found with email: $customerEmail');
          }
        } catch (e) {
          debugPrint('⚠️ Could not find customer by email: $e');
        }
      }
      
      // Log all quotation data for debugging
      debugPrint('📋 Quotation Data:');
      debugPrint('   customerId: $customerId');
      debugPrint('   customerEmail: $customerEmail');
      debugPrint('   productName: $productName');
      debugPrint('   oldStatus: $oldStatus');
      debugPrint('   newStatus: $normalizedStatus');
      debugPrint('   estimatedPrice: $estimatedPrice');
      
      // Update quotation status with normalized value
      await quotationRef.update({
        'status': normalizedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // IMPORTANT: Re-read quotation data after update to get latest estimatedPrice
      // This ensures we have the most recent price if it was just added
      if (normalizedStatus == 'quoted') {
        try {
          final updatedQuotationDoc = await quotationRef.get();
          if (updatedQuotationDoc.exists) {
            final updatedData = updatedQuotationDoc.data() as Map<String, dynamic>?;
            final latestPrice = updatedData?['estimatedPrice'] as num?;
            if (latestPrice != null && latestPrice > 0) {
              estimatedPrice = latestPrice;
              debugPrint('💰 Updated estimatedPrice from latest quotation: ${PriceFormatter.formatPrice(estimatedPrice.toDouble())}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Could not re-read quotation for latest price: $e');
        }
      }
      
      // Send notification to customer when status changes to 'Approved' OR when price is set and status is 'Quoted'
      // Also send when changing from 'Quoted' to 'Approved' with price
      bool shouldNotify = false;
      String notificationMessage = '';
      
      // Notify when status changes to 'quoted' (if customerId exists)
      if (normalizedStatus == 'quoted' && customerId != null && customerId.isNotEmpty && oldStatus != 'quoted') {
        shouldNotify = true;
        if (estimatedPrice != null && estimatedPrice > 0) {
          notificationMessage = 'Your quotation for $productName has been approved! Estimated price: ${PriceFormatter.formatPrice(estimatedPrice.toDouble())}.';
        } else {
          notificationMessage = 'Your quotation for $productName has been approved!';
        }
        debugPrint('✅ Will notify: Status changed to quoted');
        debugPrint('   Customer ID: $customerId');
        debugPrint('   Product: $productName');
        debugPrint('   Price: $estimatedPrice');
      }
      
      // IMPORTANT: Also notify if status is already quoted but we're adding/updating the price
      if (!shouldNotify && normalizedStatus == 'quoted' && oldStatus == 'quoted' && estimatedPrice != null && estimatedPrice > 0 && customerId != null && customerId.isNotEmpty) {
        // Check if price was just added (estimatedPrice exists but wasn't there before)
        final oldPrice = quotationData?['estimatedPrice'] as num?;
        if (oldPrice == null || oldPrice != estimatedPrice) {
          shouldNotify = true;
          notificationMessage = 'Your quotation for $productName has been updated with an estimated price of ${PriceFormatter.formatPrice(estimatedPrice.toDouble())}.';
          debugPrint('✅ Will notify: Price updated in Quoted status');
        }
      }
      
      if (shouldNotify && customerId != null && customerId.isNotEmpty) {
        try {
          debugPrint('📋 Quotation ID: ${quotationRef.id}');
          debugPrint('👤 Customer ID: $customerId');
          debugPrint('📊 Old Status: $oldStatus, New Status: $newStatus');
          debugPrint('💰 Estimated Price: $estimatedPrice');
          debugPrint('📨 Sending notification to customer...');
          
          final notificationData = {
            'userId': customerId,
            'type': 'quotation_approved',
            'title': 'Quotation Approved',
            'message': notificationMessage,
            'quotationId': quotationRef.id,
            'quotationStatus': normalizedStatus, // Add status to notification
            'estimatedPrice': estimatedPrice,
            'productName': productName,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          };
          
          debugPrint('📝 Notification data: $notificationData');
          
          final notificationRef = await FirebaseFirestore.instance.collection('notifications').add(notificationData);
          debugPrint('✅ Notification created with ID: ${notificationRef.id} for customer: $customerId');
          
          // Wait a moment for Firestore to process
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Verify the notification was created and can be read
          final verifyDoc = await notificationRef.get();
          if (verifyDoc.exists) {
            debugPrint('✅ Notification verified in Firestore');
            final verifyData = verifyDoc.data();
            debugPrint('📋 Verified notification userId: ${verifyData?['userId']}');
            debugPrint('📋 Verified notification title: ${verifyData?['title']}');
            
            // Test if customer can read this notification
            try {
              final testQuery = await FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: customerId)
                  .where(FieldPath.documentId, isEqualTo: notificationRef.id)
                  .limit(1)
                  .get();
              
              if (testQuery.docs.isNotEmpty) {
                debugPrint('✅ Customer can read the notification!');
              } else {
                debugPrint('⚠️ Customer cannot read the notification - possible permission issue');
              }
            } catch (e) {
              debugPrint('❌ Error testing notification read: $e');
            }
          } else {
            debugPrint('❌ Notification not found in Firestore after creation!');
          }
        } catch (e) {
          debugPrint('❌ Error sending notification: $e');
          debugPrint('❌ Stack trace: ${StackTrace.current}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Status updated but notification failed: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        } else {
          if (normalizedStatus == 'quoted') {
            debugPrint('⚠️ Notification not sent - Customer ID: $customerId, Old Status: $oldStatus, New Status: $normalizedStatus, Estimated Price: $estimatedPrice');
            debugPrint('⚠️ shouldNotify was: $shouldNotify');
            debugPrint('⚠️ Product Name: $productName');
          if (customerId == null || customerId.isEmpty) {
            debugPrint('❌ CRITICAL: Customer ID is missing! Cannot send notification.');
            debugPrint('❌ Quotation data keys: ${quotationData?.keys.toList()}');
            debugPrint('❌ customerEmail: $customerEmail');
            debugPrint('❌ Attempting to find customer by email...');
            // Try one more time to find customer
            if (customerEmail != null && customerEmail.isNotEmpty) {
              try {
                final userQuery = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: customerEmail)
                    .limit(1)
                    .get();
                if (userQuery.docs.isNotEmpty) {
                  final foundCustomerId = userQuery.docs.first.id;
                  debugPrint('✅ Found customer ID: $foundCustomerId');
                  // Create notification with found customer ID
                  try {
                    final notificationData = {
                      'userId': foundCustomerId,
                      'type': 'quotation_approved',
                      'title': 'Quotation Approved',
                      'message': 'Your quotation for $productName has been ${normalizedStatus}.${estimatedPrice != null && estimatedPrice > 0 ? ' Estimated price: ${PriceFormatter.formatPrice(estimatedPrice.toDouble())}.' : ''}',
                      'quotationId': quotationRef.id,
                      'quotationStatus': normalizedStatus,
                      'estimatedPrice': estimatedPrice,
                      'productName': productName,
                      'read': false,
                      'createdAt': FieldValue.serverTimestamp(),
                    };
                    await FirebaseFirestore.instance.collection('notifications').add(notificationData);
                    debugPrint('✅ Notification created with found customer ID');
                  } catch (e) {
                    debugPrint('❌ Error creating notification with found ID: $e');
                  }
                } else {
                  debugPrint('❌ No user found with email: $customerEmail');
                }
              } catch (e) {
                debugPrint('❌ Error finding customer: $e');
              }
            }
          } else {
            // Customer ID exists but shouldNotify is false - force notification
            debugPrint('⚠️ Customer ID exists but notification not triggered. Forcing notification...');
            try {
              final notificationData = {
                'userId': customerId,
                'type': 'quotation_approved',
                'title': 'Quotation ${newStatus}',
                'message': 'Your quotation for $productName status has been updated to ${newStatus}.${estimatedPrice != null && estimatedPrice > 0 ? ' Estimated price: ${PriceFormatter.formatPrice(estimatedPrice.toDouble())}.' : ''}',
                'quotationId': quotationRef.id,
                'quotationStatus': newStatus,
                'estimatedPrice': estimatedPrice,
                'productName': productName,
                'read': false,
                'createdAt': FieldValue.serverTimestamp(),
              };
              await FirebaseFirestore.instance.collection('notifications').add(notificationData);
              debugPrint('✅ Forced notification created');
            } catch (e) {
              debugPrint('❌ Error creating forced notification: $e');
            }
          }
        }
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quotation status updated to $newStatus'),
            backgroundColor: AppColors.success,
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

  Future<void> _addPriceEstimate(
    BuildContext context,
    DocumentReference quotationRef,
    Map<String, dynamic> quotation,
  ) async {
    debugPrint('🚀 _addPriceEstimate called for quotation: ${quotationRef.id}');
    final priceController = TextEditingController();
    final notesController = TextEditingController(
      text: quotation['notes'] ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Price Estimate'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Estimated Price (₱)',
                  border: OutlineInputBorder(),
                  prefixText: '₱',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (priceController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    debugPrint('📝 Dialog result: $result, Price: ${priceController.text.trim()}');
    if (result == true && priceController.text.trim().isNotEmpty) {
      final price = double.tryParse(priceController.text.trim());
      debugPrint('💰 Parsed price: $price');
      if (price != null && price > 0) {
        try {
          debugPrint('📋 Fetching quotation data...');
          // Get quotation data to access customerId BEFORE updating
          final quotationDoc = await quotationRef.get();
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
          
          final quotationData = quotationDoc.data() as Map<String, dynamic>?;
          // Try to get customerId, with fallback to customerEmail lookup
          String? customerId = quotationData?['customerId'] as String?;
          final customerEmail = quotationData?['customerEmail'] as String?;
          final productName = quotationData?['productName'] as String? ?? 'your quotation';
          
          // If customerId is missing, try to find user by email
          if ((customerId == null || customerId.isEmpty) && customerEmail != null && customerEmail.isNotEmpty) {
            try {
              final userQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: customerEmail)
                  .limit(1)
                  .get();
              if (userQuery.docs.isNotEmpty) {
                customerId = userQuery.docs.first.id;
                debugPrint('🔍 Found customer ID by email: $customerId');
              }
            } catch (e) {
              debugPrint('⚠️ Could not find customer by email: $e');
            }
          }
          
          debugPrint('📋 Quotation ID: ${quotationRef.id}');
          debugPrint('👤 Customer ID: $customerId');
          debugPrint('👤 Customer Email: $customerEmail');
          debugPrint('💰 Estimated Price: ${PriceFormatter.formatPrice(price)}');
          debugPrint('📦 Product Name: $productName');
          
          // CRITICAL: If customerId is still null, we MUST find it or notification will fail
          if ((customerId == null || customerId.isEmpty) && customerEmail != null && customerEmail.isNotEmpty) {
            debugPrint('⚠️ Customer ID still missing, attempting email lookup again...');
            try {
              final userQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: customerEmail)
                  .limit(1)
                  .get();
              if (userQuery.docs.isNotEmpty) {
                customerId = userQuery.docs.first.id;
                debugPrint('✅ Found customer ID by email: $customerId');
              } else {
                debugPrint('❌ No user found with email: $customerEmail');
              }
            } catch (e) {
              debugPrint('❌ Error finding customer by email: $e');
            }
          }
          
          // IMPORTANT: Send notification BEFORE updating to ensure we have the right data
          // Send notification to customer when price is added
          if (customerId != null && customerId.isNotEmpty) {
            try {
              debugPrint('📨 Sending notification to customer for price estimate...');
              debugPrint('👤 Customer ID: $customerId');
              debugPrint('💰 Price: ${PriceFormatter.formatPrice(price)}');
              
              final notificationData = {
                'userId': customerId,
                'type': 'quotation_approved',
                'title': 'Quotation Approved',
                'message': 'Your quotation for $productName has been approved with an estimated price of ${PriceFormatter.formatPrice(price)}.',
                'quotationId': quotationRef.id,
                'quotationStatus': 'quoted', // Add status to notification
                'estimatedPrice': price,
                'productName': productName,
                'read': false,
                'createdAt': FieldValue.serverTimestamp(),
              };
              
              debugPrint('📝 Notification data: $notificationData');
              
              final notificationRef = await FirebaseFirestore.instance.collection('notifications').add(notificationData);
              debugPrint('✅ Notification created with ID: ${notificationRef.id} for customer: $customerId');
              
              // Wait a moment for Firestore to process
              await Future.delayed(const Duration(milliseconds: 500));
              
              // Verify the notification was created and can be read
              final verifyDoc = await notificationRef.get();
              if (verifyDoc.exists) {
                debugPrint('✅ Notification verified in Firestore');
                final verifyData = verifyDoc.data();
                debugPrint('📋 Verified notification userId: ${verifyData?['userId']}');
                debugPrint('📋 Verified notification title: ${verifyData?['title']}');
                
                // Test if customer can read this notification
                try {
                  final testQuery = await FirebaseFirestore.instance
                      .collection('notifications')
                      .where('userId', isEqualTo: customerId)
                      .where(FieldPath.documentId, isEqualTo: notificationRef.id)
                      .limit(1)
                      .get();
                  
                  if (testQuery.docs.isNotEmpty) {
                    debugPrint('✅ Customer can read the notification!');
                  } else {
                    debugPrint('⚠️ Customer cannot read the notification - possible permission issue');
                    debugPrint('⚠️ Customer ID in query: $customerId');
                    debugPrint('⚠️ Notification ID: ${notificationRef.id}');
                  }
                } catch (e) {
                  debugPrint('❌ Error testing notification read: $e');
                }
              } else {
                debugPrint('❌ Notification not found in Firestore after creation!');
              }
            } catch (e) {
              debugPrint('❌ Error sending notification: $e');
              debugPrint('❌ Stack trace: ${StackTrace.current}');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Price added but notification failed: $e'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          } else {
            debugPrint('⚠️ Customer ID is null or empty, cannot send notification');
            debugPrint('⚠️ Quotation data: $quotationData');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Price added but customer ID not found'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
          
          // Update quotation AFTER sending notification
          // Do NOT change status - only update price and notes
          // Status should only be changed via Approve/Reject buttons
          await quotationRef.update({
            'estimatedPrice': price,
            'notes': notesController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Price estimate added successfully'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          debugPrint('❌ Error updating quotation: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    }
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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Quotations',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('quotations')
                      .where('customerId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final count = snapshot.data!.docs.length;
                      return Text(
                        '$count ${count == 1 ? 'quotation' : 'quotations'}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
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


